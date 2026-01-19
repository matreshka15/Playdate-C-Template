# Playdate C Game Build Script for Windows
# Usage: .\build.ps1 [-Clean] [-Run] [-SDKPath <path>] [-Name <name>]

param(
    [switch]$Clean,
    [switch]$Run,
    [string]$SDKPath = "",
    [string]$Name = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$script:Version = "2.0.0"
$script:StartTime = Get-Date

# ==========================================
#  UI & HELPER FUNCTIONS (The "Buddy" System)
# ==========================================

function Get-Icons {
    return @{
        Success = "[OK]"
        Error   = "[FAIL]"
        Warning = "[WARN]"
        Info    = "[INFO]"
        Step    = "[STEP]"
        Build   = "[BUILD]"
        Trash   = "[CLEAN]"
        Link    = "[LINK]"
        Package = "[PACK]"
        Play    = "[PLAY]"
        Code    = "[CODE]"
        Check   = "[?]"
    }
}

function Get-Colors {
    return @{
        Title     = [System.ConsoleColor]::Cyan
        Step      = [System.ConsoleColor]::Yellow
        Success   = [System.ConsoleColor]::Green
        Error     = [System.ConsoleColor]::Red
        Info      = [System.ConsoleColor]::Gray
        Warning   = [System.ConsoleColor]::DarkYellow
        Highlight = [System.ConsoleColor]::Magenta
        Border    = [System.ConsoleColor]::Blue
        Text      = [System.ConsoleColor]::White
    }
}

$icons = Get-Icons

function Show-AsciiArt {
    $colors = Get-Colors
    $art = @"
     _______
    |       |  PLAYDATE C
    |  ___  |  GAME BUILDER
    | |   | |
    | |___| |  v$script:Version
    |       |
    |   +   |  (C)ompile it!
    |_______|
"@
    Write-Host $art -ForegroundColor $colors.Highlight
}

function Speak-Message {
    param([string]$Message, [string]$Color = "Cyan")
    $colors = Get-Colors
    $face = "(^_^)"
    Write-Host "`n  $face $Message" -ForegroundColor $colors.$Color
}

function Write-Step {
    param([string]$Message)
    $colors = Get-Colors
    Write-Host "`n  $($icons.Step) $Message" -ForegroundColor $colors.Step -BackgroundColor $colors.Border -NoNewline
    Write-Host " " -BackgroundColor $colors.Border
}

function Start-Level {
    param([string]$Title, [int]$Level, [int]$Total)
    $colors = Get-Colors
    $p = "+" * $Level + "-" * ($Total - $Level)
    Write-Host "`n  [ STAGE $Level / $Total ] $Title" -ForegroundColor $colors.Highlight -BackgroundColor $colors.Border
    Write-Host "  $p" -ForegroundColor $colors.Step
}

function Write-Success { param($Message) Write-Host "  $($icons.Success) $Message" -ForegroundColor (Get-Colors).Success }
function Write-ErrorMsg { param($Message) Write-Host "  $($icons.Error) $Message" -ForegroundColor (Get-Colors).Error }
function Write-Info { param($Message) Write-Host "  $($icons.Info) $Message" -ForegroundColor (Get-Colors).Info }
function Write-Warning { param($Message) Write-Host "  $($icons.Warning) $Message" -ForegroundColor (Get-Colors).Warning }

function Start-Animation {
    param([string]$Message, [int]$Duration = 1)
    $colors = Get-Colors
    $chars = @("-", "\", "|", "/")
    $endTime = (Get-Date).AddSeconds($Duration)
    $i = 0
    Write-Host "`n  $Message " -ForegroundColor $colors.Highlight -NoNewline
    while ((Get-Date) -lt $endTime) {
        Write-Host "`r  $Message $($chars[$i % $chars.Length])" -ForegroundColor $colors.Highlight -NoNewline
        $i++
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`r  $Message $($icons.Success)" -ForegroundColor $colors.Success
}

# ==========================================
#  CORE LOGIC
# ==========================================

function Get-ScriptDirectory {
    if ($PSScriptRoot) { return $PSScriptRoot }
    return Split-Path -Parent $MyInvocation.MyCommand.Path
}

function Get-Configuration {
    $configPath = Join-Path (Get-ScriptDirectory) "setup-config.json"
    if (Test-Path $configPath) {
        try {
            return Get-Content $configPath -Raw | ConvertFrom-Json
        } catch {
            Write-Warning "Couldn't read setup-config.json. Using defaults."
        }
    }
    return $null
}

function Resolve-SDKPath {
    param([string]$ProvidedPath)
    if ($ProvidedPath -and (Test-Path $ProvidedPath)) { return $ProvidedPath }
    $envPath = $env:PLAYDATE_SDK_PATH
    if ($envPath -and (Test-Path $envPath)) { return $envPath }
    
    $commonPaths = @("D:\APP\PlaydateSDK", "C:\PlaydateSDK", "${env:HOME}\PlaydateSDK")
    foreach ($path in $commonPaths) { if (Test-Path $path) { return $path } }
    return $null
}

function Resolve-ProjectName {
    param([string]$ProvidedName, [object]$Config)
    if ($ProvidedName) { return $ProvidedName }
    if ($Config -and $Config.projectName) { return $Config.projectName }
    return "MyPlaydateGame"
}

# --- INITIALIZATION ---
Clear-Host
Show-AsciiArt

$scriptDir = Get-ScriptDirectory
$config = Get-Configuration

$PROJECT_NAME = Resolve-ProjectName -ProvidedName $Name -Config $config
$SDK_PATH = Resolve-SDKPath -ProvidedPath $SDKPath
$SOURCE_DIR = "src"
$BUILD_DIR = "build"
$OUTPUT_DIR = "."

# Calculate total stages
$currentStage = 1
$totalStages = 4
if ($Clean) { $totalStages++ }
if ($Run) { $totalStages++ }

Speak-Message "Time to build '$PROJECT_NAME'!" "Step"

# --- STAGE: CHECKS ---
Start-Level "Checking Blueprints" $currentStage $totalStages
$currentStage++

if (-not $SDK_PATH) {
    Write-ErrorMsg "I can't find the Playdate SDK!"
    Write-Info "Try running '.\setup.ps1' to fix this automatically."
    exit 1
}
Write-Success "SDK found at $SDK_PATH"

$vsPath = "C:\Program Files\Microsoft Visual Studio\2022"
$vcvarsPath = $null
foreach ($edition in @("Enterprise", "Professional", "Community")) {
    $testPath = "$vsPath\$edition\VC\Auxiliary\Build\vcvars64.bat"
    if (Test-Path $testPath) {
        $vcvarsPath = $testPath
        Write-Success "Visual Studio 2022 $edition found"
        break
    }
}

if (-not $vcvarsPath) {
    Write-ErrorMsg "Visual Studio 2022 is missing!"
    Write-Info "I need the C++ compiler to work my magic."
    exit 1
}

# --- STAGE: CLEAN (Optional) ---
if ($Clean) {
    Start-Level "Taking Out the Trash" $currentStage $totalStages
    $currentStage++
    if (Test-Path $BUILD_DIR) { Remove-Item -Recurse -Force $BUILD_DIR; Write-Success "Removed old build files" }
    if (Test-Path "$OUTPUT_DIR\$PROJECT_NAME.pdx") { Remove-Item -Recurse -Force "$OUTPUT_DIR\$PROJECT_NAME.pdx"; Write-Success "Removed old PDX" }
}

# --- STAGE: COMPILE ---
Start-Level "Cooking the Code" $currentStage $totalStages
$currentStage++

if (-not (Test-Path $BUILD_DIR)) { New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null }

$sourceFiles = Get-ChildItem -Path $SOURCE_DIR -Filter *.c -Recurse | ForEach-Object { $_.FullName }

if ($sourceFiles.Count -eq 0) {
    Write-Warning "I didn't find any .c files in '$SOURCE_DIR'!"
    Write-Info "Write some code first, then come back."
    exit 1
}

Write-Info "Found $($sourceFiles.Count) source file(s)."

$includes = "/I`"$SDK_PATH\C_API`""
$defines = "/DTARGET_PLAYDATE=1 /DTARGET_EXTENSION=1 /DTARGET_SIMULATOR=1 /D_WINDLL"
$compilerFlags = "/c /nologo /W3 /Z7 /Od /MD"
$objFiles = @()

foreach ($sourceFile in $sourceFiles) {
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($sourceFile)
    $objFile = "$BUILD_DIR\$fileName.obj"
    $objFiles += $objFile

    Write-Host "  $($icons.Code) Compiling: $([System.IO.Path]::GetFileName($sourceFile))..." -ForegroundColor Gray
    
    $batchContent = "@echo off`ncall `"$vcvarsPath`"`ncl $compilerFlags $defines $includes `"$sourceFile`" /Fo:`"$objFile`""
    $batchFile = "$BUILD_DIR\compile_$fileName.bat"
    Set-Content -Path $batchFile -Value $batchContent
    
    $result = & cmd /c $batchFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Compilation failed on $fileName.c"
        Write-Host $result -ForegroundColor Red
        exit 1
    }
}
Write-Success "All files compiled successfully!"

# --- STAGE: LINK ---
Start-Level "Gluing It All Together" $currentStage $totalStages
$currentStage++

$dllFile = "$BUILD_DIR\pdex.dll"
$objList = ($objFiles | ForEach-Object { "`"$_`"" }) -join " "
$linkerFlags = "/DLL /NOLOGO /DEBUG /INCREMENTAL:NO /EXPORT:eventHandler"

$batchContent = "@echo off`ncall `"$vcvarsPath`"`nlink $linkerFlags $objList /OUT:`"$dllFile`""
$batchFile = "$BUILD_DIR\link.bat"
Set-Content -Path $batchFile -Value $batchContent

$result = & cmd /c $batchFile 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Linking failed!"
    Write-Host $result -ForegroundColor Red
    exit 1
}
Write-Success "Created pdex.dll"

# --- STAGE: PACKAGE ---
Start-Level "Wrapping the Gift" $currentStage $totalStages
$currentStage++

$pdcPath = "$SDK_PATH\bin\pdc.exe"
if (-not (Test-Path $pdcPath)) { Write-ErrorMsg "pdc.exe missing!"; exit 1 }

$tempDir = "$BUILD_DIR\temp_game"
if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
New-Item -ItemType Directory -Path $tempDir | Out-Null
Copy-Item $dllFile "$tempDir\pdex.dll"

# Default metadata
$author = "Developer"
$description = "My Playdate Game"
$bundleID = "com.example.$PROJECT_NAME"

if ($config) {
    if ($config.author) { $author = $config.author }
    if ($config.description) { $description = $config.description }
    if ($config.bundleID) { $bundleID = $config.bundleID }
}

$pdxinfo = @"
name=$PROJECT_NAME
author=$author
description=$description
bundleID=$bundleID
version=1.0.0
buildNumber=1
"@
Set-Content -Path "$tempDir\pdxinfo" -Value $pdxinfo

$outputPdx = "$OUTPUT_DIR\$PROJECT_NAME.pdx"
& $pdcPath $tempDir $outputPdx 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outputPdx)) {
    Write-ErrorMsg "PDC packaging failed!"
    exit 1
}
Write-Success "Created package: $PROJECT_NAME.pdx"

# --- STAGE: RUN (Optional) ---
if ($Run) {
    Start-Level "It's Playtime!" $currentStage $totalStages
    $simulatorPath = "$SDK_PATH\bin\PlaydateSimulator.exe"
    if (Test-Path $simulatorPath) {
        Start-Process -FilePath $simulatorPath -ArgumentList "`"$outputPdx`""
        Speak-Message "Simulator launched. Have fun!" "Success"
    } else {
        Write-ErrorMsg "Simulator not found at $simulatorPath"
    }
} else {
    Speak-Message "Build complete! Use '.\build.ps1 -Run' to play." "Success"
}

$elapsedTime = New-TimeSpan -Start $script:StartTime -End (Get-Date)
Write-Info "Total time: $($elapsedTime.ToString("mm\:ss"))"
