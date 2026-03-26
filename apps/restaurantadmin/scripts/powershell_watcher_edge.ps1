
# PowerShell Watcher Script for RestaurantAdmin Receipt Scanner to Supabase Edge Function
# Version 2.0 (Edge Function Communication + Heartbeat Monitoring)
# Monitors one or two folders and sends new images to the Supabase Edge Function `scan-receipt`.
# Sends heartbeats every 30 seconds to track scanner online/offline status.

# -------------------------------
# CONFIGURATION
# -------------------------------
# Single folder to watch (orders + purchases together). Create if it doesn't exist.
$WatcherPath = "C:\RestaurantAdmin\ReceiptScans"

# File types to watch
$Filters = @("*.jpg", "*.jpeg", "*.png", "*.heic")

# Processed folder (files moved here on success)
$ProcessedPath = Join-Path $WatcherPath "Processed"

# Supabase Edge Function endpoints
$EdgeUrl = "https://iluhlynzkgubtaswvgwt.supabase.co/functions/v1/scan-receipt"
$HeartbeatUrl = "https://iluhlynzkgubtaswvgwt.supabase.co/functions/v1/scanner-heartbeat"

# Heartbeat interval in seconds (send status every 30 seconds)
$HeartbeatIntervalSeconds = 30

# Scanner identification (unique per machine)
$ScannerId = "$($env:COMPUTERNAME)-receipt-scanner"
$ScannerName = "Receipt Scanner ($($env:COMPUTERNAME))"

# Auth options:
# Prefer scanner secret (no JWT rotation). Set once:  setx SCANNER_SECRET "YOUR_SCANNER_SECRET"
$ScannerSecret = $env:SCANNER_SECRET
# Or use user JWT (not recommended for long-running watchers): setx AUTH_TOKEN "YOUR_USER_JWT"
$AuthToken = $env:AUTH_TOKEN
# Project anon key (public). Get from Supabase Dashboard → Project Settings → API → anon public
# Set once: setx SUPABASE_ANON_KEY "YOUR_ANON_KEY"
$AnonKey = $env:SUPABASE_ANON_KEY

# Optional: default brand context for quicker testing
$DefaultBrandName = "DEVILS SMASH BURGER"
# Quick sanity logs
if ($ScannerSecret) { Write-Host "Auth mode: Scanner-Secret" -ForegroundColor Cyan } elseif ($AuthToken) { Write-Host "Auth mode: User JWT" -ForegroundColor Yellow } else { Write-Host "Auth mode: NONE (will fail)" -ForegroundColor Red }
Write-Host "Edge URL: $EdgeUrl" -ForegroundColor DarkCyan
Write-Host "Heartbeat URL: $HeartbeatUrl" -ForegroundColor DarkCyan
Write-Host "Scanner ID: $ScannerId" -ForegroundColor DarkCyan

$DefaultBrandId   = $null  # e.g., "4446a388-aaa7-402f-be4d-b82b23797415"

# Keep global references so event subscriptions are not garbage collected
if (-not $script:EventSubscriptions) { $script:EventSubscriptions = @() }
# Track processed files (path -> lastwrite ticks) to avoid duplicate sends
if (-not $script:ProcessedFiles) { $script:ProcessedFiles = @{} }
# Heartbeat timer reference
$script:HeartbeatTimer = $null

# -------------------------------
# Helpers
# -------------------------------
function Ensure-Dir {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return }
  if (-not (Test-Path -Path $Path)) {
    New-Item -Path $Path -ItemType Directory | Out-Null
  }
}

# -------------------------------
# HEARTBEAT FUNCTIONS
# -------------------------------
function Send-Heartbeat {
  param(
    [string]$Action = "heartbeat"  # 'heartbeat', 'startup', 'shutdown'
  )

  if ([string]::IsNullOrWhiteSpace($ScannerSecret) -and [string]::IsNullOrWhiteSpace($AnonKey)) {
    # Silently skip if no auth configured
    return
  }

  try {
    $payload = @{
      scanner_id = $ScannerId
      scanner_name = $ScannerName
      hostname = $env:COMPUTERNAME
      watch_path = $WatcherPath
      action = $Action
    }

    $json = $payload | ConvertTo-Json -Depth 5

    $headers = @{ "Content-Type" = "application/json" }
    if ($ScannerSecret) { $headers["X-Scanner-Secret"] = $ScannerSecret }
    if ($AnonKey)       { $headers["apikey"] = $AnonKey; $headers["Authorization"] = "Bearer $AnonKey" }

    $response = Invoke-RestMethod -Uri $HeartbeatUrl -Method Post -Headers $headers -Body $json -TimeoutSec 10
    
    if ($Action -eq "startup") {
      Write-Host "Heartbeat: Scanner registered as ONLINE" -ForegroundColor Green
    } elseif ($Action -eq "shutdown") {
      Write-Host "Heartbeat: Scanner marked as OFFLINE" -ForegroundColor Yellow
    }
    # Silent for regular heartbeats to avoid spam
  } catch {
    # Silently ignore heartbeat errors to not spam the console
    if ($Action -ne "heartbeat") {
      Write-Host "Heartbeat warning: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
  }
}

function Start-HeartbeatTimer {
  # Create a timer that sends heartbeat every 30 seconds
  $script:HeartbeatTimer = New-Object Timers.Timer
  $script:HeartbeatTimer.Interval = $HeartbeatIntervalSeconds * 1000
  $script:HeartbeatTimer.AutoReset = $true

  $heartbeatAction = {
    Send-Heartbeat -Action "heartbeat"
  }

  $script:HeartbeatTimerSub = Register-ObjectEvent -InputObject $script:HeartbeatTimer -EventName Elapsed -Action $heartbeatAction
  $script:EventSubscriptions += @($script:HeartbeatTimerSub, $script:HeartbeatTimer)
  $script:HeartbeatTimer.Start()
  
  Write-Host "Heartbeat timer started (every ${HeartbeatIntervalSeconds}s)" -ForegroundColor DarkGreen
}

function Stop-HeartbeatAndCleanup {
  Write-Host "`nShutting down scanner..." -ForegroundColor Yellow
  
  # Send shutdown heartbeat
  Send-Heartbeat -Action "shutdown"
  
  # Stop heartbeat timer
  if ($script:HeartbeatTimer) {
    $script:HeartbeatTimer.Stop()
  }
  
  # Unregister all event subscriptions
  foreach ($sub in $script:EventSubscriptions) {
    try {
      if ($sub -is [System.Management.Automation.PSEventJob]) {
        Unregister-Event -SubscriptionId $sub.Id -ErrorAction SilentlyContinue
      }
    } catch {}
  }
  
  Write-Host "Scanner stopped." -ForegroundColor Yellow
}

# Register cleanup handler for Ctrl+C
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
  Stop-HeartbeatAndCleanup
}

# Also try to catch Ctrl+C (may not always work in all PowerShell hosts)
try {
  [Console]::TreatControlCAsInput = $false
} catch {}

function New-IdempotencyKey {
  param([string]$ImagePath)
  try {
    $file = Get-Item -LiteralPath $ImagePath -ErrorAction Stop
    $size = $file.Length
    $ts = $file.LastWriteTimeUtc.Ticks
    $name = $file.Name
    return "${size}:${ts}:${name}"
  } catch { return [guid]::NewGuid().ToString() }
}
function Process-Path {
  param(
    [Parameter(Mandatory=$true)][string]$FilePath,
    [string]$BrandName,
    [string]$BrandId,
    [Parameter(Mandatory=$true)][string]$ProcessedPath
  )

  if (-not (Test-Path -LiteralPath $FilePath)) { return }
  $name = [IO.Path]::GetFileName($FilePath)
  $ext = [IO.Path]::GetExtension($name).ToLower()
  if ($ext -notin @('.jpg','.jpeg','.png','.heic')) { return }

  try {
    Write-Host "----------------------------------------------"
    Write-Host "Detected: $name" -ForegroundColor Yellow

    # Dedupe by last-write ticks
    $lastWrite = (Get-Item -LiteralPath $FilePath -ErrorAction SilentlyContinue).LastWriteTimeUtc.Ticks
    if ($script:ProcessedFiles.ContainsKey($FilePath)) {
      if ($script:ProcessedFiles[$FilePath] -eq $lastWrite) {
        Write-Host "Skipping duplicate event for $name" -ForegroundColor DarkYellow
        return
      }
    }

    # Wait until the file is unlocked and size stabilizes
    $attempts = 0
    $prevSize = -1
    while ($attempts -lt 40) {
      try {
        $fi = Get-Item -LiteralPath $FilePath -ErrorAction Stop
        $sizeNow = $fi.Length
        $s = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
        $s.Close()
        if ($sizeNow -eq $prevSize) { break }
        $prevSize = $sizeNow
      } catch {}
      Start-Sleep -Milliseconds 250
      $attempts++
    }

    $script:ProcessedFiles[$FilePath] = (Get-Item -LiteralPath $FilePath -ErrorAction SilentlyContinue).LastWriteTimeUtc.Ticks

    $ok = Send-ImageToEdge -ImagePath $FilePath -BrandName $BrandName -BrandId $BrandId
    if ($ok) {
      $dest = Join-Path $ProcessedPath $name
      Move-Item -LiteralPath $FilePath -Destination $dest -Force
      Write-Host "Moved to: $dest" -ForegroundColor DarkGreen
    } else {
      Write-Host "Upload failed; leaving file in place." -ForegroundColor DarkRed
    }
  } catch {
    Write-Host "Watcher error: $($_.Exception.Message)" -ForegroundColor Red
  } finally {
    Write-Host "----------------------------------------------"
  }
}


function Send-ImageToEdge {
  param(
    [Parameter(Mandatory=$true)][string]$ImagePath,
    [string]$BrandId,
    [string]$BrandName,
    [string]$PlatformOrderId
  )

  if ([string]::IsNullOrWhiteSpace($ScannerSecret) -and [string]::IsNullOrWhiteSpace($AuthToken)) {
    Write-Host "ERROR: Set one of these environment variables: SCANNER_SECRET (preferred) or AUTH_TOKEN" -ForegroundColor Red
    return $false
  }

  try {
    # Ensure file is not locked
    Start-Sleep -Milliseconds 500

    $bytes = [System.IO.File]::ReadAllBytes($ImagePath)
    $b64 = [System.Convert]::ToBase64String($bytes)

    $payload = @{ receiptImageBase64 = $b64 }
    if ($BrandId)       { $payload.brandId = $BrandId }
    if ($BrandName)     { $payload.brandName = $BrandName }
    if ($PlatformOrderId) { $payload.platformOrderId = $PlatformOrderId }
    $payload.idempotencyKey = New-IdempotencyKey -ImagePath $ImagePath

    $json = $payload | ConvertTo-Json -Depth 5

    $headers = @{ "Content-Type" = "application/json" }
    if ($ScannerSecret) { $headers["X-Scanner-Secret"] = $ScannerSecret }
    # Supabase Functions gateway requires either Authorization: Bearer <anon key> or apikey header
    if ($AnonKey)      { $headers["apikey"]          = $AnonKey; $headers["Authorization"] = "Bearer $AnonKey" }
    if ($AuthToken)    { $headers["Authorization"]   = "Bearer $AuthToken" }

    $targetUrl = $EdgeUrl

    Write-Host "Target Edge URL: $targetUrl" -ForegroundColor DarkCyan

    Write-Host "Sending $($ImagePath) to Edge…" -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri $targetUrl -Method Post -Headers $headers -Body $json -TimeoutSec 90
    Write-Host "Edge response: $([string]::new((ConvertTo-Json $response -Depth 5)))" -ForegroundColor Green
    return $true
  } catch {
    Write-Host "ERROR sending to Edge: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
      try {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $errorText = $reader.ReadToEnd()
        Write-Host "Error details: $errorText" -ForegroundColor DarkRed
      } catch {}
    }
    return $false
  }
}

function New-Watcher {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string[]]$Filters,
    [Parameter(Mandatory=$true)][string]$ProcessedPath
  )

  Ensure-Dir -Path $Path
  Ensure-Dir -Path $ProcessedPath

  # Create a single watcher and filter in the event by extension
  $fsw = New-Object System.IO.FileSystemWatcher
  $fsw.Path = $Path
  $fsw.Filter = '*.*'
  $fsw.IncludeSubdirectories = $false
  $fsw.NotifyFilter = [IO.NotifyFilters]::FileName -bor [IO.NotifyFilters]::LastWrite -bor [IO.NotifyFilters]::CreationTime -bor [IO.NotifyFilters]::Size
  $fsw.IncludeSubdirectories = $true  # be generous; some scanners write temp subfolders

  # Unified handler used for Created/Renamed/Changed events
  $handler = {
    param($sender, $eventArgs)
    $createdPath = $eventArgs.FullPath
 
    if (-not $createdPath) { return }

    # Retrieve message data (values captured at registration time)
    $md = $event.MessageData
    Process-Path -FilePath $createdPath -BrandName $md.BrandName -BrandId $md.BrandId -ProcessedPath $md.ProcessedPath
  }

  # Subscribe to multiple events to catch different write patterns
  $subCreated = Register-ObjectEvent -InputObject $fsw -EventName Created -Action $handler -MessageData @{ BrandName = $DefaultBrandName; BrandId = $DefaultBrandId; ProcessedPath = $ProcessedPath }
  $subRenamed = Register-ObjectEvent -InputObject $fsw -EventName Renamed -Action $handler -MessageData @{ BrandName = $DefaultBrandName; BrandId = $DefaultBrandId; ProcessedPath = $ProcessedPath }
  $subChanged = Register-ObjectEvent -InputObject $fsw -EventName Changed -Action $handler -MessageData @{ BrandName = $DefaultBrandName; BrandId = $DefaultBrandId; ProcessedPath = $ProcessedPath }

  # Extra: manual polling fallback every 2s (in case FS events are blocked)
  $pollTimer = New-Object Timers.Timer
  $pollTimer.Interval = 2000
  $pollTimer.AutoReset = $true
  $pollAction = {
    param($sender, $args)
    Get-ChildItem -LiteralPath $Path -Recurse -File -Include *.jpg, *.jpeg, *.png, *.heic | ForEach-Object {
      $fakeEvent = New-Object PSObject -Property @{ FullPath = $_.FullName; ChangeType = 'Poll' }
      & $handler $null $fakeEvent
    }
  }
  $subTimer = Register-ObjectEvent -InputObject $pollTimer -EventName Elapsed -Action $pollAction -MessageData @{ BrandName = $DefaultBrandName; BrandId = $DefaultBrandId; ProcessedPath = $ProcessedPath }
  $pollTimer.Start()

  # Keep references to prevent GC of subscriptions
  $script:EventSubscriptions += @($subCreated, $subRenamed, $subChanged, $subTimer, $pollTimer)

  # Enable after subscribing
  $fsw.EnableRaisingEvents = $true

  return $fsw
}

# -------------------------------
# MAIN
# -------------------------------
Write-Host "==============================================="
Write-Host " RestaurantAdmin Edge Watcher v2.0             " -ForegroundColor Green
Write-Host " With Heartbeat Monitoring                     " -ForegroundColor Green
Write-Host "==============================================="

# Send startup heartbeat (notifies app that scanner is online)
Send-Heartbeat -Action "startup"

# Start heartbeat timer (sends status every 30 seconds)
Start-HeartbeatTimer

# Create watcher
$watchers = @()
if (-not [string]::IsNullOrWhiteSpace($WatcherPath)) {
  $watchers += New-Watcher -Path $WatcherPath -Filters $Filters -ProcessedPath $ProcessedPath
}

Write-Host "Watching folder: $WatcherPath"
Write-Host "Press CTRL+C to stop."
Write-Host ""
Write-Host "Scanner Status: ONLINE" -ForegroundColor Green
Write-Host "Heartbeat: Every ${HeartbeatIntervalSeconds} seconds" -ForegroundColor DarkGray

# Keep script alive
try {
  while ($true) { Wait-Event -Timeout 5 }
} finally {
  # Cleanup on exit
  Stop-HeartbeatAndCleanup
}




