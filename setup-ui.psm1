# Enhanced UI Functions for Playdate Setup Wizard

function Show-EnhancedHeader {
    param([string]$Title = \"PLAYDATE SETUP WIZARD\")
    
    $colors = Get-Colors
    $width = 60
    
    Write-Host \"`n\" -NoNewline
    Write-Host $(\"┌\" + $(\"─\" * ($width - 2)) + \"┐\") -ForegroundColor $colors.Border
    Write-Host \"│\" -NoNewline -ForegroundColor $colors.Border
    Write-Host $(\"$($Title.PadLeft([Math]::Floor(($width + $Title.Length) / 2)).PadRight($width - 2))\") -ForegroundColor $colors.Title -NoNewline
    Write-Host \"│\" -ForegroundColor $colors.Border
    Write-Host $(\"├\" + $(\"─\" * ($width - 2)) + \"┤\") -ForegroundColor $colors.Border
}

function Show-EnhancedFooter {
    $colors = Get-Colors
    $width = 60
    
    Write-Host $(\"└\" + $(\"─\" * ($width - 2)) + \"┘\") -ForegroundColor $colors.Border
    Write-Host \"`n\" -NoNewline
}

function Show-ProgressBar {
    param(
        [int]$Percent,
        [string]$Message = \"\",
        [int]$Width = 40
    )
    
    $colors = Get-Colors
    $filled = [Math]::Floor($Width * $Percent / 100)
    $empty = $Width - $filled
    
    $progressBar = \"[\" + $(\"█\" * $filled) + $(\"░\" * $empty) + \"]\"
    
    Write-Host \"  $progressBar\" -NoNewline -ForegroundColor $colors.Success
    Write-Host \" $Percent%\" -NoNewline -ForegroundColor $colors.Step
    if ($Message) {
        Write-Host \" - $Message\" -ForegroundColor $colors.Info
    } else {
        Write-Host \"\"
    }
}

function Show-InteractiveMenu {
    param(
        [string]$Title,
        [hashtable]$Options,
        [string]$Prompt = \"请选择\"
    )
    
    $colors = Get-Colors
    $width = 60
    
    Show-EnhancedHeader -Title $Title
    
    $i = 1
    foreach ($key in $Options.Keys) {
        $description = $Options[$key]
        Write-Host \"│\" -NoNewline -ForegroundColor $colors.Border
        Write-Host \"  $i. $description\" -NoNewline -ForegroundColor $colors.Text
        Write-Host $(\" \" * ($width - 8 - $description.Length - $i.ToString().Length)) -NoNewline
        Write-Host \"│\" -ForegroundColor $colors.Border
        $i++
    }
    
    Write-Host $(\"├\" + $(\"─\" * ($width - 2)) + \"┤\") -ForegroundColor $colors.Border
    Write-Host \"│\" -NoNewline -ForegroundColor $colors.Border
    Write-Host \"  $Prompt [1-$($Options.Count)]: \" -NoNewline -ForegroundColor $colors.Step
    $choice = Read-Host
    Write-Host \"│\" -ForegroundColor $colors.Border
    
    Show-EnhancedFooter
    
    if ($choice -match '^\d+$' -and $choice -ge 1 -and $choice -le $Options.Count) {
        return $Options.Keys[$choice - 1]
    }
    
    return $null
}

function Show-ConfirmDialog {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Default = \"Y\"
    )
    
    $colors = Get-Colors
    $width = 60
    
    Show-EnhancedHeader -Title $Title
    
    $words = $Message -split ' '
    $currentLine = \"│  \"
    foreach ($word in $words) {
        if (($currentLine.Length + $word.Length) -gt ($width - 5)) {
            Write-Host \"$currentLine\" -ForegroundColor $colors.Text
            $currentLine = \"│  $word\"
        } else {
            $currentLine += \" $word\"
        }
    }
    Write-Host \"$currentLine\" -ForegroundColor $colors.Text
    
    Write-Host $(\"├\" + $(\"─\" * ($width - 2)) + \"┤\") -ForegroundColor $colors.Border
    Write-Host \"│\" -NoNewline -ForegroundColor $colors.Border
    Write-Host \"  确认继续? [Y/n]: \" -NoNewline -ForegroundColor $colors.Step
    $response = Read-Host
    Write-Host \"│\" -ForegroundColor $colors.Border
    
    Show-EnhancedFooter
    
    if ([string]::IsNullOrEmpty($response)) {
        return $Default -eq \"Y\"
    }
    
    return $response -eq \"Y\" -or $response -eq \"y\"
}

# Export functions
Export-ModuleMember -Function Show-EnhancedHeader, Show-EnhancedFooter, Show-ProgressBar, Show-InteractiveMenu, Show-ConfirmDialog
