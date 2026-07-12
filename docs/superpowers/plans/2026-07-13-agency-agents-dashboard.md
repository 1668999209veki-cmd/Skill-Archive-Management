# Agency Agents Dashboard Bundle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one searchable `agency-agents` bundle card to the Skill archive and reward XiaoV 5 fullness points when the bundle first appears.

**Architecture:** A repository-owned JSON manifest identifies Agency TOML basenames. The PowerShell generator intersects that manifest with the configured Codex Agents directory and adds one normal archive record with separate compact invocation triggers and expanded search terms. Existing rendering, sorting, filtering, invocation history, and XiaoV installed-item settlement then work without a second UI path.

**Tech Stack:** PowerShell 5.1, JSON, generated single-file HTML, browser localStorage, Playwright browser verification.

---

## File Structure

- Create `data/agent-bundles/agency-agents.json`: package metadata and canonical Agent TOML basenames.
- Create `tests/test-generate-skill-archive.ps1`: isolated generator integration tests and archive contract assertions.
- Modify `scripts/generate-skill-archive.ps1`: load bundle manifests, scan Codex Agents, create one bundle record, and expose Agent names only through search metadata.
- Regenerate `skill-archive.html`: include the detected local bundle card and updated XiaoV installed snapshot input.

### Task 1: Add the RED generator integration test

**Files:**
- Create: `tests/test-generate-skill-archive.ps1`

- [ ] **Step 1: Write the isolated failing test**

The test creates one fixture Skill, two Agency Agent TOMLs, one unrelated Agent TOML, and a two-entry fixture bundle manifest. It invokes the real generator with environment overrides and asserts exactly one bundle card, a detected count of two, searchable member names, exclusion of `explorer`, an installed state, and the GitHub link. It then removes both matching files and asserts that the bundle card disappears.

```powershell
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$generator = Join-Path $repoRoot "scripts\generate-skill-archive.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("skill-archive-test-" + [guid]::NewGuid().ToString("N"))
$projectSkills = Join-Path $tempRoot "project-skills"
$codexSkills = Join-Path $tempRoot "codex-skills"
$agentsSkills = Join-Path $tempRoot "agents-skills"
$codexAgents = Join-Path $tempRoot "codex-agents"
$manifestPath = Join-Path $tempRoot "agent-bundles.json"
$outputPath = Join-Path $tempRoot "archive.html"

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

New-Item -ItemType Directory -Force -Path (Join-Path $projectSkills "fixture-skill"), $codexSkills, $agentsSkills, $codexAgents | Out-Null
Set-Content -LiteralPath (Join-Path $projectSkills "fixture-skill\SKILL.md") -Encoding UTF8 -Value "---`nname: fixture-skill`ndescription: Fixture skill for archive tests.`n---"
Set-Content -LiteralPath (Join-Path $codexAgents "frontend-developer.toml") -Encoding UTF8 -Value 'name = "Frontend Developer"'
Set-Content -LiteralPath (Join-Path $codexAgents "copywriter.toml") -Encoding UTF8 -Value 'name = "Copywriter"'
Set-Content -LiteralPath (Join-Path $codexAgents "explorer.toml") -Encoding UTF8 -Value 'name = "Explorer"'
@{
  bundles = @(@{
    name = "agency-agents"
    category = "Agent bundle"
    description = "Codex custom-Agent collection."
    chineseDescription = "Codex custom-Agent collection."
    link = "https://github.com/msitarzewski/agency-agents"
    sourceLabel = "Codex Agents installed"
    files = @("frontend-developer.toml", "copywriter.toml")
  })
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$previous = @{}
$overrides = @{
  SKILL_ARCHIVE_PROJECT_SKILLS_DIR = $projectSkills
  SKILL_ARCHIVE_CODEX_SKILLS_DIR = $codexSkills
  SKILL_ARCHIVE_AGENTS_SKILLS_DIR = $agentsSkills
  SKILL_ARCHIVE_CODEX_AGENTS_DIR = $codexAgents
  SKILL_ARCHIVE_AGENT_BUNDLES_FILE = $manifestPath
}

try {
  foreach ($entry in $overrides.GetEnumerator()) {
    $previous[$entry.Key] = [Environment]::GetEnvironmentVariable($entry.Key)
    [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value)
  }

  & $generator -OutputPath $outputPath
  $html = Get-Content -LiteralPath $outputPath -Raw -Encoding UTF8
  Assert-True (([regex]::Matches($html, 'data-name="agency-agents"')).Count -eq 1) "Expected one agency-agents card."
  Assert-True ($html.Contains('data-installed="true"')) "Expected an installed bundle card."
  Assert-True ($html.Contains('2 Codex Agents')) "Expected the matched Agent count."
  Assert-True ($html.Contains('frontend-developer') -and $html.Contains('copywriter')) "Expected Agent names in search metadata."
  $bundleCard = [regex]::Match($html, '(?s)<article[^>]+data-name="agency-agents".*?</article>').Value
  Assert-True (-not $bundleCard.Contains('explorer')) "Unrelated Agents must not enter the bundle card."
  Assert-True ($bundleCard.Contains('https://github.com/msitarzewski/agency-agents')) "Expected the Agency source link."

  Remove-Item -LiteralPath (Join-Path $codexAgents "frontend-developer.toml"), (Join-Path $codexAgents "copywriter.toml")
  & $generator -OutputPath $outputPath
  $html = Get-Content -LiteralPath $outputPath -Raw -Encoding UTF8
  Assert-True (-not $html.Contains('data-name="agency-agents"')) "Bundle card must be omitted when no members are installed."
} finally {
  foreach ($entry in $overrides.GetEnumerator()) {
    [Environment]::SetEnvironmentVariable($entry.Key, $previous[$entry.Key])
  }
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test-generate-skill-archive.ps1
```

Expected: FAIL with `Expected one agency-agents card.` because the generator does not yet scan Codex Agent bundles.

- [ ] **Step 3: Commit the RED checkpoint**

```powershell
git add tests/test-generate-skill-archive.ps1
git commit -m "test: add agency agents bundle reproducer"
```

### Task 2: Add the Agency source manifest and generator support

**Files:**
- Create: `data/agent-bundles/agency-agents.json`
- Modify: `scripts/generate-skill-archive.ps1`
- Test: `tests/test-generate-skill-archive.ps1`

- [ ] **Step 1: Generate the canonical manifest from the verified installation**

Read the Agency source commit from the retained clone and mechanically write the sorted 254 installed basenames, excluding the three pre-existing project roles:

```powershell
$sourceRoot = "$env:LOCALAPPDATA\Temp\agency-agents-scan"
$sourceCommit = git -C $sourceRoot rev-parse HEAD
$files = Get-ChildItem "$env:USERPROFILE\.codex\agents" -Filter *.toml |
  Where-Object Name -notin @("docs-researcher.toml", "explorer.toml", "reviewer.toml") |
  Sort-Object Name |
  ForEach-Object Name
@{
  bundles = @(@{
    name = "agency-agents"
    category = "Agent bundle"
    description = "A collection of Codex custom Agents installed from msitarzewski/agency-agents."
    chineseDescription = "Agency Agents 合集，包含已安装的 Codex 自定义 Agent。"
    link = "https://github.com/msitarzewski/agency-agents"
    sourceLabel = "Codex Agents 已安装"
    sourceCommit = $sourceCommit
    files = $files
  })
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath .\data\agent-bundles\agency-agents.json -Encoding UTF8
```

Verify that `files` contains exactly 254 unique `.toml` basenames.

- [ ] **Step 2: Add bundle configuration and loading**

At generator startup, define:

```powershell
$codexAgentsRoot = Get-ConfiguredPath "SKILL_ARCHIVE_CODEX_AGENTS_DIR" (Join-Path $env:USERPROFILE ".codex\agents")
$agentBundleManifestPath = Get-ConfiguredPath "SKILL_ARCHIVE_AGENT_BUNDLES_FILE" (Join-Path (Split-Path -Parent $PSScriptRoot) "data\agent-bundles\agency-agents.json")
$codexAgentsPublicRoot = @{
  Path = $codexAgentsRoot
  PublicPrefix = "{{CODEX_AGENTS_DIR}}"
  Label = (T "Codex Agents &#x5DF2;&#x5B89;&#x88C5;")
  Rank = 1
}
```

Load JSON with `ConvertFrom-Json`, treating a missing or malformed optional manifest as an empty bundle list with a warning for malformed content.

- [ ] **Step 3: Add one aggregate record per detected bundle**

For each definition, build a case-insensitive set of expected filenames, enumerate only direct `*.toml` children of the Codex Agents directory, and select matches. When matches exist, add one record to `$recordsByName` with:

```powershell
@{
  name = [string]$bundle.name
  description = "$matchedCount Codex Agents detected. $([string]$bundle.description)"
  chineseDescription = "$(T '&#x5DF2;&#x68C0;&#x6D4B;&#x5230;') $matchedCount $(T '&#x4E2A; Codex Agents&#x3002;')$([string]$bundle.chineseDescription)"
  category = (T "Agent &#x5408;&#x96C6;")
  link = [string]$bundle.link
  triggers = @('$' + [string]$bundle.name, [string]$bundle.name)
  searchTerms = @($matches | ForEach-Object { $_.BaseName })
  sources = [System.Collections.Generic.List[object]]@(@{
    label = (T "Codex Agents &#x5DF2;&#x5B89;&#x88C5;")
    path = "{{CODEX_AGENTS_DIR}} ($matchedCount matched)"
    updated = $newest.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
    ticks = $newest.LastWriteTime.Ticks
    rank = 1
    kind = "codex-agent-bundle"
  })
  latestTicks = $newest.LastWriteTime.Ticks
  latest = $newest.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
  preferredRank = 1
}
```

Add `searchTerms = @()` to normal Skill records. Include `searchTerms` in `data-search`, but do not render those names as invocation chips. Treat `codex-agent-bundle` as installed in both `$installedSkillCount` and card `data-installed` calculations.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test-generate-skill-archive.ps1
```

Expected: PASS with exit code 0 and both generated fixture archives reporting one fixture Skill, with the first archive additionally reporting one installed Agent bundle.

- [ ] **Step 5: Commit the GREEN checkpoint**

```powershell
git add data/agent-bundles/agency-agents.json scripts/generate-skill-archive.ps1 tests/test-generate-skill-archive.ps1
git commit -m "feat: add agency agents bundle to dashboard"
```

### Task 3: Regenerate and verify the real dashboard

**Files:**
- Modify: `skill-archive.html`
- Test: `tests/test-generate-skill-archive.ps1`

- [ ] **Step 1: Regenerate the local archive**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-skill-archive.ps1
```

Expected: successful generation with one more archive entry than the Skill-only baseline and a log message that includes the detected Agent bundle.

- [ ] **Step 2: Run static archive contract checks**

Run:

```powershell
$html = Get-Content .\skill-archive.html -Raw -Encoding UTF8
if (([regex]::Matches($html, 'class="[^"]*skill-card')).Count -le 0) { throw "No cards generated" }
foreach ($sort in @("count", "date", "name", "category")) {
  if (-not $html.Contains('data-sort="' + $sort + '"')) { throw "Missing sort: $sort" }
}
if (-not $html.Contains("data-history-count")) { throw "Missing history count" }
if (([regex]::Matches($html, 'data-name="agency-agents"')).Count -ne 1) { throw "Expected one Agency bundle" }
if (-not $html.Contains("frontend-developer")) { throw "Expected member search metadata" }
```

Expected: exit code 0.

- [ ] **Step 3: Verify search behavior in a browser**

Open the generated dashboard, search for `agency-agents`, then `frontend-developer`. For each query, assert that exactly one visible card remains and its `data-name` is `agency-agents`. Capture desktop and mobile screenshots and confirm no card text, controls, or XiaoV UI overlap.

- [ ] **Step 4: Verify XiaoV settlement input**

In a fresh browser storage context, load the prior Skill-only archive once, then load the regenerated archive with the bundle card. Assert that `installedSkillNames` gains exactly `agency-agents` and fullness increases by 5, capped at 30.

- [ ] **Step 5: Review the final diff and commit the generated archive**

```powershell
git diff --check
git diff -- scripts/generate-skill-archive.ps1 tests/test-generate-skill-archive.ps1 data/agent-bundles/agency-agents.json skill-archive.html
git add skill-archive.html
git commit -m "chore: refresh dashboard with agency agents bundle"
```

Expected: only the scoped generator, manifest, test, archive, spec, and plan changes are in task commits; unrelated report and `strix/` changes remain untouched.
