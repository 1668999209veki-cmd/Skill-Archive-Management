param(
  [string]$OutputPath = (Join-Path (Get-Location) "skill-source-index.json"),
  [switch]$UseGitFallback
)

$ErrorActionPreference = "Continue"

$roots = @(
  "C:\Users\16689\Documents\skills",
  "C:\Users\16689\.codex\skills",
  "C:\Users\16689\.agents\skills"
)

$repoPattern = "https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?(?:/[A-Za-z0-9_./?=%#~:+-]+)?"

function Get-FrontMatterName {
  param([string]$Content, [string]$Fallback)
  $match = [regex]::Match($Content, "(?m)^name\s*:\s*(.+?)\s*$")
  if ($match.Success) { return $match.Groups[1].Value.Trim().Trim('"').Trim("'") }
  return $Fallback
}

function Normalize-GitHubRepo {
  param([string]$Url)

  $match = [regex]::Match($Url, "github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)")
  if (-not $match.Success) { return $null }

  $owner = $match.Groups[1].Value
  $repo = $match.Groups[2].Value -replace "\.git$", ""

  if ($owner -in @("org", "user", "username", "apps")) { return $null }
  if ($repo -in @("repo")) { return $null }

  return "$owner/$repo"
}

function Get-UserMessageText {
  param($Item)

  if ($Item.type -eq "event_msg" -and $Item.payload.type -eq "user_message") {
    return [string]$Item.payload.message
  }

  if ($Item.type -eq "message" -and $Item.role -eq "user") {
    return ($Item.content | Out-String)
  }

  return $null
}

function Get-RepoSkillEntries {
  param([string]$Repo)

  $headers = @{ "User-Agent" = "skill-source-indexer" }

  try {
    $repoInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo" -Headers $headers -TimeoutSec 20
    $branch = $repoInfo.default_branch
    $tree = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/git/trees/$branch`?recursive=1" -Headers $headers -TimeoutSec 30
    return @($tree.tree | Where-Object { $_.type -eq "blob" -and $_.path -match "(^|/)SKILL\.md$" } | ForEach-Object {
      [ordered]@{
        branch = $branch
        path = $_.path
      }
    })
  } catch {
    Write-Warning "GitHub API failed for ${Repo}: $($_.Exception.Message)"
  }

  if (-not $UseGitFallback) {
    return @()
  }

  $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("skill-source-" + [guid]::NewGuid().ToString("N"))
  try {
    $remote = "https://github.com/$Repo.git"
    $head = git ls-remote --symref $remote HEAD 2>$null
    $branch = "main"
    foreach ($line in $head) {
      $match = [regex]::Match($line, "^ref:\s+refs/heads/(.+?)\s+HEAD$")
      if ($match.Success) {
        $branch = $match.Groups[1].Value
        break
      }
    }

    git clone --depth 1 --filter=blob:none --sparse $remote $tempRoot 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git clone failed" }

    git -C $tempRoot sparse-checkout set --no-cone `
      "/*/SKILL.md" `
      "/skills/*/SKILL.md" `
      "/skills/**/SKILL.md" `
      "/.agents/skills/*/SKILL.md" `
      "/.codex/skills/*/SKILL.md" `
      "/.kiro/skills/*/SKILL.md" `
      "/docs/*/skills/*/SKILL.md" `
      "/docs/*/skills/**/SKILL.md" 2>$null | Out-Null

    $prefixLength = $tempRoot.Length + 1
    return @(Get-ChildItem -LiteralPath $tempRoot -Recurse -Filter "SKILL.md" -File -ErrorAction SilentlyContinue | ForEach-Object {
      [ordered]@{
        branch = $branch
        path = ($_.FullName.Substring($prefixLength) -replace "\\", "/")
      }
    })
  } catch {
    Write-Warning "Git fallback failed for ${Repo}: $($_.Exception.Message)"
  } finally {
    if (Test-Path -LiteralPath $tempRoot) {
      Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  return @()
}

$skills = @{}
foreach ($root in $roots) {
  if (-not (Test-Path -LiteralPath $root)) { continue }
  Get-ChildItem -LiteralPath $root -Recurse -Filter "SKILL.md" -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $content = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
    $name = Get-FrontMatterName -Content $content -Fallback $_.Directory.Name
    $key = $name.ToLowerInvariant()
    if (-not $skills.ContainsKey($key)) {
      $skills[$key] = [ordered]@{
        name = $name
        directory = $_.Directory.Name
      }
    }
  }
}

$repoUrls = New-Object System.Collections.Generic.List[string]

$sessionsRoot = Join-Path $env:USERPROFILE ".codex\sessions"
if (Test-Path -LiteralPath $sessionsRoot) {
  Get-ChildItem -LiteralPath $sessionsRoot -Recurse -Filter "*.jsonl" -File -ErrorAction SilentlyContinue | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
      try {
        $item = $_ | ConvertFrom-Json
      } catch {
        return
      }

      $text = Get-UserMessageText -Item $item
      if (-not $text -or $text -notmatch "github\.com") { return }

      [regex]::Matches($text, $repoPattern) | ForEach-Object {
        $repoUrls.Add($_.Value)
      }
    }
  }
}

foreach ($root in $roots) {
  if (-not (Test-Path -LiteralPath $root)) { continue }
  Get-ChildItem -LiteralPath $root -Recurse -Filter "SKILL.md" -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $content = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
    $head = (($content -split "`n") | Select-Object -First 120) -join "`n"
    $sourceLines = [regex]::Matches($head, "(?im)^(?:\s*(?:homepage|repository|repo|source|upstream|upstream source|upstream project|install source|provenance|canonical)\s*:|.*(?:Upstream|Source|homepage|repository|project|canonical):).*$") | ForEach-Object { $_.Value }
    $sourceText = ($sourceLines -join "`n")
    [regex]::Matches($sourceText, $repoPattern) | ForEach-Object {
      $repoUrls.Add($_.Value)
    }
  }
}

$repos = @($repoUrls | ForEach-Object { Normalize-GitHubRepo -Url $_ } | Where-Object { $_ } | Sort-Object -Unique)
$index = [ordered]@{}

foreach ($repo in $repos) {
  $entries = Get-RepoSkillEntries -Repo $repo
  foreach ($entry in $entries) {
    $parentPath = Split-Path -Parent $entry.path
    if (-not $parentPath) { continue }
    $folder = Split-Path -Leaf $parentPath
    foreach ($skill in $skills.Values) {
      if ($folder -ieq $skill.directory -or $folder -ieq $skill.name) {
        $key = $skill.name.ToLowerInvariant()
        if (-not $index.Contains($key)) {
          $index[$key] = "https://github.com/$repo/blob/$($entry.branch)/$($entry.path)"
        }
      }
    }
  }
}

if ($index.Count -eq 0 -and (Test-Path -LiteralPath $OutputPath)) {
  Write-Warning "No skill source links were found; keeping the existing index file."
  return
}

$index | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output "Indexed $($index.Count) skill GitHub source links from $($repos.Count) repos."
