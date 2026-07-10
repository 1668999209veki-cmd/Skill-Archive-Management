---
name: materials-to-office
description: Use when a user wants to turn raw source materials, notes, files, research, meeting records, screenshots, or mixed资料 into polished spreadsheets, tables, Word-style documents, reports, briefings, slide decks, PPTs, or executive summaries. Use this skill whenever the user says 把资料整理成表格, 生成文档, 做汇报, 做PPT, 做Excel, 转成表格, 转成报告, 输出Word, or asks for a deliverable from unstructured content, even if they do not name a file format.
---

# Materials To Office

## Purpose

Turn messy source materials into useful office deliverables: structured tables, spreadsheets, documents, reports, and presentations.

This skill is a coordinator. It helps decide what the user is really trying to produce, then routes to the most appropriate document, spreadsheet, or presentation workflow available in the current environment.

Upstream reference and optional install source: `https://github.com/anthropics/skills.git`

## Trigger Signals

Use this skill when the user provides or mentions:

- Raw notes, research, meeting minutes, chat logs, survey responses, screenshots, PDFs, web pages, CSVs, spreadsheets, or copied text.
- A request to make a table, Excel workbook, Word document, report, briefing, proposal, summary, PPT, deck, or presentation.
- Chinese intent such as `资料变表格`, `资料变文档`, `资料变汇报`, `整理成表格`, `做成PPT`, `生成汇报`, `输出Excel`, `输出Word`, or `转成报告`.

## First Decision

Identify the primary deliverable before transforming content.

| User goal | Route |
|---|---|
| Rows, metrics, comparisons, trackers, inventories, budgets, analysis tables | Spreadsheet/table workflow |
| Narrative, policy, memo, proposal, report, SOP, contract-style draft | Document/report workflow |
| Briefing, stakeholder update, classroom/training material, pitch, visual story | Presentation workflow |
| User asks for multiple outputs | Produce a shared source outline first, then generate each artifact from that outline |
| User is unclear | Provide the most useful default and state the assumption briefly |

When the user's requested output is ambiguous, default to a concise table in chat plus an offerable file artifact if the environment supports file creation.

## Intake Checklist

Before creating the final artifact, extract:

1. Audience: who will read or watch this?
2. Purpose: decision, status update, analysis, training, archive, sales, or reporting?
3. Source quality: complete, partial, contradictory, or noisy?
4. Required format: chat table, `.xlsx`, `.docx`, `.pptx`, Markdown, PDF, or another target.
5. Tone and depth: executive, operational, academic, client-facing, technical, or casual.
6. Constraints: language, branding, deadline, page/slide count, columns, formulas, citations, or confidentiality.

Ask a clarifying question only when the missing answer changes the artifact materially. Otherwise make a reasonable assumption and name it.

## Transformation Workflow

1. **Inventory the source material.** List the input types and note missing, duplicated, or unreliable parts.
2. **Extract atomic facts.** Break the material into rows, claims, dates, metrics, decisions, owners, actions, quotes, or evidence.
3. **Choose the structure.** Select a table schema, document outline, or slide storyline before writing the final artifact.
4. **Normalize and deduplicate.** Standardize names, dates, units, currencies, and categories. Preserve uncertainty instead of inventing facts.
5. **Create the deliverable.** Use the environment's spreadsheet, document, or presentation capabilities when a file is requested.
6. **Quality-check the output.** Verify that the final artifact matches the source, uses the requested language, and does not hide unresolved assumptions.

## Spreadsheet/Table Output

For tables and spreadsheets:

- Use explicit column names that match the user's goal, not just the source wording.
- Keep one fact per cell and one record per row.
- Add derived fields only when they help analysis, such as category, priority, status, owner, due date, confidence, or source.
- Preserve traceability with a `Source` or `Notes` column when the original material is messy or disputed.
- For `.xlsx` files, include a clean data sheet and, when useful, a summary sheet with pivots, charts, formulas, or key metrics.

Good default columns for mixed notes:

| Item | Category | Summary | Owner | Date | Status | Priority | Evidence/Source | Notes |
|---|---|---|---|---|---|---|---|---|

## Document/Report Output

For documents and reports:

- Start from an outline before drafting.
- Put the answer first for executive readers, then supporting detail.
- Use headings that describe decisions, findings, or sections clearly.
- Separate verified facts, interpretations, recommendations, and open questions.
- Include citations or source references when the user needs auditability.

Good default report structure:

```markdown
# [Title]

## Executive Summary
## Key Findings
## Details
## Recommendations
## Risks And Open Questions
## Appendix Or Source Notes
```

## Presentation/Briefing Output

For presentations and briefings:

- Build a storyline, not a document chopped into slides.
- Keep each slide focused on one message.
- Prefer charts, tables, timelines, comparison matrices, process diagrams, and decision pages over dense paragraphs.
- Use speaker notes for nuance that should not crowd the slide.
- Make slide titles action-oriented when possible.

Good default deck structure:

```markdown
1. Title / Topic
2. Context
3. Key Insight Or Problem
4. Evidence
5. Options Or Plan
6. Recommendation
7. Next Steps
8. Appendix
```

## Multi-Artifact Pattern

When the user asks for table + document + presentation:

1. Create a single canonical source outline first.
2. Generate the spreadsheet from the structured facts.
3. Generate the report from the outline and findings.
4. Generate the presentation from the story and key visuals.
5. Cross-check names, dates, numbers, and recommendations across all artifacts.

This avoids the common failure where each artifact tells a slightly different story.

## Installing Upstream Anthropic Skills

If the user specifically asks to install the upstream Anthropic office skills into Codex, use the skill installer with these paths:

```powershell
python "$env:USERPROFILE\.codex\skills\.system\skill-installer\scripts\install-skill-from-github.py" --repo anthropics/skills --path skills/xlsx skills/docx skills/pptx
```

For environments using the upstream `skills` CLI, the source also supports commands like:

```powershell
npx skills add https://github.com/anthropics/skills --skill xlsx
npx skills add https://github.com/anthropics/skills --skill docx
npx skills add https://github.com/anthropics/skills --skill pptx
```

Do not copy upstream skill contents into this local coordinator skill. Install upstream skills directly and respect their license terms.

If network access or GitHub authentication fails, explain the exact failure and keep this local coordinator skill usable with the built-in document, spreadsheet, and presentation tools.

After installing new skills into `~/.codex/skills`, tell the user to restart Codex so the new skills are picked up.

## Completion Criteria

Before returning the final answer:

- Confirm which source materials were used.
- State the output location or include the generated table/content directly.
- Mention any assumptions, missing fields, or unverifiable claims.
- For file artifacts, verify the file opens or validates when the environment provides a reasonable check.
