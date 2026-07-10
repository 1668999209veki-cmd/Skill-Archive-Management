---
name: wx-cli
description: Use wx-cli to install, initialize, search, inspect, and export local WeChat desktop data. Trigger when the user asks to query WeChat messages/history/chat records, sessions, contacts, group members, group nicknames, favorites, Moments, official account articles, attachments/images, unread/new messages, statistics, or chat exports.
---

# wx-cli

## Overview

Use `wx` to turn the user's own local WeChat desktop data into a searchable, exportable source for Codex. The CLI decrypts local databases on the machine, caches them through a daemon, and supports sessions, history, search, contacts, groups, favorites, Moments, official account articles, attachments, statistics, and exports.

## Safety

- Work only with the user's own local WeChat data. If a request implies unauthorized access to another person's account, credentials, device, or decrypted data, refuse or ask for authorization context.
- Keep private data local. Prefer saving exports to local files and summarizing only the relevant parts in chat.
- Use the narrowest useful query: add chat names, date ranges, message types, and limits before broad searches.
- Before broad exports or large dumps, confirm scope and destination if the user did not provide them.
- Do not run remote installer scripts such as `irm ... | iex` or `curl ... | bash` unless the user explicitly wants that install path. Prefer package managers or official releases.

## Setup

Check whether `wx` is already available:

```powershell
Get-Command wx
wx --version
```

If missing, install with npm when Node.js is available:

```powershell
npm install -g @jackwener/wx-cli
```

Other official install paths include GitHub releases and platform installer scripts from `https://github.com/jackwener/wx-cli`; use them only when appropriate for the user's platform and consent.

Keep WeChat desktop running and logged in before initialization. Initialize once, from an elevated shell where the platform requires it:

```powershell
wx init
```

On macOS or Linux, use `sudo wx init`. macOS may require WeChat ad-hoc signing and TCC permission reset after WeChat updates; if initialization fails there, consult the upstream README and rerun initialization after WeChat is fully restarted.

Verify that the daemon can read recent sessions:

```powershell
wx sessions --json
```

## Query Workflow

For agent-readable output, add `--json`. For quick human inspection, default YAML is fine.

1. Start narrow when possible:

```powershell
wx search "keyword" --in "chat name" --since 2026-01-01 -n 100 --json
wx history "chat name" --since 2026-01-01 --until 2026-01-31 -n 500 --json
```

2. If the chat name is unknown, inspect sessions or search globally first:

```powershell
wx sessions --json
wx search "keyword" -n 50 --json
```

3. Always check `meta.status` in JSON wrappers for `sessions`, `history`, `search`, `new-messages`, `stats`, and `attachments`.

If `meta.status` is `possibly_stale_unknown_shards`, run:

```powershell
wx init --force
```

If `meta.status` is `possibly_stale`, tell the user the result may omit newer messages and rerun initialization if freshness matters. If `meta.status` is `windowed`, treat the result as a scoped view, not a complete conversation.

## Common Commands

Messages:

```powershell
wx sessions
wx unread
wx unread --filter private,group
wx new-messages --json
wx history "chat name" -n 200 --json
wx history "chat name" --since 2026-04-01 --until 2026-04-15 --json
wx search "keyword" --json
wx search "keyword" --in "chat name" --since 2026-01-01 -n 500 --json
```

People and groups:

```powershell
wx contacts --json
wx contacts --query "name" --json
wx members "group name" --json
```

Use `display` for group members when presenting names. Use `sender_username`, `sender_contact_display`, and `sender_group_nickname` to distinguish same-nickname group members when those fields are present.

Favorites, Moments, official account articles, and stats:

```powershell
wx favorites --json
wx favorites --query "keyword" --json
wx sns-notifications --include-read -n 100 --json
wx sns-feed --since 2026-04-01 -n 100 --json
wx sns-search "keyword" --json
wx biz-articles --account "account name" --json
wx stats "chat name" --since 2026-01-01 --json
```

Attachments and image extraction:

```powershell
wx attachments "chat name" --kind image -n 100 --json
wx extract <attachment_id> -o "C:\path\to\photo.jpg"
```

Export:

```powershell
wx export "chat name" --format markdown -o "C:\path\to\chat.md"
wx export "chat name" --since 2026-01-01 --format json -o "C:\path\to\chat.json"
wx export "chat name" -n 2000 --format markdown -o "C:\path\to\chat.md"
```

Use Markdown for human-readable archives and JSON for downstream parsing. Avoid printing full exports into the response; provide the file path and a short summary.

## Troubleshooting

- If `wx` is not found after npm install, reopen the shell or inspect the npm global bin path.
- If initialization cannot read WeChat memory, ensure WeChat is running and the shell has administrator or `sudo` permissions.
- If results miss recent messages, run `wx init --force` and retry.
- If daemon state looks wrong, inspect or restart it:

```powershell
wx daemon status
wx daemon stop
wx daemon logs --follow
```

- Remember local coverage limits: wx-cli can only access data present in the local desktop WeChat cache. Moments and media that were never loaded locally cannot be recovered by querying.
