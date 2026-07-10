---
name: moneyprinterturbo-video
description: Use when the user wants to install, run, or automate harry0703/MoneyPrinterTurbo for one-click HD short video generation from a topic or script. Trigger for MoneyPrinterTurbo, harry0703/MoneyPrinterTurbo.git, 一键生成高清短视频, 自动生成短视频, 文案转视频, topic-to-video, TikTok/Reels/YouTube Shorts/Douyin/Kuaishou short-video generation, or API/WebUI setup for this project.
---

# MoneyPrinterTurbo Video

## What this skill enables

Use MoneyPrinterTurbo to generate HD short videos from a topic, keywords, or a finished script. Prefer the local API workflow for automation, and use the WebUI only when the user asks for a visual/manual workflow.

Upstream project: `https://github.com/harry0703/MoneyPrinterTurbo.git`

For endpoint details, read `references/moneyprinterturbo-api.md` only when you need direct API calls or troubleshooting.

## Default assumptions

When the user leaves options unspecified, use these defaults:

| Option | Default |
|---|---|
| Aspect | `9:16` portrait, 1080x1920 |
| Count | `1` video |
| Material source | `pexels` |
| Clip duration | `5` seconds |
| Subtitles | enabled |
| Subtitle style | bottom, white text, black stroke, font size `60` |
| BGM | `random`, volume controlled by MoneyPrinterTurbo defaults |
| TTS | project default Edge TTS unless the user asks for another voice |

Ask a concise follow-up only when there is no video topic/script, or when generation cannot proceed because required keys/configuration are missing.

## Setup workflow

1. Check whether a MoneyPrinterTurbo project already exists. Use the user's path if they gave one; otherwise prefer `$env:MPT_HOME`; otherwise use a local `MoneyPrinterTurbo` directory under the current working directory.
2. If the project is missing, clone from `https://github.com/harry0703/MoneyPrinterTurbo.git`.
3. Ensure Python dependencies are installed. Prefer:

   ```powershell
   uv python install 3.11
   uv sync --frozen
   ```

4. Ensure `config.toml` exists. If missing, copy `config.example.toml` to `config.toml`.
5. Confirm the required configuration before spending render time:
   - For topic-to-video generation, `llm_provider` and the matching provider API key must be configured.
   - For online stock materials, configure either `pexels_api_keys` or `pixabay_api_keys` and set `video_source` accordingly.
   - Edge TTS works by default for many voices. Azure TTS V2 requires `[azure].speech_key` and `[azure].speech_region`.
   - If FFmpeg auto-download fails, set `[app].ffmpeg_path`.
6. Start the API service when needed:

   ```powershell
   uv run python main.py
   ```

   API docs should appear at `http://127.0.0.1:8080/docs`.

## One-command automation

Use the bundled script for most tasks. Resolve the script path relative to this `SKILL.md` file.

Example:

```powershell
$skill = "C:\Users\16689\Documents\skills\moneyprinterturbo-video"
& "$skill\scripts\mpt_generate.ps1" `
  -Subject "用60秒介绍上海城市夜景和外滩旅行灵感" `
  -Aspect "9:16" `
  -VideoCount 1 `
  -OutputDir "$PWD\mpt-output" `
  -StartServer
```

If the user already wrote a script/copy, pass it with `-ScriptText` to reduce dependency on the LLM:

```powershell
& "$skill\scripts\mpt_generate.ps1" `
  -Subject "夏季防晒小贴士" `
  -ScriptText "第一，出门前十五分钟涂防晒。第二，每两小时补涂一次。第三，帽子和墨镜也很重要。" `
  -VideoSource "pexels" `
  -Aspect "9:16" `
  -StartServer
```

The script will:

1. Clone MoneyPrinterTurbo if needed.
2. Install/sync dependencies with `uv`.
3. Copy `config.example.toml` to `config.toml` if needed.
4. Start the API server if `-StartServer` is provided and the API is not already reachable.
5. Submit `POST /api/v1/videos`.
6. Poll `GET /api/v1/tasks/{task_id}`.
7. Download generated `.mp4` files into `-OutputDir`.

Do not put API keys directly in commands or conversation output. Ask the user to edit `config.toml` or set provider-specific environment/config values locally.

## Direct API workflow

Use direct HTTP calls when the bundled script is not enough:

1. Start API:

   ```powershell
   cd <MoneyPrinterTurbo>
   uv run python main.py
   ```

2. Submit a task:

   ```powershell
   $body = @{
     video_subject = "A day in Shanghai"
     video_aspect = "9:16"
     video_source = "pexels"
     video_count = 1
     video_clip_duration = 5
     subtitle_enabled = $true
     font_size = 60
   } | ConvertTo-Json

   Invoke-RestMethod -Method Post `
     -Uri "http://127.0.0.1:8080/api/v1/videos" `
     -ContentType "application/json" `
     -Body $body
   ```

3. Poll:

   ```powershell
   Invoke-RestMethod "http://127.0.0.1:8080/api/v1/tasks/<task_id>"
   ```

4. Download the URLs returned in `data.videos` or `data.combined_videos`.

## Quality guidance

- Use `9:16` for Douyin, TikTok, Reels, and YouTube Shorts. Use `16:9` only when the user explicitly wants landscape.
- Keep scripts short and punchy. For a 30-60 second short, aim for 80-180 Chinese characters or roughly 70-140 English words.
- Use `video_count 2` or `3` only when the user wants choices; it increases render time and API/material usage.
- Use `video_concat_mode = "sequential"` when the user supplies ordered local materials.
- Prefer `video_source = "local"` when the user provides their own videos/images; upload files with `/api/v1/video_materials` or place them in the project's local video storage.
- Warn the user that generated stock-material videos still need final review for brand safety, factual accuracy, licensing fit, and platform policy compliance.

## Troubleshooting

| Symptom | What to do |
|---|---|
| API not reachable on port `8080` | Start `uv run python main.py`; check `storage/codex-api.err.log` if started by the script. |
| `config.toml` was just created | Ask the user to fill provider keys before generating from only a topic. |
| Task returns `429` | Queue is full; wait or lower `video_count`. |
| Stock footage is empty/fails | Check `pexels_api_keys` or `pixabay_api_keys`, proxy, and TLS settings. |
| `No ffmpeg exe could be found` | Install FFmpeg or set `[app].ffmpeg_path` in `config.toml`. |
| Subtitles are inaccurate | Keep `subtitle_provider = "edge"` for speed; switch to `whisper` only when accuracy is more important and the model is available. |

## Reporting results

When finished, report:

- MoneyPrinterTurbo project path.
- API base URL.
- Task ID.
- Downloaded video file paths.
- Any configuration gaps or warnings.

Keep the response short and practical so the user can immediately inspect the generated video.
