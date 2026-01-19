#!/usr/bin/env pwsh
#
# Playdate C Template - Automated Test Runner
# Usage: .\test.ps1 [-All] [-Unit] [-Integration] [-Functional] [-Performance] [-Verbose]
#

param(
    [switch]$All,
    [switch]$Unit,
    [switch]$Integration,
    [switch]$Functional,
    [switch]$Performance,
    [switch]$Verbose,
    [switch]$Quick
)

$ErrorActionPreference = "Continue"
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0
$script:TestResults = @()
$script:StartTime = Get-Date

$colors = @{
    Title = [System.ConsoleColor]::Cyan
    Success = [System.ConsoleColor]::Green
    Error = [System.ConsoleColor]::Red
    Info = [System.ConsoleColor]::Gray
    Warning = [System.ConsoleColor]::Yellow
}

function Write-Title {
    param([string]$Message)
    Write-Host "`n$Message" -ForegroundColor $colors.Title -BackgroundColor DarkBlue
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor $colors.Success
}

function Write-Error-Message {
    param([string]$Message)
    Write-Host "  ✗ $Message" -ForegroundColor $colors.Error
}

function Write-Info {
    param([string]$Message)
    Write-Host "  ℹ $Message" -ForegroundColor $colors.Info
}

function Write-Warning {
    param([string]$Message)
    Write-Host "  ⚠ $Message" -ForegroundColor $colors.Warning
}

function Record-Test {
    param(
        [string]$TestID,
        [string]$TestName,
        [string]$Category,
        [string]$Expected,
        [string]$Actual,
        [bool]$Passed
    )

    $result = @{
        ID = $TestID
        Name = $TestName
        Category = $Category
        Expected = $Expected
        Actual = $Actual
        Passed = $Passed
        Time = (Get-Date)
    }
    $script:TestResults += $result

    if ($Passed) {
        $script:TestsPassed++
        Write-Success "$TestID: $TestName"
    } else {
        $script:TestsFailed++
        Write-Error-Message "$TestID: $TestName"
        if ($Verbose) {
            Write-Info "  Expected: $Expected"
            Write-Info "  Actual: $Actual"
        }
    }
}

function Test-FileExists {
    param([string]$Path, [string]$TestID, [string]$TestName, [string]$Category)
    $exists = Test-Path $Path
    Record-Test -TestID $TestID -TestName $TestName -Category $Category `
        -Expected "File exists" -Actual $(if ($exists) { "File exists" } else { "File not found" }) -Passed $exists
    return $exists
}

function Test-FileNotEmpty {
    param([string]$Path, [string]$TestID, [string]$TestName, [string]$Category)
    if (-not (Test-Path $Path)) {
        Record-Test -TestID $TestID -TestName $TestName -Category $Category `
            -Expected "File not empty" -Actual "File not found" -Passed $false
        return $false
    }
    $content = Get-Content $Path -Raw
    $notEmpty = -not [string]::IsNullOrWhiteSpace($content)
    Record-Test -TestID $TestID -TestName $TestName -Category $Category `
        -Expected "File not empty" -Actual $(if ($notEmpty) { "File has content" } else { "File is empty" }) -Passed $notEmpty
    return $notEmpty
}

function Test-ValidJson {
    param([string]$Path, [string]$TestID, [string]$TestName, [string]$Category)
    if (-not (Test-Path $Path)) {
        Record-Test -TestID $TestID -TestName $TestName -Category $Category `
            -Expected "Valid JSON" -Actual "File not found" -Passed $false
        return $false
    }
    try {
        $content = Get-Content $Path -Raw | ConvertFrom-Json
        Record-Test -TestID $TestID -TestName $TestName -Category $Category `
            -Expected "Valid JSON" -Actual "Valid JSON" -Passed $true
        return $true
    } catch {
        Record-Test -TestID $TestID -TestName $TestName -Category $Category `
            -Expected "Valid JSON" -Actual "Invalid JSON" -Passed $false
        return $false
    }
}

function Test-JsonField {
    param(
        [string]$Path,
        [string]$Field,
        [string]$TestID,
        [string]$TestName,
        [string]$Category
    )
    if (-not (Test-Path $Path)) {
        Record-Test -TestID $TestID -TestName $TestName -Category $Category `
            -Expected "Field exists: $Field" -Actual "File not found" -Passed $false
        return $false
    }
    try {
        $content = Get-Content $Path -Raw | ConvertFrom-Json
        $hasField = $null -ne $content.$Field
        Record-Test -TestID $TestID -TestName $TestName -Category $Category `
            -Expected "Field exists: $Field" -Actual $(if ($hasField) { "Field exists" } else { "Field missing" }) -Passed $hasField
        return $hasField
    } catch {
        Record-Test -TestID $TestID -TestName $TestName -Category $Category `
            -Expected "Field exists: $Field" -Actual "Parse error" -Passed $false
        return $false
    }
}

function Test-ParameterDefinition {
    param([string]$File, [string]$Param, [string]$TestID, [string]$TestName, [string]$Category)
    $content = Get-Content $File -Raw
    $hasParam = $content -match "\[Parameter\]\s*$Param" -or $content -match "`$$Param"
    Record-Test -TestID $TestID -TestName $TestName -Category $Category `
        -Expected "Parameter defined: $Param" -Actual $(if ($hasParam) { "Parameter found" } else { "Parameter missing" }) -Passed $hasParam
    return $hasParam
}

function Test-EnvironmentVariable {
    param([string]$Variable, [string]$TestID, [string]$TestName, [string]$Category)
    $value = [Environment]::GetEnvironmentVariable($Variable)
    $exists = -not [string]::IsNullOrEmpty($value)
    Record-Test -TestID $TestID -TestName $TestName -Category $Category `
        -Expected "Variable set: $Variable" -Actual $(if ($exists) { "Value: $value" } else { "Not set" }) -Passed $exists
    return $exists
}

function Test-FunctionDefinition {
    param([string]$File, [string]$Function, [string]$TestID, [string]$TestName, [string]$Category)
    $content = Get-Content $File -Raw
    $hasFunction = $content -match "function\s+$Function\s*\{"
    Record-Test -TestID $TestID -TestName $TestName -Category $Category `
        -Expected "Function defined: $Function" -Actual $(if ($hasFunction) { "Function found" } else { "Function missing" }) -Passed $hasFunction
    return $hasFunction
}

function Test-RegexMatch {
    param(
        [string]$File,
        [string]$Pattern,
        [string]$TestID,
        [string]$TestName,
        [string]$Category
    )
    $content = Get-Content $File -Raw
    $matches = $content -match $Pattern
    Record-Test -TestID $TestID -TestName $TestName -Category $Category `
        -Expected "Pattern found: $Pattern" -Actual $(if ($matches) { "Pattern matched" } else { "Pattern not found" }) -Passed $matches
    return $matches
}

function Test-NoHardcodedPaths {
    param([string]$File, [string]$TestID, [string]$TestName, [string]$Category)
    $content = Get-Content $File -Raw
    $hardcodedPaths = $content -match '[a-zA-Z]:\\[^\s"]+'
    $hasHardcoded = $null -ne $hardcodedPaths
    Record-Test -TestID $TestID -TestName $TestName -Category $Category `
        -Expected "No hardcoded paths" -Actual $(if ($hasHardcoded) { "Hardcoded paths found" } else { "No hardcoded paths" }) -Passed (-not $hasHardcoded)
    return (-not $hasHardcoded)
}

function Run-UnitTests {
    Write-Title "Unit Tests"

    $testDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $projectDir = Split-Path -Parent $testDir

    Test-FileExists -Path "$projectDir\setup.ps1" -TestID "UT-001" -TestName "setup.ps1 exists" -Category "Unit"
    Test-FileExists -Path "$projectDir\build.ps1" -TestID "UT-002" -TestName "build.ps1 exists" -Category "Unit"
    Test-FileExists -Path "$projectDir\src\main.c" -TestID "UT-003" -TestName "main.c exists" -Category "Unit"
    Test-FileExists -Path "$projectDir\setup-config.json" -TestID "UT-004" -TestName "setup-config.json exists" -Category "Unit"

    Test-FileNotEmpty -Path "$projectDir\setup.ps1" -TestID "UT-005" -TestName "setup.ps1 not empty" -Category "Unit"
    Test-FileNotEmpty -Path "$projectDir\build.ps1" -TestID "UT-006" -TestName "build.ps1 not empty" -Category "Unit"
    Test-FileNotEmpty -Path "$projectDir\src\main.c" -TestID "UT-007" -TestName "main.c not empty" -Category "Unit"

    Test-ValidJson -Path "$projectDir\setup-config.json" -TestID "UT-008" -TestName "setup-config.json valid JSON" -Category "Unit"

    Test-ParameterDefinition -File "$projectDir\setup.ps1" -Param "Mode" -TestID "UT-009" -TestName "setup.ps1 has Mode parameter" -Category "Unit"
    Test-ParameterDefinition -File "$projectDir\build.ps1" -Param "Clean" -TestID "UT-010" -TestName "build.ps1 has Clean parameter" -Category "Unit"
    Test-ParameterDefinition -File "$projectDir\build.ps1" -Param "Run" -TestID "UT-011" -TestName "build.ps1 has Run parameter" -Category "Unit"

    Test-FunctionDefinition -File "$projectDir\setup.ps1" -Function "Start-Main" -TestID "UT-012" -TestName "setup.ps1 has Start-Main function" -Category "Unit"
    Test-FunctionDefinition -File "$projectDir\build.ps1" -Function "Get-ScriptDirectory" -TestID "UT-013" -TestName "build.ps1 has Get-ScriptDirectory function" -Category "Unit"
}

function Run-IntegrationTests {
    Write-Title "Integration Tests"

    $testDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $projectDir = Split-Path -Parent $testDir

    Test-JsonField -Path "$projectDir\setup-config.json" -Field "projectName" -TestID "IT-001" -TestName "Config has projectName field" -Category "Integration"
    Test-JsonField -Path "$projectDir\setup-config.json" -Field "author" -TestID "IT-002" -TestName "Config has author field" -Category "Integration"
    Test-JsonField -Path "$projectDir\setup-config.json" -Field "sdkPath" -TestID "IT-003" -TestName "Config has sdkPath field" -Category "Integration"

    Test-FileExists -Path "$projectDir\.vscode\settings.json" -TestID "IT-004" -TestName "VS Code settings exist" -Category "Integration"
    Test-FileExists -Path "$projectDir\.vscode\launch.json" -TestID "IT-005" -TestName "VS Code launch config exist" -Category "Integration"
    Test-FileExists -Path "$projectDir\.vscode\tasks.json" -TestID "IT-006" -TestName "VS Code tasks exist" -Category "Integration"

    Test-RegexMatch -File "$projectDir\.vscode\settings.json" -Pattern "PLAYDATE_SDK_PATH" -TestID "IT-007" -TestName "VS Code has SDK path configured" -Category "Integration"
}

function Run-FunctionalTests {
    Write-Title "Functional Tests"

    $testDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $projectDir = Split-Path -Parent $testDir

    Test-NoHardcodedPaths -File "$projectDir\build.ps1" -TestID "FT-001" -TestName "build.ps1 has no hardcoded paths" -Category "Functional"
    Test-NoHardcodedPaths -File "$projectDir\.vscode\settings.json" -TestID "FT-002" -TestName "VS Code settings have no hardcoded paths" -Category "Functional"

    Test-RegexMatch -File "$projectDir\build.ps1" -Pattern "PLAYDATE_SDK_PATH" -TestID "FT-003" -TestName "build.ps1 reads SDK from environment" -Category "Functional"
    Test-RegexMatch -File "$projectDir\build.ps1" -Pattern "Get-Configuration" -TestID "FT-004" -TestName "build.ps1 supports configuration file" -Category "Functional"
    Test-RegexMatch -File "$projectDir\build.ps1" -Pattern "Resolve-SDKPath" -TestID "FT-005" -TestName "build.ps1 has SDK path resolution" -Category "Functional"

    Test-EnvironmentVariable -Variable "PLAYDATE_SDK_PATH" -TestID "FT-006" -TestName "PLAYDATE_SDK_PATH environment variable set" -Category "Functional"
}

function Run-PerformanceTests {
    Write-Title "Performance Tests"

    $testDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $projectDir = Split-Path -Parent $testDir

    Write-Info "Measuring script startup time..."
    $startTime = Get-Date
    $null = & "$projectDir\build.ps1" -? 2>&1 | Out-Null
    $elapsed = New-TimeSpan -Start $startTime -End (Get-Date)
    $startupTime = $elapsed.TotalMilliseconds

    if ($startupTime -lt 5000) {
        Record-Test -TestID "PT-001" -TestName "Script startup < 5s" -Category "Performance" `
            -Expected "< 5000ms" -Actual "$([int]$startupTime)ms" -Passed $true
    } else {
        Record-Test -TestID "PT-001" -TestName "Script startup < 5s" -Category "Performance" `
            -Expected "< 5000ms" -Actual "$([int]$startupTime)ms" -Passed $false
    }

    Write-Info "Checking configuration file size..."
    $configSize = (Get-Item "$projectDir\setup-config.json").Length
    if ($configSize -lt 1024) {
        Record-Test -TestID "PT-002" -TestName "Config file size < 1KB" -Category "Performance" `
            -Expected "< 1024 bytes" -Actual "$configSize bytes" -Passed $true
    } else {
        Record-Test -TestID "PT-002" -TestName "Config file size < 1KB" -Category "Performance" `
            -Expected "< 1024 bytes" -Actual "$configSize bytes" -Passed $false
    }
}

function Show-Summary {
    param([bool]$QuickMode)

    $elapsed = New-TimeSpan -Start $script:StartTime -End (Get-Date)
    $total = $script:TestsPassed + $script:TestsFailed

    Write-Title "═══════════════════════════════════════════════════════════"
    Write-Host "                    Test Summary" -ForegroundColor White
    Write-Title "═══════════════════════════════════════════════════════════"

    Write-Host "`nTest Results:" -ForegroundColor White
    Write-Host "  Total Tests:  $total" -ForegroundColor Gray
    Write-Host "  Passed:       " -NoNewline -ForegroundColor Gray
    Write-Host "$script:TestsPassed" -ForegroundColor $colors.Success
    Write-Host "  Failed:       " -NoNewline -ForegroundColor Gray
    Write-Host "$script:TestsFailed" -ForegroundColor $colors.Error
    Write-Host "  Pass Rate:    " -NoNewline -ForegroundColor Gray
    $passRate = if ($total -gt 0) { [math]::Round(($script:TestsPassed / $total) * 100, 1) } else { 0 }
    Write-Host "$passRate%" -ForegroundColor $(if ($passRate -ge 80) { $colors.Success } else { $colors.Error })
    Write-Host "`nExecution Time: $($elapsed.TotalSeconds.ToString('F2'))s" -ForegroundColor White

    if (-not $QuickMode -and $script:TestResults.Count -gt 0) {
        Write-Host "`nFailed Tests:" -ForegroundColor White
        foreach ($result in $script:TestResults | Where-Object { -not $_.Passed }) {
            Write-Host "  ✗ $($result.ID): $($result.Name)" -ForegroundColor $colors.Error
            Write-Host "    Expected: $($result.Expected)" -ForegroundColor $colors.Info
            Write-Host "    Actual: $($result.Actual)" -ForegroundColor $colors.Info
        }
    }

    Write-Host "`n" -ForegroundColor White
    if ($script:TestsFailed -eq 0) {
        Write-Host "All tests passed! 🎉" -ForegroundColor $colors.Success
    } else {
        Write-Host "Some tests failed. Please review the results above." -ForegroundColor $colors.Error
    }
    Write-Host ""
}

function Start-TestRunner {
    Clear-Host

    Write-Title "═══════════════════════════════════════════════════════════"
    Write-Host "      🎮 Playdate C Template - Test Runner v1.0.0" -ForegroundColor White
    Write-Title "═══════════════════════════════════════════════════════════"

    Write-Host "`nThis test suite validates:" -ForegroundColor White
    Write-Host "  • File existence and structure" -ForegroundColor Gray
    Write-Host "  • Configuration validity" -ForegroundColor Gray
    Write-Host "  • Script functionality" -ForegroundColor Gray
    Write-Host "  • Performance metrics" -ForegroundColor Gray

    $runAll = $All -or (-not ($Unit -or $Integration -or $Functional -or $Performance))

    if ($runAll -or $Unit) { Run-UnitTests }
    if ($runAll -or $Integration) { Run-IntegrationTests }
    if ($runAll -or $Functional) { Run-FunctionalTests }
    if ($runAll -or $Performance) { Run-PerformanceTests }

    Show-Summary -QuickMode $Quick
}

Start-TestRunner
