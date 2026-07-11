# OpenCLI Setup Reference

Use this only when OpenCLI is missing, setup fails, or a task needs command details that are not in `SKILL.md`.

## Source

- Repository: `https://github.com/jackwener/OpenCLI.git`
- Package: `@jackwener/opencli`
- Upstream browser skill: `skills/opencli-browser/SKILL.md` in the repository
- Browser Bridge extension: `https://chromewebstore.google.com/detail/opencli/ildkmabpimmkaediidaifkhjpohdnifk`

## Install

OpenCLI requires Node.js 20 or newer.

```powershell
node --version
npm install -g @jackwener/opencli
opencli doctor
```

Install or refresh the upstream OpenCLI skills for an agent:

```powershell
npx skills add jackwener/opencli
npx skills add jackwener/opencli --skill opencli-browser
```

Install only adjacent upstream skills when the task needs them:

```powershell
npx skills add jackwener/opencli --skill opencli-adapter-author
npx skills add jackwener/opencli --skill opencli-browser-sitemap
npx skills add jackwener/opencli --skill opencli-sitemap-author
npx skills add jackwener/opencli --skill opencli-autofix
npx skills add jackwener/opencli --skill opencli-usage
```

## Browser Bridge

OpenCLI talks to Chrome or Chromium through the Browser Bridge extension and a small local daemon. If the Chrome Web Store is unavailable, download the latest `opencli-extension-v*.zip` from the GitHub releases page, unzip it, enable Developer mode in `chrome://extensions`, and load the unzipped folder.

Run this after extension setup:

```powershell
opencli doctor
```

Typical setup failures are Browser Bridge not connected, Chrome not running, old Node.js, blocked debug access, or conflicting extensions.

## Profiles

Each connected Chrome profile has its own Browser Bridge context. With one connected profile OpenCLI can pick it automatically; with several profiles, choose explicitly.

```powershell
opencli profile list
opencli profile rename <contextId> work
opencli profile use work
opencli --profile work browser state
```

You can also set `OPENCLI_PROFILE` for repeat runs.

## Important Commands

| Command | Use |
|---|---|
| `opencli list` | List registered commands and adapters. |
| `opencli doctor` | Diagnose OpenCLI, daemon, extension, and browser connectivity. |
| `opencli <site> <command>` | Run a built-in or generated adapter. |
| `opencli browser <session> open <url>` | Open a URL in a named browser session. |
| `opencli browser <session> bind` | Bind the currently open Chrome tab to a session. |
| `opencli browser <session> state` | Inspect page structure and numeric refs. |
| `opencli browser <session> network` | Inspect captured API/network responses. |
| `opencli browser <session> close` | Release an owned browser session. |

## Environment

| Variable | Purpose |
|---|---|
| `OPENCLI_PROFILE` | Browser Bridge profile alias or context ID. |
| `OPENCLI_WINDOW` | `foreground` or `background` browser placement. |
| `OPENCLI_BROWSER_CONNECT_TIMEOUT` | Browser connection timeout in seconds. |
| `OPENCLI_BROWSER_COMMAND_TIMEOUT` | Per-command timeout in seconds. |
| `OPENCLI_DAEMON_PORT` | Local daemon HTTP port, default `19825`. |
| `OPENCLI_VERBOSE` | Enable verbose output when set to `true`. |
| `DEBUG_SNAPSHOT` | Set to `1` for DOM snapshot debug output. |

## Exit Codes

OpenCLI uses Unix-style exit codes. Important cases:

| Code | Meaning |
|---|---|
| `0` | Success. |
| `66` | Empty result. |
| `69` | Browser Bridge down. |
| `75` | Timeout. |
| `77` | Authentication required. |
| `78` | Configuration error. |
| `130` | Interrupted. |

## Troubleshooting

| Symptom | Check |
|---|---|
| Browser Bridge not connected | Confirm extension is installed and enabled, then run `opencli doctor`. |
| Old Node errors, missing `fetch`, startup crash | Upgrade to Node.js 20 or newer. |
| Attach failure on extension URL | Temporarily disable other extensions that may consume debug access. |
| Empty data or unauthorized response | Re-authenticate in the target Chrome profile, then retry. |
| Several Chrome profiles connected | Use `opencli profile list` and choose with `opencli profile use <alias>`. |
| Daemon uncertainty | Check `curl localhost:19825/status` and `curl localhost:19825/logs`. |
