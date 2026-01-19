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
        Download = "[DL]"      # download icon
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

function Find-PlaydateSDK {
    $colors = Get-Colors
    Write-Host "  $($icons.Search) Searching for Playdate SDK..." -ForegroundColor $colors.Info
    
    # Priority 1: Environment Variable
    if ($env:PLAYDATE_SDK_PATH -and (Test-Path $env:PLAYDATE_SDK_PATH)) {
        $test = Test-PlaydateSDK -Path $env:PLAYDATE_SDK_PATH
        if ($test.Success) { 
             Write-Host "    $($icons.Success) Found at $($test.Path) (Environment Variable)" -ForegroundColor $colors.Success
             return @{ Path = $test.Path; Source = "Environment Variable" }
        }
    }
    
    # Priority 2: Registry
    $regPaths = "HKLM:\SOFTWARE\Playdate\SDK", "HKCU:\SOFTWARE\Playdate\SDK", "HKLM:\SOFTWARE\Wow6432Node\Playdate\SDK", "HKCU:\SOFTWARE\Wow6432Node\Playdate\SDK"
    foreach ($rp in $regPaths) {
        try {
            $val = Get-ItemProperty -Path $rp -Name "InstallPath" -ErrorAction SilentlyContinue
            if ($val.InstallPath -and (Test-Path $val.InstallPath)) {
                 $test = Test-PlaydateSDK -Path $val.InstallPath
                 if ($test.Success) {
                     Write-Host "    $($icons.Success) Found at $($test.Path) (Windows Registry)" -ForegroundColor $colors.Success
                     return @{ Path = $test.Path; Source = "Windows Registry" }
                 }
            }
        } catch {}
    }

    # Priority 3: Combinatorial Search (Optimized)
    # Define search space components
    $drives = @("C:", "D:", "E:", "F:", "G:")
    if ($env:SystemDrive -notin $drives) { $drives = @($env:SystemDrive) + $drives }
    
    $rootFolders = @(
        "\", 
        "\Program Files", 
        "\Program Files (x86)", 
        "\Programs",
        "\Tools", 
        "\Dev", 
        "\Development",
        "\Games"
    )
    
    $sdkNames = @("PlaydateSDK", "Playdate SDK")
    
    $userFolders = @(
        "$env:USERPROFILE",
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Development",
        "$env:USERPROFILE\source",
        "$env:LOCALAPPDATA\Programs",
        "$env:ProgramData"
    )

    $searchList = @()
    
    # Build User Paths
    foreach ($folder in $userFolders) {
        foreach ($name in $sdkNames) {
            $searchList += Join-Path $folder $name
        }
    }

    # Build Drive Paths
    foreach ($drive in $drives) {
        foreach ($root in $rootFolders) {
            foreach ($name in $sdkNames) {
                $searchList += "$drive$root\$name"
            }
        }
    }
    
    # Build Relative Paths
    $scriptDir = Get-ScriptDirectory
    $searchList += Join-Path $scriptDir "..\Playdate SDK"
    $searchList += Join-Path $scriptDir "..\..\Playdate SDK"
    $searchList += Join-Path (Split-Path $scriptDir -Parent) "Playdate SDK"

    # Execute Search (Lazy Evaluation)
    $checked = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    
    foreach ($path in $searchList) {
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        # Normalize path
        $cleanPath = $path.Replace("/", "\").TrimEnd('\')
        
        if (-not $checked.Contains($cleanPath)) {
            $checked.Add($cleanPath) | Out-Null
            # Only test if directory exists (fast check)
            if (Test-Path $cleanPath) {
                $test = Test-PlaydateSDK -Path $cleanPath
                if ($test.Success) {
                    Write-Host "    $($icons.Success) Found at $cleanPath (Auto-Search)" -ForegroundColor $colors.Success
                    return @{ Path = $cleanPath; Source = "Auto-Search" }
                }
            }
        }
    }

    return $null
}

function Test-PlaydateSDK {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Log-Message "WARN" "Playdate SDK path is null or empty"
        return @{ Success = $false; Path = $Path }
    }
    $pdcPath = Join-Path $Path "bin\pdc.exe"
    if (Test-Path $pdcPath) {
        Log-Message "INFO" "Playdate SDK found at $Path"
        return @{ Success = $true; Path = $Path }
    }
    return @{ Success = $false; Path = $Path }
}

function Test-VisualStudio {
    Log-Message "INFO" "Searching for Visual Studio..."
    
    # 0. Check Environment Variables (Developer Command Prompt)
    if ($env:VSINSTALLDIR -and (Test-Path $env:VSINSTALLDIR)) {
         $vcvarsPath = Join-Path $env:VSINSTALLDIR "VC\Auxiliary\Build\vcvars64.bat"
         if (Test-Path $vcvarsPath) {
             Log-Message "INFO" "Visual Studio found via Environment Variable at $env:VSINSTALLDIR"
             return @{ Success = $true; Path = $vcvarsPath; Edition = "EnvVar"; InstallPath = $env:VSINSTALLDIR }
         }
    }

    # 1. Try using vswhere (most reliable method)
    $vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswherePath)) {
        $vswherePath = "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe"
    }

    if (Test-Path $vswherePath) {
        try {
            # Search for VS with VC++ tools using JSON format for efficiency
            $jsonOutput = & $vswherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json | ConvertFrom-Json
            
            if ($jsonOutput) {
                # Handle case where ConvertFrom-Json returns an array or single object
                if ($jsonOutput -is [array]) { $vsInfo = $jsonOutput[0] } else { $vsInfo = $jsonOutput }

                $vsPath = $vsInfo.installationPath
                if ($vsPath -and (Test-Path $vsPath)) {
                    $vcvarsPath = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
                    if (Test-Path $vcvarsPath) {
                        $vsName = $vsInfo.catalog.productDisplayVersion
                        $editionId = $vsInfo.productId
                        $edition = ($editionId -split '\.')[-1]
                    
                        Log-Message "INFO" "Visual Studio found via vswhere at $vsPath"
                        return @{ Success = $true; Path = $vcvarsPath; Edition = "$edition ($vsName)"; InstallPath = $vsPath }
                    }
                }
            }
        } catch {
            Log-Message "WARN" "vswhere execution failed: $_"
        }
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
                    Log-Message "INFO" "Visual Studio found at $vcvarsPath"
                    return @{ Success = $true; Path = $vcvarsPath; Edition = "$year $edition" }
                }
            }
        }
    }

    Log-Message "WARN" "Visual Studio not found"
    return @{ Success = $false }
}

function Find-Tool {
    param([string]$Command, [string[]]$Paths)
    
    # 1. PATH check
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if ($cmd) { return @{ Success = $true; Path = $cmd.Source } }

    # 2. Explicit Path Search
    $drives = @("C:", "D:", "E:", "F:", "G:")
    if ($env:SystemDrive -notin $drives) { $drives = @($env:SystemDrive) + $drives }
    
    foreach ($p in $Paths) {
        # If absolute path, check directly
        if ($p -match "^[a-zA-Z]:") {
             if (Test-Path $p) { return @{ Success = $true; Path = $p } }
             continue
        }
        
        # Relative pattern, check across drives and roots
        $roots = @("\", "\Program Files", "\Program Files (x86)", "\Programs", "\Tools", "\Dev", "\Development", "\Software")
        foreach ($d in $drives) {
            foreach ($r in $roots) {
                $fullPath = "$d$r\$p"
                # Handle wildcards
                if ($fullPath.Contains("*")) {
                    $found = Get-ChildItem $fullPath -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Select-Object -First 1
                    if ($found) { return @{ Success = $true; Path = $found.FullName } }
                } elseif (Test-Path $fullPath) {
                    return @{ Success = $true; Path = $fullPath }
                }
            }
        }
    }
    return @{ Success = $false }
}

function Test-VSCode {
    return Find-Tool -Command "code" -Paths @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "Microsoft VS Code\bin\code.cmd"
    )
}

function Test-Make {
    return Find-Tool -Command "make" -Paths @(
        "GnuWin32\bin\make.exe",
        "MinGW\bin\make.exe",
        "MinGW\bin\mingw32-make.exe",
        "Chocolatey\bin\make.exe",
        "ProgramData\chocolatey\bin\make.exe"
    )
}

function Test-ArmToolchain {
    return Find-Tool -Command "arm-none-eabi-gcc" -Paths @(
        "GNU Arm Embedded Toolchain\*\bin\arm-none-eabi-gcc.exe",
        "GNU Tools ARM Embedded\*\bin\arm-none-eabi-gcc.exe",
        "Arm GNU Toolchain\*\bin\arm-none-eabi-gcc.exe"
    )
}

function Test-Git {
    return Find-Tool -Command "git" -Paths @(
        "Git\cmd\git.exe",
        "Git\bin\git.exe"
    )
}

function Set-EnvironmentVariable {
    param([string]$Name, [string]$Value, [string]$Scope = "Machine")
    try {
        $existingValue = [Environment]::GetEnvironmentVariable($Name, $Scope)
        if ($existingValue -eq $Value) { return $true }
        [Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
        $script:ChangesMade += @{ Type = "EnvVar"; Name = $Name; Value = $Value }
        Log-Message "INFO" "Setting environment variable $Name to $Value (Scope: $Scope)"
        return $true
    } catch { $err = $_; Log-Message "ERROR" "Failed to set ${Name}: $err"; return $false }
}

function Get-EnvironmentVariables {
    param([string]$VarName = "PLAYDATE_SDK_PATH")
    $vars = @{
        User = [Environment]::GetEnvironmentVariable($VarName, "User")
        Machine = [Environment]::GetEnvironmentVariable($VarName, "Machine")
        Process = [Environment]::GetEnvironmentVariable($VarName, "Process")
    }
    return $vars
}

function Test-EnvironmentVariable {
    param([string]$VarName = "PLAYDATE_SDK_PATH")
    $vars = Get-EnvironmentVariables -VarName $VarName
    $validPaths = @()
    
    foreach ($scope in @("Machine", "User", "Process")) {
        $path = $vars[$scope]
        if ($path -and (Test-PlaydateSDK -Path $path).Success) {
            $validPaths += @{ Scope = $scope; Path = $path }
        }
    }
    
    return $validPaths
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

function Install-PlaydateSDK {
    param([string]$InstallPath = "")
    $colors = Get-Colors
    
    if ([string]::IsNullOrWhiteSpace($InstallPath)) {
        $InstallPath = "$env:ProgramFiles\Playdate SDK"
    }
    
    Write-Host "  $($icons.Download) Downloading Playdate SDK..." -ForegroundColor $colors.Info
    
    try {
        # Create temporary directory for download
        $tempDir = Join-Path $env:TEMP "PlaydateSDK_$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        # Download URL (this would need to be updated with actual SDK URL)
        $sdkUrl = "https://download.panic.com/playdate_sdk/PlaydateSDK.zip"
        $zipPath = Join-Path $tempDir "PlaydateSDK.zip"
        
        # Download using Invoke-WebRequest
        Write-Host "    Downloading from: $sdkUrl" -ForegroundColor $colors.Info
        Invoke-WebRequest -Uri $sdkUrl -OutFile $zipPath -UseBasicParsing
        
        # Extract ZIP
        Write-Host "    Extracting SDK..." -ForegroundColor $colors.Info
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
        
        # Find extracted SDK directory
        $extractedDir = Get-ChildItem -Path $tempDir -Directory | Where-Object { $_.Name -like "*Playdate*" } | Select-Object -First 1
        
        if ($extractedDir) {
            # Create installation directory if it doesn't exist
            if (-not (Test-Path $InstallPath)) {
                New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
            }
            
            # Move SDK files to installation directory
            Write-Host "    Installing to: $InstallPath" -ForegroundColor $colors.Info
            Copy-Item -Path "$($extractedDir.FullName)\*" -Destination $InstallPath -Recurse -Force
            
            # Clean up temporary files
            Remove-Item -Path $tempDir -Recurse -Force
            
            # Verify installation
            $testResult = Test-PlaydateSDK -Path $InstallPath
            if ($testResult.Success) {
                Write-Host "    $($icons.Success) SDK installed successfully!" -ForegroundColor $colors.Success
                return @{ Success = $true; Path = $InstallPath }
            } else {
                Write-Host "    $($icons.Error) Installation verification failed" -ForegroundColor $colors.Error
                return @{ Success = $false }
            }
        } else {
            Write-Host "    $($icons.Error) Could not find extracted SDK directory" -ForegroundColor $colors.Error
            return @{ Success = $false }
        }
    } catch {
        Write-Host "    $($icons.Error) Download/installation failed: $_" -ForegroundColor $colors.Error
        # Clean up on error
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }
        return @{ Success = $false }
    }
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
    
    $checks = @(
        @{ Name = "Playdate SDK"; Result = $Results.SDK },
        @{ Name = "Environment"; Result = $Results.EnvVar },
        @{ Name = "Visual Studio"; Result = $Results.VS },
        @{ Name = "ARM Compiler"; Result = $Results.Arm },
        @{ Name = "VS Code"; Result = $Results.VSCode },
        @{ Name = "Make"; Result = $Results.Make },
        @{ Name = "Git"; Result = $Results.Git }
    )

    $actions = @(
        @{ Label = "Show Cheat Sheet"; Code = "CheatSheet"; Desc = "View build commands" },
        @{ Label = "Open VS Code"; Code = "VSCode"; Desc = "Launch project editor" },
        @{ Label = "Read Guide"; Code = "Docs"; Desc = "Open GETTING_STARTED.md" },
        @{ Label = "Explore Code"; Code = "Explorer"; Desc = "Open src folder" },
        @{ Label = "Exit"; Code = "Exit"; Desc = "Close wizard" }
    )
    
    $selection = 0
    $firstRun = $true
    
    # Clear input buffer to prevent skipping
    while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") }

    while ($true) {
        if ($firstRun) {
            Clear-Host
            Show-AsciiArt
            Speak-Message "Setup complete! (Time: $timeStr)" "Success"
            
            Write-Host "`n  [ REPORT CARD ]" -ForegroundColor $colors.Highlight -BackgroundColor $colors.Border
            
            # Animation for first run
            foreach ($check in $checks) {
                Write-Host "  $($check.Name.PadRight(14))" -NoNewline -ForegroundColor Gray
                if ($check.Result.Success) { Write-Host " [PASS]" -ForegroundColor $colors.Success }
                elseif ($check.Result.Success -eq $false -and $check.Result.Optional) { Write-Host " [WARN]" -ForegroundColor $colors.Warning }
                else { Write-Host " [FAIL]" -ForegroundColor $colors.Error }
                Start-Sleep -Milliseconds 50
            }
            
            if (-not $Results.Arm.Success) {
                Write-Typewriter "  Note: ARM Compiler is missing. Device builds disabled." "Info" 10
            }
            
            $firstRun = $false
            # Another buffer clear just in case user mashed keys during animation
            while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") }
        }
        else {
            # Static Redraw (No Animation)
            Clear-Host
            Show-AsciiArt
            # Re-print header to maintain context
            Write-Host "`n  [ REPORT CARD ]" -ForegroundColor $colors.Highlight -BackgroundColor $colors.Border
            foreach ($check in $checks) {
                Write-Host "  $($check.Name.PadRight(14))" -NoNewline -ForegroundColor Gray
                if ($check.Result.Success) { Write-Host " [PASS]" -ForegroundColor $colors.Success }
                elseif ($check.Result.Success -eq $false -and $check.Result.Optional) { Write-Host " [WARN]" -ForegroundColor $colors.Warning }
                else { Write-Host " [FAIL]" -ForegroundColor $colors.Error }
            }
            if (-not $Results.Arm.Success) { Write-Host "  Note: ARM Compiler is missing." -ForegroundColor (Get-Colors).Info }
        }

        # Draw Menu (Always visible below report card)
        Write-Host "`n  [ DIRECTOR'S CUT ]" -ForegroundColor $colors.Highlight -BackgroundColor $colors.Border
        
        for ($i = 0; $i -lt $actions.Count; $i++) {
            $act = $actions[$i]
            if ($i -eq $selection) {
                Write-Host "  $($icons.Arrow) $($act.Label)" -ForegroundColor $colors.Highlight -NoNewline
                Write-Host "  $($act.Desc)" -ForegroundColor $colors.Step
            } else {
                Write-Host "    $($act.Label)" -ForegroundColor Gray -NoNewline
                Write-Host "  $($act.Desc)" -ForegroundColor DarkGray
            }
        }
        
        Write-Host "`n  [UP/DOWN] Select   [ENTER] Confirm" -ForegroundColor DarkGray

        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { if ($selection -gt 0) { $selection-- } else { $selection = $actions.Count - 1 } } # Up
            40 { if ($selection -lt $actions.Count - 1) { $selection++ } else { $selection = 0 } } # Down
            13 { # Enter
                $code = $actions[$selection].Code
                if ($code -eq "Exit") { return }
                
                if ($code -eq "CheatSheet") {
                    Clear-Host
                    Show-AsciiArt
                    Write-Host "`n  [ CHEAT SHEET ]" -ForegroundColor $colors.Highlight -BackgroundColor $colors.Border
                    Write-Host "`n  Build & Run:     .\build.ps1 -Run" -ForegroundColor $colors.Text
                    Write-Host "  Build Only:      .\build.ps1" -ForegroundColor $colors.Text
                    Write-Host "  Clean Build:     .\build.ps1 -Clean" -ForegroundColor $colors.Text
                    Speak-Message "Got it? Press any key to go back." "Info"
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
                elseif ($code -eq "VSCode") {
                    if ($Results.VSCode.Success) { 
                        code . 
                        Speak-Message "VS Code launching..." "Success"
                        Start-Sleep -Seconds 1
                    } else { 
                        Speak-Message "VS Code is not installed or configured." "Error" 
                        Start-Sleep -Seconds 2
                    }
                }
                elseif ($code -eq "Docs") {
                    $docPath = Join-Path $scriptDir "docs\GETTING_STARTED.md"
                    if (Test-Path $docPath) { Invoke-Item $docPath } else { Write-Warning "Docs missing" }
                }
                elseif ($code -eq "Explorer") {
                    Invoke-Item (Join-Path $scriptDir "src")
                }
            }
        }
    }
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
      ___________
     |  _______  |  PLAYDATE C
     | |       | |  SETUP WIZARD
     | |_______| |__
     |      @    |  | v$script:Version
     |   _    O  |  |
     | _| |_  O  |  |
     ||_   _|    |__| (C)rank it!
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
    param([string]$Message, [string]$Color = "Title", [string]$Mood = "")
    $colors = Get-Colors
    $faces = Get-Faces
    
    # Robustness: Map legacy/invalid colors to valid theme keys
    if (-not $colors.ContainsKey($Color)) {
        switch ($Color) {
            "Cyan"      { $Color = "Title" }
            "Excited"   { $Color = "Highlight" }
            default     { $Color = "Text" }
        }
    }
    
    # Auto-detect mood if not provided
    if (-not $Mood) {
        switch ($Color) {
            "Success"   { $Mood = "Success" }
            "Error"     { $Mood = "Error" }
            "Warning"   { $Mood = "Warning" }
            "Info"      { $Mood = "Info" }
            "Title"     { $Mood = "Happy" }
            "Highlight" { $Mood = "Excited" }
            default     { $Mood = "Happy" }
        }
    }

    $face = if ($faces.ContainsKey($Mood)) { $faces[$Mood] } else { $faces.Happy }
    
    # Final safety check before output
    $consoleColor = if ($colors.ContainsKey($Color)) { $colors.$Color } else { [System.ConsoleColor]::White }
    Write-Host "`n  $face $Message" -ForegroundColor $consoleColor
}

function Start-Level {
    param([string]$Title, [int]$Level, [int]$Total)
    $colors = Get-Colors    
    
    # UX Pacing: Brief pause between levels so user can track progress
    if ($script:ExecutionMode -ne 'silent') { Start-Sleep -Milliseconds 800 }

    # Ensure progress doesn't go negative
    if ($Level -gt $Total) { $Total = $Level }
    $remaining = $Total - $Level
    if ($remaining -lt 0) { $remaining = 0 }

    $p = "+" * $Level + "-" * $remaining
    Write-Host "`n  [ LEVEL $Level / $Total ] $Title" -ForegroundColor $colors.Highlight -BackgroundColor $colors.Border
    Write-Host "  $p" -ForegroundColor $colors.Step
}

# Display feature list
Write-Host "`n$($icons.Bullet) This wizard will help you with:" -ForegroundColor $colors.Text
Write-Host "`n  $($icons.Arrow) $($icons.SDK) Check system for required tools and SDK" -ForegroundColor $colors.Text
Write-Host "  $($icons.Arrow) $($icons.Env) Configure Playdate SDK environment variables" -ForegroundColor $colors.Text
Write-Host "  $($icons.Arrow) $($icons.VS) Verify Visual Studio installation" -ForegroundColor $colors.Text
Write-Host "  $($icons.Arrow) $($icons.Code) Check for ARM GCC Toolchain (for device)" -ForegroundColor $colors.Text
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
            check = 3
            env = 3
            build = 5
            vscode = 5
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
    # Recalculate steps for non-interactive mode too
    $stepCounts = @{
        check = 3
        env = 3
        build = 5
        vscode = 5
        repair = 6
        interactive = 6
    }
    $totalSteps = $stepCounts[$Mode]
    if (-not $totalSteps) { $totalSteps = 6 }
}

$results = @{
    SDK = @{ Success = $false; Optional = $false }
    EnvVar = @{ Success = $false; Optional = $false }
    VS = @{ Success = $false; Optional = $false }
    VSCode = @{ Success = $false; Optional = $true }
    Make = @{ Success = $false; Optional = $true }
    Git = @{ Success = $false; Optional = $true }
    Arm = @{ Success = $false; Optional = $true }
}

$currentStep = 1

# SDK detection (required for all modes)
if ($Mode -in @('interactive', 'check', 'env', 'build', 'repair', 'vscode')) {
    Start-Level "Detecting Playdate SDK" $currentStep $totalSteps
    $currentStep++

    # Use the enhanced SDK detection
    $foundSDK = Find-PlaydateSDK
    
    if ($foundSDK) {
        $script:DetectedSDKPath = $foundSDK.Path
        $results.SDK = @{ Success = $true; Path = $foundSDK.Path; Source = $foundSDK.Source }
        Speak-Message "Found the Playdate SDK at $($foundSDK.Path)! Nice." "Success"
        Log-Message "INFO" "SDK detection successful via $($foundSDK.Source)"
    } else {
        if ($Mode -eq 'silent') {
            Write-ErrorMsg "Cannot find SDK in silent mode. Please set PLAYDATE_SDK_PATH first"
            Log-Message "ERROR" "Playdate SDK not found in silent mode"
        } else {
            Speak-Message "I couldn't find the Playdate SDK automatically." "Warning"
            Write-Info "The system searched in common locations, registry, and environment variables."
            
            # Offer automatic download
            $autoDownload = Read-Confirmation "Would you like me to download and install the SDK automatically?" -HelpText "This will download the latest Playdate SDK from the official website."
            if ($autoDownload) {
                $installResult = Install-PlaydateSDK
                if ($installResult.Success) {
                    $script:DetectedSDKPath = $installResult.Path
                    $results.SDK = @{ Success = $true; Path = $installResult.Path; Source = "Auto-Install" }
                    Speak-Message "SDK installed successfully at $($installResult.Path)!" "Success"
                    Log-Message "INFO" "SDK auto-installed at $($installResult.Path)"
                } else {
                    Speak-Message "Automatic installation failed. Let's try manual setup." "Error"
                    Write-Info "Download from: https://play.date/dev/"
                    $manualPath = Read-Host "`n$($icons.Search) Enter Playdate SDK path (or Ctrl+C to exit)"
                    $sdkTest = Test-PlaydateSDK -Path $manualPath
                    if ($sdkTest.Success) {
                        $script:DetectedSDKPath = $sdkTest.Path
                        $results.SDK = @{ Success = $true; Path = $sdkTest.Path; Source = "Manual" }
                        Write-Success "Verified: $($sdkTest.Path)"
                    } else {
                        Write-ErrorMsg "Invalid SDK path: $manualPath"
                    }
                }
            } else {
                Write-Info "Download from: https://play.date/dev/"
                $manualPath = Read-Host "`n$($icons.Search) Enter Playdate SDK path (or Ctrl+C to exit)"
                $sdkTest = Test-PlaydateSDK -Path $manualPath
                if ($sdkTest.Success) {
                    $script:DetectedSDKPath = $sdkTest.Path
                    $results.SDK = @{ Success = $true; Path = $sdkTest.Path; Source = "Manual" }
                    Write-Success "Verified: $($sdkTest.Path)"
                } else {
                    Write-ErrorMsg "Invalid SDK path: $manualPath"
                }
            }
        }
    }
}

function Press-Any-Key {
    if ($script:ExecutionMode -eq 'interactive') {
        Write-Host "`n  $($icons.Play) Press any key to continue..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Open-Browser {
    param([string]$Url)
    if ($script:ExecutionMode -ne 'silent' -and (Read-Confirmation "Open download page now?" -DefaultYes $true)) {
        Start-Process $Url
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
        Write-Info "We need the C++ compiler."
        Open-Browser "https://visualstudio.microsoft.com/downloads/"
        
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

    $armTest = Test-ArmToolchain
    if ($armTest.Success) { 
        $results.Arm = @{ Success = $true; Optional = $true }
        Speak-Message "Found ARM Toolchain (for device builds)!" "Success" 
    } else { 
        $results.Arm = @{ Success = $false; Optional = $true }
        Speak-Message "ARM Toolchain missing (needed for device builds)" "Info"
        Open-Browser "https://developer.arm.com/downloads/-/gnu-rm"
    }

    $gitTest = Test-Git
    if ($gitTest.Success) { $results.Git = @{ Success = $true; Optional = $true }; Speak-Message "Found Git!" "Success" }
    else { $results.Git = @{ Success = $false; Optional = $true }; Speak-Message "Git not found (optional)" "Info" }

    Press-Any-Key
}

if ($Mode -in @('interactive', 'check', 'env', 'build', 'repair', 'vscode')) {
    Start-Level "Configuring Environment Variables" $currentStep $totalSteps
    $currentStep++

    $envConfigured = $false
    $existingEnvVars = Test-EnvironmentVariable
    
    if ($existingEnvVars.Count -gt 0) {
        $bestEnvVar = $existingEnvVars[0]
        Speak-Message "Environment variable already configured! $($bestEnvVar.Scope) scope." "Success"
        $results.EnvVar = @{ Success = $true; Path = $bestEnvVar.Path; Scope = $bestEnvVar.Scope }
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
                        $results.EnvVar = @{ Success = $true; Path = $script:DetectedSDKPath; Scope = "Machine" }
                        Speak-Message "Done! Restart your terminal to see the changes." "Success"
                    }
                }
            } else {
                $env:PLAYDATE_SDK_PATH = $script:DetectedSDKPath
                $env:Path = "$env:Path;$script:DetectedSDKPath\bin"
                $envConfigured = $true
                Speak-Message "Okay, I set it just for this session." "Info"
                $results.EnvVar = @{ Success = $true; Path = $script:DetectedSDKPath; Scope = "Process" }
            }
        }
    }
    
    Press-Any-Key
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
            
            # UX: Show spinner instead of raw build log
            Write-Host "  $($icons.Settings) Cranking the build machine..." -NoNewline -ForegroundColor Gray
            
            try {
                $buildOutput = & $buildScript -Clean 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host " [OK]" -ForegroundColor Green
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
                    Write-Host " [FAIL]" -ForegroundColor Red
                    Speak-Message "Build failed. Here is what happened:" "Error"
                    Write-Host "----------------------------------------" -ForegroundColor DarkRed
                    $buildOutput | ForEach-Object { Write-Host $_ -ForegroundColor Red }
                    Write-Host "----------------------------------------" -ForegroundColor DarkRed
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

if ($Mode -eq 'interactive') {
    Write-Host "`n  Press any key to view the report card..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Clear-Host
    Show-AsciiArt
}

function Write-Typewriter {
    param([string]$Text, [string]$Color = "Cyan", [int]$Speed = 15)
    $colors = Get-Colors
    $Text.ToCharArray() | ForEach-Object {
        Write-Host $_ -NoNewline -ForegroundColor $colors.$Color
        if ($Speed -gt 0) { Start-Sleep -Milliseconds $Speed }
    }
    Write-Host ""
}

Show-Summary -Results $results
Log-Message "INFO" "Setup wizard completed"
