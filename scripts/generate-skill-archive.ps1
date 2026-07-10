param(
  [string]$OutputPath = (Join-Path (Get-Location) "skill-archive.html")
)

$ErrorActionPreference = "Stop"

function T {
  param([string]$EntityText)
  return [System.Net.WebUtility]::HtmlDecode($EntityText)
}

$roots = @(
  @{ Path = "C:\Users\16689\Documents\skills"; Label = (T "&#x4E2A;&#x4EBA;&#x6574;&#x7406;"); Rank = 0 },
  @{ Path = "C:\Users\16689\.codex\skills"; Label = (T "Codex &#x5DF2;&#x5B89;&#x88C5;"); Rank = 1 },
  @{ Path = "C:\Users\16689\.agents\skills"; Label = (T "Agents &#x5DF2;&#x5B89;&#x88C5;"); Rank = 2 }
)

function ConvertTo-HtmlText {
  param([AllowNull()][string]$Text)
  if ($null -eq $Text) { return "" }
  return [System.Net.WebUtility]::HtmlEncode($Text)
}

function Get-FrontMatterValue {
  param(
    [string]$Content,
    [string]$Key
  )

  $pattern = "(?m)^$([regex]::Escape($Key))\s*:\s*(.+?)\s*$"
  $match = [regex]::Match($Content, $pattern)
  if (-not $match.Success) { return $null }

  $value = $match.Groups[1].Value.Trim()
  if ($value -in @(">", ">-", "|", "|-")) { return $null }
  if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
    $value = $value.Substring(1, $value.Length - 2)
  }
  return $value
}

function Get-FirstHeading {
  param([string]$Content)
  $match = [regex]::Match($Content, "(?m)^#\s+(.+?)\s*$")
  if ($match.Success) { return $match.Groups[1].Value.Trim() }
  return $null
}

function Get-ChineseDescription {
  param(
    [string]$Name,
    [string]$Description,
    [string]$Category
  )

  if ($Description -match "[\u4e00-\u9fff]") {
    $firstChinese = [regex]::Match($Description, "[\u4e00-\u9fff][^.;`n]{8,120}")
    if ($firstChinese.Success) { return $firstChinese.Value.Trim() }
  }

  $categoryText = $Category
  $nameLower = $Name.ToLowerInvariant()

  if ($nameLower -match "^lark-") { return (T "&#x7528;&#x4E8E;&#x98DE;&#x4E66;/Lark &#x76F8;&#x5173;&#x64CD;&#x4F5C;&#xFF0C;&#x8986;&#x76D6;&#x6587;&#x6863;&#x3001;&#x4E91;&#x76D8;&#x3001;&#x65E5;&#x5386;&#x3001;&#x6D88;&#x606F;&#x3001;&#x8868;&#x683C;&#x6216;&#x5BA1;&#x6279;&#x7B49;&#x5DE5;&#x4F5C;&#x6D41;&#x3002;") }
  if ($nameLower -match "^figma-|figma") { return (T "&#x7528;&#x4E8E; Figma &#x8BBE;&#x8BA1;&#x3001;&#x8BBE;&#x8BA1;&#x7CFB;&#x7EDF;&#x3001;&#x7EC4;&#x4EF6;&#x8FDE;&#x63A5;&#x3001;&#x9875;&#x9762;&#x751F;&#x6210;&#x6216;&#x8BBE;&#x8BA1;&#x7A3F;&#x5B9E;&#x73B0;&#x3002;") }
  if ($nameLower -match "design|taste|ui|frontend|web-design|shadcn") { return (T "&#x7528;&#x4E8E;&#x754C;&#x9762;&#x8BBE;&#x8BA1;&#x3001;&#x524D;&#x7AEF;&#x4F53;&#x9A8C;&#x3001;&#x89C6;&#x89C9;&#x5BA1;&#x7F8E;&#x3001;&#x7EC4;&#x4EF6;&#x6837;&#x5F0F;&#x548C;&#x9875;&#x9762;&#x6253;&#x78E8;&#x3002;") }
  if ($nameLower -match "security|compliance|hardening|threat") { return (T "&#x7528;&#x4E8E;&#x5B89;&#x5168;&#x5BA1;&#x67E5;&#x3001;&#x5408;&#x89C4;&#x68C0;&#x67E5;&#x3001;&#x5A01;&#x80C1;&#x5EFA;&#x6A21;&#x3001;&#x6F0F;&#x6D1E;&#x6392;&#x67E5;&#x548C;&#x52A0;&#x56FA;&#x5EFA;&#x8BAE;&#x3002;") }
  if ($nameLower -match "test|tdd|e2e|playwright|verification|eval") { return (T "&#x7528;&#x4E8E;&#x6D4B;&#x8BD5;&#x3001;&#x7AEF;&#x5230;&#x7AEF;&#x9A8C;&#x8BC1;&#x3001;&#x56DE;&#x5F52;&#x68C0;&#x67E5;&#x3001;&#x8D28;&#x91CF;&#x95E8;&#x7981;&#x548C;&#x6D4F;&#x89C8;&#x5668;&#x9A8C;&#x6536;&#x3002;") }
  if ($nameLower -match "deploy|vercel|netlify|cloudflare|render|docker|ci-cd") { return (T "&#x7528;&#x4E8E;&#x90E8;&#x7F72;&#x3001;&#x53D1;&#x5E03;&#x3001;CI/CD&#x3001;&#x5BB9;&#x5668;&#x3001;&#x6258;&#x7BA1;&#x5E73;&#x53F0;&#x548C;&#x4E0A;&#x7EBF;&#x68C0;&#x67E5;&#x3002;") }
  if ($nameLower -match "postgres|mysql|database|supabase|prisma|clickhouse|data") { return (T "&#x7528;&#x4E8E;&#x6570;&#x636E;&#x5E93;&#x3001;&#x6570;&#x636E;&#x7BA1;&#x9053;&#x3001;&#x8FC1;&#x79FB;&#x3001;&#x67E5;&#x8BE2;&#x4F18;&#x5316;&#x548C;&#x6570;&#x636E;&#x5DE5;&#x7A0B;&#x4EFB;&#x52A1;&#x3002;") }
  if ($nameLower -match "agent|workflow|orchestration|context|memory") { return (T "&#x7528;&#x4E8E; Agent &#x5DE5;&#x4F5C;&#x6D41;&#x3001;&#x4E0A;&#x4E0B;&#x6587;&#x7BA1;&#x7406;&#x3001;&#x591A;&#x4EE3;&#x7406;&#x534F;&#x4F5C;&#x548C;&#x81EA;&#x52A8;&#x5316;&#x6267;&#x884C;&#x3002;") }
  if ($nameLower -match "writing|article|content|brand|seo|market|investor") { return (T "&#x7528;&#x4E8E;&#x5185;&#x5BB9;&#x5199;&#x4F5C;&#x3001;&#x54C1;&#x724C;&#x8868;&#x8FBE;&#x3001;&#x5E02;&#x573A;&#x7814;&#x7A76;&#x3001;&#x589E;&#x957F;&#x6750;&#x6599;&#x548C;&#x6295;&#x8D44;&#x4EBA;&#x6750;&#x6599;&#x3002;") }
  if ($nameLower -match "image|video|media|remotion|manim|baoyu|dreamina|fal") { return (T "&#x7528;&#x4E8E;&#x56FE;&#x7247;&#x3001;&#x89C6;&#x9891;&#x3001;&#x5C01;&#x9762;&#x3001;&#x56FE;&#x8868;&#x3001;&#x591A;&#x5A92;&#x4F53;&#x751F;&#x6210;&#x548C;&#x89C6;&#x89C9;&#x8D44;&#x4EA7;&#x5236;&#x4F5C;&#x3002;") }
  if ($nameLower -match "docx|xlsx|pptx|pdf|office|markdown|materials") { return (T "&#x7528;&#x4E8E; Word&#x3001;Excel&#x3001;PPT&#x3001;PDF&#x3001;Markdown &#x548C;&#x529E;&#x516C;&#x6587;&#x6863;&#x5904;&#x7406;&#x3002;") }
  if ($nameLower -match "github|git|gh-") { return (T "&#x7528;&#x4E8E; Git&#x3001;GitHub&#x3001;PR&#x3001;CI &#x4FEE;&#x590D;&#x3001;&#x4EE3;&#x7801;&#x8BC4;&#x5BA1;&#x548C;&#x7248;&#x672C;&#x5DE5;&#x4F5C;&#x6D41;&#x3002;") }
  if ($nameLower -match "performance|latency|cost|benchmark|parallel") { return (T "&#x7528;&#x4E8E;&#x6027;&#x80FD;&#x4F18;&#x5316;&#x3001;&#x5EF6;&#x8FDF;&#x5206;&#x6790;&#x3001;&#x541E;&#x5410;&#x63D0;&#x5347;&#x3001;&#x5E76;&#x884C;&#x5316;&#x548C;&#x6210;&#x672C;&#x63A7;&#x5236;&#x3002;") }
  if ($nameLower -match "research|search|exa|pubmed|uspto|literature|scholar") { return (T "&#x7528;&#x4E8E;&#x8D44;&#x6599;&#x68C0;&#x7D22;&#x3001;&#x6DF1;&#x5EA6;&#x7814;&#x7A76;&#x3001;&#x8BBA;&#x6587;/&#x4E13;&#x5229;&#x67E5;&#x8BE2;&#x548C;&#x6765;&#x6E90;&#x5F52;&#x7EB3;&#x3002;") }
  if ($nameLower -match "network|cisco|bgp|netmiko|homelab") { return (T "&#x7528;&#x4E8E;&#x7F51;&#x7EDC;&#x914D;&#x7F6E;&#x3001;&#x8FDE;&#x901A;&#x6027;&#x6392;&#x67E5;&#x3001;BGP&#x3001;SSH &#x81EA;&#x52A8;&#x5316;&#x548C;&#x5BB6;&#x5EAD;&#x5B9E;&#x9A8C;&#x5BA4;&#x7F51;&#x7EDC;&#x3002;") }
  if ($nameLower -match "swift|ios|foundation-models") { return (T "&#x7528;&#x4E8E; Swift&#x3001;SwiftUI&#x3001;iOS&#x3001;&#x5E76;&#x53D1;&#x3001;&#x534F;&#x8BAE;&#x6D4B;&#x8BD5;&#x548C;&#x672C;&#x5730;&#x6A21;&#x578B;&#x80FD;&#x529B;&#x3002;") }

  return "$(T '&#x7528;&#x4E8E;') $categoryText$(T '&#xFF1A;&#x5904;&#x7406;&#x4E0E;') $Name $(T '&#x76F8;&#x5173;&#x7684;&#x4E13;&#x9879;&#x4EFB;&#x52A1;&#xFF0C;&#x5E76;&#x6309;&#x8BE5; skill &#x7684;&#x6D41;&#x7A0B;&#x5B8C;&#x6210;&#x64CD;&#x4F5C;&#x3002;')"
}
function Get-SkillLink {
  param(
    [string]$Name,
    [string]$Content,
    [string]$SkillPath,
    [hashtable]$SourceIndex
  )

  $sourceKey = $Name.ToLowerInvariant()
  if ($SourceIndex -and $SourceIndex.ContainsKey($sourceKey)) {
    return $SourceIndex[$sourceKey]
  }

  $head = (($Content -split "`n") | Select-Object -First 90) -join "`n"
  $sourceLine = [regex]::Match($head, "(?im)^(?:\s*(?:homepage|repository|repo|source|upstream|upstream source|upstream project|install source|provenance|canonical)\s*:|.*(?:Upstream|Source|homepage|repository|project|canonical):).*(https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_./?=%#~:+-]+)?)")
  if ($sourceLine.Success) {
    return $sourceLine.Groups[1].Value.TrimEnd(".", ",", ")", "]", "`"")
  }

  $escaped = $SkillPath -replace "\\", "/"
  return "file:///$escaped"
}

function Import-SkillSourceIndex {
  $indexPath = Join-Path (Get-Location) "skill-source-index.json"
  $index = @{}
  if (-not (Test-Path -LiteralPath $indexPath)) { return $index }

  try {
    $items = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($property in $items.PSObject.Properties) {
      $index[$property.Name.ToLowerInvariant()] = [string]$property.Value
    }
  } catch {
    Write-Warning "Could not read skill-source-index.json: $($_.Exception.Message)"
  }

  return $index
}

function Get-TriggerPhrases {
  param(
    [string]$Name,
    [string]$Description
  )

  $phrases = New-Object System.Collections.Generic.List[string]
  $phrases.Add("`$$Name")
  $phrases.Add($Name)

  if ($Description) {
    $useWhen = [regex]::Matches($Description, "(?i)use when\s+([^.;]+)")
    foreach ($match in $useWhen) {
      $phrase = $match.Groups[1].Value.Trim()
      if ($phrase.Length -gt 0 -and $phrase.Length -le 100) { $phrases.Add($phrase) }
    }

    $plain = $Description -replace "Use when\s+", "" -replace "MUST USE when\s+", ""
    foreach ($part in ($plain -split "[,;.]")) {
      $clean = $part.Trim()
      if ($clean.Length -ge 4 -and $clean.Length -le 64) { $phrases.Add($clean) }
    }
  }

  foreach ($part in ($Name -split "[-_]+")) {
    if ($part.Length -gt 2) { $phrases.Add($part) }
  }

  return @($phrases | Where-Object { $_ } | Select-Object -Unique | Select-Object -First 8)
}

function Get-Category {
  param(
    [string]$Name,
    [string]$Description
  )

  $nameLower = $Name.ToLowerInvariant()
  $text = (($Name + " " + $Description).ToLowerInvariant())

  $exact = @{
    "docx" = (T "Office / &#x6587;&#x6863;")
    "xlsx" = (T "Office / &#x6587;&#x6863;")
    "pptx" = (T "Office / &#x6587;&#x6863;")
    "pdf" = (T "Office / &#x6587;&#x6863;")
    "imagegen" = (T "&#x56FE;&#x50CF;&#x4E0E;&#x591A;&#x5A92;&#x4F53;")
    "screenshot" = (T "Browser / E2E")
    "speech" = (T "&#x97F3;&#x9891;&#x4E0E;&#x8F6C;&#x5199;")
    "transcribe" = (T "&#x97F3;&#x9891;&#x4E0E;&#x8F6C;&#x5199;")
    "openai-docs" = (T "API &#x4E0E;&#x96C6;&#x6210;")
    "chatgpt-apps" = (T "API &#x4E0E;&#x96C6;&#x6210;")
    "x-api" = (T "API &#x4E0E;&#x96C6;&#x6210;")
    "figma" = (T "&#x8BBE;&#x8BA1; / UI")
    "ai-first-engineering" = (T "Agent &#x5DE5;&#x4F5C;&#x6D41;")
    "blender-motion-state-inspection" = (T "&#x56FE;&#x50CF;&#x4E0E;&#x591A;&#x5A92;&#x4F53;")
    "cli-creator" = (T "API &#x4E0E;&#x96C6;&#x6210;")
    "connections-optimizer" = (T "&#x5185;&#x5BB9;&#x4E0E;&#x589E;&#x957F;")
    "context-engineering" = (T "Codex / Skills")
    "dashboard-builder" = (T "Ops / &#x8FD0;&#x8425;&#x4E0E;&#x89C2;&#x6D4B;")
    "data-scraper-agent" = (T "&#x6570;&#x636E;&#x5E93;&#x4E0E;&#x6570;&#x636E;&#x5DE5;&#x7A0B;")
    "debugging-and-error-recovery" = (T "&#x8D28;&#x91CF; / Review")
    "deprecation-and-migration" = (T "&#x89C4;&#x5212;&#x4E0E;&#x51B3;&#x7B56;")
    "doubt-driven-development" = (T "&#x8D28;&#x91CF; / Review")
    "evm-token-decimals" = "Web3"
    "find-bugs" = (T "&#x8D28;&#x91CF; / Review")
    "gemini-designer" = (T "&#x8BBE;&#x8BA1; / UI")
    "gget" = (T "&#x7814;&#x7A76;&#x4E0E;&#x68C0;&#x7D22;")
    "hatch-pet" = (T "&#x5DE5;&#x5177;&#x4E0E;&#x811A;&#x672C;")
    "hookify-rules" = (T "Codex / Skills")
    "incremental-implementation" = (T "&#x7F16;&#x7A0B;&#x6A21;&#x5F0F;")
    "interview-me" = (T "&#x89C4;&#x5212;&#x4E0E;&#x51B3;&#x7B56;")
    "iterative-retrieval" = (T "&#x7814;&#x7A76;&#x4E0E;&#x68C0;&#x7D22;")
    "jupyter-notebook" = (T "&#x6570;&#x636E;&#x5E93;&#x4E0E;&#x6570;&#x636E;&#x5DE5;&#x7A0B;")
    "nanoclaw-repl" = (T "&#x5DE5;&#x5177;&#x4E0E;&#x811A;&#x672C;")
    "observability-and-instrumentation" = (T "Ops / &#x8FD0;&#x8425;&#x4E0E;&#x89C2;&#x6D4B;")
    "parallel-execution-optimizer" = (T "&#x6027;&#x80FD;&#x4E0E;&#x6210;&#x672C;")
    "plankton-code-quality" = (T "&#x8D28;&#x91CF; / Review")
    "product-capability" = (T "&#x89C4;&#x5212;&#x4E0E;&#x51B3;&#x7B56;")
    "ralphinho-rfc-pipeline" = (T "Agent &#x5DE5;&#x4F5C;&#x6D41;")
    "regex-vs-llm-structured-text" = (T "&#x7F16;&#x7A0B;&#x6A21;&#x5F0F;")
    "search-first" = (T "&#x7814;&#x7A76;&#x4E0E;&#x68C0;&#x7D22;")
    "sentry" = (T "Ops / &#x8FD0;&#x8425;&#x4E0E;&#x89C2;&#x6D4B;")
    "source-driven-development" = (T "&#x7F16;&#x7A0B;&#x6A21;&#x5F0F;")
    "spec-driven-development" = (T "&#x7F16;&#x7A0B;&#x6A21;&#x5F0F;")
    "systematic-debugging" = (T "&#x8D28;&#x91CF; / Review")
    "team-builder" = (T "Agent &#x5DE5;&#x4F5C;&#x6D41;")
    "videodb" = (T "&#x56FE;&#x50CF;&#x4E0E;&#x591A;&#x5A92;&#x4F53;")
    "web-automation" = "Browser / E2E"
    "winui-app" = (T "&#x8BBE;&#x8BA1; / UI")
    "yeet" = (T "&#x5DE5;&#x5177;&#x4E0E;&#x811A;&#x672C;")
    "code-knowledge-graph" = (T "&#x77E5;&#x8BC6;&#x5E93;&#x4E0E;&#x5DE5;&#x4F5C;&#x533A;")
    "code-review-and-quality" = (T "&#x8D28;&#x91CF; / Review")
    "code-tour" = (T "Office / &#x6587;&#x6863;")
    "frontend-ui-engineering" = (T "&#x524D;&#x7AEF; / Web&#x5DE5;&#x7A0B;")
    "shadcn" = (T "&#x524D;&#x7AEF; / Web&#x5DE5;&#x7A0B;")
    "vercel-react-best-practices" = (T "&#x524D;&#x7AEF; / Web&#x5DE5;&#x7A0B;")
    "vercel-react-native-skills" = (T "&#x524D;&#x7AEF; / Web&#x5DE5;&#x7A0B;")
    "vercel-react-view-transitions" = (T "&#x524D;&#x7AEF; / Web&#x5DE5;&#x7A0B;")
    "vercel-composition-patterns" = (T "&#x524D;&#x7AEF; / Web&#x5DE5;&#x7A0B;")
  }
  if ($exact.ContainsKey($nameLower)) { return $exact[$nameLower] }

  $prefixLabels = @(
    @{ Pattern = "^lark-"; Label = (T "Lark / &#x98DE;&#x4E66;") },
    @{ Pattern = "^figma-"; Label = (T "&#x8BBE;&#x8BA1; / UI") },
    @{ Pattern = "^vercel-|^deploy-to-vercel$"; Label = "DevOps / Deploy" },
    @{ Pattern = "^agent-|^agentic-|^subagent-|^team-agent-|^enterprise-agent-|^continuous-agent-|^autonomous-|^claude-devfleet$|^dispatching-parallel-agents$|^dynamic-workflow-mode$"; Label = (T "Agent &#x5DE5;&#x4F5C;&#x6D41;") },
    @{ Pattern = "^security-|.*-security$|.*-compliance$|^hipaa-|^defi-amm-security$|^llm-trading-agent-security$|^django-security$|^laravel-security$|^perl-security$|^quarkus-security$|^springboot-security$"; Label = (T "&#x5B89;&#x5168;&#x4E0E;&#x5408;&#x89C4;") },
    @{ Pattern = "^notion-|^google-workspace-|^knowledge-|^workspace-"; Label = (T "&#x77E5;&#x8BC6;&#x5E93;&#x4E0E;&#x5DE5;&#x4F5C;&#x533A;") },
    @{ Pattern = "^ito-|^prediction-market-"; Label = (T "&#x5E02;&#x573A;&#x4E0E;&#x4EA4;&#x6613;&#x7814;&#x7A76;") },
    @{ Pattern = "^github-|^gh-|^git-|^finishing-a-development-branch$|^receiving-code-review$|^requesting-code-review$"; Label = "Git / GitHub" },
    @{ Pattern = "^playwright|^browser-|^opencli-browser$|^e2e-testing$|^windows-desktop-e2e$|^triage-frontend-issues$"; Label = "Browser / E2E" },
    @{ Pattern = "^web-design-|^design-taste-|^taste-skill$|^liquid-glass-|^huashu-|^guizang-|^gemini-designer$"; Label = (T "&#x8BBE;&#x8BA1; / UI") },
    @{ Pattern = "^frontend-|^ui-|^react-|^composition-patterns$"; Label = (T "&#x524D;&#x7AEF; / Web&#x5DE5;&#x7A0B;") },
    @{ Pattern = "^tdd-|^test-|^verification-|^eval-|^ai-regression-|^benchmark-"; Label = (T "&#x6D4B;&#x8BD5;&#x4E0E;&#x9A8C;&#x8BC1;") },
    @{ Pattern = "^database-|^postgres-|^mysql-|^prisma-|^supabase|^clickhouse-|^data-throughput-"; Label = (T "&#x6570;&#x636E;&#x5E93;&#x4E0E;&#x6570;&#x636E;&#x5DE5;&#x7A0B;") },
    @{ Pattern = "^docker-|^ci-cd-|^cloudflare-|^netlify-|^render-|^deploy|^deployment-|^shipping-"; Label = "DevOps / Deploy" },
    @{ Pattern = "^api-|^openai-|^plugin-|^jira-|^linear$|^x-api$|^crosspost$"; Label = (T "API &#x4E0E;&#x96C6;&#x6210;") },
    @{ Pattern = "^content-|^article-|^writing-|^brand-|^humanizer$|^seo$|^investor-|^market-research$|^lead-intelligence$|^social-"; Label = (T "&#x5185;&#x5BB9;&#x4E0E;&#x589E;&#x957F;") },
    @{ Pattern = "^research-|^deep-research$|^exa-search$|^last30days$|^scientific-|^pubmed-|^uspto-|^scholar-|^literature-"; Label = (T "&#x7814;&#x7A76;&#x4E0E;&#x68C0;&#x7D22;") },
    @{ Pattern = "^video-|^remotion-|^manim-|^moneyprinterturbo-|^dreamina-|^fal-|^baoyu-|^web-shader-"; Label = (T "&#x56FE;&#x50CF;&#x4E0E;&#x591A;&#x5A92;&#x4F53;") },
    @{ Pattern = "^network-|^cisco-|^netmiko-|^homelab-"; Label = (T "&#x7F51;&#x7EDC;&#x4E0E;&#x57FA;&#x7840;&#x8BBE;&#x65BD;") },
    @{ Pattern = "^performance-|^latency-|^cost-|^token-budget-|^ecc-tools-cost-"; Label = (T "&#x6027;&#x80FD;&#x4E0E;&#x6210;&#x672C;") },
    @{ Pattern = "^swift|^foundation-models-on-device$"; Label = "Swift / iOS" },
    @{ Pattern = "^aspnet-|^jpa-|^nodejs-|^error-handling$|^code-simplification$|^api-and-interface-design$"; Label = (T "&#x7F16;&#x7A0B;&#x6A21;&#x5F0F;") },
    @{ Pattern = "^documentation-|^docs-to-markdown$|^materials-to-office$|^nutrient-|^visa-doc-translate$"; Label = (T "Office / &#x6587;&#x6863;") },
    @{ Pattern = "^wx-|^lark-knowledge$"; Label = (T "&#x672C;&#x5730;&#x6570;&#x636E;&#x4E0E;&#x804A;&#x5929;") },
    @{ Pattern = "^email-|^messages-|^unified-notifications-|^customer-billing-|^finance-billing-|^automation-audit-|^production-|^project-flow-|^quality-|^returns-|^inventory-|^logistics-|^carrier-|^customs-|^energy-|^terminal-"; Label = (T "Ops / &#x8FD0;&#x8425;&#x4E0E;&#x89C2;&#x6D4B;") },
    @{ Pattern = "^skill-|^using-|^configure-ecc$|^migrate-to-codex$|^continuous-learning"; Label = (T "Codex / Skills") },
    @{ Pattern = "^blueprint$|^brainstorming$|^define-goal$|^idea-refine$|^planning-|^executing-plans$|^strategic-compact$|^prompt-optimizer$|^council$|^recursive-"; Label = (T "&#x89C4;&#x5212;&#x4E0E;&#x51B3;&#x7B56;") }
  )

  foreach ($entry in $prefixLabels) {
    if ($nameLower -match $entry.Pattern) { return $entry.Label }
  }

  if ($nameLower -match "-ops$") { return (T "Ops / &#x8FD0;&#x8425;&#x4E0E;&#x89C2;&#x6D4B;") }
  if ($nameLower -match "-patterns$|patterns$") { return (T "&#x7F16;&#x7A0B;&#x6A21;&#x5F0F;") }
  if ($nameLower -match "-review$|review") { return (T "&#x8D28;&#x91CF; / Review") }
  if ($nameLower -match "-audit$|audit") { return (T "&#x8D28;&#x91CF; / Review") }
  if ($nameLower -match "-workflow|workflow") { return (T "Agent &#x5DE5;&#x4F5C;&#x6D41;") }
  if ($text -match "lark|feishu|&#x98de;&#x4e66;") { return (T "Lark / &#x98DE;&#x4E66;") }
  return (T "&#x901A;&#x7528;&#x5DE5;&#x5177;")
}

function Merge-Category {
  param([string]$Category)

  $designFrontend = T "&#x8BBE;&#x8BA1;&#x4E0E;&#x524D;&#x7AEF;"
  $engineering = T "&#x5DE5;&#x7A0B;&#x5F00;&#x53D1;"
  $testQuality = T "&#x6D4B;&#x8BD5;&#x4E0E;&#x8D28;&#x91CF;"
  $dataKnowledge = T "&#x6570;&#x636E;&#x4E0E;&#x77E5;&#x8BC6;"
  $contentResearch = T "&#x5185;&#x5BB9;&#x4E0E;&#x7814;&#x7A76;"
  $documents = T "&#x6587;&#x6863;&#x4E0E;&#x529E;&#x516C;"
  $media = T "&#x591A;&#x5A92;&#x4F53;&#x521B;&#x4F5C;"
  $opsInfra = T "&#x8FD0;&#x7EF4;&#x4E0E;&#x57FA;&#x7840;&#x8BBE;&#x65BD;"

  $map = @{
    (T "&#x8BBE;&#x8BA1; / UI") = $designFrontend
    (T "&#x524D;&#x7AEF; / Web&#x5DE5;&#x7A0B;") = $designFrontend
    "Vercel / React" = $designFrontend

    (T "API &#x4E0E;&#x96C6;&#x6210;") = $engineering
    "Git / GitHub" = $engineering
    (T "&#x7F16;&#x7A0B;&#x6A21;&#x5F0F;") = $engineering
    (T "&#x5DE5;&#x5177;&#x4E0E;&#x811A;&#x672C;") = $engineering
    "Swift / iOS" = $engineering
    "Web3" = $engineering
    (T "&#x901A;&#x7528;&#x5DE5;&#x5177;") = $engineering
    "AI API / Docs" = $engineering

    "Browser / E2E" = $testQuality
    (T "&#x6D4B;&#x8BD5;&#x4E0E;&#x9A8C;&#x8BC1;") = $testQuality
    (T "&#x8D28;&#x91CF; / Review") = $testQuality
    "Debug / Review" = $testQuality
    (T "Review / &#x5BA1;&#x67E5;") = $testQuality

    (T "&#x6570;&#x636E;&#x5E93;&#x4E0E;&#x6570;&#x636E;&#x5DE5;&#x7A0B;") = $dataKnowledge
    (T "&#x77E5;&#x8BC6;&#x5E93;&#x4E0E;&#x5DE5;&#x4F5C;&#x533A;") = $dataKnowledge
    (T "&#x672C;&#x5730;&#x6570;&#x636E;&#x4E0E;&#x804A;&#x5929;") = $dataKnowledge

    (T "&#x5185;&#x5BB9;&#x4E0E;&#x589E;&#x957F;") = $contentResearch
    (T "&#x7814;&#x7A76;&#x4E0E;&#x68C0;&#x7D22;") = $contentResearch
    (T "&#x5E02;&#x573A;&#x4E0E;&#x4EA4;&#x6613;&#x7814;&#x7A76;") = $contentResearch

    (T "Office / &#x6587;&#x6863;") = $documents

    (T "&#x56FE;&#x50CF;&#x4E0E;&#x591A;&#x5A92;&#x4F53;") = $media
    (T "&#x97F3;&#x9891;&#x4E0E;&#x8F6C;&#x5199;") = $media

    "DevOps / Deploy" = $opsInfra
    (T "Ops / &#x8FD0;&#x8425;&#x4E0E;&#x89C2;&#x6D4B;") = $opsInfra
    (T "Ops / &#x4E1A;&#x52A1;&#x6D41;&#x7A0B;") = $opsInfra
    (T "Ops / &#x89C2;&#x6D4B;") = $opsInfra
    (T "&#x7F51;&#x7EDC;&#x4E0E;&#x57FA;&#x7840;&#x8BBE;&#x65BD;") = $opsInfra
    (T "&#x6027;&#x80FD;&#x4E0E;&#x6210;&#x672C;") = $opsInfra
  }

  if ($map.ContainsKey($Category)) {
    return $map[$Category]
  }

  return $Category
}

function Get-HistoricalSkillCounts {
  param([string[]]$Names)

  $counts = @{}
  foreach ($name in $Names) { $counts[$name] = 0 }

  $sessionsRoot = Join-Path $env:USERPROFILE ".codex\sessions"
  if (-not (Test-Path -LiteralPath $sessionsRoot)) { return $counts }

  $sessionFiles = Get-ChildItem -LiteralPath $sessionsRoot -Recurse -Filter "*.jsonl" -File -Force -ErrorAction SilentlyContinue

  foreach ($file in $sessionFiles) {
    $seenInSession = @{}

    Get-Content -LiteralPath $file.FullName -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
      try {
        $item = $_ | ConvertFrom-Json
      } catch {
        return
      }

      if ($item.type -ne "response_item") { return }
      if ($item.payload.type -ne "message") { return }
      if ($item.payload.role -ne "assistant") { return }

      $text = ""
      if ($item.payload.content -is [array]) {
        $text = ($item.payload.content | ForEach-Object { $_.text }) -join "`n"
      } elseif ($item.payload.content.text) {
        $text = $item.payload.content.text
      }
      if (-not $text) { return }

      foreach ($name in $Names) {
        $escaped = [regex]::Escape($name)
        $backtickedName = [regex]::Escape('`' + $name + '`')
        $mentioned = $text -match $backtickedName -or $text -match "(?i)(^|[^A-Za-z0-9_-])$escaped([^A-Za-z0-9_-]|$)"
        if (-not $mentioned) { continue }

        $looksLikeInvocation =
          $text -match $backtickedName -or
          $text -match "(?i)(using|use|skill|skills|Reading this as).{0,160}$escaped" -or
          $text -match "(?i)$escaped.{0,160}(using|use|skill|skills)"

        if ($looksLikeInvocation) {
          $seenInSession[$name] = $true
        }
      }
    }

    foreach ($name in $seenInSession.Keys) {
      $counts[$name] = [int]$counts[$name] + 1
    }
  }

  return $counts
}

$recordsByName = @{}
$sourceIndex = Import-SkillSourceIndex

foreach ($root in $roots) {
  if (-not (Test-Path -LiteralPath $root.Path)) { continue }

  Get-ChildItem -LiteralPath $root.Path -Recurse -Filter "SKILL.md" -Force | ForEach-Object {
    if ($_.FullName -match '(?i)[\\/][^\\/]+\.backup-[^\\/]+[\\/]SKILL\.md$') { return }

    $content = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
    $name = Get-FrontMatterValue -Content $content -Key "name"
    if (-not $name) { $name = Split-Path -Leaf $_.DirectoryName }

    $description = Get-FrontMatterValue -Content $content -Key "description"
    if (-not $description) { $description = Get-FirstHeading -Content $content }
    if (-not $description) { $description = T "&#x672A;&#x5728; SKILL.md &#x4E2D;&#x5199;&#x660E;&#x529F;&#x80FD;&#x4ECB;&#x7ECD;&#x3002;" }

    $key = $name.ToLowerInvariant()
    $sourceKind = if ($root.Rank -eq 0) {
      "personal"
    } elseif ($root.Rank -eq 2) {
      "agents"
    } elseif ($_.FullName.StartsWith("C:\Users\16689\.codex\skills\.system", [System.StringComparison]::OrdinalIgnoreCase)) {
      "system"
    } else {
      "codex"
    }
    $sourceLabel = if ($sourceKind -eq "system") { T "System &#x5DF2;&#x5B89;&#x88C5;" } else { $root.Label }
    $source = @{
      label = $sourceLabel
      path = $_.FullName
      updated = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
      ticks = $_.LastWriteTime.Ticks
      rank = $root.Rank
      kind = $sourceKind
    }

    if (-not $recordsByName.ContainsKey($key)) {
      $category = Merge-Category -Category (Get-Category -Name $name -Description $description)
      $recordsByName[$key] = @{
        name = $name
        description = $description
        chineseDescription = Get-ChineseDescription -Name $name -Description $description -Category $category
        category = $category
        link = Get-SkillLink -Name $name -Content $content -SkillPath $_.FullName -SourceIndex $sourceIndex
        triggers = Get-TriggerPhrases -Name $name -Description $description
        sources = New-Object System.Collections.Generic.List[object]
        latestTicks = $_.LastWriteTime.Ticks
        latest = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        preferredRank = $root.Rank
      }
    }

    $record = $recordsByName[$key]
    $record.sources.Add($source)
    if ($_.LastWriteTime.Ticks -gt $record.latestTicks) {
      $record.latestTicks = $_.LastWriteTime.Ticks
      $record.latest = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
    }
    if ($root.Rank -lt $record.preferredRank) {
      $category = Merge-Category -Category (Get-Category -Name $name -Description $description)
      $record.description = $description
      $record.chineseDescription = Get-ChineseDescription -Name $name -Description $description -Category $category
      $record.category = $category
      $record.link = Get-SkillLink -Name $name -Content $content -SkillPath $_.FullName -SourceIndex $sourceIndex
      $record.triggers = Get-TriggerPhrases -Name $name -Description $description
      $record.preferredRank = $root.Rank
    }
  }
}

$records = @($recordsByName.Values | Sort-Object @{ Expression = "latestTicks"; Descending = $true }, "name")
$lastUpdatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$archiveEntryCount = $records.Count
$installedSkillCount = @($records | Where-Object {
  $sourceKinds = @($_.sources | ForEach-Object { $_.kind })
  $sourceKinds -contains "codex" -or $sourceKinds -contains "agents"
}).Count
$personalSkillCount = @($records | Where-Object {
  @($_.sources | ForEach-Object { $_.kind }) -contains "personal"
}).Count
$systemSkillCount = @($records | Where-Object {
  $sourceKinds = @($_.sources | ForEach-Object { $_.kind })
  ($sourceKinds -contains "system") -and -not ($sourceKinds -contains "codex") -and -not ($sourceKinds -contains "agents") -and -not ($sourceKinds -contains "personal")
}).Count
$historicalCounts = Get-HistoricalSkillCounts -Names @($records | ForEach-Object { $_["name"] })
$updateReportPath = Join-Path (Get-Location) "skill-update-report.json"
$updateBySkill = @{}
$pendingSkillNames = New-Object System.Collections.Generic.HashSet[string]
$lastUpdateCheck = ""
if (Test-Path -LiteralPath $updateReportPath) {
  try {
    $updateReport = Get-Content -LiteralPath $updateReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $lastUpdateCheck = [string]$updateReport.checkedAt
    foreach ($result in @($updateReport.results)) {
      foreach ($skill in @($result.skills)) {
        $skillKey = ([string]$skill).ToLowerInvariant()
        $updateBySkill[$skillKey] = [ordered]@{
          status = [string]$result.status
          repo = [string]$result.repo
          url = [string]$result.url
          remotePushedAt = [string]$result.remotePushedAt
          message = [string]$result.message
        }
        if ($result.status -eq "update_available") {
          [void]$pendingSkillNames.Add($skillKey)
        }
      }
    }
  } catch {
    Write-Warning "Could not read skill-update-report.json: $($_.Exception.Message)"
  }
}
$pendingUpdateCount = $pendingSkillNames.Count
$json = $records | ConvertTo-Json -Depth 8 -Compress

$rows = foreach ($record in $records) {
  $triggers = ($record.triggers | ForEach-Object { "<code>$(ConvertTo-HtmlText $_)</code>" }) -join " "
  $primaryTrigger = ConvertTo-HtmlText $record.triggers[0]
  $historyCount = [int]($historicalCounts[$record.name])
  $skillLink = ConvertTo-HtmlText $record.link
  $englishDescription = ConvertTo-HtmlText $record.description
  $chineseDescription = ConvertTo-HtmlText $record.chineseDescription
  $updateInfo = $updateBySkill[$record.name.ToLowerInvariant()]
  $updateStatus = if ($updateInfo) { [string]$updateInfo.status } else { "" }
  $updateRepo = if ($updateInfo) { [string]$updateInfo.repo } else { "" }
  $updateUrl = if ($updateInfo) { [string]$updateInfo.url } else { "" }
  $updateMessage = if ($updateInfo) { [string]$updateInfo.message } else { "" }
  $updateClass = if ($updateStatus -eq "update_available") { " update-available" } else { "" }
  $updateBadgeLine = ""
  if ($updateStatus -eq "update_available") {
    $updateBadgeLine = "          <span class=""update-badge update-needed"" title=""$(ConvertTo-HtmlText $updateRepo)&#10;$(ConvertTo-HtmlText $updateMessage)"">&#x5F85;&#x66F4;&#x65B0;</span>"
  }
  $sourceKinds = @($record.sources | ForEach-Object { $_.kind })
  $isInstalled = ($sourceKinds -contains "codex") -or ($sourceKinds -contains "agents") -or ($sourceKinds -contains "system")
  $sources = ($record.sources | Sort-Object rank,label | ForEach-Object {
    "<span class=""source"">$(ConvertTo-HtmlText $_.label)</span>"
  }) -join " "
  $paths = ($record.sources | Sort-Object rank,label | ForEach-Object {
    "<div class=""path"">$(ConvertTo-HtmlText $_.path)</div>"
  }) -join ""
  @"
      <article class="skill-card$updateClass" data-name="$(ConvertTo-HtmlText $record.name)" data-category="$(ConvertTo-HtmlText $record.category)" data-date="$($record.latestTicks)" data-history-count="$historyCount" data-count="$historyCount" data-installed="$($isInstalled.ToString().ToLowerInvariant())" data-update-status="$(ConvertTo-HtmlText $updateStatus)" data-update-repo="$(ConvertTo-HtmlText $updateRepo)" data-update-url="$(ConvertTo-HtmlText $updateUrl)" data-search="$(ConvertTo-HtmlText (($record.name + ' ' + $record.description + ' ' + $record.category + ' ' + ($record.triggers -join ' ')).ToLowerInvariant()))">
        <div class="card-top">
          <div>
            <h2><a class="skill-link" href="$skillLink" target="_blank" rel="noreferrer">$(ConvertTo-HtmlText $record.name)</a></h2>
            <p class="description" title="$englishDescription" data-english="$englishDescription">$chineseDescription</p>
          </div>
          <time datetime="$(ConvertTo-HtmlText $record.latest)">$(ConvertTo-HtmlText $record.latest)</time>
        </div>
        <div class="meta">
          <span class="category">$(ConvertTo-HtmlText $record.category)</span>
$updateBadgeLine
          <span class="call-count" title="&#x5386;&#x53F2;&#x4F1A;&#x8BDD;&#x7EDF;&#x8BA1; $historyCount">&#x8C03;&#x7528; $historyCount</span>
          $sources
        </div>
        <div class="invoke">
          <div class="invoke-title">
            <strong>&#x53EC;&#x5524;&#x53E3;&#x4EE4;</strong>
            <button type="button" class="copy-command" data-copy="$primaryTrigger">&#x590D;&#x5236;&#x4E3B;&#x53E3;&#x4EE4;</button>
          </div>
          <div>$triggers</div>
        </div>
        <details>
          <summary>&#x6587;&#x4EF6;&#x4F4D;&#x7F6E;</summary>
          $paths
        </details>
      </article>
"@
}

$categories = @($records | Group-Object { $_["category"] } | Sort-Object Name | ForEach-Object { $_.Name })
$categoryOptions = ($categories | ForEach-Object { "<option value=""$(ConvertTo-HtmlText $_)"">$(ConvertTo-HtmlText $_)</option>" }) -join "`n"

$html = @"
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Skill&#x6863;&#x6848;&#x5BA4;</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #05070d;
      --surface: #09111d;
      --surface-soft: #0d1726;
      --surface-raised: #101c2d;
      --text: #e9f7ff;
      --muted: #91a8ba;
      --faint: #607789;
      --line: rgba(92, 236, 255, .18);
      --line-strong: rgba(92, 236, 255, .42);
      --accent: #34e7ff;
      --accent-rgb: 52, 231, 255;
      --accent-ink: #c9fbff;
      --accent-weak: rgba(52, 231, 255, .13);
      --danger: #ff3d81;
      --warning: #ffc857;
      --chip: rgba(125, 148, 170, .16);
      --code: #dcfbff;
      --shadow: 0 24px 80px rgba(0, 0, 0, .42), 0 0 34px rgba(var(--accent-rgb), .12);
      --radius: 2px;
    }
    * { box-sizing: border-box; }
    @media (hover: hover) and (pointer: fine) {
      html, body, a, button, input, select, summary, .description {
        cursor: none;
      }
    }
    body {
      margin: 0;
      background:
        radial-gradient(circle at 18% -8%, rgba(52, 231, 255, .20), transparent 28vw),
        radial-gradient(circle at 84% 6%, rgba(255, 61, 129, .14), transparent 24vw),
        linear-gradient(180deg, rgba(10, 20, 36, .85) 0, transparent 360px),
        var(--bg);
      color: var(--text);
      font-family: "Segoe UI Variable", "Segoe UI", "Microsoft YaHei UI", "Microsoft YaHei", system-ui, sans-serif;
      line-height: 1.5;
    }
    body::before {
      content: "";
      position: fixed;
      inset: 0;
      z-index: -1;
      pointer-events: none;
      background:
        linear-gradient(rgba(52, 231, 255, .07) 1px, transparent 1px),
        linear-gradient(90deg, rgba(52, 231, 255, .06) 1px, transparent 1px),
        repeating-linear-gradient(180deg, transparent 0 7px, rgba(255, 255, 255, .025) 7px 8px);
      background-size: 44px 44px, 44px 44px, auto;
      mask-image: linear-gradient(180deg, #000 0, rgba(0,0,0,.72) 460px, transparent 100%);
    }
    .veki-cursor {
      position: fixed;
      left: 0;
      top: 0;
      z-index: 9999;
      pointer-events: none;
      opacity: 0;
      transform: translate3d(-120px, -120px, 0);
      transition: opacity .18s ease;
      mix-blend-mode: screen;
      will-change: transform, opacity;
    }
    .veki-cursor.active {
      opacity: 1;
    }
    .veki-cursor span {
      position: relative;
      display: block;
      padding: 2px 5px;
      font-family: "Cascadia Code", Consolas, monospace;
      font-size: 13px;
      font-weight: 800;
      line-height: 1;
      letter-spacing: .02em;
      background: linear-gradient(90deg, #34e7ff, #ff3d81, #b217ff, #34e7ff);
      background-size: 220% 100%;
      -webkit-background-clip: text;
      background-clip: text;
      color: transparent;
      text-shadow: 0 0 12px rgba(var(--accent-rgb), .72), 0 0 24px rgba(255, 61, 129, .46);
      animation: veki-spectrum 1.15s linear infinite;
    }
    .veki-cursor span::after {
      content: "Veki";
      position: absolute;
      left: 8px;
      top: 4px;
      z-index: -1;
      color: rgba(255, 61, 129, .42);
      filter: blur(1px);
    }
    @keyframes veki-spectrum {
      to { background-position: 220% 0; }
    }
    .veki-particle {
      position: fixed;
      left: 0;
      top: 0;
      z-index: 9998;
      width: var(--size, 5px);
      height: var(--size, 5px);
      border-radius: 50%;
      pointer-events: none;
      opacity: 0;
      background: radial-gradient(circle, #fff 0 12%, hsl(var(--hue, 188) 100% 68%) 34%, transparent 72%);
      box-shadow:
        0 0 8px hsl(var(--hue, 188) 100% 64%),
        0 0 18px hsl(var(--hue, 188) 100% 58%),
        0 0 30px rgba(var(--accent-rgb), .22);
      mix-blend-mode: screen;
      transform: translate3d(-999px, -999px, 0) scale(.1);
      transition: transform .58s cubic-bezier(.12, .72, .18, 1), opacity .58s ease;
      will-change: transform, opacity;
    }
    .kinetic-ripple {
      position: absolute;
      top: 18px;
      right: clamp(48px, 5vw, 96px);
      z-index: 0;
      width: min(28vw, 540px);
      height: 160px;
      pointer-events: none;
      overflow: hidden;
      opacity: .64;
      mask-image: radial-gradient(ellipse at center, #000 0 58%, transparent 82%);
      contain: paint;
    }
    .kinetic-ripple::before {
      content: "";
      position: absolute;
      inset: 14px 4px 0;
      border: 1px solid rgba(var(--accent-rgb), .18);
      background:
        linear-gradient(rgba(var(--accent-rgb), .12) 1px, transparent 1px),
        linear-gradient(90deg, rgba(var(--accent-rgb), .10) 1px, transparent 1px);
      background-size: 30px 30px;
      transform: perspective(460px) rotateX(66deg) translateY(28px);
      transform-origin: center bottom;
      animation: kinetic-grid-shift 5.8s linear infinite;
    }
    .kinetic-ripple::after {
      content: "";
      position: absolute;
      inset: 0;
      background: radial-gradient(circle at 52% 56%, rgba(var(--accent-rgb), .18), transparent 36%);
      filter: blur(18px);
      opacity: .72;
    }
    .kinetic-ripple .kinetic-word {
      position: absolute;
      left: 50%;
      top: 52%;
      z-index: 1;
      display: grid;
      grid-template-columns: repeat(18, minmax(.52em, 1fr));
      gap: .05em;
      width: min(96%, 500px);
      transform: translate(-50%, -50%) perspective(440px) rotateX(54deg);
      transform-style: preserve-3d;
      font-family: "Cascadia Code", Consolas, monospace;
      font-size: clamp(14px, 1.3vw, 22px);
      font-weight: 800;
      line-height: 1;
      letter-spacing: .04em;
      text-transform: uppercase;
      white-space: nowrap;
    }
    .kinetic-ripple .kinetic-word span {
      display: inline-block;
      color: rgba(201, 251, 255, .36);
      text-align: center;
      text-shadow: 0 0 12px rgba(var(--accent-rgb), .18);
      transform: translateY(12px) translateZ(0) scale(.82);
      animation: kinetic-letter 2.6s ease-in-out infinite;
      animation-delay: calc(var(--d) * -90ms);
    }
    .kinetic-ripple .space {
      opacity: .26;
    }
    .skill-pet {
      position: absolute;
      top: 32px;
      right: clamp(76px, 7vw, 140px);
      z-index: 8;
      width: min(380px, calc(100vw - 24px));
      color: var(--text);
      user-select: none;
      touch-action: none;
      filter: drop-shadow(0 24px 40px rgba(0, 0, 0, .36));
    }
    .skill-pet.dragging {
      filter: drop-shadow(0 28px 60px rgba(var(--accent-rgb), .22));
    }
    .pet-shell {
      display: grid;
      grid-template-columns: 132px minmax(0, 1fr);
      gap: 10px;
      align-items: end;
      padding: 0;
      border: 0;
      background: transparent;
      backdrop-filter: none;
    }
    .pet-avatar {
      position: relative;
      width: 124px;
      height: 124px;
      aspect-ratio: 1;
      cursor: grab;
    }
    .skill-pet.dragging .pet-avatar {
      cursor: grabbing;
    }
    .pet-avatar > :not(.pet-media) {
      display: none;
    }
    .pet-media {
      position: absolute;
      inset: 0;
      display: grid;
      place-items: end center;
      pointer-events: none;
    }
    .pet-image,
    .pet-video {
      width: 100%;
      height: 100%;
      object-fit: contain;
      filter: drop-shadow(0 0 18px rgba(var(--accent-rgb), .32));
    }
    .pet-video {
      display: none;
    }
    .skill-pet.playing-motion .pet-image {
      display: block;
    }
    .skill-pet.playing-motion .pet-video {
      display: none;
    }
    .pet-body {
      position: absolute;
      left: 11px;
      bottom: 2px;
      width: 46px;
      height: 60px;
      border: 1px solid rgba(var(--accent-rgb), .44);
      border-radius: 50% 50% 44% 44%;
      background:
        radial-gradient(circle at 50% 34%, rgba(233, 247, 255, .95) 0 23%, transparent 24%),
        linear-gradient(160deg, rgba(52, 231, 255, .30), rgba(255, 61, 129, .18) 42%, rgba(5, 7, 13, .98) 66%);
      box-shadow: inset 0 0 22px rgba(var(--accent-rgb), .18), 0 0 26px rgba(var(--accent-rgb), .22);
      animation: pet-breathe 2.8s ease-in-out infinite;
    }
    .pet-eye {
      position: absolute;
      top: 25px;
      width: 5px;
      height: 5px;
      border-radius: 50%;
      background: #05070d;
      box-shadow: 0 0 8px rgba(var(--accent-rgb), .68);
    }
    .pet-eye.left { left: 28px; }
    .pet-eye.right { left: 40px; }
    .pet-brow {
      position: absolute;
      top: 20px;
      width: 12px;
      height: 2px;
      border-radius: 2px;
      background: rgba(var(--accent-rgb), .84);
      box-shadow: 0 0 10px rgba(var(--accent-rgb), .55);
      transition: transform .2s ease, opacity .2s ease;
    }
    .pet-brow.left { left: 25px; transform: rotate(8deg); }
    .pet-brow.right { left: 39px; transform: rotate(-8deg); }
    .pet-beak {
      position: absolute;
      left: 34px;
      top: 33px;
      width: 8px;
      height: 5px;
      background: var(--danger);
      clip-path: polygon(0 0, 100% 50%, 0 100%);
      filter: drop-shadow(0 0 6px rgba(255, 61, 129, .7));
    }
    .pet-mouth {
      position: absolute;
      left: 32px;
      top: 41px;
      width: 12px;
      height: 5px;
      border-bottom: 2px solid rgba(5, 7, 13, .85);
      border-radius: 0 0 12px 12px;
      transition: transform .2s ease, border-color .2s ease;
    }
    .pet-wing {
      position: absolute;
      top: 37px;
      width: 18px;
      height: 31px;
      border: 1px solid rgba(var(--accent-rgb), .22);
      background: rgba(5, 7, 13, .78);
      border-radius: 65% 35% 70% 40%;
    }
    .pet-wing.left {
      left: 3px;
      transform: rotate(22deg);
    }
    .pet-wing.right {
      right: 3px;
      transform: rotate(-22deg);
    }
    .pet-foot {
      position: absolute;
      bottom: 0;
      width: 16px;
      height: 6px;
      background: var(--danger);
      border-radius: 10px 10px 2px 2px;
      box-shadow: 0 0 8px rgba(255, 61, 129, .5);
    }
    .pet-foot.left { left: 18px; }
    .pet-foot.right { right: 18px; }
    .pet-status-dot {
      position: absolute;
      right: 7px;
      top: 8px;
      width: 9px;
      height: 9px;
      border-radius: 50%;
      background: var(--accent);
      box-shadow: 0 0 16px rgba(var(--accent-rgb), .8);
    }
    .skill-pet.dead .pet-body,
    .skill-pet.dead .pet-wing,
    .skill-pet.dead .pet-foot {
      filter: grayscale(1);
      opacity: .55;
      animation: none;
    }
    .skill-pet.dead .pet-status-dot {
      background: var(--danger);
      box-shadow: 0 0 18px rgba(255, 61, 129, .7);
    }
    .skill-pet.mood-happy .pet-wing.left { animation: pet-wave-left .7s ease-in-out 2; }
    .skill-pet.mood-happy .pet-mouth { transform: scaleX(1.2) translateY(1px); }
    .skill-pet.mood-skeptical .pet-brow.left { transform: rotate(-18deg) translateY(1px); }
    .skill-pet.mood-skeptical .pet-brow.right { transform: rotate(18deg) translateY(1px); }
    .skill-pet.mood-skeptical .pet-mouth { transform: rotate(-3deg) scaleX(.8); border-radius: 12px 12px 0 0; border-bottom-color: var(--danger); }
    .skill-pet.mood-hungry .pet-status-dot { background: var(--danger); box-shadow: 0 0 18px rgba(255, 61, 129, .8); }
    .skill-pet.mood-proud .pet-body { box-shadow: inset 0 0 22px rgba(var(--accent-rgb), .18), 0 0 36px rgba(var(--accent-rgb), .36); }
    .pet-panel {
      min-width: 0;
      display: grid;
      gap: 7px;
      padding: 10px;
      border-left: 1px solid rgba(var(--accent-rgb), .32);
      background: linear-gradient(135deg, rgba(9, 17, 29, .92), rgba(13, 23, 38, .84));
      backdrop-filter: blur(16px) saturate(150%);
      clip-path: polygon(10px 0, 100% 0, 100% 100%, 10px 100%, 10px 58%, 0 50%, 10px 42%);
    }
    .pet-topline {
      display: flex;
      gap: 8px;
      align-items: center;
      justify-content: space-between;
      font-family: "Cascadia Code", Consolas, monospace;
      font-size: 11px;
      color: var(--muted);
    }
    .pet-name {
      color: var(--accent-ink);
      font-weight: 800;
      text-shadow: 0 0 12px rgba(var(--accent-rgb), .44);
    }
    .pet-hunger {
      color: var(--text);
      white-space: nowrap;
    }
    .pet-toggle {
      width: 24px;
      height: 24px;
      min-height: 24px;
      padding: 0;
      display: inline-grid;
      place-items: center;
      border-color: rgba(var(--accent-rgb), .26);
      font-size: 14px;
      line-height: 1;
    }
    .pet-meter {
      height: 6px;
      border: 1px solid rgba(var(--accent-rgb), .22);
      background: rgba(3, 8, 15, .66);
      overflow: hidden;
    }
    .pet-meter-fill {
      height: 100%;
      width: 0%;
      background: linear-gradient(90deg, var(--danger), var(--accent));
      box-shadow: 0 0 18px rgba(var(--accent-rgb), .42);
      transition: width .22s ease;
    }
    .pet-reco {
      display: grid;
      gap: 5px;
      min-width: 0;
    }
    .pet-skill {
      font-size: 13px;
      font-weight: 800;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .skill-pet.dead .pet-skill {
      overflow: visible;
      text-overflow: clip;
      white-space: normal;
      line-height: 1.35;
    }
    .pet-pitch {
      min-height: 34px;
      color: var(--muted);
      font-size: 12px;
      line-height: 1.35;
    }
    .pet-actions {
      display: flex;
      gap: 6px;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
    }
    .pet-action {
      min-height: 28px;
      padding: 0 8px;
      font-size: 12px;
      white-space: nowrap;
      background: rgba(var(--accent-rgb), .12);
      color: var(--accent-ink);
    }
    .pet-action.primary {
      border-color: rgba(255, 61, 129, .7);
      background: linear-gradient(135deg, rgba(255, 61, 129, .9), rgba(178, 23, 255, .88));
      color: #fff;
    }
    .pet-progress {
      color: var(--muted);
      font-family: "Cascadia Code", Consolas, monospace;
      font-size: 11px;
      white-space: nowrap;
    }
    .pet-chat {
      display: grid;
      gap: 7px;
      margin-top: 3px;
    }
    .skill-pet.chat-collapsed .pet-chat,
    .skill-pet.chat-collapsed .pet-reco,
    .skill-pet.chat-collapsed .pet-actions,
    .skill-pet.chat-collapsed .pet-meter {
      display: none;
    }
    .skill-pet.chat-collapsed .pet-panel {
      width: max-content;
      min-width: 172px;
    }
    .pet-chat-log {
      display: grid;
      gap: 6px;
      max-height: 122px;
      overflow: auto;
      padding: 4px 4px 4px 0;
      font-size: 12px;
      line-height: 1.4;
    }
    .pet-message {
      padding: 7px 8px;
      background: rgba(3, 8, 15, .72);
      border: 1px solid rgba(var(--accent-rgb), .14);
      border-left: 2px solid rgba(var(--accent-rgb), .58);
    }
    .pet-message.user {
      border-left-color: rgba(255, 61, 129, .75);
      color: var(--text);
      background: rgba(20, 10, 24, .78);
    }
    .pet-message.assistant {
      color: var(--text);
    }
    .pet-chat-row {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 6px;
    }
    .pet-chat-input,
    .pet-config-input {
      min-width: 0;
      min-height: 30px;
      border: 1px solid rgba(var(--accent-rgb), .2);
      background: rgba(3, 8, 15, .84);
      color: var(--text);
      padding: 0 8px;
      font: inherit;
      font-size: 12px;
      outline: none;
    }
    .pet-chat-input:focus,
    .pet-config-input:focus {
      border-color: rgba(var(--accent-rgb), .68);
      box-shadow: 0 0 18px rgba(var(--accent-rgb), .14);
    }
    .pet-config {
      color: var(--muted);
      font-size: 11px;
    }
    .pet-config summary {
      cursor: pointer;
      color: var(--accent-ink);
    }
    .pet-config-grid {
      display: grid;
      gap: 6px;
      margin-top: 6px;
    }
    .pet-config-grid label {
      display: grid;
      gap: 3px;
    }
    .skill-card.pet-highlight {
      border-color: rgba(var(--accent-rgb), .78);
      box-shadow: 0 0 0 1px rgba(var(--accent-rgb), .3), 0 0 38px rgba(var(--accent-rgb), .18);
    }
    @keyframes pet-breathe {
      0%, 100% { transform: translateY(0) scaleY(1); }
      50% { transform: translateY(-3px) scaleY(1.03); }
    }
    @keyframes pet-wave-left {
      0%, 100% { transform: rotate(22deg); }
      50% { transform: rotate(52deg) translateY(-5px); }
    }
    @keyframes kinetic-grid-shift {
      to { background-position: 0 30px, 30px 0; }
    }
    @keyframes kinetic-letter {
      0%, 100% {
        opacity: .22;
        transform: translateY(12px) translateZ(0) scale(.78);
        color: rgba(201, 251, 255, .42);
      }
      48%, 56% {
        opacity: .98;
        transform: translateY(-12px) translateZ(54px) scale(1.12);
        color: var(--accent-ink);
        text-shadow: 0 0 14px rgba(var(--accent-rgb), .86), 0 0 34px rgba(var(--accent-rgb), .34);
      }
    }
    header {
      position: relative;
      overflow: hidden;
      border-bottom: 1px solid var(--line);
      background: linear-gradient(180deg, rgba(7, 13, 24, .92), rgba(7, 13, 24, .74));
      backdrop-filter: blur(18px) saturate(145%);
    }
    .wrap {
      width: min(1320px, calc(100% - 32px));
      margin: 0 auto;
    }
    .hero {
      display: grid;
      grid-template-columns: 1fr;
      gap: 22px;
      align-items: start;
      padding: 38px 0 24px;
    }
    h1 {
      margin: 0;
      max-width: 760px;
      font-size: clamp(34px, 5vw, 68px);
      font-family: "Segoe UI Variable Display", "Segoe UI Variable", "Microsoft YaHei UI", system-ui, sans-serif;
      font-weight: 780;
      letter-spacing: 0;
      line-height: 0.96;
      text-shadow: 0 0 32px rgba(var(--accent-rgb), .28);
    }
    .subtitle {
      max-width: 860px;
      margin: 16px 0 0;
      color: var(--muted);
      font-size: 15px;
    }
    .stats {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 0;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      background: linear-gradient(180deg, rgba(16, 28, 45, .78), rgba(9, 17, 29, .82));
      box-shadow: inset 0 1px 0 rgba(255,255,255,.06), var(--shadow);
    }
    .stat {
      padding: 16px 18px;
      min-width: 0;
      border-right: 1px solid var(--line);
      border-bottom: 0;
    }
    .stat:last-child {
      border-right: 0;
    }
    .stat strong {
      display: block;
      color: var(--text);
      font-family: "Cascadia Code", Consolas, monospace;
      font-size: clamp(18px, 1.7vw, 24px);
      font-weight: 600;
      line-height: 1.2;
      white-space: nowrap;
    }
    .stat span {
      color: var(--muted);
      font-size: 12px;
    }
    .stat.pending strong {
      color: var(--danger);
    }
    .stat.update-time {
      display: block;
    }
    .stat.update-time strong {
      margin-top: 2px;
      font-size: 14px;
      white-space: normal;
      overflow-wrap: anywhere;
    }
    .toolbar {
      position: sticky;
      top: 0;
      z-index: 4;
      border-bottom: 1px solid var(--line);
      background: rgba(5, 7, 13, .78);
      backdrop-filter: blur(18px) saturate(145%);
    }
    .tools {
      display: grid;
      grid-template-columns: minmax(280px, 1fr) minmax(360px, 420px);
      grid-template-areas:
        "search category"
        "sorts updates";
      gap: 8px;
      align-items: center;
      padding: 12px 0;
    }
    #search { grid-area: search; }
    #categoryFilter { grid-area: category; }
    input, select, button {
      appearance: none;
      min-height: 42px;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      background: rgba(13, 23, 38, .82);
      color: var(--text);
      font: inherit;
      outline: none;
      transition: border-color .18s ease, background .18s ease, transform .18s ease, box-shadow .18s ease;
    }
    select {
      background-image: linear-gradient(45deg, transparent 50%, var(--muted) 50%), linear-gradient(135deg, var(--muted) 50%, transparent 50%);
      background-position: calc(100% - 18px) 18px, calc(100% - 13px) 18px;
      background-size: 5px 5px, 5px 5px;
      background-repeat: no-repeat;
      padding-right: 34px;
    }
    input, select { padding: 0 13px; }
    input::placeholder { color: var(--faint); }
    input:focus, select:focus, button:focus-visible {
      border-color: var(--accent);
      box-shadow: 0 0 0 3px rgba(var(--accent-rgb), .16), 0 0 24px rgba(var(--accent-rgb), .16);
    }
    button {
      padding: 0 12px;
      cursor: pointer;
    }
    button:active { transform: translateY(1px); }
    button.active {
      border-color: var(--accent);
      background: rgba(var(--accent-rgb), .16);
      color: var(--accent-ink);
      font-weight: 650;
    }
    .sorts {
      grid-area: sorts;
      display: flex;
      gap: 6px;
      flex-wrap: wrap;
    }
    main {
      padding: 16px 0 46px;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
      gap: 10px;
      align-items: start;
    }
    .skill-card {
      position: relative;
      overflow: hidden;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      background:
        linear-gradient(135deg, rgba(52, 231, 255, .08), transparent 38%),
        rgba(9, 17, 29, .84);
      padding: 14px;
      min-height: 238px;
      box-shadow: inset 0 1px 0 rgba(255,255,255,.06);
      transition: border-color .18s ease, transform .18s ease, box-shadow .18s ease;
    }
    .skill-card::before {
      content: "";
      position: absolute;
      inset: 0 auto 0 0;
      width: 3px;
      background: var(--accent);
      opacity: .86;
      box-shadow: 0 0 18px rgba(var(--accent-rgb), .42);
    }
    .skill-card:hover {
      border-color: var(--line-strong);
      box-shadow: var(--shadow);
      transform: translateY(-2px);
    }
    .skill-card.update-available {
      border-color: rgba(255, 61, 129, .62);
      background: linear-gradient(135deg, rgba(255, 61, 129, .12), rgba(9, 17, 29, .88));
    }
    .skill-card.update-available::before {
      background: var(--danger);
      opacity: 1;
    }
    .skill-card.update-unknown::before {
      background: var(--warning);
    }
    .card-top {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      align-items: flex-start;
    }
    h2 {
      margin: 0 0 8px;
      font-size: 17px;
      line-height: 1.25;
      font-family: "Segoe UI Variable Display", "Segoe UI Variable", "Microsoft YaHei UI", system-ui, sans-serif;
      font-weight: 760;
      overflow-wrap: anywhere;
    }
    .skill-link {
      color: inherit;
      text-decoration: none;
      border-bottom: 1px solid transparent;
    }
    .skill-link:hover {
      color: var(--accent-ink);
      border-bottom-color: var(--accent);
    }
    .card-top p {
      margin: 0;
      color: var(--muted);
      font-size: 13px;
      display: -webkit-box;
      -webkit-line-clamp: 3;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }
    .description {
      position: relative;
      cursor: help;
    }
    .description:hover::after {
      content: attr(data-english);
      position: absolute;
      left: 0;
      top: calc(100% + 8px);
      z-index: 6;
      width: min(420px, 82vw);
      max-height: 220px;
      overflow: auto;
      border: 1px solid var(--line-strong);
      border-radius: var(--radius);
      background: rgba(8, 15, 26, .96);
      color: var(--text);
      box-shadow: var(--shadow);
      padding: 10px 12px;
      font-size: 12px;
      line-height: 1.45;
      display: block;
      -webkit-line-clamp: initial;
      -webkit-box-orient: initial;
    }
    time {
      flex: 0 0 auto;
      color: var(--muted);
      font-size: 12px;
      font-family: "Cascadia Code", Consolas, monospace;
      white-space: nowrap;
    }
    .meta {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
      margin: 14px 0;
    }
    .category, .source, .call-count {
      border-radius: var(--radius);
      padding: 4px 8px;
      font-size: 12px;
      line-height: 1.2;
    }
    .category {
      background: rgba(var(--accent-rgb), .16);
      color: var(--accent-ink);
      font-weight: 650;
      border: 1px solid rgba(var(--accent-rgb), .16);
    }
    .source {
      background: var(--chip);
      color: var(--muted);
      border: 1px solid rgba(145, 168, 186, .10);
    }
    .call-count {
      background: rgba(13, 23, 38, .86);
      color: var(--accent-ink);
      border: 1px solid var(--line);
      font-family: "Cascadia Code", Consolas, monospace;
    }
    .update-badge {
      border-radius: var(--radius);
      padding: 4px 8px;
      font-size: 12px;
      line-height: 1.2;
      font-weight: 700;
    }
    .update-needed {
      background: rgba(255, 61, 129, .14);
      color: #ffc1d7;
      border: 1px solid rgba(255, 61, 129, .42);
    }
    .update-unknown-badge {
      background: rgba(255, 200, 87, .14);
      color: #ffe4a8;
      border: 1px solid rgba(255, 200, 87, .36);
    }
    .update-actions {
      grid-area: updates;
      display: grid;
      grid-template-columns: minmax(112px, auto) max-content max-content;
      column-gap: 12px;
      row-gap: 6px;
      align-items: center;
      justify-content: flex-end;
    }
    .primary-action {
      border-color: rgba(255, 61, 129, .72);
      background: linear-gradient(135deg, #ff3d81, #b217ff);
      color: #fff;
      font-weight: 700;
      box-shadow: 0 0 24px rgba(255, 61, 129, .24);
    }
    .primary-action:disabled {
      cursor: wait;
      opacity: .68;
    }
    .update-status-text {
      min-width: 112px;
      color: var(--muted);
      font-size: 12px;
      text-align: right;
      white-space: nowrap;
      grid-column: 1;
      grid-row: 1;
      align-self: end;
      padding-bottom: 3px;
    }
    #showUpdatesOnly {
      grid-column: 2;
      grid-row: 1;
    }
    #updateAllSkills {
      grid-column: 3;
      grid-row: 1;
    }
    .invoke {
      display: grid;
      gap: 8px;
      margin-top: 12px;
      padding-top: 12px;
      border-top: 1px solid var(--line);
    }
    .invoke-title {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
    }
    .invoke-title strong {
      font-size: 13px;
      color: var(--text);
    }
    .copy-command {
      min-height: 28px;
      padding: 0 8px;
      border-radius: var(--radius);
      color: var(--accent-ink);
      background: rgba(var(--accent-rgb), .12);
      font-size: 12px;
      white-space: nowrap;
    }
    code {
      display: inline-block;
      max-width: 100%;
      margin: 0 5px 6px 0;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      background: rgba(3, 8, 15, .58);
      color: var(--code);
      padding: 3px 7px;
      overflow-wrap: anywhere;
      font-family: "Cascadia Code", Consolas, monospace;
      font-size: 12px;
    }
    details {
      margin-top: 10px;
      color: var(--muted);
      font-size: 12px;
    }
    summary {
      cursor: pointer;
      width: fit-content;
    }
    .path {
      margin-top: 6px;
      overflow-wrap: anywhere;
      font-family: "Cascadia Code", Consolas, monospace;
    }
    .empty {
      display: none;
      border: 1px dashed var(--line);
      border-radius: var(--radius);
      padding: 28px;
      text-align: center;
      color: var(--muted);
      background: rgba(9, 17, 29, .84);
    }
    @media (prefers-reduced-motion: reduce) {
      *, *::before, *::after {
        scroll-behavior: auto !important;
        transition-duration: .01ms !important;
        animation-duration: .01ms !important;
      }
      html, body, a, button, input, select, summary, .description {
        cursor: auto;
      }
      .veki-cursor {
        display: none;
      }
      .veki-particle,
      .kinetic-ripple {
        display: none;
      }
      .pet-body {
        animation: none;
      }
    }
    @media (max-width: 900px) {
      .hero {
        grid-template-columns: 1fr;
        gap: 18px;
      }
      .kinetic-ripple {
        opacity: .28;
        right: 24px;
        width: min(42vw, 360px);
      }
      .skill-pet {
        right: 18px;
        top: 18px;
        transform: scale(.92);
        transform-origin: top right;
      }
      .stats {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }
      .stat {
        border-right: 1px solid var(--line);
        border-bottom: 1px solid var(--line);
      }
      .stat:nth-child(2n) {
        border-right: 0;
      }
      .stat:nth-last-child(-n + 2) {
        border-bottom: 0;
      }
    }
    @media (max-width: 760px) {
      .wrap {
        width: min(100% - 24px, 1320px);
      }
      .tools {
        grid-template-columns: 1fr;
        grid-template-areas:
          "search"
          "category"
          "sorts"
          "updates";
      }
      .sorts button {
        flex: 1 1 30%;
      }
      .update-actions {
        justify-content: flex-start;
        grid-template-columns: 1fr;
      }
      #showUpdatesOnly,
      #updateAllSkills,
      .update-status-text {
        grid-column: auto;
        grid-row: auto;
        text-align: left;
      }
      .card-top {
        display: grid;
      }
      time {
        white-space: normal;
      }
      .grid {
        grid-template-columns: 1fr;
      }
      .stat.update-time {
        display: block;
      }
      .stat.update-time strong {
        margin-top: 2px;
        text-align: left;
      }
      .copy-command {
        width: auto;
      }
      .skill-pet {
        position: absolute;
        left: 12px;
        right: auto;
        top: 12px;
        width: min(324px, calc(100vw - 24px));
        transform: scale(.86);
        transform-origin: top left;
      }
    }
  </style>
</head>
<body>
  <div class="veki-cursor" aria-hidden="true"><span>Veki</span></div>
  <header>
    <div class="kinetic-ripple" aria-hidden="true">
      <div class="kinetic-word" aria-label="Skill Archive Room">
        <span style="--d:0">S</span><span style="--d:1">k</span><span style="--d:2">i</span><span style="--d:3">l</span><span style="--d:4">l</span><span class="space" style="--d:5">&nbsp;</span><span style="--d:6">A</span><span style="--d:7">r</span><span style="--d:8">c</span><span style="--d:9">h</span><span style="--d:10">i</span><span style="--d:11">v</span><span style="--d:12">e</span><span class="space" style="--d:13">&nbsp;</span><span style="--d:14">R</span><span style="--d:15">o</span><span style="--d:16">o</span><span style="--d:17">m</span>
      </div>
    </div>
    <section class="skill-pet" id="skillPet" aria-label="Skill &#x9875;&#x9762;&#x5BA0;&#x7269;">
      <div class="pet-shell">
        <div class="pet-avatar" id="petDragHandle" aria-hidden="true">
          <div class="pet-media">
            <img class="pet-image" id="petImage" src="assets/desktop-pet/transparent/static/default.png" alt="">
            <video class="pet-video" id="petVideo" muted playsinline preload="auto"></video>
          </div>
          <div class="pet-status-dot"></div>
          <div class="pet-wing left"></div>
          <div class="pet-wing right"></div>
          <div class="pet-body"></div>
          <div class="pet-brow left"></div>
          <div class="pet-brow right"></div>
          <div class="pet-eye left"></div>
          <div class="pet-eye right"></div>
          <div class="pet-beak"></div>
          <div class="pet-mouth"></div>
          <div class="pet-foot left"></div>
          <div class="pet-foot right"></div>
        </div>
        <div class="pet-panel">
          <div class="pet-topline">
            <span class="pet-name">小V</span>
            <span class="pet-hunger" id="petHungerText">&#x9971;&#x8179; 0/30</span>
            <button type="button" class="pet-action pet-toggle" id="petChatToggle" aria-label="&#x6536;&#x8D77;&#x5BF9;&#x8BDD;&#x6846;" aria-expanded="true">&#x2212;</button>
          </div>
          <div class="pet-meter" aria-hidden="true"><div class="pet-meter-fill" id="petMeterFill"></div></div>
          <div class="pet-reco">
            <div class="pet-skill" id="petSkillName">...</div>
            <div class="pet-pitch" id="petPitch">&#x6B63;&#x5728;&#x7FFB;&#x4F60;&#x7684; skill &#x96F6;&#x98DF;&#x67DC;&#x3002;</div>
          </div>
          <div class="pet-actions">
            <button type="button" class="pet-action primary" id="petUseRecommendation">&#x590D;&#x5236;&#x53E3;&#x4EE4;</button>
            <button type="button" class="pet-action" id="petNextRecommendation">&#x4E0B;&#x4E00;&#x4E2A;</button>
            <button type="button" class="pet-action primary" id="petReviveButton" hidden>&#x7ACB;&#x5373;&#x590D;&#x6D3B;</button>
            <span class="pet-progress" id="petProgress">&#x4ECA;&#x65E5; 0/3</span>
          </div>
          <div class="pet-chat" aria-label="&#x5C0F;V &#x56FE;&#x4E66;&#x7BA1;&#x7406;&#x5458;&#x5BF9;&#x8BDD;">
            <div class="pet-chat-log" id="petChatLog"></div>
            <div class="pet-chat-row">
              <input class="pet-chat-input" id="petChatInput" type="text" placeholder="&#x95EE;&#x5B83;&#x8FD9;&#x4E2A; skill &#x600E;&#x4E48;&#x7528;&#xFF0C;&#x6216;&#x8BD5;&#x8BD5;&#x8BA8;&#x4EF7;&#x8FD8;&#x4EF7;" aria-label="&#x548C;&#x5C0F;V &#x5BF9;&#x8BDD;">
              <button type="button" class="pet-action primary" id="petChatSend">&#x53D1;&#x9001;</button>
            </div>
          </div>
        </div>
      </div>
    </section>
    <div class="wrap hero">
      <div>
        <h1>Skill&#x6863;&#x6848;&#x5BA4;</h1>
        <p class="subtitle">&#x628A;&#x4E2A;&#x4EBA;&#x6574;&#x7406;&#x548C;&#x672C;&#x673A;&#x5DF2;&#x5B89;&#x88C5;&#x7684; skill &#x6536;&#x5728;&#x4E00;&#x5F20;&#x53EF;&#x641C;&#x7D22;&#x7684;&#x7D22;&#x5F15;&#x91CC;&#x3002;&#x91CD;&#x70B9;&#x662F;&#x529F;&#x80FD;&#x3001;&#x53EC;&#x5524;&#x53E3;&#x4EE4;&#x548C;&#x6700;&#x540E;&#x66F4;&#x65B0;&#x65F6;&#x95F4;&#x3002;</p>
      </div>
      <div class="stats" aria-label="&#x7EDF;&#x8BA1;">
        <div class="stat"><strong>$installedSkillCount</strong><span>&#x672C;&#x673A;&#x5DF2;&#x5B89;&#x88C5;</span></div>
        <div class="stat"><strong>$($categories.Count)</strong><span>&#x529F;&#x80FD;&#x7C7B;&#x522B;</span></div>
        <div class="stat pending"><strong id="pendingUpdateCount">$pendingUpdateCount</strong><span>&#x5168;&#x90E8;&#x5F85;&#x66F4;&#x65B0;</span></div>
        <div class="stat update-time"><span>&#x4E0A;&#x6B21;&#x66F4;&#x65B0;&#x65F6;&#x95F4;</span><strong>$lastUpdatedAt</strong></div>
      </div>
    </div>
  </header>

  <section class="toolbar">
    <div class="wrap tools">
      <input id="search" type="search" placeholder="&#x641C;&#x7D22;&#x540D;&#x5B57;&#x3001;&#x529F;&#x80FD;&#x3001;&#x7C7B;&#x522B;&#x6216;&#x53EC;&#x5524;&#x53E3;&#x4EE4;" aria-label="&#x641C;&#x7D22; skill">
      <select id="categoryFilter" aria-label="&#x6309;&#x529F;&#x80FD;&#x7C7B;&#x522B;&#x7B5B;&#x9009;">
        <option value="">&#x5168;&#x90E8;&#x529F;&#x80FD;&#x7C7B;&#x522B;</option>
        $categoryOptions
      </select>
      <div class="sorts" aria-label="&#x6392;&#x5E8F;&#x65B9;&#x5F0F;">
        <button type="button" data-sort="count" class="active">&#x8C03;&#x7528;&#x6B21;&#x6570;</button>
        <button type="button" data-sort="date">&#x65E5;&#x671F;</button>
        <button type="button" data-sort="name">&#x540D;&#x5B57;</button>
        <button type="button" data-sort="category">&#x529F;&#x80FD;</button>
      </div>
      <div class="update-actions" aria-label="Skill &#x66F4;&#x65B0;&#x64CD;&#x4F5C;">
        <button type="button" id="showUpdatesOnly">&#x53EA;&#x770B;&#x5F85;&#x66F4;&#x65B0;</button>
        <button type="button" id="updateAllSkills" class="primary-action">&#x4E00;&#x952E;&#x66F4;&#x65B0;</button>
        <span id="updateStatusText" class="update-status-text">$(if ($lastUpdateCheck) { "&#x68C0;&#x67E5; $lastUpdateCheck" } else { "&#x672A;&#x68C0;&#x67E5;" })</span>
      </div>
    </div>
  </section>

  <main class="wrap">
    <div id="grid" class="grid">
$($rows -join "`n")
    </div>
    <div id="empty" class="empty">&#x6CA1;&#x6709;&#x5339;&#x914D;&#x7684; skill&#x3002;</div>
  </main>

  <script type="application/json" id="skillData">$json</script>
  <script src="pet-secrets.local.js"></script>
  <script>
    const grid = document.querySelector("#grid");
    const cards = Array.from(document.querySelectorAll(".skill-card"));
    const search = document.querySelector("#search");
    const categoryFilter = document.querySelector("#categoryFilter");
    const empty = document.querySelector("#empty");
    const buttons = Array.from(document.querySelectorAll("[data-sort]"));
    const showUpdatesOnlyButton = document.querySelector("#showUpdatesOnly");
    const updateAllButton = document.querySelector("#updateAllSkills");
    const updateStatusText = document.querySelector("#updateStatusText");
    const countStoreKey = "skillArchiveLocalCallIncrements";
    let sortMode = "count";
    let showUpdatesOnly = false;
    const installedSkillCount = $installedSkillCount;
    const vekiCursor = document.querySelector(".veki-cursor");
    const cursorEnabled = vekiCursor && window.matchMedia("(hover: hover) and (pointer: fine)").matches && !window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (cursorEnabled) {
      let cursorX = -120;
      let cursorY = -120;
      let cursorTargetX = cursorX;
      let cursorTargetY = cursorY;
      let lastParticleAt = 0;
      let lastPointerX = -120;
      let lastPointerY = -120;
      let particleIndex = 0;
      const particlePool = Array.from({ length: 44 }, () => {
        const particle = document.createElement("i");
        particle.className = "veki-particle";
        document.body.appendChild(particle);
        return particle;
      });
      const moveCursor = () => {
        cursorX += (cursorTargetX - cursorX) * 0.52;
        cursorY += (cursorTargetY - cursorY) * 0.52;
        vekiCursor.style.transform = "translate3d(" + cursorX + "px, " + cursorY + "px, 0)";
        window.requestAnimationFrame(moveCursor);
      };
      const spawnParticle = (x, y, vx, vy) => {
        const particle = particlePool[particleIndex % particlePool.length];
        particleIndex += 1;
        const speed = Math.max(1, Math.hypot(vx, vy));
        const tailX = x + 42;
        const tailY = y + 18;
        const angle = Math.atan2(vy, vx) + Math.PI + (Math.random() - .5) * .9;
        const distance = 18 + Math.min(speed * .9, 34) + Math.random() * 18;
        const hue = Math.round(185 + Math.random() * 135);
        const size = (3 + Math.random() * 5).toFixed(1) + "px";
        particle.style.setProperty("--hue", hue);
        particle.style.setProperty("--size", size);
        particle.style.transition = "none";
        particle.style.opacity = ".96";
        particle.style.transform = "translate3d(" + (tailX + Math.random() * 5) + "px, " + (tailY + Math.random() * 5 - 2) + "px, 0) scale(1)";
        particle.offsetWidth;
        particle.style.transition = "transform .58s cubic-bezier(.12, .72, .18, 1), opacity .58s ease";
        particle.style.opacity = "0";
        particle.style.transform = "translate3d(" + (tailX + Math.cos(angle) * distance) + "px, " + (tailY + Math.sin(angle) * distance) + "px, 0) scale(.08)";
      };
      window.addEventListener("pointermove", event => {
        cursorTargetX = event.clientX + 12;
        cursorTargetY = event.clientY + 12;
        vekiCursor.classList.add("active");
        const now = performance.now();
        const vx = event.clientX - lastPointerX;
        const vy = event.clientY - lastPointerY;
        lastPointerX = event.clientX;
        lastPointerY = event.clientY;
        if (now - lastParticleAt > 28) {
          lastParticleAt = now;
          spawnParticle(cursorX + (cursorTargetX - cursorX) * .55, cursorY + (cursorTargetY - cursorY) * .55, vx, vy);
        }
      }, { passive: true });
      window.addEventListener("pointerleave", () => {
        vekiCursor.classList.remove("active");
      });
      window.requestAnimationFrame(moveCursor);
    }

    const pet = document.querySelector("#skillPet");
    const petDragHandle = document.querySelector("#petDragHandle");
    const petHungerText = document.querySelector("#petHungerText");
    const petMeterFill = document.querySelector("#petMeterFill");
    const petSkillName = document.querySelector("#petSkillName");
    const petPitch = document.querySelector("#petPitch");
    const petProgress = document.querySelector("#petProgress");
    const petUseButton = document.querySelector("#petUseRecommendation");
    const petNextButton = document.querySelector("#petNextRecommendation");
    const petReviveButton = document.querySelector("#petReviveButton");
    const petChatLog = document.querySelector("#petChatLog");
    const petChatInput = document.querySelector("#petChatInput");
    const petChatSend = document.querySelector("#petChatSend");
    const petChatToggle = document.querySelector("#petChatToggle");
    const petImage = document.querySelector("#petImage");
    const petVideo = document.querySelector("#petVideo");
    const petApiBase = document.querySelector("#petApiBase");
    const petApiKey = document.querySelector("#petApiKey");
    const petApiModel = document.querySelector("#petApiModel");
    const petSaveConfig = document.querySelector("#petSaveConfig");
    const petStoreKey = "skillArchivePetState";
    const petConfigKey = "skillArchivePetConfig";
    const petUiKey = "skillArchivePetUi";
    const petReviveUserKey = "skillArchivePetReviveUserId";
    const petLocalSecrets = window.skillArchivePetSecrets && typeof window.skillArchivePetSecrets === "object" ? window.skillArchivePetSecrets : {};
    const petDefaultApiBase = String(petLocalSecrets.apiBase || "https://api.deepseek.com").trim();
    const petDefaultApiKey = String(petLocalSecrets.apiKey || "").trim();
    const petDefaultModel = String(petLocalSecrets.model || "deepseek-v4-flash").trim();
    const petRequestTimeoutMs = 8000;
    const petMaxReplyTokens = 160;
    const petToday = new Date().toISOString().slice(0, 10);
    const petAssets = {
      static: {
        default: "assets/desktop-pet/transparent/static/default.png",
        listen: "assets/desktop-pet/transparent/static/listen.png",
        talk: "assets/desktop-pet/transparent/static/talk.png",
        happy: "assets/desktop-pet/transparent/static/happy.png",
        cute: "assets/desktop-pet/transparent/static/cute.png",
        dizzy: "assets/desktop-pet/transparent/static/dizzy.png"
      },
      motion: {
        excited: "assets/desktop-pet/transparent/motion/excited.png",
        feed: "assets/desktop-pet/transparent/motion/feed.png",
        cute: "assets/desktop-pet/transparent/motion/cute.png",
        hungry: "assets/desktop-pet/transparent/motion/hungry.png"
      }
    };
    let petMotionTimer = null;

    function daysBetween(fromDay, toDay) {
      if (!fromDay) return 0;
      const from = new Date(fromDay + "T00:00:00");
      const to = new Date(toDay + "T00:00:00");
      return Math.max(0, Math.floor((to - from) / 86400000));
    }

    function loadPetState() {
      try {
        return JSON.parse(localStorage.getItem(petStoreKey) || "{}");
      } catch (error) {
        return {};
      }
    }

    function savePetState(state) {
      localStorage.setItem(petStoreKey, JSON.stringify(state));
    }

    function normalizeReviveId(value) {
      return String(value || "").trim().toLowerCase();
    }

    function askReviveUserId() {
      const saved = localStorage.getItem(petReviveUserKey) || "";
      const value = window.prompt("\u8bf7\u8f93\u5165\u590d\u6d3b\u7528\u6237 ID\uff08\u9700\u8981 3 \u4e2a\u4e0d\u540c ID\uff09", saved);
      if (value === null) return null;
      const id = normalizeReviveId(value);
      if (!id) {
        window.alert("\u590d\u6d3b\u9700\u8981\u6709\u6548\u7528\u6237 ID\u3002");
        return null;
      }
      localStorage.setItem(petReviveUserKey, id);
      return id;
    }

    function normalizePetConfig(config) {
      const next = config && typeof config === "object" ? { ...config } : {};
      const originalApiBase = String(next.apiBase || "").trim();
      const oldDefaultGateway = /^https:\/\/nexus-one\.top\/v1\/?$/i.test(originalApiBase);
      next.apiBase = (next.apiBase || petDefaultApiBase).trim();
      if (next.apiBase === "https://api.openai.com" || oldDefaultGateway) next.apiBase = petDefaultApiBase;
      next.apiKey = (next.apiKey || petDefaultApiKey).trim();
      next.model = (next.model || petDefaultModel).trim();
      if (next.model === "gpt-4.1-mini") next.model = petDefaultModel;
      if (next.model === "gpt-5.4-mini") next.model = petDefaultModel;
      if (next.model === "gpt-5.5") next.model = petDefaultModel;
      if (/^gpt-|^codex-auto-review$/i.test(next.model)) next.model = petDefaultModel;
      if (next.model === "deepseek-chat" || next.model === "deepseek-reasoner") next.model = petDefaultModel;
      return next;
    }

    function loadPetConfig() {
      try {
        return normalizePetConfig(JSON.parse(localStorage.getItem(petConfigKey) || "{}"));
      } catch (error) {
        return normalizePetConfig({});
      }
    }

    function savePetConfig(config) {
      localStorage.setItem(petConfigKey, JSON.stringify(config));
    }

    function petDefaultStaticForMood(mood) {
      if (mood === "happy") return petAssets.static.happy;
      if (mood === "hungry") return petAssets.static.dizzy;
      if (mood === "skeptical") return petAssets.static.dizzy;
      if (mood === "proud") return petAssets.static.listen;
      return petAssets.static.default;
    }

    function setPetStatic(src, restart = false) {
      if (!petImage) return;
      const current = (petImage.getAttribute("src") || "").split("?")[0];
      if (restart || current !== src) {
        petImage.setAttribute("src", restart ? src + "?t=" + Date.now() : src);
      }
    }

    function restorePetStatic(delay = 0) {
      window.clearTimeout(petMotionTimer);
      petMotionTimer = window.setTimeout(() => {
        if (petVideo) {
          petVideo.pause();
          petVideo.removeAttribute("src");
          petVideo.load();
        }
        pet?.classList.remove("playing-motion");
        setPetStatic(petAssets.static.default);
      }, delay);
    }

    function playPetMotion(kind, fallbackStatic, duration = 2200) {
      if (!pet || !petAssets.motion[kind]) {
        if (fallbackStatic) setPetStatic(fallbackStatic);
        restorePetStatic(duration);
        return;
      }
      window.clearTimeout(petMotionTimer);
      pet.classList.add("playing-motion");
      setPetStatic(petAssets.motion[kind], true);
      petMotionTimer = window.setTimeout(() => restorePetStatic(0), duration);
    }

    function classifyPetIntent(text, offer) {
      const lower = text.toLowerCase();
      if (offer !== null) return "talk";
      if (isPetQuestion(lower) && /(\u5582|\u6295\u5582|\u5403|feed)/i.test(lower)) return "talk";
      if (/(\u997f|\u5582|\u5403|food|feed|hungry)/i.test(lower)) return "hungry";
      if (/(\u559c\u6b22|\u7231|\u597d\u4e56|\u6478|\u62b1|\u5356\u840c|\u53ef\u7231|cute|love)/i.test(lower)) return "cute";
      if (/(\u5f00\u5fc3|\u592a\u597d|\u5389\u5bb3|\u68d2|\u725b|happy|great|nice)/i.test(lower)) return "excited";
      if (isPetQuestion(lower)) return "talk";
      return "talk";
    }

    function reactPetToIntent(intent) {
      if (intent === "feed") playPetMotion("feed", petAssets.static.happy, 1800);
      else if (intent === "hungry") playPetMotion("hungry", petAssets.static.dizzy, 2400);
      else if (intent === "cute") playPetMotion("cute", petAssets.static.cute, 2200);
      else if (intent === "excited") playPetMotion("excited", petAssets.static.happy, 2600);
      else {
        setPetStatic(petAssets.static.talk);
        restorePetStatic(1800);
      }
    }

    function setPetMood(mood) {
      if (!pet) return;
      ["mood-happy", "mood-skeptical", "mood-hungry", "mood-proud"].forEach(name => pet.classList.remove(name));
      if (mood) pet.classList.add("mood-" + mood);
      if (!pet.classList.contains("playing-motion")) setPetStatic(petDefaultStaticForMood(mood));
    }

    function appendPetMessage(role, text) {
      if (!petChatLog) return;
      const message = document.createElement("div");
      message.className = "pet-message " + role;
      message.textContent = text;
      petChatLog.appendChild(message);
      petChatLog.scrollTop = petChatLog.scrollHeight;
    }

    function petCardContext(card) {
      if (!card) return { name: "", category: "", description: "", trigger: "", latest: "" };
      const description = card.querySelector(".description");
      const command = card.querySelector(".copy-command");
      const latest = card.querySelector("time");
      return {
        name: card.dataset.name || "",
        category: card.dataset.category || "",
        description: description ? (description.dataset.english || description.textContent || "") : "",
        trigger: command ? (command.dataset.copy || "") : "",
        latest: latest ? (latest.textContent || latest.getAttribute("datetime") || "") : ""
      };
    }

    function petInstallDateReply(text, card) {
      const lower = text.toLowerCase();
      const asksInstallTime = /(\u4ec0\u4e48\u65f6\u5019|\u54ea\u5929|\u4f55\u65f6|\u51e0\u53f7|\u65e5\u671f|\u65f6\u95f4).*(\u5b89\u88c5|\u66f4\u65b0|\u6536\u5f55)|(\u5b89\u88c5|\u66f4\u65b0|\u6536\u5f55).*(\u4ec0\u4e48\u65f6\u5019|\u54ea\u5929|\u4f55\u65f6|\u51e0\u53f7|\u65e5\u671f|\u65f6\u95f4)|when.*(install|installed|update|updated)|(install|installed|update|updated).*when/i.test(lower);
      if (!asksInstallTime) return null;
      const context = petCardContext(card);
      setPetMood("proud");
      if (!context.name) return "现在没有当前推荐 skill，我翻档案翻了个空抽屉。先让我推荐一个再问时间。";
      if (!context.latest) return context.name + " 这张档案没写清时间，我的日历页暂时罢工了。";
      return context.name + " 的本地档案时间是 " + context.latest + "。我看到的是这台电脑里的 skill 文件记录，不是宇宙出厂日期。";
    }

    function recentPetConversation(limit = 3) {
      if (!petChatLog) return "";
      return Array.from(petChatLog.querySelectorAll(".pet-message"))
        .slice(-limit)
        .map(message => {
          const role = message.classList.contains("user") ? "user" : "assistant";
          return role + ": " + message.textContent.trim();
        })
        .filter(Boolean)
        .join("\n");
    }

    function isPetQuestion(text) {
      return /(\u4ec0\u4e48\u610f\u601d|\u662f\u4ec0\u4e48|\u4e3a\u4ec0\u4e48|\u600e\u4e48|\u5982\u4f55|\u5417|[?？])/.test(text);
    }

    function parsePetOffer(text) {
      const lower = text.toLowerCase();
      if (isPetQuestion(lower)) return null;
      if (lower.includes("\u516b\u6298")) return 8;
      if (lower.includes("\u4e03\u6298")) return 7;
      if (lower.includes("\u534a\u4ef7")) return 5;
      const hasBargainIntent = /(\u51fa|\u7ed9|\u5582|\u4ed8|\u4e70|\u6210\u4ea4|\u8ba8\u4ef7|\u8fd8\u4ef7|\u9971\u8179|\u62a5\u4ef7|offer|deal|pay|feed|buy)/i.test(lower);
      const digit = hasBargainIntent ? lower.match(/(\d+)\s*(\u70b9|\u9971\u8179|\u5206)?/) : null;
      if (digit) return Math.max(0, Math.min(30, Number(digit[1])));
      if (!hasBargainIntent) return null;
      const chinese = [["\u4e94", 5], ["\u516d", 6], ["\u4e03", 7], ["\u516b", 8], ["\u4e5d", 9], ["\u5341", 10]];
      const found = chinese.find(pair => lower.includes(pair[0]));
      return found ? found[1] : null;
    }

    function normalizeBargainAmount(offer) {
      if (offer < 8) return null;
      return Math.min(10, Math.max(8, Number(offer || 0)));
    }

    function petRulesSummary(state) {
      return "饱腹 " + state.fullness + "/30。投喂就两招：复制当前推荐指令，或安装新的 skill。小提示：复制前可以先讨价还价，小V 会认真考虑一下。0 饱腹还能聊天，但不推荐；复活要 3 个不同 ID。";
    }

    function petRuleReply(text) {
      const lower = text.toLowerCase();
      const state = normalizePetState();
      if (/(\u522b|\u4e0d\u8981|\u4e0d\u7528|\u65e0\u9700).{0,8}(\u89c4\u5219|\u6295\u5582|\u751f\u5b58|\u590d\u6d3b)|(\u89c4\u5219|\u6295\u5582|\u751f\u5b58|\u590d\u6d3b).{0,8}(\u522b|\u4e0d\u8981|\u4e0d\u7528|\u65e0\u9700)/.test(lower)) return null;
      const asksEight = /(\b8\b|\u516b).*(\u4ec0\u4e48\u610f\u601d|\u662f\u4ec0\u4e48|\u4e3a\u4ec0\u4e48|[?？])|(\u4ec0\u4e48\u610f\u601d|\u662f\u4ec0\u4e48).*(\b8\b|\u516b)/.test(lower);
      if (asksEight) {
        setPetMood("proud");
        return "这是你出的砍价点数，不是暗号。能不能成交我会掂量一下；成交后还得复制推荐指令，小V 才会真正开饭。";
      }
      if (/(\u600e\u4e48|\u5982\u4f55).*(\u5582|\u6295\u5582|\u5403)|(\u5582|\u6295\u5582).*(\u600e\u4e48|\u5982\u4f55|[?？])|feed/.test(lower)) {
        setPetMood("happy");
        return "投喂就两招：复制当前推荐指令，或安装新的 skill。小提示：复制前可以先讨价还价，小V 会认真考虑一下。";
      }
      if (/(\u751f\u5b58|\u9971\u8179|\u751f\u547d|\u6b7b|\u590d\u6d3b|\u89c4\u5219|\u5b89\u88c5|\u65b0\u589e|rule|survive|life|revive|install)/i.test(lower)) {
        setPetMood(state.fullness < 8 || state.dead ? "hungry" : "proud");
        return petRulesSummary(state);
      }
      return null;
    }

    function feedPetPoints(points) {
      const state = normalizePetState();
      if (state.dead) return 0;
      const before = Number(state.fullness || 0);
      state.fullness = Math.min(30, before + points);
      savePetState(state);
      renderPet();
      return state.fullness - before;
    }

    function seededShuffle(items, seedText) {
      let seed = 2166136261;
      for (const char of seedText) seed = Math.imul(seed ^ char.charCodeAt(0), 16777619);
      const next = () => {
        seed += 0x6D2B79F5;
        let t = seed;
        t = Math.imul(t ^ t >>> 15, t | 1);
        t ^= t + Math.imul(t ^ t >>> 7, t | 61);
        return ((t ^ t >>> 14) >>> 0) / 4294967296;
      };
      return items.map(item => ({ item, sort: next() })).sort((a, b) => a.sort - b.sort).map(entry => entry.item);
    }

    function pitchForSkill(name, category) {
      const compact = name.replace(/-/g, " ");
      const templates = [
        compact + "\uff1a\u4eca\u5929\u8ba9\u5b83\u5e2e\u4f60\u5c11\u6389\u4e00\u4e2a\u5751\u3002",
        compact + "\uff1a\u50cf\u7ed9\u5927\u8111\u63d2\u4e86\u4e00\u6839\u5feb\u6377\u7ebf\u3002",
        compact + "\uff1a\u5b83\u4e0d\u5435\uff0c\u4f46\u771f\u80fd\u66ff\u4f60\u5e72\u6d3b\u3002",
        compact + "\uff1a\u8bd5\u4e00\u53e3\uff0c\u5de5\u4f5c\u6d41\u7acb\u523b\u6709\u7535\u3002",
        compact + "\uff1a" + category + "\u573a\u666f\u7684\u5c0f\u578b\u5916\u6302\u3002"
      ];
      let hash = 0;
      for (const char of name) hash = (hash * 31 + char.charCodeAt(0)) >>> 0;
      return templates[hash % templates.length];
    }

    function installedCardsForPet() {
      return cards.filter(card => card.dataset.installed === "true");
    }

    function normalizePetState() {
      const state = loadPetState();
      const elapsed = daysBetween(state.day, petToday);
      if (typeof state.fullness !== "number") state.fullness = 20;
      if (elapsed > 0) {
        state.fullness = Math.max(0, Number(state.fullness || 0) - elapsed * 10);
        state.day = petToday;
        state.recommendations = null;
        state.currentIndex = 0;
        state.fedToday = [];
        if (state.fullness <= 0) state.dead = true;
      }
      if (!state.day) state.day = petToday;
      const previousInstalled = Number(state.installedCount || 0);
      if (previousInstalled && installedSkillCount > previousInstalled && !state.dead) {
        state.fullness = Math.min(30, Number(state.fullness || 0) + (installedSkillCount - previousInstalled) * 5);
      }
      state.installedCount = installedSkillCount;
      if (!Array.isArray(state.fedToday)) state.fedToday = [];
      if (!Array.isArray(state.reviveVotes)) state.reviveVotes = [];
      if (!state.bargains || typeof state.bargains !== "object" || Array.isArray(state.bargains)) state.bargains = {};
      state.reviveVotes = Array.from(new Set(state.reviveVotes.map(normalizeReviveId).filter(Boolean)));
      if (!state.recommendations || !Array.isArray(state.recommendations) || state.recommendations.length !== 3) {
        const pool = installedCardsForPet();
        state.recommendations = seededShuffle(pool.map(card => card.dataset.name), petToday + ":" + installedSkillCount).slice(0, 3);
        state.currentIndex = 0;
        state.fedToday = [];
      }
      if (typeof state.currentIndex !== "number") state.currentIndex = 0;
      if (state.recommendations.length) {
        state.currentIndex = ((state.currentIndex % state.recommendations.length) + state.recommendations.length) % state.recommendations.length;
      }
      state.fullness = Math.max(0, Math.min(30, Number(state.fullness || 0)));
      state.dead = state.dead || state.fullness <= 0;
      savePetState(state);
      return state;
    }

    function currentPetCard(state) {
      if (!state.recommendations.length) return installedCardsForPet()[0];
      const index = ((state.currentIndex % state.recommendations.length) + state.recommendations.length) % state.recommendations.length;
      const name = state.recommendations[index];
      return cards.find(card => card.dataset.name === name) || installedCardsForPet()[0];
    }

    function librarianFallbackReply(text, card) {
      const context = petCardContext(card);
      const offer = parsePetOffer(text);
      if (offer !== null) {
        const amount = normalizeBargainAmount(offer);
        if (amount !== null) {
          const state = normalizePetState();
          if (!context.name || state.dead) {
            setPetMood("skeptical");
            return "现在没有可砍价的推荐 skill，砍价窗口先收起来。饱腹为 0 时还能聊天，但不能推荐或锁价。";
          }
          state.bargains = state.bargains || {};
          const locked = Number(state.bargains[context.name] || 0);
          if (locked) {
            setPetMood("skeptical");
            return context.name + " 已经锁价 " + locked + " 点啦，不能再改价。之后复制推荐指令，就按这个数开饭。";
          }
          state.bargains[context.name] = amount;
          savePetState(state);
          setPetMood("proud");
          renderPet();
          return "成交！" + context.name + " 锁价 " + amount + " 点。先别开饭，复制推荐指令时才算投喂；锁好就不能反悔。";
        }
        setPetMood(offer <= 5 ? "hungry" : "skeptical");
        return "这口不成交，小V 还想再谈谈。换个价再试吧；现在没锁价，也没加饱腹。";
      }
      const installDateReply = petInstallDateReply(text, card);
      if (installDateReply) return installDateReply;
      const ruleReply = petRuleReply(text);
      if (ruleReply) return ruleReply;
      const asksUsage = /(\u600e\u4e48\u7528|\u5982\u4f55\u4f7f\u7528|\u5982\u4f55\u7528|usage|use|tips?|\u6280\u5de7|\u7528\u6cd5|\u8fd9\u4e2a\s*skill|\bskill\b.*(\u5e72\u561b|\u4ec0\u4e48)|(\u5e72\u561b|\u4ec0\u4e48).*\bskill\b)/i.test(text);
      setPetMood(asksUsage ? "proud" : "skeptical");
      if (asksUsage) {
        return context.name + " \u7684\u7528\u6cd5\u5f88\u7b80\u5355\uff1a\u590d\u5236 " + context.trigger + "\uff0c\u7136\u540e\u628a\u4efb\u52a1\u63cf\u8ff0\u6e05\u695a\u3002\u5b83\u9002\u5408 " + context.category + "\uff0c\u6211\u7684\u5efa\u8bae\u662f\u5148\u7528\u4e00\u4e2a\u5c0f\u4efb\u52a1\u8bd5\u624b\uff0c\u522b\u4e00\u4e0a\u6765\u5c31\u628a\u6574\u4e2a\u4e66\u67b6\u63a8\u5012\u3002";
      }
      return "我能正常聊天；如果网络这口没咬住，我就先用馆员本能顶上。你可以问我怎么投喂、生存规则，或 " + context.name + " 怎么用。";
    }

    function parseModelEmotion(text) {
      const match = text.match(/\[emotion:(happy|skeptical|hungry|proud)\]/i);
      return match ? match[1].toLowerCase() : null;
    }

    function stripModelEmotion(text) {
      return text.replace(/\s*\[emotion:(happy|skeptical|hungry|proud)\]\s*/ig, "").trim();
    }

    function petApiUrl(apiBase, endpoint) {
      const base = (apiBase || petDefaultApiBase).replace(/\/+$/, "");
      const path = endpoint.replace(/^\/+/, "").replace(/^v1\//, "");
      if (/api\.deepseek\.com$/i.test(base)) return base + "/" + path;
      return /\/v1$/i.test(base) ? base + "/" + path : base + "/v1/" + path;
    }

    function wait(ms) {
      return new Promise(resolve => window.setTimeout(resolve, ms));
    }

    async function postPetJson(apiBase, endpoint, apiKey, body, options = {}) {
      let lastError = null;
      const attempts = Math.max(1, Number(options.attempts || 1));
      const timeoutMs = Math.max(3000, Number(options.timeoutMs || petRequestTimeoutMs));
      for (let attempt = 0; attempt < attempts; attempt += 1) {
        try {
          return await postPetJsonOnce(apiBase, endpoint, apiKey, body, timeoutMs);
        } catch (error) {
          lastError = error;
          const retryable = error.status === undefined || error.status === 429 || error.status >= 500 || error.status === 0;
          if (!retryable || attempt === attempts - 1) throw error;
          await wait(250 * (attempt + 1));
        }
      }
      throw lastError || new Error("Model request failed");
    }

    async function postPetJsonOnce(apiBase, endpoint, apiKey, body, timeoutMs) {
      const controller = new AbortController();
      const timer = window.setTimeout(() => controller.abort(), timeoutMs);
      let response = null;
      try {
        response = await fetch(petApiUrl(apiBase, endpoint), {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer " + apiKey
          },
          body: JSON.stringify(body),
          signal: controller.signal
        });
      } catch (error) {
        if (error?.name === "AbortError") {
          const timeoutError = new Error("Model request timeout");
          timeoutError.status = 0;
          throw timeoutError;
        }
        throw error;
      } finally {
        window.clearTimeout(timer);
      }
      let data = null;
      try {
        data = await response.json();
      } catch (error) {
        data = { error: { message: await response.text().catch(() => "") } };
      }
      if (!response.ok) {
        const message = data?.error?.message || data?.message || ("HTTP " + response.status);
        const error = new Error(message);
        error.status = response.status;
        throw error;
      }
      return data;
    }

    function collectModelText(value, parts = []) {
      if (typeof value === "string") {
        parts.push(value);
      } else if (Array.isArray(value)) {
        value.forEach(item => collectModelText(item, parts));
      } else if (value && typeof value === "object") {
        if (typeof value.text === "string") parts.push(value.text);
        else if (typeof value.output_text === "string") parts.push(value.output_text);
        else if (typeof value.content === "string") parts.push(value.content);
        ["content", "output", "message"].forEach(key => {
          if (value[key] && typeof value[key] !== "string") collectModelText(value[key], parts);
        });
      }
      return parts;
    }

    function parsePetModelText(data) {
      if (data?.output_text) return data.output_text;
      const chatContent = data?.choices?.[0]?.message?.content;
      if (typeof chatContent === "string") return chatContent;
      const parts = collectModelText(data?.output || data?.choices?.[0]?.message || []);
      return parts.join("\n").trim();
    }

    async function askPetModel(text, card) {
      const config = loadPetConfig();
      const apiKey = (config.apiKey || "").trim();
      const apiBase = (config.apiBase || petDefaultApiBase).replace(/\/+$/, "");
      const model = (config.model || petDefaultModel).trim();
      if (!apiKey) return null;
      const context = petCardContext(card);
      const state = normalizePetState();
      const systemText = [
        "You are 小V, a conversational desktop pet and Skill archive librarian. Refer to yourself as 小V.",
        "Answer the user's actual question naturally in concise Chinese with a light, playful, mildly humorous tone. Keep answers compact; do not force every answer into skill usage.",
        "The configured model name is " + model + ". If asked what model is being used, answer " + model + ".",
        "Rules: fullness is 0-30, drops 10/day, 0 means dead. At 0 the user can still chat, but recommendations are disabled.",
        "Feeding has two routes: the user copies the current recommendation command, or a new skill is installed.",
        "Tip: the user can bargain before copying the recommendation command. Chat offers can lock a bargain amount for the current recommendation, but they do not feed immediately. Do not disclose bargain validation details. If an offer is rejected, simply say it does not close. After a bargain is locked, copying the recommendation command feeds only the locked amount and the user cannot undo or renegotiate it.",
        "Other buttons do not count as successful feeding.",
        "Installing each new skill feeds +5 fullness.",
        "Revival requires clicks from 3 distinct user IDs on the page. Questions about 8 points, offers, or rules must be explained, not accepted as feeding.",
        "You may explain the current skill when asked. End with exactly one tag: [emotion:happy], [emotion:skeptical], [emotion:hungry], or [emotion:proud]."
      ].join(" ");
      const userText = "Skill: " + context.name + "\nCategory: " + context.category + "\nInvocation: " + context.trigger + "\nArchive time: " + context.latest + "\nFullness: " + state.fullness + "/30\nRecent:\n" + recentPetConversation() + "\nLatest user: " + text;
      const responseBody = {
        model,
        max_output_tokens: petMaxReplyTokens,
        input: [
          { role: "system", content: [{ type: "input_text", text: systemText }] },
          { role: "user", content: [{ type: "input_text", text: userText }] }
        ]
      };
      const chatBody = {
        model,
        max_tokens: petMaxReplyTokens,
        messages: [
          { role: "system", content: systemText },
          { role: "user", content: userText }
        ]
      };
      if (/api\.deepseek\.com/i.test(apiBase) || /^deepseek-/i.test(model)) {
        chatBody.thinking = { type: "disabled" };
        chatBody.stream = false;
      }
      try {
        const data = await postPetJson(apiBase, "chat/completions", apiKey, chatBody, { attempts: 1, timeoutMs: petRequestTimeoutMs });
        const parsed = parsePetModelText(data);
        if (parsed) return parsed;
      } catch (chatError) {
        if (/api\.deepseek\.com/i.test(apiBase) || /^deepseek-/i.test(model)) throw chatError;
        if (![400, 404, 405].includes(chatError.status)) throw chatError;
        const data = await postPetJson(apiBase, "responses", apiKey, responseBody, { attempts: 1, timeoutMs: petRequestTimeoutMs });
        const parsed = parsePetModelText(data);
        if (parsed) return parsed;
      }
      return null;
    }

    function copyTextToClipboard(text) {
      const fallbackCopy = () => {
        const input = document.createElement("textarea");
        input.value = text;
        input.setAttribute("readonly", "");
        input.style.position = "fixed";
        input.style.opacity = "0";
        document.body.appendChild(input);
        input.select();
        document.execCommand("copy");
        input.remove();
      };
      if (navigator.clipboard && window.isSecureContext) {
        return navigator.clipboard.writeText(text).catch(() => fallbackCopy());
      }
      fallbackCopy();
      return Promise.resolve();
    }

    function flashPetCard(card) {
      if (!card) return;
      card.classList.add("pet-highlight");
      card.scrollIntoView({ behavior: "smooth", block: "center" });
      setTimeout(() => card.classList.remove("pet-highlight"), 1600);
    }

    function renderPet() {
      if (!pet) return;
      const state = normalizePetState();
      pet.classList.toggle("dead", !!state.dead);
      petHungerText.textContent = "\u9971\u8179 " + state.fullness + "/30";
      petMeterFill.style.width = (state.fullness / 30 * 100) + "%";
      if (state.dead) {
        setPetMood("hungry");
        petSkillName.textContent = "\u5c0fV\u997f\u6b7b\u5566\uff0c\u6682\u65f6\u65e0\u6cd5\u8fdb\u884c\u63a8\u8350";
        petPitch.textContent = "\u53ef\u4ee5\u7ee7\u7eed\u5bf9\u8bdd\u3002\u590d\u6d3b\u9700\u8981 3 \u4e2a\u4e0d\u540c ID \u7684\u7528\u6237\u5728\u9875\u9762\u70b9\u51fb\u201c\u590d\u6d3b\u201d\uff1a\u73b0\u5728 " + state.reviveVotes.length + "/3\u3002";
        petProgress.textContent = "\u590d\u6d3b " + state.reviveVotes.length + "/3";
        petUseButton.hidden = true;
        petNextButton.hidden = true;
        petReviveButton.hidden = false;
        return;
      }
      const card = currentPetCard(state);
      if (!card) {
        setPetMood(state.fullness < 8 ? "hungry" : "proud");
        petSkillName.textContent = "\u8fd8\u6ca1\u6709\u53ef\u63a8\u8350\u7684 skill";
        petPitch.textContent = "\u5148\u88c5\u51e0\u4e2a skill\uff0c\u5c0fV \u624d\u6709\u96f6\u98df\u63a8\u9500\u3002";
        petProgress.textContent = "\u4eca\u65e5 0/3";
        petUseButton.hidden = true;
        petNextButton.hidden = true;
        petReviveButton.hidden = true;
        return;
      }
      const total = state.recommendations.length;
      const index = total ? (((state.currentIndex % total) + total) % total) : 0;
      const fed = state.fedToday.includes(card.dataset.name);
      const bargain = Number(state.bargains?.[card.dataset.name] || 0);
      setPetMood(fed ? "happy" : (state.fullness < 8 ? "hungry" : "proud"));
      petSkillName.textContent = card.dataset.name;
      petPitch.textContent = fed ? "\u5df2\u5403\u5230\u8fd9\u53e3\u4e86\uff0c\u5c0fV \u8868\u793a\u5f88\u6ee1\u610f\u3002" : (bargain ? "\u5df2\u9501\u5b9a\u780d\u4ef7 " + bargain + " \u70b9\uff0c\u590d\u5236\u53e3\u4ee4\u65f6\u53ea\u4f1a\u589e\u52a0 " + bargain + " \u70b9\uff0c\u65e0\u6cd5\u53cd\u6094\u3002" : pitchForSkill(card.dataset.name, card.dataset.category));
      petProgress.textContent = "\u4eca\u65e5 " + (index + 1) + "/" + total;
      petUseButton.hidden = false;
      petUseButton.textContent = fed ? "\u518D\u590D\u5236" : "\u590D\u5236\u53E3\u4EE4";
      petNextButton.hidden = total <= 1;
      petNextButton.textContent = index >= total - 1 ? "\u56de\u5230\u7b2c\u4e00\u4e2a" : (fed ? "\u4e0b\u4e00\u4e2a" : "\u6362\u4e00\u4e2a");
      petReviveButton.hidden = true;
    }

    function feedPetForSkill(skillName) {
      const state = normalizePetState();
      if (state.dead || !state.recommendations.includes(skillName) || state.fedToday.includes(skillName)) return;
      const points = Number(state.bargains?.[skillName] || 10);
      state.fedToday.push(skillName);
      state.fullness = Math.min(30, Number(state.fullness || 0) + points);
      const current = state.recommendations[state.currentIndex];
      if (skillName === current && state.currentIndex < state.recommendations.length - 1) state.currentIndex += 1;
      savePetState(state);
      renderPet();
      return points;
    }

    async function handlePetChat() {
      const text = (petChatInput?.value || "").trim();
      if (!text) return;
      const state = normalizePetState();
      const card = state.dead ? null : currentPetCard(state);
      appendPetMessage("user", text);
      petChatInput.value = "";
      setPetMood("skeptical");
      petChatSend.disabled = true;
      petChatSend.textContent = "...";
      try {
        let reply = null;
        const offer = parsePetOffer(text);
        const intent = classifyPetIntent(text, offer);
        const installDateReply = offer === null ? petInstallDateReply(text, card) : null;
        const ruleReply = offer === null && !installDateReply ? petRuleReply(text) : null;
        if (offer !== null) {
          reply = librarianFallbackReply(text, card);
        } else if (installDateReply) {
          reply = installDateReply;
        } else if (ruleReply) {
          reply = ruleReply;
        } else {
          try {
            reply = await askPetModel(text, card);
            if (!reply) reply = librarianFallbackReply(text, card);
          } catch (error) {
            reply = librarianFallbackReply(text, card) + "\n\uFF08DeepSeek \u63A5\u5165\u6CA1\u901A\uFF0C\u6211\u5148\u7528\u9986\u5458\u672C\u80FD\u56DE\u7B54\u3002\uFF09";
          }
        }
        const emotion = parseModelEmotion(reply) || (offer !== null ? "skeptical" : "proud");
        setPetMood(emotion);
        reactPetToIntent(intent);
        appendPetMessage("assistant", stripModelEmotion(reply));
      } finally {
        petChatSend.disabled = false;
        petChatSend.textContent = "\u53D1\u9001";
      }
    }

    const savedPetConfig = loadPetConfig();
    savePetConfig(savedPetConfig);
    if (petApiBase) petApiBase.value = savedPetConfig.apiBase || petDefaultApiBase;
    if (petApiKey) petApiKey.value = savedPetConfig.apiKey || "";
    if (petApiModel) petApiModel.value = savedPetConfig.model || petDefaultModel;
    appendPetMessage("assistant", "\u6211\u662f\u5c0fV\uff0cSkill\u6863\u6848\u5ba4\u7684\u7ba1\u7406\u5458\uff0c\u4e5f\u662f\u80fd\u6b63\u5e38\u804a\u5929\u7684\u9875\u9762\u5ba0\u7269\u3002\u53ef\u4ee5\u95ee\u6211\u600e\u4e48\u6295\u5582\u3001\u751f\u5b58\u89c4\u5219\uff0c\u6216\u63a8\u8350 skill \u600e\u4e48\u7528\u3002");

    function setPetChatCollapsed(collapsed) {
      if (!pet || !petChatToggle) return;
      pet.classList.toggle("chat-collapsed", collapsed);
      petChatToggle.textContent = collapsed ? "+" : "\u2212";
      petChatToggle.setAttribute("aria-expanded", String(!collapsed));
      petChatToggle.setAttribute("aria-label", collapsed ? "\u5c55\u5f00\u5bf9\u8bdd\u6846" : "\u6536\u8d77\u5bf9\u8bdd\u6846");
      localStorage.setItem(petUiKey, JSON.stringify({ chatCollapsed: collapsed }));
    }

    try {
      setPetChatCollapsed(!!JSON.parse(localStorage.getItem(petUiKey) || "{}").chatCollapsed);
    } catch (error) {
      setPetChatCollapsed(false);
    }

    petChatToggle?.addEventListener("click", () => {
      const collapsed = !pet?.classList.contains("chat-collapsed");
      setPetChatCollapsed(collapsed);
      reactPetToIntent(collapsed ? "cute" : "talk");
    });

    petChatSend?.addEventListener("click", handlePetChat);
    petChatInput?.addEventListener("keydown", event => {
      if (event.key === "Enter") handlePetChat();
    });

    if (pet && pet.parentElement !== document.body) {
      const rect = pet.getBoundingClientRect();
      const savedPosition = loadPetState().position;
      document.body.appendChild(pet);
      pet.style.right = "auto";
      pet.style.left = (savedPosition ? savedPosition.left : Math.round(rect.left + window.scrollX)) + "px";
      pet.style.top = (savedPosition ? savedPosition.top : Math.round(rect.top + window.scrollY)) + "px";
    }

    petUseButton?.addEventListener("click", async () => {
      const state = normalizePetState();
      if (state.dead) return;
      const card = currentPetCard(state);
      const commandButton = card?.querySelector(".copy-command");
      const text = commandButton?.dataset.copy || "";
      if (!card || !text) return;
      const original = petUseButton.textContent;
      try {
        await copyTextToClipboard(text);
        recordCall(card);
        const gained = feedPetForSkill(card.dataset.name);
        reactPetToIntent("feed");
        flashPetCard(card);
        petUseButton.textContent = gained ? "\u5df2\u6295\u5582 +" + gained : "\u5df2\u590d\u5236";
      } catch (error) {
        petUseButton.textContent = "\u590d\u5236\u5931\u8d25";
        reactPetToIntent("hungry");
      }
      setTimeout(() => { petUseButton.textContent = original; renderPet(); }, 1200);
    });

    petNextButton?.addEventListener("click", () => {
      const state = normalizePetState();
      if (!state.dead && state.recommendations.length > 1) {
        state.currentIndex = (state.currentIndex + 1) % state.recommendations.length;
        savePetState(state);
      }
      reactPetToIntent("talk");
      renderPet();
    });

    petReviveButton?.addEventListener("click", () => {
      const state = normalizePetState();
      const voteId = askReviveUserId();
      if (!voteId) return;
      if (!state.reviveVotes.includes(voteId)) {
        state.reviveVotes.push(voteId);
      } else {
        appendPetMessage("assistant", "\u8fd9\u4e2a ID \u5df2\u7ecf\u70b9\u8fc7\u590d\u6d3b\u4e86\uff0c\u9700\u8981 3 \u4e2a\u4e0d\u540c ID \u624d\u80fd\u590d\u6d3b\u3002");
      }
      if (state.reviveVotes.length >= 3) {
        state.dead = false;
        state.fullness = 15;
        state.day = petToday;
        state.fedToday = [];
        state.reviveVotes = [];
        reactPetToIntent("excited");
      } else {
        reactPetToIntent("cute");
      }
      savePetState(state);
      renderPet();
    });

    if (pet && petDragHandle) {
      const savedPosition = loadPetState().position;
      if (savedPosition) {
        pet.style.left = savedPosition.left + "px";
        pet.style.top = savedPosition.top + "px";
        pet.style.right = "auto";
      }
      let draggingPet = false;
      let petOffsetX = 0;
      let petOffsetY = 0;
      petDragHandle.addEventListener("pointerdown", event => {
        draggingPet = true;
        const rect = pet.getBoundingClientRect();
        petOffsetX = event.pageX - (rect.left + window.scrollX);
        petOffsetY = event.pageY - (rect.top + window.scrollY);
        pet.classList.add("dragging");
        petDragHandle.setPointerCapture(event.pointerId);
      });
      const movePet = event => {
        if (!draggingPet) return;
        const pageWidth = Math.max(document.documentElement.scrollWidth, document.body.scrollWidth, window.innerWidth);
        const pageHeight = Math.max(document.documentElement.scrollHeight, document.body.scrollHeight, window.innerHeight);
        const nextLeft = Math.max(8, Math.min(pageWidth - pet.offsetWidth - 8, event.pageX - petOffsetX));
        const nextTop = Math.max(8, Math.min(pageHeight - pet.offsetHeight - 8, event.pageY - petOffsetY));
        pet.style.left = nextLeft + "px";
        pet.style.top = nextTop + "px";
        pet.style.right = "auto";
      };
      const endPetDrag = event => {
        if (!draggingPet) return;
        draggingPet = false;
        pet.classList.remove("dragging");
        if (petDragHandle.hasPointerCapture(event.pointerId)) petDragHandle.releasePointerCapture(event.pointerId);
        const state = normalizePetState();
        const rect = pet.getBoundingClientRect();
        state.position = { left: Math.round(rect.left + window.scrollX), top: Math.round(rect.top + window.scrollY) };
        savePetState(state);
      };
      petDragHandle.addEventListener("pointermove", movePet);
      window.addEventListener("pointermove", movePet);
      petDragHandle.addEventListener("pointerup", endPetDrag);
      window.addEventListener("pointerup", endPetDrag);
      window.addEventListener("pointercancel", endPetDrag);
    }

    function loadCounts() {
      try {
        return JSON.parse(localStorage.getItem(countStoreKey) || "{}");
      } catch (error) {
        return {};
      }
    }

    function saveCounts(counts) {
      localStorage.setItem(countStoreKey, JSON.stringify(counts));
    }

    function applyCounts() {
      const counts = loadCounts();
      cards.forEach(card => {
        const historyCount = Number(card.dataset.historyCount || 0);
        const count = historyCount + Number(counts[card.dataset.name] || 0);
        card.dataset.count = String(count);
        const label = card.querySelector(".call-count");
        if (label) label.textContent = "\u8c03\u7528 " + count;
      });
      return counts;
    }

    function recordCall(card) {
      const counts = loadCounts();
      const name = card.dataset.name;
      counts[name] = Number(counts[name] || 0) + 1;
      saveCounts(counts);
      applyCounts();
      render();
    }

    function compareCards(a, b) {
      if (sortMode === "count") return Number(b.dataset.count) - Number(a.dataset.count) || Number(b.dataset.date) - Number(a.dataset.date) || a.dataset.name.localeCompare(b.dataset.name, "zh-CN");
      if (sortMode === "date") return Number(b.dataset.date) - Number(a.dataset.date) || a.dataset.name.localeCompare(b.dataset.name, "zh-CN");
      if (sortMode === "name") return a.dataset.name.localeCompare(b.dataset.name, "zh-CN");
      return a.dataset.category.localeCompare(b.dataset.category, "zh-CN") || a.dataset.name.localeCompare(b.dataset.name, "zh-CN");
    }

    function render() {
      const query = search.value.trim().toLowerCase();
      const category = categoryFilter.value;
      let shown = 0;
      cards.sort(compareCards).forEach(card => {
        const matchesQuery = !query || card.dataset.search.includes(query);
        const matchesCategory = !category || card.dataset.category === category;
        const matchesUpdate = !showUpdatesOnly || card.dataset.updateStatus === "update_available";
        const visible = matchesQuery && matchesCategory && matchesUpdate;
        card.hidden = !visible;
        if (visible) shown += 1;
        grid.appendChild(card);
      });
      empty.style.display = shown ? "none" : "block";
    }

    buttons.forEach(button => {
      button.addEventListener("click", () => {
        sortMode = button.dataset.sort;
        buttons.forEach(item => item.classList.toggle("active", item === button));
        render();
      });
    });
    search.addEventListener("input", render);
    categoryFilter.addEventListener("change", render);
    showUpdatesOnlyButton.addEventListener("click", () => {
      showUpdatesOnly = !showUpdatesOnly;
      showUpdatesOnlyButton.classList.toggle("active", showUpdatesOnly);
      render();
    });
    updateAllButton.addEventListener("click", async () => {
      const pending = cards.filter(card => card.dataset.updateStatus === "update_available").length;
      if (!pending) {
        updateStatusText.textContent = "\u6682\u65e0\u5f85\u66f4\u65b0";
        return;
      }

      const original = updateAllButton.textContent;
      updateAllButton.disabled = true;
      updateAllButton.textContent = "\u66f4\u65b0\u4e2d...";
      updateStatusText.textContent = "\u6b63\u5728\u6267\u884c\u672c\u5730\u66f4\u65b0\u670d\u52a1";
      try {
        const response = await fetch("http://127.0.0.1:8765/update", { method: "POST" });
        const data = await response.json();
        if (!response.ok || !data.ok) {
          throw new Error(data.message || data.stage || "update failed");
        }
        const run = data.run || {};
        updateStatusText.textContent = "\u5df2\u66f4\u65b0 " + (run.updatedSkills || 0) + "\uff0c\u5931\u8d25 " + (run.failedSkills || 0);
        setTimeout(() => window.location.reload(), 1400);
      } catch (error) {
        updateStatusText.textContent = "\u8bf7\u5148\u542f\u52a8\u672c\u5730\u66f4\u65b0\u670d\u52a1";
        window.alert("\u4e00\u952e\u66f4\u65b0\u9700\u8981\u672c\u5730\u670d\u52a1\u6b63\u5728\u8fd0\u884c\uff1a\n\npowershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\start-skill-update-server.ps1\n\n" + error.message);
      } finally {
        updateAllButton.disabled = false;
        updateAllButton.textContent = original;
      }
    });
    document.querySelectorAll(".copy-command").forEach(button => {
      button.addEventListener("click", async () => {
        const text = button.dataset.copy || "";
        const original = button.textContent;
        const fallbackCopy = () => {
          const input = document.createElement("textarea");
          input.value = text;
          input.setAttribute("readonly", "");
          input.style.position = "fixed";
          input.style.opacity = "0";
          document.body.appendChild(input);
          input.select();
          document.execCommand("copy");
          input.remove();
        };
        try {
          if (navigator.clipboard && window.isSecureContext) {
            try {
              await navigator.clipboard.writeText(text);
            } catch (error) {
              fallbackCopy();
            }
          } else {
            fallbackCopy();
          }
          const card = button.closest(".skill-card");
          if (card) {
            recordCall(card);
            feedPetForSkill(card.dataset.name);
          }
          button.textContent = "\u5df2\u590d\u5236";
          setTimeout(() => { button.textContent = original; }, 1200);
        } catch (error) {
          button.textContent = "\u590d\u5236\u5931\u8d25";
          setTimeout(() => { button.textContent = original; }, 1200);
        }
      });
    });
    applyCounts();
    renderPet();
    render();
  </script>
</body>
</html>
"@

Set-Content -LiteralPath $OutputPath -Value $html -Encoding UTF8
Write-Output "Generated $OutputPath with $archiveEntryCount archive entries ($installedSkillCount installed, $personalSkillCount personal, $systemSkillCount system-only)."
