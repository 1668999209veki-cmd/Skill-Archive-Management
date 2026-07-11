param(
  [string]$ReportPath = (Join-Path (Join-Path (Get-Location) "reports") "skill-update-report.json"),
  [string]$SourceIndexPath = (Join-Path (Get-Location) "skill-source-index.json"),
  [string]$OutputPath = (Join-Path (Join-Path (Get-Location) "reports") "skill-update-run.json")
)

$ErrorActionPreference = "Continue"

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null

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

function ConvertTo-RepoSpec {
  param([string]$Url)

  $match = [regex]::Match($Url, "github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)(?:/blob/([^/]+)/(.+?))?$")
  if (-not $match.Success) { return $null }

  $repoName = $match.Groups[2].Value -replace "\.git$", ""
  $skillFilePath = if ($match.Groups[4].Success) { $match.Groups[4].Value } else { $null }
  $skillDirPath = if ($skillFilePath) { Split-Path -Parent $skillFilePath } else { $null }

  return [ordered]@{
    repo = "$($match.Groups[1].Value)/$repoName"
    branch = if ($match.Groups[3].Success) { $match.Groups[3].Value } else { $null }
    skillDirPath = if ($skillDirPath) { $skillDirPath -replace "\\", "/" } else { $null }
  }
}

function Test-UnderRoots {
  param([string]$Path)
  $resolved = [System.IO.Path]::GetFullPath($Path)
  foreach ($root in $roots) {
    $rootFull = [System.IO.Path]::GetFullPath($root)
    if ($resolved.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  return $false
}

function Get-LocalSkillDirs {
  param([string]$SkillName)

  $dirs = New-Object System.Collections.Generic.List[string]
  foreach ($root in $roots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    Get-ChildItem -LiteralPath $root -Recurse -Filter "SKILL.md" -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
      $content = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
      $name = Get-FrontMatterName -Content $content -Fallback $_.Directory.Name
      if ($name -ieq $SkillName -or $_.Directory.Name -ieq $SkillName) {
        $dirs.Add($_.Directory.FullName)
      }
    }
  }
  return @($dirs | Sort-Object -Unique)
}

function Get-RemoteSkillDir {
  param(
    [string]$Repo,
    [AllowNull()][string]$Branch,
    [AllowNull()][string]$SkillDirPath,
    [string]$SkillName
  )

  # Risk note: this update path clones or inspects remote repositories.
  # Review source URLs first and only update Skills from trusted repositories.
  $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("skill-update-" + [guid]::NewGuid().ToString("N"))
  try {
    $remote = "https://github.com/$Repo.git"
    if (-not $Branch) {
      $head = git ls-remote --symref $remote HEAD 2>$null
      $Branch = "main"
      foreach ($line in $head) {
        $match = [regex]::Match($line, "^ref:\s+refs/heads/(.+?)\s+HEAD$")
        if ($match.Success) {
          $Branch = $match.Groups[1].Value
          break
        }
      }
    }

    git clone --depth 1 --filter=blob:none --sparse --branch $Branch $remote $tempRoot 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git clone failed for $Repo" }

    if ($SkillDirPath) {
      git -C $tempRoot sparse-checkout set --no-cone "/$SkillDirPath/**" 2>$null | Out-Null
    } else {
      git -C $tempRoot sparse-checkout set --no-cone `
        "/*/SKILL.md" `
        "/skills/*/SKILL.md" `
        "/skills/**/SKILL.md" `
        "/.agents/skills/*/SKILL.md" `
        "/.codex/skills/*/SKILL.md" `
        "/.kiro/skills/*/SKILL.md" `
        "/docs/*/skills/*/SKILL.md" `
        "/docs/*/skills/**/SKILL.md" 2>$null | Out-Null
    }

    $candidates = Get-ChildItem -LiteralPath $tempRoot -Recurse -Filter "SKILL.md" -File -ErrorAction SilentlyContinue
    foreach ($candidate in $candidates) {
      $content = Get-Content -LiteralPath $candidate.FullName -Raw -Encoding UTF8
      $name = Get-FrontMatterName -Content $content -Fallback $candidate.Directory.Name
      if ($name -ieq $SkillName -or $candidate.Directory.Name -ieq $SkillName) {
        return [ordered]@{
          tempRoot = $tempRoot
          path = $candidate.Directory.FullName
          branch = $Branch
        }
      }
    }

    throw "could not find $SkillName in $Repo"
  } catch {
    if (Test-Path -LiteralPath $tempRoot) {
      Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    throw
  }
}

if (-not (Test-Path -LiteralPath $ReportPath)) {
  throw "Missing update report: $ReportPath"
}

$sourceIndex = @{}
if (Test-Path -LiteralPath $SourceIndexPath) {
  $sourceJson = Get-Content -LiteralPath $SourceIndexPath -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($property in $sourceJson.PSObject.Properties) {
    $sourceIndex[$property.Name.ToLowerInvariant()] = [string]$property.Value
  }
}

$report = Get-Content -LiteralPath $ReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
$targets = @($report.results | Where-Object { $_.status -eq "update_available" })
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path (Get-Location) "skill-update-backups\$stamp"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

$results = New-Object System.Collections.Generic.List[object]

foreach ($target in $targets) {
  foreach ($skillName in @($target.skills)) {
    $skillKey = $skillName.ToLowerInvariant()
    $sourceUrl = if ($sourceIndex.ContainsKey($skillKey)) { $sourceIndex[$skillKey] } else { $target.url }
    $spec = ConvertTo-RepoSpec -Url $sourceUrl
    if (-not $spec) {
      $results.Add([ordered]@{ skill = $skillName; repo = $target.repo; status = "skipped"; message = "No usable GitHub source URL." })
      continue
    }

    try {
      $localDirs = Get-LocalSkillDirs -SkillName $skillName
      if (-not $localDirs -or $localDirs.Count -eq 0) { throw "Local skill directory not found." }

      $remoteDir = Get-RemoteSkillDir -Repo $spec.repo -Branch $spec.branch -SkillDirPath $spec.skillDirPath -SkillName $skillName
      try {
        foreach ($localDir in $localDirs) {
          if (-not (Test-UnderRoots -Path $localDir)) { throw "Refusing to update path outside skill roots: $localDir" }

          $backupDir = Join-Path $backupRoot (($skillName + "-" + ([guid]::NewGuid().ToString("N"))) -replace '[\\/:*?"<>|]', '_')
          Copy-Item -LiteralPath $localDir -Destination $backupDir -Recurse -Force

          Get-ChildItem -LiteralPath $localDir -Force | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force
          }
          Get-ChildItem -LiteralPath $remoteDir.path -Force | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $localDir -Recurse -Force
          }
        }

        $results.Add([ordered]@{
          skill = $skillName
          repo = $spec.repo
          status = "updated"
          message = "Updated $($localDirs.Count) local copy/copies from $($spec.repo)."
        })
      } finally {
        if ($remoteDir.tempRoot -and (Test-Path -LiteralPath $remoteDir.tempRoot)) {
          Remove-Item -LiteralPath $remoteDir.tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
      }
    } catch {
      $results.Add([ordered]@{
        skill = $skillName
        repo = $target.repo
        status = "failed"
        message = $_.Exception.Message
      })
    }
  }
}

$resultItems = @($results.ToArray())
$summary = [ordered]@{
  updatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  requestedRepos = @($targets).Count
  updatedSkills = @($resultItems | Where-Object { $_.status -eq "updated" }).Count
  failedSkills = @($resultItems | Where-Object { $_.status -eq "failed" }).Count
  skippedSkills = @($resultItems | Where-Object { $_.status -eq "skipped" }).Count
  backupRoot = $backupRoot
  results = @($resultItems)
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output "Updated $($summary.updatedSkills) skills. Failed: $($summary.failedSkills). Skipped: $($summary.skippedSkills)."
