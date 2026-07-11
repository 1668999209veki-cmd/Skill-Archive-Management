param(
  [string]$OutputJson = (Join-Path (Join-Path (Get-Location) "reports") "skill-update-report.json"),
  [string]$OutputHtml = (Join-Path (Join-Path (Get-Location) "reports") "skill-update-report.html"),
  [switch]$UseGitFallback,
  [int]$GitTimeoutSec = 25
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputJson), (Split-Path -Parent $OutputHtml) | Out-Null

function Get-ConfiguredPath {
  param(
    [string]$EnvName,
    [string]$Fallback
  )

  $value = [System.Environment]::GetEnvironmentVariable($EnvName)
  if ([string]::IsNullOrWhiteSpace($value)) { return $Fallback }
  return $value
}

$roots = @(
  (Get-ConfiguredPath "SKILL_ARCHIVE_PROJECT_SKILLS_DIR" (Join-Path (Get-Location) "skills")),
  (Get-ConfiguredPath "SKILL_ARCHIVE_CODEX_SKILLS_DIR" (Join-Path $env:USERPROFILE ".codex\skills")),
  (Get-ConfiguredPath "SKILL_ARCHIVE_AGENTS_SKILLS_DIR" (Join-Path $env:USERPROFILE ".agents\skills"))
)

function Get-FrontMatterName {
  param([string]$Content, [string]$Fallback)
  $match = [regex]::Match($Content, "(?m)^name\s*:\s*(.+?)\s*$")
  if ($match.Success) { return $match.Groups[1].Value.Trim().Trim('"').Trim("'") }
  return $Fallback
}

function Get-GitHubRepo {
  param([string]$Content)
  # Risk note: update checks call GitHub APIs for many repositories.
  # Run responsibly, cache outputs, and avoid aggressive polling.
  $match = [regex]::Match($Content, "https://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)")
  if (-not $match.Success) { return $null }
  return Normalize-GitHubRepo -Repo "$($match.Groups[1].Value)/$($match.Groups[2].Value)"
}

function Normalize-GitHubRepo {
  param([string]$Repo)

  $parts = $Repo -split "/", 3
  if ($parts.Count -lt 2) { return $null }

  $owner = $parts[0]
  $name = $parts[1] -replace "\.git$", ""

  if ($owner -in @("org", "user", "username", "apps")) { return $null }
  if ($name -in @("repo")) { return $null }

  return "$owner/$name"
}

function Get-GitHubRepoFromUrl {
  param([string]$Url)
  $match = [regex]::Match($Url, "github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)")
  if (-not $match.Success) { return $null }
  return Normalize-GitHubRepo -Repo "$($match.Groups[1].Value)/$($match.Groups[2].Value)"
}

function Invoke-ProcessWithTimeout {
  param(
    [string]$FileName,
    [string]$Arguments,
    [string]$WorkingDirectory,
    [int]$TimeoutSec
  )

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $FileName
  $psi.Arguments = $Arguments
  $psi.WorkingDirectory = $WorkingDirectory
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $process = [System.Diagnostics.Process]::Start($psi)
  if (-not $process.WaitForExit($TimeoutSec * 1000)) {
    try { $process.Kill($true) } catch { try { $process.Kill() } catch {} }
    throw "$FileName timed out after $TimeoutSec seconds"
  }

  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  if ($process.ExitCode -ne 0) {
    throw "$FileName exited $($process.ExitCode): $stderr"
  }

  return $stdout
}

function Get-RemoteRepoInfo {
  param([string]$Repo)

  $headers = @{ "User-Agent" = "skill-archive-checker" }
  try {
    $apiUrl = "https://api.github.com/repos/$Repo"
    $repoInfo = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 20
    return [ordered]@{
      pushedAt = [datetime]$repoInfo.pushed_at
      head = $null
      source = "github_api"
      message = "GitHub API checked."
    }
  } catch {
    $apiMessage = $_.Exception.Message
  }

  if (-not $UseGitFallback) {
    return [ordered]@{
      pushedAt = $null
      head = $null
      source = "unknown"
      message = "API failed: $apiMessage. Git fallback was not enabled."
    }
  }

  $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("skill-update-check-" + [guid]::NewGuid().ToString("N"))
  try {
    $remote = "https://github.com/$Repo.git"
    Invoke-ProcessWithTimeout -FileName "git" -Arguments "-c http.lowSpeedLimit=1000 -c http.lowSpeedTime=10 clone --depth 1 --filter=blob:none --no-checkout $remote `"$tempRoot`"" -WorkingDirectory (Get-Location).Path -TimeoutSec $GitTimeoutSec | Out-Null

    $head = (Invoke-ProcessWithTimeout -FileName "git" -Arguments "-C `"$tempRoot`" rev-parse HEAD" -WorkingDirectory (Get-Location).Path -TimeoutSec 8).Trim()
    $pushedAtText = (Invoke-ProcessWithTimeout -FileName "git" -Arguments "-C `"$tempRoot`" show -s --format=%cI HEAD" -WorkingDirectory (Get-Location).Path -TimeoutSec 8).Trim()
    if (-not $pushedAtText) { throw "could not read HEAD commit time" }

    return [ordered]@{
      pushedAt = [datetime]$pushedAtText
      head = $head
      source = "git_fallback"
      message = "Git fallback checked after API failure: $apiMessage"
    }
  } catch {
    return [ordered]@{
      pushedAt = $null
      head = $null
      source = "unknown"
      message = "API failed: $apiMessage; git fallback failed: $($_.Exception.Message)"
    }
  } finally {
    if (Test-Path -LiteralPath $tempRoot) {
      Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

$items = @{}
$skillLatest = @{}
foreach ($root in $roots) {
  if (-not (Test-Path -LiteralPath $root)) { continue }
  Get-ChildItem -LiteralPath $root -Recurse -Filter "SKILL.md" -File -Force | ForEach-Object {
    $content = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
    $name = Get-FrontMatterName -Content $content -Fallback (Split-Path -Leaf $_.DirectoryName)
    $nameKey = $name.ToLowerInvariant()
    if (-not $skillLatest.ContainsKey($nameKey) -or $_.LastWriteTime -gt $skillLatest[$nameKey]) {
      $skillLatest[$nameKey] = $_.LastWriteTime
    }

    $repo = Get-GitHubRepo -Content $content
    if (-not $repo) { return }
    if (-not $items.ContainsKey($repo)) {
      $items[$repo] = [ordered]@{
        repo = $repo
        url = "https://github.com/$repo"
        skills = New-Object System.Collections.Generic.List[string]
        localLatest = $_.LastWriteTime
      }
    }
    $items[$repo].skills.Add($name)
    if ($_.LastWriteTime -gt $items[$repo].localLatest) {
      $items[$repo].localLatest = $_.LastWriteTime
    }
  }
}

$sourceIndexPath = Join-Path (Get-Location) "skill-source-index.json"
if (Test-Path -LiteralPath $sourceIndexPath) {
  $sourceIndex = Get-Content -LiteralPath $sourceIndexPath -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($property in $sourceIndex.PSObject.Properties) {
    $repo = Get-GitHubRepoFromUrl -Url ([string]$property.Value)
    if (-not $repo) { continue }

    $skillName = $property.Name
    $localLatest = if ($skillLatest.ContainsKey($skillName.ToLowerInvariant())) { $skillLatest[$skillName.ToLowerInvariant()] } else { Get-Date "1970-01-01" }

    if (-not $items.ContainsKey($repo)) {
      $items[$repo] = [ordered]@{
        repo = $repo
        url = "https://github.com/$repo"
        skills = New-Object System.Collections.Generic.List[string]
        localLatest = $localLatest
      }
    }

    $items[$repo].skills.Add($skillName)
    if ($localLatest -gt $items[$repo].localLatest) {
      $items[$repo].localLatest = $localLatest
    }
  }
}

$results = foreach ($item in $items.Values) {
  $status = "unknown"
  $remotePushedAt = $null
  $remoteHead = $null
  $checkSource = "unknown"
  $message = ""
  $remoteInfo = Get-RemoteRepoInfo -Repo $item.repo
  $remotePushedAt = $remoteInfo.pushedAt
  $remoteHead = $remoteInfo.head
  $checkSource = $remoteInfo.source
  $message = $remoteInfo.message
  if ($remotePushedAt) {
    if ($remotePushedAt -gt $item.localLatest.ToUniversalTime()) {
      $status = "update_available"
      $message = "$message Remote commits are newer than the local SKILL.md timestamp."
    } else {
      $status = "current"
      $message = "$message No newer remote commit detected."
    }
  }

  [ordered]@{
    repo = $item.repo
    url = $item.url
    skills = @($item.skills | Sort-Object -Unique)
    localLatest = $item.localLatest.ToString("yyyy-MM-dd HH:mm:ss")
    remotePushedAt = if ($remotePushedAt) { $remotePushedAt.ToString("yyyy-MM-dd HH:mm:ss") } else { $null }
    remoteHead = $remoteHead
    checkSource = $checkSource
    status = $status
    message = $message
  }
}

$report = [ordered]@{
  checkedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  totalRepos = @($results).Count
  updateCount = @($results | Where-Object { $_.status -eq "update_available" }).Count
  results = @($results | Sort-Object status, repo)
}

$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputJson -Encoding UTF8

$rows = foreach ($result in $report.results) {
  $skills = [System.Net.WebUtility]::HtmlEncode(($result.skills -join ", "))
  $repo = [System.Net.WebUtility]::HtmlEncode($result.repo)
  $url = [System.Net.WebUtility]::HtmlEncode($result.url)
  $status = [System.Net.WebUtility]::HtmlEncode($result.status)
  $local = [System.Net.WebUtility]::HtmlEncode($result.localLatest)
  $remote = [System.Net.WebUtility]::HtmlEncode($result.remotePushedAt)
  "<tr><td><a href=""$url"">$repo</a></td><td>$skills</td><td>$status</td><td>$local</td><td>$remote</td></tr>"
}

$html = @"
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Skill GitHub 更新检查</title>
  <style>
    body { font-family: "Segoe UI", "Microsoft YaHei", sans-serif; margin: 24px; line-height: 1.5; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border-bottom: 1px solid #ddd; padding: 8px; text-align: left; vertical-align: top; }
    th { background: #f4f6f4; }
    a { color: #176b57; }
  </style>
</head>
<body>
  <h1>Skill GitHub 更新检查</h1>
  <p>检查时间：$($report.checkedAt)；识别仓库：$($report.totalRepos)；发现更新：$($report.updateCount)。</p>
  <table>
    <thead><tr><th>仓库</th><th>关联 skill</th><th>状态</th><th>本地时间</th><th>GitHub 最新 push</th></tr></thead>
    <tbody>$($rows -join "`n")</tbody>
  </table>
</body>
</html>
"@

Set-Content -LiteralPath $OutputHtml -Value $html -Encoding UTF8

Write-Output "Checked $($report.totalRepos) GitHub repos. Updates: $($report.updateCount)."
if ($report.updateCount -gt 0) {
  $report.results | Where-Object { $_.status -eq "update_available" } | ForEach-Object {
    Write-Output "UPDATE $($_.repo): $($_.url)"
  }
}
