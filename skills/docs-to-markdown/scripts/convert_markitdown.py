#!/usr/bin/env python3
"""Convert local documents to Markdown with Microsoft MarkItDown."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


DEFAULT_EXTENSIONS = {
    ".bmp",
    ".csv",
    ".doc",
    ".docx",
    ".eml",
    ".epub",
    ".gif",
    ".htm",
    ".html",
    ".jpeg",
    ".jpg",
    ".json",
    ".mp3",
    ".msg",
    ".pdf",
    ".png",
    ".ppt",
    ".pptx",
    ".tif",
    ".tiff",
    ".txt",
    ".wav",
    ".xls",
    ".xlsx",
    ".xml",
    ".zip",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert files or folders to Markdown using Microsoft MarkItDown."
    )
    parser.add_argument("inputs", nargs="+", help="Input file(s) or folder(s).")
    parser.add_argument(
        "-o",
        "--output",
        help="Output .md path. Only valid when exactly one input file is converted.",
    )
    parser.add_argument(
        "--output-dir",
        help="Directory for batch output. Relative paths under input folders are preserved.",
    )
    parser.add_argument(
        "-r",
        "--recursive",
        action="store_true",
        help="Recursively scan input directories.",
    )
    parser.add_argument(
        "--extensions",
        default=",".join(sorted(DEFAULT_EXTENSIONS)),
        help=(
            "Comma-separated extensions for folder scans. Use '*' to attempt every file. "
            "Default includes common document and Office formats."
        ),
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing Markdown files.",
    )
    parser.add_argument(
        "--use-plugins",
        action="store_true",
        help="Enable installed MarkItDown plugins.",
    )
    parser.add_argument(
        "--docintel-endpoint",
        help="Azure Document Intelligence endpoint. Use only when cloud processing is intended.",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Only print errors.",
    )
    return parser.parse_args()


def fail(message: str, code: int = 1) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(code)


def load_markitdown():
    try:
        from markitdown import MarkItDown
    except Exception as exc:  # pragma: no cover - depends on user environment
        print("error: MarkItDown is not installed or could not be imported.", file=sys.stderr)
        print(f"import error: {exc}", file=sys.stderr)
        print(
            'install: python -m pip install "markitdown[all]"',
            file=sys.stderr,
        )
        print(
            "source install: git clone https://github.com/microsoft/markitdown.git "
            '&& cd markitdown && python -m pip install -e "packages/markitdown[all]"',
            file=sys.stderr,
        )
        raise SystemExit(2)
    return MarkItDown


def normalize_extensions(value: str) -> set[str] | None:
    if value.strip() == "*":
        return None
    extensions: set[str] = set()
    for item in value.split(","):
        ext = item.strip().lower()
        if not ext:
            continue
        if not ext.startswith("."):
            ext = f".{ext}"
        extensions.add(ext)
    return extensions


def collect_files(inputs: list[str], recursive: bool, extensions: set[str] | None) -> list[tuple[Path, Path]]:
    files: list[tuple[Path, Path]] = []
    for raw_input in inputs:
        path = Path(raw_input).expanduser().resolve()
        if path.is_file():
            files.append((path, path.parent))
            continue
        if not path.exists():
            fail(f"input does not exist: {path}")
        if not path.is_dir():
            fail(f"input is neither a file nor a directory: {path}")

        iterator = path.rglob("*") if recursive else path.glob("*")
        for candidate in iterator:
            if not candidate.is_file():
                continue
            if extensions is not None and candidate.suffix.lower() not in extensions:
                continue
            files.append((candidate.resolve(), path))
    return files


def destination_for(source: Path, root: Path, args: argparse.Namespace, total_files: int) -> Path:
    if args.output:
        if total_files != 1:
            fail("--output can only be used when exactly one file is converted")
        return Path(args.output).expanduser().resolve()

    if args.output_dir:
        output_root = Path(args.output_dir).expanduser().resolve()
        try:
            relative = source.relative_to(root)
        except ValueError:
            relative = Path(source.name)
        return (output_root / relative).with_suffix(".md")

    return source.with_suffix(".md")


def extract_markdown(result: object) -> str:
    for attribute in ("text_content", "markdown"):
        value = getattr(result, attribute, None)
        if isinstance(value, str):
            return value
    return str(result)


def convert_file(converter: object, source: Path) -> str:
    if hasattr(converter, "convert_local"):
        result = converter.convert_local(str(source))
    else:
        result = converter.convert(str(source))
    return extract_markdown(result)


def build_converter(args: argparse.Namespace):
    MarkItDown = load_markitdown()
    kwargs: dict[str, object] = {"enable_plugins": args.use_plugins}
    if args.docintel_endpoint:
        kwargs["docintel_endpoint"] = args.docintel_endpoint
    return MarkItDown(**kwargs)


def main() -> int:
    args = parse_args()
    extensions = normalize_extensions(args.extensions)
    files = collect_files(args.inputs, args.recursive, extensions)
    if not files:
        fail("no matching input files found")

    converter = build_converter(args)
    errors: list[str] = []

    for source, root in files:
        output = destination_for(source, root, args, len(files))
        try:
            if output.exists() and not args.overwrite:
                raise FileExistsError(f"output exists, pass --overwrite to replace it: {output}")
            output.parent.mkdir(parents=True, exist_ok=True)
            markdown = convert_file(converter, source)
            if not markdown.strip():
                raise ValueError("conversion produced empty Markdown")
            output.write_text(markdown, encoding="utf-8", newline="\n")
            if not args.quiet:
                print(f"converted: {source} -> {output} ({len(markdown)} chars)")
        except Exception as exc:
            errors.append(f"{source}: {exc}")

    if errors:
        print("conversion completed with errors:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    if not args.quiet:
        print(f"done: {len(files)} file(s) converted")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
