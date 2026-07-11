param(
  [switch]$NoOpen
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$archivePath = Join-Path $repoRoot "skill-archive.html"
$generatorPath = Join-Path $repoRoot "scripts\generate-skill-archive.ps1"

if (-not (Test-Path -LiteralPath $generatorPath)) {
  throw "Missing generator script: $generatorPath"
}

Push-Location $repoRoot
try {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $generatorPath -OutputPath $archivePath
} finally {
  Pop-Location
}

if (-not (Test-Path -LiteralPath $archivePath)) {
  throw "Dashboard was not generated: $archivePath"
}

Write-Host ""
Write-Host "Skill archive dashboard generated:"
Write-Host $archivePath

if (-not $NoOpen) {
  Start-Process $archivePath
}
