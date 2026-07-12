# Agency Agents Dashboard Bundle Design

## Goal

Represent the installed `msitarzewski/agency-agents` package as one searchable dashboard card instead of 254 individual Agent cards. Treat the bundle as one installation for XiaoV fullness rewards.

## Detection

- Add a repository-owned manifest containing the 254 expected Codex Agent TOML basenames from the installed Agency release.
- Scan the configured Codex Agents directory, defaulting to `~/.codex/agents` and allowing an environment-variable override for tests and portable setups.
- Intersect installed TOML basenames with the manifest. Do not count unrelated custom Agents such as `explorer.toml`, `reviewer.toml`, or `docs-researcher.toml`.
- Omit the bundle card when no manifest entries are installed.

## Dashboard Record

Generate one record with these properties:

- Name: `agency-agents`
- Category: the dashboard's Chinese label for `Agent bundle`
- Source: the dashboard's Chinese label for `Codex Agents installed`
- Link: `https://github.com/msitarzewski/agency-agents`
- Description: report the detected Agent count and explain that this is a Codex custom-Agent collection.
- Search terms: bundle name plus every detected Agent basename, so a search such as `frontend-developer` finds the bundle card.
- Updated time: newest modification time among matched Agent TOML files.
- Installed state: true when at least one manifest entry is present.

The existing card layout, sorting controls, category filter, and source display remain unchanged. The bundle participates in name, date, category, and history-count sorting like a Skill record.

## Invocation History

Historical invocation counting remains bundle-level. Session references to `agency-agents` count toward the bundle; individual Agent invocations are search metadata and do not create separate cards or inflate the bundle invocation count.

## XiaoV Reward

The bundle card participates in the existing installed-item snapshot. Its stable identity is `agency-agents`. When it first appears compared with the browser's previous localStorage snapshot, XiaoV gains 5 fullness points, subject to the existing fullness cap. All 254 Agents count as one installation.

## Tests

Add a PowerShell generator integration test using temporary Skill and Agent roots. The test must verify:

- Agency TOML files produce exactly one `agency-agents` card.
- The card reports only matched manifest entries and excludes unrelated TOML files.
- Individual Agent basenames are searchable through the bundle card.
- The card is installed and contains the GitHub source link.
- No bundle card is emitted when no Agency manifest entries are installed.
- Existing archive guarantees remain intact: at least one card in the real archive, sort buttons `count`, `date`, `name`, and `category`, and `data-history-count`.

After generation, perform a browser check that searching `agency-agents` and a representative Agent name both reveal the single bundle card, and that no layout overlap is introduced.

## Scope

This change does not alter or reinstall third-party Agent files, publish resources, add 254 individual cards, or change existing Skill invocation statistics.
