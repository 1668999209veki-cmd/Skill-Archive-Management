---
name: web-automation
description: Use when a user needs Codex to automate webpages or logged-in browser workflows with OpenCLI, including webpage navigation, form filling, clicking, extraction, browser state inspection, screenshots, network capture, Chrome profile setup, or installing OpenCLI from jackwener/OpenCLI.git.
---

# Web Automation

## Overview

Use OpenCLI when Codex needs to operate a real Chrome or Chromium page through a CLI, especially for logged-in sessions, existing tabs, forms, UI workflows, and ad-hoc webpage extraction. Keep the workflow selector-first: inspect the page, act on stable targets, verify important writes, and refresh state after transitions.

Upstream source and install reference: `https://github.com/jackwener/OpenCLI.git`. For setup details, read `references/opencli-setup.md`.

## First Decision

| Situation | Action |
|---|---|
| The user explicitly asks for OpenCLI or gives the OpenCLI repo | Use this skill and check OpenCLI setup first. |
| The task needs the user's logged-in Chrome state or an already-open tab | Use `opencli browser <session> bind` or an owned OpenCLI browser session. |
| A built-in OpenCLI site adapter covers the task | Prefer `opencli <site> <command>` before raw browser driving. |
| The task is local app testing and built-in Browser/Playwright tools are available | Prefer those local testing tools unless the user asks for OpenCLI. |
| The goal is only to read a public page | Prefer normal web/HTTP reading unless interaction, auth, or dynamic page state is needed. |
| The user wants a reusable command for a site | Install/use upstream `opencli-adapter-author`; do not solve it only with ad-hoc browser clicks. |

## Setup Check

1. Check the CLI:

   ```powershell
   opencli --version
   opencli doctor
   ```

2. If `opencli` is missing or `doctor` is not green, read `references/opencli-setup.md` and fix setup before continuing.
3. If multiple Chrome profiles are connected, list and select one:

   ```powershell
   opencli profile list
   opencli profile use <alias-or-contextId>
   ```

4. If the upstream OpenCLI skills are not installed and the user wants agent-native browser automation, install or refresh the relevant upstream skill:

   ```powershell
   npx skills add jackwener/opencli --skill opencli-browser
   ```

## Browser Workflow

1. Choose a short, stable session name for the task.
2. Open a URL or bind the current tab:

   ```powershell
   opencli browser <session> open "https://example.com"
   opencli browser <session> bind
   ```

3. Inspect before every meaningful action:

   ```powershell
   opencli browser <session> state
   opencli browser <session> find --role button --name "Submit"
   ```

4. Prefer numeric refs returned by `state` or `find`. Use CSS only when a ref is unavailable or a compact query is clearer.
5. Interact with structured commands:

   ```powershell
   opencli browser <session> click <ref>
   opencli browser <session> fill <ref> "value"
   opencli browser <session> type <ref> "value"
   opencli browser <session> select <ref> "Option label"
   opencli browser <session> keys Enter
   ```

6. Verify important writes:

   ```powershell
   opencli browser <session> get value <ref>
   opencli browser <session> get text <ref>
   ```

7. After navigation, form submission, SPA route changes, or login redirects, wait and then take a fresh state snapshot:

   ```powershell
   opencli browser <session> wait selector "[data-testid=account-menu]" --timeout 15000
   opencli browser <session> state
   ```

8. Extract with the smallest reliable surface:

   | Need | Prefer |
   |---|---|
   | Page structure and refs | `state` or `find` |
   | One field or label | `get text`, `get value`, `get attributes` |
   | Long article content | `extract --chunk-size <n>` |
   | API-backed list/table data | `network`, then `network --detail <key>` |
   | Visual layout, chart, icon-only controls | `screenshot --annotate` |

9. Release the session when done:

   ```powershell
   opencli browser <session> close
   opencli browser <session> unbind
   ```

## Safety Rules

- Do not print cookies, bearer tokens, passwords, one-time codes, or private page data unless the user explicitly requested that exact data.
- Ask before purchases, payments, account deletion, permission changes, sending messages, publishing content, or submitting forms with legal or financial consequences.
- When the user is watching or needs control, use a foreground window or bind their current tab instead of silently creating a background flow.
- Treat `match_level: reidentified` as a warning. Re-check with `state`, `get text`, or `get value` before chaining more writes.
- Do not mutate pages with JavaScript `eval`; use `click`, `fill`, `type`, `select`, `check`, `uncheck`, `keys`, or `upload` so OpenCLI can return structured results.

## Common Mistakes

| Mistake | Better action |
|---|---|
| Running clicks from memory | Run `state` or `find` first and use returned refs. |
| Reusing refs after navigation | Wait for the new page, then run `state` again. |
| Scraping rendered DOM when data comes from JSON | Use `network` and inspect the API response shape. |
| Typing into autocomplete and assuming it committed | Follow with `get value`; press `Enter` or click a suggestion if needed. |
| Using screenshots for ordinary text pages | Use `state`, `find`, `get`, `extract`, or `network`; screenshots are for visual ambiguity. |
| Treating setup failures as page bugs | Run `opencli doctor` and fix Browser Bridge or profile issues first. |

## Useful References

- `references/opencli-setup.md` - install, browser extension, profile selection, environment variables, exit codes, and troubleshooting.
- Upstream browser skill: `https://github.com/jackwener/OpenCLI/blob/main/skills/opencli-browser/SKILL.md`.
