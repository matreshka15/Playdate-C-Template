# Playdate Setup Wizard for Windows
# 新手第一次使用只需直接运行：  .\setup.ps1
#
# 高级用法 (Advanced):
#   .\setup.ps1                    # 交互式完整安装 (默认)
#   .\setup.ps1 -Mode check        # 检查工具是否齐全
#   .\setup.ps1 -Mode repair       # 自动修复环境变量
#   .\setup.ps1 -SearchTool all    # 仅搜索已安装的工具

param(
    [ValidateSet('interactive', 'silent', 'check', 'repair', 'env', 'build', 'vscode', 'search', 'smart')]
    [string]$Mode = 'interactive',
    [string]$SearchTool = '',
    [switch]$SkipEnvVar,
    [string]$LogFile = '',
    [string]$Config = '',
    [switch]$NoColor,
    [switch]$Verbose,
    [switch]$SkipChecks
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$script:Version = "4.0.0"
$script:StartTime = Get-Date
$script:LogFilePath = ''
$script:NoColorMode = $NoColor
$script:VerboseMode = $Verbose
$script:ExecutionMode = $Mode
$script:ChangesMade = @()
$script:DetectedSDKPath = ''

# ==========================================
#  SMART CACHE SYSTEM
# ==========================================
$cacheDir = Join-Path $env:TEMP "PlaydateSetupCache"
if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
}

$script:ToolCache = @{}
$script:CacheFile = Join-Path $cacheDir "tool_cache.json"
$script:CacheExpiry = 86400  # 24 hours in seconds

# Load cache if exists and not expired
if (Test-Path $script:CacheFile) {
    try {
        $cacheData = Get-Content $script:CacheFile -Raw | ConvertFrom-Json
        $cacheTime = [DateTime]::Parse($cacheData.timestamp)
        $timeDiff = (Get-Date) - $cacheTime
        
        if ($timeDiff.TotalSeconds -lt $script:CacheExpiry) {
            # Convert PSCustomObject to Hashtable
            $script:ToolCache = @{}
            foreach ($prop in $cacheData.tools.PSObject.Properties) {
                $script:ToolCache[$prop.Name] = $prop.Value
            }
        }
    } catch {
        # Cache load failed, will refresh
    }
}

function Save-ToolCache {
    param([hashtable]$Tools)
    
    $cacheData = @{
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        tools = $Tools
    }
    
    try {
        $cacheData | ConvertTo-Json -Depth 10 | Set-Content -Path $script:CacheFile -Encoding UTF8
    } catch {
        # Cache save failed
    }
}

function Get-CachedTool {
    param([string]$ToolName)
    
    if ($script:ToolCache.ContainsKey($ToolName)) {
        $cached = $script:ToolCache[$ToolName]
        $cacheTime = [DateTime]::Parse($cached.timestamp)
        $timeDiff = (Get-Date) - $cacheTime
        
        if ($timeDiff.TotalSeconds -lt $script:CacheExpiry) {
            return $cached
        }
    }
    return $null
}

function Set-CachedTool {
    param(
        [string]$ToolName,
        [hashtable]$Data
    )
    
    $cachedData = @{
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        data = $Data
    }
    
    $script:ToolCache[$ToolName] = $cachedData
    Save-ToolCache -Tools $script:ToolCache
}

# Create logs directory
$logsDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

$script:LogFilePath = $LogFile
if (-not $script:LogFilePath) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:LogFilePath = Join-Path $logsDir "setup_$timestamp.log"
}

# ==========================================
#  UI & HELPER FUNCTIONS
# ==========================================

function Get-Icons {
    return @{
        Success = "[OK]"
        Error   = "[FAIL]"
        Warning = "[WARN]"
        Info    = "[INFO]"
        Step    = "[STEP]"
        Bullet  = "*"
        Arrow   = "->"
        Check   = "[?]"
        Play    = "[PLAY]"
        Code    = "[CODE]"
        Settings = "[SET]"
        Search  = "[SEARCH]"
        Download = "[DL]"
        Git     = "[GIT]"
        Make    = "[MAKE]"
        VSCode  = "[VSC]"
        VS      = "[VS]"
        SDK     = "[SDK]"
        Env     = "[ENV]"
        Terminal = "[TERM]"
        ARM     = "[ARM]"
    }
}

function Get-Colors {
    if ($script:NoColorMode) {
        return @{
            Title     = [System.ConsoleColor]::White
            Step      = [System.ConsoleColor]::Cyan
            Success   = [System.ConsoleColor]::Green
            Error     = [System.ConsoleColor]::Red
            Info      = [System.ConsoleColor]::Gray
            Warning   = [System.ConsoleColor]::Yellow
            Highlight = [System.ConsoleColor]::Magenta
            Border    = [System.ConsoleColor]::White
            Text      = [System.ConsoleColor]::White
        }
    }
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

function Show-AsciiArt {
    $colors = Get-Colors
    $art = @"
      ___________
     |  _______  |   P L A Y D A T E
     | |       | |   Setup Wizard  /  配置向导
     | |_______| |__
     |      @    |  |  v$script:Version
     |   _    O  |  |  Just run me, I'll do the rest!
     | _| |_  O  |  |  跟着我走完四步，立刻开始做游戏
     ||_   _|    |__|
     |  |_|      |
     |___________|
"@
    Write-Host $art -ForegroundColor $colors.Highlight
}

function Write-Success { param($Message) Write-Host "  $($icons.Success) $Message" -ForegroundColor (Get-Colors).Success }
function Write-ErrorMsg { param($Message) Write-Host "  $($icons.Error) $Message" -ForegroundColor (Get-Colors).Error }
function Write-Info { param($Message) Write-Host "  $($icons.Info) $Message" -ForegroundColor (Get-Colors).Info }
function Write-Warning { param($Message) Write-Host "  $($icons.Warning) $Message" -ForegroundColor (Get-Colors).Warning }
function Write-Step { param($Message) Write-Host "`n  $($icons.Step) $Message" -ForegroundColor (Get-Colors).Step -BackgroundColor (Get-Colors).Border -NoNewline; Write-Host " " -BackgroundColor (Get-Colors).Border }

function Get-ScriptDirectory {
    if ($PSScriptRoot) { return $PSScriptRoot }
    return Split-Path -Parent $MyInvocation.MyCommand.Path
}

# ==========================================
#  TOOL DETECTION FUNCTIONS
# ==========================================

function Find-PlaydateSDK {
    $colors = Get-Colors
    
    # Check cache first
    $cached = Get-CachedTool -ToolName "PlaydateSDK"
    if ($cached -and $script:VerboseMode) {
        Write-Host "  $($icons.Info) Using cached result..." -ForegroundColor $colors.Info
    }
    
    if ($cached -and (Test-Path $cached.data.Path)) {
        $test = Test-PlaydateSDK -Path $cached.data.Path
        if ($test.Success) {
            Write-Host "  $($icons.Success) Found at $($test.Path) (Cached)" -ForegroundColor $colors.Success
            return $cached.data
        }
    }
    
    Write-Host "  $($icons.Search) Searching for Playdate SDK..." -ForegroundColor $colors.Info
    
    # Priority 1: Environment Variable
    if ($env:PLAYDATE_SDK_PATH -and (Test-Path $env:PLAYDATE_SDK_PATH)) {
        $test = Test-PlaydateSDK -Path $env:PLAYDATE_SDK_PATH
        if ($test.Success) { 
            Write-Host "    $($icons.Success) Found at $($test.Path) (Environment Variable)" -ForegroundColor $colors.Success
            $result = @{ Path = $test.Path; Source = "Environment Variable" }
            Set-CachedTool -ToolName "PlaydateSDK" -Data $result
            return $result
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

    # Priority 3: Common Paths
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
        "D:\Playdate SDK",
        "D:\Program Files\PlaydateSDK",
        "E:\PlaydateSDK",
        "E:\Playdate SDK",
        "F:\PlaydateSDK",
        "G:\PlaydateSDK"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            $test = Test-PlaydateSDK -Path $path
            if ($test.Success) {
                Write-Host "    $($icons.Success) Found at $path (Auto-Search)" -ForegroundColor $colors.Success
                return @{ Path = $path; Source = "Auto-Search" }
            }
        }
    }

    # Priority 4: Deep Search (search all drives)
    Write-Host "    $($icons.Info) Performing deep search..." -ForegroundColor $colors.Info
    try {
        $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | Select-Object -ExpandProperty Root
        
        foreach ($drive in $drives) {
            # Skip system drives for performance
            if ($drive -eq "C:\" -or $drive -eq "D:\") { continue }
            
            # Search for PlaydateSDK folder
            try {
                $found = Get-ChildItem -Path $drive -Filter "PlaydateSDK" -Directory -ErrorAction SilentlyContinue -Recurse -Depth 3 | Select-Object -First 1
                if ($found) {
                    $test = Test-PlaydateSDK -Path $found.FullName
                    if ($test.Success) {
                        Write-Host "    $($icons.Success) Found at $($found.FullName) (Deep Search)" -ForegroundColor $colors.Success
                        return @{ Path = $found.FullName; Source = "Deep Search" }
                    }
                }
            } catch {}
        }
    } catch {}

    return $null
}

function Test-PlaydateSDK {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return @{ Success = $false; Path = $Path }
    }
    $pdcPath = Join-Path $Path "bin\pdc.exe"
    if (Test-Path $pdcPath) {
        Log-Message "INFO" "Playdate SDK found at $Path"
        return @{ Success = $true; Path = $Path }
    }
    return @{ Success = $false; Path = $Path }
}

function Find-VisualStudio {
    Log-Message "INFO" "Searching for Visual Studio..."
    
    # 0. Check Environment Variables
    if ($env:VSINSTALLDIR -and (Test-Path $env:VSINSTALLDIR)) {
        $vcvarsPath = Join-Path $env:VSINSTALLDIR "VC\Auxiliary\Build\vcvars64.bat"
        if (Test-Path $vcvarsPath) {
            Log-Message "INFO" "Visual Studio found via Environment Variable at $env:VSINSTALLDIR"
            return @{ Success = $true; Path = $vcvarsPath; Edition = "EnvVar"; InstallPath = $env:VSINSTALLDIR }
        }
    }

    # 1. Try vswhere
    $vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswherePath)) {
        $vswherePath = "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe"
    }

    if (Test-Path $vswherePath) {
        try {
            $jsonOutput = & $vswherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json | ConvertFrom-Json
            
            if ($jsonOutput) {
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

function Find-ArmToolchain {
    $colors = Get-Colors
    Write-Host "  $($icons.Search) Searching for ARM toolchain..." -ForegroundColor $colors.Info
    
    # Check if arm-none-eabi-gcc is in PATH
    $armGcc = Get-Command "arm-none-eabi-gcc" -ErrorAction SilentlyContinue
    if ($armGcc) {
        Write-Host "    $($icons.Success) Found at $($armGcc.Source)" -ForegroundColor $colors.Success
        Write-Host "    $($icons.ARM) Version: $(& arm-none-eabi-gcc --version | Select-Object -First 1)" -ForegroundColor $colors.Info
        return @{ Success = $true; Path = $armGcc.Source }
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
                return @{ Success = $true; Path = $found.FullName }
            }
        } catch {}
    }
    
    Write-Host "    $($icons.Warning) ARM toolchain not found" -ForegroundColor $colors.Warning
    return @{ Success = $false }
}

function Find-CMake {
    $cmake = Get-Command "cmake" -ErrorAction SilentlyContinue
    if ($cmake) {
        return @{ Success = $true; Path = $cmake.Source }
    }
    
    # Search common paths
    $commonPaths = @(
        "C:\Program Files\CMake\bin\cmake.exe",
        "C:\Program Files (x86)\CMake\bin\cmake.exe",
        "${env:LOCALAPPDATA}\Programs\CMake\bin\cmake.exe"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return @{ Success = $true; Path = $path }
        }
    }
    
    return @{ Success = $false }
}

function Find-VSCode {
    $code = Get-Command "code" -ErrorAction SilentlyContinue
    if ($code) {
        return @{ Success = $true; Path = $code.Source }
    }
    
    $commonPaths = @(
        "${env:LOCALAPPDATA}\Programs\Microsoft VS Code\bin\code.cmd",
        "${env:ProgramFiles}\Microsoft VS Code\bin\code.cmd"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return @{ Success = $true; Path = $path }
        }
    }
    
    return @{ Success = $false }
}

# ==========================================
#  CONFIGURATION FUNCTIONS
# ==========================================

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

function Get-SmartRecommendations {
    param(
        [hashtable]$Results
    )
    
    $recommendations = @()
    
    # Check SDK
    if (-not $Results.SDK -or -not $Results.SDK.Path) {
        $recommendations += @{
            Priority = "Critical"
            Issue = "Playdate SDK not found"
            Action = "Install Playdate SDK from https://play.date/dev/"
            AutoFix = $false
        }
    }
    
    # Check Visual Studio
    if (-not $Results.VS -or -not $Results.VS.Success) {
        $recommendations += @{
            Priority = "Critical"
            Issue = "Visual Studio not found"
            Action = "Install Visual Studio 2019/2022 with C++ Desktop Development workload"
            AutoFix = $false
        }
    }
    
    # Check ARM Toolchain
    if (-not $Results.ARM -or -not $Results.ARM.Success) {
        $recommendations += @{
            Priority = "Optional"
            Issue = "ARM Toolchain not found"
            Action = "Install gcc-arm-none-eabi from https://developer.arm.com/downloads/-/gnu-rm"
            AutoFix = $false
        }
    } else {
        # ARM found, check if CMake is also present
        if (-not $Results.CMake -or -not $Results.CMake.Success) {
            $recommendations += @{
                Priority = "Optional"
                Issue = "CMake not found (required for device builds)"
                Action = "Install CMake from https://cmake.org/download/"
                AutoFix = $false
            }
        }
    }
    
    # Check environment variables
    if ($Results.SDK -and $Results.SDK.Path -and -not $env:PLAYDATE_SDK_PATH) {
        $recommendations += @{
            Priority = "Recommended"
            Issue = "PLAYDATE_SDK_PATH not set"
            Action = "Set PLAYDATE_SDK_PATH environment variable"
            AutoFix = $true
            FixFunction = { Set-EnvironmentVariable -Name "PLAYDATE_SDK_PATH" -Value $Results.SDK.Path -Scope "Machine" }
        }
    }
    
    # Check for VS Code (optional but recommended)
    if (-not $Results.VSCode -or -not $Results.VSCode.Success) {
        $recommendations += @{
            Priority = "Optional"
            Issue = "VS Code not found"
            Action = "Install VS Code from https://code.visualstudio.com/"
            AutoFix = $false
        }
    }
    
    return $recommendations | Sort-Object @{Expression = {
        switch ($_.Priority) {
            "Critical" { 0 }
            "Recommended" { 1 }
            "Optional" { 2 }
        }
    }}
}

function Show-SmartRecommendations {
    param([hashtable]$Results)
    
    $colors = Get-Colors
    $recommendations = Get-SmartRecommendations -Results $Results
    
    if ($recommendations.Count -eq 0) {
        Write-Success "Everything looks good! No recommendations."
        return
    }
    
    Write-Host "`n  =========================================" -ForegroundColor $colors.Border
    Write-Host "  Smart Recommendations" -ForegroundColor $colors.Highlight
    Write-Host "  =========================================" -ForegroundColor $colors.Border
    
    foreach ($rec in $recommendations) {
        $priorityColor = switch ($rec.Priority) {
            "Critical" { [System.ConsoleColor]::Red }
            "Recommended" { [System.ConsoleColor]::Yellow }
            "Optional" { [System.ConsoleColor]::Gray }
        }
        
        Write-Host "`n  [$($rec.Priority)]" -ForegroundColor $priorityColor -NoNewline
        Write-Host " $($rec.Issue)" -ForegroundColor $colors.Text
        Write-Host "  Action: $($rec.Action)" -ForegroundColor $colors.Info
        
        if ($rec.AutoFix) {
            Write-Host "  [AUTO-FIX AVAILABLE]" -ForegroundColor $colors.Success
        }
    }
    
    Write-Host ""
    
    # Ask if user wants to auto-fix
    $autoFixable = $recommendations | Where-Object { $_.AutoFix }
    if ($autoFixable.Count -gt 0) {
        Write-Host "  Found $($autoFixable.Count) auto-fixable issue(s)." -ForegroundColor $colors.Step
        $response = Read-Host "  Apply auto-fixes? [Y/n]"
        
        if ($response -ne "n" -and $response -ne "N") {
            foreach ($rec in $autoFixable) {
                Write-Host "`n  Applying fix for: $($rec.Issue)" -ForegroundColor $colors.Info
                try {
                    & $rec.FixFunction
                    Write-Success "Fix applied successfully"
                } catch {
                    Write-ErrorMsg "Failed to apply fix: $_"
                }
            }
        }
    }
}

function Invoke-AutoRepair {
    param([hashtable]$Results)
    
    $colors = Get-Colors
    Write-Host "`n  =========================================" -ForegroundColor $colors.Border
    Write-Host "  Auto-Repair Mode" -ForegroundColor $colors.Highlight
    Write-Host "  =========================================" -ForegroundColor $colors.Border
    
    $repairs = 0
    
    # Fix SDK environment variable
    if ($Results.SDK -and $Results.SDK.Path -and -not $env:PLAYDATE_SDK_PATH) {
        Write-Host "`n  Fixing PLAYDATE_SDK_PATH..." -ForegroundColor $colors.Info
        Set-EnvironmentVariable -Name "PLAYDATE_SDK_PATH" -Value $Results.SDK.Path -Scope "Machine"
        $repairs++
    }
    
    # Check for missing critical tools
    if (-not $Results.SDK -or -not $Results.VS) {
        Write-Host "`n  Cannot auto-fix missing tools. Please install:" -ForegroundColor $colors.Warning
        if (-not $Results.SDK) {
            Write-Host "  - Playdate SDK: https://play.date/dev/" -ForegroundColor $colors.Info
        }
        if (-not $Results.VS) {
            Write-Host "  - Visual Studio: https://visualstudio.microsoft.com/" -ForegroundColor $colors.Info
        }
    }
    
    if ($repairs -gt 0) {
        Write-Success "Applied $repairs auto-fix(es)"
        Write-Info "Please restart your terminal for changes to take effect."
    } else {
        Write-Info "No auto-fixes were needed or possible."
    }
}

function Save-Configuration {
    param(
        [string]$SDKPath,
        [string]$VSPath,
        [string]$ProjectName = "MyPlaydateGame",
        [string]$Author = "Developer",
        [string]$Description = "My Playdate Game",
        [string]$BundleID = "com.example.myplaydategame"
    )

    $configPath = Join-Path (Get-ScriptDirectory) "setup-config.json"

    # Merge with existing config so user-edited fields are preserved
    $existing = $null
    if (Test-Path $configPath) {
        try { $existing = Get-Content $configPath -Raw | ConvertFrom-Json } catch {}
    }

    if ($existing -and $existing.projectName)     { $ProjectName = $existing.projectName }
    if ($existing -and $existing.author)          { $Author      = $existing.author }
    if ($existing -and $existing.description)     { $Description = $existing.description }
    if ($existing -and $existing.bundleID)        { $BundleID    = $existing.bundleID }

    $config = @{
        projectName = $ProjectName
        author = $Author
        description = $Description
        bundleID = $BundleID
        version = if ($existing -and $existing.version) { $existing.version } else { "1.0.0" }
        buildNumber = if ($existing -and $existing.buildNumber) { $existing.buildNumber } else { "1" }
        sdkPath = $SDKPath
        visualStudioPath = $VSPath
        features = @{
            enableLogging = $true
            enableDebugMode = $false
            enableAnalytics = $false
        }
        buildSettings = @{
            optimizationLevel = "2"
            warningLevel = "3"
            generateDebugInfo = $true
        }
    }

    try {
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8
        Write-Success "Configuration saved to $configPath"
    } catch {
        Write-ErrorMsg "Failed to save configuration: $_"
        return $false
    }

    # Sync project name into VS Code settings.json so launch.json (F5) works
    try {
        $vscodeDir = Join-Path (Get-ScriptDirectory) ".vscode"
        $settingsPath = Join-Path $vscodeDir "settings.json"
        if (Test-Path $settingsPath) {
            $raw = Get-Content $settingsPath -Raw
            if ($raw -match '"playdate\.projectName"\s*:\s*"[^"]*"') {
                $new = $raw -replace '("playdate\.projectName"\s*:\s*")[^"]*(")', ("`${1}$ProjectName`${2}")
                if ($new -ne $raw) {
                    Set-Content -Path $settingsPath -Value $new -Encoding UTF8 -NoNewline
                    Log-Message "INFO" "Synced playdate.projectName ($ProjectName) to .vscode/settings.json"
                }
            }
        }
    } catch { Log-Message "WARN" "Could not update .vscode/settings.json: $_" }

    return $true
}

# ==========================================
#  MAIN FUNCTIONS
# ==========================================

function Invoke-InteractiveSetup {
    Clear-Host
    Show-AsciiArt
    $colors = Get-Colors

    Write-Host "`n  Welcome! This wizard sets up everything for your first build." -ForegroundColor $colors.Highlight
    Write-Host "  It should take < 30 seconds if you already have the tools installed.`n" -ForegroundColor $colors.Info

    # ---- Step 1/4: Playdate SDK (required) ----
    Write-Step "[1/4] Playdate SDK  (required / 必需)"
    $sdkResult = Find-PlaydateSDK
    if (-not $sdkResult) {
        Write-ErrorMsg "Playdate SDK not found on this machine."
        Write-Info "Download it from  https://play.date/dev/  and install it, then re-run this wizard."
        $userPath = Read-Host "`n  Or paste an existing SDK folder path now (Enter to skip)"
        if ($userPath -and (Test-Path $userPath)) {
            $test = Test-PlaydateSDK -Path $userPath
            if ($test.Success) {
                $sdkResult = @{ Path = $test.Path; Source = "User Input" }
            } else {
                Write-ErrorMsg "Path does not contain bin\pdc.exe - invalid SDK folder."
            }
        }
    }
    if ($sdkResult) {
        $script:DetectedSDKPath = $sdkResult.Path
        Write-Success "SDK : $($sdkResult.Path)"
    }

    # ---- Step 2/4: Visual Studio (required for simulator) ----
    Write-Step "[2/4] Visual Studio C++  (required / 必需)"
    $vsResult = Find-VisualStudio
    if ($vsResult.Success) {
        Write-Success "Compiler ready : $($vsResult.Edition)"
    } else {
        Write-ErrorMsg "Visual Studio with C++ tools not found."
        Write-Info "Install VS 2022 Community (free):  https://visualstudio.microsoft.com/vs/community/"
        Write-Info "During install tick:  'Desktop development with C++'"
    }

    # ---- Step 3/4: Optional tools (silent scan, just report) ----
    Write-Step "[3/4] Optional tools  (设备构建可选 / only for real device)"
    $armResult    = Find-ArmToolchain
    $cmakeResult  = Find-CMake
    $vscodeResult = Find-VSCode

    $optRow = @(
        @{ Name = "ARM toolchain"; Ok = $armResult.Success    ; Need = "device builds" },
        @{ Name = "CMake"        ; Ok = $cmakeResult.Success  ; Need = "device builds" },
        @{ Name = "VS Code"      ; Ok = $vscodeResult.Success ; Need = "recommended IDE" }
    )
    foreach ($row in $optRow) {
        if ($row.Ok) { Write-Success ("{0,-16} found" -f $row.Name) }
        else         { Write-Warning ("{0,-16} missing  ({1})" -f $row.Name, $row.Need) }
    }

    # ---- Step 4/4: Persist config + env var (single combined prompt) ----
    Write-Step "[4/4] Save configuration"
    if ($sdkResult) {
        $vsPath = if ($vsResult.Success) { $vsResult.Path } else { "" }
        Save-Configuration -SDKPath $sdkResult.Path -VSPath $vsPath | Out-Null

        if (-not $env:PLAYDATE_SDK_PATH) {
            Write-Host ""
            Write-Host "  PLAYDATE_SDK_PATH is not yet set system-wide." -ForegroundColor $colors.Step
            Write-Host "  Setting it lets any terminal + VS Code find the SDK automatically." -ForegroundColor $colors.Info
            $response = Read-Host "  Set it now? [Y/n]"
            if ($response -ne "n" -and $response -ne "N") {
                if (Set-EnvironmentVariable -Name "PLAYDATE_SDK_PATH" -Value $sdkResult.Path -Scope "Machine") {
                    $env:PLAYDATE_SDK_PATH = $sdkResult.Path   # effective for this session
                    Write-Success "PLAYDATE_SDK_PATH = $($sdkResult.Path)"
                }
            }
        }
    }

    # ---- Summary banner ----
    Write-Host ""
    Write-Host "  ==========================================================" -ForegroundColor $colors.Border
    if ($sdkResult -and $vsResult.Success) {
        Write-Host "    (*^v^*)  Setup complete - ready to build!" -ForegroundColor $colors.Success
    } else {
        Write-Host "    (>_<)  Setup incomplete - see messages above." -ForegroundColor $colors.Warning
    }
    Write-Host "  ==========================================================" -ForegroundColor $colors.Border

    Write-Host "`n  What's next:" -ForegroundColor $colors.Step
    Write-Host "    1. Edit  src\main.c                (your game code)" -ForegroundColor $colors.Info
    Write-Host "    2. Run   .\build.ps1 -Run          (build + launch simulator)" -ForegroundColor $colors.Info
    Write-Host "    3. In VS Code, just press F5       (one-click build + debug)" -ForegroundColor $colors.Info
    Write-Host ""

    # ---- Offer to build + run the demo immediately ----
    if ($sdkResult -and $vsResult.Success) {
        $runNow = Read-Host "  Build the demo now and launch the simulator? [Y/n]"
        if ($runNow -ne "n" -and $runNow -ne "N") {
            $buildScript = Join-Path (Get-ScriptDirectory) "build.ps1"
            if (Test-Path $buildScript) {
                Write-Host ""
                & $buildScript -Run
            }
        }
    }
}

function Invoke-SearchMode {
    Clear-Host
    Show-AsciiArt
    Write-Host "`n  Installation Path Search`n" -ForegroundColor (Get-Colors).Highlight
    
    $colors = Get-Colors
    
    while ($true) {
        Write-Host "`n  Select tool to search for:" -ForegroundColor $colors.Step
        Write-Host "  1. Playdate SDK" -ForegroundColor $colors.Text
        Write-Host "  2. Visual Studio" -ForegroundColor $colors.Text
        Write-Host "  3. ARM Toolchain" -ForegroundColor $colors.Text
        Write-Host "  4. CMake" -ForegroundColor $colors.Text
        Write-Host "  5. VS Code" -ForegroundColor $colors.Text
        Write-Host "  6. Search All" -ForegroundColor $colors.Highlight
        Write-Host "  0. Exit" -ForegroundColor $colors.Info
        Write-Host ""
        
        $choice = Read-Host "  Enter choice (0-6)"
        
        switch ($choice) {
            '1' { Search-Tool -ToolName "Playdate SDK" -SearchFunction { Find-PlaydateSDK } }
            '2' { Search-Tool -ToolName "Visual Studio" -SearchFunction { Find-VisualStudio } }
            '3' { Search-Tool -ToolName "ARM Toolchain" -SearchFunction { Find-ArmToolchain } }
            '4' { Search-Tool -ToolName "CMake" -SearchFunction { Find-CMake } }
            '5' { Search-Tool -ToolName "VS Code" -SearchFunction { Find-VSCode } }
            '6' { 
                Write-Host "`n  Searching for all tools..." -ForegroundColor $colors.Info
                Search-Tool -ToolName "Playdate SDK" -SearchFunction { Find-PlaydateSDK }
                Search-Tool -ToolName "Visual Studio" -SearchFunction { Find-VisualStudio }
                Search-Tool -ToolName "ARM Toolchain" -SearchFunction { Find-ArmToolchain }
                Search-Tool -ToolName "CMake" -SearchFunction { Find-CMake }
                Search-Tool -ToolName "VS Code" -SearchFunction { Find-VSCode }
            }
            '0' { break }
            default { Write-Warning "Invalid choice. Please try again." }
        }
    }
}

function Search-Tool {
    param(
        [string]$ToolName,
        [scriptblock]$SearchFunction
    )
    
    $colors = Get-Colors
    Write-Host "`n  =========================================" -ForegroundColor $colors.Border
    Write-Host "  Searching for: $ToolName" -ForegroundColor $colors.Highlight
    Write-Host "  =========================================" -ForegroundColor $colors.Border
    
    $result = & $SearchFunction
    
    # Check if result is valid (different tools return different structures)
    $found = $false
    $path = ""
    
    if ($result) {
        if ($result.Success -eq $true) {
            $found = $true
            $path = $result.Path
        } elseif ($result.Path) {
            $found = $true
            $path = $result.Path
        }
    }
    
    if ($found) {
        Write-Success "Found: $path"
        
        # Show additional info if available
        if ($result.Edition) {
            Write-Info "Edition: $($result.Edition)"
        }
        if ($result.Source) {
            Write-Info "Source: $($result.Source)"
        }
        
        # Ask to set environment variable for SDK (only in interactive mode)
        if ($ToolName -eq "Playdate SDK" -and -not $env:PLAYDATE_SDK_PATH -and $script:ExecutionMode -eq 'interactive') {
            Write-Host "`n  Set PLAYDATE_SDK_PATH environment variable?" -ForegroundColor $colors.Step
            $response = Read-Host "  [Y/n]"
            if ($response -ne "n" -and $response -ne "N") {
                Set-EnvironmentVariable -Name "PLAYDATE_SDK_PATH" -Value $path -Scope "Machine"
                Write-Success "Environment variable set"
            }
        }
    } else {
        Write-Warning "Not found"
        Write-Info "Please install $ToolName"
        
        # Provide download links
        switch ($ToolName) {
            "Playdate SDK" { Write-Info "Download: https://play.date/dev/" }
            "Visual Studio" { Write-Info "Download: https://visualstudio.microsoft.com/" }
            "ARM Toolchain" { Write-Info "Download: https://developer.arm.com/downloads/-/gnu-rm" }
            "CMake" { Write-Info "Download: https://cmake.org/download/" }
            "VS Code" { Write-Info "Download: https://code.visualstudio.com/" }
        }
    }
}

function Invoke-CheckMode {
    Clear-Host
    Show-AsciiArt
    Write-Host "`n  System Health Check`n" -ForegroundColor (Get-Colors).Highlight
    
    $results = @{}
    
    # Check SDK
    Write-Host "  Checking Playdate SDK..." -ForegroundColor (Get-Colors).Info
    $sdkResult = Find-PlaydateSDK
    $results.SDK = $sdkResult
    
    # Check Visual Studio
    Write-Host "  Checking Visual Studio..." -ForegroundColor (Get-Colors).Info
    $vsResult = Find-VisualStudio
    $results.VS = $vsResult
    
    # Check ARM Toolchain
    Write-Host "  Checking ARM Toolchain..." -ForegroundColor (Get-Colors).Info
    $armResult = Find-ArmToolchain
    $results.ARM = $armResult
    
    # Check CMake
    Write-Host "  Checking CMake..." -ForegroundColor (Get-Colors).Info
    $cmakeResult = Find-CMake
    $results.CMake = $cmakeResult
    
    # Check VS Code
    Write-Host "  Checking VS Code..." -ForegroundColor (Get-Colors).Info
    $vscodeResult = Find-VSCode
    $results.VSCode = $vscodeResult
    
    # Summary
    Write-Host "`n  =========================================" -ForegroundColor (Get-Colors).Border
    Write-Host "  Health Check Results`n" -ForegroundColor (Get-Colors).Highlight
    
    Write-Host "  Playdate SDK: " -NoNewline
    if ($results.SDK) { Write-Success "✓ Found at $($results.SDK.Path)" } else { Write-ErrorMsg "✗ Not found" }
    
    Write-Host "  Visual Studio: " -NoNewline
    if ($results.VS.Success) { Write-Success "✓ Found ($($results.VS.Edition))" } else { Write-ErrorMsg "✗ Not found" }
    
    Write-Host "  ARM Toolchain: " -NoNewline
    if ($results.ARM.Success) { Write-Success "✓ Found" } else { Write-Warning "✗ Not found (optional)" }
    
    Write-Host "  CMake: " -NoNewline
    if ($results.CMake.Success) { Write-Success "✓ Found" } else { Write-Warning "✗ Not found (optional)" }
    
    Write-Host "  VS Code: " -NoNewline
    if ($results.VSCode.Success) { Write-Success "✓ Found" } else { Write-Warning "✗ Not found (optional)" }
    
    Write-Host ""
    
    # Show smart recommendations
    Show-SmartRecommendations -Results $results
}

# ==========================================
#  ENTRY POINT
# ==========================================

# Handle -SearchTool parameter for non-interactive search
if ($SearchTool) {
    Clear-Host
    Show-AsciiArt
    Write-Host "`n  Quick Search: $SearchTool`n" -ForegroundColor (Get-Colors).Highlight
    
    switch ($SearchTool.ToLower()) {
        'sdk' { Search-Tool -ToolName "Playdate SDK" -SearchFunction { Find-PlaydateSDK } }
        'playdate' { Search-Tool -ToolName "Playdate SDK" -SearchFunction { Find-PlaydateSDK } }
        'vs' { Search-Tool -ToolName "Visual Studio" -SearchFunction { Find-VisualStudio } }
        'visualstudio' { Search-Tool -ToolName "Visual Studio" -SearchFunction { Find-VisualStudio } }
        'arm' { Search-Tool -ToolName "ARM Toolchain" -SearchFunction { Find-ArmToolchain } }
        'armtoolchain' { Search-Tool -ToolName "ARM Toolchain" -SearchFunction { Find-ArmToolchain } }
        'cmake' { Search-Tool -ToolName "CMake" -SearchFunction { Find-CMake } }
        'vscode' { Search-Tool -ToolName "VS Code" -SearchFunction { Find-VSCode } }
        'code' { Search-Tool -ToolName "VS Code" -SearchFunction { Find-VSCode } }
        'all' {
            Write-Host "`n  Searching for all tools..." -ForegroundColor (Get-Colors).Info
            Search-Tool -ToolName "Playdate SDK" -SearchFunction { Find-PlaydateSDK }
            Search-Tool -ToolName "Visual Studio" -SearchFunction { Find-VisualStudio }
            Search-Tool -ToolName "ARM Toolchain" -SearchFunction { Find-ArmToolchain }
            Search-Tool -ToolName "CMake" -SearchFunction { Find-CMake }
            Search-Tool -ToolName "VS Code" -SearchFunction { Find-VSCode }
        }
        default {
            Write-Warning "Unknown tool: $SearchTool"
            Write-Info "Valid options: sdk, vs, arm, cmake, vscode, all"
        }
    }
    exit
}

switch ($Mode) {
    'interactive' {
        Invoke-InteractiveSetup
    }
    'check' {
        Invoke-CheckMode
    }
    'search' {
        Invoke-SearchMode
    }
    'smart' {
        Clear-Host
        Show-AsciiArt
        Write-Host "`n  Smart Setup Mode`n" -ForegroundColor (Get-Colors).Highlight
        
        # Run check mode
        $results = @{}
        
        Write-Host "  Checking Playdate SDK..." -ForegroundColor (Get-Colors).Info
        $results.SDK = Find-PlaydateSDK
        
        Write-Host "  Checking Visual Studio..." -ForegroundColor (Get-Colors).Info
        $results.VS = Find-VisualStudio
        
        Write-Host "  Checking ARM Toolchain..." -ForegroundColor (Get-Colors).Info
        $results.ARM = Find-ArmToolchain
        
        Write-Host "  Checking CMake..." -ForegroundColor (Get-Colors).Info
        $results.CMake = Find-CMake
        
        Write-Host "  Checking VS Code..." -ForegroundColor (Get-Colors).Info
        $results.VSCode = Find-VSCode
        
        # Show summary
        Write-Host "`n  =========================================" -ForegroundColor (Get-Colors).Border
        Write-Host "  Check Results`n" -ForegroundColor (Get-Colors).Highlight
        
        Write-Host "  Playdate SDK: " -NoNewline
        if ($results.SDK) { Write-Success "✓ Found" } else { Write-ErrorMsg "✗ Not found" }
        
        Write-Host "  Visual Studio: " -NoNewline
        if ($results.VS.Success) { Write-Success "✓ Found" } else { Write-ErrorMsg "✗ Not found" }
        
        Write-Host "  ARM Toolchain: " -NoNewline
        if ($results.ARM.Success) { Write-Success "✓ Found" } else { Write-Warning "✗ Not found" }
        
        Write-Host "  CMake: " -NoNewline
        if ($results.CMake.Success) { Write-Success "✓ Found" } else { Write-Warning "✗ Not found" }
        
        Write-Host "  VS Code: " -NoNewline
        if ($results.VSCode.Success) { Write-Success "✓ Found" } else { Write-Warning "✗ Not found" }
        
        Write-Host ""
        
        # Show recommendations
        Show-SmartRecommendations -Results $results
        
        # Offer auto-repair
        Write-Host "`n  Run auto-repair?" -ForegroundColor (Get-Colors).Step
        $response = Read-Host "  [Y/n]"
        if ($response -ne "n" -and $response -ne "N") {
            Invoke-AutoRepair -Results $results
        }
    }
    'silent' {
        # Silent mode - just check and report
        $sdkResult = Find-PlaydateSDK
        $vsResult = Find-VisualStudio
        $armResult = Find-ArmToolchain
        
        if (-not $sdkResult) {
            Write-ErrorMsg "SDK not found"
            exit 1
        }
        if (-not $vsResult.Success) {
            Write-ErrorMsg "Visual Studio not found"
            exit 1
        }
        
        Write-Success "All critical tools found"
        exit 0
    }
    'repair' {
        # Repair mode - fix environment variables
        Write-Host "Repair mode: Fixing environment variables..."
        $sdkResult = Find-PlaydateSDK
        if ($sdkResult) {
            Set-EnvironmentVariable -Name "PLAYDATE_SDK_PATH" -Value $sdkResult.Path -Scope "Machine"
            Write-Success "PLAYDATE_SDK_PATH set to $($sdkResult.Path)"
        }
    }
    'env' {
        # Env mode - show environment
        Write-Host "PLAYDATE_SDK_PATH: $env:PLAYDATE_SDK_PATH"
        Write-Host "VSINSTALLDIR: $env:VSINSTALLDIR"
    }
    'build' {
        # Build mode - run build.ps1
        $buildScript = Join-Path (Get-ScriptDirectory) "build.ps1"
        if (Test-Path $buildScript) {
            & $buildScript @args
        } else {
            Write-ErrorMsg "build.ps1 not found"
            exit 1
        }
    }
    'vscode' {
        # VS Code mode - open in VS Code
        $vscodeResult = Find-VSCode
        if ($vscodeResult.Success) {
            & code (Get-ScriptDirectory)
        } else {
            Write-ErrorMsg "VS Code not found"
            exit 1
        }
    }
}

$elapsedTime = New-TimeSpan -Start $script:StartTime -End (Get-Date)
Write-Host "`n  Total time: $($elapsedTime.ToString("mm\:ss"))" -ForegroundColor (Get-Colors).Info