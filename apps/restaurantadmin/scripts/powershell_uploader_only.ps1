
# PowerShell Receipt Uploader (Simple Mode)
# Version 1.0 - No AI, No Order Creation
# 
# WHAT THIS DOES:
#   Receipt gets scanned -> Image uploaded to Supabase Storage -> Shows in Receipt Watcher screen
#
# WHAT THIS DOES NOT DO:
#   - No Gemini AI processing
#   - No order creation
#   - No purchase creation
#
# HOW TO RUN:
#   1. Set your SUPABASE_ANON_KEY environment variable (one-time):
#        setx SUPABASE_ANON_KEY "your-anon-key-here"
#   2. Open PowerShell and run:
#        cd C:\RestaurantAdmin
#        .\powershell_uploader_only.ps1

# -------------------------------
# CONFIGURATION
# -------------------------------
$WatcherPath   = "C:\RestaurantAdmin\ReceiptScans"
$ProcessedPath = Join-Path $WatcherPath "Processed"
$Filters       = @("*.jpg", "*.jpeg", "*.png", "*.heic")

# Supabase project config
$SupabaseUrl    = "https://iluhlynzkgubtaswvgwt.supabase.co"
$StorageBucket  = "scanned-receipts"      # Must match bucket name in Supabase Storage
$AnonKey        = $env:SUPABASE_ANON_KEY  # Set via: setx SUPABASE_ANON_KEY "..."

# Optional: label receipts with a brand name (shows in the Receipt Watcher UI)
$DefaultBrandName = "DEVILS SMASH BURGER"

# Heartbeat
$HeartbeatUrl             = "$SupabaseUrl/functions/v1/scanner-heartbeat"
$HeartbeatIntervalSeconds = 30
$ScannerId   = "$($env:COMPUTERNAME)-uploader"
$ScannerName = "Receipt Uploader ($($env:COMPUTERNAME))"

# -------------------------------
# VALIDATION
# -------------------------------
if ([string]::IsNullOrWhiteSpace($AnonKey)) {
  Write-Host "ERROR: SUPABASE_ANON_KEY environment variable is not set." -ForegroundColor Red
  Write-Host "Set it once with: setx SUPABASE_ANON_KEY `"your-anon-key-here`"" -ForegroundColor Yellow
  Write-Host "Then close and reopen PowerShell." -ForegroundColor Yellow
  exit 1
}

# -------------------------------
# HELPERS
# -------------------------------
function Ensure-Dir {
  param([string]$Path)
  if (-not [string]::IsNullOrWhiteSpace($Path) -and -not (Test-Path $Path)) {
    New-Item -Path $Path -ItemType Directory | Out-Null
  }
}

function Get-AuthHeaders {
  return @{
    "apikey"        = $AnonKey
    "Authorization" = "Bearer $AnonKey"
    "Content-Type"  = "application/json"
  }
}

# -------------------------------
# HEARTBEAT
# -------------------------------
$script:HeartbeatTimer = $null
$script:EventSubs      = @()

function Send-Heartbeat {
  param([string]$Action = "heartbeat")
  try {
    $body = @{
      scanner_id   = $ScannerId
      scanner_name = $ScannerName
      hostname     = $env:COMPUTERNAME
      watch_path   = $WatcherPath
      action       = $Action
    } | ConvertTo-Json -Depth 3

    $h = Get-AuthHeaders
    Invoke-RestMethod -Uri $HeartbeatUrl -Method Post -Headers $h -Body $body -TimeoutSec 10 | Out-Null

    if ($Action -eq "startup")  { Write-Host "Scanner: ONLINE" -ForegroundColor Green }
    if ($Action -eq "shutdown") { Write-Host "Scanner: OFFLINE" -ForegroundColor Yellow }
  } catch {
    if ($Action -ne "heartbeat") {
      Write-Host "Heartbeat warning: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
  }
}

function Start-Heartbeat {
  $script:HeartbeatTimer          = New-Object Timers.Timer
  $script:HeartbeatTimer.Interval = $HeartbeatIntervalSeconds * 1000
  $script:HeartbeatTimer.AutoReset = $true
  $sub = Register-ObjectEvent -InputObject $script:HeartbeatTimer -EventName Elapsed -Action { Send-Heartbeat }
  $script:EventSubs += $sub
  $script:HeartbeatTimer.Start()
  Write-Host "Heartbeat: every ${HeartbeatIntervalSeconds}s" -ForegroundColor DarkGray
}

function Stop-All {
  Write-Host "`nStopping..." -ForegroundColor Yellow
  Send-Heartbeat -Action "shutdown"
  if ($script:HeartbeatTimer) { $script:HeartbeatTimer.Stop() }
  foreach ($sub in $script:EventSubs) {
    try {
      if ($sub -is [System.Management.Automation.PSEventJob]) {
        Unregister-Event -SubscriptionId $sub.Id -ErrorAction SilentlyContinue
      }
    } catch {}
  }
  Write-Host "Stopped." -ForegroundColor Yellow
}

$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Stop-All }

# -------------------------------
# DUPLICATE GUARD
# -------------------------------
$script:ProcessedFiles = @{}

function Get-FileKey {
  param([string]$Path)
  try {
    $f = Get-Item -LiteralPath $Path -ErrorAction Stop
    return "$($f.Length):$($f.LastWriteTimeUtc.Ticks):$($f.Name)"
  } catch { return [guid]::NewGuid().ToString() }
}

# -------------------------------
# CORE: UPLOAD + INSERT
# -------------------------------
function Upload-Receipt {
  param([string]$FilePath)

  if (-not (Test-Path -LiteralPath $FilePath)) { return }

  $name = [IO.Path]::GetFileName($FilePath)
  $ext  = [IO.Path]::GetExtension($name).ToLower()
  if ($ext -notin @('.jpg','.jpeg','.png','.heic')) { return }

  # Dedup check
  $key = Get-FileKey -Path $FilePath
  if ($script:ProcessedFiles.ContainsKey($FilePath) -and $script:ProcessedFiles[$FilePath] -eq $key) {
    return
  }

  Write-Host "----------------------------------------------"
  Write-Host "New receipt: $name" -ForegroundColor Yellow

  # Wait for file to finish writing (scanner may still be writing)
  $attempts = 0
  $prevSize = -1
  while ($attempts -lt 40) {
    try {
      $fi      = Get-Item -LiteralPath $FilePath -ErrorAction Stop
      $curSize = $fi.Length
      $stream  = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
      $stream.Close()
      if ($curSize -eq $prevSize) { break }
      $prevSize = $curSize
    } catch {}
    Start-Sleep -Milliseconds 250
    $attempts++
  }

  $script:ProcessedFiles[$FilePath] = Get-FileKey -Path $FilePath

  # --- STEP 1: Upload image to Supabase Storage ---
  $timestamp   = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $storagePath = "receipts/$timestamp-$name"   # Path inside the bucket
  $uploadUrl   = "$SupabaseUrl/storage/v1/object/$StorageBucket/$storagePath"

  # Detect content type
  $contentType = switch ($ext) {
    ".png"  { "image/png" }
    ".heic" { "image/heic" }
    default { "image/jpeg" }
  }

  try {
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)

    $uploadHeaders = @{
      "apikey"        = $AnonKey
      "Authorization" = "Bearer $AnonKey"
      "Content-Type"  = $contentType
      "x-upsert"      = "true"
    }

    Write-Host "Uploading to Storage..." -ForegroundColor Cyan
    Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $uploadHeaders -Body $bytes -TimeoutSec 60 | Out-Null
    Write-Host "Uploaded: $storagePath" -ForegroundColor Green
  } catch {
    Write-Host "UPLOAD FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "----------------------------------------------"
    return
  }

  # --- STEP 2: Insert a row into scanned_receipts table ---
  $insertUrl = "$SupabaseUrl/rest/v1/scanned_receipts"

  $rowBody = @{
    scan_type  = "order"            # Shows under 'order' tab; change to "purchase" if needed
    storage_path = $storagePath
    brand_name = $DefaultBrandName
  } | ConvertTo-Json -Depth 3

  $insertHeaders = @{
    "apikey"        = $AnonKey
    "Authorization" = "Bearer $AnonKey"
    "Content-Type"  = "application/json"
    "Prefer"        = "return=minimal"
  }

  try {
    Write-Host "Saving to database..." -ForegroundColor Cyan
    Invoke-RestMethod -Uri $insertUrl -Method Post -Headers $insertHeaders -Body $rowBody -TimeoutSec 30 | Out-Null
    Write-Host "Saved! Receipt will now appear in the Receipt Watcher screen." -ForegroundColor Green
  } catch {
    Write-Host "DB INSERT FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "----------------------------------------------"
    return
  }

  # --- STEP 3: Move to Processed folder ---
  try {
    $dest = Join-Path $ProcessedPath $name
    Move-Item -LiteralPath $FilePath -Destination $dest -Force
    Write-Host "Moved to: Processed/$name" -ForegroundColor DarkGreen
  } catch {
    Write-Host "Could not move file (it stays in place): $($_.Exception.Message)" -ForegroundColor DarkYellow
  }

  Write-Host "----------------------------------------------"
}

# -------------------------------
# FILE WATCHER SETUP
# -------------------------------
function Start-Watcher {
  Ensure-Dir -Path $WatcherPath
  Ensure-Dir -Path $ProcessedPath

  $fsw = New-Object System.IO.FileSystemWatcher
  $fsw.Path                  = $WatcherPath
  $fsw.Filter                = '*.*'
  $fsw.IncludeSubdirectories = $false
  $fsw.NotifyFilter          = [IO.NotifyFilters]::FileName -bor [IO.NotifyFilters]::LastWrite

  $handler = {
    param($sender, $e)
    if ($e.FullPath) {
      Upload-Receipt -FilePath $e.FullPath
    }
  }

  $s1 = Register-ObjectEvent -InputObject $fsw -EventName Created -Action $handler
  $s2 = Register-ObjectEvent -InputObject $fsw -EventName Renamed -Action $handler
  $script:EventSubs += @($s1, $s2, $fsw)

  # Polling fallback every 3 seconds (catches files already in folder when script starts)
  $pollTimer          = New-Object Timers.Timer
  $pollTimer.Interval = 3000
  $pollTimer.AutoReset = $true
  $pollAction = {
    Get-ChildItem -LiteralPath $WatcherPath -File | Where-Object {
      $_.Extension.ToLower() -in @('.jpg','.jpeg','.png','.heic')
    } | ForEach-Object {
      Upload-Receipt -FilePath $_.FullName
    }
  }
  $s3 = Register-ObjectEvent -InputObject $pollTimer -EventName Elapsed -Action $pollAction
  $pollTimer.Start()
  $script:EventSubs += @($s3, $pollTimer)

  $fsw.EnableRaisingEvents = $true
  return $fsw
}

# -------------------------------
# MAIN
# -------------------------------
Write-Host "=============================================" -ForegroundColor Green
Write-Host " RestaurantAdmin — Receipt Uploader (Simple)" -ForegroundColor Green
Write-Host " No AI | No Orders | Just Photo -> App      " -ForegroundColor Green
Write-Host "============================================="
Write-Host ""
Write-Host "Watch folder : $WatcherPath"
Write-Host "Storage      : $StorageBucket/receipts/"
Write-Host "Brand label  : $DefaultBrandName"
Write-Host ""

Send-Heartbeat -Action "startup"
Start-Heartbeat
Start-Watcher | Out-Null

Write-Host "Watching for new receipts... Press CTRL+C to stop." -ForegroundColor Cyan
Write-Host ""

try {
  while ($true) { Wait-Event -Timeout 5 }
} finally {
  Stop-All
}
