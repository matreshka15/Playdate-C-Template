param(
    [ValidateSet('interactive', 'silent', 'repair', 'check', 'env', 'build', 'vscode')]
    [string]$Mode = 'interactive',
    [switch]$SkipEnvVar,
    [string]$LogFile = '',
    [string]$Config = '',
    [switch]$NoColor,
    [switch]$Verbose,
    [switch]$SkipChecks
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$script:Version = "2.0.0"
$script:StartTime = Get-Date
$script:LogFilePath = ''
$script:NoColorMode = $NoColor
$script:VerboseMode = $Verbose
$script:ExecutionMode = $Mode
$script:ChangesMade = @()
$script:DetectedSDKPath = ''

$script:LogFilePath = $LogFile
if (-not $script:LogFilePath) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:LogFilePath = Join-Path $PSScriptRoot "logs\setup_$timestamp.log"
}

$logDir = Split-Path $script:LogFilePath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Define icon system
function Get-Icons {
    return @{
        Success = "[OK]"  # success icon
        Error = "[FAIL]"    # error icon
        Warning = "[WARN]"   # warning icon
        Info = "[INFO]"      # info icon
        Step = "[STEP]"      # step icon
        Bullet = "*"     # bullet point
        Arrow = "->"     # arrow
        Check = "[?]"     # checkbox
        Play = "[PLAY]"      # play icon
        Code = "[CODE]"     # code icon
        Settings = "[SET]"  # settings icon
        Search = "[SEARCH]"    # search icon
        Git = "[GIT]"      # git icon
        Make = "[MAKE]"     # make icon
        VSCode = "[VSC]"    # vscode icon
        VS = "[VS]"       # visual studio icon
        SDK = "[SDK]"       # sdk icon
        Env = "[ENV]"       # environment icon
        Terminal = "[TERM]"   # terminal icon
    }
}

function Get-Colors {
    if ($script:NoColorMode) {
        return @{
            Title = [System.ConsoleColor]::White
            Step = [System.ConsoleColor]::Cyan
            Success = [System.ConsoleColor]::Green
            Error = [System.ConsoleColor]::Red
            Info = [System.ConsoleColor]::Gray
            Warning = [System.ConsoleColor]::Yellow
            Highlight = [System.ConsoleColor]::Magenta
            Border = [System.ConsoleColor]::White
            Text = [System.ConsoleColor]::White
        }
    }
    return @{
        Title = [System.ConsoleColor]::Cyan
        Step = [System.ConsoleColor]::Yellow
        Success = [System.ConsoleColor]::Green
        Error = [System.ConsoleColor]::Red
        Info = [System.ConsoleColor]::Gray
        Warning = [System.ConsoleColor]::DarkYellow
        Highlight = [System.ConsoleColor]::Magenta
        Border = [System.ConsoleColor]::Blue
        Text = [System.ConsoleColor]::White
    }
}

$icons = Get-Icons

function Log-Message {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    try {
        Add-Content -Path $script:LogFilePath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue | Out-Null
    } catch {}
    if ($Level -eq 'ERROR') { Write-Error $Message }
    elseif ($Level -eq 'WARN' -and -not $script:NoColorMode) { Write-Host "  $($icons.Warning) WARNING: $Message" -ForegroundColor (Get-Colors).Warning }
    elseif ($Level -eq 'DEBUG' -and $script:VerboseMode) { Write-Host "  $($icons.Search) DEBUG: $Message" -ForegroundColor (Get-Colors).Info }
}

Log-Message "INFO" "Playdate Setup Wizard v$script:Version started"
Log-Message "INFO" "Execution mode: $Mode"

function Write-Title {
    param([string]$Message)
    $colors = Get-Colors
    $border = "=" * 70
    Write-Host "`n$border" -ForegroundColor $colors.Border
    Write-Host " $Message" -ForegroundColor $colors.Title -BackgroundColor $colors.Border -NoNewline
    Write-Host " " -BackgroundColor $colors.Border
    Write-Host "$border" -ForegroundColor $colors.Border
}

function Write-Step {
    param([string]$Message, [int]$StepNumber, [int]$TotalSteps)
    $colors = Get-Colors
    $progress = "[$StepNumber/$TotalSteps]"
    Write-Host "`n$($icons.Step) $progress $Message" -ForegroundColor $colors.Step -BackgroundColor $colors.Border -NoNewline
    Write-Host " " -BackgroundColor $colors.Border
}

function Write-Success {
    param([string]$Message)
    $colors = Get-Colors
    Write-Host "  $($icons.Success) $Message" -ForegroundColor $colors.Success
}

function Write-ErrorMsg {
    param([string]$Message)
    $colors = Get-Colors
    Write-Host "  $($icons.Error) $Message" -ForegroundColor $colors.Error
}

function Write-Info {
    param([string]$Message)
    $colors = Get-Colors
    Write-Host "  $($icons.Info) $Message" -ForegroundColor $colors.Info
}

function Write-Warning {
    param([string]$Message)
    $colors = Get-Colors
    Log-Message "WARN" $Message
    Write-Host "  $($icons.Warning) $Message" -ForegroundColor $colors.Warning
}

function Read-Confirmation {
    param([string]$Prompt, [bool]$DefaultYes = $false, [string]$HelpText = "")
    if ($script:ExecutionMode -eq 'silent') { return $DefaultYes }

    $colors = Get-Colors
    $defaultText = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }

    if ($HelpText) {
        Write-Host "  $HelpText" -ForegroundColor $colors.Info
    }

    while ($true) {
        $response = Read-Host "`n$($icons.Check) $Prompt $defaultText"
        if ([string]::IsNullOrWhiteSpace($response)) { return $DefaultYes }
        $response = $response.ToLower().Trim()
        if ($response -eq 'y' -or $response -eq 'yes') { return $true }
        if ($response -eq 'n' -or $response -eq 'no') { return $false }
        Write-Host "  $($icons.Error) Invalid input. Please enter Y or N." -ForegroundColor $colors.Error
    }
}

function Show-Progress {
    param([string]$Message, [int]$Progress, [int]$Total)
    $colors = Get-Colors
    $barLength = 40
    $completedLength = [math]::Round(($Progress / $Total) * $barLength)
    $progressBar = "#" * $completedLength + "-" * ($barLength - $completedLength)
    $percent = [math]::Round(($Progress / $Total) * 100)
    Write-Host "`r  $Message [$progressBar] $percent%" -ForegroundColor $colors.Step -NoNewline
}

function Start-Animation {
    param([string]$Message, [int]$Duration = 2)
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

function Get-ScriptDirectory {
    if ($PSScriptRoot) { return $PSScriptRoot }
    return Split-Path -Parent $MyInvocation.MyCommand.Path
}

function Test-AdminRights {
    try {
        $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $windowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($windowsIdentity)
        return $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Test-SystemRequirements {
    param()

    $colors = Get-Colors
    $results = @{ Success = $true; Issues = @() }

    Write-Host "`n$($icons.Check) Checking system requirements..." -ForegroundColor $colors.Step

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        $results.Success = $false
        $results.Issues += "PowerShell version 5.0 or higher required (found $($psVersion.Major).$($psVersion.Minor))"
        Write-Host "  $($icons.Error) PowerShell version 5.0+ required" -ForegroundColor $colors.Error
    } else {
        Write-Host "  $($icons.Success) PowerShell $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor $colors.Success
    }

    # Check .NET Framework version
    try {
        $dotnetVersion = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Version
        if ($dotnetVersion -and [Version]$dotnetVersion -ge [Version]"4.7.2") {
            Write-Host "  $($icons.Success) .NET Framework $dotnetVersion" -ForegroundColor $colors.Success
        } else {
            $results.Success = $false
            $results.Issues += ".NET Framework 4.7.2 or higher required"
            Write-Host "  $($icons.Error) .NET Framework 4.7.2+ required" -ForegroundColor $colors.Error
        }
    } catch {
        Write-Host "  $($icons.Warning) Could not check .NET version" -ForegroundColor $colors.Warning
    }

    # Check Windows version
    $winVersion = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty Version
    $winBuild = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber
    Write-Host "  $($icons.Info) Windows $winVersion (Build $winBuild)" -ForegroundColor $colors.Info

    return $results
}

function Restore-Environment {
    Log-Message "INFO" "Starting environment restoration..."
    foreach ($change in $script:ChangesMade) {
        try {
            if ($change.Type -eq "EnvVar") {
                [Environment]::SetEnvironmentVariable($change.Name, $null, "Machine")
            }
            elseif ($change.Type -eq "EnvPath") {
                $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
                $newPath = $currentPath.Replace($change.Value, "")
                [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
            }
        } catch { $err = $_; Log-Message "ERROR" "Restore failed: $err" }
    }
    Write-Success "Environment restoration complete"
}

function Test-PlaydateSDK {
    param([string]$Path)
    $pdcPath = Join-Path $Path "bin\pdc.exe"
    if (Test-Path $pdcPath) {
        Log-Message "INFO" "Playdate SDK found at $Path"
        return @{ Success = $true; Path = $Path }
    }
    return @{ Success = $false; Path = $Path }
}

function Test-VisualStudio {
    $basePath = "C:\Program Files\Microsoft Visual Studio\2022"
    foreach ($edition in @("Enterprise", "Professional", "Community")) {
        $vcvarsPath = Join-Path $basePath "$edition\VC\Auxiliary\Build\vcvars64.bat"
        if (Test-Path $vcvarsPath) {
            Log-Message "INFO" "Visual Studio 2022 $edition found"
            return @{ Success = $true; Path = $vcvarsPath; Edition = $edition }
        }
    }
    Log-Message "WARN" "Visual Studio 2022 not found"
    return @{ Success = $false }
}

function Test-VSCode {
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    if ($codeCmd) { return @{ Success = $true; Path = $codeCmd.Source } }
    return @{ Success = $false }
}

function Test-Make {
    $makeCmd = Get-Command make -ErrorAction SilentlyContinue
    if ($makeCmd) { return @{ Success = $true; Path = $makeCmd.Source } }
    return @{ Success = $false }
}

function Test-Git {
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) { return @{ Success = $true; Path = $gitCmd.Source } }
    return @{ Success = $false }
}

function Set-EnvironmentVariable {
    param([string]$Name, [string]$Value, [string]$Scope = "Machine")
    try {
        $existingValue = [Environment]::GetEnvironmentVariable($Name, $Scope)
        if ($existingValue -eq $Value) { return $true }
        [Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
        $script:ChangesMade += @{ Type = "EnvVar"; Name = $Name; Value = $Value }
        Log-Message "INFO" "Setting environment variable $Name"
        return $true
    } catch { $err = $_; Log-Message "ERROR" "Failed to set ${Name}: $err"; return $false }
}

function Add-ToPath {
    param([string]$PathToAdd)
    try {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$PathToAdd*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$PathToAdd", "Machine")
            $script:ChangesMade += @{ Type = "EnvPath"; Value = $PathToAdd }
            Log-Message "INFO" "Adding to Path: $PathToAdd"
            return $true
        }
        return $true
    } catch { return $false }
}

function Start-Simulator {
    param([string]$PDXPath, [string]$SDKPath)
    $simulatorPath = Join-Path $SDKPath "bin\PlaydateSimulator.exe"
    if (-not (Test-Path $simulatorPath)) { return $false }
    try {
        Start-Process -FilePath $simulatorPath -ArgumentList "`"$PDXPath`""
        return $true
    } catch { return $false }
}

function Show-Menu {
    param()
    $colors = Get-Colors

    $menuOptions = @(
        @{ Id = '1'; Label = "Everything (Recommended)"; Desc = "Check tools, fix settings, build & run" },
        @{ Id = '2'; Label = "Just a check-up";          Desc = "Scan system health only" },
        @{ Id = '3'; Label = "Fix my settings";          Desc = "Repair environment variables" },
        @{ Id = '4'; Label = "Build & Play";             Desc = "Compile and run simulator" },
        @{ Id = '5'; Label = "Setup VS Code";            Desc = "Configure editor settings" },
        @{ Id = '0'; Label = "Exit";                     Desc = "Bye bye!" }
    )

    $selection = 0
    $maxIndex = $menuOptions.Count - 1

    # Save original cursor state
    try {
        if ($Host.UI.RawUI.CursorVisible) {
            $originCursorVisible = $Host.UI.RawUI.CursorVisible
            $Host.UI.RawUI.CursorVisible = $false
        }
    } catch {
        # If terminal doesn't support cursor hiding (like some integrated terminals), ignore error
        $originCursorVisible = $true
    }

    try {
        while ($true) {
            Clear-Host
            Show-AsciiArt
            Speak-Message "Hi! I'm your setup buddy. Use UP/DOWN to choose:" "Step"
            Write-Host ""

            for ($i = 0; $i -lt $menuOptions.Count; $i++) {
                $opt = $menuOptions[$i]
                if ($i -eq $selection) {
                    # Selected state
                    Write-Host "  $($icons.Arrow) $($opt.Label)" -ForegroundColor $colors.Highlight -NoNewline
                    Write-Host "  " -NoNewline
                    Write-Host "$($opt.Desc)" -ForegroundColor $colors.Step
                } else {
                    # Unselected state
                    Write-Host "    $($opt.Label)" -ForegroundColor Gray -NoNewline
                    Write-Host "  " -NoNewline
                    Write-Host "$($opt.Desc)" -ForegroundColor DarkGray
                }
            }

            Write-Host "`n  [ENTER] Select   [UP/DOWN] Move" -ForegroundColor DarkGray

            # Read key without echo
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

            switch ($key.VirtualKeyCode) {
                38 { # Up Arrow
                    $selection--
                    if ($selection -lt 0) { $selection = $maxIndex }
                }
                40 { # Down Arrow
                    $selection++
                    if ($selection -gt $maxIndex) { $selection = 0 }
                }
                13 { # Enter
                    return $menuOptions[$selection].Id
                }
            }
        }
    } finally {
        # Restore cursor
        try {
            $Host.UI.RawUI.CursorVisible = $originCursorVisible
        } catch {}
        Write-Host ""
    }
}

# Show startup animation
Start-Animation "Waking up setup wizard..." 1


function Show-Summary {
    param([hashtable]$Results)
    $colors = Get-Colors
    $elapsedTime = New-TimeSpan -Start $script:StartTime -End (Get-Date)
    $timeStr = $elapsedTime.ToString("mm\:ss")

    Write-Host "`n"
    Speak-Message "All done! That took $timeStr." "Success"

    Write-Host "`n  [ REPORT CARD ]" -ForegroundColor $colors.Highlight -BackgroundColor $colors.Border

    $checks = @(
        @{ Name = "Playdate SDK"; Result = $Results.SDK },
        @{ Name = "Environment"; Result = $Results.EnvVar },
        @{ Name = "Visual Studio"; Result = $Results.VS },
        @{ Name = "VS Code"; Result = $Results.VSCode },
        @{ Name = "Make"; Result = $Results.Make },
        @{ Name = "Git"; Result = $Results.Git }
    )

    foreach ($check in $checks) {
        Write-Host "  $($check.Name.PadRight(14))" -NoNewline -ForegroundColor Gray
        if ($check.Result.Success) { Write-Host " [PASS]" -ForegroundColor $colors.Success }
        elseif ($check.Result.Success -eq $false -and $check.Result.Optional) { Write-Host " [WARN]" -ForegroundColor $colors.Warning }
        else { Write-Host " [FAIL]" -ForegroundColor $colors.Error }
    }

    Write-Host "`n  [ CHEAT SHEET ]" -ForegroundColor $colors.Highlight -BackgroundColor $colors.Border
    $buildCmd = ".\build.ps1"
    Write-Host "  Build & Run:     " -NoNewline -ForegroundColor Gray
    Write-Host "$buildCmd -Run" -ForegroundColor $colors.Highlight
    Write-Host "  Build Only:      " -NoNewline -ForegroundColor Gray
    Write-Host "$buildCmd" -ForegroundColor $colors.Highlight
    Write-Host "  Clean Build:     " -NoNewline -ForegroundColor Gray
    Write-Host "$buildCmd -Clean" -ForegroundColor $colors.Highlight

    Write-Host "`n  [ WHAT'S NEXT ]" -ForegroundColor $colors.Highlight -BackgroundColor $colors.Border
    Write-Host "  1. Read GETTING_STARTED.md (It's short, I promise!)" -ForegroundColor Gray
    Write-Host "  2. Edit src/main.c to make your game." -ForegroundColor Gray
    Write-Host "  3. Crank that simulator!" -ForegroundColor $colors.Highlight

    if ($script:LogFilePath) { Write-Host "`n  Log file: $script:LogFilePath" -ForegroundColor $colors.Info }

    Speak-Message "Now go make something awesome!" "Success"
    Write-Host ""
}

$scriptDir = Get-ScriptDirectory
$colors = Get-Colors

# Set total steps based on execution mode
$totalSteps = 6
if ($Mode -eq 'check') { $totalSteps = 3 }
if ($Mode -eq 'env') { $totalSteps = 3 }
if ($Mode -eq 'build') { $totalSteps = 5 }
if ($Mode -eq 'vscode') { $totalSteps = 4 }
if ($Mode -eq 'repair') { $totalSteps = 6 }
if ($Mode -eq 'interactive') { $totalSteps = 6 }

Clear-Host

function Show-AsciiArt {
    $colors = Get-Colors
    $art = @"
     _______
    |       |  PLAYDATE C
    |  ___  |  SETUP WIZARD
    | |   | |
    | |___| |  v$script:Version
    |       |
    |   +   |  (C)rank it!
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

function Start-Level {
    param([string]$Title, [int]$Level, [int]$Total)
    $colors = Get-Colors
    $p = "+" * $Level + "-" * ($Total - $Level)
    Write-Host "`n  [ LEVEL $Level / $Total ] $Title" -ForegroundColor $colors.Highlight -BackgroundColor $colors.Border
    Write-Host "  $p" -ForegroundColor $colors.Step
}

# Display feature list
Write-Host "`n$($icons.Bullet) This wizard will help you with:" -ForegroundColor $colors.Text
Write-Host "`n  $($icons.Arrow) $($icons.SDK) Check system for required tools and SDK" -ForegroundColor $colors.Text
Write-Host "  $($icons.Arrow) $($icons.Env) Configure Playdate SDK environment variables" -ForegroundColor $colors.Text
Write-Host "  $($icons.Arrow) $($icons.VS) Verify Visual Studio installation" -ForegroundColor $colors.Text
Write-Host "  $($icons.Arrow) $($icons.Make) Check additional dependencies (make, git)" -ForegroundColor $colors.Text
Write-Host "  $($icons.Arrow) $($icons.Play) Build and run the demo game" -ForegroundColor $colors.Text
Write-Host "  $($icons.Arrow) $($icons.VSCode) Configure VS Code (if installed)" -ForegroundColor $colors.Text

# Check system requirements
$sysCheck = Test-SystemRequirements
if (-not $sysCheck.Success) {
    Write-Host "`n$($icons.Error) System requirement issues found:" -ForegroundColor $colors.Error
    foreach ($issue in $sysCheck.Issues) {
        Write-Host "  - $issue" -ForegroundColor $colors.Error
    }
    $continueAnyway = if ($Mode -eq 'silent') { $false } else { Read-Confirmation "Continue anyway?" -DefaultYes $false -HelpText "Continuing may cause unexpected issues" }
    if (-not $continueAnyway) {
        Start-Animation "Setup cancelled due to system requirements..." 1
        exit 1
    }
    Write-Warning "Continuing despite system requirement issues"
}

Log-Message "INFO" "Starting main process"

# Interactive mode menu
if ($Mode -eq 'interactive') {
        $menuChoice = Show-Menu
        switch ($menuChoice) {
            '0' {
                Log-Message "INFO" "User chose to exit"
                Speak-Message "See you later! Happy coding!" "Highlight"
                Start-Sleep -Seconds 1
                exit 0
            }
            '1' { $Mode = 'interactive'; Speak-Message "Awesome! Let's do the full setup." "Success" }
            '2' { $Mode = 'check'; Speak-Message "Okay, checking your system health." "Success" }
            '3' { $Mode = 'env'; Speak-Message "On it! Fixing your environment." "Success" }
            '4' { $Mode = 'build'; Speak-Message "Let's build a game!" "Success" }
            '5' { $Mode = 'vscode'; Speak-Message "Configuring VS Code..." "Success" }
            default {
                Speak-Message "I didn't get that. Let's do everything just to be safe." "Warning"
                $Mode = 'interactive'
            }
        }
        $script:ExecutionMode = $Mode
        # Recalculate total steps based on selected mode
        $stepCounts = @{
            check = 2
            env = 3
            build = 5
            vscode = 4
            repair = 6
            interactive = 6
        }
        $totalSteps = $stepCounts[$Mode]
        if (-not $totalSteps) { $totalSteps = 6 }
    }

# Auto-continue for non-interactive modes, menu already confirmed for interactive
if ($Mode -ne 'interactive' -and $Mode -ne 'silent') {
    # If specific mode is selected (check, env, build, etc.), continue automatically
    Log-Message "INFO" "Running in $Mode mode"
}

$results = @{
    SDK = @{ Success = $false; Optional = $false }
    EnvVar = @{ Success = $false; Optional = $false }
    VS = @{ Success = $false; Optional = $false }
    VSCode = @{ Success = $false; Optional = $true }
    Make = @{ Success = $false; Optional = $true }
    Git = @{ Success = $false; Optional = $true }
}

$currentStep = 1

# SDK detection (required for all modes)
if ($Mode -in @('interactive', 'check', 'env', 'build', 'repair', 'vscode')) {
    Start-Level "Detecting Playdate SDK" $currentStep $totalSteps
    $currentStep++

    $sdkPath = $env:PLAYDATE_SDK_PATH
    $detectedSdkPath = (Get-Item $scriptDir).Parent.Parent.FullName

    $sdkTest = Test-PlaydateSDK -Path $sdkPath
    if (-not $sdkTest.Success -and $sdkPath) { $sdkTest = Test-PlaydateSDK -Path $detectedSdkPath }

    if ($sdkTest.Success) {
        $script:DetectedSDKPath = $sdkTest.Path
        $results.SDK = @{ Success = $true; Path = $sdkTest.Path }
        Speak-Message "Found the Playdate SDK at $($sdkTest.Path)! Nice." "Success"
        Log-Message "INFO" "SDK detection successful"
    } else {
        if ($Mode -eq 'silent') {
            Write-ErrorMsg "Cannot find SDK in silent mode. Please set PLAYDATE_SDK_PATH first"
            Log-Message "ERROR" "Playdate SDK not found in silent mode"
        } else {
            Speak-Message "I couldn't find the Playdate SDK." "Error"
            Write-Info "Download from: https://play.date/dev/"
            $manualPath = Read-Host "`n$($icons.Search) Enter Playdate SDK path (or Ctrl+C to exit)"
            $sdkTest = Test-PlaydateSDK -Path $manualPath
            if ($sdkTest.Success) {
                $script:DetectedSDKPath = $sdkTest.Path
                $results.SDK = @{ Success = $true; Path = $sdkTest.Path }
                Write-Success "Verified: $($sdkTest.Path)"
            } else {
                Write-ErrorMsg "Invalid SDK path: $manualPath"
            }
        }
    }
}

if ($Mode -in @('interactive', 'check', 'env', 'build', 'repair', 'vscode')) {
    Start-Level "Detecting Development Tools" $currentStep $totalSteps
    $currentStep++

    $vsTest = Test-VisualStudio
    if ($vsTest.Success) {
        $results.VS = @{ Success = $true; Path = $vsTest.Path; Edition = $vsTest.Edition }
        Speak-Message "Found Visual Studio 2022 $($vsTest.Edition)!" "Success"
    } else {
        Speak-Message "Visual Studio 2022 is missing." "Warning"
        Write-Info "Download from: https://visualstudio.microsoft.com/downloads/"
        if ($Mode -ne 'silent' -and (Read-Confirmation "Do you have Visual Studio in a custom location?" -HelpText "If you installed VS to a non-default path, enter it here")) {
            $customPath = Read-Host "$($icons.Search) Enter full path to vcvars64.bat"
            if (Test-Path $customPath) {
                $results.VS = @{ Success = $true; Path = $customPath }
                Write-Success "Verified: $customPath"
            }
        }
    }

    $vscodeTest = Test-VSCode
    if ($vscodeTest.Success) {
        $results.VSCode = @{ Success = $true; Path = $vscodeTest.Path }
        Speak-Message "Found VS Code!" "Success"
    } else {
        Speak-Message "VS Code not found (optional but recommended)" "Info"
    }

    $makeTest = Test-Make
    if ($makeTest.Success) { $results.Make = @{ Success = $true; Optional = $true }; Speak-Message "Found Make!" "Success" }
    else { $results.Make = @{ Success = $false; Optional = $true }; Speak-Message "Make not found (optional)" "Info" }

    $gitTest = Test-Git
    if ($gitTest.Success) { $results.Git = @{ Success = $true; Optional = $true }; Speak-Message "Found Git!" "Success" }
    else { $results.Git = @{ Success = $false; Optional = $true }; Speak-Message "Git not found (optional)" "Info" }
}

if ($Mode -in @('interactive', 'check', 'env', 'build', 'repair', 'vscode')) {
    Start-Level "Configuring Environment Variables" $currentStep $totalSteps
    $currentStep++

    $envConfigured = $false
    $currentSdkPath = [Environment]::GetEnvironmentVariable("PLAYDATE_SDK_PATH", "Machine")

    if ($currentSdkPath -and (Test-PlaydateSDK -Path $currentSdkPath).Success) {
        Speak-Message "Environment variable is already good to go!" "Success"
        $results.EnvVar = @{ Success = $true; Path = $currentSdkPath }
        $envConfigured = $true
    } elseif ($script:DetectedSDKPath) {
        if ($Mode -eq 'check') {
            Speak-Message "Environment variable needs setup." "Warning"
            $results.EnvVar = @{ Success = $false; Optional = $false }
        } else {
            $shouldSet = if ($Mode -eq 'silent') { $true } else { Read-Confirmation "Can I set the PLAYDATE_SDK_PATH environment variable for you? (requires admin)" -HelpText "This helps other tools find the SDK."}
            if ($shouldSet) {
                $isAdmin = Test-AdminRights
                if (-not $isAdmin) {
                    Speak-Message "I need admin rights to do that. Asking for permission..." "Warning"
                    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -Mode $Mode"
                    Start-Process powershell -Verb RunAs -ArgumentList $arguments
                    exit 0
                }
                if (Set-EnvironmentVariable -Name "PLAYDATE_SDK_PATH" -Value $script:DetectedSDKPath) {
                    if (Add-ToPath -Path "$script:DetectedSDKPath\bin") {
                        $envConfigured = $true
                        $results.EnvVar = @{ Success = $true; Path = $script:DetectedSDKPath }
                        Speak-Message "Done! Restart your terminal to see the changes." "Success"
                    }
                }
            } else {
                $env:PLAYDATE_SDK_PATH = $script:DetectedSDKPath
                $env:Path = "$env:Path;$script:DetectedSDKPath\bin"
                $envConfigured = $true
                Speak-Message "Okay, I set it just for this session." "Info"
                $results.EnvVar = @{ Success = $true; Path = $script:DetectedSDKPath }
            }
        }
    }
}

if ($Mode -in @('interactive', 'build', 'repair', 'vscode')) {
    Start-Level "Verifying Toolchain" $currentStep $totalSteps
    $currentStep++

    if ($script:DetectedSDKPath) {
        $pdcPath = Join-Path $script:DetectedSDKPath "bin\pdc.exe"
        if (Test-Path $pdcPath) {
            Speak-Message "PDC Compiler is ready to rock!" "Success"
        } else {
            Speak-Message "Uh oh, I can't find the PDC Compiler." "Error"
        }
    }

    if ($results.VS.Success) {
        Speak-Message "Visual Studio compiler is standing by." "Info"
    }
}

if ($Mode -in @('interactive', 'build', 'repair')) {
    Start-Level "Building Demo Game" $currentStep $totalSteps
    $currentStep++

    $shouldBuild = if ($Mode -eq 'silent') { $true } else { Read-Confirmation "Shall we build the demo game now?" -DefaultYes $true -HelpText "This verifies everything works correctly."}

    if ($shouldBuild -and $results.VS.Success) {
        $buildScript = Join-Path $scriptDir "build.ps1"
        if (Test-Path $buildScript) {
            Log-Message "INFO" "Starting build process"
            $env:PLAYDATE_SDK_PATH = $script:DetectedSDKPath
            try {
                & $buildScript -Clean 2>&1 | Out-Host
                if ($LASTEXITCODE -eq 0) {
                    Speak-Message "Build successful! High five!" "Success"
                    $shouldRun = if ($Mode -eq 'silent') { $false } else { Read-Confirmation "Launch the game?" -HelpText "Opens the Playdate Simulator."}
                    if ($shouldRun) {
                        $pdxPath = Join-Path $scriptDir "MyPlaydateGame.pdx"
                        if (Test-Path $pdxPath) {
                            if (Start-Simulator -PDXPath $pdxPath -SDKPath $script:DetectedSDKPath) {
                                Speak-Message "Simulator launched. Have fun!" "Success"
                            }
                        }
                    }
                } else {
                    Speak-Message "Build failed. Check the errors above." "Error"
                }
            } catch { $err = $_; Write-ErrorMsg "Build error: $err" }
        } else {
            Write-ErrorMsg "build.ps1 not found"
        }
    } elseif (-not $results.VS.Success) {
        Speak-Message "Skipping build because Visual Studio is missing." "Warning"
    }
}

if ($Mode -in @('interactive', 'repair', 'vscode')) {
    Start-Level "VS Code Configuration" $currentStep $totalSteps
    $currentStep++

    if ($results.VSCode.Success) {
        $settingsPath = Join-Path $scriptDir ".vscode\settings.json"
        if (Test-Path $settingsPath) {
            Speak-Message "VS Code is fully configured." "Success"
        }
        Write-Info "Keyboard Shortcuts:"
        Write-Host "    F5            - Run game" -ForegroundColor Gray
        Write-Host "    Ctrl+Shift+B  - Build" -ForegroundColor Gray
        if ($Mode -ne 'silent' -and (Read-Confirmation "Open project in VS Code now?" -HelpText "This is where the magic happens.")) {
            Set-Location $scriptDir
            & code .
            Speak-Message "Launching VS Code..." "Success"
        }
    } else {
        Speak-Message "You should install VS Code for the best experience!" "Info"
    }
}

# Show completion animation
Start-Animation "Setup completing..." 1

Show-Summary -Results $results
Log-Message "INFO" "Setup wizard completed"
