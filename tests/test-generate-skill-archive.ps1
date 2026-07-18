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

function Assert-True {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) { throw $Message }
}

New-Item -ItemType Directory -Force -Path (Join-Path $projectSkills "fixture-skill"), (Join-Path $projectSkills "nested\fixture-skill"), (Join-Path $projectSkills "helper-skill"), $codexSkills, $agentsSkills, $codexAgents | Out-Null
$fixtureSkill = @'
---
name: fixture-skill
description: Fixture skill for archive tests.
requires:
  - helper-skill
recommends: [agency-agents]
inputs:
  - source notes
outputs:
  - archive row
relationshipSource: fixture-frontmatter
confidence: 0.91
---

# Fixture Skill

## Related Skills

- `helper-skill`
'@
Set-Content -LiteralPath (Join-Path $projectSkills "fixture-skill\SKILL.md") -Encoding UTF8 -Value $fixtureSkill
Set-Content -LiteralPath (Join-Path $projectSkills "nested\fixture-skill\SKILL.md") -Encoding UTF8 -Value $fixtureSkill
Set-Content -LiteralPath (Join-Path $projectSkills "helper-skill\SKILL.md") -Encoding UTF8 -Value "---`nname: helper-skill`ndescription: Helper skill for relationship tests.`n---"
Set-Content -LiteralPath (Join-Path $codexAgents "frontend-developer.toml") -Encoding UTF8 -Value 'name = "Frontend Developer"'
Set-Content -LiteralPath (Join-Path $codexAgents "copywriter.toml") -Encoding UTF8 -Value 'name = "Copywriter"'
Set-Content -LiteralPath (Join-Path $codexAgents "explorer.toml") -Encoding UTF8 -Value 'name = "Explorer"'
@{
  bundles = @(@{
    name = "agency-agents"
    description = "Codex custom-Agent collection."
    chineseDescription = "Codex custom-Agent collection."
    link = "https://github.com/msitarzewski/agency-agents"
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
  Assert-True ($html.Contains('id="resourceFilter"')) "Expected resource type filter."
  Assert-True ($html.Contains('id="relationshipData"') -and $html.Contains('relationship-table')) "Expected relationship data and list view."
  Assert-True ($html.Contains('id="taskAdvisorInput"') -and $html.Contains('id="taskAdvisorRun"') -and $html.Contains('id="taskAdvisorOutput"')) "Expected task advisor controls."
  Assert-True ($html.Contains('id="backHomeButton"') -and $html.Contains('back-home-button') -and $html.Contains('height: 56px') -and $html.Contains('window.scrollTo({ top: 0')) "Expected fixed square back-home button."
  Assert-True ($html.Contains('recommendSkillsForTask') -and $html.Contains('buildSkillMatchReport') -and $html.Contains('localSkillMatchesForTask') -and $html.Contains('renderTaskRelationshipSummary')) "Expected task-to-skill recommendation card logic."
  Assert-True ($html.Contains('task-resource-card') -and $html.Contains('renderTaskResourceCards') -and $html.Contains('generateClusterYaml') -and $html.Contains('dynamicDispatchPrompt')) "Expected task recommendation cards and deployment guidance."
  Assert-True ($html.Contains('projectIntegrationInstruction') -and $html.Contains('task-resource-heading-row') -and $html.Contains('integrationButton.addEventListener')) "Expected a project-level copy instruction for recommended Skills."
  Assert-True (-not $html.Contains('reportBlock.className = "task-report"') -and -not $html.Contains('copyReport')) "Expected no long report rendering."
  Assert-True ($html.Contains('inferRunMode') -and $html.Contains('inferProjectStatus') -and $html.Contains('mode: fixed_pipeline')) "Expected run mode and project status judgement."
  Assert-True ($html.Contains('searchGithubCandidate') -and $html.Contains('api.github.com/search/repositories') -and $html.Contains('githubResults')) "Expected direct GitHub repository result lookup."
  Assert-True (-not $html.Contains('candidate.keyword')) "Expected no prompt-style GitHub keyword copy action."
  Assert-True ($html.Contains('githubCandidatesWithResults') -and $html.Contains('candidate.githubStatus === "done"') -and $html.Contains('candidate.githubResults.length')) "Expected Github cards only for completed searches with repository results."
  Assert-True ($html.Contains('intentRefinementSuggestion') -and $html.Contains('developmentOrderSuggestion') -and $html.Contains('recommendationReason') -and $html.Contains('recommendationGroups')) "Expected actionable intent refinement and grouped recommendation rationale."
  Assert-True ($html.Contains('candidateTitleLink') -and $html.Contains('results[0].url')) "Expected the Github candidate Skill title to link to the returned repository."
  Assert-True ($html.Contains('parseTaskCommand') -and $html.Contains('operate_type') -and $html.Contains('target_skill_name') -and $html.Contains('install_skill') -and $html.Contains('normal_recommend')) "Expected structured install command parsing before normal recommendations."
  Assert-True ($html.Contains('"skill"') -and $html.Contains('taskStopTokens')) "Expected standalone skill to be ignored as an intent search token."
  Assert-True ($html.Contains('target_repo_url') -and $html.Contains('extractGithubRepositoryUrl') -and $html.Contains('installSkillFromUrl')) "Expected explicit Github repository URL installation routing."
  Assert-True ($html.Contains('skillArchivePendingInstall') -and $html.Contains('sessionStorage') -and $html.Contains('window.location.reload()')) "Expected successful installation to reload and restore the installed card result."
  $installFlow = [regex]::Match($html, '(?s)async function runSkillInstallFlow\(.*?\n    function restoreInstalledSkillResult').Value
  Assert-True ($installFlow -and $installFlow.Contains('const localMatch = findLocalInstallMatch(command);') -and $installFlow.IndexOf('findLocalInstallMatch(command)', [StringComparison]::Ordinal) -lt $installFlow.IndexOf('installSkillFromUrl(command, requestId)', [StringComparison]::Ordinal)) "Expected URL installation to check the local archive before starting a remote installation job."
  $localInstallMatcher = [regex]::Match($html, '(?s)function findLocalInstallMatch\(command\).*?\n    // STRUCTURED_MATCHER_START').Value
  Assert-True ($localInstallMatcher -and $localInstallMatcher.Contains('const exact = installedCandidates.find') -and -not $localInstallMatcher.Contains('target.includes(name)')) "Expected local install matching to require an exact normalized Skill name."
  Assert-True ($html.Contains('recommendationRelationshipKind') -and $html.Contains('alternative') -and $html.Contains('\u6216\u5173\u7cfb')) "Expected recommendation relationships to distinguish alternatives from ordered dependencies."
  Assert-True ($html.Contains('\u4e0d\u9700\u8981\u5168\u90e8\u4f7f\u7528')) "Expected alternative Skill cards to explain that every recommendation is not required."
  Assert-True ($html.Contains('STRUCTURED_MATCHER_START') -and $html.Contains('parseStructuredIntent') -and $html.Contains('matchStructuredCandidate')) "Expected structured intent matcher implementation."
  Assert-True ($html.Contains('semanticCapabilityCatalog') -and $html.Contains('requestSemanticIntentAnalysis') -and $html.Contains('applySemanticIntentAnalysis')) "Expected model-assisted semantic intent matching with a local fallback."
  Assert-True ($html.Contains('platforms') -and $html.Contains('actions') -and $html.Contains('objects') -and $html.Contains('outputs') -and $html.Contains('constraints')) "Expected five-dimensional intent and capability profiles."
  Assert-True ($html.Contains('gatePassed') -and $html.Contains('matchedPlatforms') -and $html.Contains('matchedActions') -and $html.Contains('confidence')) "Expected hard Gate evidence and confidence."
  Assert-True ($html.Contains('strict_gate') -and $html.Contains('loose_compatible') -and $html.Contains('professionalActions')) "Expected automatic strict and loose matching modes."
  Assert-True ($html.Contains('missing.push') -and $html.Contains('intent.broad')) "Expected broad-intent refinement guidance."
  Assert-True ($html.Contains('data-search-primary') -and $html.Contains('archiveSearchMatches') -and $html.Contains('highlightArchiveCard') -and $html.Contains('clearArchiveHighlights')) "Expected precise archive search and highlighting."
  Assert-True ($html.Contains('match-highlight')) "Expected visible search highlight styling."
  $resourceRenderer = [regex]::Match($html, '(?s)function renderTaskResourceCards\(report\).*?\n    function renderTaskAdvisorOutput').Value
  Assert-True ($resourceRenderer -and -not $resourceRenderer.Contains('createExternalResourceCard')) "Expected local recommendation rendering to remain separate from Github result rendering."
  Assert-True ($html.Contains('githubSearchQueriesForGap') -and $html.Contains('usefulnessScore') -and $html.Contains('evidenceCount') -and $html.Contains('verifyGithubSkillStructure') -and $html.Contains('GitHub Contents API')) "Expected bilingual, decomposed Github search queries with usefulness and repository-structure checks."
  Assert-True ($html.Contains('renderGithubResourceCards') -and $html.Contains('createGithubResourceCard') -and $html.Contains('installGithubSearchResult')) "Expected useful Github results to reuse recommendation-card layout and support installation."
  Assert-True ($html.Contains('task-search-progress') -and $html.Contains('renderTaskSearchProgress') -and $html.Contains('setPetSearchState')) "Expected dynamic search progress and pet status feedback."
  Assert-True ($html.Contains('task-search-audit') -and $html.Contains('githubQueryCount') -and $html.Contains('githubQualifiedCount') -and $html.Contains('await wait(350)')) "Expected a visible Github search audit and observable query stages."
  Assert-True ($html.Contains('installGithubSearchResult') -and $html.Contains('state.status === "completed"') -and $html.Contains('button.disabled = true')) "Expected the current external result to expose installation state."
  Assert-True ($html.Contains('function groupTaskCardsBySubtask') -and $html.Contains('task-resource-group') -and $resourceRenderer.Contains('groupTaskCardsBySubtask')) "Expected local recommendation cards to be grouped by covered subtask."
  Assert-True ($html.Contains('function createTaskResourceCarousel') -and $html.Contains('task-resource-list') -and $html.Contains('grid-template-columns: minmax(0, 1fr)')) "Expected a full-width single-column recommendation list."
  Assert-True ($html.Contains('grid-template-columns: minmax(220px, .85fr) minmax(0, 1.6fr) max-content') -and $html.Contains('.task-resource-card > .task-resource-block')) "Expected wide recommendation cards with aligned horizontal sections."
  $localResourceRenderer = [regex]::Match($html, '(?s)function createLocalResourceCard\(item, report, index, selectedKeys\).*?\n    function createExternalResourceCard').Value
  Assert-True ($localResourceRenderer.Contains('task-resource-description') -and -not $localResourceRenderer.Contains('taskSupportStages(item)') -and -not $localResourceRenderer.Contains('resourceFunctionSummary') -and -not $localResourceRenderer.Contains('taskMissingHints') -and -not $localResourceRenderer.Contains('resourceInstallHint')) "Expected compact local recommendation cards with descriptions instead of match-detail fields."
  Assert-True ($localResourceRenderer.Contains('task-resource-name-link') -and $localResourceRenderer.Contains('github\.com')) "Expected local recommendation names to link to their Github source when available."
  Assert-True ($html.Contains('task-resource-description') -and -not $localResourceRenderer.Contains('taskSupportStages(item)')) "Expected local recommendation cards to show a Skill description instead of support-stage fields."
  Assert-True (-not $localResourceRenderer.Contains('task-resource-score') -and -not $localResourceRenderer.Contains('confidence ')) "Expected confidence to be hidden from local recommendation cards."
  Assert-True ($html.Contains('development-order') -and $html.Contains('development-order-line') -and $html.Contains('multipleIntents') -and $html.Contains('document.createElement("strong")')) "Expected grouped development advice with emphasized Skill names."
  Assert-True ($html.Contains('renderGithubTextResults') -and $html.Contains('github-text-list') -and $html.Contains('filterGithubResultsForIntent')) "Expected ranked Github text-only candidate results."
  Assert-True ($html.Contains('technicalExecutionPhase') -and $html.Contains('firstCoveredSubtaskIndex')) "Expected recommendations to be ordered by technical implementation stage."
  Assert-True ($html.Contains('namedInstallAction') -and $html.Contains('actionRemainder.trim().length > 0')) "Expected bare install wording to remain a normal recommendation while named installs enter the installation workflow."
  Assert-True ($html.Contains('\u5b89\u88c5skill') -and $html.Contains('\u5bfc\u5165skill') -and $html.Contains('\u62c9\u53d6skill') -and $html.Contains('\u4e0b\u8f7dskill') -and $html.Contains('\u6dfb\u52a0skill') -and $html.Contains('\u83b7\u53d6skill') -and $html.Contains('\u5b89\u88c5\u6280\u80fd') -and $html.Contains('\u5bfc\u5165\u6280\u80fd')) "Expected all supported Skill installation triggers."
  Assert-True ($html.Contains('findLocalInstallMatch') -and $html.Contains('renderInstalledArchiveCard') -and $html.Contains('renderInstallProgressCard') -and $html.Contains('pollInstallProgress') -and $html.Contains('runSkillInstallFlow')) "Expected installed Skills to use normal archive cards and pending installs to show progress cards."
  Assert-True ($html.Contains('cloneNode(true)') -and $html.Contains('bindCopyCommand')) "Expected installed Skill results to preserve the normal archive card structure and interactions."
  Assert-True ($html.Contains('install-progress-card') -and $html.Contains('setAttribute("aria-busy"') -and $html.Contains('install-progress-fill') -and $html.Contains('install-elapsed')) "Expected an accessible installation progress card while a Skill is not installed."
  Assert-True ($html.Contains('refreshInstallToken') -and $html.Contains('/install/token') -and $html.Contains('Installer authorization failed')) "Expected expired installer tokens to refresh and retry automatically."
  Assert-True ($html.Contains('requestId !== taskAdvisorRequestId')) "Expected stale installation requests not to overwrite current results."
  Assert-True ($html.Contains('localDayString') -and $html.Contains('dailyPetRecommendations') -and $html.Contains('recommendationDay')) "Expected daily local Skill recommendations for pet."
  Assert-True ($html.Contains('has-task-results')) "Expected task results to disable sticky toolbar while results are shown."
  Assert-True ($html.Contains('data-name="fixture-skill"') -and $html.Contains('data-resource-kind="skill"')) "Expected fixture skill to be typed as skill."
  $fixtureCard = [regex]::Match($html, '(?s)<article[^>]+data-name="fixture-skill".*?</article>').Value
  Assert-True (([regex]::Matches($fixtureCard, '<span class="source">')).Count -eq 1) "Expected duplicate source labels for one source type to render once."
  Assert-True (([regex]::Matches($html, 'data-name="agency-agents"')).Count -eq 1) "Expected one agency-agents card."
  Assert-True ($html.Contains('data-installed="true"')) "Expected an installed bundle card."
  Assert-True ($html.Contains('2 Codex Agents')) "Expected the matched Agent count."
  Assert-True ($html.Contains('frontend-developer') -and $html.Contains('copywriter')) "Expected Agent names in search metadata."
  $bundleCard = [regex]::Match($html, '(?s)<article[^>]+data-name="agency-agents".*?</article>').Value
  Assert-True ($bundleCard.Contains('data-resource-kind="agents"')) "Expected the bundle card to be typed as agents."
  Assert-True (-not $bundleCard.Contains('explorer')) "Unrelated Agents must not enter the bundle card."
  Assert-True ($bundleCard.Contains('https://github.com/msitarzewski/agency-agents')) "Expected the Agency source link."
  $relationshipPath = Join-Path $tempRoot "skill-relationships.json"
  Assert-True (Test-Path -LiteralPath $relationshipPath) "Expected relationship JSON output."
  $relationshipData = Get-Content -LiteralPath $relationshipPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $requiresEdge = @($relationshipData.relationships | Where-Object { $_.source -eq "fixture-skill" -and $_.target -eq "helper-skill" -and $_.type -eq "requires" })
  $mentionsEdge = @($relationshipData.relationships | Where-Object { $_.source -eq "fixture-skill" -and $_.target -eq "helper-skill" -and $_.type -eq "mentions" })
  Assert-True ($requiresEdge.Count -eq 1) "Expected metadata requires relationship."
  Assert-True ($requiresEdge[0].relationshipSource -eq "fixture-frontmatter" -and [string]$requiresEdge[0].confidence -eq "0.91") "Expected relationship source and confidence."
  Assert-True ($mentionsEdge.Count -eq 1) "Expected explicit mention relationship."
  & node (Join-Path $PSScriptRoot "test-structured-intent-matcher.js") $outputPath
  Assert-True ($LASTEXITCODE -eq 0) "Expected structured intent matcher behavior tests to pass."

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
