# Repository Structure

This repository is organized around one primary artifact: `skill-archive.html`.

## Root Files

- `README.md`: project overview, quick start, common commands, and safety notes.
- `skill-archive.html`: generated archive page. Open it directly in a browser.
- `skill-source-index.json`: source mapping used to link Skills back to upstream repositories.
- `skill-update-report.html`: human-readable update report.
- `skill-update-report.json`: machine-readable update report.
- `skill-update-run.json`: latest local update run summary.
- `启动 Skill档案管理.cmd`: Windows double-click launcher for generating and opening the dashboard.
- `启动 Skill档案管理.command`: macOS double-click launcher for generating and opening the dashboard.
- `.env.example`: public environment variable template.
- `pet-secrets.example.js`: public page-pet model configuration template.
- `.gitignore`: local secrets, logs, caches, generated media, model weights, and IDE files.
- `OPEN_SOURCE_SECURITY_AUDIT.md`: open source security review and Git history cleanup plan.
- `LICENSE`: MIT license.

## Directories

- `scripts/`: PowerShell and Python utilities for dashboard setup, archive generation, update checks, source indexing, and pet asset processing.
- `assets/desktop-pet/`: static and motion assets for the “小V” page administrator.
- `assets/previews/`: preview images and visual references for the archive page.
- `docs/`: supporting documentation and design notes.
- `code-knowledge-graph/`, `docs-to-markdown/`, `lark-knowledge/`, `materials-to-office/`, `moneyprinterturbo-video/`, `performance-optimization/`, `web-automation/`, `wx-cli/`: local Skill packages included in the archive source set.
- `stop-slop-mvp/`: small testable web app used as a lightweight quality check.
- `小demo/poster-wallpaper-factory/`: small poster/wallpaper demo with tests.
- `skill-update-backups/`: local update backup output.

## Generated vs Source Files

Treat these as generated or machine-local outputs:

- `skill-archive.html`
- `skill-update-report.html`
- `skill-update-report.json`
- `skill-update-run.json`
- `skill-update-backups/`

Treat these as source/configuration:

- `scripts/`
- `assets/desktop-pet/`
- `assets/previews/`
- Skill package directories
- `.env.example`
- `pet-secrets.example.js`
- Documentation files

## Private Files

These files should only exist locally and must not be committed:

- `.env`
- `.env.*` except `.env.example`
- `pet-secrets.local.js`
- `skill-archive.local.js`
- private keys or certificates
- logs, caches, temporary files, generated local media, and model weights
