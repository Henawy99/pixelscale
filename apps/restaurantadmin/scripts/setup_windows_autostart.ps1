
# =============================================================
#  RestaurantAdmin — Windows Auto-Start Setup Script
#  Version 1.0
# =============================================================
#
# WHAT THIS DOES:
#   Adds the RestaurantAdmin Flutter Windows app to the Windows
#   Startup folder so it opens automatically when you log in.
#
# HOW TO RUN (once, as Administrator):
#   Right-click PowerShell → Run as Administrator
#   cd C:\RestaurantAdmin
#   .\setup_windows_autostart.ps1
#
# UNINSTALL:
#   Run with -Remove flag:
#   .\setup_windows_autostart.ps1 -Remove
#
# REQUIREMENTS:
#   The app must already be built and placed at:
#   C:\RestaurantAdmin\restaurantadmin.exe
#   (or update $AppExePath below to point to your actual .exe location)
# =============================================================

param(
  [switch]$Remove
)

# -----------------------------------------------
# CONFIGURATION — update these paths if needed
# -----------------------------------------------
# Path to the built Flutter Windows executable
$AppExePath = "C:\RestaurantAdmin\restaurantadmin.exe"

# Name shown in the Startup folder
$ShortcutName = "RestaurantAdmin"

# Windows Startup folder path (per-user)
$StartupFolder = [System.Environment]::GetFolderPath("Startup")
$ShortcutPath  = Join-Path $StartupFolder "$ShortcutName.lnk"

# -----------------------------------------------
# REMOVE MODE
# -----------------------------------------------
if ($Remove) {
  if (Test-Path $ShortcutPath) {
    Remove-Item $ShortcutPath -Force
    Write-Host "Removed auto-start shortcut: $ShortcutPath" -ForegroundColor Yellow
  } else {
    Write-Host "No auto-start shortcut found at: $ShortcutPath" -ForegroundColor DarkGray
  }
  exit 0
}

# -----------------------------------------------
# VALIDATE APP EXISTS
# -----------------------------------------------
if (-not (Test-Path $AppExePath)) {
  Write-Host ""
  Write-Host "============================================================" -ForegroundColor Red
  Write-Host " ERROR: App executable not found!" -ForegroundColor Red
  Write-Host "============================================================" -ForegroundColor Red
  Write-Host " Expected path: $AppExePath" -ForegroundColor Yellow
  Write-Host ""
  Write-Host " To fix this, either:" -ForegroundColor Cyan
  Write-Host "   1. Build and copy restaurantadmin.exe to C:\RestaurantAdmin\" -ForegroundColor Cyan
  Write-Host "   2. OR edit this script and update the `$AppExePath variable" -ForegroundColor Cyan
  Write-Host ""
  Write-Host " To build the app on your Mac:" -ForegroundColor DarkGray
  Write-Host "   flutter build windows --release" -ForegroundColor DarkGray
  Write-Host "   Then copy build\windows\x64\runner\Release\ to the Windows PC" -ForegroundColor DarkGray
  Write-Host "============================================================" -ForegroundColor Red
  exit 1
}

# -----------------------------------------------
# CREATE STARTUP SHORTCUT
# -----------------------------------------------
try {
  Write-Host ""
  Write-Host "Creating auto-start shortcut..." -ForegroundColor Cyan

  $WScriptShell = New-Object -ComObject WScript.Shell
  $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
  $Shortcut.TargetPath     = $AppExePath
  $Shortcut.WorkingDirectory = [System.IO.Path]::GetDirectoryName($AppExePath)
  $Shortcut.Description    = "RestaurantAdmin — Auto-start on login"
  $Shortcut.WindowStyle    = 1  # Normal window
  $Shortcut.Save()

  Write-Host ""
  Write-Host "============================================================" -ForegroundColor Green
  Write-Host " SUCCESS! RestaurantAdmin will now open on every login." -ForegroundColor Green
  Write-Host "============================================================" -ForegroundColor Green
  Write-Host " Shortcut created at:" -ForegroundColor DarkGray
  Write-Host "   $ShortcutPath" -ForegroundColor White
  Write-Host ""
  Write-Host " To test: Log out and log back in." -ForegroundColor Cyan
  Write-Host " To remove: Run this script with -Remove flag." -ForegroundColor DarkGray
  Write-Host "============================================================" -ForegroundColor Green

} catch {
  Write-Host ""
  Write-Host "ERROR creating shortcut: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Try running this script as Administrator." -ForegroundColor Yellow
  exit 1
}
