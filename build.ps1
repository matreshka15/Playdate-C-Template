# Playdate C Game Build Script for Windows
# 日常用法 (Daily use):
#   .\build.ps1 -Run                    # 构建 + 启动模拟器  (最常用)
#   .\build.ps1                         # 仅构建 .pdx
#   .\build.ps1 -Clean                  # 清理构建产物
# 高级 (Advanced):
#   .\build.ps1 -Config Release         # Release 模式（关掉调试信息）
#   .\build.ps1 -Target Device          # 构建真机版本 (需 ARM 工具链 + CMake)

param(
    [switch]$Clean,
    [switch]$Run,
    [ValidateSet('Simulator', 'Device')]
    [string]$Target = "Simulator",
    [ValidateSet('Debug', 'Release')]
    [string]$Config = "Debug",
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
    param([string]$ProvidedName, [object]$ProjectConfig)
    if ($ProvidedName) { return $ProvidedName }
    if ($ProjectConfig -and $ProjectConfig.projectName) { return $ProjectConfig.projectName }
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

function Find-ArmToolchain {
    $colors = Get-Colors
    Write-Host "  $($icons.Search) Searching for ARM toolchain..." -ForegroundColor $colors.Info
    
    # Check if arm-none-eabi-gcc is in PATH
    $armGcc = Get-Command "arm-none-eabi-gcc" -ErrorAction SilentlyContinue
    if ($armGcc) {
        Write-Host "    $($icons.Success) Found at $($armGcc.Source)" -ForegroundColor $colors.Success
        return $armGcc.Source
    }
    
    # Search common installation paths
    $commonPaths = @(
        # New Arm GNU Toolchain format (mingw-w64-i686)
        "C:\Program Files (x86)\Arm\GNU Toolchain mingw-w64-i686-arm-none-eabi\bin\arm-none-eabi-gcc.exe",
        "C:\Program Files\Arm\GNU Toolchain mingw-w64-i686-arm-none-eabi\bin\arm-none-eabi-gcc.exe",
        "${env:ProgramFiles(x86)}\Arm\GNU Toolchain mingw-w64-i686-arm-none-eabi\bin\arm-none-eabi-gcc.exe",
        "${env:ProgramFiles}\Arm\GNU Toolchain mingw-w64-i686-arm-none-eabi\bin\arm-none-eabi-gcc.exe",
        "D:\Arm\GNU Toolchain mingw-w64-i686-arm-none-eabi\bin\arm-none-eabi-gcc.exe",
        "E:\Arm\GNU Toolchain mingw-w64-i686-arm-none-eabi\bin\arm-none-eabi-gcc.exe",
        # Legacy GNU Arm Embedded Toolchain
        "C:\Program Files\GNU Arm Embedded Toolchain\*\bin\arm-none-eabi-gcc.exe",
        "C:\Program Files (x86)\GNU Arm Embedded Toolchain\*\bin\arm-none-eabi-gcc.exe",
        "${env:ProgramFiles}\Arm GNU Toolchain\*\bin\arm-none-eabi-gcc.exe",
        "${env:ProgramFiles(x86)}\Arm GNU Toolchain\*\bin\arm-none-eabi-gcc.exe",
        "${env:LOCALAPPDATA}\Programs\Arm GNU Toolchain\*\bin\arm-none-eabi-gcc.exe",
        "D:\Program Files\GNU Arm Embedded Toolchain\*\bin\arm-none-eabi-gcc.exe",
        "E:\Program Files\GNU Arm Embedded Toolchain\*\bin\arm-none-eabi-gcc.exe"
    )
    
    foreach ($pattern in $commonPaths) {
        try {
            $found = Get-ChildItem $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                Write-Host "    $($icons.Success) Found at $($found.FullName)" -ForegroundColor $colors.Success
                return $found.FullName
            }
        } catch {}
    }
    
    return $null
}

function Build-ForDevice {
    param(
        [string]$SDKPath,
        [string]$SourceDir,
        [string]$BuildDir,
        [string]$Config,
        [string]$ProjectName
    )
    
    $colors = Get-Colors
    Write-Step "Building for Playdate Device"
    
    # Check for CMake
    $cmake = Get-Command "cmake" -ErrorAction SilentlyContinue
    if (-not $cmake) {
        Write-ErrorMsg "CMake not found!"
        Write-Info "Device builds require CMake."
        Write-Info "Please install CMake from: https://cmake.org/download/"
        Write-Info "Make sure to add it to your PATH during installation."
        exit 1
    }
    Write-Success "CMake found: $($cmake.Source)"
    
    # Find ARM toolchain
    $armGccPath = Find-ArmToolchain
    if (-not $armGccPath) {
        Write-ErrorMsg "ARM toolchain not found!"
        Write-Info "Please install gcc-arm-none-eabi from https://developer.arm.com"
        Write-Info "Make sure to add it to your PATH during installation."
        exit 1
    }
    
    # Get toolchain directory
    $armToolchainDir = Split-Path -Parent $armGccPath
    
    # Check for arm.cmake
    $armCmakePath = Join-Path $SDKPath "C_API\buildsupport\arm.cmake"
    if (-not (Test-Path $armCmakePath)) {
        Write-ErrorMsg "ARM toolchain file not found at: $armCmakePath"
        exit 1
    }
    
    Write-Success "ARM toolchain ready"
    
    # Create CMakeLists.txt if it doesn't exist
    $cmakeListsPath = Join-Path (Get-ScriptDirectory) "CMakeLists.txt"
    if (-not (Test-Path $cmakeListsPath)) {
        Write-Info "Creating CMakeLists.txt for device build..."
        $cmakeContent = @"
cmake_minimum_required(VERSION 3.14)
set(CMAKE_C_STANDARD 11)

set(ENVSDK `$ENV{PLAYDATE_SDK_PATH})
if (NOT `${ENVSDK} STREQUAL "")
    file(TO_CMAKE_PATH `${ENVSDK} SDK)
else()
    message(FATAL_ERROR "SDK Path not found; set ENV value PLAYDATE_SDK_PATH")
endif()

set(CMAKE_CONFIGURATION_TYPES "Debug;Release")
set(PLAYDATE_GAME_NAME $ProjectName)
project(`${PLAYDATE_GAME_NAME} C ASM)

add_library(`${PLAYDATE_GAME_NAME} SHARED src/main.c)
include(`${SDK}/C_API/buildsupport/playdate_game.cmake)
"@
        Set-Content -Path $cmakeListsPath -Value $cmakeContent
    }
    
    # Create build directory
    $deviceBuildDir = Join-Path $BuildDir "device_$Config"
    if (-not (Test-Path $deviceBuildDir)) {
        New-Item -ItemType Directory -Path $deviceBuildDir -Force | Out-Null
    }
    
    # Run CMake with ARM toolchain
    Write-Info "Configuring CMake for ARM toolchain..."
    $cmakeCmd = "cmake -G `"NMake Makefiles`" -DCMAKE_TOOLCHAIN_FILE=`"$armCmakePath`" -DCMAKE_BUILD_TYPE=$Config .."
    Push-Location $deviceBuildDir
    $result = Invoke-Expression $cmakeCmd 2>&1
    Pop-Location
    
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "CMake configuration failed!"
        Write-Host "$result" -ForegroundColor Red
        exit 1
    }
    
    Write-Success "CMake configured"
    
    # Build with NMake
    Write-Info "Building for device..."
    Push-Location $deviceBuildDir
    $result = nmake 2>&1
    Pop-Location
    
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Device build failed!"
        Write-Host "$result" -ForegroundColor Red
        exit 1
    }
    
    Write-Success "Device build complete!"
    
    # Copy pdex.bin to output
    $binFile = Join-Path $deviceBuildDir "$ProjectName.pdx\pdex.bin"
    if (Test-Path $binFile) {
        Write-Success "Created pdex.bin for device"
        return $binFile
    } else {
        Write-ErrorMsg "pdex.bin not found after build!"
        exit 1
    }
}

# --- INITIALIZATION ---
Clear-Host
Show-AsciiArt

$scriptDir = Get-ScriptDirectory
$projectConfig = Get-Configuration

$PROJECT_NAME = Resolve-ProjectName -ProvidedName $Name -Config $projectConfig
$SDK_PATH = Resolve-SDKPath -ProvidedPath $SDKPath
$SOURCE_DIR = "src"
$BUILD_DIR = "build"
$OUTPUT_DIR = "."

# Display build configuration
$targetInfo = if ($Target -eq "Device") { "Playdate Device (ARM)" } else { "Simulator (x64)" }
$configInfo = "$Config Mode"
Speak-Message "Building '$PROJECT_NAME' for $targetInfo ($configInfo)" "Step"

# Calculate total stages
$currentStage = 1
$totalStages = 4
if ($Clean) { $totalStages++ }
if ($Run -and $Target -eq "Simulator") { $totalStages++ }

# --- STAGE: CHECKS ---
Start-Level "Checking Blueprints" $currentStage $totalStages
$currentStage++

if (-not $SDK_PATH) {
    Write-ErrorMsg "Playdate SDK not found!  (找不到 Playdate SDK)"
    Write-Host ""
    Write-Info "Most likely fixes:"
    Write-Info "  1. Run  .\setup.ps1           # auto-detect + set PLAYDATE_SDK_PATH"
    Write-Info "  2. Or install the SDK from    https://play.date/dev/"
    Write-Info "  3. Or pass it explicitly:     .\build.ps1 -SDKPath 'C:\path\to\PlaydateSDK'"
    exit 1
}
Write-Success "SDK found at $SDK_PATH"

# Check tools based on target
if ($Target -eq "Simulator") {
    $vcvarsPath = Get-VisualStudioPath -ConfigPath $projectConfig.visualStudioPath
    
    if ($vcvarsPath) {
        Write-Success "Visual Studio environment found"
        if (-not (Import-VisualStudioEnv -VcVarsPath $vcvarsPath)) {
            Write-ErrorMsg "Failed to initialize Visual Studio environment."
            Write-Info "Could not load environment from: $vcvarsPath"
            exit 1
        }
    } else {
        Write-ErrorMsg "Visual Studio C++ compiler is missing!  (找不到 MSVC 编译器)"
        Write-Host ""
        Write-Info "Install Visual Studio 2022 Community (free):"
        Write-Info "  https://visualstudio.microsoft.com/vs/community/"
        Write-Info ""
        Write-Info "During install, you MUST tick this workload:"
        Write-Info "  [x] Desktop development with C++"
        Write-Info ""
        Write-Info "Already installed?  Run  .\setup.ps1 -Mode check  to diagnose."
        exit 1
    }
} else {
    # Device build - will check ARM toolchain later
    Write-Info "Target: Playdate Device (will check ARM toolchain during build)"
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

# Branch based on target
if ($Target -eq "Device") {
    # Device build using CMake + ARM toolchain
    $binFile = Build-ForDevice -SDKPath $SDK_PATH -SourceDir $SOURCE_DIR -BuildDir $BUILD_DIR -Config $Config -ProjectName $PROJECT_NAME
    $currentStage++
    
    # Package device build
    Start-Level "Wrapping the Gift" $currentStage $totalStages
    $currentStage++
    
    $pdcPath = "$SDK_PATH\bin\pdc.exe"
    if (-not (Test-Path $pdcPath)) { Write-ErrorMsg "pdc.exe missing!"; exit 1 }
    
    $tempDir = "$BUILD_DIR\temp_device_game"
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    
    # Copy pdex.bin
    Copy-Item $binFile "$tempDir\pdex.bin"
    
    # Create pdxinfo
    $author = if ($projectConfig -and $projectConfig.author) { $projectConfig.author } else { "Developer" }
    $description = if ($projectConfig -and $projectConfig.description) { $projectConfig.description } else { "My Playdate Game" }
    $bundleID = if ($projectConfig -and $projectConfig.bundleID) { $projectConfig.bundleID } else { "com.example.$PROJECT_NAME" }
    
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
    Write-Success "Created device package: $PROJECT_NAME.pdx"
    
    # Device builds can't run in simulator
    if ($Run) {
        Write-Warning "Device builds cannot run in simulator."
        Write-Info "Upload your .pdx to a real Playdate device to test."
    } else {
        Speak-Message "Device build complete! Upload to Playdate to test." "Success"
    }
    
    $elapsedTime = New-TimeSpan -Start $script:StartTime -End (Get-Date)
    Write-Info "Total time: $($elapsedTime.ToString("mm\:ss"))"
    exit 0
}

# Simulator build
if (-not (Test-Path $BUILD_DIR)) { New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null }

$sourceFiles = Get-ChildItem -Path $SOURCE_DIR -Filter *.c -Recurse | ForEach-Object { $_.FullName }

if ($sourceFiles.Count -eq 0) {
    Write-Warning "I didn't find any .c files in '$SOURCE_DIR'!"
    Write-Info "Write some code first, then come back."
    exit 1
}

Write-Info "Found $($sourceFiles.Count) source file(s)."

# Set compiler flags based on config
$compilerFlags = "/c /nologo /W3 /MD /MP"
if ($Config -eq "Debug") {
    $compilerFlags += " /Z7 /Od"
    $defines = "/DTARGET_PLAYDATE=1 /DTARGET_EXTENSION=1 /DTARGET_SIMULATOR=1 /D_WINDLL /DDEBUG=1"
} else {
    $compilerFlags += " /O2"
    $defines = "/DTARGET_PLAYDATE=1 /DTARGET_EXTENSION=1 /DTARGET_SIMULATOR=1 /D_WINDLL /DNDEBUG=1"
}

$includes = "/I`"$SDK_PATH\C_API`""

# OPTIMIZATION: Compile all files in one go to leverage /MP (Parallel Build)
Write-Host "  $($icons.Code) Compiling $($sourceFiles.Count) files ($Config)..." -ForegroundColor Gray

# Wrap paths in quotes
$quotedSourceFiles = $sourceFiles | ForEach-Object { "`"$_`"" }
$allSources = $quotedSourceFiles -join " "

# Ensure build dir has trailing slash for /Fo
$outputDirParam = "/Fo`"$BUILD_DIR\`""

# Execute cl directly (environment is already loaded)
$compileCmd = "cl $compilerFlags $defines $includes $allSources $outputDirParam"
$result = Invoke-Expression $compileCmd 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Compilation failed!  (编译失败)"
    Write-Host ""
    Write-Host "$result" -ForegroundColor Red
    Write-Host ""
    # Friendly diagnosis for the most common mistakes
    $text = ($result | Out-String)
    if ($text -match 'Cannot open include file.*pd_api\.h') {
        Write-Info "Likely cause : SDK include path is wrong or PLAYDATE_SDK_PATH is stale."
        Write-Info "Fix          : Re-run  .\setup.ps1   (it will refresh the config)"
    } elseif ($text -match 'cl.*is not recognized|is not recognized as') {
        Write-Info "Likely cause : Visual Studio environment failed to initialize."
        Write-Info "Fix          : Close this window, open a fresh PowerShell, retry."
    } elseif ($text -match 'error C\d+') {
        Write-Info "Looks like a source code error - check messages above for file:line."
        Write-Info "Tip          : The first  error C####  line usually points at the real bug."
    } else {
        Write-Info "See logs\ folder for the full output, or run  .\setup.ps1 -Mode check"
    }
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

# Set linker flags based on config
$linkerFlags = "/DLL /NOLOGO /INCREMENTAL:NO /EXPORT:eventHandler"
if ($Config -eq "Debug") {
    $linkerFlags += " /DEBUG"
}

Write-Host "  $($icons.Link) Linking ($Config)..." -ForegroundColor Gray

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

if ($projectConfig) {
    if ($projectConfig.author) { $author = $projectConfig.author }
    if ($projectConfig.description) { $description = $projectConfig.description }
    if ($projectConfig.bundleID) { $bundleID = $projectConfig.bundleID }
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
        Speak-Message "Simulator launched. Have fun!  模拟器已启动，祗你玩得愉快！" "Success"
    } else {
        Write-ErrorMsg "Simulator not found at $simulatorPath"
    }
} else {
    Speak-Message "Build complete!  Run  .\build.ps1 -Run  to play." "Success"
}

$elapsedTime = New-TimeSpan -Start $script:StartTime -End (Get-Date)
$absPdx = Resolve-Path $outputPdx -ErrorAction SilentlyContinue
$pdxDisplay = if ($absPdx) { $absPdx.Path } else { $outputPdx }
Write-Host ""
Write-Info ("Output : {0}" -f $pdxDisplay)
Write-Info ("Time   : {0}" -f $elapsedTime.ToString("mm\:ss"))
