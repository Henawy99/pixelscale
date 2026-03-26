import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/config/supabase_config.dart';

/// Service to generate field-specific camera recording scripts (V2)
/// for Raspberry Pi devices at football fields.
/// 
/// V2 Features:
/// - Environment variable configuration
/// - Retry logic with exponential backoff
/// - Local chunk retention until stitch complete
/// - Health heartbeat monitoring
/// - Concurrent recording support
/// - Automatic disk space cleanup
/// - Fallback to raw video if ball tracking fails
class CameraScriptGenerator {
  // Supabase configuration
  // static const String _supabaseUrl = 'https://hlimykvqvhqgfqfpxmiu.supabase.co';
  // static const String _supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhsaW15a3ZxdmhxZ2ZxZnB4bWl1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI0NDQ1OTAsImV4cCI6MjA0ODAyMDU5MH0.u1HNSxCTyZ5RCWiY1PJShv0MoxomYyS2oRGfvSn7r6w';
  
  /// Generate the complete Python script for a football field (V2)
  static String generateScript(FootballField field) {
    final supabaseUrl = SupabaseConfig.supabaseUrl;
    final supabaseKey = SupabaseConfig.supabaseAnonKey;

    if (!field.hasCamera && (field.cameraIpAddress == null || field.cameraIpAddress!.isEmpty)) {
      throw Exception('Field does not have camera configured');
    }
    // Setup logs table listener - we don't need to change anything here as the 
    // AdminCameraMonitoringScreen handles log subscription
    
    // For logging to work, the Python script's SupabaseLogHandler
    // must be successfully inserting into 'camera_logs' table.
    // 
    // The python script uses:
    // requests.post(f"{self.url}/rest/v1/camera_logs", headers=self.headers, json=to_send, timeout=5)
    
    // If logs aren't showing, ensure:
    // 1. camera_logs table exists (migration was run)
    // 2. Python script has correct SUPABASE_URL/KEY
    // 3. Pi has internet access
    
    return _getScriptTemplateV2()
        .replaceAll('{{FIELD_ID}}', field.id)
        .replaceAll('{{FIELD_NAME}}', field.footballFieldName.replaceAll("'", "\\'"))
        .replaceAll('{{SUPABASE_URL}}', supabaseUrl)
        .replaceAll('{{SUPABASE_KEY}}', supabaseKey)
        .replaceAll('{{CAMERA_IP}}', field.cameraIpAddress ?? '')
        .replaceAll('{{CAMERA_USERNAME}}', field.cameraUsername ?? 'admin')
        .replaceAll('{{CAMERA_PASSWORD}}', field.cameraPassword ?? '')
        .replaceAll('{{CAMERA_RTSP_PORT}}', '554')
        .replaceAll('{{RASPBERRY_PI_IP}}', field.raspberryPiIp ?? 'unknown')
        .replaceAll('{{GENERATED_DATE}}', DateTime.now().toIso8601String());
  }

  /// Generate environment variables file content
  static String generateEnvFile(FootballField field) {
    final supabaseUrl = SupabaseConfig.supabaseUrl;
    final supabaseKey = SupabaseConfig.supabaseAnonKey;

    return '''
# Playmaker Camera Script Environment Variables
# Field: ${field.footballFieldName}
# Generated: ${DateTime.now().toIso8601String()}

# Field Configuration
PLAYMAKER_FIELD_ID=${field.id}
PLAYMAKER_FIELD_NAME=${field.footballFieldName}

# Supabase Configuration
SUPABASE_URL=$supabaseUrl
SUPABASE_KEY=$supabaseKey

# Camera Configuration
CAMERA_IP=${field.cameraIpAddress ?? ''}
CAMERA_USERNAME=${field.cameraUsername ?? 'admin'}
CAMERA_PASSWORD=${field.cameraPassword ?? ''}
CAMERA_RTSP_PORT=554

# RTSP URL Pattern - Adjust for your camera model:
# Hikvision: rtsp://{username}:{password}@{ip}:{port}/Streaming/Channels/101
# Dahua: rtsp://{username}:{password}@{ip}:{port}/cam/realmonitor?channel=1&subtype=0
# Reolink: rtsp://{username}:{password}@{ip}:{port}/h264Preview_01_main
CAMERA_RTSP_PATTERN=rtsp://{username}:{password}@{ip}:{port}/h264Preview_01_main

# Recording Settings
CHUNK_DURATION_MINUTES=20
RECORDING_DIR=/home/pi/recordings
TEMP_DIR=/home/pi/temp
LOG_DIR=/home/pi/logs

# Retry Settings
MAX_UPLOAD_RETRIES=3
RETRY_DELAY_SECONDS=10

# Disk Space (GB)
MIN_FREE_SPACE_GB=2.0

# Heartbeat Interval (seconds)
HEARTBEAT_INTERVAL=60

# Modal Webhook
MODAL_WEBHOOK_URL=https://youssefelhenawy0--playmaker-ball-tracking-trigger-job.modal.run
''';
  }

  /// Generate setup instructions for the Raspberry Pi (V2)
  static String generateSetupInstructions(FootballField field) {
    final supabaseUrl = SupabaseConfig.supabaseUrl;
    final supabaseKey = SupabaseConfig.supabaseAnonKey;

    return '''
# ==========================================
# PLAYMAKER CAMERA SETUP V2 - ${field.footballFieldName}
# ==========================================

## 📋 What's New in V2
- ✅ Retry logic for uploads (no more lost recordings!)
- ✅ Keeps chunks locally until stitch complete
- ✅ Health monitoring heartbeat
- ✅ Auto disk space cleanup
- ✅ Environment variable configuration
- ✅ Fallback to raw video if processing fails

## 🔧 Prerequisites
- Raspberry Pi 4 (4GB RAM recommended)
- SD Card (32GB minimum, Class 10)
- Ethernet connection (recommended)
- IP Camera with RTSP support

## 📦 Step 1: System Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y python3-pip ffmpeg

# Install Python packages
pip3 install supabase python-dotenv requests --break-system-packages

# Create directories
mkdir -p /home/pi/recordings /home/pi/temp /home/pi/logs /home/pi/scripts
```

## 📝 Step 2: Create Environment File

```bash
# Create .env file for sensitive configuration
nano /home/pi/scripts/.env
```

Paste these environment variables:

```
PLAYMAKER_FIELD_ID=${field.id}
PLAYMAKER_FIELD_NAME=${field.footballFieldName}
SUPABASE_URL=$supabaseUrl
SUPABASE_KEY=$supabaseKey
CAMERA_IP=${field.cameraIpAddress ?? 'YOUR_CAMERA_IP'}
CAMERA_USERNAME=${field.cameraUsername ?? 'admin'}
CAMERA_PASSWORD=${field.cameraPassword ?? 'YOUR_PASSWORD'}
CAMERA_RTSP_PORT=554
```

Save and secure:
```bash
chmod 600 /home/pi/scripts/.env
```

## 📄 Step 3: Install Script

```bash
# Create script file
nano /home/pi/scripts/field_camera.py

# Paste the generated Python script
# Save with Ctrl+X, Y, Enter

# Make executable
chmod +x /home/pi/scripts/field_camera.py
```

## 🔍 Step 4: Test Camera Connection

```bash
# Test RTSP stream
ffprobe -v error -rtsp_transport tcp -i "rtsp://${field.cameraUsername ?? 'admin'}:PASSWORD@${field.cameraIpAddress ?? 'CAMERA_IP'}:554/Streaming/Channels/101"

# Record 10 second test
ffmpeg -rtsp_transport tcp -i "rtsp://${field.cameraUsername ?? 'admin'}:PASSWORD@${field.cameraIpAddress ?? 'CAMERA_IP'}:554/Streaming/Channels/101" -t 10 -c:v copy test.mp4
```

## 🚀 Step 5: Run Script

```bash
# Load environment and run
cd /home/pi/scripts
export \$(cat .env | xargs)
python3 field_camera.py
```

## ⚙️ Step 6: Auto-Start on Boot (Production)

```bash
# Create systemd service
sudo nano /etc/systemd/system/playmaker-camera.service
```

Add this content:

```ini
[Unit]
Description=Playmaker Camera Recording Service V2
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/scripts
EnvironmentFile=/home/pi/scripts/.env
ExecStart=/usr/bin/python3 /home/pi/scripts/field_camera.py
Restart=always
RestartSec=30
StandardOutput=append:/home/pi/logs/service.log
StandardError=append:/home/pi/logs/service_error.log

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable playmaker-camera
sudo systemctl start playmaker-camera

# Check status
sudo systemctl status playmaker-camera

# View logs
journalctl -u playmaker-camera -f
```

## 🔧 Troubleshooting

### Camera not connecting
1. Verify IP: `ping ${field.cameraIpAddress ?? 'CAMERA_IP'}`
2. Check port: `nc -zv ${field.cameraIpAddress ?? 'CAMERA_IP'} 554`
3. Test with VLC: `vlc rtsp://...`

### Common RTSP URL patterns:
| Brand | Pattern |
|-------|---------|
| Hikvision | `/Streaming/Channels/101` |
| Dahua | `/cam/realmonitor?channel=1&subtype=0` |
| Reolink | `/h264Preview_01_main` |
| Axis | `/axis-media/media.amp` |

### Logs
- Main log: `/home/pi/logs/camera_${field.id}.log`
- Service log: `/home/pi/logs/service.log`

### Disk space
Script auto-cleans files older than 24 hours. Check with:
```bash
df -h /home/pi
```

## 📊 Monitoring

The script sends heartbeat every 60 seconds to Supabase.
Check camera status in the Admin app under "Camera Monitoring".

## 📱 Field Information

| Property | Value |
|----------|-------|
| Field ID | `${field.id}` |
| Field Name | ${field.footballFieldName} |
| Camera IP | ${field.cameraIpAddress ?? 'Not configured'} |
| Pi IP | ${field.raspberryPiIp ?? 'Not configured'} |
| Has Camera | ${field.hasCamera} |

---
**Script Version**: 2.0
**Generated**: ${DateTime.now().toIso8601String()}
''';
  }

  /// Get the V2 Python script template
  static String _getScriptTemplateV2() {
    return r'''#!/usr/bin/env python3
"""
==========================================
PLAYMAKER FIELD CAMERA RECORDING SCRIPT V2
==========================================

Field: {{FIELD_NAME}}
Field ID: {{FIELD_ID}}
Generated: {{GENERATED_DATE}}

FEATURES:
- ✅ Retry logic with exponential backoff
- ✅ Local chunk retention until stitch complete
- ✅ Health heartbeat monitoring
- ✅ Concurrent recording support
- ✅ Automatic disk space cleanup
- ✅ Fallback to raw video if ball tracking fails
- ✅ Environment variable configuration

==========================================
"""

import os
import sys
import time
import json
import subprocess
import threading
import logging
import shutil
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, Dict, List
from dataclasses import dataclass, field
from enum import Enum
import requests

# ==========================================
# CONFIGURATION
# ==========================================
FIELD_ID = os.environ.get('PLAYMAKER_FIELD_ID', '{{FIELD_ID}}')
FIELD_NAME = os.environ.get('PLAYMAKER_FIELD_NAME', '{{FIELD_NAME}}')

SUPABASE_URL = os.environ.get('SUPABASE_URL', '{{SUPABASE_URL}}')
SUPABASE_KEY = os.environ.get('SUPABASE_KEY', '{{SUPABASE_KEY}}')

CAMERA_IP = os.environ.get('CAMERA_IP', '{{CAMERA_IP}}')
CAMERA_USERNAME = os.environ.get('CAMERA_USERNAME', '{{CAMERA_USERNAME}}')
CAMERA_PASSWORD = os.environ.get('CAMERA_PASSWORD', '{{CAMERA_PASSWORD}}')
CAMERA_RTSP_PORT = os.environ.get('CAMERA_RTSP_PORT', '{{CAMERA_RTSP_PORT}}')

CAMERA_RTSP_PATTERN = os.environ.get(
    'CAMERA_RTSP_PATTERN',
    'rtsp://{username}:{password}@{ip}:{port}/h264Preview_01_main'
)

CHUNK_DURATION_MINUTES = int(os.environ.get('CHUNK_DURATION_MINUTES', '20'))
RECORDING_DIR = os.environ.get('RECORDING_DIR', '/home/pi/recordings')
TEMP_DIR = os.environ.get('TEMP_DIR', '/home/pi/temp')
LOG_DIR = os.environ.get('LOG_DIR', '/home/pi/logs')

MAX_UPLOAD_RETRIES = int(os.environ.get('MAX_UPLOAD_RETRIES', '3'))
RETRY_DELAY_SECONDS = int(os.environ.get('RETRY_DELAY_SECONDS', '10'))
MIN_FREE_SPACE_GB = float(os.environ.get('MIN_FREE_SPACE_GB', '2.0'))
HEARTBEAT_INTERVAL = int(os.environ.get('HEARTBEAT_INTERVAL', '60'))

MODAL_WEBHOOK_URL = os.environ.get(
    'MODAL_WEBHOOK_URL',
    'https://youssefelhenawy0--playmaker-ball-tracking-trigger-job.modal.run'
)

# ==========================================
# LOGGING HANDLER (Non-blocking for clean exit)
# ==========================================
class SupabaseLogHandler(logging.Handler):
    def __init__(self, supabase, field_id):
        super().__init__()
        self.supabase = supabase
        self.field_id = field_id
        self.batch = []
        self.lock = threading.RLock()  # Use RLock to prevent deadlock
        self.running = True
        
        # Start flusher thread
        self._flusher = threading.Thread(target=self._flush_loop, daemon=True)
        self._flusher.start()

    def emit(self, record):
        if not self.running:
            return
        try:
            msg = self.format(record)
            # Non-blocking lock acquisition
            if self.lock.acquire(blocking=False):
                try:
                    self.batch.append({
                        'field_id': self.field_id,
                        'level': record.levelname,
                        'message': msg,
                        'created_at': datetime.now().isoformat()
                    })
                finally:
                    self.lock.release()
        except:
            pass  # Silently ignore errors during shutdown

    def _flush_loop(self):
        while self.running:
            time.sleep(5)
            self.flush()

    def flush(self):
        if not self.running:
            return
        if self.lock.acquire(blocking=False):
            try:
                if not self.batch:
                    return
                to_send = self.batch[:]
                self.batch = []
            finally:
                self.lock.release()
                
            try:
                self.supabase.insert_logs(to_send)
            except:
                pass  # Prevent infinite loop if logging fails
    
    def stop(self):
        """Stop the handler gracefully."""
        self.running = False

# ==========================================
# SETUP
# ==========================================
Path(LOG_DIR).mkdir(parents=True, exist_ok=True)
Path(RECORDING_DIR).mkdir(parents=True, exist_ok=True)
Path(TEMP_DIR).mkdir(parents=True, exist_ok=True)

# Will be initialized in main()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


class RecordingStatus(Enum):
    PENDING = "pending"
    SCHEDULED = "scheduled"
    RECORDING = "recording"
    UPLOADING = "uploading"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


@dataclass
class RecordingJob:
    booking_id: str
    start_time: datetime
    end_time: datetime
    duration_minutes: int
    status: RecordingStatus = RecordingStatus.PENDING
    chunks: List[str] = field(default_factory=list)
    error_message: Optional[str] = None


class SupabaseClient:
    """Supabase client with retry logic."""
    
    def __init__(self, url: str, key: str):
        self.url = url
        self.key = key
        self.headers = {
            'apikey': key,
            'Authorization': f'Bearer {key}',
            'Content-Type': 'application/json',
            'Prefer': 'return=representation'
        }
    
    def _request(self, method: str, endpoint: str, data: dict = None, retries: int = MAX_UPLOAD_RETRIES):
        url = f"{self.url}/rest/v1/{endpoint}"
        
        for attempt in range(retries):
            try:
                if method == 'GET':
                    response = requests.get(url, headers=self.headers, params=data, timeout=30)
                elif method == 'POST':
                    response = requests.post(url, headers=self.headers, json=data, timeout=60)
                elif method == 'PATCH':
                    response = requests.patch(url, headers=self.headers, json=data, timeout=30)
                
                response.raise_for_status()
                return response.json() if response.text else {}
                
            except requests.exceptions.RequestException as e:
                logger.warning(f"Request failed (attempt {attempt + 1}/{retries}): {e}")
                if attempt < retries - 1:
                    time.sleep(RETRY_DELAY_SECONDS * (2 ** attempt))
                else:
                    raise
        return {}
    
    def get_upcoming_bookings(self, field_id: str) -> List[dict]:
        now = datetime.now()
        today = now.strftime('%Y-%m-%d')
        tomorrow = (now + timedelta(days=1)).strftime('%Y-%m-%d')
        
        params = {
            'football_field_id': f'eq.{field_id}',
            'is_recording_enabled': 'eq.true',
            'date': f'in.({today},{tomorrow})',
            'status': 'in.(confirmed,pending)',
            'select': '*'
        }
        return self._request('GET', 'bookings', params) or []
    
    def get_booking(self, booking_id: str) -> Optional[dict]:
        params = {'id': f'eq.{booking_id}', 'select': '*'}
        result = self._request('GET', 'bookings', params)
        return result[0] if result else None
    
    def update_booking(self, booking_id: str, data: dict):
        url = f"{self.url}/rest/v1/bookings?id=eq.{booking_id}"
        try:
            requests.patch(url, headers=self.headers, json=data, timeout=30)
            logger.info(f"📝 Updated booking {booking_id}: {data.get('status', 'updated')}")
        except Exception as e:
            logger.error(f"Failed to update booking: {e}")
    
    def create_ball_tracking_job(self, booking_id: str, video_url: str, field_id: str) -> Optional[str]:
        data = {
            'input_video_url': video_url,
            'video_name': f"field_{field_id[:8]}_booking_{booking_id[:8]}",
            'status': 'pending',
            'progress_percent': 0,
            'script_config': {'zoom_base': 1.75, 'detect_every_frames': 3, 'yolo_conf': 0.12, 'yolo_model': 'yolov8l'},
            'script_version': '2.0',
            'booking_id': booking_id,
            'field_id': field_id
        }
        try:
            result = self._request('POST', 'ball_tracking_jobs', data)
            if isinstance(result, list) and result:
                return result[0].get('id')
            return result.get('id') if isinstance(result, dict) else None
        except Exception as e:
            logger.error(f"Failed to create ball tracking job: {e}")
            return None
    
    def upload_file(self, path: str, file_path: str) -> Optional[str]:
        url = f"{self.url}/storage/v1/object/videos/{path}"
        
        for attempt in range(MAX_UPLOAD_RETRIES):
            try:
                file_size = os.path.getsize(file_path) / (1024 * 1024)
                logger.info(f"☁️ Uploading {file_size:.1f} MB (attempt {attempt + 1})...")
                
                with open(file_path, 'rb') as f:
                    headers = {
                        'apikey': self.key,
                        'Authorization': f'Bearer {self.key}',
                        'Content-Type': 'video/mp4'
                    }
                    response = requests.post(url, headers=headers, data=f, timeout=900)
                    response.raise_for_status()
                
                public_url = f"{self.url}/storage/v1/object/public/videos/{path}"
                logger.info(f"✅ Upload complete!")
                return public_url
                
            except Exception as e:
                logger.warning(f"Upload failed (attempt {attempt + 1}): {e}")
                if attempt < MAX_UPLOAD_RETRIES - 1:
                    time.sleep(RETRY_DELAY_SECONDS * (2 ** attempt))
        return None
    
    def send_heartbeat(self, field_id: str, status: str, details: dict = None):
        data = {
            'field_id': field_id,
            'status': status,
            'last_heartbeat': datetime.now().isoformat(),
            'details': json.dumps(details or {})
        }
        try:
            url = f"{self.url}/rest/v1/camera_status?field_id=eq.{field_id}"
            response = requests.patch(url, headers=self.headers, json=data, timeout=10)
            if response.status_code == 404 or not response.text or response.text == '[]':
                # Insert if not exists
                requests.post(f"{self.url}/rest/v1/camera_status", headers=self.headers, json=data, timeout=10)
        except:
            pass  # Silent fail for heartbeat
    
    def insert_logs(self, logs: List[dict]):
        try:
            requests.post(f"{self.url}/rest/v1/camera_logs", headers=self.headers, json=logs, timeout=5)
        except:
            pass

    def send_notification(self, booking_id: str, title: str, body: str, event_type: str):
        """Send push notification via Supabase Edge Function."""
        try:
            url = f"{self.url}/functions/v1/send-recording-notification"
            data = {
                'booking_id': booking_id,
                'title': title,
                'body': body,
                'event_type': event_type
            }
            requests.post(url, headers=self.headers, json=data, timeout=30)
            logger.info(f"📱 Notification sent: {event_type}")
        except Exception as e:
            logger.debug(f"Notification failed: {e}")


class CameraRecorder:
    def __init__(self, supabase: SupabaseClient):
        self.supabase = supabase
        self.active_recordings: Dict[str, RecordingJob] = {}
        self.lock = threading.Lock()
    
    def get_rtsp_url(self) -> str:
        return CAMERA_RTSP_PATTERN.format(
            username=CAMERA_USERNAME,
            password=CAMERA_PASSWORD,
            ip=CAMERA_IP,
            port=CAMERA_RTSP_PORT
        )
    
    def check_disk_space(self) -> bool:
        try:
            stat = shutil.disk_usage(RECORDING_DIR)
            free_gb = stat.free / (1024 ** 3)
            if free_gb < MIN_FREE_SPACE_GB:
                logger.warning(f"⚠️ Low disk: {free_gb:.1f}GB free")
                self._cleanup_old_files()
                return free_gb >= MIN_FREE_SPACE_GB * 0.5
            return True
        except:
            return True
    
    def _cleanup_old_files(self):
        try:
            cutoff = datetime.now() - timedelta(hours=24)
            for dir_path in [RECORDING_DIR, TEMP_DIR]:
                for f in os.listdir(dir_path):
                    fp = os.path.join(dir_path, f)
                    if os.path.isfile(fp) and datetime.fromtimestamp(os.path.getmtime(fp)) < cutoff:
                        os.remove(fp)
                        logger.info(f"🗑️ Cleaned: {f}")
        except Exception as e:
            logger.error(f"Cleanup error: {e}")
    
    def test_camera(self) -> bool:
        try:
            # Use shutil to find ffprobe in PATH
            ffprobe_cmd = shutil.which('ffprobe') or '/usr/bin/ffprobe'
            
            # Reduced timeout to 5 seconds to prevent hanging
            result = subprocess.run(
                [ffprobe_cmd, '-v', 'error', '-rtsp_transport', 'tcp', '-i', self.get_rtsp_url()],
                capture_output=True, timeout=5, stdin=subprocess.DEVNULL
            )
            return result.returncode == 0
        except:
            return False
    
    def start_recording(self, job: RecordingJob) -> bool:
        with self.lock:
            if job.booking_id in self.active_recordings:
                return False
            self.active_recordings[job.booking_id] = job
        
        try:
            if not self.check_disk_space():
                raise Exception("Insufficient disk space")
            
            booking = self.supabase.get_booking(job.booking_id)
            if not booking or booking.get('status') == 'cancelled':
                raise Exception("Booking cancelled or not found")
            
            job.status = RecordingStatus.RECORDING
            self.supabase.update_booking(job.booking_id, {'status': 'recording'})
            self.supabase.send_notification(
                job.booking_id,
                '🎬 Recording Started',
                f'Your match at {FIELD_NAME} is being recorded.',
                'recording_started'
            )
            
            logger.info(f"🎬 Recording {job.booking_id} ({job.duration_minutes} min)")
            
            num_chunks = (job.duration_minutes + CHUNK_DURATION_MINUTES - 1) // CHUNK_DURATION_MINUTES
            
            for i in range(num_chunks):
                # Update pipeline status
                self.supabase.send_heartbeat(FIELD_ID, 'recording', {
                    'current_booking': job.booking_id,
                    'step': 'recording',
                    'message': f'Recording chunk {i+1}/{num_chunks}',
                    'progress': int(((i) / num_chunks) * 100)
                })

                # Check cancellation
                current = self.supabase.get_booking(job.booking_id)
                if current and current.get('status') == 'cancelled':
                    logger.warning("⚠️ Booking cancelled mid-recording")
                    job.status = RecordingStatus.CANCELLED
                    return False
                
                remaining = job.duration_minutes - (i * CHUNK_DURATION_MINUTES)
                duration = min(CHUNK_DURATION_MINUTES, remaining)
                
                chunk = self._record_chunk(job.booking_id, i + 1, duration)
                if chunk:
                    job.chunks.append(chunk)
                    logger.info(f"✅ Chunk {i + 1}/{num_chunks}")
                else:
                    logger.error(f"❌ Chunk {i + 1} failed")
            
            if not job.chunks:
                raise Exception("No chunks recorded")
            
            self._process_recording(job)
            return True
            
        except Exception as e:
            logger.error(f"Recording failed: {e}")
            job.status = RecordingStatus.FAILED
            job.error_message = str(e)
            self.supabase.update_booking(job.booking_id, {'status': 'recording_failed'})
            self.supabase.send_notification(
                job.booking_id,
                '❌ Recording Failed',
                f'There was an issue recording your match. Our team has been notified.',
                'recording_failed'
            )
            self.supabase.send_heartbeat(FIELD_ID, 'error', {
                'error': str(e),
                'last_step': 'recording'
            })
            return False
        finally:
            with self.lock:
                self.active_recordings.pop(job.booking_id, None)
    
    def _record_chunk(self, booking_id: str, chunk_num: int, duration_min: int) -> Optional[str]:
        ts = datetime.now().strftime('%Y%m%d_%H%M%S')
        path = os.path.join(RECORDING_DIR, f"{booking_id[:8]}_c{chunk_num:03d}_{ts}.mp4")
        
        cmd = [
            'ffmpeg', '-y', '-rtsp_transport', 'tcp',
            '-i', self.get_rtsp_url(),
            '-t', str(duration_min * 60),
            '-c:v', 'copy', '-c:a', 'aac',
            '-movflags', '+faststart', '-f', 'mp4', path
        ]
        
        logger.info(f"📹 Recording chunk {chunk_num} ({duration_min} min)...")
        
        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            proc.communicate(timeout=duration_min * 60 + 120)
            
            if proc.returncode == 0 and os.path.exists(path) and os.path.getsize(path) > 1024:
                return path
            return None
        except subprocess.TimeoutExpired:
            proc.kill()
            return path if os.path.exists(path) else None
        except:
            return None
    
    def _process_recording(self, job: RecordingJob):
        job.status = RecordingStatus.PROCESSING
        self.supabase.update_booking(job.booking_id, {'status': 'processing'})
        
        try:
            # Stitch locally
            self.supabase.send_heartbeat(FIELD_ID, 'processing', {
                'current_booking': job.booking_id,
                'step': 'stitching',
                'message': f'Stitching {len(job.chunks)} chunks...'
            })
            
            if len(job.chunks) == 1:
                final = job.chunks[0]
            else:
                final = self._stitch_chunks(job.chunks, job.booking_id)
                if not final:
                    raise Exception("Stitch failed")
            
            # Upload
            job.status = RecordingStatus.UPLOADING
            ts = datetime.now().strftime('%Y%m%d_%H%M%S')
            storage_path = f"raw-recordings/{FIELD_ID[:8]}/{job.booking_id[:8]}_{ts}.mp4"
            
            self.supabase.send_heartbeat(FIELD_ID, 'uploading', {
                'current_booking': job.booking_id,
                'step': 'uploading',
                'message': 'Uploading video to cloud...'
            })
            
            video_url = self.supabase.upload_file(storage_path, final)
            if not video_url:
                raise Exception("Upload failed")
            
            # Save raw video URL
            self.supabase.update_booking(job.booking_id, {
                'status': 'recorded',
                'recording_url': video_url
            })
            
            self.supabase.send_notification(
                job.booking_id,
                '✅ Recording Complete',
                f'Your match recording is ready! Processing for highlights...',
                'recording_complete'
            )
            
            # Try ball tracking
            self.supabase.send_heartbeat(FIELD_ID, 'processing', {
                'current_booking': job.booking_id,
                'step': 'ai_trigger',
                'message': 'Triggering AI analysis...'
            })
            
            tracking_id = self.supabase.create_ball_tracking_job(job.booking_id, video_url, FIELD_ID)
            if tracking_id:
                logger.info(f"🎯 Ball tracking: {tracking_id}")
                self._trigger_modal(tracking_id, video_url, job.booking_id)
            
            # Cleanup local files
            self._cleanup_job(job)
            
            job.status = RecordingStatus.COMPLETED
            logger.info(f"✅ Complete: {job.booking_id}")
            
            # Final success heartbeat
            self.supabase.send_heartbeat(FIELD_ID, 'online', {
                'last_completed': job.booking_id,
                'message': 'Ready for next booking'
            })
            
        except Exception as e:
            logger.error(f"Processing failed: {e}")
            job.status = RecordingStatus.FAILED
            self.supabase.update_booking(job.booking_id, {'status': 'recording_failed'})
    
    def _stitch_chunks(self, chunks: List[str], booking_id: str) -> Optional[str]:
        concat_file = os.path.join(TEMP_DIR, f"{booking_id[:8]}_concat.txt")
        output = os.path.join(TEMP_DIR, f"{booking_id[:8]}_stitched.mp4")
        
        with open(concat_file, 'w') as f:
            for c in chunks:
                f.write(f"file '{c}'\n")
        
        logger.info(f"🔗 Stitching {len(chunks)} chunks...")
        
        try:
            result = subprocess.run([
                'ffmpeg', '-y', '-f', 'concat', '-safe', '0',
                '-i', concat_file, '-c', 'copy', '-movflags', '+faststart', output
            ], capture_output=True, text=True, timeout=300)
            
            if result.returncode == 0 and os.path.exists(output):
                size_mb = os.path.getsize(output) / (1024 * 1024)
                logger.info(f"✅ Stitched: {size_mb:.1f} MB")
                return output
        except Exception as e:
            logger.error(f"Stitch error: {e}")
        return None
    
    def _trigger_modal(self, job_id: str, video_url: str, booking_id: str):
        for attempt in range(MAX_UPLOAD_RETRIES):
            try:
                response = requests.post(MODAL_WEBHOOK_URL, json={
                    'job_id': job_id,
                    'video_url': video_url,
                    'booking_id': booking_id,
                    'config': {'zoom_base': 1.75, 'detect_every_frames': 3, 'yolo_conf': 0.12, 'yolo_model': 'yolov8l'}
                }, timeout=180)
                
                if response.status_code == 200:
                    logger.info("✅ Ball tracking triggered")
                    return
            except Exception as e:
                logger.warning(f"Modal trigger attempt {attempt + 1} failed: {e}")
            
            if attempt < MAX_UPLOAD_RETRIES - 1:
                time.sleep(RETRY_DELAY_SECONDS * (2 ** attempt))
        
        logger.error("❌ Modal trigger failed - raw video available")
    
    def _cleanup_job(self, job: RecordingJob):
        try:
            for c in job.chunks:
                if os.path.exists(c):
                    os.remove(c)
            for f in os.listdir(TEMP_DIR):
                if job.booking_id[:8] in f:
                    os.remove(os.path.join(TEMP_DIR, f))
            logger.info(f"🗑️ Cleaned up {job.booking_id[:8]}")
        except:
            pass


class Scheduler:
    def __init__(self, recorder: CameraRecorder, supabase: SupabaseClient, log_handler=None):
        self.recorder = recorder
        self.supabase = supabase
        self.scheduled: Dict[str, RecordingJob] = {}
        self.lock = threading.Lock()
        self.running = True
        self.log_handler = log_handler
    
    def start(self):
        logger.info(f"🚀 Scheduler started for {FIELD_NAME}")
        
        # Heartbeat thread
        threading.Thread(target=self._heartbeat_loop, daemon=True).start()
        
        self._refresh_bookings()
        
        try:
            while self.running:
                try:
                    self._check_recordings()
                    self._refresh_bookings()
                    time.sleep(15)
                except Exception as e:
                    logger.error(f"Scheduler error: {e}")
                    time.sleep(30)
        except KeyboardInterrupt:
            self._shutdown()
    
    def _shutdown(self):
        """Clean shutdown."""
        print("\n🛑 Shutting down gracefully...")
        self.running = False
        if self.log_handler:
            self.log_handler.stop()
        print("👋 Goodbye!")
    
    def _heartbeat_loop(self):
        while self.running:
            try:
                self.supabase.send_heartbeat(FIELD_ID, 'online', {
                    'active': len(self.recorder.active_recordings),
                    'scheduled': len(self.scheduled),
                    'camera_ok': self.recorder.test_camera()
                })
            except:
                pass
            time.sleep(HEARTBEAT_INTERVAL)
    
    def _refresh_bookings(self):
        try:
            bookings = self.supabase.get_upcoming_bookings(FIELD_ID)
            for b in bookings:
                bid = b['id']
                if bid in self.scheduled or bid in self.recorder.active_recordings:
                    continue
                
                job = self._create_job(b)
                if job:
                    with self.lock:
                        self.scheduled[bid] = job
                    logger.info(f"📆 Scheduled: {bid[:8]} at {job.start_time}")
        except Exception as e:
            logger.error(f"Refresh error: {e}")
    
    def _create_job(self, booking: dict) -> Optional[RecordingJob]:
        try:
            date = datetime.strptime(booking['date'], '%Y-%m-%d')
            # Handle both snake_case (DB) and camelCase (Legacy)
            time_slot = booking.get('time_slot') or booking.get('timeSlot')
            if not time_slot:
                return None

            start_str, end_str = time_slot.split('-')
            sh, sm = map(int, start_str.split(':'))
            eh, em = map(int, end_str.split(':'))
            
            start = date.replace(hour=sh, minute=sm)
            end = date.replace(hour=eh, minute=em)
            if end <= start:
                end += timedelta(days=1)
            
            return RecordingJob(
                booking_id=booking['id'],
                start_time=start,
                end_time=end,
                duration_minutes=int((end - start).total_seconds() / 60),
                status=RecordingStatus.SCHEDULED
            )
        except:
            return None
    
    def _check_recordings(self):
        now = datetime.now()
        with self.lock:
            for bid, job in list(self.scheduled.items()):
                if now >= job.start_time - timedelta(minutes=1):
                    del self.scheduled[bid]
                    threading.Thread(
                        target=self.recorder.start_recording,
                        args=(job,),
                        name=f"rec-{bid[:8]}"
                    ).start()
                    logger.info(f"⏰ Started: {bid[:8]}")


def main():
    print("=" * 50)
    print("🎬 PLAYMAKER CAMERA V2")
    print(f"📍 {FIELD_NAME}")
    print(f"📹 Camera: {CAMERA_IP}")
    print("=" * 50)
    
    if "{{" in FIELD_ID:
        print("❌ Not configured! Set environment variables.")
        sys.exit(1)
    
    # Test camera connection FIRST (before logging setup)
    print("\n🔍 Checking camera connection...")
    rtsp_url = CAMERA_RTSP_PATTERN.format(
        username=CAMERA_USERNAME,
        password=CAMERA_PASSWORD,
        ip=CAMERA_IP,
        port=CAMERA_RTSP_PORT
    )
    
    try:
        ffprobe_cmd = shutil.which('ffprobe') or '/usr/bin/ffprobe'
        result = subprocess.run(
            [ffprobe_cmd, '-v', 'error', '-rtsp_transport', 'tcp', '-i', rtsp_url],
            capture_output=True, timeout=10, stdin=subprocess.DEVNULL
        )
        if result.returncode == 0:
            print("✅ Camera connection successful!")
        else:
            print("⚠️ Camera test failed - will retry during recording")
            print(f"   RTSP URL: rtsp://{CAMERA_USERNAME}:***@{CAMERA_IP}:{CAMERA_RTSP_PORT}/...")
    except subprocess.TimeoutExpired:
        print("⚠️ Camera connection timed out - will retry during recording")
    except Exception as e:
        print(f"⚠️ Camera test error: {e}")
    
    print()  # Blank line
    
    supabase = SupabaseClient(SUPABASE_URL, SUPABASE_KEY)
    
    # Setup logging
    formatter = logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')
    
    # File Handler
    file_handler = logging.FileHandler(f'{LOG_DIR}/camera_{FIELD_ID[:8]}.log')
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)
    
    # Stream Handler (Console)
    stream_handler = logging.StreamHandler()
    stream_handler.setFormatter(formatter)
    logger.addHandler(stream_handler)
    
    # Supabase Handler (Cloud) - for Admin dashboard logs
    supabase_handler = SupabaseLogHandler(supabase, FIELD_ID)
    supabase_handler.setFormatter(formatter)
    logger.addHandler(supabase_handler)

    recorder = CameraRecorder(supabase)
    recorder.check_disk_space()
    
    # Pass log handler to scheduler for clean shutdown
    Scheduler(recorder, supabase, supabase_handler).start()


if __name__ == "__main__":
    main()
''';
  }
}
