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
      ___________
     |  _______  |  PLAYDATE C
     | |       | |  GAME BUILDER
     | |_______| |__
     |      @    |  | v$script:Version
     |   _    O  |  |
     | _| |_  O  |  |
     ||_   _|    |__| (C)ompile it!
     |  |_|      |
     |___________|
"@
    Write-Host $art -ForegroundColor $colors.Highlight
}

function Get-Faces {
    return @{
        Happy    = "(^_^)"
        Success  = "(*^v^*)"
        Excited  = "\(^o^)/"
        Warning  = "(>_<)"
        Error    = "(T_T)"
        Info     = "(o_o)"
        Confused = "(?_?)"
        Sleepy   = "(-.-)Zzz"
        Cool     = "(^_~)d"
    }
}

function Speak-Message {
    param([string]$Message, [string]$Color = "Cyan", [string]$Mood = "")
    $colors = Get-Colors
    $faces = Get-Faces
    
    # Auto-detect mood if not provided
    if (-not $Mood) {
        switch ($Color) {
            "Success"   { $Mood = "Success" }
            "Error"     { $Mood = "Error" }
            "Warning"   { $Mood = "Warning" }
            "Info"      { $Mood = "Info" }
            "Cyan"      { $Mood = "Happy" }
            "Highlight" { $Mood = "Excited" }
            default     { $Mood = "Happy" }
        }
    }

    $face = if ($faces.ContainsKey($Mood)) { $faces[$Mood] } else { $faces.Happy }
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
    
    $commonPaths = @(
        "$env:USERPROFILE\Documents\PlaydateSDK",
        "$env:USERPROFILE\Documents\Playdate SDK",
        "$env:ProgramFiles\PlaydateSDK",
        "$env:ProgramFiles\Playdate SDK",
        "${env:ProgramFiles(x86)}\PlaydateSDK",
        "${env:ProgramFiles(x86)}\Playdate SDK",
        "C:\PlaydateSDK",
        "C:\Playdate SDK",
        "D:\PlaydateSDK",
        "E:\PlaydateSDK",
        "D:\Program Files\PlaydateSDK",
        "D:\Program Files (x86)\PlaydateSDK",
        "E:\Program Files\PlaydateSDK",
        "E:\Program Files (x86)\PlaydateSDK",
        "${env:HOME}\PlaydateSDK",
        "${env:HOME}\Playdate SDK",
        "$env:USERPROFILE\PlaydateSDK"
    )
    foreach ($path in $commonPaths) { if (Test-Path $path) { return $path } }
    return $null
}

function Resolve-ProjectName {
    param([string]$ProvidedName, [object]$Config)
    if ($ProvidedName) { return $ProvidedName }
    if ($Config -and $Config.projectName) { return $Config.projectName }
    return "MyPlaydateGame"
}

function Get-VisualStudioPath {
    param([string]$ConfigPath)

    # -1. Check Config Path
    if ($ConfigPath -and (Test-Path $ConfigPath)) {
        return $ConfigPath
    }

    # 0. Check Environment Variables (Developer Command Prompt)
    if ($env:VSINSTALLDIR -and (Test-Path $env:VSINSTALLDIR)) {
        $vcvarsPath = Join-Path $env:VSINSTALLDIR "VC\Auxiliary\Build\vcvars64.bat"
        if (Test-Path $vcvarsPath) {
            return $vcvarsPath
        }
    }

    # 1. Try vswhere (most reliable method)
    $vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswherePath)) {
        $vswherePath = "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe"
    }

    if (Test-Path $vswherePath) {
        try {
            # Search for VS with VC++ tools using JSON format
            $jsonOutput = & $vswherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json | ConvertFrom-Json
            
            if ($jsonOutput) {
                if ($jsonOutput -is [array]) { $vsInfo = $jsonOutput[0] } else { $vsInfo = $jsonOutput }
                $vsPath = $vsInfo.installationPath
                
                if ($vsPath -and (Test-Path $vsPath)) {
                    $vcvarsPath = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
                    if (Test-Path $vcvarsPath) {
                        return $vcvarsPath
                    }
                }
            }
        } catch {}
    }

    # 2. Fallback to legacy search
    $basePaths = @(
        "C:\Program Files\Microsoft Visual Studio",
        "C:\Program Files (x86)\Microsoft Visual Studio"
    )
    $years = @("2022", "2019", "2017")
    $editions = @("Community", "Professional", "Enterprise", "BuildTools")

    foreach ($base in $basePaths) {
        foreach ($year in $years) {
            foreach ($edition in $editions) {
                $vcvarsPath = Join-Path $base "$year\$edition\VC\Auxiliary\Build\vcvars64.bat"
                if (Test-Path $vcvarsPath) {
                    return $vcvarsPath
                }
            }
        }
    }
    return $null
}

function Import-VisualStudioEnv {
    param([string]$VcVarsPath)
    
    # Check if cl is already available
    if (Get-Command "cl.exe" -ErrorAction SilentlyContinue) {
        return $true
    }

    if (-not $VcVarsPath -or -not (Test-Path $VcVarsPath)) {
        return $false
    }

    # OPTIMIZATION: Cache environment variables
    $cacheDir = Join-Path $env:TEMP "PlaydateVSBuildCache"
    if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
    
    $pathHash = [BitConverter]::ToString(($([System.Security.Cryptography.SHA256]::Create()).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($VcVarsPath)))).Replace("-", "")
    $cacheFile = Join-Path $cacheDir "env_$pathHash.json"
    
    if (Test-Path $cacheFile) {
        try {
            $vcvarsTime = (Get-Item $VcVarsPath).LastWriteTime
            $cacheTime = (Get-Item $cacheFile).LastWriteTime
            
            if ($cacheTime -gt $vcvarsTime) {
                $cachedEnv = Get-Content $cacheFile | ConvertFrom-Json
                foreach ($prop in $cachedEnv.PSObject.Properties) {
                    [Environment]::SetEnvironmentVariable($prop.Name, $prop.Value, "Process")
                }
                if (Get-Command "cl.exe" -ErrorAction SilentlyContinue) { return $true }
            }
        } catch { Remove-Item $cacheFile -ErrorAction SilentlyContinue }
    }

    Write-Info "Initializing Visual Studio environment (this runs once)..."
    
    # Capture environment variables from vcvars batch file
    # We use cmd to run vcvars and then capture stdout directly to avoid encoding issues with temp files
    Write-Host "  $($icons.Settings) Running vcvars64.bat..." -ForegroundColor Gray
    
    $lines = & cmd /c "`"$VcVarsPath`" > nul && set" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $envMap = @{}
        foreach ($line in $lines) {
            if ($line -match "^(.*?)=(.*)$") {
                $name = $matches[1]
                $value = $matches[2]
                
                # Skip empty names or internal cmd variables
                if ([string]::IsNullOrWhiteSpace($name) -or $name.StartsWith(":")) { continue }

                # Set variable
                if ([Environment]::GetEnvironmentVariable($name, "Process") -ne $value) {
                    [Environment]::SetEnvironmentVariable($name, $value, "Process")
                    $envMap[$name] = $value
                }
            }
        }
        
        # Verify result
        if (Get-Command "cl.exe" -ErrorAction SilentlyContinue) {
             # Save cache only if successful
            try { $envMap | ConvertTo-Json -Depth 1 | Set-Content $cacheFile } catch {}
            return $true
        }
    }
    
    return $false
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

$vcvarsPath = Get-VisualStudioPath -ConfigPath $config.visualStudioPath

if ($vcvarsPath) {
    Write-Success "Visual Studio environment found"
    if (-not (Import-VisualStudioEnv -VcVarsPath $vcvarsPath)) {
        Write-ErrorMsg "Failed to initialize Visual Studio environment."
        Write-Info "Could not load environment from: $vcvarsPath"
        exit 1
    }
} else {
    Write-ErrorMsg "Visual Studio is missing!"
    Write-Info "I need the C++ compiler (MSVC) to work my magic."
    Write-Info "Please install Visual Studio 2022/2019/2017 with C++ Desktop Development workload."
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
$compilerFlags = "/c /nologo /W3 /Z7 /Od /MD /MP"

# OPTIMIZATION: Compile all files in one go to leverage /MP (Parallel Build)
Write-Host "  $($icons.Code) Compiling $($sourceFiles.Count) files..." -ForegroundColor Gray

# Wrap paths in quotes
$quotedSourceFiles = $sourceFiles | ForEach-Object { "`"$_`"" }
$allSources = $quotedSourceFiles -join " "

# Ensure build dir has trailing slash for /Fo
$outputDirParam = "/Fo`"$BUILD_DIR\`""

# Execute cl directly (environment is already loaded)
$compileCmd = "cl $compilerFlags $defines $includes $allSources $outputDirParam"
$result = Invoke-Expression $compileCmd 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Compilation failed!"
    Write-Host "$result" -ForegroundColor Red
    exit 1
}

Write-Success "Compilation complete!"

# --- STAGE: LINK ---
Start-Level "Gluing It All Together" $currentStage $totalStages
$currentStage++

$dllFile = "$BUILD_DIR\pdex.dll"
# Collect all .obj files from the build directory
$objFiles = Get-ChildItem -Path $BUILD_DIR -Filter *.obj | ForEach-Object { $_.FullName }
$objList = ($objFiles | ForEach-Object { "`"$_`"" }) -join " "
$linkerFlags = "/DLL /NOLOGO /DEBUG /INCREMENTAL:NO /EXPORT:eventHandler"

Write-Host "  $($icons.Link) Linking..." -ForegroundColor Gray

# Execute link directly
$linkCmd = "link $linkerFlags $objList /OUT:`"$dllFile`""
$result = Invoke-Expression $linkCmd 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Linking failed!"
    Write-Host "$result" -ForegroundColor Red
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
