# Repository Structure

This repository is organized around one primary artifact: `skill-archive.html`.

## Root Files

- `README.md`: project overview, quick start, common commands, and safety notes.
- `skill-archive.html`: generated archive page. Open it directly in a browser.
- `skill-source-index.json`: source mapping used to link Skills back to upstream repositories.
- `AGENTS.md`: Codex-facing instructions that make the dashboard launcher the default install flow.
- `.env.example`: public environment variable template.
- `pet-secrets.example.js`: public page-pet model configuration template.
- `.gitignore`: local secrets, logs, caches, generated media, model weights, and IDE files.
- `OPEN_SOURCE_SECURITY_AUDIT.md`: open source security review and Git history cleanup plan.
- `LICENSE`: MIT license.

## Directories

- `scripts/`: PowerShell and Python utilities for dashboard setup, archive generation, update checks, source indexing, and pet asset processing.
- `launchers/windows/`: Windows double-click launcher for generating and opening the dashboard.
- `launchers/macos/`: macOS double-click launcher for generating and opening the dashboard.
- `assets/desktop-pet/`: static and motion assets for the “小V” page administrator.
- `assets/previews/`: preview images and visual references for the archive page.
- `docs/`: supporting documentation and design notes.
- `skills/`: local Skill packages included in the archive source set.
- `examples/stop-slop-mvp/`: small testable web app used as a lightweight quality check.
- `examples/小demo/poster-wallpaper-factory/`: small poster/wallpaper demo with tests.
- `reports/`: update reports, update run summaries, and local update backups.
- `showcase/pitch/`: pitch page and local pitch media exports.
- `showcase/layouts/`: layout explorations and screenshots.

## Generated vs Source Files

Treat these as generated or machine-local outputs:

- `skill-archive.html`
- `reports/skill-update-report.html`
- `reports/skill-update-report.json`
- `reports/skill-update-run.json`
- `reports/skill-update-backups/`
- `showcase/pitch/`
- `showcase/layouts/`

Treat these as source/configuration:

- `scripts/`
- `assets/desktop-pet/`
- `assets/previews/`
- `skills/`
- `examples/`
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
