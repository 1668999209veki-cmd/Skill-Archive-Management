---
name: code-knowledge-graph
description: Use when a user asks Codex to turn source code, repositories, architecture, dependencies, modules, files, or code changes into a knowledge graph; to generate or inspect `.understand-anything/knowledge-graph.json`; to install or use Understand-Anything; to open the Understand-Anything dashboard/chat/diff/domain/onboarding workflows; or when the user says code-to-graph, code graph, repo map, architecture graph, code relationship map, or code knowledge graph.
---

# Code Knowledge Graph

## Purpose

Use Understand-Anything as the preferred workflow for turning a codebase into a queryable knowledge graph, then use that graph for architecture understanding, onboarding, change impact, dependency exploration, and repo Q&A.

Upstream source and install reference: `https://github.com/Egonex-AI/Understand-Anything.git`. For setup details, read `references/understand-anything-setup.md`.

## First Decision

| Situation | Action |
|---|---|
| The user explicitly asks for Understand-Anything or gives its GitHub repo | Check setup first, then install or refresh from the requested repo. |
| The user asks to convert code/repo/architecture into a knowledge graph | Use `/understand` or the installed upstream Understand-Anything skill/command surface. |
| A graph already exists at `.understand-anything/knowledge-graph.json` | Reuse it for chat, dashboard, diff, or targeted analysis before regenerating. |
| The user wants to explore the graph visually | Use `/understand-dashboard` after confirming the graph exists. |
| The user asks questions about code relationships or module purpose | Use `/understand-chat` when available; otherwise read the graph JSON and relevant files directly. |
| The user asks what changed or what may break after edits | Use `/understand-diff` when available and compare against git state. |
| The repo is huge, generated-heavy, or secret-heavy | Narrow the target path and review ignores before generating the graph. |

## Setup Check

1. Check for an installed Understand-Anything skill or plugin under common Codex/agent skill roots:

   ```powershell
   Get-ChildItem "$env:USERPROFILE\.agents\skills","$env:USERPROFILE\.codex\skills" -ErrorAction SilentlyContinue |
     Where-Object { $_.Name -match 'understand|knowledge|graph' }
   ```

2. Check for an upstream working copy:

   ```powershell
   Test-Path "$env:USERPROFILE\.understand-anything\repo"
   ```

3. If setup is missing, read `references/understand-anything-setup.md` and install from the user-specified upstream source.
4. After installing or refreshing skills in `~/.agents/skills` or `~/.codex/skills`, tell the user to restart Codex if the new commands are not visible in the current session.

## Code Graph Workflow

1. Confirm the target root:

   ```powershell
   git rev-parse --show-toplevel
   git status --short
   ```

   If the user points at a subdirectory or package, keep the graph scoped to that path instead of analyzing the whole monorepo.

2. Review likely exclusions before graph generation. Respect `.gitignore` and avoid dependency, build, cache, vendored, binary, generated, and secret-heavy directories unless the user explicitly needs them.

3. Generate or refresh the graph with the upstream command surface. In environments where slash commands are available, the usual entry point is:

   ```text
   /understand
   ```

   For Chinese-facing output, prefer the upstream language option when it is available:

   ```text
   /understand --language zh
   ```

   Do not paste slash commands into a shell prompt. Use them only in an agent/CLI context that supports them. If this Codex session exposes installed Understand-Anything skills instead of slash commands, read those upstream skill files and follow their exact workflow.

4. Verify the graph file exists:

   ```powershell
   Test-Path ".understand-anything\knowledge-graph.json"
   Get-Item ".understand-anything\knowledge-graph.json" | Select-Object FullName, Length, LastWriteTime
   ```

5. Use the graph for the user's real goal:

   | Goal | Preferred action |
   |---|---|
   | Visual exploration | `/understand-dashboard` |
   | Natural-language questions | `/understand-chat <question>` |
   | Explain one file | `/understand-explain <path>` |
   | Change impact | `/understand-diff` plus `git diff --stat` |
   | Domain/business concepts | `/understand-domain` |
   | Onboarding guide | `/understand-onboard` |
   | Knowledge-base style export | `/understand-knowledge <target>` when upstream supports it |

6. When slash commands are unavailable, inspect `.understand-anything/knowledge-graph.json` with structured JSON tools, then read only the code files needed to answer the user's question.

## Output And Sharing

When the user asks for the graph result, report:

- The graph file path: `.understand-anything/knowledge-graph.json`.
- The repo/path analyzed.
- Whether the graph was generated, refreshed, or reused.
- Any notable exclusions or warnings.
- The next useful command, such as dashboard, chat, diff, or onboarding.

If the user wants to share the graph with a team, inspect `.understand-anything/README.md` or upstream guidance first. In general, commit human-useful graph/config artifacts only after checking for sensitive paths or summaries. Keep temporary overlays, caches, and noisy generated artifacts out of git.

## Safety Rules

- Treat knowledge graphs as potentially sensitive because they can expose filenames, architecture, internal concepts, and code summaries.
- Do not publish, commit, or upload `.understand-anything` artifacts without checking whether the repo contains secrets, private customer data, or proprietary implementation details.
- Do not run remote install scripts from a URL that differs from the user's requested source unless you explain the discrepancy and get confirmation.
- Ask before enabling persistent hooks, automatic regeneration, or background watchers that modify repo files.
- Prefer source-controlled ignores and explicit target paths over broad whole-disk scans.

## Common Mistakes

| Mistake | Better action |
|---|---|
| Running `/understand` from PowerShell | Use slash commands only in the agent/CLI command interface, not the shell. |
| Regenerating a large repo graph without checking scope | Reuse the existing graph or target a package/subdirectory first. |
| Treating the graph as public documentation | Review sensitive names, summaries, and paths before sharing. |
| Answering architecture questions from memory | Query or inspect the graph first, then open the relevant files. |
| Ignoring dirty git state before diff analysis | Run `git status --short` and connect graph results to actual changed files. |

## Completion Criteria

Before returning the final answer:

- State whether Understand-Anything was installed, refreshed, already present, or unavailable.
- State whether `.understand-anything/knowledge-graph.json` exists and where.
- Summarize the key graph-backed finding or provide the dashboard/chat/diff next step requested by the user.
- Mention any setup, network, command-surface, or sensitivity caveat that affects the result.
