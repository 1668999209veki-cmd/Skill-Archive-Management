# Understand-Anything Setup

Use this reference when the local machine does not already expose Understand-Anything commands or skills.

## Source

Preferred upstream source for this skill:

```text
https://github.com/Egonex-AI/Understand-Anything.git
```

The upstream README may mention another default repository in sample commands. When the user explicitly provided the Egonex-AI URL, preserve that source by setting `UA_REPO_URL`.

## Windows Install For Codex

Download the installer first so the command and source are visible:

```powershell
$env:UA_REPO_URL = "https://github.com/Egonex-AI/Understand-Anything.git"
$installer = Join-Path $env:TEMP "install-understand-anything.ps1"
Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/Egonex-AI/Understand-Anything/main/install.ps1" -OutFile $installer
powershell -ExecutionPolicy Bypass -File $installer codex
```

If the user wants the installer to choose the platform interactively, omit `codex`:

```powershell
powershell -ExecutionPolicy Bypass -File $installer
```

## macOS / Linux Install For Codex

```bash
export UA_REPO_URL="https://github.com/Egonex-AI/Understand-Anything.git"
curl -fsSL "https://raw.githubusercontent.com/Egonex-AI/Understand-Anything/main/install.sh" | bash -s codex
```

## Refresh Or Update

If `~/.understand-anything/repo` exists, prefer the upstream update flag when available:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.understand-anything\repo\install.ps1" -Update
```

On macOS/Linux:

```bash
bash "$HOME/.understand-anything/repo/install.sh" --update
```

Restart Codex after installing or updating if newly installed skills are not visible in the current session.

## Expected Local Locations

Common paths:

```text
~/.understand-anything/repo
~/.agents/skills
~/.codex/skills
```

Expected graph output inside an analyzed repository:

```text
.understand-anything/knowledge-graph.json
```

## Useful Commands After Setup

These are agent/CLI slash commands, not shell commands:

```text
/understand
/understand --language zh
/understand-dashboard
/understand-chat <question>
/understand-diff
/understand-explain <path>
/understand-domain
/understand-onboard
/understand-knowledge <target>
```

Use only commands exposed by the installed upstream version. If a command is unavailable, inspect the installed upstream skills or README and choose the closest supported workflow.

## Troubleshooting

| Symptom | Check |
|---|---|
| GitHub clone/download fails | Retry later, check proxy/VPN, or ask the user for a local clone/archive. |
| Install script uses a different source repo | Set `UA_REPO_URL` to the user-requested URL and rerun. |
| Commands are installed but not visible | Restart Codex/agent session, then re-check skill roots. |
| Graph generation is slow | Narrow the target path and exclude generated/dependency folders. |
| Graph file exists but answers seem stale | Refresh with `/understand` and compare `LastWriteTime`. |
| Dashboard cannot open | Confirm graph file exists; if Browser tools are unavailable, report the graph path and use chat/JSON inspection. |

## Security Notes

Remote install scripts execute code on the user's machine. Only run installers from the source the user requested or from an official upstream URL you can cite. Knowledge graph output can include internal architecture and file metadata, so review before committing or uploading it.
