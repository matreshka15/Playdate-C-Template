# ========================================
# 🎮 Playdate C Game Development Setup Wizard
# ========================================
# This friendly wizard will help you set up everything you need!
#
# Usage: .\setup.ps1

param(
    [switch]$SkipChecks,
    [switch]$QuickStart
)

$ErrorActionPreference = "Continue"

# Pretty output functions 🎨
function Write-Title { param($msg) Write-Host "`n$msg" -ForegroundColor Cyan -BackgroundColor DarkBlue }
function Write-Step { param($msg) Write-Host "`n► $msg" -ForegroundColor Yellow }
function Write-Success { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Error { param($msg) Write-Host "  ✗ $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "  ℹ $msg" -ForegroundColor Cyan }
function Write-Warning { param($msg) Write-Host "  ⚠ $msg" -ForegroundColor Yellow }

function Read-Confirmation {
    param($prompt)
    $response = Read-Host "$prompt (Y/N)"
    return $response -match '^[Yy]'
}

function Wait-UserInput {
    Write-Host "`nPress any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ========================================
# Welcome! 🎉
# ========================================
Clear-Host
Write-Title "═══════════════════════════════════════════════════════════"
Write-Host "      🎮 Playdate C Game Development Setup Wizard" -ForegroundColor White
Write-Title "═══════════════════════════════════════════════════════════"

Write-Host @"

Welcome! This wizard will help you:

  1. ✅ Check your system for required tools
  2. ✅ Set up Playdate SDK environment variables
  3. ✅ Verify Visual Studio installation
  4. ✅ Build and run the demo game
  5. ✅ Configure VS Code (if installed)

Estimated time: 5-10 minutes ⏱️

"@ -ForegroundColor White

if (-not $QuickStart) {
    Wait-UserInput
}

# ========================================
# Step 1: Check Environment 🔍
# ========================================
$checks = @{
    SDK = $false
    VS = $false
    VSCode = $false
    EnvVar = $false
}

Write-Title "Step 1/5: Checking Your System 🔍"

# Check Playdate SDK
Write-Step "Looking for Playdate SDK..."
$sdkPath = $env:PLAYDATE_SDK_PATH
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$detectedSdkPath = (Get-Item $scriptDir).Parent.Parent.FullName

if ($sdkPath -and (Test-Path "$sdkPath\bin\pdc.exe")) {
    Write-Success "Found Playdate SDK: $sdkPath"
    $checks.SDK = $true
    $checks.EnvVar = $true
} elseif (Test-Path "$detectedSdkPath\bin\pdc.exe") {
    Write-Warning "SDK installed but environment variable not set"
    Write-Info "Detected SDK path: $detectedSdkPath"
    $sdkPath = $detectedSdkPath
    $checks.SDK = $true
} else {
    Write-Error "Playdate SDK not found"
    Write-Info "Download it from: https://play.date/dev/"
    $sdkPath = Read-Host "`nPlease enter your Playdate SDK path (or Ctrl+C to exit)"
    if (Test-Path "$sdkPath\bin\pdc.exe") {
        Write-Success "Verified: $sdkPath"
        $checks.SDK = $true
    } else {
        Write-Error "Invalid SDK path. Please run the wizard again."
        exit 1
    }
}

# Check Visual Studio
Write-Step "Looking for Visual Studio 2022..."
$vsPath = "C:\Program Files\Microsoft Visual Studio\2022"
$vcvarsPath = $null
$vsEdition = $null

foreach ($edition in @("Enterprise", "Professional", "Community")) {
    $testPath = "$vsPath\$edition\VC\Auxiliary\Build\vcvars64.bat"
    if (Test-Path $testPath) {
        $vcvarsPath = $testPath
        $vsEdition = $edition
        Write-Success "Found Visual Studio 2022 $edition"
        $checks.VS = $true
        break
    }
}

if (-not $checks.VS) {
    Write-Error "Visual Studio 2022 not found"
    Write-Info "Download Visual Studio 2022 Community (free!):"
    Write-Info "→ https://visualstudio.microsoft.com/downloads/"
    Write-Info ""
    Write-Info "During installation, select:"
    Write-Info "  • Desktop development with C++"
    Write-Info "  • Windows 10/11 SDK"
    
    if (Read-Confirmation "`nDo you have VS installed in a custom location?") {
        $customPath = Read-Host "Enter full path to vcvars64.bat"
        if (Test-Path $customPath) {
            $vcvarsPath = $customPath
            $checks.VS = $true
            Write-Success "Verified!"
        }
    }
    
    if (-not $checks.VS) {
        Write-Warning "Without Visual Studio, you can't compile C code."
        if (-not (Read-Confirmation "Continue anyway?")) {
            exit 1
        }
    }
}

# Check VS Code
Write-Step "Looking for Visual Studio Code..."
$vscodeCmd = Get-Command code -ErrorAction SilentlyContinue
if ($vscodeCmd) {
    Write-Success "Found VS Code: $($vscodeCmd.Source)"
    $checks.VSCode = $true
} else {
    Write-Warning "VS Code not found"
    Write-Info "Download from: https://code.visualstudio.com/"
    Write-Info "(VS Code is optional but makes development easier!)"
}

# ========================================
# Step 2: Set Environment Variables 🔧
# ========================================
Write-Title "Step 2/5: Setting Up Environment Variables 🔧"

if (-not $checks.EnvVar) {
    Write-Step "Setting PLAYDATE_SDK_PATH..."
    Write-Info "Current SDK path: $sdkPath"
    
    if (Read-Confirmation "Set as system environment variable? (requires admin)") {
        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            
            if ($isAdmin) {
                [Environment]::SetEnvironmentVariable("PLAYDATE_SDK_PATH", $sdkPath, "Machine")
                
                $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
                $binPath = "$sdkPath\bin"
                if ($currentPath -notlike "*$binPath*") {
                    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$binPath", "Machine")
                    Write-Success "Environment variables set! (restart terminal to take effect)"
                } else {
                    Write-Success "Environment variables already set!"
                }
                $checks.EnvVar = $true
            } else {
                Write-Warning "Admin rights required to set system variables"
                Write-Info "Restarting with admin privileges..."
                
                $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
                Start-Process powershell -Verb RunAs -ArgumentList $arguments
                exit
            }
        } catch {
            Write-Error "Failed to set environment variable: $_"
        }
    } else {
        Write-Info "Setting for current session only"
        $env:PLAYDATE_SDK_PATH = $sdkPath
        $env:Path = "$env:Path;$sdkPath\bin"
        Write-Success "Temporary environment variable set"
    }
} else {
    Write-Success "Environment variables already configured"
}

# ========================================
# Step 3: Verify Tools 🛠️
# ========================================
Write-Title "Step 3/5: Verifying Tools 🛠️"

Write-Step "Testing Playdate Compiler (pdc)..."
try {
    $pdcVersion = & "$sdkPath\bin\pdc.exe" --version 2>&1
    Write-Success "pdc version: $pdcVersion"
} catch {
    Write-Error "pdc failed to run: $_"
}

if ($checks.VS) {
    Write-Step "Testing Visual Studio compiler..."
    $testBatch = @"
@echo off
call "$vcvarsPath" >nul 2>&1
cl /? >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo OK
) else (
    echo FAIL
)
"@
    $testFile = "$env:TEMP\test_cl.bat"
    Set-Content -Path $testFile -Value $testBatch
    $result = & cmd /c $testFile 2>&1
    Remove-Item $testFile -ErrorAction SilentlyContinue
    
    if ($result -match "OK") {
        Write-Success "Visual Studio compiler ready!"
    } else {
        Write-Warning "Visual Studio compiler test failed"
    }
}

# ========================================
# Step 4: Build Demo Game 🎮
# ========================================
Write-Title "Step 4/5: Building Demo Game 🎮"

Write-Info "Project path: $scriptDir"
Write-Info "Game name: MyPlaydateGame"

if ($checks.VS) {
    if (Read-Confirmation "`nBuild the demo game now?") {
        Write-Step "Building..."
        
        $env:PLAYDATE_SDK_PATH = $sdkPath
        
        $buildScript = Join-Path $scriptDir "build.ps1"
        if (Test-Path $buildScript) {
            & $buildScript -Clean
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Build successful! 🎉"
                
                if (Read-Confirmation "`nRun the game now?") {
                    Write-Step "Starting Playdate Simulator..."
                    $pdxPath = Join-Path $scriptDir "MyPlaydateGame.pdx"
                    if (Test-Path $pdxPath) {
                        Start-Process "$sdkPath\bin\PlaydateSimulator.exe" -ArgumentList "`"$pdxPath`""
                        Write-Success "Simulator started! 🎮"
                        Write-Info "You should see a bouncing text animation!"
                    }
                }
            } else {
                Write-Error "Build failed 😢"
            }
        } else {
            Write-Error "build.ps1 not found"
        }
    }
} else {
    Write-Warning "Skipping build (Visual Studio not found)"
}

# ========================================
# Step 5: Configure VS Code 💻
# ========================================
Write-Title "Step 5/5: VS Code Configuration 💻"

if ($checks.VSCode) {
    Write-Step "Configuring VS Code..."
    
    $settingsPath = Join-Path $scriptDir ".vscode\settings.json"
    if (Test-Path $settingsPath) {
        try {
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            if ($settings.'terminal.integrated.env.windows') {
                $settings.'terminal.integrated.env.windows'.PLAYDATE_SDK_PATH = $sdkPath
            }
            $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath
            Write-Success "VS Code configured!"
        } catch {
            Write-Warning "Could not update VS Code settings: $_"
        }
    }
    
    Write-Info "VS Code keyboard shortcuts:"
    Write-Host "    F5            - Run game" -ForegroundColor Gray
    Write-Host "    Ctrl+Shift+B  - Build" -ForegroundColor Gray
    Write-Host "    Ctrl+Shift+P  - Command palette" -ForegroundColor Gray
    
    if (Read-Confirmation "`nOpen project in VS Code now?") {
        Set-Location $scriptDir
        & code .
        Write-Success "VS Code launched!"
    }
} else {
    Write-Info "Install VS Code for a better development experience!"
    Write-Info "Download: https://code.visualstudio.com/"
}

# ========================================
# Summary 📊
# ========================================
Write-Title "═══════════════════════════════════════════════════════════"
Write-Host "                  Setup Complete! 🎉" -ForegroundColor Green
Write-Title "═══════════════════════════════════════════════════════════"

Write-Host "`nEnvironment Check:" -ForegroundColor White
Write-Host "  Playdate SDK:      " -NoNewline
if ($checks.SDK) { Write-Host "✓" -ForegroundColor Green } else { Write-Host "✗" -ForegroundColor Red }

Write-Host "  Environment Vars:  " -NoNewline
if ($checks.EnvVar) { Write-Host "✓" -ForegroundColor Green } else { Write-Host "✗" -ForegroundColor Red }

Write-Host "  Visual Studio:     " -NoNewline
if ($checks.VS) { Write-Host "✓" -ForegroundColor Green } else { Write-Host "✗" -ForegroundColor Red }

Write-Host "  VS Code:           " -NoNewline
if ($checks.VSCode) { Write-Host "✓" -ForegroundColor Green } else { Write-Host "✗" -ForegroundColor Red }

Write-Host "`nQuick Start Commands:" -ForegroundColor White
Write-Host "  Build and run:     " -NoNewline -ForegroundColor Gray
Write-Host ".\build.ps1 -Run" -ForegroundColor Cyan

Write-Host "  Just build:        " -NoNewline -ForegroundColor Gray
Write-Host ".\build.ps1" -ForegroundColor Cyan

Write-Host "  Clean:             " -NoNewline -ForegroundColor Gray
Write-Host ".\build.ps1 -Clean" -ForegroundColor Cyan

Write-Host "  Open in VS Code:   " -NoNewline -ForegroundColor Gray
Write-Host "code ." -ForegroundColor Cyan

Write-Host "`nNext Steps:" -ForegroundColor White
Write-Host "  1. Read GETTING_STARTED.md to learn Playdate C basics" -ForegroundColor Gray
Write-Host "  2. Edit src/main.c to make your own game" -ForegroundColor Gray
Write-Host "  3. Run .\build.ps1 -Run to test your changes" -ForegroundColor Gray
Write-Host "  4. Have fun making games! 🎮" -ForegroundColor Gray

Write-Host "`nNeed Help?" -ForegroundColor White
Write-Host "  • Read GETTING_STARTED.md - Learn the basics" -ForegroundColor Gray
Write-Host "  • Visit https://devforum.play.date/ - Friendly community!" -ForegroundColor Gray
Write-Host "  • Check SDK examples: $sdkPath\C_API\Examples\" -ForegroundColor Gray

Write-Host "`nHappy game making! 🚀✨" -ForegroundColor Yellow
Write-Host ""
