# Lark Knowledge Skill Design

## Goal

Create a Codex skill that helps agents work with Lark/Feishu documents and knowledge bases through the official `lark-cli`.

The skill should be an entry point, not a replacement for the official Lark skills. It should help the agent install and verify the CLI, authenticate safely, inspect URLs and tokens, and route the user request to the correct official Lark domain skill or command family.

## Scope

The skill covers:

- Installing `lark-cli` from npm or from `https://github.com/larksuite/cli.git`.
- Verifying `lark-cli` availability and authentication state.
- Reading Lark/Feishu document content from `/docx/`, `/doc/`, and `/wiki/` URLs or tokens.
- Managing knowledge bases, Wiki spaces, Wiki nodes, and Wiki members.
- Searching Drive/Wiki resources before reading or organizing them.
- Routing embedded Sheets/Base resources to their own skills.
- Handling risky write operations with explicit user confirmation.

The skill does not duplicate full command references from `larksuite/cli`. It points the agent to `lark-shared`, `lark-doc`, `lark-drive`, `lark-wiki`, `lark-sheets`, and `lark-base` when those official skills are installed.

## Architecture

`lark-knowledge/SKILL.md` contains:

- Trigger-focused frontmatter.
- A quick setup workflow for `lark-cli`.
- Authentication and permission handling rules.
- A routing table for document, wiki, drive, sheet, base, markdown, upload/download, and organization tasks.
- Command examples for inspect, search, fetch, and wiki node lookup.
- Safety rules for destructive or bulk write operations.

`lark-knowledge/evals/evals.json` contains a few realistic prompts that can be used later to test triggering and routing behavior.

## Data Flow

1. User gives a Lark/Feishu task, URL, token, or knowledge-base request.
2. Agent checks whether `lark-cli` is available and authenticated.
3. If the input is a URL/token, agent uses `drive +inspect` or `wiki +node-get` to resolve resource type and canonical token.
4. Agent routes content reads to `docs +fetch --api-version v2`, knowledge-base structure work to `wiki`, and resource discovery/import/download/comment/permission work to `drive`.
5. For bulk organization, the agent produces an auditable plan first and executes only after explicit confirmation.

## Error Handling

- Missing CLI: install with `npx @larksuite/cli@latest install` or source install from `https://github.com/larksuite/cli.git`.
- Missing auth: start a scoped or recommended login flow and return the verification URL and QR code to the user.
- Permission errors: follow identity-specific handling. Bot scope errors go to the developer console; user scope errors use `auth login --scope` or `--domain`.
- Unknown URL/token type: inspect first instead of guessing.
- High-risk writes: show the action and target, wait for explicit confirmation, then retry with the CLI confirmation flag if needed.

## Testing

The initial tests are lightweight prompt scenarios rather than full subagent benchmarks:

- Read and summarize a Lark document URL.
- Inspect and reorganize a messy knowledge base without executing writes before confirmation.
- Install and authenticate `lark-cli` for a user who has not configured it yet.

These tests focus on the skill's main value: correct routing, safe setup, and confirmation discipline.
