
# =============================================================
#  RestaurantAdmin — MASTER SETUP SCRIPT
#  Version 1.0
# =============================================================
#
# Run this ONCE on your Windows PC (as Administrator) to set up
# everything automatically:
#
#   1. Creates all required folders
#   2. Sets SCANNER_SECRET environment variable
#   3. Registers the scanner watcher to auto-start on login
#   4. Adds the admin website to auto-start on login
#   5. Configures ScanSnap Home save folder
#   6. Verifies everything is working
#
# HOW TO RUN:
#   Right-click PowerShell -> Run as Administrator
#   cd C:\RestaurantAdmin
#   .\setup_all.ps1
#
# REQUIREMENTS:
#   - Copy the entire scripts folder to C:\RestaurantAdmin\
#   - Have your SCANNER_SECRET ready (from Supabase Dashboard)
# =============================================================

param(
  [string]$ScannerSecretValue = "",
  [switch]$Status,
  [switch]$Uninstall
)

# -----------------------------------------------
# COLORS / HELPERS
# -----------------------------------------------
function Write-Step  { param($n, $msg) Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "    ✓ $msg" -ForegroundColor Green }
function Write-WARN  { param($msg) Write-Host "    ! $msg" -ForegroundColor Yellow }
function Write-ERR   { param($msg) Write-Host "    ✗ $msg" -ForegroundColor Red }
function Write-INFO  { param($msg) Write-Host "    → $msg" -ForegroundColor DarkGray }

$ScriptsFolder   = "C:\RestaurantAdmin"
$WatchFolder     = "$ScriptsFolder\ReceiptScans"
$ProcessedFolder = "$WatchFolder\Processed"
$WatcherScript   = "$ScriptsFolder\powershell_watcher_edge.ps1"
$AdminUrl        = "https://restaurantadmin-62asc7a0x-youssefs-projects-e4f54780.vercel.app"
$TaskName        = "RestaurantAdmin-ScannerWatcher"
$BrowserTaskName = "RestaurantAdmin-OpenBrowser"

# -----------------------------------------------
# STATUS MODE
# -----------------------------------------------
if ($Status) {
  Write-Host "`n============ RestaurantAdmin Status ============" -ForegroundColor Cyan

  # Folders
  Write-Host "`nFolders:"
  foreach ($f in @($ScriptsFolder, $WatchFolder, $ProcessedFolder)) {
    if (Test-Path $f) { Write-OK $f } else { Write-ERR "Missing: $f" }
  }

  # Scanner Secret
  Write-Host "`nScanner Secret:"
  if ($env:SCANNER_SECRET) { Write-OK "SCANNER_SECRET is set" }
  else { Write-ERR "SCANNER_SECRET is NOT set (notifications won't work)" }

  # Watcher task
  Write-Host "`nScanner Watcher Task:"
  $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  if ($t) {
    Write-OK "Task exists - State: $($t.State)"
    $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($info) { Write-INFO "Last run: $($info.LastRunTime) | Result: $($info.LastTaskResult)" }
  } else { Write-ERR "Task not found" }

  # Browser task
  Write-Host "`nAuto-Open Browser Task:"
  $b = Get-ScheduledTask -TaskName $BrowserTaskName -ErrorAction SilentlyContinue
  if ($b) { Write-OK "Task exists - State: $($b.State)" }
  else { Write-ERR "Task not found" }

  # Watcher script
  Write-Host "`nWatcher Script:"
  if (Test-Path $WatcherScript) { Write-OK $WatcherScript }
  else { Write-ERR "Missing: $WatcherScript" }

  Write-Host "`n================================================`n" -ForegroundColor Cyan
  exit 0
}

# -----------------------------------------------
# UNINSTALL MODE
# -----------------------------------------------
if ($Uninstall) {
  Write-Host "`n=== Removing RestaurantAdmin auto-start tasks ===" -ForegroundColor Yellow
  foreach ($t in @($TaskName, $BrowserTaskName)) {
    Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue
    Write-WARN "Removed task: $t"
  }
  Write-Host "Done. Folders and files are kept." -ForegroundColor Yellow
  exit 0
}

# -----------------------------------------------
# BANNER
# -----------------------------------------------
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   RestaurantAdmin — One-Click Setup           ║" -ForegroundColor Cyan
Write-Host "║   ScanSnap iX100 + Auto-Start + Notifications ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------
# STEP 1: Create Folders
# -----------------------------------------------
Write-Step "1/6" "Creating required folders..."
foreach ($f in @($WatchFolder, $ProcessedFolder)) {
  if (-not (Test-Path $f)) {
    New-Item -ItemType Directory -Path $f -Force | Out-Null
    Write-OK "Created: $f"
  } else {
    Write-OK "Already exists: $f"
  }
}

# -----------------------------------------------
# STEP 2: Scanner Secret
# -----------------------------------------------
Write-Step "2/6" "Setting up Scanner Secret..."

$currentSecret = [System.Environment]::GetEnvironmentVariable("SCANNER_SECRET", "User")

if ($ScannerSecretValue -and $ScannerSecretValue.Length -gt 5) {
  [System.Environment]::SetEnvironmentVariable("SCANNER_SECRET", $ScannerSecretValue, "User")
  $env:SCANNER_SECRET = $ScannerSecretValue
  Write-OK "SCANNER_SECRET saved permanently"
} elseif ($currentSecret) {
  Write-OK "SCANNER_SECRET already set (using existing value)"
  $env:SCANNER_SECRET = $currentSecret
} else {
  Write-WARN "SCANNER_SECRET not provided!"
  Write-Host ""
  $secret = Read-Host "    Enter your SCANNER_SECRET (from Supabase Dashboard -> Edge Functions -> Secrets)"
  if ($secret.Length -gt 5) {
    [System.Environment]::SetEnvironmentVariable("SCANNER_SECRET", $secret, "User")
    $env:SCANNER_SECRET = $secret
    Write-OK "SCANNER_SECRET saved permanently"
  } else {
    Write-ERR "No secret provided — online/offline notifications will NOT work"
    Write-INFO "You can set it later: setx SCANNER_SECRET `"your-secret`""
  }
}

# -----------------------------------------------
# STEP 3: Scanner Watcher Auto-Start (Task Scheduler)
# -----------------------------------------------
Write-Step "3/6" "Setting up Scanner Watcher to auto-start..."

if (-not (Test-Path $WatcherScript)) {
  Write-ERR "Watcher script not found at: $WatcherScript"
  Write-INFO "Make sure powershell_watcher_edge.ps1 is in C:\RestaurantAdmin\"
} else {
  try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

    $Action = New-ScheduledTaskAction `
      -Execute "powershell.exe" `
      -Argument "-NonInteractive -ExecutionPolicy Bypass -WindowStyle Minimized -File `"$WatcherScript`"" `
      -WorkingDirectory $ScriptsFolder

    $Trigger = New-ScheduledTaskTrigger -AtLogOn

    $Settings = New-ScheduledTaskSettingsSet `
      -ExecutionTimeLimit (New-TimeSpan -Hours 0) `
      -RestartCount 5 `
      -RestartInterval (New-TimeSpan -Minutes 2) `
      -MultipleInstances IgnoreNew `
      -StartWhenAvailable

    $Principal = New-ScheduledTaskPrincipal `
      -UserId $env:USERNAME `
      -LogonType Interactive `
      -RunLevel Highest

    Register-ScheduledTask `
      -TaskName $TaskName `
      -Action $Action `
      -Trigger $Trigger `
      -Settings $Settings `
      -Principal $Principal `
      -Description "RestaurantAdmin: Auto-start receipt scanner watcher on login." `
      -Force | Out-Null

    Write-OK "Scanner watcher will auto-start on every login"
    Write-INFO "Auto-restarts if it crashes (up to 5 times, every 2 min)"
  } catch {
    Write-ERR "Failed to create task: $($_.Exception.Message)"
  }
}

# -----------------------------------------------
# STEP 4: Auto-Open Admin Website on Login
# -----------------------------------------------
Write-Step "4/6" "Setting up Admin Website to auto-open in browser..."

try {
  Unregister-ScheduledTask -TaskName $BrowserTaskName -Confirm:$false -ErrorAction SilentlyContinue

  # Delay of 10 seconds after login to let desktop settle before opening browser
  $BrowserAction = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c timeout /t 10 /nobreak >nul && start `"`" `"$AdminUrl`""

  $BrowserTrigger = New-ScheduledTaskTrigger -AtLogOn

  $BrowserSettings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2) `
    -MultipleInstances IgnoreNew

  $BrowserPrincipal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive

  Register-ScheduledTask `
    -TaskName $BrowserTaskName `
    -Action $BrowserAction `
    -Trigger $BrowserTrigger `
    -Settings $BrowserSettings `
    -Principal $BrowserPrincipal `
    -Description "RestaurantAdmin: Open admin website in browser on login." `
    -Force | Out-Null

  Write-OK "Admin website will auto-open in browser on every login"
  Write-INFO "URL: $AdminUrl"
} catch {
  Write-ERR "Failed to create browser task: $($_.Exception.Message)"
}

# -----------------------------------------------
# STEP 5: ScanSnap Home Folder Configuration
# -----------------------------------------------
Write-Step "5/6" "Checking ScanSnap Home setup..."

$scanSnapPaths = @(
  "$env:LOCALAPPDATA\PFU\ScanSnap Home",
  "$env:ProgramFiles\PFU\ScanSnap Home",
  "${env:ProgramFiles(x86)}\PFU\ScanSnap Home"
)

$scanSnapFound = $scanSnapPaths | Where-Object { Test-Path $_ }

if ($scanSnapFound) {
  Write-OK "ScanSnap Home found"
  Write-WARN "You must configure the Save Folder manually in ScanSnap Home:"
  Write-Host ""
  Write-Host "    MANUAL STEP REQUIRED:" -ForegroundColor Yellow
  Write-Host "    ┌─────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
  Write-Host "    │ 1. Open ScanSnap Home                               │" -ForegroundColor DarkGray
  Write-Host "    │ 2. Go to: ☰ Menu → Preferences → General           │" -ForegroundColor DarkGray
  Write-Host "    │ 3. Enable: 'Start ScanSnap Home when Windows starts'│" -ForegroundColor DarkGray
  Write-Host "    │ 4. Click your Profile → Edit Profile                │" -ForegroundColor DarkGray
  Write-Host "    │ 5. Set 'Save to' folder to:                         │" -ForegroundColor DarkGray
  Write-Host "    │      C:\RestaurantAdmin\ReceiptScans                │" -ForegroundColor White
  Write-Host "    │ 6. Set File Format to: PDF (or JPEG)                │" -ForegroundColor DarkGray
  Write-Host "    │ 7. Set Scanning Side: Both Sides or Single Side     │" -ForegroundColor DarkGray
  Write-Host "    │ 8. Click 'Save'                                     │" -ForegroundColor DarkGray
  Write-Host "    └─────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
  Write-Host ""

  # Copy the save path to clipboard for easy pasting in ScanSnap Home
  "C:\RestaurantAdmin\ReceiptScans" | Set-Clipboard
  Write-OK "Save folder path copied to clipboard - just paste it in ScanSnap Home!"
} else {
  Write-WARN "ScanSnap Home not found in standard paths"
  Write-INFO "Make sure ScanSnap Home is installed, then configure it manually:"
  Write-INFO "  Save folder: C:\RestaurantAdmin\ReceiptScans"
}

# -----------------------------------------------
# STEP 6: Start Everything Now (Optional)
# -----------------------------------------------
Write-Step "6/6" "Starting everything now..."

# Start the watcher task immediately
try {
  Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop
  Write-OK "Scanner watcher started now (running in background)"
} catch {
  Write-WARN "Could not start watcher now: $($_.Exception.Message)"
  Write-INFO "It will start automatically on next login"
}

# Open browser now
try {
  Start-Process $AdminUrl
  Write-OK "Admin website opened in your browser"
} catch {
  Write-WARN "Could not open browser now"
  Write-INFO "Open manually: $AdminUrl"
}

# -----------------------------------------------
# FINAL SUMMARY
# -----------------------------------------------
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║         SETUP COMPLETE!                       ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host " From now on, every time you start Windows:" -ForegroundColor White
Write-Host "   🟢 ScanSnap Home opens automatically (after manual setup)" -ForegroundColor DarkGray
Write-Host "   📡 Scanner watcher starts in background" -ForegroundColor DarkGray
Write-Host "   🌐 Admin website opens in browser (after 10s delay)" -ForegroundColor DarkGray
Write-Host "   📱 You'll get push notifications on your phone" -ForegroundColor DarkGray
Write-Host ""
Write-Host " Workflow:" -ForegroundColor White
Write-Host "   1. Put receipt in ScanSnap iX100" -ForegroundColor DarkGray
Write-Host "   2. Press scan button" -ForegroundColor DarkGray
Write-Host "   3. File saved to C:\RestaurantAdmin\ReceiptScans\" -ForegroundColor DarkGray
Write-Host "   4. Watcher uploads + AI processes receipt" -ForegroundColor DarkGray
Write-Host "   5. Receipt appears in admin website" -ForegroundColor DarkGray
Write-Host "   6. Push notification sent to phone 📱" -ForegroundColor DarkGray
Write-Host ""
Write-Host " Run '.\setup_all.ps1 -Status' anytime to check status" -ForegroundColor Cyan
Write-Host ""
