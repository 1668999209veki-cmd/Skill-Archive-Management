param(
  [int]$Port = 8765
)

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()

Write-Output "Skill update server listening at http://127.0.0.1:$Port/"

function Write-JsonResponse {
  param(
    [System.Net.HttpListenerContext]$Context,
    [int]$StatusCode,
    [object]$Body
  )

  $Context.Response.StatusCode = $StatusCode
  $Context.Response.Headers.Add("Access-Control-Allow-Origin", "*")
  $Context.Response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  $Context.Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
  $Context.Response.ContentType = "application/json; charset=utf-8"
  $json = $Body | ConvertTo-Json -Depth 8
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $Context.Response.Close()
}

function Invoke-SkillCommand {
  param([string]$Command)

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = "powershell.exe"
  $psi.WorkingDirectory = $root
  $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command $Command"
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $process = [System.Diagnostics.Process]::Start($psi)
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()

  return [ordered]@{
    exitCode = $process.ExitCode
    stdout = $stdout
    stderr = $stderr
  }
}

while ($listener.IsListening) {
  $context = $listener.GetContext()
  try {
    if ($context.Request.HttpMethod -eq "OPTIONS") {
      Write-JsonResponse -Context $context -StatusCode 200 -Body @{ ok = $true }
      continue
    }

    $path = $context.Request.Url.AbsolutePath.TrimEnd("/")
    if ($path -eq "") { $path = "/" }

    if ($context.Request.HttpMethod -eq "GET" -and $path -eq "/status") {
      $reportPath = Join-Path $root "skill-update-report.json"
      $runPath = Join-Path $root "skill-update-run.json"
      $report = if (Test-Path -LiteralPath $reportPath) { Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
      $run = if (Test-Path -LiteralPath $runPath) { Get-Content -LiteralPath $runPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
      Write-JsonResponse -Context $context -StatusCode 200 -Body @{ ok = $true; report = $report; lastRun = $run }
      continue
    }

    if ($context.Request.HttpMethod -eq "POST" -and $path -eq "/check") {
      $check = Invoke-SkillCommand -Command "& '.\scripts\check-skill-updates.ps1' -UseGitFallback -GitTimeoutSec 18"
      if ($check.exitCode -ne 0) {
        Write-JsonResponse -Context $context -StatusCode 500 -Body @{ ok = $false; stage = "check"; result = $check }
        continue
      }
      $generate = Invoke-SkillCommand -Command "& '.\scripts\generate-skill-archive.ps1'"
      $reportPath = Join-Path $root "skill-update-report.json"
      $report = if (Test-Path -LiteralPath $reportPath) { Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
      Write-JsonResponse -Context $context -StatusCode 200 -Body @{ ok = $true; check = $check; generate = $generate; report = $report }
      continue
    }

    if ($context.Request.HttpMethod -eq "POST" -and $path -eq "/update") {
      $update = Invoke-SkillCommand -Command "& '.\scripts\update-skills.ps1'"
      if ($update.exitCode -ne 0) {
        Write-JsonResponse -Context $context -StatusCode 500 -Body @{ ok = $false; stage = "update"; result = $update }
        continue
      }

      $refreshCheck = Invoke-SkillCommand -Command "& '.\scripts\check-skill-updates.ps1'"
      $generate = Invoke-SkillCommand -Command "& '.\scripts\generate-skill-archive.ps1'"
      $runPath = Join-Path $root "skill-update-run.json"
      $run = if (Test-Path -LiteralPath $runPath) { Get-Content -LiteralPath $runPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
      Write-JsonResponse -Context $context -StatusCode 200 -Body @{ ok = $true; update = $update; refreshCheck = $refreshCheck; generate = $generate; run = $run }
      continue
    }

    Write-JsonResponse -Context $context -StatusCode 404 -Body @{ ok = $false; message = "Not found." }
  } catch {
    Write-JsonResponse -Context $context -StatusCode 500 -Body @{ ok = $false; message = $_.Exception.Message }
  }
}
