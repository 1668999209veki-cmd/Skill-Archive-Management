# MoneyPrinterTurbo API Reference

Source: `https://github.com/harry0703/MoneyPrinterTurbo.git`

## Service

Start the API from the MoneyPrinterTurbo project root:

```powershell
uv run python main.py
```

Default docs URL:

```text
http://127.0.0.1:8080/docs
```

All v1 endpoints use this prefix:

```text
/api/v1
```

## Core endpoints

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/v1/videos` | Generate a complete short video. |
| `POST` | `/api/v1/subtitle` | Generate subtitles only. |
| `POST` | `/api/v1/audio` | Generate narration/audio only. |
| `GET` | `/api/v1/tasks` | List tasks. |
| `GET` | `/api/v1/tasks/{task_id}` | Poll one task. |
| `DELETE` | `/api/v1/tasks/{task_id}` | Delete a task and generated files. |
| `GET` | `/api/v1/musics` | List local BGM files. |
| `POST` | `/api/v1/musics` | Upload an `.mp3` BGM file. |
| `GET` | `/api/v1/video_materials` | List local video/image materials. |
| `POST` | `/api/v1/video_materials` | Upload `mp4`, `mov`, `avi`, `flv`, `mkv`, `jpg`, `jpeg`, or `png` materials. |

Generated files are served from `/tasks/...` URLs.

## Minimal video body

```json
{
  "video_subject": "A day in Shanghai",
  "video_aspect": "9:16",
  "video_source": "pexels",
  "video_count": 1,
  "video_clip_duration": 5,
  "subtitle_enabled": true,
  "font_size": 60
}
```

## Useful fields

| Field | Type | Notes |
|---|---|---|
| `video_subject` | string | Required topic/title. |
| `video_script` | string | Optional finished script. If omitted, the project asks the configured LLM to write one. |
| `video_terms` | string or array | Optional search terms for stock/local material selection. |
| `video_aspect` | enum | `9:16`, `16:9`, or `1:1`. |
| `video_concat_mode` | enum | `random` or `sequential`. |
| `video_transition_mode` | enum/null | `Shuffle`, `FadeIn`, `FadeOut`, `SlideIn`, `SlideOut`, or null. |
| `video_clip_duration` | integer | Seconds per clip; usually `4` to `6`. |
| `video_count` | integer | Number of variants to generate. |
| `video_source` | string | Usually `pexels`, `pixabay`, or `local`. |
| `video_materials` | array | Local/custom material objects when supplying assets directly. |
| `custom_audio_file` | string | Uses a local audio file; ignores script and disables subtitles. |
| `video_language` | string | Leave blank for auto-detect. |
| `voice_name` | string | TTS voice ID; blank uses config/default. |
| `voice_volume` | number | Default `1.0`. |
| `voice_rate` | number | Default `1.0`. |
| `bgm_type` | string | Usually `random` or empty/custom depending on project config. |
| `bgm_file` | string | Uploaded/local BGM filename. |
| `bgm_volume` | number | Default `0.2`. |
| `subtitle_enabled` | boolean | Default true. |
| `subtitle_position` | string | `top`, `center`, `bottom`, or `custom`. |
| `custom_position` | number | Top percentage when using custom subtitle position. |
| `font_name` | string | Font file from project resources. |
| `text_fore_color` | string | Subtitle foreground color, e.g. `#FFFFFF`. |
| `text_background_color` | boolean/string | Subtitle background. |
| `rounded_subtitle_background` | boolean | Rounded subtitle background. |
| `font_size` | integer | `60` is a good portrait default. |
| `stroke_color` | string | Subtitle outline color, e.g. `#000000`. |
| `stroke_width` | number | Default `1.5`. |
| `n_threads` | integer | Worker threads for processing. |
| `paragraph_number` | integer | `1` to `10`; controls generated script paragraphs. |
| `video_script_prompt` | string | Custom script prompt, max 2000 chars. |
| `custom_system_prompt` | string | Custom system prompt, max 8000 chars. |

## Task response

Task creation returns:

```json
{
  "status": 200,
  "message": "success",
  "data": {
    "task_id": "6c85c8cc-a77a-42b9-bc30-947815aa0558"
  }
}
```

Polling eventually returns data similar to:

```json
{
  "state": 1,
  "progress": 100,
  "videos": [
    "http://127.0.0.1:8080/tasks/6c85c8cc-a77a-42b9-bc30-947815aa0558/final-1.mp4"
  ],
  "combined_videos": [
    "http://127.0.0.1:8080/tasks/6c85c8cc-a77a-42b9-bc30-947815aa0558/combined-1.mp4"
  ]
}
```
