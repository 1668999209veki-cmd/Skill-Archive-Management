param(
  [string]$OutputPath = (Join-Path (Get-Location) "skill-archive.html")
)

$ErrorActionPreference = "Stop"

function T {
  param([string]$EntityText)
  return [System.Net.WebUtility]::HtmlDecode($EntityText)
}

function Get-ConfiguredPath {
  param(
    [string]$EnvName,
    [string]$Fallback
  )

  $value = [System.Environment]::GetEnvironmentVariable($EnvName)
  if ([string]::IsNullOrWhiteSpace($value)) { return $Fallback }
  return $value
}

function ConvertTo-PublicPath {
  param(
    [string]$Path,
    [array]$RootConfigs
  )

  foreach ($root in ($RootConfigs | Sort-Object { $_.Path.Length } -Descending)) {
    if ($Path.StartsWith($root.Path, [System.StringComparison]::OrdinalIgnoreCase)) {
      $relative = $Path.Substring($root.Path.Length).TrimStart("\", "/")
      if ($relative.Length -eq 0) { return $root.PublicPrefix }
      return ($root.PublicPrefix + "/" + ($relative -replace "\\", "/"))
    }
  }

  return "{{LOCAL_PATH}}"
}

$roots = @(
  # Fill these paths through environment variables when running on another machine.
  @{ Path = (Get-ConfiguredPath "SKILL_ARCHIVE_PROJECT_SKILLS_DIR" (Join-Path (Get-Location) "skills")); PublicPrefix = "{{PROJECT_SKILLS_DIR}}"; Label = (T "&#x4E2A;&#x4EBA;&#x6574;&#x7406;"); Rank = 0 },
  @{ Path = (Get-ConfiguredPath "SKILL_ARCHIVE_CODEX_SKILLS_DIR" (Join-Path $env:USERPROFILE ".codex\skills")); PublicPrefix = "{{CODEX_SKILLS_DIR}}"; Label = (T "Codex &#x5DF2;&#x5B89;&#x88C5;"); Rank = 1 },
  @{ Path = (Get-ConfiguredPath "SKILL_ARCHIVE_AGENTS_SKILLS_DIR" (Join-Path $env:USERPROFILE ".agents\skills")); PublicPrefix = "{{AGENTS_SKILLS_DIR}}"; Label = (T "Agents &#x5DF2;&#x5B89;&#x88C5;"); Rank = 2 }
)
$systemSkillsRoot = Join-Path $roots[1].Path ".system"
$codexAgentsRoot = Get-ConfiguredPath "SKILL_ARCHIVE_CODEX_AGENTS_DIR" (Join-Path $env:USERPROFILE ".codex\agents")
$agentBundleManifestPath = Get-ConfiguredPath "SKILL_ARCHIVE_AGENT_BUNDLES_FILE" (Join-Path (Split-Path -Parent $PSScriptRoot) "data\agent-bundles\agency-agents.json")

function Import-AgentBundleDefinitions {
  if (-not (Test-Path -LiteralPath $agentBundleManifestPath)) { return @() }

  try {
    $manifest = Get-Content -LiteralPath $agentBundleManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    return @($manifest.bundles)
  } catch {
    Write-Warning "Could not read agent bundle manifest: $($_.Exception.Message)"
    return @()
  }
}

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

function Get-FrontMatterText {
  param([string]$Content)

  $match = [regex]::Match($Content, "(?s)\A---\s*\r?\n(.*?)\r?\n---")
  if ($match.Success) { return $match.Groups[1].Value }
  return ""
}

function ConvertFrom-MetadataValue {
  param([AllowNull()][string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) { return @() }

  $text = $Value.Trim()
  if ($text -in @(">", ">-", "|", "|-")) { return @() }
  if ($text -match "^[A-Za-z0-9_.-]+\s*:\s*(.+)$") {
    $text = $Matches[1].Trim()
  }
  if ($text.StartsWith("[") -and $text.EndsWith("]")) {
    $text = $text.Substring(1, $text.Length - 2)
  }

  $parts = if ($text -match "[,;]") { $text -split "\s*[,;]\s*" } else { @($text) }
  return @($parts | ForEach-Object {
    $item = ([string]$_).Trim()
    $item = $item -replace '^[\s\-`"''\.,;\[\]\{\}\(\)]+', ''
    $item = $item -replace '[\s\-`"''\.,;\[\]\{\}\(\)]+$', ''
    $item = $item -replace "^\$", ""
    if ($item -match "^[A-Za-z0-9_.-]+\s*:\s*(.+)$") {
      $item = $Matches[1].Trim()
      $item = $item -replace '^[\s\-`"''\.,;\[\]\{\}\(\)]+', ''
      $item = $item -replace '[\s\-`"''\.,;\[\]\{\}\(\)]+$', ''
    }
    if ($item) { $item }
  } | Where-Object { $_ } | Select-Object -Unique)
}

function Get-MetadataList {
  param(
    [string]$Content,
    [string]$Key
  )

  $frontMatter = Get-FrontMatterText -Content $Content
  if ([string]::IsNullOrWhiteSpace($frontMatter)) { return @() }

  $lines = $frontMatter -split "\r?\n"
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = [string]$lines[$i]
    $match = [regex]::Match($line, "^(?<indent>\s*)$([regex]::Escape($Key))\s*:\s*(?<inline>.*)$")
    if (-not $match.Success) { continue }

    $indentLength = $match.Groups["indent"].Value.Length
    $inline = $match.Groups["inline"].Value.Trim()
    if (-not [string]::IsNullOrWhiteSpace($inline)) {
      return ConvertFrom-MetadataValue -Value $inline
    }

    $items = New-Object System.Collections.Generic.List[string]
    for ($j = $i + 1; $j -lt $lines.Count; $j++) {
      $next = [string]$lines[$j]
      if ([string]::IsNullOrWhiteSpace($next)) { continue }

      $nextIndent = ([regex]::Match($next, "^\s*").Value.Length)
      if ($nextIndent -le $indentLength) { break }

      $trimmed = $next.Trim()
      if ($trimmed -match "^-\s*(.+)$") {
        foreach ($item in (ConvertFrom-MetadataValue -Value $Matches[1])) { $items.Add($item) }
      } elseif ($trimmed -match "^[A-Za-z0-9_.-]+\s*:\s*(.+)$") {
        foreach ($item in (ConvertFrom-MetadataValue -Value $Matches[1])) { $items.Add($item) }
      }
    }

    return @($items | Where-Object { $_ } | Select-Object -Unique)
  }

  return @()
}

function Get-MetadataScalar {
  param(
    [string]$Content,
    [string]$Key
  )

  $items = @(Get-MetadataList -Content $Content -Key $Key)
  if ($items.Count -eq 0) { return "" }
  return [string]$items[0]
}

function Get-CleanRelationshipTarget {
  param([AllowNull()][string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
  $target = [System.Net.WebUtility]::HtmlDecode($Value).Trim()
  $pathMatch = [regex]::Match($target, '(?i)(?:^|[\\/])([^\\/]+)[\\/]SKILL\.md')
  if ($pathMatch.Success) { $target = $pathMatch.Groups[1].Value }
  $linkMatch = [regex]::Match($target, "\[([^\]]+)\]\([^)]+\)")
  if ($linkMatch.Success) { $target = $linkMatch.Groups[1].Value }
  $target = $target -replace "(?i)^\s*(?:Skill|Related Skill|Use)\s*:\s*", ""
  $target = $target -replace '^[\s`"''\.,;:\(\)\[\]\{\}<>]+', ''
  $target = $target -replace '[\s`"''\.,;:\(\)\[\]\{\}<>]+$', ''
  $target = $target -replace "^\$", ""
  if ($target -match "[\\/]") { $target = Split-Path -Leaf $target }
  if ($target.EndsWith(".md", [System.StringComparison]::OrdinalIgnoreCase)) {
    $target = [System.IO.Path]::GetFileNameWithoutExtension($target)
  }
  return $target.Trim()
}

function Resolve-SkillReference {
  param(
    [AllowNull()][string]$Value,
    [hashtable]$KnownNameByKey
  )

  $target = Get-CleanRelationshipTarget -Value $Value
  if ([string]::IsNullOrWhiteSpace($target)) { return $null }
  $key = $target.ToLowerInvariant()
  if ($KnownNameByKey.ContainsKey($key)) { return $KnownNameByKey[$key] }
  return $null
}

function Get-ExplicitSkillMentions {
  param(
    [string]$Content,
    [string]$CurrentName,
    [array]$KnownNames
  )

  $mentions = New-Object System.Collections.Generic.List[string]
  foreach ($name in $KnownNames) {
    if ([string]::IsNullOrWhiteSpace($name)) { continue }
    if ($name.Equals($CurrentName, [System.StringComparison]::OrdinalIgnoreCase)) { continue }

    $escaped = [regex]::Escape($name)
    $patterns = New-Object System.Collections.Generic.List[string]
    $patterns.Add("(?i)" + [regex]::Escape('`' + $name + '`'))
    $patterns.Add(('(?i)(?<![A-Za-z0-9_-])\$' + $escaped + '(?![A-Za-z0-9_-])'))
    $patterns.Add(('(?i)(?:Skill|Related Skill)\s*:\s*`?' + $escaped + '`?'))
    $patterns.Add(('(?i)[\\/]' + $escaped + '[\\/]SKILL\.md'))
    $patterns.Add(('(?i)\[[^\]]*' + $escaped + '[^\]]*\]\([^)]+\)'))
    if ($name.Length -ge 5) {
      $patterns.Add(('(?i)(?<![A-Za-z0-9_-])`?' + $escaped + '`?(?![A-Za-z0-9_-])'))
    }

    foreach ($pattern in $patterns) {
      if ([regex]::IsMatch($Content, $pattern)) {
        $mentions.Add($name)
        break
      }
    }
  }

  return @($mentions | Sort-Object -Unique)
}

function Get-FirstHeading {
  param([string]$Content)
  $match = [regex]::Match($Content, "(?m)^#\s+(.+?)\s*$")
  if ($match.Success) { return $match.Groups[1].Value.Trim() }
  return $null
}

function Get-SkillBodySearchTerms {
  param([string]$Content)

  if ([string]::IsNullOrWhiteSpace($Content)) { return @() }

  $body = $Content
  $frontMatter = [regex]::Match($body, "(?s)\A---\s*\r?\n.*?\r?\n---\s*")
  if ($frontMatter.Success) {
    $body = $body.Substring($frontMatter.Length)
  }
  $body = [regex]::Replace($body, '(?s)```.*?```', " ")

  $terms = New-Object System.Collections.Generic.List[string]
  foreach ($match in [regex]::Matches($body, "(?m)^\s{0,3}#{1,4}\s+(.+?)\s*$")) {
    $text = $match.Groups[1].Value.Trim()
    if ($text.Length -ge 3 -and $text.Length -le 90) { $terms.Add($text) }
  }
  foreach ($match in [regex]::Matches($body, "(?m)^\s*(?:[-*]|\d+\.)\s+(.+?)\s*$")) {
    $text = $match.Groups[1].Value.Trim()
    $text = $text -replace "`r|`n", " "
    if ($text.Length -ge 6 -and $text.Length -le 140) { $terms.Add($text) }
  }

  return @($terms | Select-Object -First 80 | Sort-Object -Unique)
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
function Get-GitHubRepositoryUrl {
  param([AllowNull()][string]$Text)

  if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
  $match = [regex]::Match($Text, "https://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)(?:\.git)?(?:/[A-Za-z0-9_./?=%#~:+-]+)?")
  if (-not $match.Success) { return "" }
  return "https://github.com/$($match.Groups[1].Value)/$($match.Groups[2].Value -replace '\\.git$', '')"
}

$packageSourceLinkCache = @{}
function Get-PackageSourceLink {
  param([string]$SkillPath)

  if ([string]::IsNullOrWhiteSpace($SkillPath)) { return "" }
  $directory = Split-Path -Parent $SkillPath
  for ($depth = 0; $depth -lt 5 -and -not [string]::IsNullOrWhiteSpace($directory); $depth++) {
    $cacheKey = $directory.ToLowerInvariant()
    if ($packageSourceLinkCache.ContainsKey($cacheKey)) { return $packageSourceLinkCache[$cacheKey] }

    foreach ($fileName in @("skill.json", "package.json", "README.md")) {
      $candidate = Join-Path $directory $fileName
      if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
      try {
        $text = (Get-Content -LiteralPath $candidate -Encoding UTF8 -TotalCount 320) -join "`n"
        $link = Get-GitHubRepositoryUrl -Text $text
        if ($link) {
          $packageSourceLinkCache[$cacheKey] = $link
          return $link
        }
      } catch {
      }
    }

    $packageSourceLinkCache[$cacheKey] = ""
    $parent = Split-Path -Parent $directory
    if ($parent -eq $directory) { break }
    $directory = $parent
  }

  return ""
}

function Get-RootPointerTargetPath {
  param(
    [string]$Content,
    [string]$SkillPath
  )

  if ($Content -notmatch "(?i)\broot pointer\b|\bprimary skill entry\b") { return "" }
  $match = [regex]::Match($Content, '(?im)^\s*`?((?:[A-Za-z0-9_.-]+[\\/])+SKILL\.md)`?\s*$')
  if (-not $match.Success) { return "" }

  $relative = $match.Groups[1].Value -replace "[\\/]", ([System.IO.Path]::DirectorySeparatorChar.ToString())
  $target = Join-Path (Split-Path -Parent $SkillPath) $relative
  if (Test-Path -LiteralPath $target -PathType Leaf) { return $target }
  return ""
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
    $contentLink = Get-GitHubRepositoryUrl -Text $sourceLine.Groups[1].Value.TrimEnd(".", ",", ")", "]", "`"")
    if ($contentLink) { return $contentLink }
  }

  $packageLink = Get-PackageSourceLink -SkillPath $SkillPath
  if ($packageLink) { return $packageLink }

  return "#local-skill-file"
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

  $namesByKey = @{}
  $escapedNames = New-Object System.Collections.Generic.List[string]
  foreach ($name in ($Names | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object Length -Descending -Unique)) {
    $namesByKey[$name.ToLowerInvariant()] = $name
    [void]$escapedNames.Add([regex]::Escape($name))
  }
  if ($escapedNames.Count -eq 0) { return $counts }
  $mentionPattern = [regex]::new("(?i)(?<![A-Za-z0-9_-])(" + ($escapedNames -join "|") + ")(?![A-Za-z0-9_-])")

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

      $mentionedNames = @{}
      foreach ($match in $mentionPattern.Matches($text)) {
        $key = $match.Groups[1].Value.ToLowerInvariant()
        if ($namesByKey.ContainsKey($key)) { $mentionedNames[$namesByKey[$key]] = $true }
      }
      foreach ($name in $mentionedNames.Keys) {
        $escaped = [regex]::Escape($name)
        $backtickedName = [regex]::Escape('`' + $name + '`')

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
$contentByRecordKey = @{}
$rootPointerRecordKeys = @{}
$sourceIndex = Import-SkillSourceIndex

foreach ($root in $roots) {
  if (-not (Test-Path -LiteralPath $root.Path)) { continue }

  Get-ChildItem -LiteralPath $root.Path -Recurse -Filter "SKILL.md" -Force | ForEach-Object {
    if ($_.FullName -match '(?i)[\\/][^\\/]+\.backup-[^\\/]+[\\/]SKILL\.md$') { return }

    $content = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
    $rootPointerTarget = Get-RootPointerTargetPath -Content $content -SkillPath $_.FullName
    $name = Get-FrontMatterValue -Content $content -Key "name"
    if (-not $name) { $name = Split-Path -Leaf $_.DirectoryName }
    if ($rootPointerTarget) {
      $rootPointerRecordKeys[$name.ToLowerInvariant()] = $true
      return
    }

    $description = Get-FrontMatterValue -Content $content -Key "description"
    if (-not $description) { $description = Get-FirstHeading -Content $content }
    if (-not $description) { $description = T "&#x672A;&#x5728; SKILL.md &#x4E2D;&#x5199;&#x660E;&#x529F;&#x80FD;&#x4ECB;&#x7ECD;&#x3002;" }

    $key = $name.ToLowerInvariant()
    $sourceKind = if ($root.Rank -eq 0) {
      "personal"
    } elseif ($root.Rank -eq 2) {
      "agents"
    } elseif ($_.FullName.StartsWith($systemSkillsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
      "system"
    } else {
      "codex"
    }
    $sourceLabel = if ($sourceKind -eq "system") { T "System &#x5DF2;&#x5B89;&#x88C5;" } else { $root.Label }
    $source = @{
      label = $sourceLabel
      path = ConvertTo-PublicPath -Path $_.FullName -RootConfigs $roots
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
        searchTerms = @(Get-SkillBodySearchTerms -Content $content)
        requires = @()
        recommends = @()
        precedes = @()
        inputs = @()
        outputs = @()
        relationshipSource = ""
        confidence = ""
        mentionedSkills = @()
        resourceKind = "skill"
        resourceLabel = "Skill"
        sources = New-Object System.Collections.Generic.List[object]
        latestTicks = $_.LastWriteTime.Ticks
        latest = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        preferredRank = $root.Rank
      }
    }

    $record = $recordsByName[$key]
    if (-not $contentByRecordKey.ContainsKey($key)) {
      $contentByRecordKey[$key] = $content
    }
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
      $record.searchTerms = @(Get-SkillBodySearchTerms -Content $content)
      $record.preferredRank = $root.Rank
      $contentByRecordKey[$key] = $content
    }
  }
}

foreach ($rootPointerKey in $rootPointerRecordKeys.Keys) {
  [void]$recordsByName.Remove($rootPointerKey)
  [void]$contentByRecordKey.Remove($rootPointerKey)
}

if (Test-Path -LiteralPath $codexAgentsRoot) {
  $installedAgentFiles = @(Get-ChildItem -LiteralPath $codexAgentsRoot -File -Filter "*.toml" -Force)
  foreach ($bundle in (Import-AgentBundleDefinitions)) {
    $bundleName = [string]$bundle.name
    if ([string]::IsNullOrWhiteSpace($bundleName)) { continue }

    $expectedNames = @{}
    foreach ($fileName in @($bundle.files)) {
      $baseName = [System.IO.Path]::GetFileName([string]$fileName)
      if (-not [string]::IsNullOrWhiteSpace($baseName)) {
        $expectedNames[$baseName.ToLowerInvariant()] = $true
      }
    }

    $matches = @($installedAgentFiles | Where-Object { $expectedNames.ContainsKey($_.Name.ToLowerInvariant()) })
    if ($matches.Count -eq 0) { continue }

    $newest = $matches | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $matchedCount = $matches.Count
    $key = $bundleName.ToLowerInvariant()
    if ($recordsByName.ContainsKey($key)) { continue }

    $bundleSources = New-Object System.Collections.Generic.List[object]
    $bundleSources.Add(@{
      label = T "Codex Agents &#x5DF2;&#x5B89;&#x88C5;"
      path = "{{CODEX_AGENTS_DIR}} ($matchedCount matched)"
      updated = $newest.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
      ticks = $newest.LastWriteTime.Ticks
      rank = 1
      kind = "codex-agent-bundle"
    })

    $recordsByName[$key] = @{
      name = $bundleName
      description = "$matchedCount Codex Agents detected. $([string]$bundle.description)"
      chineseDescription = "$(T '&#x5DF2;&#x68C0;&#x6D4B;&#x5230;') $matchedCount $(T '&#x4E2A; Codex Agents&#x3002;')$([string]$bundle.chineseDescription)"
      category = T "Agent &#x5408;&#x96C6;"
      link = [string]$bundle.link
      triggers = @(('$' + $bundleName), $bundleName)
      searchTerms = @($matches | ForEach-Object { $_.BaseName })
      requires = @()
      recommends = @()
      precedes = @()
      inputs = @()
      outputs = @()
      relationshipSource = "manifest"
      confidence = "1"
      mentionedSkills = @()
      resourceKind = "agents"
      resourceLabel = T "Agents &#x96C6;&#x7FA4;"
      sources = $bundleSources
      latestTicks = $newest.LastWriteTime.Ticks
      latest = $newest.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
      preferredRank = 1
    }
  }
}

$knownNameByKey = @{}
foreach ($record in $recordsByName.Values) {
  $knownNameByKey[[string]$record.name.ToLowerInvariant()] = [string]$record.name
}
$knownSkillNames = @($recordsByName.Values | Where-Object { $_.resourceKind -eq "skill" } | ForEach-Object { [string]$_.name } | Sort-Object -Unique)

foreach ($record in $recordsByName.Values) {
  if ($record.resourceKind -ne "skill") { continue }

  $recordKey = [string]$record.name.ToLowerInvariant()
  $content = if ($contentByRecordKey.ContainsKey($recordKey)) { [string]$contentByRecordKey[$recordKey] } else { "" }
  $record.requires = @(Get-MetadataList -Content $content -Key "requires")
  $record.recommends = @(Get-MetadataList -Content $content -Key "recommends")
  $record.precedes = @(Get-MetadataList -Content $content -Key "precedes")
  $record.inputs = @(Get-MetadataList -Content $content -Key "inputs")
  $record.outputs = @(Get-MetadataList -Content $content -Key "outputs")
  $record.relationshipSource = Get-MetadataScalar -Content $content -Key "relationshipSource"
  $record.confidence = Get-MetadataScalar -Content $content -Key "confidence"
  $record.mentionedSkills = @(Get-ExplicitSkillMentions -Content $content -CurrentName $record.name -KnownNames $knownSkillNames)
}

$relationships = New-Object System.Collections.Generic.List[object]
foreach ($record in $recordsByName.Values) {
  $sourceName = [string]$record.name
  $metadataSource = if ($record.relationshipSource) { [string]$record.relationshipSource } else { "metadata" }
  $metadataConfidence = if ($record.confidence) { [string]$record.confidence } else { "1" }

  foreach ($relationType in @("requires", "recommends", "precedes")) {
    foreach ($rawTarget in @($record[$relationType])) {
      $cleanTarget = Get-CleanRelationshipTarget -Value $rawTarget
      if ([string]::IsNullOrWhiteSpace($cleanTarget)) { continue }

      $resolvedSkill = Resolve-SkillReference -Value $rawTarget -KnownNameByKey $knownNameByKey
      $targetName = if ($resolvedSkill) { $resolvedSkill } else { $cleanTarget }
      if ($targetName.Equals($sourceName, [System.StringComparison]::OrdinalIgnoreCase)) { continue }

      $relationships.Add([ordered]@{
        source = $sourceName
        target = $targetName
        type = $relationType
        targetKind = if ($resolvedSkill) { "skill" } else { "external" }
        relationshipSource = $metadataSource
        confidence = $metadataConfidence
      })
    }
  }

  foreach ($mentionedSkill in @($record.mentionedSkills)) {
    if ([string]::IsNullOrWhiteSpace($mentionedSkill)) { continue }
    $relationships.Add([ordered]@{
      source = $sourceName
      target = [string]$mentionedSkill
      type = "mentions"
      targetKind = "skill"
      relationshipSource = "SKILL.md explicit mention"
      confidence = "0.7"
    })
  }
}

$records = @($recordsByName.Values | Sort-Object @{ Expression = "latestTicks"; Descending = $true }, "name")
$lastUpdatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$archiveEntryCount = $records.Count
$agentResourceCount = @($records | Where-Object { $_.resourceKind -eq "agents" }).Count
$skillResourceCount = $archiveEntryCount - $agentResourceCount
$installedSkillCount = @($records | Where-Object {
  $sourceKinds = @($_.sources | ForEach-Object { $_.kind })
  $sourceKinds -contains "codex" -or $sourceKinds -contains "agents" -or $sourceKinds -contains "codex-agent-bundle"
}).Count
$personalSkillCount = @($records | Where-Object {
  @($_.sources | ForEach-Object { $_.kind }) -contains "personal"
}).Count
$systemSkillCount = @($records | Where-Object {
  $sourceKinds = @($_.sources | ForEach-Object { $_.kind })
  ($sourceKinds -contains "system") -and -not ($sourceKinds -contains "codex") -and -not ($sourceKinds -contains "agents") -and -not ($sourceKinds -contains "personal")
}).Count
$historicalCounts = Get-HistoricalSkillCounts -Names @($records | ForEach-Object { $_["name"] })
$updateReportPath = Join-Path (Join-Path (Get-Location) "reports") "skill-update-report.json"
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
    Write-Warning "Could not read reports/skill-update-report.json: $($_.Exception.Message)"
  }
}
$pendingUpdateCount = $pendingSkillNames.Count
$relationships = @($relationships | Sort-Object { $_["source"] }, { $_["type"] }, { $_["target"] }, { $_["relationshipSource"] } -Unique)
$relationshipData = [ordered]@{
  generatedAt = $lastUpdatedAt
  metadataFields = @("requires", "recommends", "precedes", "inputs", "outputs", "relationshipSource", "confidence")
  records = @($records | ForEach-Object {
    [ordered]@{
      name = [string]$_.name
      resourceKind = [string]$_.resourceKind
      requires = @($_.requires)
      recommends = @($_.recommends)
      precedes = @($_.precedes)
      inputs = @($_.inputs)
      outputs = @($_.outputs)
      relationshipSource = [string]$_.relationshipSource
      confidence = [string]$_.confidence
      mentionedSkills = @($_.mentionedSkills)
    }
  })
  relationships = @($relationships)
}
$relationshipJson = $relationshipData | ConvertTo-Json -Depth 10 -Compress
$relationshipOutputPath = Join-Path (Split-Path -Parent $OutputPath) "skill-relationships.json"
$relationshipData | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $relationshipOutputPath -Encoding UTF8
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
  $resourceKind = if ($record.resourceKind) { [string]$record.resourceKind } else { "skill" }
  $resourceLabel = if ($record.resourceLabel) { [string]$record.resourceLabel } else { "Skill" }
  $resourceClass = "resource-$resourceKind"
  $updateBadgeLine = ""
  if ($updateStatus -eq "update_available") {
    $updateBadgeLine = "          <span class=""update-badge update-needed"" title=""$(ConvertTo-HtmlText $updateRepo)&#10;$(ConvertTo-HtmlText $updateMessage)"">&#x5F85;&#x66F4;&#x65B0;</span>"
  }
  $sourceKinds = @($record.sources | ForEach-Object { $_.kind })
  $isInstalled = ($sourceKinds -contains "codex") -or ($sourceKinds -contains "agents") -or ($sourceKinds -contains "system") -or ($sourceKinds -contains "codex-agent-bundle")
  $displaySources = @($record.sources | Sort-Object rank,label,path | Group-Object { $_.kind + "|" + $_.label } | ForEach-Object {
    $_.Group | Select-Object -First 1
  })
  $sources = ($displaySources | ForEach-Object {
    "<span class=""source"">$(ConvertTo-HtmlText $_.label)</span>"
  }) -join " "
  $paths = ($displaySources | ForEach-Object {
    "<div class=""path"">$(ConvertTo-HtmlText $_.path)</div>"
  }) -join ""
  @"
      <article class="skill-card $resourceClass$updateClass" data-name="$(ConvertTo-HtmlText $record.name)" data-resource-kind="$(ConvertTo-HtmlText $resourceKind)" data-resource-label="$(ConvertTo-HtmlText $resourceLabel)" data-category="$(ConvertTo-HtmlText $record.category)" data-date="$($record.latestTicks)" data-history-count="$historyCount" data-count="$historyCount" data-installed="$($isInstalled.ToString().ToLowerInvariant())" data-update-status="$(ConvertTo-HtmlText $updateStatus)" data-update-repo="$(ConvertTo-HtmlText $updateRepo)" data-update-url="$(ConvertTo-HtmlText $updateUrl)" data-search-primary="$(ConvertTo-HtmlText (($record.name + ' ' + $record.description + ' ' + $record.chineseDescription + ' ' + $record.category + ' ' + $resourceLabel + ' ' + ($record.triggers -join ' ')).ToLowerInvariant()))" data-search="$(ConvertTo-HtmlText (($record.name + ' ' + $record.description + ' ' + $record.chineseDescription + ' ' + $record.category + ' ' + $resourceLabel + ' ' + ($record.triggers -join ' ')).ToLowerInvariant()))">
        <div class="card-top">
          <div>
            <h2><a class="skill-link" href="$skillLink" target="_blank" rel="noreferrer">$(ConvertTo-HtmlText $record.name)</a></h2>
            <p class="description" title="$englishDescription" data-english="$englishDescription">$chineseDescription</p>
          </div>
          <time datetime="$(ConvertTo-HtmlText $record.latest)">$(ConvertTo-HtmlText $record.latest)</time>
        </div>
        <div class="meta">
          <span class="resource-badge $resourceClass">$(ConvertTo-HtmlText $resourceLabel)</span>
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
$relationshipTypes = @($relationships | Group-Object { $_["type"] } | Sort-Object Name | ForEach-Object { $_.Name })
$relationshipTypeOptions = ($relationshipTypes | ForEach-Object { "<option value=""$(ConvertTo-HtmlText $_)"">$(ConvertTo-HtmlText $_)</option>" }) -join "`n"
$relationshipRows = foreach ($relationship in $relationships) {
  $relSource = [string]$relationship["source"]
  $relType = [string]$relationship["type"]
  $relTarget = [string]$relationship["target"]
  $relTargetKind = [string]$relationship["targetKind"]
  $relRelationshipSource = [string]$relationship["relationshipSource"]
  $relConfidence = [string]$relationship["confidence"]
  $targetClass = if ($relTargetKind -eq "skill") { "target-skill" } else { "target-external" }
  $searchText = (($relSource + " " + $relType + " " + $relTarget + " " + $relTargetKind + " " + $relRelationshipSource) -join " ").ToLowerInvariant()
  @"
          <tr data-relation-row data-relation-type="$(ConvertTo-HtmlText $relType)" data-relation-search="$(ConvertTo-HtmlText $searchText)">
            <td><code>$(ConvertTo-HtmlText $relSource)</code></td>
            <td><span class="relation-type">$(ConvertTo-HtmlText $relType)</span></td>
            <td><code class="$targetClass">$(ConvertTo-HtmlText $relTarget)</code></td>
            <td>$(ConvertTo-HtmlText $relTargetKind)</td>
            <td>$(ConvertTo-HtmlText $relRelationshipSource)</td>
            <td>$(ConvertTo-HtmlText $relConfidence)</td>
          </tr>
"@
}

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
      grid-template-columns: repeat(6, minmax(0, 1fr));
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
    .stat.agents strong {
      color: #ffe4a8;
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
    .toolbar.has-task-results {
      position: relative;
      top: auto;
      z-index: 2;
    }
    .tools {
      display: grid;
      grid-template-columns: minmax(260px, 1fr) minmax(180px, 220px) minmax(300px, 380px);
      grid-template-areas:
        "search resource category"
        "sorts sorts updates";
      gap: 8px;
      align-items: center;
      padding: 12px 0;
    }
    .task-advisor {
      padding: 12px 0 0;
    }
    .task-advisor-label {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 8px;
      color: var(--accent-ink);
      font-size: 13px;
      font-weight: 750;
    }
    .task-advisor-label::before {
      content: "";
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--accent);
      box-shadow: 0 0 18px rgba(var(--accent-rgb), .68);
    }
    .task-advisor-row {
      display: grid;
      grid-template-columns: minmax(0, 1fr) max-content;
      gap: 8px;
      align-items: stretch;
    }
    #taskAdvisorInput {
      min-height: 66px;
      max-height: 160px;
      resize: vertical;
      line-height: 1.45;
    }
    .task-advisor-run {
      min-width: 112px;
      border-color: rgba(var(--accent-rgb), .34);
      background: rgba(var(--accent-rgb), .14);
      color: var(--accent-ink);
      font-weight: 750;
    }
    .task-advisor-output {
      display: grid;
      gap: 10px;
      margin-top: 8px;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      background: rgba(9, 17, 29, .9);
      padding: 12px;
      box-shadow: inset 0 1px 0 rgba(255,255,255,.04);
    }
    .task-advisor-output[hidden] {
      display: none;
    }
    .task-search-progress {
      display: flex;
      align-items: center;
      gap: 10px;
      min-height: 54px;
      padding: 12px;
      border: 1px solid rgba(var(--accent-rgb), .24);
      color: var(--muted);
    }
    .task-search-spinner {
      width: 18px;
      height: 18px;
      flex: 0 0 auto;
      border: 2px solid rgba(var(--accent-rgb), .18);
      border-top-color: var(--accent);
      border-radius: 50%;
      animation: task-search-spin .8s linear infinite;
    }
    @keyframes task-search-spin { to { transform: rotate(360deg); } }
    .task-advisor-summary {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 12px;
      color: var(--muted);
      font-size: 13px;
    }
    .task-advisor-summary strong {
      display: block;
      margin-bottom: 4px;
      color: var(--text);
      font-size: 14px;
    }
    .task-advisor-summary span {
      overflow-wrap: anywhere;
    }
    .task-advisor-list {
      display: grid;
      gap: 8px;
    }
    .task-recommendation {
      border: 1px solid rgba(92, 236, 255, .14);
      border-radius: var(--radius);
      background: rgba(13, 23, 38, .72);
      padding: 11px;
    }
    .task-rec-head {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 10px;
    }
    .task-rec-title {
      display: flex;
      flex-wrap: wrap;
      gap: 7px;
      align-items: center;
      min-width: 0;
    }
    .task-rec-rank,
    .task-score {
      font-family: "Cascadia Code", Consolas, monospace;
      font-size: 12px;
    }
    .task-rec-rank {
      border: 1px solid rgba(var(--accent-rgb), .24);
      border-radius: var(--radius);
      padding: 2px 6px;
      color: var(--accent-ink);
      background: rgba(var(--accent-rgb), .12);
    }
    .task-rec-name {
      color: var(--text);
      font-weight: 760;
      overflow-wrap: anywhere;
    }
    .task-score {
      color: var(--muted);
      white-space: nowrap;
    }
    .task-rec-meta {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
      margin-top: 8px;
    }
    .task-rec-meta span {
      border: 1px solid rgba(145, 168, 186, .16);
      border-radius: var(--radius);
      padding: 3px 7px;
      color: var(--muted);
      font-size: 12px;
      background: rgba(5, 7, 13, .34);
    }
    .task-rec-section {
      margin-top: 9px;
      color: var(--muted);
      font-size: 12px;
      line-height: 1.5;
    }
    .task-rec-section strong {
      color: var(--text);
      font-weight: 700;
    }
    .task-rec-section ul {
      margin: 5px 0 0;
      padding-left: 18px;
    }
    .task-rec-missing {
      color: #ffe4a8;
    }
    .task-copy-row {
      display: grid;
      grid-template-columns: minmax(0, 1fr) max-content;
      gap: 8px;
      margin-top: 9px;
      align-items: stretch;
    }
    .task-copy-text {
      min-height: 42px;
      border: 1px solid rgba(145, 168, 186, .16);
      border-radius: var(--radius);
      padding: 9px 10px;
      color: var(--code);
      background: rgba(5, 7, 13, .42);
      font-family: "Cascadia Code", Consolas, monospace;
      font-size: 12px;
      line-height: 1.45;
      overflow-wrap: anywhere;
    }
    .task-copy-button,
    .task-copy-all {
      border-color: rgba(var(--accent-rgb), .24);
      color: var(--accent-ink);
      background: rgba(var(--accent-rgb), .10);
      white-space: nowrap;
    }
    .task-advisor-empty {
      color: var(--muted);
      font-size: 13px;
      line-height: 1.5;
    }
    .task-report-actions {
      display: flex;
      justify-content: flex-end;
      gap: 8px;
    }
    .task-report {
      margin: 0;
      white-space: pre-wrap;
      overflow-wrap: anywhere;
      border: 1px solid rgba(145, 168, 186, .16);
      border-radius: var(--radius);
      background: rgba(5, 7, 13, .42);
      color: var(--text);
      padding: 12px;
      font-family: "Microsoft YaHei UI", "Segoe UI", system-ui, sans-serif;
      font-size: 13px;
      line-height: 1.65;
    }
    .task-resource-heading {
      margin: 4px 0 0;
      color: var(--text);
      font-size: 14px;
      font-weight: 760;
    }
    .task-resource-heading-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      margin-top: 4px;
    }
    .task-resource-heading-row .task-resource-heading {
      margin: 0;
    }
    .task-resource-heading-action {
      min-height: 34px;
      border: 1px solid rgba(var(--accent-rgb), .24);
      border-radius: var(--radius);
      padding: 7px 10px;
      color: var(--accent-ink);
      background: rgba(var(--accent-rgb), .10);
      font: inherit;
      font-size: 12px;
      cursor: pointer;
      white-space: nowrap;
    }
    .task-relationship-summary {
      border: 1px solid rgba(var(--accent-rgb), .20);
      border-radius: var(--radius);
      background: rgba(5, 7, 13, .38);
      padding: 10px 12px;
      color: var(--muted);
      font-size: 13px;
      line-height: 1.55;
    }
    .task-relationship-summary > strong,
    .task-relationship-summary .development-order > strong {
      display: block;
      margin-bottom: 4px;
      color: var(--text);
    }
    .task-relationship-summary .development-order {
      display: block;
      margin-top: 6px;
      color: var(--text);
    }
    .task-relationship-summary .development-order-line + .development-order-line {
      margin-top: 4px;
    }
    .task-relationship-summary .development-order-line strong {
      display: inline;
      margin: 0;
      color: var(--text);
    }
    .github-text-list {
      display: grid;
      gap: 8px;
      margin-top: 10px;
    }
    .github-text-item {
      border-bottom: 1px solid rgba(92, 236, 255, .14);
      padding: 0 0 8px;
      line-height: 1.65;
      color: var(--muted);
    }
    .github-text-item:last-child {
      border-bottom: 0;
      padding-bottom: 0;
    }
    .github-text-item a {
      color: var(--accent);
      font-weight: 800;
    }
    .task-resource-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 10px;
    }
    .task-resource-list {
      display: grid;
      grid-template-columns: minmax(0, 1fr);
      gap: 10px;
      width: 100%;
    }
    .task-resource-group {
      display: grid;
      gap: 8px;
    }
    .task-resource-group + .task-resource-group {
      margin-top: 12px;
    }
    .task-resource-group-title {
      color: var(--muted);
      font-size: 12px;
      font-weight: 700;
    }
    .task-resource-card {
      display: grid;
      grid-template-columns: minmax(220px, .85fr) minmax(0, 1.6fr) max-content;
      gap: 12px 20px;
      align-items: start;
      border: 1px solid rgba(92, 236, 255, .16);
      border-radius: var(--radius);
      background: rgba(13, 23, 38, .74);
      padding: 12px;
    }
    .task-resource-card > .task-resource-top {
      grid-column: 1;
      grid-row: 1;
    }
    .task-resource-card > .task-resource-block {
      grid-column: 2;
    }
    .task-resource-card > .task-resource-description {
      grid-column: 2;
      margin: 0;
      color: var(--muted);
      font-size: 13px;
      line-height: 1.55;
    }
    .task-resource-card > .task-card-actions {
      grid-column: 3;
      grid-row: 1;
      align-self: center;
      justify-content: flex-end;
    }
    @media (max-width: 760px) {
      .task-resource-card {
        grid-template-columns: minmax(0, 1fr);
      }
      .task-resource-card > .task-resource-top,
      .task-resource-card > .task-resource-block,
      .task-resource-card > .task-resource-description,
      .task-resource-card > .task-card-actions {
        grid-column: auto;
        grid-row: auto;
      }
      .task-resource-card > .task-card-actions {
        justify-content: flex-start;
      }
    }
    .task-resource-card.selected {
      border-color: rgba(var(--accent-rgb), .42);
      background: linear-gradient(135deg, rgba(52, 231, 255, .10), rgba(13, 23, 38, .78));
    }
    .task-resource-card.uninstalled,
    .task-resource-card.external {
      border-color: rgba(255, 200, 87, .34);
      background: linear-gradient(135deg, rgba(255, 200, 87, .10), rgba(13, 23, 38, .78));
    }
    .match-highlight {
      background: #ffe06a;
      color: #101722;
      border-radius: 2px;
      padding: 0 1px;
    }
    .install-result-grid {
      display: grid;
      grid-template-columns: minmax(0, 1fr);
      gap: 10px;
    }
    .install-result-card {
      width: 100%;
      box-sizing: border-box;
    }
    .install-progress-card {
      display: grid;
      gap: 12px;
      border: 1px solid rgba(var(--accent-rgb), .4);
      border-radius: var(--radius);
      background: rgba(13, 23, 38, .78);
      padding: 14px;
    }
    .install-progress-card.failed {
      border-color: rgba(255, 93, 112, .55);
    }
    .install-progress-head,
    .install-progress-meta {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
    }
    .install-progress-head strong {
      overflow-wrap: anywhere;
    }
    .install-progress-badge {
      flex: 0 0 auto;
      border: 1px solid rgba(var(--accent-rgb), .38);
      border-radius: 4px;
      padding: 3px 7px;
      color: var(--accent-ink);
      font-size: 12px;
      font-weight: 750;
    }
    .install-progress-card.failed .install-progress-badge {
      border-color: rgba(255, 93, 112, .6);
      color: #ffb3bd;
    }
    .install-progress-track {
      height: 8px;
      overflow: hidden;
      border: 1px solid rgba(145, 168, 186, .22);
      border-radius: 4px;
      background: rgba(5, 7, 13, .72);
    }
    .install-progress-fill {
      height: 100%;
      width: 0;
      background: var(--accent);
      transition: width .35s ease;
    }
    .install-progress-card.failed .install-progress-fill {
      background: var(--danger);
    }
    .install-progress-meta {
      color: var(--muted);
      font-size: 12px;
    }
    .install-progress-message {
      margin: 0;
      color: var(--muted);
      line-height: 1.5;
    }
    .install-progress-actions {
      display: flex;
      justify-content: flex-end;
    }
    .task-resource-top {
      display: flex;
      justify-content: space-between;
      gap: 10px;
      align-items: flex-start;
    }
    .task-resource-title {
      display: grid;
      gap: 5px;
      min-width: 0;
    }
    .task-resource-title strong {
      color: var(--text);
      overflow-wrap: anywhere;
    }
    .task-resource-name-link {
      color: inherit;
      text-decoration: none;
      border-bottom: 1px solid transparent;
    }
    .task-resource-name-link:hover,
    .task-resource-name-link:focus-visible {
      color: var(--accent);
      border-bottom-color: currentColor;
      outline: none;
    }
    .task-resource-badges {
      display: flex;
      flex-wrap: wrap;
      gap: 5px;
    }
    .task-resource-badges span {
      border: 1px solid rgba(145, 168, 186, .16);
      border-radius: var(--radius);
      padding: 2px 6px;
      color: var(--muted);
      background: rgba(5, 7, 13, .32);
      font-size: 12px;
    }
    .task-resource-badges .installed {
      color: var(--accent-ink);
      border-color: rgba(var(--accent-rgb), .28);
    }
    .task-resource-badges .missing {
      color: #ffe4a8;
      border-color: rgba(255, 200, 87, .38);
    }
    .task-resource-score {
      display: inline-flex;
      align-items: center;
      min-height: 36px;
      color: var(--muted);
      font-family: "Cascadia Code", Consolas, monospace;
      font-size: 12px;
      white-space: nowrap;
    }
    .task-resource-block {
      color: var(--muted);
      font-size: 12px;
      line-height: 1.5;
    }
    .task-resource-block strong {
      color: var(--text);
    }
    .task-resource-block ul {
      margin: 5px 0 0;
      padding-left: 18px;
    }
    .task-card-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 7px;
      align-items: center;
    }
    .task-card-actions button,
    .task-card-actions a {
      min-height: 36px;
      border: 1px solid rgba(var(--accent-rgb), .24);
      border-radius: var(--radius);
      padding: 8px 10px;
      color: var(--accent-ink);
      background: rgba(var(--accent-rgb), .10);
      font-size: 12px;
      text-decoration: none;
      display: inline-flex;
      align-items: center;
      justify-content: center;
    }
    .back-home-button {
      position: fixed;
      right: 18px;
      top: 50%;
      transform: translateY(-50%);
      z-index: 5;
      display: grid;
      grid-template-rows: 22px 12px;
      align-content: center;
      justify-items: center;
      gap: 3px;
      width: 56px;
      height: 56px;
      min-height: 56px;
      padding: 0;
      box-sizing: border-box;
      border-color: rgba(var(--accent-rgb), .28);
      background: rgba(9, 17, 29, .86);
      color: var(--accent-ink);
      box-shadow: 0 0 24px rgba(var(--accent-rgb), .14);
      backdrop-filter: blur(14px) saturate(140%);
    }
    .back-home-button span {
      font-family: "Cascadia Code", Consolas, monospace;
      font-size: 20px;
      line-height: 1;
      display: block;
    }
    .back-home-button small {
      color: var(--muted);
      font-size: 11px;
      line-height: 1;
      display: block;
    }
    .back-home-button:hover {
      border-color: var(--accent);
      background: rgba(var(--accent-rgb), .14);
    }
    #search { grid-area: search; }
    #resourceFilter { grid-area: resource; }
    #categoryFilter { grid-area: category; }
    input, select, button, textarea {
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
    textarea { padding: 10px 13px; }
    input::placeholder,
    textarea::placeholder { color: var(--faint); }
    input:focus, select:focus, textarea:focus, button:focus-visible {
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
    .skill-card.resource-agents {
      border-color: rgba(255, 200, 87, .38);
      background:
        linear-gradient(135deg, rgba(255, 200, 87, .12), transparent 38%),
        rgba(9, 17, 29, .84);
    }
    .skill-card.resource-agents::before {
      background: var(--warning);
      box-shadow: 0 0 18px rgba(255, 200, 87, .42);
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
    .category, .source, .call-count, .resource-badge {
      border-radius: var(--radius);
      padding: 4px 8px;
      font-size: 12px;
      line-height: 1.2;
    }
    .resource-badge {
      font-weight: 750;
      letter-spacing: 0;
      background: rgba(13, 23, 38, .9);
      color: var(--text);
      border: 1px solid rgba(145, 168, 186, .22);
    }
    .resource-badge.resource-skill {
      color: var(--accent-ink);
      border-color: rgba(var(--accent-rgb), .28);
    }
    .resource-badge.resource-agents {
      color: #ffe4a8;
      border-color: rgba(255, 200, 87, .42);
      background: rgba(255, 200, 87, .12);
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
    .relationship-panel {
      border-bottom: 1px solid var(--line);
      background: rgba(5, 7, 13, .54);
    }
    .relationship-inner {
      padding: 14px 0 16px;
    }
    .relationship-header {
      display: flex;
      align-items: flex-end;
      justify-content: space-between;
      gap: 16px;
      margin-bottom: 10px;
    }
    .relationship-header h2 {
      margin: 0;
      font-size: 18px;
    }
    .relationship-header p {
      margin: 4px 0 0;
      color: var(--muted);
      font-size: 12px;
    }
    .relationship-count {
      color: var(--accent-ink);
      font-family: "Cascadia Code", Consolas, monospace;
      font-size: 13px;
      white-space: nowrap;
    }
    .relationship-controls {
      display: grid;
      grid-template-columns: minmax(180px, 240px) minmax(240px, 1fr);
      gap: 8px;
      margin-bottom: 10px;
    }
    .relationship-table-wrap {
      max-height: 320px;
      overflow: auto;
      border: 1px solid var(--line);
      background: rgba(9, 17, 29, .72);
    }
    .relationship-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 12px;
    }
    .relationship-table th,
    .relationship-table td {
      padding: 8px 10px;
      border-bottom: 1px solid rgba(92, 236, 255, .10);
      text-align: left;
      vertical-align: top;
    }
    .relationship-table th {
      position: sticky;
      top: 0;
      z-index: 1;
      background: rgba(13, 23, 38, .96);
      color: var(--muted);
      font-weight: 650;
    }
    .relationship-table code {
      color: var(--code);
      overflow-wrap: anywhere;
    }
    .relationship-table .target-skill {
      color: var(--accent-ink);
    }
    .relationship-table .target-external {
      color: #ffe4a8;
    }
    .relation-type {
      display: inline-block;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      padding: 2px 6px;
      color: var(--accent-ink);
      background: rgba(var(--accent-rgb), .10);
      font-family: "Cascadia Code", Consolas, monospace;
    }
    .relationship-empty {
      display: none;
      padding: 12px;
      color: var(--muted);
      border: 1px solid var(--line);
      background: rgba(9, 17, 29, .72);
      font-size: 13px;
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
          "resource"
          "category"
          "sorts"
          "updates";
      }
      .task-advisor-row,
      .task-copy-row {
        grid-template-columns: 1fr;
      }
      .task-advisor-summary {
        display: grid;
      }
      .task-advisor-run,
      .task-copy-button,
      .task-copy-all {
        width: 100%;
      }
      .task-report-actions {
        display: grid;
      }
      .task-rec-head {
        display: grid;
      }
      .task-score {
        white-space: normal;
      }
      .back-home-button {
        top: auto;
        right: 12px;
        bottom: 18px;
        transform: none;
        width: 52px;
        height: 52px;
        min-height: 52px;
      }
      .sorts button {
        flex: 1 1 30%;
      }
      .update-actions {
        justify-content: flex-start;
        grid-template-columns: 1fr;
      }
      .relationship-header {
        display: block;
      }
      .relationship-count {
        display: block;
        margin-top: 6px;
      }
      .relationship-controls {
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
  <button type="button" id="backHomeButton" class="back-home-button" aria-label="&#x56DE;&#x5230;&#x9996;&#x9875;" title="&#x56DE;&#x5230;&#x9996;&#x9875;">
    <span aria-hidden="true">&#x2191;</span>
    <small>&#x9996;&#x9875;</small>
  </button>
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
        <p class="subtitle">&#x628A;&#x4E2A;&#x4EBA;&#x6574;&#x7406;&#x3001;&#x672C;&#x673A;&#x5DF2;&#x5B89;&#x88C5;&#x7684; Skill &#x548C; Agents &#x96C6;&#x7FA4;&#x6536;&#x5728;&#x4E00;&#x5F20;&#x53EF;&#x641C;&#x7D22;&#x7684;&#x7D22;&#x5F15;&#x91CC;&#x3002;&#x91CD;&#x70B9;&#x662F;&#x8D44;&#x6E90;&#x7C7B;&#x578B;&#x3001;&#x529F;&#x80FD;&#x3001;&#x53EC;&#x5524;&#x53E3;&#x4EE4;&#x548C;&#x6700;&#x540E;&#x66F4;&#x65B0;&#x65F6;&#x95F4;&#x3002;</p>
      </div>
      <div class="stats" aria-label="&#x7EDF;&#x8BA1;">
        <div class="stat"><strong>$installedSkillCount</strong><span>&#x672C;&#x673A;&#x8D44;&#x6E90;</span></div>
        <div class="stat"><strong>$skillResourceCount</strong><span>Skill &#x5361;&#x7247;</span></div>
        <div class="stat agents"><strong>$agentResourceCount</strong><span>Agents &#x96C6;&#x7FA4;</span></div>
        <div class="stat"><strong>$($categories.Count)</strong><span>&#x529F;&#x80FD;&#x7C7B;&#x522B;</span></div>
        <div class="stat pending"><strong id="pendingUpdateCount">$pendingUpdateCount</strong><span>&#x5168;&#x90E8;&#x5F85;&#x66F4;&#x65B0;</span></div>
        <div class="stat update-time"><span>&#x4E0A;&#x6B21;&#x66F4;&#x65B0;&#x65F6;&#x95F4;</span><strong>$lastUpdatedAt</strong></div>
      </div>
    </div>
  </header>

  <section class="toolbar">
    <div class="wrap task-advisor" aria-label="&#x4EFB;&#x52A1;&#x63CF;&#x8FF0;&#x63A8;&#x8350; Skill">
      <label class="task-advisor-label" for="taskAdvisorInput">&#x4EFB;&#x52A1;&#x63CF;&#x8FF0;</label>
      <div class="task-advisor-row">
        <textarea id="taskAdvisorInput" rows="2" placeholder="&#x63CF;&#x8FF0;&#x4EFB;&#x52A1;" aria-label="&#x8F93;&#x5165;&#x4EFB;&#x52A1;&#x63CF;&#x8FF0;"></textarea>
        <button type="button" id="taskAdvisorRun" class="task-advisor-run">&#x63A8;&#x8350; Skill</button>
      </div>
      <div id="taskAdvisorOutput" class="task-advisor-output" hidden aria-live="polite"></div>
    </div>
    <div class="wrap tools">
      <input id="search" type="search" placeholder="&#x641C;&#x7D22;&#x540D;&#x5B57;&#x3001;&#x8D44;&#x6E90;&#x7C7B;&#x578B;&#x3001;&#x529F;&#x80FD;&#x3001;&#x7C7B;&#x522B;&#x6216;&#x53EC;&#x5524;&#x53E3;&#x4EE4;" aria-label="&#x641C;&#x7D22; Skill &#x6216; Agents">
      <select id="resourceFilter" aria-label="&#x6309;&#x8D44;&#x6E90;&#x7C7B;&#x578B;&#x7B5B;&#x9009;">
        <option value="">&#x5168;&#x90E8;&#x8D44;&#x6E90;&#x7C7B;&#x578B;</option>
        <option value="skill">Skill</option>
        <option value="agents">Agents &#x96C6;&#x7FA4;</option>
      </select>
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

  <section class="relationship-panel" aria-label="Skill &#x5173;&#x7CFB;&#x5217;&#x8868;">
    <div class="wrap relationship-inner">
      <div class="relationship-header">
        <div>
          <h2>Skill &#x5173;&#x7CFB;&#x5217;&#x8868;</h2>
          <p>&#x6765;&#x6E90;&#x4E8E; SKILL.md &#x5143;&#x6570;&#x636E;&#x548C;&#x6B63;&#x6587;&#x4E2D;&#x660E;&#x786E;&#x63D0;&#x5230;&#x7684;&#x5176;&#x4ED6; Skill&#x3002;</p>
        </div>
        <span class="relationship-count"><strong id="relationshipShownCount">$($relationships.Count)</strong> / $($relationships.Count) relations</span>
      </div>
      <div class="relationship-controls">
        <select id="relationshipTypeFilter" aria-label="&#x6309;&#x5173;&#x7CFB;&#x7C7B;&#x578B;&#x7B5B;&#x9009;">
          <option value="">&#x5168;&#x90E8;&#x5173;&#x7CFB;</option>
          $relationshipTypeOptions
        </select>
        <input id="relationshipSearch" type="search" placeholder="&#x641C;&#x7D22;&#x6E90; Skill&#x3001;&#x76EE;&#x6807;&#x3001;&#x5173;&#x7CFB;&#x7C7B;&#x578B;&#x6216;&#x6765;&#x6E90;" aria-label="&#x641C;&#x7D22; Skill &#x5173;&#x7CFB;">
      </div>
      <div class="relationship-table-wrap">
        <table class="relationship-table">
          <thead>
            <tr>
              <th>Source</th>
              <th>Type</th>
              <th>Target</th>
              <th>Target Kind</th>
              <th>Source Field</th>
              <th>Confidence</th>
            </tr>
          </thead>
          <tbody id="relationshipRows">
$($relationshipRows -join "`n")
          </tbody>
        </table>
      </div>
      <div id="relationshipEmpty" class="relationship-empty">&#x6CA1;&#x6709;&#x5339;&#x914D;&#x7684; Skill &#x5173;&#x7CFB;&#x3002;</div>
    </div>
  </section>

  <main class="wrap">
    <div id="grid" class="grid">
$($rows -join "`n")
    </div>
    <div id="empty" class="empty">&#x6CA1;&#x6709;&#x5339;&#x914D;&#x7684;&#x8D44;&#x6E90;&#x3002;</div>
  </main>

  <script type="application/json" id="skillData">$json</script>
  <script type="application/json" id="relationshipData">$relationshipJson</script>
  <script src="pet-secrets.local.js"></script>
  <script src="skill-install-token.local.js"></script>
  <script>
    const grid = document.querySelector("#grid");
    const toolbar = document.querySelector(".toolbar");
    const backHomeButton = document.querySelector("#backHomeButton");
    const cards = Array.from(document.querySelectorAll(".skill-card"));
    const search = document.querySelector("#search");
    const resourceFilter = document.querySelector("#resourceFilter");
    const categoryFilter = document.querySelector("#categoryFilter");
    const empty = document.querySelector("#empty");
    const buttons = Array.from(document.querySelectorAll("[data-sort]"));
    const showUpdatesOnlyButton = document.querySelector("#showUpdatesOnly");
    const updateAllButton = document.querySelector("#updateAllSkills");
    const updateStatusText = document.querySelector("#updateStatusText");
    const relationshipTypeFilter = document.querySelector("#relationshipTypeFilter");
    const relationshipSearch = document.querySelector("#relationshipSearch");
    const relationshipRows = Array.from(document.querySelectorAll("[data-relation-row]"));
    const relationshipShownCount = document.querySelector("#relationshipShownCount");
    const relationshipEmpty = document.querySelector("#relationshipEmpty");
    const taskAdvisorInput = document.querySelector("#taskAdvisorInput");
    const taskAdvisorRun = document.querySelector("#taskAdvisorRun");
    const taskAdvisorOutput = document.querySelector("#taskAdvisorOutput");
    const parsedSkillRecords = readJsonScript("#skillData", []);
    const skillRecords = Array.isArray(parsedSkillRecords) ? parsedSkillRecords : [];
    const relationshipGraph = readJsonScript("#relationshipData", { records: [], relationships: [] });
    const relationshipRecords = Array.isArray(relationshipGraph.records) ? relationshipGraph.records : [];
    const relationshipEdges = Array.isArray(relationshipGraph.relationships) ? relationshipGraph.relationships : [];
    const cardBySkillName = new Map(cards.map(card => [normalizeTaskKey(card.dataset.name), card]));
    const relationshipRecordBySkillName = new Map(relationshipRecords.map(record => [normalizeTaskKey(record.name), record]));
    const taskStopTokens = new Set(["帮我", "一下", "这个", "那个", "一个", "进行", "可以", "需要", "我的", "你的", "他的", "她的", "以及", "并且", "skill"]);
    const countStoreKey = "skillArchiveLocalCallIncrements";
    const githubSearchCacheKey = "skillArchiveGithubSearchCache";
    let taskAdvisorRequestId = 0;
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
    function localDayString(date) {
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, "0");
      const day = String(date.getDate()).padStart(2, "0");
      return year + "-" + month + "-" + day;
    }

    const petToday = localDayString(new Date());
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
      return cards.filter(card => card.dataset.installed === "true" && card.dataset.resourceKind === "skill");
    }

    function installedSkillNamesForPet() {
      return installedCardsForPet()
        .map(card => card.dataset.name)
        .filter(Boolean)
        .sort((a, b) => a.localeCompare(b));
    }

    function dailyPetRecommendations(previousRecommendations) {
      const pool = installedCardsForPet().map(card => card.dataset.name).filter(Boolean);
      const uniquePool = Array.from(new Set(pool)).sort((a, b) => a.localeCompare(b));
      if (!uniquePool.length) return [];
      const poolSignature = uniquePool.join("|");
      const shuffled = seededShuffle(uniquePool, petToday + ":" + poolSignature);
      const previousSet = new Set(Array.isArray(previousRecommendations) ? previousRecommendations.filter(Boolean) : []);
      if (uniquePool.length > 3 && previousSet.size) {
        const fresh = shuffled.filter(name => !previousSet.has(name));
        const filled = fresh.concat(shuffled.filter(name => previousSet.has(name)));
        return filled.slice(0, 3);
      }
      return shuffled.slice(0, 3);
    }

    function normalizePetState() {
      const state = loadPetState();
      const elapsed = daysBetween(state.day, petToday);
      const previousRecommendations = Array.isArray(state.recommendations) ? state.recommendations.slice() : [];
      if (typeof state.fullness !== "number") state.fullness = 20;
      if (elapsed > 0) {
        state.fullness = Math.max(0, Number(state.fullness || 0) - elapsed * 10);
        state.day = petToday;
        state.fedToday = [];
        if (state.fullness <= 0) state.dead = true;
      }
      if (!state.day) state.day = petToday;
      const previousInstalled = Number(state.installedCount || 0);
      const currentInstalledNames = installedSkillNamesForPet();
      const previousInstalledNames = Array.isArray(state.installedSkillNames) ? state.installedSkillNames.filter(Boolean) : [];
      let newlyInstalledCount = 0;
      if (previousInstalledNames.length) {
        const previousNameSet = new Set(previousInstalledNames);
        newlyInstalledCount = currentInstalledNames.filter(name => !previousNameSet.has(name)).length;
      } else if (previousInstalled && installedSkillCount > previousInstalled) {
        newlyInstalledCount = installedSkillCount - previousInstalled;
      }
      if (newlyInstalledCount > 0) {
        state.fullness = Math.min(30, Number(state.fullness || 0) + newlyInstalledCount * 5);
        if (state.fullness > 0) state.dead = false;
      }
      state.installedCount = installedSkillCount;
      state.installedSkillNames = currentInstalledNames;
      if (!Array.isArray(state.fedToday)) state.fedToday = [];
      if (!Array.isArray(state.reviveVotes)) state.reviveVotes = [];
      if (!state.bargains || typeof state.bargains !== "object" || Array.isArray(state.bargains)) state.bargains = {};
      state.reviveVotes = Array.from(new Set(state.reviveVotes.map(normalizeReviveId).filter(Boolean)));
      const currentRecommendationNames = installedCardsForPet().map(card => card.dataset.name).filter(Boolean);
      const currentRecommendationSet = new Set(currentRecommendationNames);
      const hasInvalidRecommendation = !Array.isArray(state.recommendations) || state.recommendations.some(name => !currentRecommendationSet.has(name));
      if (state.recommendationDay !== petToday || hasInvalidRecommendation || !Array.isArray(state.recommendations) || state.recommendations.length !== 3) {
        state.recommendations = dailyPetRecommendations(previousRecommendations);
        state.recommendationDay = petToday;
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
      // Risk note: this optional browser-side model call can consume paid API quota.
      // Keep the API key in pet-secrets.local.js or environment-managed local config only.
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

    function readJsonScript(selector, fallbackValue) {
      const node = document.querySelector(selector);
      if (!node) return fallbackValue;
      try {
        const parsed = JSON.parse(node.textContent || "null");
        return parsed || fallbackValue;
      } catch (error) {
        return fallbackValue;
      }
    }

    function asTaskArray(value) {
      if (Array.isArray(value)) return value.filter(item => item !== null && item !== undefined).map(item => String(item));
      if (value === null || value === undefined || value === "") return [];
      return [String(value)];
    }

    function normalizeTaskText(value) {
      const raw = String(value || "").toLowerCase();
      try {
        return raw.normalize("NFKC");
      } catch (error) {
        return raw;
      }
    }

    function normalizeTaskKey(value) {
      return normalizeTaskText(value).trim();
    }

    // STRUCTURED_MATCHER_START
    const capabilityAliasCatalog = {
      platforms: [
        { canonical: "xiaohongshu", aliases: ["\u5c0f\u7ea2\u4e66", "\u5c0f\u7ea2\u4e66\u5e73\u53f0", "xhs", "redbook", "red book"] },
        { canonical: "lark", aliases: ["\u98de\u4e66", "\u98de\u4e66lark", "lark", "feishu"] },
        { canonical: "notion", aliases: ["notion"] },
        { canonical: "github", aliases: ["github", "git hub"] },
        { canonical: "windows", aliases: ["windows", "win32", "wpf", "winui"] },
        { canonical: "ios", aliases: ["ios", "iphone", "swiftui"] },
        { canonical: "wechat", aliases: ["\u5fae\u4fe1", "wechat"] },
        { canonical: "douyin", aliases: ["\u6296\u97f3", "douyin", "tiktok"] },
        { canonical: "vercel", aliases: ["vercel"] },
        { canonical: "supabase", aliases: ["supabase"] }
      ],
      actions: [
        { canonical: "scrape", gate: true, aliases: ["\u6293\u53d6", "\u722c\u53d6", "\u91c7\u96c6", "\u722c\u866b", "\u62c9\u53d6\u6570\u636e", "\u63d0\u53d6", "scrape", "scraping", "scraper", "crawler", "crawl", "collector", "fetch", "fetching", "retrieve", "extraction", "extract"] },
        { canonical: "translate", gate: true, aliases: ["\u7ffb\u8bd1", "\u8bd1", "\u6587\u672c\u8f6c\u6362", "translate", "translation"] },
        { canonical: "deploy", gate: true, aliases: ["\u90e8\u7f72", "\u4e0a\u7ebf", "\u53d1\u5e03\u670d\u52a1", "\u53d1\u5e03\u4e0a\u7ebf", "deploy", "deployment"] },
        { canonical: "analyze", gate: false, aliases: ["\u5206\u6790", "\u89e3\u6790", "\u7814\u5224", "\u7edf\u8ba1", "\u7814\u7a76", "analyze", "analysis", "research"] },
        { canonical: "test", gate: true, aliases: ["\u6d4b\u8bd5", "\u9a8c\u6536", "test", "testing", "qa"] },
        { canonical: "transcribe", gate: true, aliases: ["\u8f6c\u5f55", "\u8bed\u97f3\u8f6c\u6587\u5b57", "transcribe", "transcription"] },
        { canonical: "publish", gate: true, aliases: ["\u53d1\u5e03", "\u63a8\u9001", "publish", "post"] },
        { canonical: "summarize", gate: false, aliases: ["\u603b\u7ed3", "\u6c47\u603b", "\u6458\u8981", "\u7eaa\u8981", "summarize", "summary"] }
      ],
      objects: [
        { canonical: "note", aliases: ["\u7b14\u8bb0", "\u5e16\u5b50", "note", "notes"] },
        { canonical: "pdf", aliases: ["pdf", "pdf\u6587\u6863", "pdf\u6587\u4ef6"] },
        { canonical: "desktop_pet", aliases: ["\u684c\u9762\u5ba0\u7269", "\u684c\u9762\u840c\u5ba0", "desktop pet", "pet", "pets", "mascot", "mascots", "sprite", "sprites", "spritesheet", "spritesheets"] },
        { canonical: "meeting_minutes", aliases: ["\u4f1a\u8bae\u7eaa\u8981", "\u5999\u8bb0", "meeting minutes"] },
        { canonical: "video", aliases: ["\u89c6\u9891", "video"] },
        { canonical: "image", aliases: ["\u56fe\u7247", "\u56fe\u50cf", "image", "photo"] },
        { canonical: "webpage", aliases: ["\u7f51\u9875", "\u7f51\u7ad9", "webpage", "website"] },
        { canonical: "database", aliases: ["\u6570\u636e\u5e93", "database", "postgres", "mysql"] }
      ],
      outputs: [
        { canonical: "radar", aliases: ["\u96f7\u8fbe", "\u76d1\u63a7\u5668", "radar", "monitor"] },
        { canonical: "report", aliases: ["\u62a5\u544a", "\u62a5\u8868", "report"] },
        { canonical: "webpage", aliases: ["\u7f51\u9875", "\u9875\u9762", "webpage", "website"] },
        { canonical: "table", aliases: ["\u8868\u683c", "\u7535\u5b50\u8868\u683c", "table", "spreadsheet"] },
        { canonical: "dashboard", aliases: ["\u770b\u677f", "dashboard"] }
      ],
      constraints: [
        { canonical: "realtime", aliases: ["\u5b9e\u65f6", "\u5b9e\u65f6\u83b7\u53d6", "\u5373\u65f6", "real-time", "realtime"] },
        { canonical: "batch", aliases: ["\u6279\u91cf", "\u6279\u91cf\u5904\u7406", "\u591a\u4efb\u52a1", "batch"] },
        { canonical: "local", aliases: ["\u672c\u5730", "local", "offline"] },
        { canonical: "scheduled", aliases: ["\u5b9a\u65f6", "\u5b9a\u65f6\u4efb\u52a1", "\u5468\u671f", "\u5468\u671f\u6267\u884c", "scheduled", "cron"] }
      ]
    };
    const genericIntentTerms = new Set(["\u4fe1\u606f", "\u641c\u7d22", "\u5185\u5bb9", "\u5904\u7406", "\u751f\u6210", "\u5de5\u5177", "\u6570\u636e", "\u4efb\u52a1", "\u63a5\u53e3", "\u811a\u672c", "skill", "information", "search", "content", "process", "generate", "tool", "data", "task", "interface", "api", "script"]);
    const semanticCapabilityCatalog = [
      { canonical: "visual_design", aliases: ["\u8bbe\u8ba1", "\u7f8e\u672f", "\u89c6\u89c9", "\u53ef\u7231", "\u5f62\u8c61", "mascot", "visual", "design", "sprite"] },
      { canonical: "image_generation", aliases: ["\u751f\u6210\u56fe\u7247", "\u56fe\u50cf\u751f\u6210", "\u7ed8\u56fe", "\u914d\u56fe", "image generation", "imagegen", "generate image"] },
      { canonical: "animation", aliases: ["\u52a8\u753b", "\u52a8\u4f5c", "\u52a8\u6548", "animate", "animation", "motion", "rig"] },
      { canonical: "interaction", aliases: ["\u4e92\u52a8", "\u4ea4\u4e92", "\u5bf9\u8bdd", "\u966a\u4f34", "\u804a\u5929", "interaction", "interactive", "conversation", "chat"] },
      { canonical: "voice", aliases: ["\u8bed\u97f3", "\u58f0\u97f3", "\u8bed\u97f3\u4e92\u52a8", "\u8bed\u97f3\u5408\u6210", "voice", "speech", "tts", "text-to-speech", "audio"] },
      { canonical: "desktop_app", aliases: ["\u684c\u9762\u5e94\u7528", "\u684c\u9762\u7a0b\u5e8f", "desktop app", "desktop application", "winui", "wpf", "electron"] },
      { canonical: "ui_development", aliases: ["\u524d\u7aef", "\u754c\u9762\u5f00\u53d1", "ui\u5f00\u53d1", "frontend", "front-end", "ui development"] },
      { canonical: "persistence", aliases: ["\u4fdd\u5b58\u6570\u636e", "\u672c\u5730\u5b58\u50a8", "\u8bb0\u5fc6", "persistence", "storage", "database", "local storage"] },
      { canonical: "notification", aliases: ["\u63d0\u9192", "\u901a\u77e5", "\u6d88\u606f\u63a8\u9001", "notification", "reminder", "alert"] }
    ];

    function structuredNormalize(value) {
      const raw = String(value || "").toLowerCase();
      try { return raw.normalize("NFKC"); } catch (error) { return raw; }
    }

    function structuredLatinTokens(value) {
      return structuredNormalize(value).match(/[a-z0-9]+/g) || [];
    }

    function structuredAliasMatches(text, alias) {
      const normalizedText = structuredNormalize(text);
      const normalizedAlias = structuredNormalize(alias).trim();
      if (!normalizedAlias) return false;
      if (/^[a-z0-9 ]+$/.test(normalizedAlias)) {
        const phrase = normalizedAlias.split(/\s+/).filter(Boolean);
        const tokens = structuredLatinTokens(normalizedText);
        if (phrase.length === 1) return tokens.includes(phrase[0]);
        return normalizedText.split(/[^a-z0-9]+/).join(" ").includes(phrase.join(" "));
      }
      return normalizedText.includes(normalizedAlias);
    }

    function extractCatalogValues(text, entries) {
      return entries.filter(entry => entry.aliases.some(alias => structuredAliasMatches(text, alias))).map(entry => entry.canonical);
    }

    function extractSemanticCapabilities(text) {
      return extractCatalogValues(text, semanticCapabilityCatalog);
    }

    function structuredSpecificTerms(text) {
      const normalized = structuredNormalize(text);
      const terms = new Set();
      structuredLatinTokens(normalized).forEach(token => {
        if (token.length > 2 && !genericIntentTerms.has(token)) terms.add(token);
      });
      (normalized.match(/[\u4e00-\u9fff]{2,}/g) || []).forEach(chunk => {
        if (chunk.length <= 8 && !genericIntentTerms.has(chunk)) terms.add(chunk);
      });
      return Array.from(terms);
    }

    function parseStructuredIntent(text) {
      const normalized = structuredNormalize(text);
      const intent = {
        text: String(text || "").trim(),
        platforms: extractCatalogValues(normalized, capabilityAliasCatalog.platforms),
        actions: extractCatalogValues(normalized, capabilityAliasCatalog.actions),
        objects: extractCatalogValues(normalized, capabilityAliasCatalog.objects),
        outputs: extractCatalogValues(normalized, capabilityAliasCatalog.outputs),
        constraints: extractCatalogValues(normalized, capabilityAliasCatalog.constraints),
        capabilities: extractSemanticCapabilities(normalized),
        specificTerms: structuredSpecificTerms(normalized)
      };
      const professionalActionSet = new Set(capabilityAliasCatalog.actions.filter(entry => entry.gate !== false).map(entry => entry.canonical));
      intent.professionalActions = intent.actions.filter(action => professionalActionSet.has(action));
      intent.matchMode = intent.platforms.length || intent.professionalActions.length ? "strict_gate" : "loose_compatible";
      intent.broad = intent.matchMode === "loose_compatible";
      return intent;
    }

    function applySemanticIntentAnalysis(intent, semanticAnalysis, subtaskIndex = -1) {
      if (!semanticAnalysis || !semanticAnalysis.enabled || !Array.isArray(semanticAnalysis.capabilities)) return intent;
      const subtask = subtaskIndex >= 0 && Array.isArray(semanticAnalysis.subtasks) ? semanticAnalysis.subtasks[subtaskIndex] : null;
      const capabilities = Array.from(new Set((intent.capabilities || []).concat(semanticAnalysis.capabilities || [], subtask && Array.isArray(subtask.capabilities) ? subtask.capabilities : [])));
      const keywords = Array.isArray(semanticAnalysis.keywords) ? semanticAnalysis.keywords : [];
      const specificTerms = Array.from(new Set((intent.specificTerms || []).concat(keywords.map(value => structuredNormalize(value)).filter(value => value && !genericIntentTerms.has(value))))).slice(0, 12);
      return { ...intent, capabilities, specificTerms, semanticSource: semanticAnalysis.source || "model" };
    }

    function capabilityPrimaryText(record) {
      return [
        record && record.name,
        record && record.description,
        record && record.chineseDescription,
        record && record.category,
        record && record.resourceLabel,
        ...(Array.isArray(record && record.triggers) ? record.triggers : []),
        ...(Array.isArray(record && record.inputs) ? record.inputs : []),
        ...(Array.isArray(record && record.outputs) ? record.outputs : [])
      ].filter(Boolean).join(" ");
    }

    function capabilityProfileForRecord(record) {
      const text = capabilityPrimaryText(record);
      return {
        platforms: extractCatalogValues(text, capabilityAliasCatalog.platforms),
        actions: extractCatalogValues(text, capabilityAliasCatalog.actions),
        objects: extractCatalogValues(text, capabilityAliasCatalog.objects),
        outputs: extractCatalogValues(text, capabilityAliasCatalog.outputs),
        constraints: extractCatalogValues(text, capabilityAliasCatalog.constraints),
        capabilities: extractSemanticCapabilities(text),
        specificTerms: structuredSpecificTerms(text)
      };
    }

    function structuredIntersection(left, right) {
      const allowed = new Set(right || []);
      return (left || []).filter(value => allowed.has(value));
    }

    function capabilityNameAffinity(record, matchedCapabilities) {
      const nameAndTriggers = [record && record.name, ...(Array.isArray(record && record.triggers) ? record.triggers : [])].filter(Boolean).join(" ");
      return (matchedCapabilities || []).reduce((total, capability) => {
        const entry = semanticCapabilityCatalog.find(item => item.canonical === capability);
        if (!entry || !entry.aliases.some(alias => structuredAliasMatches(nameAndTriggers, alias))) return total;
        return total + 16;
      }, 0);
    }

    function matchStructuredCandidate(record, intent) {
      const profile = capabilityProfileForRecord(record || {});
      const matchedPlatforms = structuredIntersection(intent.platforms, profile.platforms);
      const matchedActions = structuredIntersection(intent.actions, profile.actions);
      const matchedProfessionalActions = structuredIntersection(intent.professionalActions || [], profile.actions);
      const matchedObjects = structuredIntersection(intent.objects, profile.objects);
      const matchedOutputs = structuredIntersection(intent.outputs, profile.outputs);
      const matchedConstraints = structuredIntersection(intent.constraints, profile.constraints);
      const matchedCapabilities = structuredIntersection(intent.capabilities || [], profile.capabilities || []);
      const matchedSpecificTerms = structuredIntersection(intent.specificTerms, profile.specificTerms).filter(term => !genericIntentTerms.has(term));
      const gateFailures = [];
      const strictMode = intent.matchMode === "strict_gate";
      if (strictMode && intent.platforms.length && !matchedPlatforms.length) gateFailures.push("platform");
      if (strictMode && intent.professionalActions.length && !matchedProfessionalActions.length) gateFailures.push("action");
      const requiredSpecificObjects = new Set(["desktop_pet"]);
      if ((intent.objects || []).some(object => requiredSpecificObjects.has(object)) && !matchedObjects.some(object => requiredSpecificObjects.has(object))) gateFailures.push("object");
      const hasSubstantiveEvidence = matchedPlatforms.length || matchedActions.length || matchedObjects.length || matchedOutputs.length || matchedCapabilities.length || matchedSpecificTerms.length;
      if (!hasSubstantiveEvidence) gateFailures.push("generic-only");
      const matchedCompatibleActions = matchedActions.filter(action => !matchedProfessionalActions.includes(action));
      const capabilityAffinity = capabilityNameAffinity(record, matchedCapabilities);
      let score = matchedPlatforms.length * 50 + matchedProfessionalActions.length * 40 + matchedCompatibleActions.length * 18 + matchedObjects.length * 16 + matchedOutputs.length * 14 + matchedCapabilities.length * 18 + capabilityAffinity + matchedConstraints.length * 5 + matchedSpecificTerms.length * 8;
      if (intent.broad && score < 14) gateFailures.push("broad-low-confidence");
      const compatibleActionCount = Math.max(0, intent.actions.length - intent.professionalActions.length);
      const maximum = Math.max(1, intent.platforms.length * 50 + intent.professionalActions.length * 40 + compatibleActionCount * 18 + intent.objects.length * 16 + intent.outputs.length * 14 + (intent.capabilities || []).length * 34 + intent.constraints.length * 5 + Math.min(3, intent.specificTerms.length) * 8);
      const gatePassed = gateFailures.length === 0;
      return {
        name: String(record && record.name || ""),
        record,
        profile,
        gatePassed,
        gateFailures,
        matchedPlatforms,
        matchedActions,
        matchedObjects,
        matchedOutputs,
        matchedCapabilities,
        capabilityAffinity,
        matchedConstraints,
        matchedSpecificTerms,
        score: gatePassed ? score : 0,
        confidence: gatePassed ? Math.min(1, score / maximum) : 0
      };
    }

    function githubSearchKeywordForIntent(intent) {
      const terms = [];
      intent.platforms.forEach(platform => {
        if (platform === "xiaohongshu") terms.push("xiaohongshu", "xhs", "redbook");
        else terms.push(platform);
      });
      intent.actions.forEach(action => {
        if (action === "scrape") terms.push("scrape", "crawler", "collector");
        else terms.push(action);
      });
      intent.objects.forEach(object => terms.push(object));
      intent.outputs.forEach(output => terms.push(output));
      return Array.from(new Set(terms.filter(term => !genericIntentTerms.has(term)))).join(" ");
    }

    function archiveSearchTokens(value) {
      const normalized = structuredNormalize(value).trim();
      const latin = structuredLatinTokens(normalized);
      const chinese = normalized.match(/[\u4e00-\u9fff]+/g) || [];
      return { normalized, latin, chinese };
    }

    function archiveSearchMatches(record, query) {
      const parsed = archiveSearchTokens(query);
      if (!parsed.normalized) return true;
      const primary = structuredNormalize(capabilityPrimaryText(record));
      const latinMatches = parsed.latin.every(token => primary.includes(token));
      const chineseMatches = parsed.chinese.every(token => primary.includes(token));
      return latinMatches && chineseMatches;
    }

    function expandLooseRelationshipCandidates(candidates, records, edges, plan) {
      if (!plan || !plan.globalIntent || plan.globalIntent.matchMode !== "loose_compatible") return candidates.slice();
      const expanded = candidates.slice();
      const byKey = new Map(expanded.map(candidate => [structuredNormalize(candidate.key || candidate.name).trim(), candidate]));
      const recordByKey = new Map((records || []).map(record => [structuredNormalize(record && record.name).trim(), record]));
      const seeds = expanded.filter(candidate => candidate.gatePassed !== false && candidate.baseScore > 0)
        .sort((left, right) => right.baseScore - left.baseScore || left.name.localeCompare(right.name, "zh-CN"))
        .slice(0, 1);
      const seedByKey = new Map(seeds.map(candidate => [structuredNormalize(candidate.key || candidate.name).trim(), candidate]));
      const allowedTypes = new Set(["requires", "recommends", "precedes", "mentions"]);
      const weights = { requires: 12, recommends: 11, precedes: 9, mentions: 7 };
      (edges || []).forEach(edge => {
        const sourceKey = structuredNormalize(edge && edge.source).trim();
        const targetKey = structuredNormalize(edge && edge.target).trim();
        const type = structuredNormalize(edge && edge.type).trim();
        if (!sourceKey || !targetKey || sourceKey === targetKey || !allowedTypes.has(type)) return;
        if (structuredNormalize(edge && edge.targetKind || "skill").trim() !== "skill") return;
        const seed = seedByKey.get(sourceKey);
        const record = recordByKey.get(targetKey);
        if (!seed || !record || byKey.has(targetKey)) return;
        const targetMatch = matchStructuredCandidate(record, plan.globalIntent);
        if (!targetMatch.gatePassed && type === "mentions") return;
        const relationScore = weights[type] || 6;
        const candidate = {
          key: targetKey,
          name: String(record.name || ""),
          record,
          relationRecord: {},
          gatePassed: true,
          relationshipSupport: true,
          relationshipSource: seed.name,
          relationshipType: type,
          score: Math.max(relationScore, Math.round(seed.baseScore * 0.55) + relationScore),
          baseScore: relationScore,
          confidence: Math.max(0.3, Math.min(0.72, Number(seed.confidence || 0) * 0.72)),
          reasons: ["\u5173\u8054\u8f85\u52a9\uff1a" + seed.name + " " + type + " " + String(record.name || "")],
          matchedPlatforms: targetMatch.matchedPlatforms,
          matchedActions: targetMatch.matchedActions,
          matchedObjects: targetMatch.matchedObjects,
          matchedOutputs: targetMatch.matchedOutputs,
          matchedCapabilities: targetMatch.matchedCapabilities,
          matchedConstraints: targetMatch.matchedConstraints,
          coveredSubtasks: Array.isArray(seed.coveredSubtasks) ? seed.coveredSubtasks.slice() : [],
          coveredSubtaskIds: Array.isArray(seed.coveredSubtaskIds) ? seed.coveredSubtaskIds.slice() : [],
          gateFailures: []
        };
        expanded.push(candidate);
        byKey.set(targetKey, candidate);
      });
      return expanded;
    }

    globalThis.__skillMatcherTestApi = {
      parseStructuredIntent,
      capabilityProfileForRecord,
      matchStructuredCandidate,
      githubSearchKeywordForIntent,
      archiveSearchMatches,
      expandLooseRelationshipCandidates,
      applySemanticIntentAnalysis
    };
    // STRUCTURED_MATCHER_END

    function taskTokens(value) {
      const text = normalizeTaskText(value);
      const tokens = new Set();
      if (text.trim().length > 1 && text.trim().length <= 80) tokens.add(text.trim());
      (text.match(/[a-z0-9][a-z0-9_-]{1,}/g) || []).forEach(token => {
        tokens.add(token);
        if (token.includes("-")) token.split("-").forEach(part => {
          if (part.length > 1) tokens.add(part);
        });
      });
      (text.match(/[\u4e00-\u9fff]{2,}/g) || []).forEach(chunk => {
        tokens.add(chunk);
        if (chunk.length <= 12) {
          for (let index = 0; index < chunk.length - 1; index += 1) {
            tokens.add(chunk.slice(index, index + 2));
          }
        }
      });
      return Array.from(tokens).filter(token => token.length > 1 && !taskStopTokens.has(token)).slice(0, 90);
    }

    function addTaskReason(reasons, reason) {
      if (!reason || reasons.includes(reason)) return;
      reasons.push(reason);
    }

    function taskFieldHits(tokens, value) {
      const text = normalizeTaskText(asTaskArray(value).join(" "));
      if (!text) return [];
      return tokens.filter(token => text.includes(token)).slice(0, 6);
    }

    function relationWeight(type) {
      if (type === "recommends") return 10;
      if (type === "requires") return 9;
      if (type === "precedes") return 8;
      if (type === "mentions") return 6;
      return 4;
    }

    function relationLabel(type) {
      if (type === "requires") return "requires";
      if (type === "recommends") return "recommends";
      if (type === "precedes") return "precedes";
      if (type === "mentions") return "mentions";
      return type || "relationship";
    }

    function resourceKindValue(record) {
      return normalizeTaskKey(record && record.resourceKind ? record.resourceKind : "skill") || "skill";
    }

    function resourceTypeLabel(record) {
      const kind = resourceKindValue(record);
      if (kind === "agents" || kind === "agentcluster" || kind === "agent-cluster") return "AgentCluster";
      if (kind === "agent") return "Agent";
      return "Skill";
    }

    function isRecommendableRecord(record) {
      const kind = resourceKindValue(record);
      return kind === "skill" || kind === "agent" || kind === "agents" || kind === "agentcluster" || kind === "agent-cluster";
    }

    function isAtomicSkillRecord(record) {
      return resourceKindValue(record) === "skill";
    }

    function scoreTaskCandidate(record, taskText, tokens) {
      const name = String(record.name || "");
      const key = normalizeTaskKey(name);
      const relationRecord = relationshipRecordBySkillName.get(key) || {};
      const reasons = [];
      let score = 0;
      const normalizedTask = normalizeTaskText(taskText);
      const normalizedName = normalizeTaskKey(name);

      const triggerHits = [];
      asTaskArray(record.triggers).forEach(trigger => {
        let triggerText = normalizeTaskText(trigger).trim();
        const dollar = String.fromCharCode(36);
        while (triggerText.charAt(0) === dollar) triggerText = triggerText.slice(1);
        if (triggerText.length < 2) return;
        if (normalizedTask.includes(triggerText) || (normalizedTask.length > 3 && triggerText.includes(normalizedTask))) {
          score += 58;
          triggerHits.push(trigger);
          return;
        }
        const matched = tokens.filter(token => triggerText.includes(token) || token.includes(triggerText)).slice(0, 2);
        if (matched.length) {
          score += 26 + matched.length * 6;
          triggerHits.push(trigger);
        }
      });
      if (triggerHits.length) addTaskReason(reasons, "触发词匹配：" + triggerHits.slice(0, 2).join(", "));

      if (normalizedName && normalizedTask.includes(normalizedName)) {
        score += 42;
        addTaskReason(reasons, "名称直接匹配：" + name);
      } else {
        const nameHits = taskFieldHits(tokens, name);
        if (nameHits.length) {
          score += Math.min(35, 18 + nameHits.length * 7);
          addTaskReason(reasons, "名称命中：" + nameHits.slice(0, 3).join(", "));
        }
      }

      const descriptionFields = [
        record.description,
        record.chineseDescription,
        asTaskArray(record.searchTerms).join(" "),
        record.resourceKind,
        record.resourceLabel,
        asTaskArray(relationRecord.inputs).join(" "),
        asTaskArray(relationRecord.outputs).join(" ")
      ].join(" ");
      const descriptionHits = taskFieldHits(tokens, descriptionFields);
      if (descriptionHits.length) {
        score += Math.min(32, 10 + descriptionHits.length * 5);
        addTaskReason(reasons, "描述/输入输出命中：" + descriptionHits.slice(0, 4).join(", "));
      }

      const categoryHits = taskFieldHits(tokens, record.category);
      const categoryText = normalizeTaskText(record.category);
      if (categoryText && (normalizedTask.includes(categoryText) || categoryHits.length)) {
        score += 12;
        addTaskReason(reasons, "分类匹配：" + String(record.category || "未分类"));
      }

      const resourceType = resourceTypeLabel(record);
      if (resourceType === "AgentCluster" && /agent|agents|集群|多代理|编排|协同|团队/.test(normalizedTask)) {
        score += 18;
        addTaskReason(reasons, "资源类型匹配：AgentCluster 适合多代理协同或编排任务");
      } else if (resourceType === "Agent" && /agent|智能体|代理/.test(normalizedTask)) {
        score += 14;
        addTaskReason(reasons, "资源类型匹配：Agent 适合单一角色型任务");
      }

      const card = cardBySkillName.get(key);
      if (card && card.dataset.installed === "true") score += 4;
      return {
        key,
        name,
        record,
        relationRecord,
        score,
        baseScore: score,
        reasons
      };
    }

    function applyRelationshipBoosts(candidates) {
      const byKey = new Map(candidates.map(candidate => [candidate.key, candidate]));
      const seedKeys = new Set(candidates.filter(candidate => candidate.baseScore > 0).sort((a, b) => b.baseScore - a.baseScore).slice(0, 8).map(candidate => candidate.key));
      relationshipEdges.forEach(edge => {
        const sourceKey = normalizeTaskKey(edge.source);
        const targetKey = normalizeTaskKey(edge.target);
        if (!sourceKey || !targetKey || sourceKey === targetKey) return;
        if (normalizeTaskKey(edge.targetKind || "skill") !== "skill") return;
        const weight = relationWeight(String(edge.type || ""));
        if (seedKeys.has(sourceKey) && byKey.has(targetKey)) {
          const candidate = byKey.get(targetKey);
          candidate.score += weight;
          addTaskReason(candidate.reasons, "已验证搭配：" + String(edge.source || "") + " " + relationLabel(edge.type) + " " + candidate.name);
        }
        if (seedKeys.has(targetKey) && byKey.has(sourceKey)) {
          const candidate = byKey.get(sourceKey);
          candidate.score += Math.max(4, weight - 2);
          addTaskReason(candidate.reasons, "已验证搭配：" + candidate.name + " " + relationLabel(edge.type) + " " + String(edge.target || ""));
        }
      });
    }

    function moveRecommendationBefore(items, firstKey, secondKey) {
      const firstIndex = items.findIndex(item => item.key === firstKey);
      const secondIndex = items.findIndex(item => item.key === secondKey);
      if (firstIndex < 0 || secondIndex < 0 || firstIndex < secondIndex) return;
      const item = items.splice(firstIndex, 1)[0];
      const nextSecondIndex = items.findIndex(entry => entry.key === secondKey);
      items.splice(nextSecondIndex, 0, item);
    }

    function technicalExecutionPhase(candidate) {
      const profile = capabilityProfileForRecord(candidate.record || {});
      const actions = new Set([...(candidate.matchedActions || []), ...(profile.actions || [])]);
      const capabilities = new Set([...(candidate.matchedCapabilities || []), ...(profile.capabilities || [])]);
      const outputs = new Set([...(candidate.matchedOutputs || []), ...(profile.outputs || [])]);
      const objects = new Set([...(candidate.matchedObjects || []), ...(profile.objects || [])]);
      if (actions.has("scrape") || actions.has("transcribe")) return { rank: 10, guidance: "先准备和获取任务所需输入" };
      if (actions.has("translate") || actions.has("analyze") || actions.has("summarize")) return { rank: 20, guidance: "再整理和分析输入信息" };
      if (capabilities.has("image_generation")) return { rank: 30, guidance: "先完成方案与素材设计" };
      if (capabilities.has("desktop_app") || capabilities.has("ui_development") || capabilities.has("interaction") || capabilities.has("persistence") || objects.has("desktop_pet") || outputs.has("webpage")) return { rank: 40, guidance: "实现核心功能和交互" };
      if (capabilities.has("visual_design")) return { rank: 30, guidance: "先完成方案与素材设计" };
      if (actions.has("test")) return { rank: 70, guidance: "测试并修正核心功能" };
      if (actions.has("deploy") || actions.has("publish")) return { rank: 80, guidance: "完成部署或发布" };
      return { rank: 50, guidance: "实现当前功能模块" };
    }

    function firstCoveredSubtaskIndex(candidate) {
      const ids = (candidate.coveredSubtaskIds || []).map(value => Number(value)).filter(Number.isFinite);
      return ids.length ? Math.min(...ids) : Number.MAX_SAFE_INTEGER;
    }

    function orderTaskRecommendations(items, plan) {
      const ordered = items.slice().sort((left, right) => {
        const phaseDelta = technicalExecutionPhase(left).rank - technicalExecutionPhase(right).rank;
        if (phaseDelta) return phaseDelta;
        const subtaskDelta = firstCoveredSubtaskIndex(left) - firstCoveredSubtaskIndex(right);
        if (subtaskDelta) return subtaskDelta;
        return right.score - left.score || left.name.localeCompare(right.name, "zh-CN");
      });
      for (let pass = 0; pass < 4; pass += 1) {
        relationshipEdges.forEach(edge => {
          const sourceKey = normalizeTaskKey(edge.source);
          const targetKey = normalizeTaskKey(edge.target);
          if (edge.type === "precedes") moveRecommendationBefore(ordered, sourceKey, targetKey);
          if (edge.type === "requires") moveRecommendationBefore(ordered, targetKey, sourceKey);
        });
      }
      return ordered;
    }

    function mergeStructuredCoreIntent(localIntent, globalIntent) {
      const merged = {
        ...localIntent,
        platforms: localIntent.platforms.length ? localIntent.platforms : globalIntent.platforms.slice(),
        actions: localIntent.actions.length ? localIntent.actions : globalIntent.actions.slice(),
        capabilities: localIntent.capabilities.length ? localIntent.capabilities : globalIntent.capabilities.slice()
      };
      const professionalActionSet = new Set(capabilityAliasCatalog.actions.filter(entry => entry.gate !== false).map(entry => entry.canonical));
      merged.professionalActions = merged.actions.filter(action => professionalActionSet.has(action));
      merged.matchMode = merged.platforms.length || merged.professionalActions.length ? "strict_gate" : "loose_compatible";
      merged.broad = merged.matchMode === "loose_compatible";
      return merged;
    }

    function structuredTaskPlan(taskText, semanticAnalysis) {
      const subtasks = splitTaskClauses(taskText);
      const texts = subtasks.length ? subtasks : [cleanReportLine(taskText)];
      const globalIntent = applySemanticIntentAnalysis(parseStructuredIntent(taskText), semanticAnalysis);
      const explicitSequence = /\u7136\u540e|\u63a5\u7740|\u6700\u540e|\u5148.+\u518d|\u518d\u5c06|\u518d\u628a/.test(taskText);
      return {
        globalIntent,
        explicitSequence,
        subtasks: texts.map((text, index) => {
          const localIntent = applySemanticIntentAnalysis(parseStructuredIntent(text), semanticAnalysis, index);
          return {
            id: index,
            text,
            intent: localIntent
          };
        })
      };
    }

    function structuredCandidateForTask(record, taskText, plan) {
      const key = normalizeTaskKey(record.name);
      const matches = plan.subtasks.map(subtask => ({ subtask, match: matchStructuredCandidate(record, subtask.intent) }));
      const passed = matches.filter(entry => entry.match.gatePassed);
      const matchedPlatforms = Array.from(new Set(passed.flatMap(entry => entry.match.matchedPlatforms)));
      const matchedActions = Array.from(new Set(passed.flatMap(entry => entry.match.matchedActions)));
      const matchedObjects = Array.from(new Set(passed.flatMap(entry => entry.match.matchedObjects)));
      const matchedOutputs = Array.from(new Set(passed.flatMap(entry => entry.match.matchedOutputs)));
      const matchedCapabilities = Array.from(new Set(passed.flatMap(entry => entry.match.matchedCapabilities)));
      const matchedConstraints = Array.from(new Set(passed.flatMap(entry => entry.match.matchedConstraints)));
      const matchedSpecificTerms = Array.from(new Set(passed.flatMap(entry => entry.match.matchedSpecificTerms)));
      const score = passed.length ? Math.max(...passed.map(entry => entry.match.score)) + Math.max(0, passed.length - 1) * 8 : 0;
      const confidence = passed.length ? Math.max(...passed.map(entry => entry.match.confidence)) : 0;
      const reasons = [];
      if (matchedPlatforms.length) reasons.push("\u5e73\u53f0 Gate \u547d\u4e2d\uff1a" + matchedPlatforms.join(", "));
      if (matchedActions.length) reasons.push("\u4e13\u4e1a\u52a8\u4f5c Gate \u547d\u4e2d\uff1a" + matchedActions.join(", "));
      if (matchedObjects.length) reasons.push("\u5bf9\u8c61\u547d\u4e2d\uff1a" + matchedObjects.join(", "));
      if (matchedOutputs.length) reasons.push("\u4ea7\u51fa\u547d\u4e2d\uff1a" + matchedOutputs.join(", "));
      if (matchedCapabilities.length) reasons.push("\u80fd\u529b\u547d\u4e2d\uff1a" + matchedCapabilities.join(", "));
      if (matchedSpecificTerms.length) reasons.push("\u4e13\u7528\u8bcd\u547d\u4e2d\uff1a" + matchedSpecificTerms.slice(0, 4).join(", "));
      return {
        key,
        name: String(record.name || ""),
        record,
        relationRecord: relationshipRecordBySkillName.get(key) || {},
        gatePassed: passed.length > 0,
        score,
        baseScore: score,
        confidence,
        reasons,
        matchedPlatforms,
        matchedActions,
        matchedObjects,
        matchedOutputs,
        matchedCapabilities,
        matchedConstraints,
        coveredSubtasks: passed.map(entry => entry.subtask.text),
        coveredSubtaskIds: passed.map(entry => entry.subtask.id),
        gateFailures: matches.flatMap(entry => entry.match.gateFailures)
      };
    }

    function localSkillMatchesForTask(taskText, semanticAnalysis) {
      const plan = structuredTaskPlan(taskText, semanticAnalysis);
      const directCandidates = skillRecords.filter(isAtomicSkillRecord).map(record => structuredCandidateForTask(record, taskText, plan)).filter(candidate => candidate.gatePassed);
      const candidates = expandLooseRelationshipCandidates(directCandidates, skillRecords.filter(isAtomicSkillRecord), relationshipEdges, plan);
      candidates.forEach(candidate => {
        if (!candidate.relationRecord || !Object.keys(candidate.relationRecord).length) candidate.relationRecord = relationshipRecordBySkillName.get(candidate.key) || {};
      });
      applyRelationshipBoosts(candidates);
      return candidates
        .filter(candidate => candidate.confidence >= 0.28)
        .sort((a, b) => b.score - a.score || b.baseScore - a.baseScore || a.name.localeCompare(b.name, "zh-CN"))
        .slice(0, 12);
    }

    function selectTaskRecommendations(candidates, plan, limit = 3) {
      const directCandidates = candidates.filter(candidate => !candidate.relationshipSupport);
      const primaryPool = directCandidates.length ? directCandidates : candidates;
      const selected = [];
      const covered = new Set();
      const chooseFrom = pool => {
        while (selected.length < limit) {
          const next = pool.filter(candidate => !selected.some(item => item.key === candidate.key)).sort((left, right) => {
            const leftNovelty = (left.coveredSubtaskIds || []).filter(id => !covered.has(id)).length;
            const rightNovelty = (right.coveredSubtaskIds || []).filter(id => !covered.has(id)).length;
            return rightNovelty - leftNovelty || right.score - left.score || left.name.localeCompare(right.name, "zh-CN");
          })[0];
          if (!next) return;
          selected.push(next);
          (next.coveredSubtaskIds || []).forEach(id => covered.add(id));
        }
      };
      chooseFrom(primaryPool);
      if (selected.length < limit) {
        const selectedKeys = new Set(selected.map(item => item.key));
        const supporting = candidates.filter(candidate => candidate.relationshipSupport && selectedKeys.has(normalizeTaskKey(candidate.relationshipSource)));
        chooseFrom(supporting);
      }
      return orderTaskRecommendations(selected, plan);
    }

    function recommendSkillsForTask(taskText, semanticAnalysis) {
      const plan = structuredTaskPlan(taskText, semanticAnalysis);
      return selectTaskRecommendations(localSkillMatchesForTask(taskText, semanticAnalysis), plan);
    }

    function primaryTaskInvocation(record) {
      const trigger = asTaskArray(record.triggers)[0];
      if (trigger) return trigger;
      return String.fromCharCode(36) + String(record.name || "");
    }

    function taskInvocationText(item, taskText, index, total) {
      const trigger = primaryTaskInvocation(item.record);
      const projectStatus = inferProjectStatus(taskText);
      const scope = coveredSubtasksForCandidate(item, splitTaskClauses(taskText)).join("；") || taskText;
      const projectInstruction = projectStatus === "【存量项目嵌入开发】"
        ? "先审阅现有项目结构和测试，以最小改动接入"
        : "从最小可运行骨架开始接入";
      const handoff = total > 1 ? "输出可继续传递给后续环节的结果。" : "输出实现和最小验证结果。";
      return [
        "任务：" + taskText,
        projectInstruction + "；在「" + scope + "」环节调用 " + trigger + "。",
        "仅处理该环节；仅调用已安装 Skill，缺失依赖时说明阻塞。" + handoff
      ].join("\n");
    }

    function uniqueTaskHints(hints) {
      return Array.from(new Set(hints.filter(Boolean)));
    }

    function taskMissingHints(item, selectedItems) {
      const hints = [];
      const selectedKeys = new Set(selectedItems.map(entry => entry.key));
      const card = cardBySkillName.get(item.key);
      if (!card) {
        hints.push("当前档案没有找到这个资源卡片，可能需要先安装或刷新档案。");
      } else if (card.dataset.installed !== "true") {
        hints.push("当前卡片没有检测到本机已安装来源，使用前请确认已安装。");
      }

      relationshipEdges.forEach(edge => {
        if (normalizeTaskKey(edge.source) !== item.key || edge.type !== "requires") return;
        const targetName = String(edge.target || "").trim();
        if (!targetName) return;
        const targetKey = normalizeTaskKey(targetName);
        if (normalizeTaskKey(edge.targetKind || "skill") !== "skill") {
          hints.push("依赖外部资源：" + targetName + "，需要自行准备。");
          return;
        }
        const targetCard = cardBySkillName.get(targetKey);
        if (!targetCard || targetCard.dataset.installed !== "true") {
          hints.push("依赖资源未检测到安装：" + targetName + "。");
        } else if (!selectedKeys.has(targetKey)) {
          hints.push("可先准备依赖资源：" + targetName + "。");
        }
      });

      const cleanHints = uniqueTaskHints(hints);
      return cleanHints.length ? cleanHints : ["未发现缺失或未安装依赖。"];
    }

    function cleanReportLine(value) {
      return String(value || "").replace(/\s+/g, " ").trim();
    }

    function splitTaskClauses(taskText) {
      const normalized = cleanReportLine(taskText);
      const segments = normalized
        .replace(/(然后|并且|同时|以及|最后|接着|再)/g, "，")
        .split(/[，,。；;\n]+/)
        .map(part => cleanReportLine(part))
        .filter(part => part.length >= 3);
      return Array.from(new Set(segments)).slice(0, 6);
    }

    function inferExpectedOutput(taskText) {
      const text = cleanReportLine(taskText);
      const match = text.match(/(?:生成|输出|返回|整理成|写成|创建|导出|产出|发布|提交)(.{2,80})/);
      if (match && match[1]) return cleanReportLine(match[1]);
      return "完成用户描述的任务，并产出可直接继续使用的结果。";
    }

    function inferPrerequisites(taskText) {
      const text = cleanReportLine(taskText);
      const hints = [];
      if (/基于|根据|参考|从|读取|上传|导入|已有|本地|仓库/.test(text)) {
        hints.push("需要用户提供或本机已有相关输入材料。");
      }
      if (/api|token|key|密钥|数据库|飞书|lark|github|vercel|supabase/i.test(text)) {
        hints.push("可能需要提前配置对应平台凭证或环境变量。");
      }
      if (!hints.length) hints.push("用户未明确额外前置条件，默认使用当前本地环境与输入文本。");
      return hints;
    }

    function analyzeUserIntent(taskText, semanticAnalysis) {
      const clauses = splitTaskClauses(taskText);
      const subtasks = clauses.length ? clauses : [cleanReportLine(taskText)];
      const structuredPlan = structuredTaskPlan(taskText, semanticAnalysis);
      return {
        coreGoal: cleanReportLine(taskText),
        prerequisites: inferPrerequisites(taskText),
        expectedOutput: inferExpectedOutput(taskText),
        subtasks,
        structuredIntent: structuredPlan.globalIntent,
        structuredPlan
      };
    }

    function candidateSearchText(candidate) {
      const record = candidate.record || {};
      const relationRecord = candidate.relationRecord || {};
      return [
        record.name,
        record.description,
        record.chineseDescription,
        record.category,
        asTaskArray(record.triggers).join(" "),
        asTaskArray(record.searchTerms).join(" "),
        asTaskArray(relationRecord.inputs).join(" "),
        asTaskArray(relationRecord.outputs).join(" ")
      ].join(" ");
    }

    function coveredSubtasksForCandidate(candidate, subtasks) {
      if (Array.isArray(candidate.coveredSubtasks)) return candidate.coveredSubtasks.slice(0, 6);
      const text = normalizeTaskText(candidateSearchText(candidate));
      const covered = [];
      subtasks.forEach((subtask, index) => {
        const tokens = taskTokens(subtask);
        const hits = tokens.filter(token => text.includes(token));
        if (hits.length || candidate.score >= 48 && index === 0) {
          covered.push(subtask);
        }
      });
      if (!covered.length && subtasks.length) covered.push(subtasks[0]);
      return Array.from(new Set(covered)).slice(0, 3);
    }

    function candidateFullyCoversSubtask(candidate, subtask) {
      const coveredIds = new Set((candidate.coveredSubtaskIds || []).map(value => Number(value)).filter(Number.isFinite));
      if (subtask && Number.isFinite(Number(subtask.id)) && !coveredIds.has(Number(subtask.id))) return false;
      const intent = subtask && subtask.intent ? subtask.intent : null;
      if (!intent || intent.matchMode !== "strict_gate") return true;

      const matchedPlatforms = new Set(candidate.matchedPlatforms || []);
      const matchedActions = new Set(candidate.matchedActions || []);
      const hasAllPlatforms = !(intent.platforms || []).some(platform => !matchedPlatforms.has(platform));
      const hasAllProfessionalActions = !(intent.professionalActions || []).some(action => !matchedActions.has(action));
      return hasAllPlatforms && hasAllProfessionalActions;
    }

    function uncoveredSubtasks(analysis, localMatches) {
      const structuredSubtasks = analysis && analysis.structuredPlan && Array.isArray(analysis.structuredPlan.subtasks)
        ? analysis.structuredPlan.subtasks
        : [];
      if (structuredSubtasks.length) {
        return structuredSubtasks
          .filter(subtask => !(localMatches || []).some(candidate => candidateFullyCoversSubtask(candidate, subtask)))
          .map(subtask => subtask.text);
      }
      if (!localMatches.length) return analysis.subtasks.slice();
      const covered = new Set(localMatches.flatMap(candidate => candidate.coveredSubtasks || []));
      return analysis.subtasks.filter(subtask => !covered.has(subtask));
    }

    function compactSkillId(name) {
      const value = cleanReportLine(name);
      return value || "unknown-skill";
    }

    function githubSearchKeywordForGap(gap) {
      const intentTerms = githubSearchKeywordForIntent(parseStructuredIntent(gap));
      const fallbackTerms = structuredSpecificTerms(gap).filter(term => !genericIntentTerms.has(term)).slice(0, 6).join(" ");
      const capabilityTerms = intentTerms || fallbackTerms;
      return [capabilityTerms, "codex", "SKILL.md", "agent template"].filter(Boolean).join(" ");
    }

    function githubSearchQueriesForGap(gap) {
      const intent = parseStructuredIntent(gap);
      const english = githubSearchKeywordForIntent(intent);
      const chinese = cleanReportLine(gap);
      const platforms = intent.platforms.filter(term => term && !genericIntentTerms.has(term));
      const actions = intent.actions.filter(term => term && !genericIntentTerms.has(term));
      const actionRepositoryTerms = actions.map(action => action === "scrape" ? "scraper" : action);
      const queries = [
        [chinese, "Skill"].filter(Boolean).join(" "),
        ...platforms.map(platform => platform + " skill"),
        ...platforms.flatMap(platform => actions.map(action => [platform, action, "skill"].join(" "))),
        ...platforms.flatMap(platform => actionRepositoryTerms.map(action => [platform, action].join(" "))),
        [english, "skill"].filter(Boolean).join(" ")
      ];
      return Array.from(new Set(queries.map(cleanReportLine).filter(Boolean))).slice(0, 6);
    }

    function githubSearchUrl(query) {
      return "https://github.com/search?q=" + encodeURIComponent(query) + "&type=repositories";
    }

    function githubCandidateForGap(gap) {
      const shortName = cleanReportLine(gap).slice(0, 36) || "未覆盖子任务";
      const query = githubSearchKeywordForGap(gap);
      return {
        name: "Github待检索候选: " + shortName + " Skill模板",
        usage: "覆盖本地Skill未完整命中的子任务：" + gap,
        query,
        queries: githubSearchQueriesForGap(gap),
        link: githubSearchUrl(query),
        githubStatus: "pending",
        githubResults: [],
        githubError: "",
        structuredIntent: parseStructuredIntent(gap),
        feature: "外部资源，需要导入本地仓库后方可调用；优先选择包含 SKILL.md、README、输入输出示例或 Function Calling schema 的标准化仓库。"
      };
    }

    function loadGithubSearchCache() {
      try {
        return JSON.parse(localStorage.getItem(githubSearchCacheKey) || "{}");
      } catch (error) {
        return {};
      }
    }

    function saveGithubSearchCache(cache) {
      try {
        localStorage.setItem(githubSearchCacheKey, JSON.stringify(cache));
      } catch (error) {
      }
    }

    function isSafeGithubRepoUrl(value) {
      return /^https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\/?$/.test(String(value || ""));
    }

    function normalizeGithubRepo(item) {
      return {
        name: String(item.full_name || item.name || ""),
        url: String(item.html_url || ""),
        description: cleanReportLine(item.description || "无描述"),
        topics: Array.isArray(item.topics) ? item.topics.map(topic => String(topic)) : [],
        stars: Number(item.stargazers_count || 0),
        updatedAt: String(item.updated_at || "").slice(0, 10)
      };
    }

    function filterGithubResultsForIntent(candidate, repositories) {
      const intent = candidate.structuredIntent || parseStructuredIntent(candidate.usage || candidate.query || "");
      const minimumScore = intent.broad ? 28 : 40;
      return repositories.map(repo => {
        const match = matchStructuredCandidate({
          name: repo.name,
          description: [repo.description, ...(repo.topics || [])].join(" "),
          category: "Github repository",
          triggers: []
        }, intent);
        const evidenceCount = match.matchedPlatforms.length + match.matchedActions.length + match.matchedObjects.length + match.matchedOutputs.length + match.matchedCapabilities.length;
        const skillSignal = /\b(skill|agent|codex|mcp|prompt)\b/i.test([repo.name, repo.description, ...(repo.topics || [])].join(" "));
        const usefulnessScore = match.score + (skillSignal ? 12 : 0) + Math.min(8, Math.log10(Math.max(1, repo.stars + 1)) * 2);
        return {
          ...repo,
          gatePassed: match.gatePassed,
          matchScore: match.score,
          confidence: match.confidence,
          matchedPlatforms: match.matchedPlatforms,
          matchedActions: match.matchedActions,
          usefulnessScore,
          skillSignal,
          evidenceCount
        };
      }).filter(repo => repo.gatePassed && repo.evidenceCount > 0 && repo.usefulnessScore >= minimumScore)
        .sort((a, b) => b.usefulnessScore - a.usefulnessScore || b.stars - a.stars || a.name.localeCompare(b.name))
        .slice(0, 3);
    }

    async function verifyGithubSkillStructure(repo) {
      const match = String(repo.url || "").match(/^https:\/\/github\.com\/([A-Za-z0-9_.-]+)\/([A-Za-z0-9_.-]+)\/?$/);
      if (!match) return { ...repo, structureVerified: false, structureScore: 0 };
      try {
        const apiUrl = "https://api.github.com/repos/" + encodeURIComponent(match[1]) + "/" + encodeURIComponent(match[2]) + "/contents";
        const response = await fetch(apiUrl, { headers: { Accept: "application/vnd.github+json" } });
        if (!response.ok) throw new Error("GitHub Contents API " + response.status);
        const entries = await response.json();
        const names = new Set((Array.isArray(entries) ? entries : []).map(entry => String(entry.name || "").toLowerCase()));
        const hasSkillStructure = names.has("skill.md") || names.has("skills") || names.has(".agents");
        return { ...repo, structureVerified: hasSkillStructure, structureScore: hasSkillStructure ? 20 : 0 };
      } catch (error) {
        return { ...repo, structureVerified: false, structureScore: 0 };
      }
    }

    function githubCandidateResultLines(candidate) {
      if (candidate.githubStatus === "pending") return ["Github检索结果：正在检索GitHub仓库链接..."];
      if (candidate.githubStatus === "error") return ["Github检索结果：检索失败，未返回可用仓库链接。"];
      const results = Array.isArray(candidate.githubResults) ? candidate.githubResults : [];
      if (!results.length) return ["Github检索结果：未找到匹配仓库。"];
      const lines = ["Github检索结果："];
      results.forEach((repo, index) => {
        lines.push("  " + (index + 1) + ". " + repo.name + "｜" + repo.url + "｜stars " + repo.stars + "｜" + repo.description);
      });
      return lines;
    }

    async function searchGithubCandidate(candidate, onProgress) {
      const queries = Array.from(new Set((candidate.queries || [candidate.query]).map(cleanReportLine).filter(Boolean)));
      if (!queries.length) {
        candidate.githubStatus = "done";
        candidate.githubResults = [];
        return candidate;
      }
      const cache = loadGithubSearchCache();
      const now = Date.now();
      const repositories = new Map();
      candidate.githubStatus = "searching";
      try {
        for (let index = 0; index < queries.length; index += 1) {
          const query = queries[index];
          if (onProgress) onProgress(candidate, index + 1, queries.length, query);
          await wait(350);
          const cached = cache[query];
          let normalizedResults = [];
          if (cached && now - Number(cached.cachedAt || 0) < 86400000) {
            normalizedResults = Array.isArray(cached.results) ? cached.results : [];
          } else {
            const apiUrl = "https://api.github.com/search/repositories?q=" + encodeURIComponent(query) + "&per_page=10";
            const response = await fetch(apiUrl, { headers: { Accept: "application/vnd.github+json" } });
            if (!response.ok) throw new Error("GitHub API " + response.status);
            const data = await response.json();
            normalizedResults = (Array.isArray(data.items) ? data.items : []).map(normalizeGithubRepo);
            cache[query] = { cachedAt: now, results: normalizedResults };
          }
          normalizedResults.filter(repo => repo.name && isSafeGithubRepoUrl(repo.url)).forEach(repo => repositories.set(repo.url, repo));
        }
        const relevant = filterGithubResultsForIntent(candidate, Array.from(repositories.values()));
        const verified = await Promise.all(relevant.map(verifyGithubSkillStructure));
        const results = verified.filter(repo => repo.structureVerified);
        candidate.githubStatus = "done";
        candidate.githubResults = results;
        candidate.processedQueries = queries.slice();
        saveGithubSearchCache(cache);
      } catch (error) {
        candidate.githubStatus = "error";
        candidate.githubError = error && error.message ? error.message : "GitHub search failed";
        candidate.githubResults = [];
        candidate.processedQueries = queries.slice();
      }
      return candidate;
    }

    async function resolveGithubCandidates(report, onProgress) {
      if (!report.externalCandidates.length) return Promise.resolve(report);
      report.externalCandidates.forEach(candidate => {
        candidate.githubStatus = candidate.githubStatus || "pending";
      });
      for (const candidate of report.externalCandidates) {
        await searchGithubCandidate(candidate, onProgress);
      }
      return report;
    }

    function selectedDependencyEdges(recommendations) {
      const selected = new Set(recommendations.map(item => item.key));
      return relationshipEdges.filter(edge => {
        const sourceKey = normalizeTaskKey(edge.source);
        const targetKey = normalizeTaskKey(edge.target);
        return selected.has(sourceKey) && selected.has(targetKey) && (edge.type === "requires" || edge.type === "precedes");
      });
    }

    function hasSelectedDependency(recommendations) {
      return selectedDependencyEdges(recommendations).length > 0;
    }

    function recommendationRelationshipKind(taskText, recommendations) {
      if (recommendations.length <= 1) return "single";
      if (hasSelectedDependency(recommendations)) return "serial";
      if (/\u540c\u65f6|\u5e76\u884c|\u5206\u522b|\u5404\u81ea|\u6279\u91cf|\u591a\u4e2a/.test(taskText)) return "parallel";
      return "alternative";
    }

    function inferExecutionTopology(taskText, recommendations, analysis) {
      const kind = recommendationRelationshipKind(taskText, recommendations);
      if (kind === "serial") return "【多资源串行协同】";
      if (kind === "parallel") return "【多资源并行协同】";
      if (kind === "alternative") return "【候选资源，择一使用】";
      return "【单资源独立执行】";
    }

    function inferDependencyShape(taskText, recommendations, analysis) {
      const kind = recommendationRelationshipKind(taskText, recommendations);
      if (kind === "serial") return "串行关系：存在 requires/precedes 依赖，前一Skill输出作为后一Skill输入。";
      if (kind === "parallel") return "并行关系：多个Skill共享输入、分别执行，最后汇总结果。";
      if (kind === "alternative") return "或关系：这些Skill互为备选，不要求先后顺序，选择最适合的一个即可。";
      return "单Skill独立完成，无跨Skill依赖。";
    }

    function inferRunMode(taskText, recommendations, analysis) {
      const text = cleanReportLine(taskText);
      const fixedSignal = /固定|流水线|流程|自动|一键|批量|定时|每天|周期|标准化|导入.*输出|先.*再|然后|最后|生成.*发布|采集.*整理/i.test(text);
      const dynamicSignal = /临时|一次|探索|研究|分析一下|帮我想|怎么做|不确定|自由|根据情况|自主|动态/i.test(text);
      const relationshipKind = recommendationRelationshipKind(taskText, recommendations);
      const hasPipelineShape = relationshipKind === "serial" || relationshipKind === "parallel" || analysis.subtasks.length > 1;
      if ((fixedSignal || hasPipelineShape) && !dynamicSignal) {
        return {
          mode: "【固定编排流水线】",
          reason: "任务可拆成明确步骤，Skill之间存在可描述的输入输出传递关系，适合封装为AgentCluster后自动驱动整套流程。"
        };
      }
      return {
        mode: "【LLM动态调度】",
        reason: "任务边界或执行路径较灵活，暂不强绑定固定顺序；更适合向Codex提供可用Skill清单，由LLM根据上下文自主选择调用时机与组合。"
      };
    }

    function inferProjectStatus(taskText) {
      const text = cleanReportLine(taskText);
      if (/已有|现有|当前项目|项目里|仓库|代码库|业务代码|存量|嵌入|集成|改造|接入|agent代码|运行中/i.test(text)) {
        return "【存量项目嵌入开发】";
      }
      if (/0-1|从零|新项目|新建|搭建|创建|做一个|开发一个|暂无|没有.*代码|空项目/i.test(text)) {
        return "【0-1新项目】";
      }
      return "【0-1新项目】";
    }

    function yamlScalar(value) {
      return String(value || "").replace(/\\/g, "\\\\").replace(/"/g, '\\"');
    }

    function skillOutputName(candidate, index) {
      const base = normalizeTaskKey(candidate.name).replace(/[^a-z0-9_-]+/g, "-").replace(/^-+|-+$/g, "");
      return (base || ("skill-" + (index + 1))) + "-output";
    }

    function generateClusterYaml(report) {
      const skills = report.recommendations;
      const lines = [];
      lines.push("name: generated-skill-cluster");
      lines.push("type: AgentCluster");
      lines.push("description: \"" + yamlScalar("由Skill档案管理根据用户任务自动生成的固定编排流水线") + "\"");
      lines.push("mode: fixed_pipeline");
      lines.push("entrypoint: user_request");
      lines.push("inputs:");
      lines.push("  user_request:");
      lines.push("    type: text");
      lines.push("    required: true");
      lines.push("  source_materials:");
      lines.push("    type: files_or_text");
      lines.push("    required: false");
      lines.push("skills:");
      if (!skills.length) {
        lines.push("  []");
      } else {
        skills.forEach((candidate, index) => {
          lines.push("  - id: \"" + yamlScalar(compactSkillId(candidate.name)) + "\"");
          lines.push("    name: \"" + yamlScalar(candidate.name) + "\"");
          lines.push("    invoke: \"" + yamlScalar(primaryTaskInvocation(candidate.record)) + "\"");
          lines.push("    role: \"" + yamlScalar(coveredSubtasksForCandidate(candidate, report.analysis.subtasks).join("；")) + "\"");
          lines.push("    input_from: \"" + (index === 0 ? "user_request" : skillOutputName(skills[index - 1], index - 1)) + "\"");
          lines.push("    output_as: \"" + skillOutputName(candidate, index) + "\"");
        });
      }
      lines.push("edges:");
      if (skills.length <= 1) {
        lines.push("  []");
      } else {
        for (let index = 1; index < skills.length; index += 1) {
          lines.push("  - from: \"" + skillOutputName(skills[index - 1], index - 1) + "\"");
          lines.push("    to: \"" + yamlScalar(compactSkillId(skills[index].name)) + "\"");
          lines.push("    mapping: \"previous_output -> input\"");
        }
      }
      lines.push("outputs:");
      lines.push("  final_result: \"" + (skills.length ? skillOutputName(skills[skills.length - 1], skills.length - 1) : "manual_result") + "\"");
      return lines.join("\n");
    }

    function dynamicDispatchPrompt(report) {
      const skillLines = report.recommendations.length
        ? report.recommendations.map(candidate => "- " + primaryTaskInvocation(candidate.record) + "：" + coveredSubtasksForCandidate(candidate, report.analysis.subtasks).join("；"))
        : ["- 暂无本地Skill，请先导入第三部分候选Skill后再调度。"];
      return [
        "将以下Skill清单提供给Codex，由LLM根据实时任务动态选择调用顺序：",
        skillLines.join("\n"),
        "调度规则：优先调用覆盖当前子任务最直接的Skill；当上一步输出能作为下一步输入时再串联；不强制固定顺序。"
      ].join("\n");
    }

    function projectIntegrationInstruction(report) {
      const existingProject = report.projectStatus === "【存量项目嵌入开发】";
      const relationship = recommendationRelationshipKind(report.analysis.coreGoal, report.recommendations);
      const relationshipRule = relationship === "serial"
        ? "调用方式：按顺序交接前一步输出。"
        : relationship === "parallel"
          ? "调用方式：各环节可独立执行，最后汇总。"
          : relationship === "alternative"
            ? "调用方式：以下为可替代选择，只调用最匹配的一项。"
            : "调用方式：直接调用。";
      const lines = [
        "任务：" + report.analysis.coreGoal,
        existingProject ? "模式：存量项目，先读结构和测试，以最小改动接入。" : "模式：0-1 新项目，先建最小可运行骨架。",
        relationshipRule,
        "Skill 调用："
      ];
      report.recommendations.forEach((item, index) => {
        const trigger = primaryTaskInvocation(item.record);
        const tasks = coveredSubtasksForCandidate(item, report.analysis.subtasks).join("；") || "当前任务环节";
        const inputRule = relationship === "serial" && index > 0
          ? "接收上一步结果；"
          : relationship === "parallel"
            ? "使用原始任务输入；"
            : relationship === "alternative"
              ? "仅在最匹配当前技术栈和输入时调用；"
              : "";
        const outputRule = relationship === "serial" && index < report.recommendations.length - 1
          ? "输出交给下一步。"
          : relationship === "parallel"
            ? "保留结果用于汇总。"
            : "输出实现和验证结果。";
        lines.push((index + 1) + ". " + trigger + "：" + tasks + "。" + inputRule + outputRule);
      });
      lines.push("仅调用已安装 Skill；缺失依赖时说明阻塞，不编造结果。");
      return lines.join("\n");
    }

    function stepOrdinal(index) {
      return ["第一步", "第二步", "第三步", "第四步", "第五步"][index] || ("第" + (index + 1) + "步");
    }

    function localSkillLine(candidate, index, analysis) {
      const tasks = coveredSubtasksForCandidate(candidate, analysis.subtasks).join("；");
      const id = compactSkillId(candidate.name);
      const type = resourceTypeLabel(candidate.record);
      return (index + 1) + ". [" + id + " | " + candidate.name + " | " + type + "]：承担任务：" + tasks + "。匹配原因：" + (candidate.reasons.slice(0, 3).join("；") || "本地关系数据命中") + "。";
    }

    function executionStepLine(candidate, index, recommendations, analysis, topology) {
      const type = resourceTypeLabel(candidate.record);
      const tasks = coveredSubtasksForCandidate(candidate, analysis.subtasks).join("；");
      let input = index === 0 ? "用户原始需求文本及相关输入材料" : "上一步输出的结构化结果";
      if (topology.indexOf("并行") >= 0 && index > 0) input = "同一份用户原始需求文本或独立输入材料";
      const parallelNote = topology.indexOf("并行") >= 0 && index > 0 ? "，可与前序资源并行执行" : "";
      return (index + 1) + ". " + stepOrdinal(index) + "：" + candidate.name + " " + type + parallelNote + "，接收" + input + "作为入参，作用：" + tasks + "。可复制调用指令：" + taskInvocationText(candidate, analysis.coreGoal, index, recommendations.length) + "。";
    }

    function fallbackExecutionLine(index, externalCandidates) {
      const target = externalCandidates[index] || externalCandidates[0];
      const name = target ? target.name : "第三部分候选Skill";
      const usage = target ? target.usage : "补齐本地缺失能力";
      return (index + 1) + ". " + stepOrdinal(index) + "：" + name + "，作用：" + usage + "。";
    }

    function githubSectionLines(externalCandidates) {
      const lines = [];
      lines.push("# 三、Github待导入候选Skill（本地缺失能力）");
      if (!externalCandidates.length) {
        lines.push("无。本地Skill已覆盖当前任务，不需要Github补充。");
      } else {
        externalCandidates.forEach((candidate, index) => {
          lines.push((index + 1) + ". 名称：" + candidate.name);
          lines.push("能力说明：" + candidate.usage + "【需导入本地仓库后方可使用】");
          githubCandidateResultLines(candidate).forEach(line => lines.push(line));
        });
      }
      return lines;
    }

    function refreshGithubSectionText(report) {
      const nextSectionText = githubSectionLines(report.externalCandidates).join("\n");
      if (report.githubSectionText) {
        report.text = report.text.replace(report.githubSectionText, nextSectionText);
      }
      report.githubSectionText = nextSectionText;
      return report;
    }

    function buildSkillMatchReport(taskText, semanticAnalysis) {
      const analysis = analyzeUserIntent(taskText, semanticAnalysis);
      const localMatches = localSkillMatchesForTask(taskText, semanticAnalysis);
      const recommendations = selectTaskRecommendations(localMatches, analysis.structuredPlan);
      const gaps = uncoveredSubtasks(analysis, recommendations);
      const externalCandidates = gaps.map(githubCandidateForGap);
      const topology = inferExecutionTopology(taskText, recommendations, analysis);
      const dependencyShape = inferDependencyShape(taskText, recommendations, analysis);
      const runMode = inferRunMode(taskText, recommendations, analysis);
      const projectStatus = inferProjectStatus(taskText);
      const lines = [];
      const fence = String.fromCharCode(96).repeat(3);

      lines.push("# 一、用户意图与子任务拆解");
      lines.push("核心目标：" + analysis.coreGoal + "（前置条件：" + analysis.prerequisites.join("；") + "；最终期望输出：" + analysis.expectedOutput + "）");
      lines.push("子任务清单：");
      analysis.subtasks.forEach((subtask, index) => {
        lines.push((index + 1) + ". " + subtask);
      });
      lines.push("");

      lines.push("# 二、本地匹配可用Skill");
      if (!localMatches.length) {
        lines.push("【本地无可用Skill，建议导入下方Github资源】");
      } else {
        localMatches.forEach((candidate, index) => {
          const tasks = coveredSubtasksForCandidate(candidate, analysis.subtasks).join("；");
          lines.push((index + 1) + ". " + compactSkillId(candidate.name) + "｜" + candidate.name + "：承担子任务说明：" + tasks + "。匹配原因：" + (candidate.reasons.slice(0, 3).join("；") || "本地Skill描述、分类或关系数据命中") + "。");
        });
      }
      lines.push("");

      const githubLines = githubSectionLines(externalCandidates);
      githubLines.forEach(line => lines.push(line));
      lines.push("");

      lines.push("# 四、推荐运行模式判定");
      lines.push("推荐模式：" + runMode.mode);
      lines.push("选择理由：" + runMode.reason);
      lines.push("用户工程现状预判：" + projectStatus);
      lines.push("");

      lines.push("# 五、Skill组合方案");
      lines.push("执行依赖关系（串行/并行）：" + dependencyShape);
      lines.push("技能间数据传递说明：");
      if (recommendations.length) {
        recommendations.forEach((candidate, index) => {
          const input = index === 0 ? "用户原始需求文本、source_materials" : skillOutputName(recommendations[index - 1], index - 1);
          const output = skillOutputName(candidate, index);
          lines.push((index + 1) + ". " + candidate.name + "：输入=" + input + "；输出=" + output + "；承担=" + coveredSubtasksForCandidate(candidate, analysis.subtasks).join("；") + "。");
        });
      } else {
        lines.push("1. 当前本地无可执行Skill链路；需先导入第三部分候选Skill，再重新生成组合方案。");
      }
      lines.push("");

      lines.push("# 六、落地集成操作指南（最重要部分，区分场景给出可执行步骤）");
      lines.push("## 场景分支A：推荐模式=固定编排流水线");
      lines.push("交付产物：可导入Skill管理器的AgentCluster配置");
      lines.push("操作步骤：");
      lines.push("1. 将涉及的全部Skill导入仓库（外部Github技能先完成导入）");
      lines.push("2. 使用下方Cluster配置新建集群资源");
      lines.push(fence + "yaml");
      lines.push(generateClusterYaml({ recommendations, analysis }));
      lines.push(fence);
      lines.push("3. 将Cluster入口输入绑定为用户原始需求、文件路径或业务系统事件。");
      lines.push("4. 按配置中的edges顺序传递每个Skill的输出，最后读取final_result。");
      lines.push("");
      lines.push("## 场景分支B：推荐模式=LLM动态调度");
      lines.push("交付产物：提供给Codex的可用Skill清单与动态调度提示词");
      lines.push("操作步骤：");
      lines.push("1. 确认本地Skill已安装；外部候选Skill先导入后刷新档案。");
      lines.push("2. 将下方调度提示词交给Codex，让LLM按实时上下文选择调用顺序。");
      lines.push(fence + "text");
      lines.push(dynamicDispatchPrompt({ recommendations, analysis }));
      lines.push(fence);
      if (projectStatus === "【存量项目嵌入开发】") {
        lines.push("3. 在现有Agent/业务代码中增加Skill调用入口，保持原有业务状态、日志、鉴权和错误处理不被覆盖。");
        lines.push("4. 用小范围真实输入做回归测试，确认新增Skill不会破坏存量流程。");
      } else {
        lines.push("3. 先按Cluster或动态调度提示搭建最小可运行版本，再补充UI、存储、权限和部署脚本。");
        lines.push("4. 使用一组样例任务验证每个Skill的输入输出是否能串起来。");
      }
      const dependencyHints = recommendations.flatMap(item => taskMissingHints(item, recommendations)).filter(hint => hint !== "未发现缺失或未安装依赖。");
      lines.push("额外注意：" + (dependencyHints.length ? uniqueTaskHints(dependencyHints).join("；") : "未发现本地依赖缺失；如任务涉及平台API，仍需自行确认密钥和环境变量。"));

      return {
        text: lines.join("\n"),
        githubSectionText: githubLines.join("\n"),
        recommendations,
        localMatches,
        externalCandidates,
        analysis,
        topology,
        runMode,
        projectStatus,
        searchAudit: {
          localMatchCount: localMatches.length,
          githubRequested: externalCandidates.length > 0,
          githubQueryCount: 0,
          githubQualifiedCount: 0
        },
        semanticAnalysis: semanticAnalysis || { enabled: false, source: "local" },
        dependencyShape
      };
    }

    function appendTaskSection(parent, title, values, extraClass) {
      const section = document.createElement("div");
      section.className = "task-rec-section" + (extraClass ? " " + extraClass : "");
      const label = document.createElement("strong");
      label.textContent = title;
      section.appendChild(label);
      const list = document.createElement("ul");
      values.forEach(value => {
        const item = document.createElement("li");
        item.textContent = value;
        list.appendChild(item);
      });
      section.appendChild(list);
      parent.appendChild(section);
    }

    async function copyTaskAdvisorText(button, text, skillNames) {
      const original = button.textContent;
      try {
        await copyTextToClipboard(text);
        asTaskArray(skillNames).forEach(skillName => {
          const card = cardBySkillName.get(normalizeTaskKey(skillName));
          if (card) {
            recordCall(card);
            feedPetForSkill(card.dataset.name);
          }
        });
        button.textContent = "已复制";
      } catch (error) {
        button.textContent = "复制失败";
      }
      setTimeout(() => { button.textContent = original; }, 1200);
    }

    function resourceSourceLink(record) {
      const link = cleanReportLine(record && record.link);
      if (/^https?:\/\//i.test(link)) return link;
      return "";
    }

    function resourceInstallHint(item) {
      const card = cardBySkillName.get(item.key);
      const link = resourceSourceLink(item.record);
      if (card && card.dataset.installed === "true") return "已安装，可直接调用。";
      if (link) return "未检测到本机安装。请打开来源链接，按仓库说明安装或导入后刷新本页。";
      return "未检测到本机安装。请先导入本地 Skill/Agent 仓库，或补充 GitHub 来源后刷新本页。";
    }

    function resourceFunctionSummary(item) {
      const record = item.record || {};
      const summary = cleanReportLine(record.chineseDescription || record.description);
      if (summary) return summary;
      return resourceTypeLabel(record) + " 资源，用于承接与 " + String(record.category || "当前任务") + " 相关的子任务。";
    }

    function resourceNeedExplanation(item, report) {
      const tasks = coveredSubtasksForCandidate(item, report.analysis.subtasks);
      const relationshipKind = recommendationRelationshipKind(report.analysis.coreGoal, report.recommendations);
      if (relationshipKind === "alternative") {
        return "\u8fd9\u662f\u53ef\u72ec\u7acb\u8986\u76d6\u4efb\u52a1\u7684\u5907\u9009\u4e4b\u4e00\uff0c\u4e0e\u5176\u4ed6\u5907\u9009\u662f\u6216\u5173\u7cfb\uff0c\u4e0d\u9700\u8981\u5168\u90e8\u4f7f\u7528\u3002\u53ef\u627f\u62c5\uff1a" + tasks.join("\uff1b");
      }
      const type = resourceTypeLabel(item.record);
      let prefix = type === "AgentCluster" ? "需要它来组织一组 Agent 协同处理：" : (type === "Agent" ? "需要它来承担明确角色型任务：" : "需要它来完成原子任务：");
      return prefix + tasks.join("；");
    }

    function taskSupportStages(item) {
      const fields = [
        ["\u5e73\u53f0", item.matchedPlatforms],
        ["\u52a8\u4f5c", item.matchedActions],
        ["\u5bf9\u8c61", item.matchedObjects],
        ["\u4ea7\u51fa", item.matchedOutputs],
        ["\u9650\u5236", item.matchedConstraints],
        ["\u80fd\u529b", item.matchedCapabilities]
      ];
      return fields
        .filter(([, values]) => Array.isArray(values) && values.length)
        .map(([label, values]) => label + "\uff1a" + values.map(capabilityDisplayLabel).join("/"))
        .join("\uff1b");
    }

    function appendResourceTextBlock(parent, title, content) {
      const block = document.createElement("div");
      block.className = "task-resource-block";
      const label = document.createElement("strong");
      label.textContent = title;
      block.appendChild(label);
      const text = document.createElement("div");
      text.textContent = content;
      block.appendChild(text);
      parent.appendChild(block);
    }

    function appendResourceListBlock(parent, title, values) {
      const block = document.createElement("div");
      block.className = "task-resource-block";
      const label = document.createElement("strong");
      label.textContent = title;
      block.appendChild(label);
      const list = document.createElement("ul");
      values.forEach(value => {
        const item = document.createElement("li");
        item.textContent = value;
        list.appendChild(item);
      });
      block.appendChild(list);
      parent.appendChild(block);
    }

    function createLocalResourceCard(item, report, index, selectedKeys) {
      const card = document.createElement("article");
      const sourceCard = cardBySkillName.get(item.key);
      const installed = !!(sourceCard && sourceCard.dataset.installed === "true");
      const selected = selectedKeys.has(item.key);
      card.className = "task-resource-card" + (selected ? " selected" : "") + (installed ? "" : " uninstalled");

      const top = document.createElement("div");
      top.className = "task-resource-top";
      const title = document.createElement("div");
      title.className = "task-resource-title";
      const name = document.createElement("strong");
      const sourceUrl = resourceSourceLink(item.record);
      if (/^https:\/\/github\.com\//i.test(sourceUrl)) {
        const nameLink = document.createElement("a");
        nameLink.className = "task-resource-name-link";
        nameLink.href = sourceUrl;
        nameLink.target = "_blank";
        nameLink.rel = "noreferrer";
        nameLink.textContent = item.name;
        name.appendChild(nameLink);
      } else {
        name.textContent = item.name;
      }
      const badges = document.createElement("div");
      badges.className = "task-resource-badges";
      [resourceTypeLabel(item.record), String(item.record.category || "未分类"), selected ? "推荐方案" : "候选资源"].forEach(value => {
        const badge = document.createElement("span");
        badge.textContent = value;
        badges.appendChild(badge);
      });
      const stateBadge = document.createElement("span");
      stateBadge.className = installed ? "installed" : "missing";
      stateBadge.textContent = installed ? "已安装" : "未安装/未检测";
      badges.appendChild(stateBadge);
      title.appendChild(name);
      title.appendChild(badges);
      top.appendChild(title);
      card.appendChild(top);

      const description = document.createElement("p");
      description.className = "task-resource-description";
      description.textContent = String(item.record.chineseDescription || item.record.description || "该 Skill 可承接当前任务中的对应功能模块。");
      card.appendChild(description);

      const actions = document.createElement("div");
      actions.className = "task-card-actions";
      const command = taskInvocationText(item, report.analysis.coreGoal, 0, 1);
      const copyButton = document.createElement("button");
      copyButton.type = "button";
      copyButton.textContent = installed ? "复制调用指令" : "复制安装后调用指令";
      copyButton.addEventListener("click", () => copyTaskAdvisorText(copyButton, command, item.name));
      actions.appendChild(copyButton);

      if (sourceCard) {
        const locateButton = document.createElement("button");
        locateButton.type = "button";
        locateButton.textContent = "查看档案卡";
        locateButton.addEventListener("click", () => flashPetCard(sourceCard));
        actions.appendChild(locateButton);
      }
      card.appendChild(actions);
      return card;
    }

    function createExternalResourceCard(candidate, index) {
      const card = document.createElement("article");
      card.className = "task-resource-card external";
      const results = Array.isArray(candidate.githubResults) ? candidate.githubResults : [];

      const top = document.createElement("div");
      top.className = "task-resource-top";
      const title = document.createElement("div");
      title.className = "task-resource-title";
      const name = document.createElement("strong");
      if (results.length) {
        const candidateTitleLink = document.createElement("a");
        candidateTitleLink.href = results[0].url;
        candidateTitleLink.target = "_blank";
        candidateTitleLink.rel = "noreferrer";
        candidateTitleLink.textContent = candidate.name;
        name.appendChild(candidateTitleLink);
      } else {
        name.textContent = candidate.name;
      }
      const badges = document.createElement("div");
      badges.className = "task-resource-badges";
      const externalBadges = candidate.installCommand ? ["Github\u5019\u9009", "\u5f85\u5bfc\u5165\uff5c\u5916\u90e8\u8d44\u6e90"] : ["Github候选", "外部资源", "需导入"];
      externalBadges.forEach(value => {
        const badge = document.createElement("span");
        badge.className = value === "需导入" || value.includes("\u5f85\u5bfc\u5165") ? "missing" : "";
        badge.textContent = value;
        badges.appendChild(badge);
      });
      title.appendChild(name);
      title.appendChild(badges);
      top.appendChild(title);
      card.appendChild(top);

      appendResourceTextBlock(card, "用途", candidate.usage);
      appendResourceTextBlock(card, "为什么推荐", "本地 Skill 未完整覆盖该子任务，需要从 Github 补充可导入的 Skill 模板。");
      appendResourceTextBlock(card, "为什么需要", "它用于补齐当前任务链路里的缺口；如果 GitHub 没有返回仓库结果，就说明暂时没有找到可直接导入的候选。");
      appendResourceTextBlock(card, "安装引导", candidate.feature);
      const resultsBlock = document.createElement("div");
      resultsBlock.className = "task-resource-block";
      const resultLabel = document.createElement("strong");
      resultLabel.textContent = "GitHub检索结果";
      resultsBlock.appendChild(resultLabel);
      if (candidate.githubStatus === "pending") {
        const text = document.createElement("div");
        text.textContent = "正在检索GitHub仓库链接...";
        resultsBlock.appendChild(text);
      } else if (candidate.githubStatus === "error") {
        const text = document.createElement("div");
        text.textContent = "检索失败，未返回可用仓库链接。";
        resultsBlock.appendChild(text);
      } else if (!results.length) {
        const text = document.createElement("div");
        text.textContent = candidate.emptyMessage || "未找到匹配仓库。";
        resultsBlock.appendChild(text);
      } else {
        const list = document.createElement("ul");
        results.forEach(repo => {
          const item = document.createElement("li");
          const link = document.createElement("a");
          link.href = repo.url;
          link.target = "_blank";
          link.rel = "noreferrer";
          link.textContent = repo.name;
          item.appendChild(link);
          const meta = document.createElement("span");
          meta.textContent = "｜stars " + repo.stars + "｜" + repo.description;
          item.appendChild(meta);
          list.appendChild(item);
        });
        resultsBlock.appendChild(list);
      }
      card.appendChild(resultsBlock);

      const actions = document.createElement("div");
      actions.className = "task-card-actions";
      if (results.length) {
        results.forEach((repo, repoIndex) => {
          const githubLink = document.createElement("a");
          githubLink.href = repo.url;
          githubLink.target = "_blank";
          githubLink.rel = "noreferrer";
          githubLink.textContent = repoIndex === 0 ? "打开最佳结果" : "打开候选 " + (repoIndex + 1);
          actions.appendChild(githubLink);
        });
      }
      card.appendChild(actions);
      return card;
    }

    function createGithubResourceCard(candidate, repo, index) {
      const card = document.createElement("article");
      card.className = "task-resource-card external";
      const top = document.createElement("div");
      top.className = "task-resource-top";
      const title = document.createElement("div");
      title.className = "task-resource-title";
      const name = document.createElement("strong");
      const link = document.createElement("a");
      link.className = "task-resource-name-link";
      link.href = repo.url;
      link.target = "_blank";
      link.rel = "noreferrer";
      link.textContent = repo.name;
      name.appendChild(link);
      const badges = document.createElement("div");
      badges.className = "task-resource-badges";
      ["Github候选", "外部资源", "需导入"].forEach(value => {
        const badge = document.createElement("span");
        badge.textContent = value;
        badges.appendChild(badge);
      });
      title.appendChild(name);
      title.appendChild(badges);
      top.appendChild(title);
      card.appendChild(top);

      const description = document.createElement("p");
      description.className = "task-resource-description";
      description.textContent = repo.description || candidate.usage;
      card.appendChild(description);

      const actions = document.createElement("div");
      actions.className = "task-card-actions";
      const copyButton = document.createElement("button");
      copyButton.type = "button";
      copyButton.textContent = "复制调用指令";
      copyButton.addEventListener("click", () => copyTaskAdvisorText(copyButton, "使用 " + repo.name + " 完成：" + candidate.usage, repo.name));
      actions.appendChild(copyButton);
      card.appendChild(actions);
      return card;
    }

    function renderGithubResourceCards(report) {
      const results = report.externalCandidates.flatMap(candidate => (candidate.githubResults || []).map(repo => ({ candidate, repo })));
      if (!results.length) return;
      const heading = document.createElement("h3");
      heading.className = "task-resource-heading";
      heading.textContent = "Github 补充候选";
      const list = document.createElement("div");
      list.className = "task-resource-list";
      results
        .sort((left, right) => Number(right.repo.usefulnessScore || 0) - Number(left.repo.usefulnessScore || 0) || Number(right.repo.stars || 0) - Number(left.repo.stars || 0))
        .forEach(({ candidate, repo }, index) => list.appendChild(createGithubResourceCard(candidate, repo, index)));
      taskAdvisorOutput.appendChild(heading);
      taskAdvisorOutput.appendChild(list);
    }

    function githubCandidatesWithResults(report) {
      return report.externalCandidates.filter(candidate => (
        candidate.githubStatus === "done" &&
        Array.isArray(candidate.githubResults) &&
        candidate.githubResults.length > 0
      ));
    }

    function intentRefinementSuggestion(intent) {
      if (!intent || !intent.broad) return "";
      const missing = [];
      if (!(intent.platforms || []).length) missing.push("目标平台或运行环境（如 Windows、飞书）");
      if (!(intent.professionalActions || []).length) missing.push("关键动作（如抓取、分析、设计、开发、测试或部署）");
      if (!(intent.objects || []).length) missing.push("处理对象");
      if (!(intent.outputs || []).length) missing.push("最终产出（如可运行桌面应用、网页或报表）");
      if (!(intent.constraints || []).length) missing.push("必要限制（如本地、批量或定时）");
      return "为了获得更准确的推荐，任务描述可补充：" + missing.slice(0, 3).join("、") + "。";
    }

    function recommendationReason(candidate) {
      const evidence = [];
      if ((candidate.matchedPlatforms || []).length) evidence.push("匹配目标平台/环境：" + candidate.matchedPlatforms.map(capabilityDisplayLabel).join("/"));
      if ((candidate.matchedActions || []).length) evidence.push("匹配关键动作：" + candidate.matchedActions.map(capabilityDisplayLabel).join("/"));
      if ((candidate.matchedObjects || []).length) evidence.push("匹配处理对象：" + candidate.matchedObjects.map(capabilityDisplayLabel).join("/"));
      if ((candidate.matchedOutputs || []).length) evidence.push("匹配预期产出：" + candidate.matchedOutputs.map(capabilityDisplayLabel).join("/"));
      if ((candidate.matchedCapabilities || []).length) evidence.push("匹配任务能力：" + candidate.matchedCapabilities.map(capabilityDisplayLabel).join("/"));
      if ((candidate.coveredSubtaskIds || []).length > 1) evidence.push("同时覆盖多个已识别子任务");
      return evidence.slice(0, 2).join("；") || "与当前任务目标匹配度更高";
    }

    function recommendationGroups(recommendations) {
      const groups = new Map();
      recommendations.forEach(item => {
        const ids = (item.coveredSubtaskIds || []).map(value => Number(value)).filter(Number.isFinite).sort((left, right) => left - right);
        const key = ids.length ? String(ids[0]) : item.key;
        if (!groups.has(key)) groups.set(key, []);
        groups.get(key).push(item);
      });
      return Array.from(groups.values()).map(items => ({
        items,
        intent: String((items[0].coveredSubtasks || [])[0] || "")
      }));
    }

    function developmentOrderSuggestion(recommendations) {
      if (!recommendations.length) return [{ message: "暂未匹配到可直接承接该任务的本地 Skill。" }];
      return recommendationGroups(recommendations).map(group => {
        const preferred = group.items[0];
        return {
          intent: group.intent,
          preferred,
          alternatives: group.items.slice(1),
          reason: recommendationReason(preferred)
        };
      });
    }

    function relationshipSummaryText(report) {
      const intent = report.analysis.structuredIntent || {};
      const refinement = intentRefinementSuggestion(intent);
      const advice = developmentOrderSuggestion(report.recommendations);
      return { refinement, advice };
    }

    function renderTaskRelationshipSummary(report) {
      const summary = document.createElement("div");
      summary.className = "task-relationship-summary";
      const title = document.createElement("strong");
      title.textContent = "Skill 关系说明";
      const content = relationshipSummaryText(report);
      summary.appendChild(title);
      if (content.refinement) {
        const refinement = document.createElement("div");
        refinement.textContent = content.refinement;
        summary.appendChild(refinement);
      }
      const order = document.createElement("div");
      order.className = "development-order";
      const heading = document.createElement("strong");
      heading.textContent = "开发建议";
      order.appendChild(heading);
      const multipleIntents = content.advice.length > 1;
      content.advice.forEach((entry, index) => {
        const line = document.createElement("div");
        line.className = "development-order-line";
        if (entry.message) {
          line.textContent = entry.message;
          order.appendChild(line);
          return;
        }
        if (multipleIntents) {
          line.append((index + 1) + ". " + (entry.intent ? entry.intent + "：" : "子任务："));
        }
        const preferred = document.createElement("strong");
        preferred.textContent = entry.preferred.name;
        line.appendChild(preferred);
        line.append("：更推荐，因为" + entry.reason);
        if (entry.alternatives.length) {
          line.append("；");
          entry.alternatives.forEach((alternative, alternativeIndex) => {
            if (alternativeIndex) line.append("、");
            const name = document.createElement("strong");
            name.textContent = alternative.name;
            line.appendChild(name);
          });
          line.append("也可完成这一环节，可任选其一");
        }
        order.appendChild(line);
      });
      summary.appendChild(order);
      taskAdvisorOutput.appendChild(summary);
    }

    function groupTaskCardsBySubtask(items, structuredSubtasks) {
      const subtasks = Array.isArray(structuredSubtasks) ? structuredSubtasks : [];
      const groups = new Map();
      const order = [];
      const getGroup = (key, label) => {
        if (!groups.has(key)) {
          groups.set(key, { key, label, items: [] });
          order.push(key);
        }
        return groups.get(key);
      };
      items.forEach(item => {
        const covered = new Set(Array.isArray(item.coveredSubtaskIds) ? item.coveredSubtaskIds : []);
        const primary = subtasks.find(subtask => covered.has(subtask.id));
        const key = primary ? "subtask-" + primary.id : "other";
        const label = primary ? String(primary.text || "") : "";
        getGroup(key, label).items.push(item);
      });
      return order.map(key => groups.get(key));
    }

    function createTaskResourceCarousel(items, report, selectedKeys, cardIndexOffset) {
      const list = document.createElement("div");
      list.className = "task-resource-list";
      items.forEach((item, index) => {
        list.appendChild(createLocalResourceCard(item, report, cardIndexOffset + index, selectedKeys));
      });
      return list;
    }

    function renderTaskResourceCards(report) {
      const selectedKeys = new Set(report.recommendations.map(item => item.key));
      const localCards = report.recommendations.length ? report.recommendations : report.localMatches.slice(0, 3);
      if (!localCards.length) return;
      const groups = groupTaskCardsBySubtask(localCards, report.analysis.structuredPlan?.subtasks);
      const headingRow = document.createElement("div");
      headingRow.className = "task-resource-heading-row";
      const heading = document.createElement("h3");
      heading.className = "task-resource-heading";
      heading.textContent = "推荐 Skill 卡片";
      const integrationButton = document.createElement("button");
      integrationButton.type = "button";
      integrationButton.className = "task-resource-heading-action";
      integrationButton.textContent = "一键复制接入指令";
      integrationButton.addEventListener("click", () => copyTaskAdvisorText(integrationButton, projectIntegrationInstruction(report), report.recommendations.map(item => item.name)));
      headingRow.appendChild(heading);
      headingRow.appendChild(integrationButton);
      taskAdvisorOutput.appendChild(headingRow);
      groups.forEach((group, groupIndex) => {
        const section = document.createElement("section");
        section.className = "task-resource-group";
        if (groups.length > 1 && group.label) {
          const title = document.createElement("div");
          title.className = "task-resource-group-title";
          title.textContent = "承接同一任务：" + group.label;
          section.appendChild(title);
        }
        section.appendChild(createTaskResourceCarousel(group.items, report, selectedKeys, groupIndex));
        taskAdvisorOutput.appendChild(section);
      });
    }

    function capabilityDisplayLabel(value) {
      const labels = {
        xiaohongshu: "\u5c0f\u7ea2\u4e66",
        lark: "\u98de\u4e66",
        scrape: "\u6293\u53d6",
        translate: "\u7ffb\u8bd1",
        deploy: "\u90e8\u7f72",
        analyze: "\u5206\u6790",
        test: "\u6d4b\u8bd5",
        transcribe: "\u8f6c\u5f55",
        publish: "\u53d1\u5e03",
        summarize: "\u6c47\u603b",
        desktop_pet: "\u684c\u9762\u5ba0\u7269",
        visual_design: "\u89c6\u89c9\u8bbe\u8ba1",
        image_generation: "\u56fe\u50cf\u751f\u6210",
        animation: "\u52a8\u753b",
        interaction: "\u4ea4\u4e92",
        voice: "\u8bed\u97f3",
        desktop_app: "\u684c\u9762\u5e94\u7528",
        persistence: "\u6301\u4e45\u5316",
        notification: "\u901a\u77e5",
        realtime: "\u5b9e\u65f6",
        batch: "\u6279\u91cf",
        local: "\u672c\u5730",
        scheduled: "\u5b9a\u65f6"
      };
      return labels[value] || value;
    }

    function renderGithubTextResults(report) {
      const candidates = githubCandidatesWithResults(report);
      if (!candidates.length) return;
      const list = document.createElement("div");
      list.className = "github-text-list";
      candidates.flatMap(candidate => candidate.githubResults.map(repo => ({ candidate, repo })))
        .sort((a, b) => Number(b.repo.matchScore || 0) - Number(a.repo.matchScore || 0) || Number(b.repo.stars || 0) - Number(a.repo.stars || 0))
        .forEach(({ candidate, repo }) => {
          const line = document.createElement("div");
          line.className = "github-text-item";
          line.append("\u3010");
          const link = document.createElement("a");
          link.href = repo.url;
          link.target = "_blank";
          link.rel = "noreferrer";
          link.textContent = repo.name;
          line.appendChild(link);
          line.append("\u3011\uff1a");
          const platforms = (repo.matchedPlatforms || []).map(capabilityDisplayLabel);
          const actions = (repo.matchedActions || []).map(capabilityDisplayLabel);
          const evidence = [];
          if (platforms.length) evidence.push("\u5339\u914d\u5e73\u53f0 " + platforms.join("/"));
          if (actions.length) evidence.push("\u5339\u914d\u52a8\u4f5c " + actions.join("/"));
          line.append((evidence.length ? evidence.join("\uff0c") : "\u901a\u8fc7\u7ed3\u6784\u5316\u80fd\u529b\u6821\u9a8c") + "\uff0c\u53ef\u8986\u76d6" + candidate.usage.replace(/^\u8986\u76d6\u672c\u5730Skill\u672a\u5b8c\u6574\u547d\u4e2d\u7684\u5b50\u4efb\u52a1\uff1a/, "") + "\u3002");
          list.appendChild(line);
        });
      taskAdvisorOutput.appendChild(list);
    }

    function renderTaskAdvisorOutput(report) {
      taskAdvisorOutput.textContent = "";
      renderTaskRelationshipSummary(report);
      renderTaskSearchAudit(report);
      renderTaskResourceCards(report);
      renderGithubResourceCards(report);
    }

    function renderTaskSearchAudit(report) {
      const audit = report.searchAudit || {};
      const line = document.createElement("div");
      line.className = "task-relationship-summary task-search-audit";
      const localCount = Number(audit.localMatchCount || 0);
      if (!audit.githubRequested) {
        line.textContent = "检索回执：本地匹配 " + localCount + " 项，已覆盖当前子任务，未调用 Github。";
      } else {
        line.textContent = "检索回执：本地匹配 " + localCount + " 项；Github 已执行 " + Number(audit.githubQueryCount || 0) + " 轮中英文/拆分查询，自检后保留 " + Number(audit.githubQualifiedCount || 0) + " 个候选。";
      }
      taskAdvisorOutput.appendChild(line);
    }

    function publishTaskCommand(command) {
      taskAdvisorCommandState = command;
      if (!taskAdvisorOutput) return;
      taskAdvisorOutput.dataset.command = JSON.stringify(command);
      taskAdvisorOutput.dispatchEvent(new CustomEvent("skillarchivecommand", { detail: command, bubbles: true }));
    }

    function appendInstallRecognition(message) {
      const summary = document.createElement("div");
      summary.className = "task-relationship-summary";
      const title = document.createElement("strong");
      title.textContent = "\u6307\u4ee4\u8bc6\u522b";
      const text = document.createElement("div");
      text.textContent = message;
      summary.appendChild(title);
      summary.appendChild(text);
      taskAdvisorOutput.appendChild(summary);
    }

    function renderInstalledArchiveCard(command, match) {
      taskAdvisorOutput.textContent = "";
      appendInstallRecognition("\u5df2\u8bc6\u522b\u4e3a Skill \u5b89\u88c5\u6307\u4ee4\u3002\u672c\u5730\u5df2\u5b58\u5728\u300c" + match.name + "\u300d\uff0c\u53ef\u76f4\u63a5\u4f7f\u7528\uff0c\u672a\u53d1\u8d77 Github \u68c0\u7d22\u3002");
      const heading = document.createElement("h3");
      heading.className = "task-resource-heading";
      heading.textContent = "\u5df2\u5b89\u88c5 Skill";
      const grid = document.createElement("div");
      grid.className = "install-result-grid";
      const sourceCard = cardBySkillName.get(match.key);
      if (!sourceCard) return;
      const card = sourceCard.cloneNode(true);
      card.hidden = false;
      card.classList.add("install-result-card");
      card.querySelectorAll(".copy-command").forEach(bindCopyCommand);
      grid.appendChild(card);
      taskAdvisorOutput.appendChild(heading);
      taskAdvisorOutput.appendChild(grid);
    }

    function formatInstallElapsed(seconds) {
      const total = Math.max(0, Math.floor(Number(seconds || 0)));
      const minutes = Math.floor(total / 60);
      const remainder = total % 60;
      return minutes ? "\u5df2\u7528\u65f6 " + minutes + "\u5206" + remainder + "\u79d2" : "\u5df2\u7528\u65f6 " + remainder + "\u79d2";
    }

    function installStageLabel(stage) {
      const labels = {
        creating: "\u6b63\u5728\u521b\u5efa\u5b89\u88c5\u4efb\u52a1",
        downloading: "\u6b63\u5728\u4e0b\u8f7d\u5e76\u9a8c\u8bc1 Skill",
        rebuilding: "\u6b63\u5728\u5237\u65b0\u672c\u5730\u770b\u677f",
        completed: "\u5b89\u88c5\u5b8c\u6210\uff0c\u6b63\u5728\u6253\u5f00 Skill \u5361\u7247"
      };
      return labels[stage] || stage || "\u6b63\u5728\u51c6\u5907\u5b89\u88c5";
    }

    function renderInstallProgressCard(command, state = {}) {
      if (!taskAdvisorOutput) return;
      const status = String(state.status || "installing");
      const failed = status === "failed";
      const progress = Math.max(0, Math.min(100, Number(state.progress || 0)));
      const skillName = String(command.target_skill_name || "Skill");
      const stage = installStageLabel(String(state.stage || ""));
      const message = String(state.message || "\u6b63\u5728\u8fde\u63a5 Github \u5e76\u9a8c\u8bc1 Skill \u7ed3\u6784\u3002");
      const elapsed = formatInstallElapsed(state.elapsedSeconds || (state.startedAt ? (Date.now() - state.startedAt) / 1000 : 0));
      taskAdvisorOutput.textContent = "";
      taskAdvisorOutput.setAttribute("aria-busy", failed ? "false" : "true");
      appendInstallRecognition(failed ? "\u5b89\u88c5\u300c" + skillName + "\u300d\u672a\u5b8c\u6210\u3002\u53ef\u4ee5\u67e5\u770b\u539f\u56e0\u540e\u91cd\u8bd5\u3002" : "\u5df2\u8bc6\u522b\u4e3a Skill \u5b89\u88c5\u6307\u4ee4\uff0c\u6b63\u5728\u6267\u884c\u672c\u5730\u5b89\u88c5\u3002");
      const heading = document.createElement("h3");
      heading.className = "task-resource-heading";
      heading.textContent = failed ? "\u5b89\u88c5\u672a\u5b8c\u6210" : "\u6b63\u5728\u5b89\u88c5 Skill";
      const card = document.createElement("section");
      card.className = "install-progress-card" + (failed ? " failed" : "");
      card.setAttribute("aria-busy", failed ? "false" : "true");
      card.setAttribute("aria-label", "Skill \u5b89\u88c5\u8fdb\u5ea6");
      const top = document.createElement("div");
      top.className = "install-progress-head";
      const name = document.createElement("strong");
      name.textContent = skillName;
      const badge = document.createElement("span");
      badge.className = "install-progress-badge";
      badge.textContent = failed ? "\u5b89\u88c5\u5931\u8d25" : progress + "%";
      top.appendChild(name);
      top.appendChild(badge);
      const stageLine = document.createElement("div");
      stageLine.textContent = stage;
      const track = document.createElement("div");
      track.className = "install-progress-track";
      track.setAttribute("role", "progressbar");
      track.setAttribute("aria-valuemin", "0");
      track.setAttribute("aria-valuemax", "100");
      track.setAttribute("aria-valuenow", String(progress));
      track.setAttribute("aria-label", "\u5b89\u88c5\u8fdb\u5ea6 " + progress + "%");
      const fill = document.createElement("div");
      fill.className = "install-progress-fill";
      fill.style.width = progress + "%";
      track.appendChild(fill);
      const meta = document.createElement("div");
      meta.className = "install-progress-meta";
      const elapsedText = document.createElement("span");
      elapsedText.className = "install-elapsed";
      elapsedText.textContent = elapsed;
      const progressText = document.createElement("span");
      progressText.textContent = failed ? "\u4efb\u52a1\u5df2\u505c\u6b62" : "\u8fdb\u5ea6 " + progress + "%";
      meta.appendChild(elapsedText);
      meta.appendChild(progressText);
      const description = document.createElement("p");
      description.className = "install-progress-message";
      description.textContent = message;
      card.appendChild(top);
      card.appendChild(stageLine);
      card.appendChild(track);
      card.appendChild(meta);
      card.appendChild(description);
      if (failed) {
        const actions = document.createElement("div");
        actions.className = "install-progress-actions";
        const retry = document.createElement("button");
        retry.type = "button";
        retry.className = "task-advisor-run";
        retry.textContent = "\u91cd\u8bd5\u5b89\u88c5";
        retry.addEventListener("click", () => installSkillFromUrl(command, ++taskAdvisorRequestId));
        actions.appendChild(retry);
        card.appendChild(actions);
      }
      taskAdvisorOutput.appendChild(heading);
      taskAdvisorOutput.appendChild(card);
    }

    async function pollInstallProgress(command, requestId, jobId, startedAt) {
      while (requestId === taskAdvisorRequestId) {
        try {
          const response = await fetch("http://127.0.0.1:8765/install/status?jobId=" + encodeURIComponent(jobId));
          const data = await response.json().catch(() => ({}));
          if (!response.ok || !data.ok && data.status !== "failed") {
            renderInstallProgressCard(command, { status: "failed", startedAt, stage: "\u65e0\u6cd5\u8bfb\u53d6\u5b89\u88c5\u8fdb\u5ea6", message: String(data.message || "\u672c\u5730\u5b89\u88c5\u4efb\u52a1\u5df2\u4e2d\u65ad\u3002") });
            return;
          }
          const state = { ...data, startedAt };
          renderInstallProgressCard(command, state);
          if (data.status === "completed" && data.skillName) {
            sessionStorage.setItem(pendingInstallStorageKey, JSON.stringify({ skillName: data.skillName }));
            window.location.reload();
            return;
          }
          if (data.status === "failed") return;
        } catch (error) {
          if (requestId !== taskAdvisorRequestId) return;
          renderInstallProgressCard(command, { status: "failed", startedAt, stage: "\u65e0\u6cd5\u8fde\u63a5\u5b89\u88c5\u670d\u52a1", message: "\u8bf7\u4f7f\u7528\u9879\u76ee\u542f\u52a8\u5668\u91cd\u65b0\u6253\u5f00\u770b\u677f\u540e\u91cd\u8bd5\u3002" });
          return;
        }
        await wait(850);
      }
    }

    async function refreshInstallToken() {
      try {
        const response = await fetch("http://127.0.0.1:8765/install/token", { cache: "no-store" });
        const data = await response.json().catch(() => ({}));
        if (response.ok && data.ok && data.token) {
          window.SKILL_INSTALL_TOKEN = String(data.token);
          return window.SKILL_INSTALL_TOKEN;
        }
      } catch (error) {
      }
      return String(window.SKILL_INSTALL_TOKEN || "");
    }

    async function createInstallJob(repositoryUrl, token) {
      const response = await fetch("http://127.0.0.1:8765/install", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Skill-Install-Token": token
        },
        body: JSON.stringify({ repositoryUrl })
      });
      const data = await response.json().catch(() => ({}));
      return { response, data };
    }

    async function installGithubSearchResult(repositoryUrl, button) {
      const original = button.textContent;
      button.disabled = true;
      button.textContent = "安装中";
      try {
        const token = await refreshInstallToken();
        if (!token) throw new Error("Installer service is unavailable");
        const request = await createInstallJob(repositoryUrl, token);
        if (!request.response.ok || !request.data.ok || !request.data.jobId) throw new Error(String(request.data.message || "Could not create installation task"));
        const startedAt = Date.now();
        while (Date.now() - startedAt < 310000) {
          const response = await fetch("http://127.0.0.1:8765/install/status?jobId=" + encodeURIComponent(request.data.jobId));
          const state = await response.json().catch(() => ({}));
          if (!response.ok) throw new Error(String(state.message || "Could not read installation status"));
          if (state.status === "completed") {
            button.textContent = "已安装";
            appendPetMessage("assistant", "小V确认已完成安装，本次推荐结果已更新为已安装状态。");
            setPetMood("happy");
            setPetStatic(petAssets.static.happy, true);
            return;
          }
          if (state.status === "failed") throw new Error(String(state.message || "Installation failed"));
          button.textContent = "安装中 " + Math.max(0, Math.min(99, Number(state.progress || 0))) + "%";
          await wait(900);
        }
        throw new Error("Installation timed out");
      } catch (error) {
        button.disabled = false;
        button.textContent = original;
        appendPetMessage("assistant", "小V没有完成安装，请检查本地启动器和仓库地址后再试。");
        setPetMood("skeptical");
        setPetStatic(petAssets.static.dizzy, true);
      }
    }

    async function installSkillFromUrl(command, requestId) {
      const startedAt = Date.now();
      renderInstallProgressCard(command, { startedAt, progress: 5, stage: "\u6b63\u5728\u521b\u5efa\u5b89\u88c5\u4efb\u52a1", message: "\u6b63\u5728\u51c6\u5907\u4ece Github \u5b89\u88c5\u3002" });
      const token = await refreshInstallToken();
      if (!token) {
        renderInstallProgressCard(command, { status: "failed", startedAt, stage: "\u5b89\u88c5\u670d\u52a1\u672a\u542f\u52a8", message: "\u8bf7\u4f7f\u7528 Windows \u6216 macOS \u542f\u52a8\u5668\u91cd\u65b0\u6253\u5f00\u770b\u677f\u3002" });
        return;
      }
      try {
        let request = await createInstallJob(command.target_repo_url, token);
        if (request.response.status === 403 && /Installer authorization failed/i.test(String(request.data.message || ""))) {
          const refreshedToken = await refreshInstallToken();
          if (refreshedToken && refreshedToken !== token) request = await createInstallJob(command.target_repo_url, refreshedToken);
        }
        const response = request.response;
        const data = request.data;
        if (requestId !== taskAdvisorRequestId) return;
        if (!response.ok || !data.ok || !data.jobId) {
          renderInstallProgressCard(command, { status: "failed", startedAt, stage: "\u65e0\u6cd5\u521b\u5efa\u5b89\u88c5\u4efb\u52a1", message: String(data.message || "Skill \u5b89\u88c5\u5931\u8d25\u3002") });
          return;
        }
        renderInstallProgressCard(command, { ...data, startedAt });
        await pollInstallProgress(command, requestId, String(data.jobId), startedAt);
      } catch (error) {
        if (requestId !== taskAdvisorRequestId) return;
        renderInstallProgressCard(command, { status: "failed", startedAt, stage: "\u65e0\u6cd5\u8fde\u63a5\u5b89\u88c5\u670d\u52a1", message: "\u8bf7\u4f7f\u7528\u9879\u76ee\u542f\u52a8\u5668\u91cd\u65b0\u6253\u5f00\u770b\u677f\u540e\u91cd\u8bd5\u3002" });
      }
    }

    async function runSkillInstallFlow(command, requestId) {
      if (!command.target_repo_url) {
        taskAdvisorOutput.textContent = "";
        appendInstallRecognition("\u5df2\u8bc6\u522b\u4e3a Skill \u5b89\u88c5\u6307\u4ee4\u3002\u8bf7\u8f93\u5165\u5b8c\u6574 Github \u4ed3\u5e93\u7f51\u5740\uff0c\u4f8b\u5982 https://github.com/owner/repository\u3002");
        return;
      }
      const localMatch = findLocalInstallMatch(command);
      if (localMatch) {
        renderInstalledArchiveCard(command, localMatch);
        return;
      }
      await installSkillFromUrl(command, requestId);
    }

    function restoreInstalledSkillResult() {
      let pending = null;
      try {
        pending = JSON.parse(sessionStorage.getItem(pendingInstallStorageKey) || "null");
        sessionStorage.removeItem(pendingInstallStorageKey);
      } catch (error) {
        sessionStorage.removeItem(pendingInstallStorageKey);
      }
      const skillName = pending && pending.skillName ? String(pending.skillName) : "";
      if (!skillName) return;
      const key = normalizeTaskKey(skillName);
      const sourceCard = cardBySkillName.get(key);
      if (!sourceCard || sourceCard.dataset.installed !== "true") return;
      taskAdvisorInput.value = "\u5b89\u88c5 " + skillName;
      taskAdvisorOutput.hidden = false;
      toolbar?.classList.add("has-task-results");
      renderInstalledArchiveCard({ target_skill_name: skillName }, { key, name: skillName });
    }

    async function requestSemanticIntentAnalysis(taskText) {
      try {
        const response = await fetch("http://127.0.0.1:8765/intent/analyze", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ task: taskText })
        });
        const data = await response.json().catch(() => null);
        if (!data || !data.ok) return null;
        return data;
      } catch (error) {
        return null;
      }
    }

    function renderTaskReportAndGithub(report, requestId) {
      return resolveGithubCandidates(report, (candidate, current, total) => {
        if (requestId !== taskAdvisorRequestId) return;
        renderTaskSearchProgress("正在联网检索", "正在搜索 Github：" + candidate.usage + "（" + current + "/" + total + "）");
      }).then(updatedReport => {
        if (requestId !== taskAdvisorRequestId) return;
        updatedReport.searchAudit.githubQueryCount = updatedReport.externalCandidates.reduce((count, candidate) => count + (candidate.processedQueries || []).length, 0);
        updatedReport.searchAudit.githubQualifiedCount = updatedReport.externalCandidates.reduce((count, candidate) => count + (candidate.githubResults || []).length, 0);
        refreshGithubSectionText(updatedReport);
        renderTaskAdvisorOutput(updatedReport);
      });
    }

    function renderTaskSearchProgress(stage, message) {
      taskAdvisorOutput.textContent = "";
      const progress = document.createElement("div");
      progress.className = "task-search-progress";
      progress.setAttribute("aria-busy", "true");
      const spinner = document.createElement("i");
      spinner.className = "task-search-spinner";
      spinner.setAttribute("aria-hidden", "true");
      const text = document.createElement("div");
      const title = document.createElement("strong");
      title.textContent = stage;
      const detail = document.createElement("div");
      detail.textContent = message;
      text.appendChild(title);
      text.appendChild(detail);
      progress.appendChild(spinner);
      progress.appendChild(text);
      taskAdvisorOutput.appendChild(progress);
    }

    function setPetSearchState(message, mood = "proud") {
      appendPetMessage("assistant", message);
      setPetMood(mood);
      setPetStatic(mood === "skeptical" ? petAssets.static.dizzy : petAssets.static.listen, true);
    }

    async function renderTaskAdvisor() {
      if (!taskAdvisorInput || !taskAdvisorOutput) return;
      const requestId = ++taskAdvisorRequestId;
      const taskText = taskAdvisorInput.value.trim();
      taskAdvisorOutput.textContent = "";
      if (!taskText) {
        taskAdvisorRequestId += 1;
        taskAdvisorOutput.hidden = true;
        toolbar?.classList.remove("has-task-results");
        taskAdvisorInput.focus();
        return;
      }

      taskAdvisorOutput.hidden = false;
      toolbar?.classList.add("has-task-results");
      renderTaskSearchProgress("正在本地检索", "正在匹配本机已安装的 Skill、Agent 与 Agent 集群。");
      setPetSearchState("小V先检查本地档案，看看哪些能力可以直接使用。");
      const localReport = buildSkillMatchReport(taskText);
      await wait(450);
      if (requestId !== taskAdvisorRequestId) return;
      renderTaskSearchProgress("正在分析意图", "正在细分任务目标、执行动作和预期产出。");
      const semanticAnalysis = await requestSemanticIntentAnalysis(taskText);
      if (requestId !== taskAdvisorRequestId) return;
      const report = buildSkillMatchReport(taskText, semanticAnalysis);
      if (report.externalCandidates.length) {
        setPetSearchState("本地档案已检查完成，小V正在用中文、英文和拆分关键词搜索 Github。", "proud");
        await renderTaskReportAndGithub(report, requestId);
      } else {
        renderTaskAdvisorOutput(report);
      }
      if (requestId !== taskAdvisorRequestId) return;
      setPetMood("happy");
      setPetStatic(petAssets.static.happy, true);
      appendPetMessage("assistant", report.externalCandidates.length ? "小V已完成联网自检，只保留了与当前任务真正相关的候选。" : "小V已完成本地匹配，结果已准备好。");
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

    function clearArchiveHighlights() {
      document.querySelectorAll("mark.match-highlight").forEach(mark => {
        mark.replaceWith(document.createTextNode(mark.textContent || ""));
      });
      document.querySelectorAll(".skill-card").forEach(card => card.normalize());
    }

    function highlightTextNode(node, query) {
      const parsed = archiveSearchTokens(query);
      const latinTerms = Array.from(new Set(parsed.latin.filter(Boolean)));
      const chineseTerms = parsed.chinese.filter(Boolean);
      const text = node.nodeValue || "";
      if (!text) return;
      const ranges = [];
      const lowerText = text.toLowerCase();
      latinTerms.forEach(term => {
        let from = 0;
        while (from < lowerText.length) {
          const index = lowerText.indexOf(term, from);
          if (index < 0) break;
          ranges.push([index, index + term.length]);
          from = index + term.length;
        }
      });
      chineseTerms.forEach(term => {
        let from = 0;
        while (from < text.length) {
          const index = text.indexOf(term, from);
          if (index < 0) break;
          ranges.push([index, index + term.length]);
          from = index + term.length;
        }
      });
      if (!ranges.length) return;
      ranges.sort((a, b) => a[0] - b[0] || b[1] - a[1]);
      const merged = [];
      ranges.forEach(range => {
        const previous = merged[merged.length - 1];
        if (!previous || range[0] > previous[1]) merged.push(range.slice());
        else previous[1] = Math.max(previous[1], range[1]);
      });
      const fragment = document.createDocumentFragment();
      let cursor = 0;
      merged.forEach(range => {
        if (range[0] > cursor) fragment.appendChild(document.createTextNode(text.slice(cursor, range[0])));
        const mark = document.createElement("mark");
        mark.className = "match-highlight";
        mark.textContent = text.slice(range[0], range[1]);
        fragment.appendChild(mark);
        cursor = range[1];
      });
      if (cursor < text.length) fragment.appendChild(document.createTextNode(text.slice(cursor)));
      node.replaceWith(fragment);
    }

    function highlightArchiveCard(card, query) {
      const selectors = [".skill-link", ".description", ".category", ".resource-badge", ".invoke code"];
      card.querySelectorAll(selectors.join(",")).forEach(element => {
        Array.from(element.childNodes).filter(node => node.nodeType === 3).forEach(node => highlightTextNode(node, query));
      });
    }

    function archiveCardMatches(card, query) {
      return archiveSearchMatches({
        name: card.dataset.name,
        description: card.dataset.searchPrimary,
        category: card.dataset.category,
        resourceLabel: card.dataset.resourceLabel,
        triggers: []
      }, query);
    }

    function render() {
      const query = search.value.trim();
      const resourceKind = resourceFilter.value;
      const category = categoryFilter.value;
      let shown = 0;
      clearArchiveHighlights();
      cards.sort(compareCards).forEach(card => {
        const matchesQuery = !query || archiveCardMatches(card, query);
        const matchesResource = !resourceKind || card.dataset.resourceKind === resourceKind;
        const matchesCategory = !category || card.dataset.category === category;
        const matchesUpdate = !showUpdatesOnly || card.dataset.updateStatus === "update_available";
        const visible = matchesQuery && matchesResource && matchesCategory && matchesUpdate;
        card.hidden = !visible;
        if (visible) {
          shown += 1;
          if (query) highlightArchiveCard(card, query);
        }
        grid.appendChild(card);
      });
      empty.style.display = shown ? "none" : "block";
    }

    function renderRelationships() {
      const relationType = relationshipTypeFilter.value;
      const query = relationshipSearch.value.trim().toLowerCase();
      let shown = 0;
      relationshipRows.forEach(row => {
        const matchesType = !relationType || row.dataset.relationType === relationType;
        const matchesQuery = !query || row.dataset.relationSearch.includes(query);
        const visible = matchesType && matchesQuery;
        row.hidden = !visible;
        if (visible) shown += 1;
      });
      relationshipShownCount.textContent = shown;
      relationshipEmpty.style.display = shown ? "none" : "block";
    }

    buttons.forEach(button => {
      button.addEventListener("click", () => {
        sortMode = button.dataset.sort;
        buttons.forEach(item => item.classList.toggle("active", item === button));
        render();
      });
    });
    taskAdvisorRun?.addEventListener("click", renderTaskAdvisor);
    taskAdvisorInput?.addEventListener("keydown", event => {
      if ((event.ctrlKey || event.metaKey) && event.key === "Enter") renderTaskAdvisor();
    });
    taskAdvisorInput?.addEventListener("input", () => {
      if (taskAdvisorOutput && !taskAdvisorInput.value.trim()) {
        taskAdvisorRequestId += 1;
        taskAdvisorOutput.hidden = true;
        toolbar?.classList.remove("has-task-results");
      }
    });
    backHomeButton?.addEventListener("click", () => {
      const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      window.scrollTo({ top: 0, behavior: reducedMotion ? "auto" : "smooth" });
    });
    search.addEventListener("input", render);
    resourceFilter.addEventListener("change", render);
    categoryFilter.addEventListener("change", render);
    relationshipTypeFilter.addEventListener("change", renderRelationships);
    relationshipSearch.addEventListener("input", renderRelationships);
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
    function bindCopyCommand(button) {
      if (!button || button.dataset.copyBound === "true") return;
      button.dataset.copyBound = "true";
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
    }
    document.querySelectorAll(".copy-command").forEach(bindCopyCommand);
    applyCounts();
    renderPet();
    renderRelationships();
    render();
  </script>
</body>
</html>
"@

Set-Content -LiteralPath $OutputPath -Value $html -Encoding UTF8
Write-Output "Generated $OutputPath with $archiveEntryCount archive entries ($installedSkillCount installed, $personalSkillCount personal, $systemSkillCount system-only)."
