from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_STATIC = ROOT / "assets" / "desktop-pet" / "static"
SOURCE_MOTION = ROOT / "assets" / "desktop-pet" / "motion"
OUT_STATIC = ROOT / "assets" / "desktop-pet" / "transparent" / "static"
OUT_MOTION = ROOT / "assets" / "desktop-pet" / "transparent" / "motion"

CANVAS = 512
SUBJECT_HEIGHT = 468
BOTTOM_PAD = 22
WHITE_MIN = 216
WHITE_MEAN = 226
WHITE_SPREAD = 54

STATIC_MAP = {
    "默认动作-站立.png": "default.png",
    "微笑-倾听-等待输入.png": "listen.png",
    "交谈-对话-微笑.png": "talk.png",
    "兴奋.png": "happy.png",
    "卖萌.png": "cute.png",
    "无奈-思考-晕.png": "dizzy.png",
}

MOTION_MAP = {
    "桌面宠物-兴奋.mp4": "excited.png",
    "桌面宠物-投喂成功-1.mp4": "feed.png",
    "桌面宠物-撒娇.mp4": "cute.png",
    "桌面宠物-肚子饿.mp4": "hungry.png",
}


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def near_white_mask(rgb: np.ndarray) -> np.ndarray:
    channels = rgb.astype(np.int16)
    maxc = channels.max(axis=2)
    minc = channels.min(axis=2)
    mean = channels.mean(axis=2)
    return (minc >= WHITE_MIN) & (mean >= WHITE_MEAN) & ((maxc - minc) <= WHITE_SPREAD)


def border_connected(mask: np.ndarray) -> np.ndarray:
    seed = np.zeros(mask.shape, dtype=bool)
    seed[0, :] = mask[0, :]
    seed[-1, :] = mask[-1, :]
    seed[:, 0] = mask[:, 0]
    seed[:, -1] = mask[:, -1]
    connected = seed
    while True:
        expanded = connected.copy()
        expanded[1:, :] |= connected[:-1, :]
        expanded[:-1, :] |= connected[1:, :]
        expanded[:, 1:] |= connected[:, :-1]
        expanded[:, :-1] |= connected[:, 1:]
        expanded &= mask
        if np.array_equal(expanded, connected):
            return connected
        connected = expanded


def remove_white_background(image: Image.Image) -> Image.Image:
    if "A" in image.mode and image.getchannel("A").getextrema()[0] < 255:
        return image.convert("RGBA")
    rgb_image = image.convert("RGB")
    rgb = np.asarray(rgb_image)
    background = border_connected(near_white_mask(rgb))
    alpha = np.full(background.shape, 255, dtype=np.uint8)
    alpha[background] = 0
    rgba = np.dstack([rgb, alpha])
    return Image.fromarray(rgba, "RGBA")


def bbox_for_alpha(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.where(alpha > 8)
    if len(xs) == 0 or len(ys) == 0:
        return (0, 0, image.width, image.height)
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def union_bbox(boxes: list[tuple[int, int, int, int]]) -> tuple[int, int, int, int]:
    return (
        min(box[0] for box in boxes),
        min(box[1] for box in boxes),
        max(box[2] for box in boxes),
        max(box[3] for box in boxes),
    )


def fit_to_canvas(image: Image.Image, bbox: tuple[int, int, int, int]) -> Image.Image:
    cropped = image.crop(bbox)
    scale = SUBJECT_HEIGHT / max(1, cropped.height)
    width = max(1, round(cropped.width * scale))
    height = max(1, round(cropped.height * scale))
    if width > CANVAS - 32:
        scale = (CANVAS - 32) / max(1, cropped.width)
        width = max(1, round(cropped.width * scale))
        height = max(1, round(cropped.height * scale))
    resized = cropped.resize((width, height), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    x = (CANVAS - width) // 2
    y = CANVAS - BOTTOM_PAD - height
    canvas.alpha_composite(resized, (x, y))
    return canvas


def process_static() -> list[dict[str, object]]:
    OUT_STATIC.mkdir(parents=True, exist_ok=True)
    report = []
    for source_name, out_name in STATIC_MAP.items():
        source = SOURCE_STATIC / source_name
        transparent = remove_white_background(Image.open(source))
        bbox = bbox_for_alpha(transparent)
        output = fit_to_canvas(transparent, bbox)
        target = OUT_STATIC / out_name
        output.save(target, optimize=True)
        report.append({"source": source_name, "output": str(target.relative_to(ROOT)), "bbox": bbox, "size": output.size})
    return report


def ffprobe_size(path: Path) -> tuple[int, int]:
    raw = subprocess.check_output(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height",
            "-of",
            "json",
            str(path),
        ],
        text=True,
    )
    stream = json.loads(raw)["streams"][0]
    return int(stream["width"]), int(stream["height"])


def extract_scaled_frames(source: Path, frames_dir: Path) -> None:
    width, height = ffprobe_size(source)
    scale = f"{CANVAS}:-2" if width >= height else f"-2:{CANVAS}"
    run(["ffmpeg", "-y", "-v", "error", "-i", str(source), "-vf", f"scale={scale}", str(frames_dir / "frame_%04d.png")])


def process_motion() -> list[dict[str, object]]:
    OUT_MOTION.mkdir(parents=True, exist_ok=True)
    report = []
    for source_name, out_name in MOTION_MAP.items():
        source = SOURCE_MOTION / source_name
        with tempfile.TemporaryDirectory(prefix="desktop-pet-", dir=ROOT) as tmp:
            tmp_dir = Path(tmp)
            raw_dir = tmp_dir / "raw"
            processed_dir = tmp_dir / "processed"
            raw_dir.mkdir()
            processed_dir.mkdir()
            extract_scaled_frames(source, raw_dir)
            frames = sorted(raw_dir.glob("frame_*.png"))
            transparent_frames = []
            boxes = []
            for frame in frames:
                transparent = remove_white_background(Image.open(frame))
                transparent_frames.append(transparent)
                boxes.append(bbox_for_alpha(transparent))
            bbox = union_bbox(boxes)
            for index, transparent in enumerate(transparent_frames, start=1):
                fit_to_canvas(transparent, bbox).save(processed_dir / f"frame_{index:04d}.png")
            target = OUT_MOTION / out_name
            apng_frames = [Image.open(processed_dir / f"frame_{index:04d}.png") for index in range(1, len(frames) + 1)]
            apng_frames[0].save(
                target,
                save_all=True,
                append_images=apng_frames[1:],
                duration=33,
                loop=0,
                disposal=2,
                optimize=True,
            )
            report.append({"source": source_name, "output": str(target.relative_to(ROOT)), "bbox": bbox, "frames": len(frames)})
    return report


def main() -> None:
    if OUT_STATIC.exists():
        shutil.rmtree(OUT_STATIC)
    if OUT_MOTION.exists():
        shutil.rmtree(OUT_MOTION)
    report = {
        "canvas": CANVAS,
        "subjectHeight": SUBJECT_HEIGHT,
        "bottomPad": BOTTOM_PAD,
        "static": process_static(),
        "motion": process_motion(),
    }
    report_path = ROOT / "assets" / "desktop-pet" / "transparent" / "manifest.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
