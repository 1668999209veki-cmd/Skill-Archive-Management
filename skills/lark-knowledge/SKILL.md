---
name: lark-knowledge
description: Use when a user needs Codex to work with Lark, Feishu, lark-cli, 飞书, 云文档, 云盘, Wiki, or 知识库 resources: reading document URLs/tokens, inspecting Drive/Wiki links, managing knowledge spaces or nodes, organizing knowledge bases, or installing/authenticating the official Lark CLI.
---

# Lark Knowledge

## Overview

Use this skill as the entry point for Lark/Feishu document reading and knowledge-base management. Prefer the official `lark-cli` and its bundled skills instead of ad hoc web scraping or manually guessing token formats.

This skill coordinates setup, authentication, URL inspection, and routing. When the official `larksuite/cli` skills are installed, read the relevant skill progressively rather than copying its full command reference into context.

## Before Any Lark Operation

1. Check whether `lark-cli` is available:

   ```bash
   lark-cli --version
   ```

2. If it is missing, install from npm:

   ```bash
   npx @larksuite/cli@latest install
   ```

   Source install is also supported from `https://github.com/larksuite/cli.git`:

   ```bash
   git clone https://github.com/larksuite/cli.git
   cd cli
   make install
   npx skills add larksuite/cli -y -g
   ```

3. Check authentication:

   ```bash
   lark-cli auth status
   ```

4. If official Lark skills are available locally, read `lark-shared/SKILL.md` before running domain commands. It contains the current authentication, identity, permission, QR-code, and high-risk write rules.

## Authentication Pattern

Use user identity by default for personal resources such as docs, Drive, Wiki, mail, and calendar. Use bot identity only when the user explicitly wants app/bot-owned resources or an app-level operation.

For agent-assisted login, prefer split flow so the user can actually see the verification URL:

```bash
lark-cli auth login --recommend --no-wait --json
```

When the output contains a verification URL:

1. Treat the URL as an opaque string. Do not edit, encode, decode, shorten, or recompose it.
2. Generate a QR code in the current working directory:

   ```bash
   lark-cli auth qrcode "<verification_url>" --output "lark-auth.png"
   ```

3. Show the URL and QR code to the user, then stop and ask them to come back after authorization.
4. After the user confirms completion, finish the flow yourself:

   ```bash
   lark-cli auth login --device-code <device_code>
   ```

For permission errors, distinguish identity:

| Identity | Handling |
|---|---|
| `--as user` | Run scoped login such as `lark-cli auth login --scope "<missing_scope>" --no-wait --json` or `--domain <domain>` |
| `--as bot` | Do not run `auth login`; send the developer-console URL and missing scopes to the user |

## Routing

Use the smallest correct domain skill or command family.

| User intent or input | First step | Then route to |
|---|---|---|
| Read, summarize, quote, or inspect a `/docx/`, `/doc/`, or document token | `lark-cli docs +fetch --api-version v2 --doc "<url-or-token>"` | `lark-doc` |
| User gives a `/wiki/` URL but asks for content | `lark-cli drive +inspect --url "<wiki_url>" --format json` | `lark-doc` for doc content, `lark-sheets`/`lark-base` for embedded data |
| User asks what a Lark URL/token is | `lark-cli drive +inspect --url "<url-or-token>" --format json` | Continue based on returned `type` |
| Search documents, Wiki, sheets, Base, folders, or "my recent docs" | `lark-cli drive +search --query "<query>"` | `lark-drive` |
| Manage Wiki spaces, nodes, member lists, node move/copy/delete | `lark-cli wiki +node-get --node-token "<url-or-token>" --format json --as user` when a target is given | `lark-wiki` |
| Organize or restructure a knowledge base, Drive folder, or personal document library | Load the official knowledge organization workflow from `lark-drive` if available | `lark-drive` workflow |
| Upload, download, import, preview, comments, permissions, versions | Use Drive shortcuts | `lark-drive` |
| Native Drive `.md` file create/fetch/patch/diff | Use Markdown shortcuts | `lark-markdown` |
| Spreadsheet cell/table data | Inspect first if needed | `lark-sheets` |
| Base / bitable records, fields, views, dashboards | Inspect first if needed | `lark-base` |

## Command Patterns

Inspect a URL or token before guessing type:

```bash
lark-cli drive +inspect --url "https://xxx.feishu.cn/wiki/wikcnXXX" --format json
lark-cli drive +inspect --url "doxcnXXX" --type docx --format json
```

Read a document. Use local scopes when the user asks for a specific section or keyword:

```bash
lark-cli docs +fetch --api-version v2 --doc "<url-or-token>" --format json
lark-cli docs +fetch --api-version v2 --doc "<url-or-token>" --scope outline --max-depth 3 --format json
lark-cli docs +fetch --api-version v2 --doc "<url-or-token>" --scope keyword --keyword "部署|发布|上线" --format json
```

Search resources. For list/statistics requests without a real keyword, keep `--query ""` and use filters:

```bash
lark-cli drive +search --query "季度总结" --format json
lark-cli drive +search --query "" --mine --edited-since 30d --doc-types docx --format json
```

Get Wiki node details:

```bash
lark-cli wiki +node-get --node-token "<wiki-url-or-token>" --format json --as user
```

## Knowledge-Base Management

For "整理知识库 / 盘点云盘 / 重构文档库 / 找出未归档和重复内容" style requests:

1. Parse and confirm the target scope first: Drive folder, Wiki space, Wiki node, personal document library, or search scope.
2. Inventory resources with paginated listing or search. Keep complete internal state even if the user-facing table is paginated.
3. Read content only when metadata is not enough to classify a resource.
4. Produce a plan with target structure and move/create operations before any write.
5. Ask the user to confirm exactly what to execute.
6. Execute only the confirmed scope, then verify by re-listing the target.

Default to a reviewable plan. Do not delete, rename, transfer ownership, change public permissions, or batch-request permissions as part of organization unless the user asks for that specific operation and confirms the risk.

## Safety Rules

- Never print app secrets, access tokens, or raw credentials.
- Do not modify URLs returned by `lark-cli`; pass them through exactly.
- Prefer `--as user` for personal Drive/Wiki/doc resources unless the user explicitly asks for bot/app identity.
- Do not use web fetch as a fallback for Lark/Feishu URLs when `lark-cli` can inspect or read them.
- For write operations, show the target resource and action before executing when intent is ambiguous.
- For destructive or bulk writes, require explicit confirmation. If `lark-cli` returns confirmation-required exit code `10`, present the risk action and original parameters to the user; retry with `--yes` only after the user explicitly agrees.
- If a Wiki URL resolves to a Sheet or Base, do not pretend `docs +fetch` contains the inner data. Route to `lark-sheets` or `lark-base`.

## Common Mistakes

| Mistake | Better action |
|---|---|
| Treating `/wiki/<token>` as the document token | Run `drive +inspect` or `wiki +node-get` first |
| Reading an entire long document when the user asks about one section | Fetch outline or keyword scope first |
| Searching with `"all documents"` as the query | Use `--query ""` plus filters |
| Using bot identity for the user's personal document library | Use `--as user` |
| Moving or deleting Wiki nodes while still "planning" | Stop and ask for execution confirmation |
| Handling embedded Sheets/Base as plain doc text | Extract token/type and route to the specific skill |

## Useful Official Source

The official CLI and bundled skills are maintained at `https://github.com/larksuite/cli.git`.
