# Stop Slop MVP

A tiny runnable demo inspired by `hardikpandya/stop-slop`.

The upstream project is a Skill package, not a standalone app. Its core experience is a style pass that removes generic AI phrasing, weak intensifiers, buzzwords, and over-polished structure. This MVP turns that idea into a local browser tool for Chinese and English drafts.

## Run

```powershell
npm.cmd test
npm.cmd start
```

Then open `http://localhost:5174`.

If PowerShell allows npm scripts on your machine, `npm test` and `npm start` work too. If port `5174` is busy, run a direct static server on another port:

```powershell
python -m http.server 5180
```

## What It Does

- Detects common AI-flavored phrases in Chinese and English.
- Applies deterministic rewrite rules with no API key and no external service.
- Shows a naturalness score, detected issues, and rule hits.
- Includes sample drafts for quick demonstration.

## Scope

This is intentionally small: it is a 2-4 hour MVP, not a full editor or LLM-backed rewriting assistant. The next useful step would be adding an optional OpenAI-powered rewrite mode while keeping this rule-based mode as the transparent baseline.
