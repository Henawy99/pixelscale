
# =============================================================
#  RestaurantAdmin — Scanner Watcher Auto-Start via Task Scheduler
#  Version 1.0
# =============================================================
#
# WHAT THIS DOES:
#   Creates a Windows Task Scheduler task that automatically starts
#   the PowerShell receipt watcher script when you log in to Windows.
#   This is more reliable than the Startup folder for long-running scripts.
#
# HOW TO RUN (once, as Administrator):
#   Right-click PowerShell → Run as Administrator
#   cd C:\RestaurantAdmin
#   .\setup_scanner_autostart.ps1
#
# UNINSTALL:
#   .\setup_scanner_autostart.ps1 -Remove
#
# VIEW STATUS:
#   .\setup_scanner_autostart.ps1 -Status
# =============================================================

param(
  [switch]$Remove,
  [switch]$Status
)

# -----------------------------------------------
# CONFIGURATION — update if needed
# -----------------------------------------------
# Task name shown in Task Scheduler
$TaskName = "RestaurantAdmin-ScannerWatcher"

# Which watcher script to run (use edge version for AI + notifications)
# Options:
#   "powershell_watcher_edge.ps1"    <- recommended (AI + push notifications)
#   "powershell_uploader_only.ps1"   <- simple (no AI, still gets push notifications)
$WatcherScript = "powershell_uploader_only.ps1"

# Folder where the script lives on this PC
$ScriptsFolder = "C:\RestaurantAdmin"
$FullScriptPath = Join-Path $ScriptsFolder $WatcherScript

# -----------------------------------------------
# STATUS MODE
# -----------------------------------------------
if ($Status) {
  $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  if ($task) {
    Write-Host ""
    Write-Host "Task: $TaskName" -ForegroundColor Cyan
    Write-Host "State: $($task.State)" -ForegroundColor $(if ($task.State -eq 'Running') { 'Green' } else { 'Yellow' })
    $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($taskInfo) {
      Write-Host "Last Run : $($taskInfo.LastRunTime)"
      Write-Host "Last Result: $($taskInfo.LastTaskResult)"
      Write-Host "Next Run : $($taskInfo.NextRunTime)"
    }
  } else {
    Write-Host "Task '$TaskName' not found." -ForegroundColor DarkGray
    Write-Host "Run this script without flags to create it." -ForegroundColor Cyan
  }
  exit 0
}

# -----------------------------------------------
# REMOVE MODE
# -----------------------------------------------
if ($Remove) {
  $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  if ($task) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed scheduled task: $TaskName" -ForegroundColor Yellow
  } else {
    Write-Host "No task found: $TaskName" -ForegroundColor DarkGray
  }
  exit 0
}

# -----------------------------------------------
# VALIDATE SCRIPT EXISTS
# -----------------------------------------------
if (-not (Test-Path $FullScriptPath)) {
  Write-Host ""
  Write-Host "============================================================" -ForegroundColor Red
  Write-Host " ERROR: Watcher script not found!" -ForegroundColor Red
  Write-Host "============================================================" -ForegroundColor Red
  Write-Host " Expected: $FullScriptPath" -ForegroundColor Yellow
  Write-Host ""
  Write-Host " Copy the scripts folder from your Mac to:" -ForegroundColor Cyan
  Write-Host "   $ScriptsFolder\" -ForegroundColor Cyan
  Write-Host ""
  Write-Host " Then run this setup script again." -ForegroundColor Cyan
  Write-Host "============================================================" -ForegroundColor Red
  exit 1
}

# -----------------------------------------------
# CREATE SCHEDULED TASK
# -----------------------------------------------
try {
  Write-Host ""
  Write-Host "Creating scanner watcher scheduled task..." -ForegroundColor Cyan

  # Remove existing task if it exists (for updates)
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

  # Build the action: run PowerShell with the watcher script
  # -NonInteractive and -WindowStyle Minimized keep it running quietly in background
  $Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NonInteractive -ExecutionPolicy Bypass -WindowStyle Minimized -File `"$FullScriptPath`"" `
    -WorkingDirectory $ScriptsFolder

  # Trigger: on user login
  $Trigger = New-ScheduledTaskTrigger -AtLogOn

  # Settings: restart on failure, run indefinitely
  $Settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0) `
    -RestartCount 5 `
    -RestartInterval (New-TimeSpan -Minutes 2) `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable

  # Principal: run as the current user
  $Principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Highest

  # Register the task
  Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Principal $Principal `
    -Description "RestaurantAdmin: Automatically start the receipt scanner watcher on login." `
    -Force | Out-Null

  Write-Host ""
  Write-Host "============================================================" -ForegroundColor Green
  Write-Host " SUCCESS! Scanner watcher will auto-start on every login." -ForegroundColor Green
  Write-Host "============================================================" -ForegroundColor Green
  Write-Host " Task name  : $TaskName" -ForegroundColor White
  Write-Host " Script     : $FullScriptPath" -ForegroundColor White
  Write-Host " Trigger    : On login (for user: $env:USERNAME)" -ForegroundColor White
  Write-Host ""
  Write-Host " The task will restart automatically if the script crashes." -ForegroundColor DarkGray
  Write-Host " To start it now (without logging out):" -ForegroundColor Cyan
  Write-Host "   Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
  Write-Host " To check status:" -ForegroundColor Cyan
  Write-Host "   .\setup_scanner_autostart.ps1 -Status" -ForegroundColor White
  Write-Host " To remove:" -ForegroundColor Cyan
  Write-Host "   .\setup_scanner_autostart.ps1 -Remove" -ForegroundColor White
  Write-Host "============================================================" -ForegroundColor Green

} catch {
  Write-Host ""
  Write-Host "ERROR creating scheduled task: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Make sure you're running PowerShell as Administrator." -ForegroundColor Yellow
  exit 1
}
