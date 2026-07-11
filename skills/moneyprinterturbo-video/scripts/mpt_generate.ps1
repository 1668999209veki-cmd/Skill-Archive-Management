[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Subject,

    [string]$ScriptText = "",

    [string]$ProjectDir = (Join-Path (Get-Location) "MoneyPrinterTurbo"),

    [string]$RepoUrl = "https://github.com/harry0703/MoneyPrinterTurbo.git",

    [string]$ApiBase = "http://127.0.0.1:8080",

    [ValidateSet("9:16", "16:9", "1:1")]
    [string]$Aspect = "9:16",

    [ValidateSet("pexels", "pixabay", "local")]
    [string]$VideoSource = "pexels",

    [string]$Terms = "",

    [string]$VoiceName = "",

    [string]$Language = "",

    [ValidateRange(1, 10)]
    [int]$ParagraphNumber = 1,

    [ValidateRange(1, 10)]
    [int]$VideoCount = 1,

    [ValidateRange(1, 60)]
    [int]$ClipDuration = 5,

    [string]$BgmType = "random",

    [string]$BgmFile = "",

    [switch]$NoSubtitle,

    [ValidateRange(12, 200)]
    [int]$FontSize = 60,

    [string]$OutputDir = (Join-Path (Get-Location) "moneyprinterturbo-output"),

    [switch]$SkipInstall,

    [switch]$StartServer,

    [ValidateRange(10, 600)]
    [int]$ServerWaitSeconds = 120,

    [ValidateRange(1, 60)]
    [int]$PollSeconds = 5,

    [ValidateRange(1, 240)]
    [int]$TimeoutMinutes = 30
)

$ErrorActionPreference = "Stop"

function Test-CommandExists {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Resolve-OrFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($resolved) {
        return $resolved.Path
    }
    return [System.IO.Path]::GetFullPath($Path)
}

function Get-ApiUrl {
    param([Parameter(Mandatory = $true)][string]$Path)
    $base = $ApiBase.TrimEnd("/")
    if ($Path.StartsWith("/")) {
        return "$base$Path"
    }
    return "$base/$Path"
}

function Test-MptApi {
    try {
        Invoke-WebRequest -Uri (Get-ApiUrl "/docs") -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Read-ShortLog {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }
    return (Get-Content -LiteralPath $Path -Tail 40 -ErrorAction SilentlyContinue) -join [Environment]::NewLine
}

$ProjectDir = Resolve-OrFullPath $ProjectDir
$OutputDir = Resolve-OrFullPath $OutputDir
$ApiBase = $ApiBase.TrimEnd("/")

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    if (-not (Test-CommandExists "git")) {
        throw "git is required to clone MoneyPrinterTurbo, but it was not found in PATH."
    }

    $parent = Split-Path -Parent $ProjectDir
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    Write-Host "Cloning MoneyPrinterTurbo into $ProjectDir"
    git clone --depth 1 $RepoUrl $ProjectDir
}

if (-not (Test-Path -LiteralPath (Join-Path $ProjectDir "pyproject.toml"))) {
    throw "ProjectDir does not look like MoneyPrinterTurbo: $ProjectDir"
}

if (-not $SkipInstall) {
    if (-not (Test-CommandExists "uv")) {
        throw "uv is required. Install it from https://docs.astral.sh/uv/ or rerun with -SkipInstall if dependencies are already ready."
    }

    Push-Location $ProjectDir
    try {
        Write-Host "Ensuring Python 3.11 is available through uv"
        uv python install 3.11

        Write-Host "Syncing MoneyPrinterTurbo dependencies"
        uv sync --frozen
    }
    finally {
        Pop-Location
    }
}

$configPath = Join-Path $ProjectDir "config.toml"
$exampleConfigPath = Join-Path $ProjectDir "config.example.toml"
if (-not (Test-Path -LiteralPath $configPath)) {
    if (-not (Test-Path -LiteralPath $exampleConfigPath)) {
        throw "config.example.toml was not found in $ProjectDir."
    }
    Copy-Item -LiteralPath $exampleConfigPath -Destination $configPath
    Write-Warning "Created config.toml from config.example.toml. Fill provider and material API keys before topic-only generation."
}

$configText = Get-Content -LiteralPath $configPath -Raw
if ([string]::IsNullOrWhiteSpace($ScriptText) -and $configText -match 'llm_provider\s*=\s*"openai"' -and $configText -match 'openai_api_key\s*=\s*""') {
    Write-Warning "config.toml appears to use OpenAI with an empty openai_api_key. Topic-only generation may fail until the matching LLM key is configured."
}
if ($VideoSource -eq "pexels" -and $configText -match 'pexels_api_keys\s*=\s*\[\s*\]') {
    Write-Warning "video_source is pexels, but pexels_api_keys appears empty in config.toml."
}
if ($VideoSource -eq "pixabay" -and $configText -match 'pixabay_api_keys\s*=\s*\[\s*\]') {
    Write-Warning "video_source is pixabay, but pixabay_api_keys appears empty in config.toml."
}

if (-not (Test-MptApi)) {
    if (-not $StartServer) {
        throw "MoneyPrinterTurbo API is not reachable at $ApiBase. Start it with 'uv run python main.py' or rerun this script with -StartServer."
    }
    if (-not (Test-CommandExists "uv")) {
        throw "uv is required to start the API server automatically."
    }

    $logDir = Join-Path $ProjectDir "storage"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $stdoutLog = Join-Path $logDir "codex-api.out.log"
    $stderrLog = Join-Path $logDir "codex-api.err.log"

    Write-Host "Starting MoneyPrinterTurbo API at $ApiBase"
    $process = Start-Process `
        -FilePath "uv" `
        -ArgumentList @("run", "python", "main.py") `
        -WorkingDirectory $ProjectDir `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError $stderrLog `
        -PassThru

    $serverDeadline = (Get-Date).AddSeconds($ServerWaitSeconds)
    while ((Get-Date) -lt $serverDeadline) {
        if (Test-MptApi) {
            break
        }
        if ($process.HasExited) {
            $err = Read-ShortLog $stderrLog
            throw "MoneyPrinterTurbo API process exited early. See $stderrLog. $err"
        }
        Start-Sleep -Seconds 2
    }

    if (-not (Test-MptApi)) {
        throw "Timed out waiting for MoneyPrinterTurbo API at $ApiBase. See $stderrLog and $stdoutLog."
    }
}

$videoTerms = $null
if (-not [string]::IsNullOrWhiteSpace($Terms)) {
    $videoTerms = @($Terms -split "\s*,\s*" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

$body = [ordered]@{
    video_subject = $Subject
    video_script = $ScriptText
    video_terms = $videoTerms
    video_aspect = $Aspect
    video_concat_mode = "random"
    video_transition_mode = $null
    video_clip_duration = $ClipDuration
    video_count = $VideoCount
    video_source = $VideoSource
    video_language = $Language
    voice_name = $VoiceName
    bgm_type = $BgmType
    bgm_file = $BgmFile
    subtitle_enabled = -not $NoSubtitle.IsPresent
    subtitle_position = "bottom"
    font_size = $FontSize
    stroke_color = "#000000"
    stroke_width = 1.5
    paragraph_number = $ParagraphNumber
}

$jsonBody = $body | ConvertTo-Json -Depth 8
Write-Host "Submitting video task"
$createResponse = Invoke-RestMethod `
    -Method Post `
    -Uri (Get-ApiUrl "/api/v1/videos") `
    -ContentType "application/json; charset=utf-8" `
    -Body $jsonBody `
    -TimeoutSec 60

if ($createResponse.status -ne 200) {
    throw "Task creation failed: $($createResponse | ConvertTo-Json -Depth 8)"
}

$taskId = $createResponse.data.task_id
if ([string]::IsNullOrWhiteSpace($taskId)) {
    throw "Task creation response did not include task_id: $($createResponse | ConvertTo-Json -Depth 8)"
}

Write-Host "Task created: $taskId"
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$taskData = $null

while ((Get-Date) -lt $deadline) {
    $taskResponse = Invoke-RestMethod -Uri (Get-ApiUrl "/api/v1/tasks/$taskId") -TimeoutSec 30
    $taskData = $taskResponse.data
    $progress = 0
    if ($null -ne $taskData.progress) {
        $progress = [int]$taskData.progress
    }

    Write-Progress -Activity "Generating MoneyPrinterTurbo video" -Status "Task $taskId" -PercentComplete ([Math]::Min($progress, 100))
    Write-Host ("Progress: {0}%" -f $progress)

    if ($taskData.videos -and $progress -ge 100) {
        break
    }
    if ($null -ne $taskData.state -and [int]$taskData.state -lt 0) {
        throw "Task failed: $($taskData | ConvertTo-Json -Depth 8)"
    }

    Start-Sleep -Seconds $PollSeconds
}

Write-Progress -Activity "Generating MoneyPrinterTurbo video" -Completed

if (-not $taskData -or -not $taskData.videos) {
    throw "Timed out or no videos were returned for task $taskId. Last task data: $($taskData | ConvertTo-Json -Depth 8)"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$downloaded = @()
$index = 1
foreach ($videoUrlRaw in @($taskData.videos)) {
    $videoUrl = [string]$videoUrlRaw
    if ($videoUrl -notmatch "^https?://") {
        if ($videoUrl.StartsWith("/")) {
            $videoUrl = "$ApiBase$videoUrl"
        }
        else {
            $videoUrl = "$ApiBase/$videoUrl"
        }
    }

    $uri = [Uri]$videoUrl
    $fileName = [System.IO.Path]::GetFileName($uri.AbsolutePath)
    if ([string]::IsNullOrWhiteSpace($fileName)) {
        $fileName = "final-$index.mp4"
    }
    if (-not $fileName.EndsWith(".mp4", [System.StringComparison]::OrdinalIgnoreCase)) {
        $fileName = "$fileName.mp4"
    }

    $prefix = $taskId
    if ($taskId.Length -gt 8) {
        $prefix = $taskId.Substring(0, 8)
    }
    $destination = Join-Path $OutputDir "$prefix-$fileName"
    Write-Host "Downloading $videoUrl to $destination"
    Invoke-WebRequest -Uri $videoUrl -OutFile $destination -UseBasicParsing -TimeoutSec 600
    $downloaded += $destination
    $index += 1
}

[pscustomobject]@{
    task_id = $taskId
    api_base = $ApiBase
    project_dir = $ProjectDir
    output_dir = $OutputDir
    videos = $downloaded
    task = $taskData
} | ConvertTo-Json -Depth 12
