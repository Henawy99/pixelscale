#!/usr/bin/env python3
"""
Playmaker Camera Recording Script v7.3
- Scheduled recordings from Supabase
- Background uploads to BunnyCDN
- Sequential uploads for maximum bandwidth
- GPU processing via Modal
- Copy mode (uses camera's efficient H.264)
"""

import os
import sys
import time
import json
import logging
import threading
import subprocess
import signal
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from concurrent.futures import ThreadPoolExecutor
from queue import Queue
import requests

# Try imports
try:
    from supabase import create_client, Client
    from dotenv import load_dotenv
except ImportError:
    print("Installing dependencies...")
    os.system("pip3 install supabase python-dotenv requests --break-system-packages")
    from supabase import create_client, Client
    from dotenv import load_dotenv

# =============================================================================
# CONFIGURATION
# =============================================================================
SCRIPT_VERSION = "9.0"  # NEW: Screenshot capture, field mask monitoring, self-update system

load_dotenv()

SUPABASE_URL = os.getenv('SUPABASE_URL', 'https://upooyypqhftzzwjrfyra.supabase.co')
SUPABASE_KEY = os.getenv('SUPABASE_KEY', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVwb295eXBxaGZ0enp3anJmeXJhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNTM3ODIsImV4cCI6MjA3NjgyOTc4Mn0.5I1xvhg0o4DeUd7uvSsCNmwzBB7FkBAy7lrnEDBncpE')
FIELD_ID = os.getenv('FIELD_ID', '')

# BunnyCDN Storage
BUNNY_STORAGE_ZONE = os.getenv('BUNNY_STORAGE_ZONE', 'playmaker-raw')
BUNNY_API_KEY = os.getenv('BUNNY_API_KEY', 'ec5feff0-e193-4a2c-a6c0fb04ab00-2198-4f75')
BUNNY_STORAGE_URL = f"https://storage.bunnycdn.com/{BUNNY_STORAGE_ZONE}"
BUNNY_CDN_URL = os.getenv('BUNNY_CDN_URL', 'https://playmaker-raw.b-cdn.net')

# Modal endpoint
MODAL_WEBHOOK_URL = os.getenv('MODAL_WEBHOOK_URL', 'https://youssefelhenawy0--playmakerstart-process-chunk-webhook.modal.run')

# Recording settings
CHUNK_DURATION_MINUTES = 10
RECORDING_DIR = Path(os.getenv('RECORDING_DIR', '/home/pi/recordings'))
RECORDING_DIR.mkdir(parents=True, exist_ok=True)
SCREENSHOT_DIR = Path(os.getenv('SCREENSHOT_DIR', '/home/pi/screenshots'))
SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)

# SD / camera storage footage (for "replay" - process existing recordings e.g. camera records 6-12 daily)
# Set to the path where the camera saves daily footage (e.g. /mnt/camera_sd or /media/sd/recordings).
# Expected layout: SD_FOOTAGE_BASE_DIR/YYYY-MM-DD/*.mp4 (files filtered by mtime within schedule window).
# If unset, replay-from-storage is skipped (no change to existing behaviour).
# DB: camera_recording_schedules.status must allow 'replay_requested' (add to enum if you use one).
SD_FOOTAGE_BASE_DIR = os.getenv('SD_FOOTAGE_BASE_DIR', '').strip()
SD_FOOTAGE_VIDEO_EXTENSIONS = ('.mp4', '.mkv', '.avi', '.mov', '.MP4', '.MKV', '.AVI', '.MOV')

# Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger('camera')

# Global
shutdown_requested = False
supabase: Optional[Client] = None


def signal_handler(sig, frame):
    global shutdown_requested
    logger.info("🛑 Shutdown requested...")
    shutdown_requested = True


signal.signal(signal.SIGINT, signal_handler)

# =============================================================================
# SAFETY FEATURES
# =============================================================================
MIN_DISK_SPACE_GB = 5.0  # Minimum free disk space required
FAILED_UPLOADS_FILE = Path('/home/pi/failed_uploads.json')
PENDING_UPLOADS_FILE = Path('/home/pi/pending_uploads.json')  # NEW: Persistent queue
ACTIVE_RECORDING_LOCK = Path('/home/pi/.recording_active')

# Upload settings
UPLOAD_TIMEOUT_SECONDS = 20 * 60  # 20 minutes max per chunk upload
NETWORK_CHECK_INTERVAL = 60  # Check network every 60 seconds when stuck
MAX_UPLOAD_RETRIES = 5  # Total retry attempts per chunk
RETRY_BACKOFF_SECONDS = [30, 60, 120, 300, 600]  # Exponential backoff: 30s, 1m, 2m, 5m, 10m

def check_disk_space() -> tuple[bool, float]:
    """Check if there's enough disk space. Returns (ok, free_gb)"""
    try:
        import shutil
        total, used, free = shutil.disk_usage(RECORDING_DIR)
        free_gb = free / (1024**3)
        return free_gb >= MIN_DISK_SPACE_GB, free_gb
    except Exception as e:
        logger.error(f"Disk check failed: {e}")
        return True, 0  # Allow recording if check fails

def check_network_health() -> tuple[bool, int]:
    """
    Check if network is healthy enough for uploads.
    Returns (is_healthy, latency_ms)
    - Healthy = ping < 500ms
    - Degraded = ping 500-2000ms  
    - Bad = ping > 2000ms or timeout
    """
    try:
        import subprocess
        result = subprocess.run(
            ['ping', '-c', '1', '-W', '5', '8.8.8.8'],
            capture_output=True, timeout=10
        )
        if result.returncode == 0:
            # Parse ping time from output
            output = result.stdout.decode()
            if 'time=' in output:
                time_str = output.split('time=')[1].split(' ')[0]
                latency_ms = int(float(time_str))
                is_healthy = latency_ms < 500  # Under 500ms is acceptable
                return is_healthy, latency_ms
        return False, 9999
    except Exception as e:
        logger.warning(f"Network check failed: {e}")
        return False, 9999

def save_pending_upload(chunk_id: str, local_path: str, remote_path: str, schedule_id: str, retry_count: int = 0):
    """Save upload to persistent queue for retry"""
    try:
        pending = []
        if PENDING_UPLOADS_FILE.exists():
            try:
                pending = json.loads(PENDING_UPLOADS_FILE.read_text())
            except:
                pending = []
        
        # Check if already in queue
        if not any(p.get('chunk_id') == chunk_id for p in pending):
            pending.append({
                'chunk_id': chunk_id,
                'local_path': str(local_path),
                'remote_path': remote_path,
                'schedule_id': schedule_id,
                'retry_count': retry_count,
                'added_at': datetime.utcnow().isoformat(),
                'last_attempt': None
            })
            PENDING_UPLOADS_FILE.write_text(json.dumps(pending, indent=2))
            logger.info(f"📋 Saved pending upload: {chunk_id[:8]}...")
    except Exception as e:
        logger.error(f"Failed to save pending upload: {e}")

def get_pending_uploads() -> list:
    """Get all pending uploads from persistent queue"""
    try:
        if PENDING_UPLOADS_FILE.exists():
            return json.loads(PENDING_UPLOADS_FILE.read_text())
    except Exception as e:
        logger.warning(f"Failed to read pending uploads: {e}")
    return []

def remove_pending_upload(chunk_id: str):
    """Remove upload from pending queue after success"""
    try:
        if PENDING_UPLOADS_FILE.exists():
            pending = json.loads(PENDING_UPLOADS_FILE.read_text())
            pending = [p for p in pending if p.get('chunk_id') != chunk_id]
            if pending:
                PENDING_UPLOADS_FILE.write_text(json.dumps(pending, indent=2))
            else:
                PENDING_UPLOADS_FILE.unlink()
    except Exception as e:
        logger.warning(f"Failed to remove pending upload: {e}")

def update_pending_upload_retry(chunk_id: str, retry_count: int):
    """Update retry count for pending upload"""
    try:
        if PENDING_UPLOADS_FILE.exists():
            pending = json.loads(PENDING_UPLOADS_FILE.read_text())
            for p in pending:
                if p.get('chunk_id') == chunk_id:
                    p['retry_count'] = retry_count
                    p['last_attempt'] = datetime.utcnow().isoformat()
            PENDING_UPLOADS_FILE.write_text(json.dumps(pending, indent=2))
    except Exception as e:
        logger.warning(f"Failed to update pending upload: {e}")

def is_recording_active() -> bool:
    """Check if another recording is in progress"""
    if ACTIVE_RECORDING_LOCK.exists():
        try:
            # Check if lock is stale (older than 90 minutes - max recording time + buffer)
            # REDUCED from 3 hours to catch stale locks faster!
            age_minutes = (time.time() - ACTIVE_RECORDING_LOCK.stat().st_mtime) / 60
            if age_minutes > 90:
                logger.warning(f"Found stale recording lock ({age_minutes:.0f} min old), removing...")
                force_remove_lock()
                return False
            
            # Also check if the lock's schedule_id has already completed
            try:
                lock_data = json.loads(ACTIVE_RECORDING_LOCK.read_text())
                lock_schedule_id = lock_data.get('schedule_id')
                if lock_schedule_id and supabase:
                    # Check if this schedule is no longer recording
                    result = supabase.table('camera_recording_schedules')\
                        .select('status')\
                        .eq('id', lock_schedule_id)\
                        .single()\
                        .execute()
                    if result.data:
                        status = result.data.get('status')
                        if status not in ['scheduled', 'recording']:
                            logger.warning(f"Lock file for {lock_schedule_id[:8]} but status is '{status}' - removing stale lock!")
                            force_remove_lock()
                            return False
            except Exception as e:
                logger.warning(f"Could not verify lock status: {e}")
            
            return True
        except Exception as e:
            logger.warning(f"Lock check error: {e}")
            return False
    return False

def force_remove_lock():
    """Aggressively remove lock file with retries"""
    for attempt in range(3):
        try:
            if ACTIVE_RECORDING_LOCK.exists():
                ACTIVE_RECORDING_LOCK.unlink()
                logger.info("🔓 Lock file removed")
                return True
            return True  # Already doesn't exist
        except Exception as e:
            logger.warning(f"Lock removal attempt {attempt+1} failed: {e}")
            time.sleep(0.5)
    
    # Last resort: try to overwrite with empty and delete
    try:
        ACTIVE_RECORDING_LOCK.write_text("")
        ACTIVE_RECORDING_LOCK.unlink()
        return True
    except Exception as e:
        logger.error(f"CRITICAL: Cannot remove lock file: {e}")
        return False

def set_recording_active(active: bool, schedule_id: str = None):
    """Set recording lock with aggressive cleanup"""
    try:
        if active:
            # Force remove any existing lock first
            force_remove_lock()
            ACTIVE_RECORDING_LOCK.write_text(json.dumps({
                'schedule_id': schedule_id,
                'started_at': datetime.utcnow().isoformat()
            }))
            logger.info(f"🔒 Recording lock SET for {schedule_id[:8] if schedule_id else 'unknown'}")
        else:
            # Aggressive removal with retries
            if force_remove_lock():
                logger.info("🔓 Recording lock RELEASED")
            else:
                logger.error("❌ FAILED to release recording lock!")
    except Exception as e:
        logger.error(f"Lock file error: {e}")
        # If setting active=False failed, try one more time
        if not active:
            force_remove_lock()

def save_failed_upload(chunk_id: str, video_url: str, schedule_id: str):
    """Save failed upload for retry"""
    try:
        failed = []
        if FAILED_UPLOADS_FILE.exists():
            failed = json.loads(FAILED_UPLOADS_FILE.read_text())
        
        # Add if not already in list
        if not any(f['chunk_id'] == chunk_id for f in failed):
            failed.append({
                'chunk_id': chunk_id,
                'video_url': video_url,
                'schedule_id': schedule_id,
                'failed_at': datetime.utcnow().isoformat()
            })
            FAILED_UPLOADS_FILE.write_text(json.dumps(failed, indent=2))
            logger.info(f"Saved failed upload for retry: {chunk_id[:8]}")
    except Exception as e:
        logger.error(f"Failed to save upload for retry: {e}")

def retry_failed_uploads():
    """Retry any failed uploads from previous runs"""
    if not FAILED_UPLOADS_FILE.exists():
        return
    
    try:
        failed = json.loads(FAILED_UPLOADS_FILE.read_text())
        if not failed:
            return
        
        logger.info(f"🔄 Found {len(failed)} failed GPU triggers to retry...")
        
        successful = []
        for item in failed:
            chunk_id = item['chunk_id']
            video_url = item['video_url']
            schedule_id = item['schedule_id']
            
            logger.info(f"🔄 Retrying GPU trigger for chunk {chunk_id[:8]}...")
            
            # Try to trigger GPU processing
            try:
                trigger_modal_processing(chunk_id, video_url, schedule_id)
                successful.append(chunk_id)
                logger.info(f"✅ Retry successful: {chunk_id[:8]}")
            except Exception as e:
                logger.error(f"❌ Retry failed: {e}")
        
        # Remove successful ones
        if successful:
            failed = [f for f in failed if f['chunk_id'] not in successful]
            if failed:
                FAILED_UPLOADS_FILE.write_text(json.dumps(failed, indent=2))
            else:
                FAILED_UPLOADS_FILE.unlink()
                logger.info("✅ All failed GPU triggers retried successfully!")
    except Exception as e:
        logger.error(f"Failed upload retry error: {e}")

def scan_for_orphaned_chunks(uploader: 'BackgroundUploader'):
    """
    Scan database for chunks that were recorded but never uploaded.
    This catches chunks that got stuck due to network issues or crashes.
    """
    global supabase
    if not supabase:
        return
    
    try:
        logger.info("🔍 Scanning for orphaned chunks...")
        
        # Find chunks with status 'recorded' or 'uploading' (stuck) from last 24 hours
        cutoff_time = (datetime.utcnow() - timedelta(hours=24)).isoformat()
        
        result = supabase.table('camera_recording_chunks')\
            .select('id, schedule_id, chunk_number, status, file_size_mb')\
            .eq('field_id', FIELD_ID)\
            .in_('status', ['recorded', 'uploading', 'upload_failed'])\
            .gte('created_at', cutoff_time)\
            .execute()
        
        orphaned = result.data or []
        
        if not orphaned:
            logger.info("✅ No orphaned chunks found")
            return
        
        logger.info(f"📋 Found {len(orphaned)} orphaned chunks - checking for local files...")
        
        queued_count = 0
        for chunk in orphaned:
            chunk_id = chunk['id']
            schedule_id = chunk['schedule_id']
            chunk_number = chunk['chunk_number']
            
            # Look for matching local file
            pattern = f"{schedule_id[:8]}_chunk_{chunk_number:03d}.mp4"
            local_files = list(RECORDING_DIR.glob(f"*{pattern}*"))
            
            if local_files:
                local_path = local_files[0]
                remote_path = f"recordings/{FIELD_ID}/{schedule_id}/{local_path.name}"
                
                logger.info(f"  📤 Re-queuing orphaned chunk {chunk_number} for job {schedule_id[:8]}...")
                uploader.add_upload(local_path, remote_path, chunk_id, schedule_id)
                queued_count += 1
            else:
                logger.warning(f"  ⚠️ No local file for chunk {chunk_number} of job {schedule_id[:8]} - marking as lost")
                # Mark as failed so it doesn't keep appearing
                update_chunk_record(chunk_id, {'status': 'file_lost', 'error_message': 'Local file not found at startup'})
        
        if queued_count > 0:
            logger.info(f"✅ Queued {queued_count} orphaned chunks for upload")
            
    except Exception as e:
        logger.error(f"Orphan scan error: {e}")
signal.signal(signal.SIGTERM, signal_handler)


# =============================================================================
# SUPABASE HELPERS
# =============================================================================
def init_supabase() -> Client:
    global supabase
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    return supabase


def get_field_config() -> Dict[str, Any]:
    """Get field configuration including camera IP from Supabase"""
    try:
        result = supabase.table('football_fields').select('*').eq('id', FIELD_ID).single().execute()
        return result.data or {}
    except Exception as e:
        logger.error(f"Failed to get field config: {e}")
        return {}


# Global variable to track current schedule_id for logging
current_schedule_id = None


def log_to_supabase(level: str, message: str, schedule_id: str = None):
    """Log message to Supabase camera_logs table"""
    try:
        log_data = {
            'field_id': FIELD_ID,
            'level': level,
            'message': message[:500],  # Limit message length
            'created_at': datetime.utcnow().isoformat()
        }
        # Only add these columns if they exist in the table
        # (backwards compatible - won't fail if columns don't exist)
        try:
            supabase.table('camera_logs').insert({
                **log_data,
                'schedule_id': schedule_id,
                'source': 'pi'
            }).execute()
        except:
            # Fallback: insert without schedule_id and source
            supabase.table('camera_logs').insert(log_data).execute()
    except Exception as e:
        pass  # Don't fail on log errors


def bg_log(level: str, message: str, schedule_id: str = None):
    """Background logging - both console and Supabase"""
    global current_schedule_id
    if level == 'INFO':
        logger.info(message)
    elif level == 'WARNING':
        logger.warning(message)
    elif level == 'ERROR':
        logger.error(message)
    # Use provided schedule_id or global current_schedule_id
    sid = schedule_id or current_schedule_id
    # Log to Supabase in background
    threading.Thread(target=log_to_supabase, args=(level, message, sid), daemon=True).start()


def update_camera_status(status: str, details: Dict = None):
    """Update camera status in Supabase"""
    try:
        data = {
            'field_id': FIELD_ID,
            'status': status,
            'last_heartbeat': datetime.utcnow().isoformat(),
            'details': json.dumps(details or {}),
        }
        supabase.table('camera_status').upsert(data, on_conflict='field_id').execute()
    except Exception as e:
        logger.error(f"Status update failed: {e}")


def get_pending_schedules() -> List[Dict]:
    """Get scheduled recordings that should start now"""
    try:
        now = datetime.utcnow()
        # Get schedules that are pending/scheduled and should start within 1 minute
        result = supabase.table('camera_recording_schedules')\
            .select('*')\
            .eq('field_id', FIELD_ID)\
            .in_('status', ['scheduled', 'recording'])\
            .lte('start_time', (now + timedelta(minutes=1)).isoformat())\
            .gte('end_time', now.isoformat())\
            .execute()
        return result.data or []
    except Exception as e:
        logger.error(f"Failed to get schedules: {e}")
        return []


def get_replay_schedules() -> List[Dict]:
    """Get schedules that request replay from SD/camera storage (past date, status replay_requested)."""
    if not SD_FOOTAGE_BASE_DIR or not Path(SD_FOOTAGE_BASE_DIR).exists():
        return []
    try:
        now = datetime.utcnow()
        result = supabase.table('camera_recording_schedules')\
            .select('*')\
            .eq('field_id', FIELD_ID)\
            .eq('status', 'replay_requested')\
            .lt('end_time', now.isoformat())\
            .order('start_time')\
            .limit(1)\
            .execute()
        return result.data or []
    except Exception as e:
        logger.debug(f"Replay schedules check: {e}")
        return []


def find_footage_files_for_schedule(schedule: Dict) -> List[Path]:
    """
    Find video files on SD/storage that fall within the schedule's start_time--end_time.
    Looks in SD_FOOTAGE_BASE_DIR/YYYY-MM-DD/ and filters by file mtime, or flat dir by mtime.
    """
    base = Path(SD_FOOTAGE_BASE_DIR)
    if not base.exists():
        return []
    try:
        start_time = datetime.fromisoformat(schedule['start_time'].replace('Z', '+00:00'))
        end_time = datetime.fromisoformat(schedule['end_time'].replace('Z', '+00:00'))
        start_ts = start_time.timestamp()
        end_ts = end_time.timestamp() + (30 * 60)  # +30 min: file often written when segment ends
        date_str = start_time.strftime('%Y-%m-%d')
        candidates: List[Path] = []
        # Prefer date subdir: SD_FOOTAGE_BASE_DIR/2026-02-10/
        date_dir = base / date_str
        if date_dir.exists() and date_dir.is_dir():
            for ext in SD_FOOTAGE_VIDEO_EXTENSIONS:
                candidates.extend(date_dir.glob(f'*{ext}'))
        else:
            for ext in SD_FOOTAGE_VIDEO_EXTENSIONS:
                candidates.extend(base.glob(f'*{ext}'))
        out = []
        for p in candidates:
            if not p.is_file():
                continue
            try:
                mtime = p.stat().st_mtime
                if start_ts <= mtime <= end_ts:
                    out.append(p)
            except OSError:
                continue
        out.sort(key=lambda p: p.stat().st_mtime)
        return out
    except Exception as e:
        logger.warning(f"find_footage_files_for_schedule error: {e}")
        return []


def update_schedule_status(schedule_id: str, status: str, extra_data: Dict = None):
    """Update recording schedule status"""
    try:
        data = {'status': status}
        if extra_data:
            data.update(extra_data)
        supabase.table('camera_recording_schedules').update(data).eq('id', schedule_id).execute()
    except Exception as e:
        logger.error(f"Schedule update failed: {e}")


def create_chunk_record(schedule_id: str, chunk_number: int, filename: str) -> Optional[str]:
    """Create a chunk record in database, return chunk ID"""
    global current_schedule_id
    try:
        # Only include columns that exist in the database!
        insert_data = {
            'schedule_id': schedule_id,
            'field_id': FIELD_ID,
            'chunk_number': chunk_number,
            'status': 'recording',
            'upload_progress': 0,
            'start_time': datetime.utcnow().isoformat(),  # Required NOT NULL column
        }
        bg_log('INFO', f"[{schedule_id[:8]}] 📝 Creating DB record for chunk {chunk_number}...")
        bg_log('INFO', f"[{schedule_id[:8]}] 📝 field_id={FIELD_ID[:8]}...")
        
        result = supabase.table('camera_recording_chunks').insert(insert_data).execute()
        
        if result.data:
            chunk_id = result.data[0]['id']
            bg_log('INFO', f"[{schedule_id[:8]}] ✅ Chunk {chunk_number} DB record created: {chunk_id[:8]}...")
            return chunk_id
        else:
            bg_log('ERROR', f"[{schedule_id[:8]}] ❌ Chunk insert returned no data!")
            return None
    except Exception as e:
        bg_log('ERROR', f"[{schedule_id[:8]}] ❌ Failed to create chunk record: {e}")
        import traceback
        bg_log('ERROR', f"[{schedule_id[:8]}] {traceback.format_exc()}")
        return None


def update_chunk_record(chunk_id: str, data: Dict):
    """Update chunk record - silently handles missing columns"""
    if not chunk_id:
        return
    try:
        supabase.table('camera_recording_chunks').update(data).eq('id', chunk_id).execute()
    except Exception as e:
        # Log but don't fail - column might not exist
        error_str = str(e)
        if "column" in error_str.lower() and "not" in error_str.lower():
            # Column doesn't exist - try with fewer fields
            safe_fields = {k: v for k, v in data.items() if k in ['status', 'upload_progress', 'video_url', 'processed_url']}
            if safe_fields:
                try:
                    supabase.table('camera_recording_chunks').update(safe_fields).eq('id', chunk_id).execute()
                    return
                except:
                    pass
        logger.warning(f"Chunk update warning: {e}")


# =============================================================================
# CAMERA RECORDER
# =============================================================================
class CameraRecorder:
    def __init__(self, rtsp_url: str):
        self.rtsp_url = rtsp_url
    
    def test_connection(self) -> bool:
        """Test camera connection"""
        try:
            result = subprocess.run(
                ['ffprobe', '-v', 'error', '-rtsp_transport', 'tcp', 
                 '-timeout', '5000000', self.rtsp_url],
                capture_output=True, timeout=10
            )
            return result.returncode == 0
        except Exception as e:
            logger.error(f"Camera test failed: {e}")
            return False
    
    def record_chunk(self, output_path: Path, duration_seconds: int) -> bool:
        """Record a single chunk (copy mode - uses camera's efficient compression)"""
        logger.info(f"📹 Recording chunk: {output_path.name} ({duration_seconds}s)")
        
        cmd = [
            'ffmpeg', '-y',
            '-rtsp_transport', 'tcp',
            '-i', self.rtsp_url,
            '-t', str(duration_seconds),
            # Video: Copy mode - use camera's H.264 compression (efficient!)
            '-c:v', 'copy',
            # Audio: AAC compression
            '-c:a', 'aac',
            '-b:a', '128k',
            '-movflags', '+faststart',
            str(output_path)
        ]
        
        try:
            result = subprocess.run(cmd, capture_output=True, timeout=duration_seconds + 60)
            if result.returncode == 0 and output_path.exists():
                size_mb = output_path.stat().st_size / (1024 * 1024)
                logger.info(f"✅ Chunk recorded: {size_mb:.1f} MB")
                return True
            else:
                logger.error(f"❌ Recording failed: {result.stderr.decode()[:200]}")
                return False
        except subprocess.TimeoutExpired:
            logger.error("Recording timed out")
            return False
        except Exception as e:
            logger.error(f"Recording error: {e}")
            return False


# =============================================================================
# BUNNYCDN UPLOADER WITH RESUMABLE CHUNKED UPLOADS
# =============================================================================
def upload_to_bunny_storage(local_path: Path, remote_path: str, chunk_id: str = None, schedule_id: str = None, timeout: int = None) -> Optional[str]:
    """Upload file to BunnyCDN with resumable chunked upload, retries, and timeout"""
    url = f"{BUNNY_STORAGE_URL}/{remote_path}"
    schedule_prefix = schedule_id[:8] if schedule_id else "UPLOAD"
    
    MAX_RETRIES = 3
    CHUNK_SIZE = 5 * 1024 * 1024  # 5MB chunks for upload streaming
    upload_timeout = timeout or UPLOAD_TIMEOUT_SECONDS  # Use configurable timeout
    
    # Check network health before starting
    net_ok, latency = check_network_health()
    if not net_ok:
        bg_log('WARNING', f"[{schedule_prefix}] ⚠️ Network degraded (latency: {latency}ms) - will try anyway")
    else:
        bg_log('INFO', f"[{schedule_prefix}] ✅ Network OK (latency: {latency}ms)")
    
    try:
        file_size = local_path.stat().st_size
        size_mb = file_size / (1024 * 1024)
        
        bg_log('INFO', f"[{schedule_prefix}] 📤 UPLOAD STARTING: {local_path.name} ({size_mb:.1f} MB)")
        
        # Update status to uploading with start timestamp
        upload_start_time = datetime.utcnow()
        if chunk_id:
            update_chunk_record(chunk_id, {
                'status': 'uploading',
                'upload_progress': 1,
                'upload_started_at': upload_start_time.isoformat()
            })
        
        headers = {
            'AccessKey': BUNNY_API_KEY,
            'Content-Type': 'application/octet-stream'
        }
        
        # Track upload progress
        uploaded = 0
        last_progress = 0
        last_db_update = 0
        
        def file_reader_with_progress():
            nonlocal uploaded, last_progress, last_db_update
            with open(local_path, 'rb') as f:
                while True:
                    data = f.read(CHUNK_SIZE)
                    if not data:
                        break
                    uploaded += len(data)
                    progress = int((uploaded / file_size) * 100)
                    
                    # Log every 5%
                    if progress >= last_progress + 5:
                        last_progress = progress
                        uploaded_mb = uploaded / (1024 * 1024)
                        bg_log('INFO', f"[{schedule_prefix}] 📤 Upload: {progress}% ({uploaded_mb:.1f}/{size_mb:.1f} MB)")
                    
                    # Update DB every 10% to reduce DB calls
                    if chunk_id and progress >= last_db_update + 10:
                        last_db_update = progress
                        try:
                            update_chunk_record(chunk_id, {'upload_progress': progress})
                        except:
                            pass
                    
                    yield data
        
        # Retry logic for resilient uploads
        for attempt in range(MAX_RETRIES):
            try:
                uploaded = 0
                last_progress = 0
                last_db_update = 0
                
                response = requests.put(url, headers=headers, data=file_reader_with_progress(), timeout=upload_timeout)
                
                if response.status_code in [200, 201]:
                    cdn_url = f"{BUNNY_CDN_URL}/{remote_path}"
                    upload_finished_time = datetime.utcnow()
                    upload_duration_seconds = (upload_finished_time - upload_start_time).total_seconds()
                    
                    bg_log('INFO', f"[{schedule_prefix}] ✅ UPLOAD COMPLETE: {cdn_url}")
                    bg_log('INFO', f"[{schedule_prefix}] ⏱️ Upload took: {int(upload_duration_seconds)}s")
                    
                    if chunk_id:
                        update_chunk_record(chunk_id, {
                            'upload_progress': 100,
                            'video_url': cdn_url,
                            'status': 'uploaded',
                            'upload_finished_at': upload_finished_time.isoformat(),
                            'upload_duration_seconds': round(upload_duration_seconds, 1)
                        })
                    
                    return cdn_url
                else:
                    bg_log('WARNING', f"[{schedule_prefix}] ⚠️ Upload attempt {attempt+1} failed: HTTP {response.status_code}")
                    if attempt < MAX_RETRIES - 1:
                        bg_log('INFO', f"[{schedule_prefix}] 🔄 Retrying in 5 seconds...")
                        time.sleep(5)
                    
            except requests.exceptions.Timeout:
                bg_log('WARNING', f"[{schedule_prefix}] ⚠️ Upload timeout on attempt {attempt+1}")
                if attempt < MAX_RETRIES - 1:
                    bg_log('INFO', f"[{schedule_prefix}] 🔄 Retrying...")
                    time.sleep(5)
            except Exception as e:
                bg_log('WARNING', f"[{schedule_prefix}] ⚠️ Upload error on attempt {attempt+1}: {e}")
                if attempt < MAX_RETRIES - 1:
                    time.sleep(5)
        
        # All retries failed
        bg_log('ERROR', f"[{schedule_prefix}] ❌ UPLOAD FAILED after {MAX_RETRIES} attempts")
        if chunk_id:
            update_chunk_record(chunk_id, {'status': 'upload_failed'})
        return None
                
    except Exception as e:
        bg_log('ERROR', f"[{schedule_prefix}] ❌ UPLOAD ERROR: {e}")
        if chunk_id:
            update_chunk_record(chunk_id, {'status': 'upload_failed'})
        return None


# =============================================================================
# ROBUST BACKGROUND UPLOADER with retries, timeouts, and network health checks
# =============================================================================
class BackgroundUploader:
    def __init__(self):
        self.queue = Queue()
        self.results = {}  # {chunk_id: url} - results for ALL jobs
        self.job_chunks = {}  # {schedule_id: set(chunk_ids)} - track chunks per job
        self.executor = ThreadPoolExecutor(max_workers=2)  # 1 for uploads, 1 for retries
        self.running = True
        self.failed_uploads = []  # Track failed uploads for retry
        self._start_worker()
        self._start_retry_worker()
        self._load_pending_uploads()
    
    def _load_pending_uploads(self):
        """Load any pending uploads from previous runs"""
        pending = get_pending_uploads()
        if pending:
            logger.info(f"🔄 Found {len(pending)} pending uploads from previous run")
            for item in pending:
                local_path = Path(item['local_path'])
                if local_path.exists():
                    logger.info(f"  📤 Re-queuing: {item['chunk_id'][:8]}... (retry #{item.get('retry_count', 0)})")
                    self.failed_uploads.append({
                        'local_path': local_path,
                        'remote_path': item['remote_path'],
                        'chunk_id': item['chunk_id'],
                        'schedule_id': item['schedule_id'],
                        'retry_count': item.get('retry_count', 0)
                    })
                else:
                    logger.warning(f"  ⚠️ File missing, skipping: {item['chunk_id'][:8]}...")
                    remove_pending_upload(item['chunk_id'])
    
    def get_job_chunks(self, schedule_id: str) -> set:
        """Get chunk IDs for a specific job"""
        return self.job_chunks.get(schedule_id, set())
    
    def get_job_results(self, schedule_id: str) -> dict:
        """Get upload results for a specific job"""
        job_chunk_ids = self.get_job_chunks(schedule_id)
        return {cid: url for cid, url in self.results.items() if cid in job_chunk_ids}
    
    def _start_retry_worker(self):
        """Background thread that retries failed uploads when network recovers"""
        def retry_worker():
            logger.info("🔄 Retry worker started - will retry failed uploads automatically")
            while self.running:
                try:
                    # Check every 30 seconds
                    time.sleep(30)
                    
                    if not self.failed_uploads:
                        continue
                    
                    # Check network health
                    net_ok, latency = check_network_health()
                    if not net_ok:
                        logger.info(f"🌐 Network still degraded (latency: {latency}ms) - waiting...")
                        continue
                    
                    logger.info(f"🌐 Network recovered (latency: {latency}ms) - retrying {len(self.failed_uploads)} failed uploads")
                    
                    # Process failed uploads
                    to_retry = self.failed_uploads.copy()
                    self.failed_uploads.clear()
                    
                    for item in to_retry:
                        if not self.running:
                            break
                        
                        retry_count = item.get('retry_count', 0)
                        chunk_id = item['chunk_id']
                        schedule_id = item['schedule_id']
                        
                        if retry_count >= MAX_UPLOAD_RETRIES:
                            logger.error(f"❌ Max retries ({MAX_UPLOAD_RETRIES}) reached for {chunk_id[:8]}... - giving up")
                            save_failed_upload(chunk_id, "", schedule_id)  # Save for manual intervention
                            remove_pending_upload(chunk_id)
                            continue
                        
                        # Calculate backoff time
                        backoff_idx = min(retry_count, len(RETRY_BACKOFF_SECONDS) - 1)
                        backoff = RETRY_BACKOFF_SECONDS[backoff_idx]
                        
                        logger.info(f"🔄 Retry #{retry_count + 1} for {chunk_id[:8]}... (waited {backoff}s)")
                        
                        # Re-add to main queue
                        self.queue.put((
                            item['local_path'],
                            item['remote_path'],
                            chunk_id,
                            schedule_id,
                            retry_count + 1  # Pass retry count
                        ))
                        
                except Exception as e:
                    logger.error(f"Retry worker error: {e}")
        
        self.executor.submit(retry_worker)
    
    def _start_worker(self):
        def worker():
            while self.running:
                try:
                    item = self.queue.get(timeout=1)
                    if item is None:
                        break
                    
                    # Handle both 4-tuple (new) and 5-tuple (retry) formats
                    if len(item) == 5:
                        local_path, remote_path, chunk_id, schedule_id, retry_count = item
                    else:
                        local_path, remote_path, chunk_id, schedule_id = item
                        retry_count = 0
                    
                    schedule_prefix = schedule_id[:8] if schedule_id else "UPLOAD"
                    
                    # Check if file still exists
                    if not local_path.exists():
                        bg_log('WARNING', f"[{schedule_prefix}] ⚠️ File no longer exists: {local_path.name}")
                        remove_pending_upload(chunk_id)
                        self.queue.task_done()
                        continue
                    
                    # Show queue status
                    queue_size = self.queue.qsize()
                    failed_count = len(self.failed_uploads)
                    if queue_size > 0 or failed_count > 0:
                        bg_log('INFO', f"[{schedule_prefix}] 📋 Queue: {queue_size} waiting, {failed_count} pending retry")
                    
                    # IMMEDIATELY update chunk status to uploading
                    if chunk_id:
                        update_chunk_record(chunk_id, {'status': 'uploading', 'upload_progress': 0})
                        # Save to persistent queue in case of crash
                        save_pending_upload(chunk_id, str(local_path), remote_path, schedule_id, retry_count)
                    
                    bg_log('INFO', f"[{schedule_prefix}] ════════════════════════════════════")
                    bg_log('INFO', f"[{schedule_prefix}] 🚀 UPLOAD WORKER STARTED")
                    bg_log('INFO', f"[{schedule_prefix}] File: {local_path.name}")
                    bg_log('INFO', f"[{schedule_prefix}] Chunk ID: {chunk_id[:8] if chunk_id else 'None'}...")
                    if retry_count > 0:
                        bg_log('INFO', f"[{schedule_prefix}] 🔄 This is retry attempt #{retry_count}")
                    bg_log('INFO', f"[{schedule_prefix}] ════════════════════════════════════")
                    
                    # Upload with progress tracking and timeout
                    url = upload_to_bunny_storage(local_path, remote_path, chunk_id, schedule_id)
                    
                    if url:
                        self.results[chunk_id] = url
                        bg_log('INFO', f"[{schedule_prefix}] ✅ UPLOAD SUCCESS: {url[:60]}...")
                        
                        # Remove from pending queue
                        remove_pending_upload(chunk_id)
                        
                        # Trigger GPU processing (only if we have a valid chunk_id!)
                        if chunk_id:
                            bg_log('INFO', f"[{schedule_prefix}] 🎯 Triggering GPU processing...")
                            trigger_modal_processing(chunk_id, url, schedule_id)
                        
                        # Clean up local file after successful upload
                        try:
                            if local_path.exists():
                                local_path.unlink()
                                bg_log('INFO', f"[{schedule_prefix}] 🗑️ Local file deleted to save space")
                        except Exception as e:
                            bg_log('WARNING', f"[{schedule_prefix}] Could not delete local file: {e}")
                    else:
                        bg_log('ERROR', f"[{schedule_prefix}] ❌ UPLOAD FAILED - adding to retry queue")
                        
                        # Add to failed uploads for retry
                        self.failed_uploads.append({
                            'local_path': local_path,
                            'remote_path': remote_path,
                            'chunk_id': chunk_id,
                            'schedule_id': schedule_id,
                            'retry_count': retry_count + 1
                        })
                        
                        # Update persistent queue with new retry count
                        update_pending_upload_retry(chunk_id, retry_count + 1)
                        
                        if chunk_id:
                            update_chunk_record(chunk_id, {'status': 'upload_failed'})
                    
                    self.queue.task_done()
                except Exception as e:
                    if "Empty" not in str(type(e).__name__):
                        bg_log('ERROR', f"Upload worker error: {e}")
        
        self.executor.submit(worker)
    
    def add_upload(self, local_path: Path, remote_path: str, chunk_id: str, schedule_id: str):
        """Add upload to queue - chunks are processed in order (FIFO)"""
        if chunk_id and schedule_id:
            # Track this chunk as belonging to this job
            if schedule_id not in self.job_chunks:
                self.job_chunks[schedule_id] = set()
            self.job_chunks[schedule_id].add(chunk_id)
        self.queue.put((local_path, remote_path, chunk_id, schedule_id))
    
    def wait_for_job_completion(self, schedule_id: str, timeout: int = 3600):
        """Wait for all chunks of a specific job to complete"""
        job_chunk_ids = self.get_job_chunks(schedule_id)
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            # Check if all chunks for this job have results
            completed = sum(1 for cid in job_chunk_ids if cid in self.results)
            if completed >= len(job_chunk_ids):
                return True
            time.sleep(1)
        
        return False
    
    def wait_for_completion(self, timeout: int = 3600):
        """Wait for ALL queued uploads to complete (legacy method)"""
        self.queue.join()
    
    def get_stats(self) -> dict:
        """Get upload statistics"""
        return {
            'queue_size': self.queue.qsize(),
            'failed_count': len(self.failed_uploads),
            'completed_count': len(self.results),
            'pending_on_disk': len(get_pending_uploads())
        }
    
    def stop(self):
        self.running = False
        self.queue.put(None)
        self.executor.shutdown(wait=True)
        
        # Log any remaining failed uploads
        if self.failed_uploads:
            logger.warning(f"⚠️ {len(self.failed_uploads)} uploads still pending - will retry on next run")


# =============================================================================
# MODAL GPU TRIGGER
# =============================================================================
def trigger_modal_processing(chunk_id: str, video_url: str, schedule_id: str, enable_ball_tracking: bool = True, show_field_mask: bool = False):
    """Trigger Modal GPU processing for a chunk"""
    schedule_prefix = schedule_id[:8] if schedule_id else "GPU"
    
    try:
        bg_log('INFO', f"[{schedule_prefix}] 🎯 GPU TRIGGER: Sending chunk to Modal for ball tracking...")
        bg_log('INFO', f"[{schedule_prefix}] 📹 Video: {video_url}")
        bg_log('INFO', f"[{schedule_prefix}] 🔗 Webhook: {MODAL_WEBHOOK_URL}")
        
        # Update chunk status to queued for GPU
        if chunk_id:
            bg_log('INFO', f"[{schedule_prefix}] 📝 Setting status to 'gpu_queued'...")
            update_chunk_record(chunk_id, {'status': 'gpu_queued'})
        
        # Call Modal endpoint
        payload = {
            'chunk_id': chunk_id,
            'video_url': video_url,
            'schedule_id': schedule_id,
            'field_id': FIELD_ID,
            'enable_ball_tracking': enable_ball_tracking,
            'show_field_mask': show_field_mask,
        }
        bg_log('INFO', f"[{schedule_prefix}] 📤 Sending to Modal: chunk_id={chunk_id[:8] if chunk_id else 'None'}...")
        
        response = requests.post(
            MODAL_WEBHOOK_URL,
            json=payload,
            timeout=30
        )
        
        if response.status_code == 200:
            bg_log('INFO', f"[{schedule_prefix}] ✅ GPU TRIGGERED SUCCESSFULLY!")
            bg_log('INFO', f"[{schedule_prefix}] 🎯 Modal will process and update chunk when done.")
            if chunk_id:
                update_chunk_record(chunk_id, {'status': 'gpu_processing'})
        else:
            bg_log('WARNING', f"[{schedule_prefix}] ⚠️ GPU response: HTTP {response.status_code}")
            bg_log('WARNING', f"[{schedule_prefix}] Response: {response.text[:200]}")
            # Save for retry later
            save_failed_upload(chunk_id, video_url, schedule_id)
            
    except Exception as e:
        bg_log('ERROR', f"[{schedule_prefix}] ❌ GPU trigger failed: {e}")
        # Save for retry later
        save_failed_upload(chunk_id, video_url, schedule_id)
        import traceback
        bg_log('ERROR', f"[{schedule_prefix}] {traceback.format_exc()}")


# =============================================================================
# RECORDING MANAGER
# =============================================================================
def process_schedule(schedule: Dict, camera: CameraRecorder, uploader: BackgroundUploader):
    """Process a single recording schedule"""
    global current_schedule_id
    
    schedule_id = schedule['id']
    current_schedule_id = schedule_id  # Set for logging
    
    # ═══════════════════════════════════════════════════════════════
    # SAFETY CHECK 1: Is another recording in progress?
    # ═══════════════════════════════════════════════════════════════
    if is_recording_active():
        bg_log('WARNING', f"[{schedule_id[:8]}] ⚠️ Another recording is in progress! Waiting...")
        # Wait up to 2 MINUTES max (reduced from 30!) - check frequently
        wait_start = time.time()
        max_wait = 2 * 60  # 2 minutes (was 30 minutes - way too long!)
        check_count = 0
        while is_recording_active() and (time.time() - wait_start) < max_wait:
            time.sleep(5)  # Check every 5 seconds (was 30 - too slow!)
            check_count += 1
            if check_count % 6 == 0:  # Log every 30 seconds
                elapsed = int(time.time() - wait_start)
                bg_log('INFO', f"[{schedule_id[:8]}] ⏳ Still waiting for previous recording... ({elapsed}s)")
            if shutdown_requested:
                return
        
        if is_recording_active():
            # After 2 minutes, force clear the lock - it's probably stale!
            bg_log('WARNING', f"[{schedule_id[:8]}] ⚠️ Lock still exists after 2min wait - forcing removal (likely stale)")
            force_remove_lock()
            # Double-check it's actually clear now
            if is_recording_active():
                bg_log('ERROR', f"[{schedule_id[:8]}] ❌ Cannot clear recording lock! Skipping this job.")
                return
        bg_log('INFO', f"[{schedule_id[:8]}] ✅ Previous recording finished, starting this one...")
    
    # ═══════════════════════════════════════════════════════════════
    # SAFETY CHECK 2: Do we have enough disk space?
    # ═══════════════════════════════════════════════════════════════
    disk_ok, free_gb = check_disk_space()
    if not disk_ok:
        bg_log('ERROR', f"[{schedule_id[:8]}] ❌ NOT ENOUGH DISK SPACE! Only {free_gb:.1f}GB free (need {MIN_DISK_SPACE_GB}GB)")
        bg_log('ERROR', f"[{schedule_id[:8]}] Run: rm -rf /home/pi/recordings/* to free space")
        update_schedule_status(schedule_id, 'failed', {'error': f'Disk space too low: {free_gb:.1f}GB'})
        return
    else:
        bg_log('INFO', f"[{schedule_id[:8]}] 💾 Disk space OK: {free_gb:.1f}GB free")
    
    start_time = datetime.fromisoformat(schedule['start_time'].replace('Z', '+00:00'))
    end_time = datetime.fromisoformat(schedule['end_time'].replace('Z', '+00:00'))
    enable_tracking = schedule.get('enable_ball_tracking', False)
    original_total_chunks = schedule.get('total_chunks', 1)
    
    now = datetime.now(start_time.tzinfo)
    remaining_seconds = int((end_time - now).total_seconds())
    
    # RECALCULATE total_chunks based on ACTUAL remaining time (not scheduled time)
    # This fixes the issue where jobs that start late show "missing" chunks
    chunk_duration = CHUNK_DURATION_MINUTES * 60
    actual_total_chunks = max(1, (remaining_seconds + chunk_duration - 1) // chunk_duration)  # Ceiling division
    
    if actual_total_chunks != original_total_chunks:
        bg_log('WARNING', f"[{schedule_id[:8]}] ⚠️ LATE START: Reducing expected chunks from {original_total_chunks} to {actual_total_chunks}")
        bg_log('WARNING', f"[{schedule_id[:8]}] ⚠️ Recording started late - only {remaining_seconds // 60} min remaining instead of scheduled duration")
        # Update the database with corrected chunk count
        try:
            supabase.table('camera_recording_schedules').update({
                'total_chunks': actual_total_chunks,
                'actual_start_time': now.isoformat()  # Track when we actually started
            }).eq('id', schedule_id).execute()
        except Exception as e:
            bg_log('WARNING', f"[{schedule_id[:8]}] Could not update total_chunks in DB: {e}")
    
    total_chunks = actual_total_chunks
    
    if remaining_seconds <= 0:
        bg_log('WARNING', f"[{schedule_id[:8]}] End time passed ({end_time.strftime('%H:%M')}) - marking as completed")
        update_schedule_status(schedule_id, 'completed')
        return
    
    # ═══════════════════════════════════════════════════════════════
    # SAFETY: Set recording lock
    # ═══════════════════════════════════════════════════════════════
    set_recording_active(True, schedule_id)
    
    # Calculate chunks
    chunk_duration = CHUNK_DURATION_MINUTES * 60
    
    # Note: Each job's chunks are tracked separately in uploader.job_chunks
    # No need to clear - previous job's uploads continue in queue!
    
    bg_log('INFO', f"[{schedule_id[:8]}] ====== STARTING SCHEDULED RECORDING ======")
    bg_log('INFO', f"[{schedule_id[:8]}] Time: {start_time.strftime('%H:%M')} - {end_time.strftime('%H:%M')}")
    bg_log('INFO', f"[{schedule_id[:8]}] Duration: {remaining_seconds // 60} minutes")
    bg_log('INFO', f"[{schedule_id[:8]}] Chunks: {total_chunks} x {CHUNK_DURATION_MINUTES} min each")
    if enable_tracking:
        bg_log('INFO', f"[{schedule_id[:8]}] 🎯 BALL TRACKING MODE - Chunks will be processed with GPU!")
    bg_log('INFO', f"[{schedule_id[:8]}] =========================================")
    
    # Update schedule status to recording with started_at timestamp
    update_schedule_status(schedule_id, 'recording', {
        'started_at': datetime.utcnow().isoformat()
    })
    update_camera_status('recording', {'schedule_id': schedule_id, 'message': 'Recording in progress'})
    
    recorded_chunks = 0
    chunk_urls = []
    total_size = 0
    
    chunk_number = 1
    while not shutdown_requested:
        now = datetime.now(start_time.tzinfo)
        remaining = int((end_time - now).total_seconds())
        
        if remaining <= 0:
            break
        
        # Calculate this chunk's duration
        this_chunk_duration = min(chunk_duration, remaining)
        
        bg_log('INFO', f"[{schedule_id[:8]}] ------ CHUNK {chunk_number}/{total_chunks} ------")
        
        # Create chunk filename
        filename = f"{schedule_id[:8]}_chunk_{chunk_number:03d}.mp4"
        local_path = RECORDING_DIR / filename
        
        bg_log('INFO', f"[{schedule_id[:8]}] 📁 File: {filename}")
        bg_log('INFO', f"[{schedule_id[:8]}] ⏺️ RECORDING chunk {chunk_number}/{total_chunks} ({this_chunk_duration / 60:.1f} min)")
        bg_log('INFO', f"[{schedule_id[:8]}] 🚀 Sequential upload system active - full bandwidth per chunk!")
        
        # Create chunk record in DB BEFORE recording starts
        chunk_id = create_chunk_record(schedule_id, chunk_number, filename)
        
        if not chunk_id:
            bg_log('ERROR', f"[{schedule_id[:8]}] ❌ CRITICAL: Could not create chunk record! Check DB permissions.")
            bg_log('ERROR', f"[{schedule_id[:8]}] ❌ FIELD_ID: {FIELD_ID}")
            bg_log('ERROR', f"[{schedule_id[:8]}] ❌ Continuing anyway - will try to upload without DB tracking...")
        
        # Update schedule with current chunk being recorded
        update_schedule_status(schedule_id, 'recording', {
            'current_chunk': chunk_number,
            'chunks_completed': chunk_number - 1
        })
        
        # Record chunk
        success = camera.record_chunk(local_path, this_chunk_duration)
        
        if success and local_path.exists():
            size_mb = local_path.stat().st_size / (1024 * 1024)
            total_size += size_mb
            recorded_chunks += 1
            
            bg_log('INFO', f"[{schedule_id[:8]}] ✅ Chunk {chunk_number}/{total_chunks} RECORDED: {size_mb:.1f} MB")
            
            # Update chunk record with recording finished timestamp
            if chunk_id:
                bg_log('INFO', f"[{schedule_id[:8]}] 📝 Updating chunk {chunk_number} status to 'recorded'...")
                update_chunk_record(chunk_id, {
                    'status': 'recorded',
                    'recording_finished_at': datetime.utcnow().isoformat(),
                    'file_size_mb': round(size_mb, 2)
                })
            
            # Queue for background upload
            remote_path = f"recordings/{FIELD_ID}/{schedule_id}/{filename}"
            bg_log('INFO', f"[{schedule_id[:8]}] 📤 Queueing chunk {chunk_number} for upload...")
            uploader.add_upload(local_path, remote_path, chunk_id, schedule_id)
            bg_log('INFO', f"[{schedule_id[:8]}] ▶️ Recording next chunk while uploading in background!")
        else:
            bg_log('ERROR', f"[{schedule_id[:8]}] ❌ Failed to record chunk {chunk_number}")
            if chunk_id:
                update_chunk_record(chunk_id, {'status': 'recording_failed'})
        
        chunk_number += 1
        
        # Check if we should continue
        if remaining - this_chunk_duration <= 0:
            break
    
    bg_log('INFO', f"[{schedule_id[:8]}] ╔══════════════════════════════════════════╗")
    bg_log('INFO', f"[{schedule_id[:8]}] ║       ALL CHUNKS RECORDED!               ║")
    bg_log('INFO', f"[{schedule_id[:8]}] ╠══════════════════════════════════════════╣")
    bg_log('INFO', f"[{schedule_id[:8]}] ║ Recorded: {recorded_chunks}/{total_chunks} chunks")
    bg_log('INFO', f"[{schedule_id[:8]}] ║ Total Size: {total_size:.1f} MB")
    bg_log('INFO', f"[{schedule_id[:8]}] ╚══════════════════════════════════════════╝")
    
    # ═══════════════════════════════════════════════════════════════
    # RELEASE RECORDING LOCK - Allow next recording to start!
    # Uploads will continue in background
    # ═══════════════════════════════════════════════════════════════
    bg_log('INFO', f"[{schedule_id[:8]}] 🔓 Releasing recording lock...")
    set_recording_active(False)
    
    # CRITICAL: Verify lock is actually released!
    time.sleep(0.5)  # Small delay to ensure filesystem sync
    if is_recording_active():
        bg_log('ERROR', f"[{schedule_id[:8]}] ❌ CRITICAL: Lock still exists after release! Force removing...")
        force_remove_lock()
        time.sleep(0.5)
        if is_recording_active():
            bg_log('ERROR', f"[{schedule_id[:8]}] ❌❌ LOCK REMOVAL FAILED - next jobs may be delayed!")
        else:
            bg_log('INFO', f"[{schedule_id[:8]}] ✅ Lock force-removed successfully")
    else:
        bg_log('INFO', f"[{schedule_id[:8]}] ✅ Recording lock released - next job can start NOW!")
    
    # Update status to uploading
    bg_log('INFO', f"[{schedule_id[:8]}] 📝 Updating schedule status to 'uploading'...")
    update_schedule_status(schedule_id, 'uploading', {
        'chunks_recorded': recorded_chunks,
        'recording_ended_at': datetime.utcnow().isoformat()
    })
    
    # ═══════════════════════════════════════════════════════════════
    # START BACKGROUND THREAD for upload completion tracking
    # This allows the main loop to pick up the next job immediately!
    # ═══════════════════════════════════════════════════════════════
    
    # Store job info for background thread (avoid closure issues)
    job_info = {
        'schedule_id': schedule_id,
        'recorded_chunks': recorded_chunks,
        'total_size': total_size,
        'enable_tracking': enable_tracking,
    }
    
    def track_upload_completion(info):
        """Background thread to track upload completion without blocking main loop"""
        sid = info['schedule_id']
        rec_chunks = info['recorded_chunks']
        size = info['total_size']
        tracking = info['enable_tracking']
        
        bg_log('INFO', f"[{sid[:8]}] ⏳ Upload tracking started (background thread)")
        bg_log('INFO', f"[{sid[:8]}] 🚀 Main loop is FREE to start next job!")
        bg_log('INFO', f"[{sid[:8]}] 📋 This job's chunks will upload IN ORDER (after any previous job's chunks)")
        
        # Wait for THIS JOB's uploads to complete (doesn't block other jobs!)
        uploader.wait_for_job_completion(sid, timeout=3600)
        
        # Get results - ONLY for this job's chunks!
        current_job_results = uploader.get_job_results(sid)
        successful_uploads = sum(1 for url in current_job_results.values() if url)
        
        bg_log('INFO', f"[{sid[:8]}] ╔══════════════════════════════════════════╗")
        bg_log('INFO', f"[{sid[:8]}] ║         UPLOAD COMPLETE!                 ║")
        bg_log('INFO', f"[{sid[:8]}] ╠══════════════════════════════════════════╣")
        bg_log('INFO', f"[{sid[:8]}] ║ Successful: {successful_uploads}/{rec_chunks} chunks")
        bg_log('INFO', f"[{sid[:8]}] ║ Total Size: {size:.1f} MB")
        
        for chunk_id_key, url in current_job_results.items():
            if url:
                bg_log('INFO', f"[{sid[:8]}] ║ 📹 {url}")
        
        bg_log('INFO', f"[{sid[:8]}] ╚══════════════════════════════════════════╝")
        
        if successful_uploads == rec_chunks:
            bg_log('INFO', f"[{sid[:8]}] ✅ ALL CHUNKS UPLOADED SUCCESSFULLY!")
        else:
            bg_log('WARNING', f"[{sid[:8]}] ⚠️ {rec_chunks - successful_uploads} chunks FAILED to upload")
        
        # Update schedule status
        final_status = 'processing' if tracking else 'completed'
        bg_log('INFO', f"[{sid[:8]}] 📝 Updating schedule status to '{final_status}'...")
        update_schedule_status(sid, final_status, {
            'chunks_recorded': rec_chunks,
            'chunks_uploaded': successful_uploads,
            'total_size_mb': size,
            'completed_at': datetime.utcnow().isoformat() if not tracking else None
        })
        
        if tracking:
            bg_log('INFO', f"[{sid[:8]}] ╔══════════════════════════════════════════╗")
            bg_log('INFO', f"[{sid[:8]}] ║     🎯 GPU PROCESSING IN PROGRESS!      ║")
            bg_log('INFO', f"[{sid[:8]}] ║  Final video will be ready when done!   ║")
            bg_log('INFO', f"[{sid[:8]}] ╚══════════════════════════════════════════╝")
        else:
            bg_log('INFO', f"[{sid[:8]}] ✅ JOB COMPLETED! Raw video available.")
        
        bg_log('INFO', f"[{sid[:8]}] 📋 Upload tracking thread finished")
    
    # Start upload tracking in background thread
    upload_thread = threading.Thread(target=track_upload_completion, args=(job_info,), daemon=True)
    upload_thread.start()
    
    bg_log('INFO', f"[{schedule_id[:8]}] 🚀 Recording function RETURNING - main loop can process next job!")
    update_camera_status('online', {'last_recording': schedule_id})
    # Recording lock released, function returns, main loop picks up next job!


# =============================================================================
# REPLAY FROM SD / CAMERA STORAGE (e.g. camera records 6-12 daily to SD)
# =============================================================================
def process_replay_schedule(schedule: Dict, uploader: BackgroundUploader) -> None:
    """
    Process a 'replay_requested' schedule: find video files on SD/storage for the
    schedule's date and time range, upload to Bunny, trigger GPU. Does not use camera.
    """
    schedule_id = schedule['id']
    if not SD_FOOTAGE_BASE_DIR or not Path(SD_FOOTAGE_BASE_DIR).exists():
        logger.warning(f"[{schedule_id[:8]}] Replay skipped: SD_FOOTAGE_BASE_DIR not set or missing")
        update_schedule_status(schedule_id, 'cancelled', {'error_message': 'SD_FOOTAGE_BASE_DIR not configured'})
        return

    files = find_footage_files_for_schedule(schedule)
    if not files:
        logger.warning(f"[{schedule_id[:8]}] No footage files found for schedule time range")
        update_schedule_status(schedule_id, 'completed', {'error_message': 'No footage found on storage'})
        return

    enable_tracking = schedule.get('enable_ball_tracking', True)
    show_mask = schedule.get('show_field_mask', False)
    update_schedule_status(schedule_id, 'uploading', {
        'started_at': datetime.utcnow().isoformat(),
        'chunks_recorded': len(files),
    })
    update_camera_status('recording', {'schedule_id': schedule_id, 'message': 'Replay from storage'})

    chunk_number = 0
    for local_path in files:
        chunk_number += 1
        if shutdown_requested:
            break
        filename = f"{schedule_id[:8]}_replay_{chunk_number:03d}{local_path.suffix}"
        chunk_id = create_chunk_record(schedule_id, chunk_number, filename)
        if not chunk_id:
            continue
        remote_path = f"recordings/{FIELD_ID}/{schedule_id}/{filename}"
        url = upload_to_bunny_storage(local_path, remote_path, chunk_id=chunk_id, schedule_id=schedule_id)
        if url:
            update_chunk_record(chunk_id, {'video_url': url, 'upload_progress': 100, 'status': 'uploaded'})
            trigger_modal_processing(chunk_id, url, schedule_id, enable_ball_tracking=enable_tracking, show_field_mask=show_mask)
        else:
            update_chunk_record(chunk_id, {'status': 'upload_failed'})

    final_status = 'processing' if enable_tracking else 'completed'
    update_schedule_status(schedule_id, final_status, {
        'recording_ended_at': datetime.utcnow().isoformat(),
        'chunks_recorded': chunk_number,
    })
    update_camera_status('online', {'last_recording': schedule_id})
    logger.info(f"[{schedule_id[:8]}] Replay from storage done: {chunk_number} chunks sent to pipeline")


# =============================================================================
# SCREENSHOT & FIELD MASK MONITORING
# =============================================================================
# Required Supabase columns (add to camera_status table if not present):
#   ALTER TABLE camera_status ADD COLUMN IF NOT EXISTS screenshot_requested BOOLEAN DEFAULT FALSE;
#   ALTER TABLE camera_status ADD COLUMN IF NOT EXISTS screenshot_url TEXT;
#   ALTER TABLE camera_status ADD COLUMN IF NOT EXISTS screenshot_at TIMESTAMPTZ;
#
# Required table (create if not present):
#   CREATE TABLE IF NOT EXISTS field_masks (
#     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
#     field_id TEXT NOT NULL UNIQUE,
#     mask_points JSONB NOT NULL,
#     updated_at TIMESTAMPTZ DEFAULT NOW(),
#     created_at TIMESTAMPTZ DEFAULT NOW()
#   );
# =============================================================================
last_field_mask_version = None  # Track field mask changes


def check_screenshot_request() -> bool:
    """Check if admin has requested a screenshot via camera_status table"""
    try:
        result = supabase.table('camera_status')\
            .select('screenshot_requested')\
            .eq('field_id', FIELD_ID)\
            .maybe_single()\
            .execute()
        if result.data:
            return result.data.get('screenshot_requested', False) == True
        return False
    except Exception as e:
        # Column might not exist yet - that's OK
        return False


def capture_screenshot(rtsp_url: str) -> Optional[str]:
    """Capture a single frame from the camera and upload to BunnyCDN"""
    timestamp = int(time.time())
    screenshot_path = SCREENSHOT_DIR / f"screenshot_{FIELD_ID[:8]}_{timestamp}.jpg"

    try:
        logger.info("📸 Capturing screenshot from camera...")

        cmd = [
            'ffmpeg', '-y',
            '-rtsp_transport', 'tcp',
            '-i', rtsp_url,
            '-vframes', '1',
            '-q:v', '2',  # High quality JPEG
            str(screenshot_path)
        ]
        result = subprocess.run(cmd, capture_output=True, timeout=15)

        if result.returncode == 0 and screenshot_path.exists():
            size_kb = screenshot_path.stat().st_size / 1024
            logger.info(f"📸 Screenshot captured: {size_kb:.0f} KB")

            # Upload to BunnyCDN
            remote_path = f"screenshots/{FIELD_ID}/screenshot_{timestamp}.jpg"
            cdn_url = upload_screenshot_to_bunny(screenshot_path, remote_path)

            # Clean up local file
            try:
                screenshot_path.unlink(missing_ok=True)
            except:
                pass

            return cdn_url
        else:
            stderr = result.stderr.decode()[:200] if result.stderr else 'unknown error'
            logger.error(f"📸 Screenshot capture failed: {stderr}")
            return None
    except subprocess.TimeoutExpired:
        logger.error("📸 Screenshot capture timed out")
        return None
    except Exception as e:
        logger.error(f"📸 Screenshot error: {e}")
        return None


def upload_screenshot_to_bunny(local_path: Path, remote_path: str) -> Optional[str]:
    """Upload screenshot JPEG to BunnyCDN (simple single PUT)"""
    url = f"{BUNNY_STORAGE_URL}/{remote_path}"
    try:
        with open(local_path, 'rb') as f:
            response = requests.put(
                url,
                headers={
                    'AccessKey': BUNNY_API_KEY,
                    'Content-Type': 'image/jpeg'
                },
                data=f,
                timeout=30
            )
        if response.status_code in [200, 201]:
            cdn_url = f"{BUNNY_CDN_URL}/{remote_path}"
            logger.info(f"📸 Screenshot uploaded: {cdn_url}")
            return cdn_url
        else:
            logger.error(f"📸 Screenshot upload failed: HTTP {response.status_code}")
            return None
    except Exception as e:
        logger.error(f"📸 Screenshot upload error: {e}")
        return None


def handle_screenshot_request(rtsp_url: str):
    """Handle a screenshot request from admin app"""
    logger.info("📸 Screenshot requested by admin!")
    bg_log('INFO', '📸 Screenshot requested by admin - capturing frame...')

    cdn_url = capture_screenshot(rtsp_url)

    if cdn_url:
        # Update camera_status with screenshot URL and clear request flag
        try:
            supabase.table('camera_status').update({
                'screenshot_url': cdn_url,
                'screenshot_at': datetime.utcnow().isoformat(),
                'screenshot_requested': False,
            }).eq('field_id', FIELD_ID).execute()

            bg_log('INFO', f'📸 Screenshot ready: {cdn_url}')
            logger.info(f"📸 Screenshot available for admin")
        except Exception as e:
            logger.error(f"📸 Failed to update screenshot status: {e}")
            # Try to at least clear the request
            try:
                supabase.table('camera_status').update({
                    'screenshot_requested': False,
                }).eq('field_id', FIELD_ID).execute()
            except:
                pass
    else:
        # Clear request even on failure so it doesn't retry endlessly
        try:
            supabase.table('camera_status').update({
                'screenshot_requested': False,
            }).eq('field_id', FIELD_ID).execute()
        except:
            pass
        bg_log('ERROR', '📸 Screenshot capture failed - camera may be unreachable')


def check_field_mask_updates():
    """Check if the field mask has been updated and log acknowledgement"""
    global last_field_mask_version
    try:
        result = supabase.table('field_masks')\
            .select('updated_at')\
            .eq('field_id', FIELD_ID)\
            .maybe_single()\
            .execute()

        if result.data:
            current_version = result.data.get('updated_at')
            if last_field_mask_version is None:
                # First check - just record the current version
                last_field_mask_version = current_version
                logger.info(f"📐 Field mask loaded (last updated: {current_version})")
            elif current_version != last_field_mask_version:
                # Mask was updated!
                last_field_mask_version = current_version
                logger.info("📐 New field mask applied!")
                bg_log('INFO', '📐 New field mask applied! Ball tracking will use the updated boundary on next processing job.')
    except:
        pass  # field_masks table might not exist yet


# =============================================================================
# SELF-UPDATE SYSTEM
# =============================================================================
# Required Supabase table (create if not present):
#   CREATE TABLE IF NOT EXISTS pi_script_updates (
#     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
#     version TEXT NOT NULL,
#     script_url TEXT NOT NULL,
#     changelog TEXT,
#     pushed_at TIMESTAMPTZ DEFAULT NOW(),
#     pushed_by TEXT DEFAULT 'admin'
#   );
# =============================================================================
SCRIPT_PATH = Path(os.path.abspath(__file__))  # Path to THIS script file


def check_for_script_update():
    """Check Supabase for a newer script version and self-update if available"""
    global supabase
    if not supabase:
        return

    try:
        # Get the latest pushed script version
        result = supabase.table('pi_script_updates')\
            .select('version, script_url, changelog')\
            .order('pushed_at', desc=True)\
            .limit(1)\
            .execute()

        if not result.data:
            return  # No updates published yet

        latest = result.data[0]
        latest_version = latest.get('version', '')
        script_url = latest.get('script_url', '')
        changelog = latest.get('changelog', '')

        if not latest_version or not script_url:
            return

        # Compare versions (simple string comparison: "9.0" > "8.8")
        try:
            current = float(SCRIPT_VERSION)
            remote = float(latest_version)
            if remote <= current:
                return  # Already up to date
        except ValueError:
            # Fallback to string comparison
            if latest_version <= SCRIPT_VERSION:
                return

        logger.info(f"🔄 UPDATE AVAILABLE: v{SCRIPT_VERSION} → v{latest_version}")
        if changelog:
            logger.info(f"📋 Changelog: {changelog}")
        bg_log('INFO', f'🔄 Script update available: v{SCRIPT_VERSION} → v{latest_version}')

        # Download the new script
        logger.info(f"📥 Downloading new script from CDN...")
        try:
            response = requests.get(script_url, timeout=30)
            if response.status_code != 200:
                logger.error(f"❌ Download failed: HTTP {response.status_code}")
                return

            new_content = response.text

            # Safety checks
            if len(new_content) < 1000:
                logger.error(f"❌ Downloaded script too small ({len(new_content)} bytes) - aborting update")
                return

            if 'SCRIPT_VERSION' not in new_content:
                logger.error("❌ Downloaded script doesn't contain SCRIPT_VERSION - aborting update")
                return

            if 'def main()' not in new_content:
                logger.error("❌ Downloaded script doesn't contain main() function - aborting update")
                return

            logger.info(f"✅ Download OK ({len(new_content)} bytes)")

        except Exception as e:
            logger.error(f"❌ Download error: {e}")
            return

        # Write to temp file first, then replace
        temp_path = SCRIPT_PATH.parent / f"field_camera_update_{latest_version}.py"
        try:
            temp_path.write_text(new_content)
            logger.info(f"✅ Temp file written: {temp_path}")

            # Replace the current script
            import shutil
            shutil.copy2(str(temp_path), str(SCRIPT_PATH))
            logger.info(f"✅ Script replaced: {SCRIPT_PATH}")

            # Clean up temp file
            temp_path.unlink(missing_ok=True)

            # Log the update
            bg_log('INFO', f'✅ Script updated from v{SCRIPT_VERSION} to v{latest_version} — restarting...')
            logger.info(f"🔄 Script updated to v{latest_version} — restarting in 3 seconds...")

            # Give the log time to flush
            time.sleep(3)

            # Exit cleanly - systemd Restart=always will restart with new code
            logger.info("🔄 Exiting for restart...")
            os._exit(0)

        except Exception as e:
            logger.error(f"❌ Failed to replace script: {e}")
            bg_log('ERROR', f'❌ Script update failed: {e}')
            # Clean up temp file on failure
            try:
                temp_path.unlink(missing_ok=True)
            except:
                pass

    except Exception as e:
        # Don't log every time - table might not exist
        pass


# =============================================================================
# MAIN LOOP
# =============================================================================
def main():
    global shutdown_requested
    
    print("=" * 60)
    print("Camera IP is fetched from Supabase Admin app!")
    print("Change it in: Admin → Field → Camera tab")
    print("🌐 REMOTE CONFIG MODE (v4.0)")
    print("=" * 60)
    
    # Initialize
    init_supabase()
    
    # ═══════════════════════════════════════════════════════════════
    # STARTUP SAFETY CHECKS
    # ═══════════════════════════════════════════════════════════════
    # Check disk space
    disk_ok, free_gb = check_disk_space()
    logger.info(f"💾 Disk space: {free_gb:.1f}GB free {'✅' if disk_ok else '⚠️ LOW!'}")
    
    # Clear any stale recording locks
    if ACTIVE_RECORDING_LOCK.exists():
        logger.warning("Found stale recording lock from crash - clearing...")
        set_recording_active(False)
    
    # Retry any failed uploads from previous runs
    retry_failed_uploads()
    
    # Get field config
    field_config = get_field_config()
    if not field_config:
        logger.error("❌ Failed to get field configuration!")
        return
    
    camera_ip = field_config.get('camera_ip_address')
    if not camera_ip:
        logger.error("❌ No camera IP configured for this field!")
        return
    
    logger.info(f"✅ Using remote camera IP from Admin app!")
    logger.info(f"📹 Camera: {camera_ip}")
    logger.info(f"📍 Field: {field_config.get('football_field_name', 'Unknown')} ({FIELD_ID[:8]}...)")
    logger.info(f"💾 Recording dir: {RECORDING_DIR}")
    logger.info(f"⏱️ Chunk duration: {CHUNK_DURATION_MINUTES} minutes")
    
    # Build RTSP URL
    camera_user = os.getenv('CAMERA_USER', 'admin')
    camera_pass = os.getenv('CAMERA_PASS', 'Mancity99+')
    rtsp_url = f"rtsp://{camera_user}:{camera_pass}@{camera_ip}:554/h264Preview_01_main"
    
    # Create camera recorder
    camera = CameraRecorder(rtsp_url)
    
    # Test connection
    logger.info("🔍 Testing camera connection...")
    if camera.test_connection():
        logger.info("✅ Camera connected!")
    else:
        logger.warning("⚠️ Camera connection test failed - will retry on recording")
    
    print("=" * 60)
    logger.info(f"📦 Script version: {SCRIPT_VERSION}")
    logger.info(f"🔧 BULLETPROOF MODE: Detailed logging enabled!")
    logger.info("👀 Waiting for scheduled recordings...")
    logger.info("🔄 Auto-update: ENABLED")
    logger.info("")
    logger.info("📊 Pipeline: RECORD → UPLOAD → GPU → DONE")
    logger.info("📝 All steps logged to Supabase camera_logs table")
    print("=" * 60)
    
    # Send heartbeat - use 'online' so UI shows green status
    update_camera_status('online', {'camera_ok': camera.test_connection()})
    logger.info("💓 Heartbeat sent - Status: ONLINE")
    
    # Create uploader
    uploader = BackgroundUploader()
    
    # Scan for any orphaned chunks from previous runs
    scan_for_orphaned_chunks(uploader)
    
    # Check network health at startup
    net_ok, latency = check_network_health()
    if net_ok:
        logger.info(f"🌐 Network: HEALTHY (latency: {latency}ms)")
    else:
        logger.warning(f"🌐 Network: DEGRADED (latency: {latency}ms) - uploads may be slow")
    
    last_heartbeat = time.time()
    last_screenshot_check = 0
    last_mask_check = 0
    last_update_check = 0
    
    # Initial field mask check
    check_field_mask_updates()
    
    # Check for updates at startup
    check_for_script_update()
    
    try:
        while not shutdown_requested:
            # Heartbeat every 30 seconds - use 'online' for UI
            if time.time() - last_heartbeat > 30:
                update_camera_status('online', {'camera_ok': True})
                last_heartbeat = time.time()
            
            # Check for screenshot requests every 5 seconds
            if time.time() - last_screenshot_check > 5:
                try:
                    if check_screenshot_request():
                        handle_screenshot_request(rtsp_url)
                except Exception as e:
                    logger.warning(f"Screenshot check error: {e}")
                last_screenshot_check = time.time()
            
            # Check for field mask updates every 60 seconds
            if time.time() - last_mask_check > 60:
                check_field_mask_updates()
                last_mask_check = time.time()
            
            # Check for script updates every 60 seconds
            if time.time() - last_update_check > 60:
                check_for_script_update()
                last_update_check = time.time()
            
            # Check for pending schedules (live recording)
            schedules = get_pending_schedules()
            
            for schedule in schedules:
                if shutdown_requested:
                    break
                
                schedule_id = schedule['id']
                status = schedule.get('status', 'scheduled')
                
                if status == 'scheduled':
                    # Start time check
                    start_time = datetime.fromisoformat(schedule['start_time'].replace('Z', '+00:00'))
                    end_time = datetime.fromisoformat(schedule['end_time'].replace('Z', '+00:00'))
                    now = datetime.now(start_time.tzinfo)
                    
                    if now >= start_time - timedelta(seconds=30):
                        remaining = int((end_time - now).total_seconds() // 60)
                        logger.info(f"🚀 Job {schedule_id[:8]}: STARTING NOW! Start time passed, {remaining} min remaining until {end_time.strftime('%H:%M')}")
                        logger.info(f"▶️ Processing schedule {schedule_id[:8]}...")
                        process_schedule(schedule, camera, uploader)
                
                elif status == 'recording':
                    # Resume interrupted recording
                    logger.info(f"🔄 Resuming recording: {schedule_id[:8]}...")
                    process_schedule(schedule, camera, uploader)
            
            # Replay from SD/camera storage (only when no live recording)
            if not is_recording_active() and SD_FOOTAGE_BASE_DIR:
                replay_schedules = get_replay_schedules()
                for replay in replay_schedules:
                    if shutdown_requested:
                        break
                    logger.info(f"📂 Replay from storage: {replay['id'][:8]}...")
                    process_replay_schedule(replay, uploader)
                    break  # Process one replay job per loop
            
            time.sleep(5)
            
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
    finally:
        uploader.stop()
        update_camera_status('offline')
        logger.info("Camera script stopped")


if __name__ == '__main__':
    main()

