<#
.SYNOPSIS
Windows Parental Control with working time tracking
#>

# Configuration
$targetUserName = "User" # Replace with username
$allowedTimeStart = "9:30"    # 9:30 AM (format: HH:mm)
$allowedTimeEnd = "22:15"     # 10:15 PM (format: HH:mm)
$maxDailyUsageMinutes = 120 # 2 hours

# Files and folders
$logFolder = "$env:ProgramData\ParentalControl"
$usageLogFile = "$logFolder\$targetUserName-Usage.log"
$dailyUsageFile = "$logFolder\$targetUserName-DailyUsage.txt"
$trackerScriptFile = "$logFolder\TimeTracker.ps1"
$timeCheckScriptFile = "$logFolder\TimeChecker.ps1"

# Create log directory
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

# Logging function
function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $usageLogFile -Append
}

# Parse time strings to hours and minutes
function Parse-Time {
    param ([string]$timeString)
    
    $parts = $timeString -split ":"
    if ($parts.Count -eq 2) {
        $hours = [int]$parts[0]
        $minutes = [int]$parts[1]
        return @{ Hours = $hours; Minutes = $minutes; TotalMinutes = ($hours * 60 + $minutes) }
    }
    elseif ($parts.Count -eq 1) {
        $hours = [int]$parts[0]
        return @{ Hours = $hours; Minutes = 0; TotalMinutes = ($hours * 60) }
    }
    else {
        Write-Log "ERROR: Invalid time format: $timeString"
        return @{ Hours = 0; Minutes = 0; TotalMinutes = 0 }
    }
}

# Parse allowed time windows
$startTime = Parse-Time $allowedTimeStart
$endTime = Parse-Time $allowedTimeEnd

# Check if current time is within allowed window
$currentTime = Get-Date
$currentTotalMinutes = $currentTime.Hour * 60 + $currentTime.Minute

if ($currentTotalMinutes -lt $startTime.TotalMinutes -or $currentTotalMinutes -ge $endTime.TotalMinutes) {
    Write-Log "Access denied: Current time $($currentTime.ToString('HH:mm')) outside allowed window ($allowedTimeStart - $allowedTimeEnd)"
    Start-Sleep 3
    shutdown.exe /l /f
    exit
}

# Daily usage check
$today = $currentTime.ToString("yyyy-MM-dd")
$dailyUsage = 0
$fileDate = ""

if (Test-Path $dailyUsageFile) {
    $content = Get-Content $dailyUsageFile
    if ($content -and $content.Count -ge 2) {
        $fileDate = $content[0]
        $fileUsage = [int]$content[1]
        
        if ($fileDate -eq $today) {
            $dailyUsage = $fileUsage
            if ($dailyUsage -ge $maxDailyUsageMinutes) {
                Write-Log "Daily limit reached ($dailyUsage/$maxDailyUsageMinutes minutes)"
                Start-Sleep 3
                shutdown.exe /l /f
                exit
            }
        }
    }
}

# Reset counter if new day or file doesn't exist
if (-not (Test-Path $dailyUsageFile) -or ($fileDate -ne $today)) {
    "$today`n0" | Out-File $dailyUsageFile -Force
    Write-Log "Counter reset for new day"
}

# Create time tracker script
@"
# Time tracker script
`$dailyUsageFile = "$dailyUsageFile"
`$maxMinutes = $maxDailyUsageMinutes
`$logFile = "$usageLogFile"

function Write-Log {
    param ([string]`$message)
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "`$timestamp - `$message" | Out-File -FilePath `$logFile -Append
}

while (`$true) {
    Start-Sleep 60
    
    # Read current usage
    `$content = Get-Content `$dailyUsageFile
    `$date = `$content[0]
    `$minutes = [int]`$content[1] + 1
    
    # Update counter
    "`$date`n`$minutes" | Out-File `$dailyUsageFile -Force
    
    # Exit if limit reached
    if (`$minutes -ge `$maxMinutes) {
        Write-Log "Time limit enforced: `$minutes minutes"
        Start-Sleep 3
        shutdown.exe /l /f
        exit
    }
}
"@ | Out-File $trackerScriptFile -Force

# Create time window checker script
@"
# Time window checker script
`$allowedTimeStart = "$allowedTimeStart"
`$allowedTimeEnd = "$allowedTimeEnd"
`$logFile = "$usageLogFile"

function Write-Log {
    param ([string]`$message)
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "`$timestamp - `$message" | Out-File -FilePath `$logFile -Append
}

function Parse-Time {
    param ([string]`$timeString)
    
    `$parts = `$timeString -split ":"
    if (`$parts.Count -eq 2) {
        `$hours = [int]`$parts[0]
        `$minutes = [int]`$parts[1]
        return @{ Hours = `$hours; Minutes = `$minutes; TotalMinutes = (`$hours * 60 + `$minutes) }
    }
    elseif (`$parts.Count -eq 1) {
        `$hours = [int]`$parts[0]
        return @{ Hours = `$hours; Minutes = 0; TotalMinutes = (`$hours * 60) }
    }
    else {
        return @{ Hours = 0; Minutes = 0; TotalMinutes = 0 }
    }
}

`$startTime = Parse-Time `$allowedTimeStart
`$endTime = Parse-Time `$allowedTimeEnd

while (`$true) {
    `$currentTime = Get-Date
    `$currentTotalMinutes = `$currentTime.Hour * 60 + `$currentTime.Minute
    
    # Check if current time is past allowed end time
    if (`$currentTotalMinutes -ge `$endTime.TotalMinutes) {
        Write-Log "Time window ended: Current time `$(`$currentTime.ToString('HH:mm')) past allowed end time (`$allowedTimeEnd)"
        Start-Sleep 3
        shutdown.exe /l /f
        exit
    }
    
    Start-Sleep 60
}
"@ | Out-File $timeCheckScriptFile -Force

# Start tracker (hidden window)
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "powershell.exe"
$psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$trackerScriptFile`""
$psi.WindowStyle = "Hidden"
[System.Diagnostics.Process]::Start($psi) | Out-Null

# Start time window checker
$psi2 = New-Object System.Diagnostics.ProcessStartInfo
$psi2.FileName = "powershell.exe"
$psi2.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$timeCheckScriptFile`""
$psi2.WindowStyle = "Hidden"
[System.Diagnostics.Process]::Start($psi2) | Out-Null

Write-Log "Session started for $targetUserName. Allowed time: $allowedTimeStart - $allowedTimeEnd, Daily limit: $maxDailyUsageMinutes minutes"