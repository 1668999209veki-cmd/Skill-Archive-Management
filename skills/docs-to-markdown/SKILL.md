---
name: docs-to-markdown
description: Use when a user wants to convert documents, PDFs, Office files, Word/Excel/PowerPoint, HTML, CSV/JSON/XML, ZIP, EPUB, images, audio, or URLs into Markdown/MD using Microsoft MarkItDown. Use this skill for requests like "convert this docx/pdf/xlsx/pptx to md", "extract this Office file for LLM context", "turn these files into readable Markdown", "把文档转Markdown", "Office转MD", "PDF转md", or any batch document-to-markdown workflow, even if the user does not explicitly name MarkItDown.
---

# Docs To Markdown

## Purpose

Convert documents and Office-style files into Markdown for LLM context, knowledge bases, search indexes, source-controlled notes, and downstream text analysis.

Prefer Microsoft MarkItDown for this job because it is built to preserve useful document structure such as headings, lists, tables, and links as Markdown. Do not promise pixel-perfect layout fidelity; this workflow is for readable structured text, not visual reproduction.

Upstream install source: `https://github.com/microsoft/markitdown.git`

## When To Use

Use this skill when the input is one or more files or URLs and the desired output is Markdown or plain structured text, especially:

- PDF files.
- Word files such as `.docx` and, when supported by the environment, legacy `.doc`.
- Excel files such as `.xlsx` and `.xls`.
- PowerPoint files such as `.pptx`.
- HTML, CSV, JSON, XML, TXT, ZIP, EPUB, Outlook messages, images, audio, YouTube URLs, or mixed folders of these sources.
- Chinese requests such as `把文档转Markdown`, `转成md`, `Office转Markdown`, `PDF转md`, `Word转Markdown`, `Excel转Markdown`, or `PPT转Markdown`.

If the user asks for a polished Word/PDF/PPT artifact, OCR cleanup, translation, summarization, or rewriting after conversion, first convert faithfully, then perform the requested downstream work as a separate step.

## Install MarkItDown

Check whether MarkItDown is already available before installing:

```powershell
python -c "import markitdown; print('markitdown ok')"
markitdown --version
```

If it is missing, prefer a virtual environment in the current project or working folder:

```powershell
python -m venv .venv
.\.venv\Scripts\python -m pip install --upgrade pip
.\.venv\Scripts\python -m pip install "markitdown[all]"
```

When the user specifically asks to install from the Microsoft GitHub source, use the provided repository:

```powershell
git clone https://github.com/microsoft/markitdown.git
Set-Location markitdown
python -m pip install -e "packages/markitdown[all]"
```

If cloning is inconvenient and pip supports direct VCS installs in the current environment, this form can also be used:

```powershell
python -m pip install "markitdown[all] @ git+https://github.com/microsoft/markitdown.git#subdirectory=packages/markitdown"
```

Use narrower extras when the user only needs a few formats, for example:

```powershell
python -m pip install "markitdown[pdf,docx,pptx,xlsx]"
```

## Conversion Workflow

1. Inventory the inputs. Resolve exact paths, identify file types, and decide whether this is a single-file or batch conversion.
2. Choose output locations. For one file, default to the same folder with the same stem and `.md`. For batches, create or use a requested output folder and preserve relative paths.
3. Convert with MarkItDown. Use the CLI for simple one-off conversions and the bundled script for repeatable or batch work.
4. Verify the Markdown. Confirm the output file exists, is non-empty, and contains expected headings, tables, sheet names, slide text, or page text.
5. Report results. Return the output paths, note any files that failed, and mention important caveats such as scanned pages, missing OCR, formulas converted as displayed values, or layout loss.

## Simple CLI Commands

Single file:

```powershell
markitdown "C:\path\input.docx" -o "C:\path\input.md"
```

Pipe to a Markdown file:

```powershell
markitdown "C:\path\report.pdf" > "C:\path\report.md"
```

Enable installed MarkItDown plugins:

```powershell
markitdown --use-plugins "C:\path\document.pdf" -o "C:\path\document.md"
```

Use Azure Document Intelligence when the user supplies an endpoint and accepts cloud processing:

```powershell
markitdown "C:\path\scan.pdf" -o "C:\path\scan.md" -d -e "<document_intelligence_endpoint>"
```

## Bundled Batch Script

For deterministic conversion from a skill invocation, prefer:

```powershell
python "<skill-dir>\scripts\convert_markitdown.py" "C:\path\input.docx" -o "C:\path\input.md"
```

Convert every supported file in a folder:

```powershell
python "<skill-dir>\scripts\convert_markitdown.py" "C:\path\source-folder" --recursive --output-dir "C:\path\markdown-output"
```

Use plugins or Azure Document Intelligence through the script only when needed:

```powershell
python "<skill-dir>\scripts\convert_markitdown.py" "C:\path\scan.pdf" -o "C:\path\scan.md" --docintel-endpoint "<endpoint>"
python "<skill-dir>\scripts\convert_markitdown.py" "C:\path\deck.pptx" -o "C:\path\deck.md" --use-plugins
```

The script refuses to overwrite existing Markdown unless `--overwrite` is passed. This keeps accidental reruns from destroying earlier conversions.

## Quality Checks

After conversion, inspect the Markdown rather than assuming success:

```powershell
Get-Item "C:\path\output.md"
Get-Content "C:\path\output.md" -TotalCount 80
Select-String -Path "C:\path\output.md" -Pattern "expected heading|expected term"
```

For Excel and PowerPoint, check for sheet names, slide titles, table headers, and critical numeric values. For PDFs, check page headings and key sections. For Word documents, check heading hierarchy, lists, tables, and links.

## Common Caveats

- MarkItDown output is optimized for text analysis and LLM consumption. It may not preserve exact visual layout, fonts, pagination, comments, tracked changes, or complex drawing elements.
- Scanned PDFs and image-heavy Office files may need OCR or cloud document intelligence. Do not silently use paid cloud services; ask or state the assumption first.
- Macros, embedded files, charts, formulas, and SmartArt may be summarized imperfectly or omitted depending on the converter.
- Legacy Office files can fail if the needed optional dependency is unavailable. Convert legacy `.doc`, `.ppt`, or unusual formats to modern Office formats with LibreOffice or Microsoft Office first when MarkItDown cannot read them.
- For untrusted inputs in hosted/server-side contexts, restrict file paths and URLs before calling MarkItDown. MarkItDown performs I/O with the privileges of the current process.

## Completion Criteria

Before responding to the user:

- State which input files or folders were converted.
- Provide absolute output paths to the generated `.md` files.
- Mention failed files with the exact error when any conversion fails.
- Say what verification was performed, such as non-empty output and spot checks for expected headings/tables/text.
- If dependency installation was required, state whether it was installed in a virtual environment, user environment, or project environment.
