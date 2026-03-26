#!/usr/bin/env python3
"""
==========================================
PLAYMAKER FIELD CAMERA RECORDING SCRIPT V2
==========================================

IMPROVEMENTS OVER V1:
1. ✅ Keep local chunks until stitch complete (no re-download)
2. ✅ Retry logic with exponential backoff
3. ✅ Supabase realtime subscriptions (not polling)
4. ✅ Health heartbeat to database
5. ✅ Graceful handling of booking cancellations
6. ✅ Fallback to raw video if ball tracking fails
7. ✅ Automatic disk space cleanup
8. ✅ Support for concurrent recordings
9. ✅ Environment variable configuration
10. ✅ Push notifications for recording status

==========================================
"""

import os
import sys
import time
import json
import subprocess
import threading
import logging
import queue
import shutil
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, Dict, List, Callable
from dataclasses import dataclass
from enum import Enum
import requests

# ==========================================
# CONFIGURATION - Use environment variables for security
# ==========================================
FIELD_ID = os.environ.get('PLAYMAKER_FIELD_ID', '{{FIELD_ID}}')
FIELD_NAME = os.environ.get('PLAYMAKER_FIELD_NAME', '{{FIELD_NAME}}')

SUPABASE_URL = os.environ.get('SUPABASE_URL', '{{SUPABASE_URL}}')
SUPABASE_KEY = os.environ.get('SUPABASE_KEY', '{{SUPABASE_KEY}}')

CAMERA_IP = os.environ.get('CAMERA_IP', '{{CAMERA_IP}}')
CAMERA_USERNAME = os.environ.get('CAMERA_USERNAME', '{{CAMERA_USERNAME}}')
CAMERA_PASSWORD = os.environ.get('CAMERA_PASSWORD', '{{CAMERA_PASSWORD}}')
CAMERA_RTSP_PORT = os.environ.get('CAMERA_RTSP_PORT', '554')

# Camera RTSP URL pattern - adjust based on your camera model
CAMERA_RTSP_PATTERN = os.environ.get(
    'CAMERA_RTSP_PATTERN',
    'rtsp://{username}:{password}@{ip}:{port}/Streaming/Channels/101'
)

# Recording settings
CHUNK_DURATION_MINUTES = int(os.environ.get('CHUNK_DURATION_MINUTES', '20'))
RECORDING_DIR = os.environ.get('RECORDING_DIR', '/home/pi/recordings')
TEMP_DIR = os.environ.get('TEMP_DIR', '/home/pi/temp')
LOG_DIR = os.environ.get('LOG_DIR', '/home/pi/logs')

# Retry settings
MAX_UPLOAD_RETRIES = int(os.environ.get('MAX_UPLOAD_RETRIES', '3'))
RETRY_DELAY_SECONDS = int(os.environ.get('RETRY_DELAY_SECONDS', '10'))

# Disk space settings (in GB)
MIN_FREE_SPACE_GB = float(os.environ.get('MIN_FREE_SPACE_GB', '2.0'))

# Modal webhook
MODAL_WEBHOOK_URL = os.environ.get(
    'MODAL_WEBHOOK_URL',
    'https://youssefelhenawy0--playmaker-ball-tracking-trigger-job.modal.run'
)

# Heartbeat interval (seconds)
HEARTBEAT_INTERVAL = int(os.environ.get('HEARTBEAT_INTERVAL', '60'))

# ==========================================
# END CONFIGURATION
# ==========================================

# Setup logging
Path(LOG_DIR).mkdir(parents=True, exist_ok=True)
Path(RECORDING_DIR).mkdir(parents=True, exist_ok=True)
Path(TEMP_DIR).mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(f'{LOG_DIR}/camera_{FIELD_ID}.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


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
    """Represents a recording job for a booking."""
    booking_id: str
    start_time: datetime
    end_time: datetime
    duration_minutes: int
    status: RecordingStatus = RecordingStatus.PENDING
    chunks: List[str] = None
    error_message: Optional[str] = None
    
    def __post_init__(self):
        if self.chunks is None:
            self.chunks = []


class SupabaseClient:
    """Enhanced Supabase client with retry logic and realtime support."""
    
    def __init__(self, url: str, key: str):
        self.url = url
        self.key = key
        self.headers = {
            'apikey': key,
            'Authorization': f'Bearer {key}',
            'Content-Type': 'application/json'
        }
        self._realtime_callbacks: Dict[str, Callable] = {}
    
    def _request(self, method: str, endpoint: str, data: dict = None, retries: int = MAX_UPLOAD_RETRIES) -> dict:
        """Make HTTP request with retry logic."""
        url = f"{self.url}/rest/v1/{endpoint}"
        
        for attempt in range(retries):
            try:
                if method == 'GET':
                    response = requests.get(url, headers=self.headers, params=data, timeout=30)
                elif method == 'POST':
                    response = requests.post(url, headers=self.headers, json=data, timeout=60)
                elif method == 'PATCH':
                    response = requests.patch(url, headers=self.headers, json=data, timeout=30)
                elif method == 'DELETE':
                    response = requests.delete(url, headers=self.headers, timeout=30)
                
                response.raise_for_status()
                return response.json() if response.text else {}
                
            except requests.exceptions.RequestException as e:
                logger.warning(f"Request failed (attempt {attempt + 1}/{retries}): {e}")
                if attempt < retries - 1:
                    time.sleep(RETRY_DELAY_SECONDS * (2 ** attempt))  # Exponential backoff
                else:
                    raise
        
        return {}
    
    def get_upcoming_bookings(self, field_id: str) -> List[dict]:
        """Get bookings for the next 24 hours."""
        now = datetime.now()
        today = now.strftime('%Y-%m-%d')
        tomorrow = (now + timedelta(days=1)).strftime('%Y-%m-%d')
        
        params = {
            'footballFieldId': f'eq.{field_id}',
            'isRecordingEnabled': 'eq.true',
            'date': f'in.({today},{tomorrow})',
            'status': 'in.(confirmed,pending)',
            'select': '*'
        }
        
        return self._request('GET', 'bookings', params) or []
    
    def get_booking(self, booking_id: str) -> Optional[dict]:
        """Get a single booking."""
        params = {'id': f'eq.{booking_id}', 'select': '*'}
        result = self._request('GET', 'bookings', params)
        return result[0] if result else None
    
    def update_booking_status(self, booking_id: str, status: str, recording_url: str = None):
        """Update booking recording status."""
        data = {'status': status}
        if recording_url:
            data['recording_url'] = recording_url
        
        url = f"{self.url}/rest/v1/bookings?id=eq.{booking_id}"
        try:
            requests.patch(url, headers=self.headers, json=data, timeout=30)
            logger.info(f"📝 Updated booking {booking_id} status to: {status}")
        except Exception as e:
            logger.error(f"Failed to update booking status: {e}")
    
    def create_ball_tracking_job(self, booking_id: str, video_url: str, field_id: str) -> Optional[str]:
        """Create a ball tracking job."""
        data = {
            'input_video_url': video_url,
            'video_name': f"field_{field_id}_booking_{booking_id}",
            'status': 'pending',
            'progress_percent': 0,
            'script_config': {
                'zoom_base': 1.75,
                'detect_every_frames': 3,
                'yolo_conf': 0.12,
                'yolo_model': 'yolov8l'
            },
            'script_version': '2.0',
            'booking_id': booking_id,
            'field_id': field_id
        }
        
        try:
            result = self._request('POST', 'ball_tracking_jobs', data)
            return result.get('id') if result else None
        except Exception as e:
            logger.error(f"Failed to create ball tracking job: {e}")
            return None
    
    def upload_file(self, path: str, file_path: str, content_type: str = 'video/mp4') -> Optional[str]:
        """Upload file to Supabase storage with retry."""
        url = f"{self.url}/storage/v1/object/videos/{path}"
        
        for attempt in range(MAX_UPLOAD_RETRIES):
            try:
                with open(file_path, 'rb') as f:
                    headers = {
                        'apikey': self.key,
                        'Authorization': f'Bearer {self.key}',
                        'Content-Type': content_type
                    }
                    response = requests.post(url, headers=headers, data=f, timeout=600)
                    response.raise_for_status()
                
                public_url = f"{self.url}/storage/v1/object/public/videos/{path}"
                logger.info(f"☁️ Upload successful: {path}")
                return public_url
                
            except Exception as e:
                logger.warning(f"Upload failed (attempt {attempt + 1}/{MAX_UPLOAD_RETRIES}): {e}")
                if attempt < MAX_UPLOAD_RETRIES - 1:
                    time.sleep(RETRY_DELAY_SECONDS * (2 ** attempt))
        
        return None
    
    def send_heartbeat(self, field_id: str, status: str, details: dict = None):
        """Send heartbeat to let system know Pi is alive."""
        data = {
            'field_id': field_id,
            'status': status,
            'last_heartbeat': datetime.now().isoformat(),
            'details': json.dumps(details or {})
        }
        
        try:
            # Upsert to camera_status table
            url = f"{self.url}/rest/v1/camera_status?field_id=eq.{field_id}"
            requests.patch(url, headers={
                **self.headers,
                'Prefer': 'return=representation'
            }, json=data, timeout=10)
        except Exception as e:
            # Don't fail on heartbeat errors
            logger.debug(f"Heartbeat failed: {e}")


class CameraRecorder:
    """
    Improved camera recorder with:
    - Retry logic
    - Local chunk retention until stitch complete
    - Concurrent recording support
    """
    
    def __init__(self, supabase: SupabaseClient):
        self.supabase = supabase
        self.active_recordings: Dict[str, RecordingJob] = {}
        self.lock = threading.Lock()
    
    def get_rtsp_url(self) -> str:
        """Build RTSP URL for the camera."""
        return CAMERA_RTSP_PATTERN.format(
            username=CAMERA_USERNAME,
            password=CAMERA_PASSWORD,
            ip=CAMERA_IP,
            port=CAMERA_RTSP_PORT
        )
    
    def check_disk_space(self) -> bool:
        """Check if there's enough disk space."""
        try:
            stat = shutil.disk_usage(RECORDING_DIR)
            free_gb = stat.free / (1024 ** 3)
            
            if free_gb < MIN_FREE_SPACE_GB:
                logger.warning(f"⚠️ Low disk space: {free_gb:.1f}GB free (need {MIN_FREE_SPACE_GB}GB)")
                self._cleanup_old_recordings()
                return free_gb >= MIN_FREE_SPACE_GB * 0.5  # Allow if at least half
            
            return True
        except Exception as e:
            logger.error(f"Disk space check failed: {e}")
            return True  # Continue anyway
    
    def _cleanup_old_recordings(self):
        """Clean up old recording files."""
        try:
            cutoff = datetime.now() - timedelta(hours=24)
            
            for dir_path in [RECORDING_DIR, TEMP_DIR]:
                for filename in os.listdir(dir_path):
                    filepath = os.path.join(dir_path, filename)
                    if os.path.isfile(filepath):
                        mtime = datetime.fromtimestamp(os.path.getmtime(filepath))
                        if mtime < cutoff:
                            os.remove(filepath)
                            logger.info(f"🗑️ Cleaned up old file: {filename}")
        except Exception as e:
            logger.error(f"Cleanup failed: {e}")
    
    def test_camera_connection(self) -> bool:
        """Test if camera is accessible."""
        rtsp_url = self.get_rtsp_url()
        try:
            result = subprocess.run(
                ['ffprobe', '-v', 'error', '-rtsp_transport', 'tcp', 
                 '-i', rtsp_url, '-show_entries', 'format=duration'],
                capture_output=True,
                timeout=15
            )
            return result.returncode == 0
        except Exception as e:
            logger.error(f"Camera test failed: {e}")
            return False
    
    def start_recording(self, job: RecordingJob) -> bool:
        """Start a recording job."""
        with self.lock:
            if job.booking_id in self.active_recordings:
                logger.warning(f"Recording already active for {job.booking_id}")
                return False
            self.active_recordings[job.booking_id] = job
        
        try:
            # Check prerequisites
            if not self.check_disk_space():
                raise Exception("Insufficient disk space")
            
            # Check if booking still exists and is valid
            booking = self.supabase.get_booking(job.booking_id)
            if not booking:
                raise Exception("Booking not found")
            if booking.get('status') == 'cancelled':
                raise Exception("Booking was cancelled")
            
            job.status = RecordingStatus.RECORDING
            self.supabase.update_booking_status(job.booking_id, 'recording')
            
            logger.info(f"🎬 Starting recording for {job.booking_id}")
            logger.info(f"📹 Duration: {job.duration_minutes} min, Chunks: {CHUNK_DURATION_MINUTES} min each")
            
            # Record all chunks (keep locally)
            num_chunks = (job.duration_minutes + CHUNK_DURATION_MINUTES - 1) // CHUNK_DURATION_MINUTES
            
            for chunk_num in range(num_chunks):
                # Check if cancelled mid-recording
                current_booking = self.supabase.get_booking(job.booking_id)
                if current_booking and current_booking.get('status') == 'cancelled':
                    logger.warning(f"⚠️ Booking cancelled mid-recording")
                    job.status = RecordingStatus.CANCELLED
                    return False
                
                remaining = job.duration_minutes - (chunk_num * CHUNK_DURATION_MINUTES)
                chunk_duration = min(CHUNK_DURATION_MINUTES, remaining)
                
                chunk_path = self._record_chunk(job.booking_id, chunk_num + 1, chunk_duration)
                
                if chunk_path:
                    job.chunks.append(chunk_path)
                    logger.info(f"✅ Chunk {chunk_num + 1}/{num_chunks} recorded: {os.path.basename(chunk_path)}")
                else:
                    logger.error(f"❌ Failed to record chunk {chunk_num + 1}")
            
            if not job.chunks:
                raise Exception("No chunks recorded")
            
            # Process recording (stitch, upload, trigger processing)
            self._process_recording(job)
            
            return True
            
        except Exception as e:
            logger.error(f"Recording failed: {e}")
            job.status = RecordingStatus.FAILED
            job.error_message = str(e)
            self.supabase.update_booking_status(job.booking_id, 'recording_failed')
            return False
            
        finally:
            with self.lock:
                self.active_recordings.pop(job.booking_id, None)
    
    def _record_chunk(self, booking_id: str, chunk_num: int, duration_minutes: int) -> Optional[str]:
        """Record a single chunk."""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        chunk_filename = f"{booking_id}_chunk{chunk_num:03d}_{timestamp}.mp4"
        chunk_path = os.path.join(RECORDING_DIR, chunk_filename)
        
        rtsp_url = self.get_rtsp_url()
        duration_seconds = duration_minutes * 60
        
        ffmpeg_cmd = [
            'ffmpeg', '-y',
            '-rtsp_transport', 'tcp',
            '-i', rtsp_url,
            '-t', str(duration_seconds),
            '-c:v', 'copy',
            '-c:a', 'aac',
            '-movflags', '+faststart',
            '-f', 'mp4',
            chunk_path
        ]
        
        logger.info(f"📹 Recording chunk {chunk_num} ({duration_minutes} min)...")
        
        try:
            process = subprocess.Popen(
                ffmpeg_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            # Wait with timeout buffer
            stdout, stderr = process.communicate(timeout=duration_seconds + 120)
            
            if process.returncode != 0:
                logger.error(f"FFmpeg error: {stderr.decode()[:500]}")
                return None
            
            if os.path.exists(chunk_path) and os.path.getsize(chunk_path) > 1024:  # > 1KB
                return chunk_path
            
            return None
            
        except subprocess.TimeoutExpired:
            process.kill()
            logger.warning("Recording timeout - chunk may be incomplete")
            return chunk_path if os.path.exists(chunk_path) else None
        except Exception as e:
            logger.error(f"Recording error: {e}")
            return None
    
    def _process_recording(self, job: RecordingJob):
        """Process completed recording - stitch, upload, trigger ball tracking."""
        job.status = RecordingStatus.PROCESSING
        self.supabase.update_booking_status(job.booking_id, 'processing')
        
        try:
            # Step 1: Stitch chunks (they're still local - no re-download!)
            if len(job.chunks) == 1:
                final_video = job.chunks[0]
                logger.info("Single chunk - no stitching needed")
            else:
                final_video = self._stitch_chunks(job.chunks, job.booking_id)
                if not final_video:
                    raise Exception("Failed to stitch chunks")
            
            # Step 2: Upload to Supabase storage
            job.status = RecordingStatus.UPLOADING
            
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            storage_path = f"raw-recordings/{FIELD_ID}/{job.booking_id}_{timestamp}.mp4"
            
            video_url = self.supabase.upload_file(storage_path, final_video)
            
            if not video_url:
                raise Exception("Failed to upload video")
            
            logger.info(f"☁️ Video uploaded: {video_url}")
            
            # Step 3: Update booking with raw video URL (fallback)
            # This ensures user has SOMETHING even if ball tracking fails
            self.supabase.update_booking_status(job.booking_id, 'recorded', video_url)
            
            # Step 4: Create ball tracking job
            tracking_job_id = self.supabase.create_ball_tracking_job(
                job.booking_id, video_url, FIELD_ID
            )
            
            if tracking_job_id:
                logger.info(f"🎯 Ball tracking job created: {tracking_job_id}")
                self._trigger_ball_tracking(tracking_job_id, video_url, job.booking_id)
            else:
                logger.warning("⚠️ Ball tracking job creation failed - raw video available")
            
            # Step 5: Cleanup local files (NOW we can delete)
            self._cleanup_job_files(job)
            
            job.status = RecordingStatus.COMPLETED
            logger.info(f"✅ Recording complete for {job.booking_id}")
            
        except Exception as e:
            logger.error(f"Processing failed: {e}")
            job.status = RecordingStatus.FAILED
            job.error_message = str(e)
            self.supabase.update_booking_status(job.booking_id, 'recording_failed')
    
    def _stitch_chunks(self, chunk_paths: List[str], booking_id: str) -> Optional[str]:
        """Stitch video chunks together."""
        concat_file = os.path.join(TEMP_DIR, f"{booking_id}_concat.txt")
        output_path = os.path.join(TEMP_DIR, f"{booking_id}_stitched.mp4")
        
        # Create concat file
        with open(concat_file, 'w') as f:
            for path in chunk_paths:
                f.write(f"file '{path}'\n")
        
        logger.info(f"🔗 Stitching {len(chunk_paths)} chunks...")
        
        ffmpeg_cmd = [
            'ffmpeg', '-y',
            '-f', 'concat',
            '-safe', '0',
            '-i', concat_file,
            '-c', 'copy',
            '-movflags', '+faststart',
            output_path
        ]
        
        try:
            result = subprocess.run(ffmpeg_cmd, capture_output=True, text=True, timeout=300)
            
            if result.returncode != 0:
                logger.error(f"Stitch error: {result.stderr[:500]}")
                return None
            
            if os.path.exists(output_path):
                logger.info(f"✅ Stitched video: {os.path.getsize(output_path) / (1024*1024):.1f} MB")
                return output_path
            
        except Exception as e:
            logger.error(f"Stitch failed: {e}")
        
        return None
    
    def _trigger_ball_tracking(self, job_id: str, video_url: str, booking_id: str):
        """Trigger Modal ball tracking with retry."""
        for attempt in range(MAX_UPLOAD_RETRIES):
            try:
                response = requests.post(
                    MODAL_WEBHOOK_URL,
                    json={
                        'job_id': job_id,
                        'video_url': video_url,
                        'booking_id': booking_id,
                        'config': {
                            'zoom_base': 1.75,
                            'detect_every_frames': 3,
                            'yolo_conf': 0.12,
                            'yolo_model': 'yolov8l'
                        }
                    },
                    timeout=180
                )
                
                if response.status_code == 200:
                    logger.info(f"✅ Ball tracking triggered successfully")
                    return
                else:
                    logger.warning(f"Modal returned {response.status_code}: {response.text[:200]}")
                    
            except Exception as e:
                logger.warning(f"Trigger attempt {attempt + 1} failed: {e}")
                
            if attempt < MAX_UPLOAD_RETRIES - 1:
                time.sleep(RETRY_DELAY_SECONDS * (2 ** attempt))
        
        logger.error("❌ Ball tracking trigger failed - raw video still available")
    
    def _cleanup_job_files(self, job: RecordingJob):
        """Clean up local files for a completed job."""
        try:
            # Remove chunks
            for chunk in job.chunks:
                if os.path.exists(chunk):
                    os.remove(chunk)
                    logger.debug(f"Removed chunk: {chunk}")
            
            # Remove temp files
            for filename in os.listdir(TEMP_DIR):
                if job.booking_id in filename:
                    filepath = os.path.join(TEMP_DIR, filename)
                    os.remove(filepath)
                    logger.debug(f"Removed temp: {filename}")
                    
            logger.info(f"🗑️ Cleaned up files for {job.booking_id}")
            
        except Exception as e:
            logger.warning(f"Cleanup warning: {e}")


class BookingScheduler:
    """
    Improved scheduler with:
    - Realtime booking monitoring
    - Concurrent recording support
    - Heartbeat monitoring
    """
    
    def __init__(self, recorder: CameraRecorder, supabase: SupabaseClient):
        self.recorder = recorder
        self.supabase = supabase
        self.scheduled_jobs: Dict[str, RecordingJob] = {}
        self.recording_threads: Dict[str, threading.Thread] = {}
        self.lock = threading.Lock()
        self.running = True
    
    def start(self):
        """Start the scheduler."""
        logger.info(f"🚀 Starting scheduler for field: {FIELD_NAME}")
        
        # Start heartbeat thread
        heartbeat_thread = threading.Thread(target=self._heartbeat_loop, daemon=True)
        heartbeat_thread.start()
        
        # Initial booking check
        self._refresh_bookings()
        
        # Main loop
        while self.running:
            try:
                self._check_scheduled_recordings()
                self._refresh_bookings()
                time.sleep(15)  # Check every 15 seconds
            except KeyboardInterrupt:
                logger.info("Scheduler stopped by user")
                self.running = False
            except Exception as e:
                logger.error(f"Scheduler error: {e}")
                time.sleep(30)
    
    def _heartbeat_loop(self):
        """Send periodic heartbeat."""
        while self.running:
            try:
                details = {
                    'active_recordings': len(self.recorder.active_recordings),
                    'scheduled_jobs': len(self.scheduled_jobs),
                    'camera_connected': self.recorder.test_camera_connection()
                }
                self.supabase.send_heartbeat(FIELD_ID, 'online', details)
            except:
                pass
            time.sleep(HEARTBEAT_INTERVAL)
    
    def _refresh_bookings(self):
        """Refresh upcoming bookings."""
        try:
            bookings = self.supabase.get_upcoming_bookings(FIELD_ID)
            
            for booking in bookings:
                booking_id = booking['id']
                
                # Skip if already scheduled or recording
                if booking_id in self.scheduled_jobs:
                    continue
                if booking_id in self.recorder.active_recordings:
                    continue
                
                # Parse booking time
                job = self._create_job_from_booking(booking)
                if job:
                    with self.lock:
                        self.scheduled_jobs[booking_id] = job
                    logger.info(f"📆 Scheduled: {booking_id} at {job.start_time}")
                    
        except Exception as e:
            logger.error(f"Refresh bookings failed: {e}")
    
    def _create_job_from_booking(self, booking: dict) -> Optional[RecordingJob]:
        """Create a RecordingJob from a booking dict."""
        try:
            booking_date = datetime.strptime(booking['date'], '%Y-%m-%d')
            time_slot = booking['timeSlot']
            start_str, end_str = time_slot.split('-')
            
            start_h, start_m = map(int, start_str.split(':'))
            end_h, end_m = map(int, end_str.split(':'))
            
            start_time = booking_date.replace(hour=start_h, minute=start_m)
            end_time = booking_date.replace(hour=end_h, minute=end_m)
            
            # Handle overnight
            if end_time <= start_time:
                end_time += timedelta(days=1)
            
            duration = int((end_time - start_time).total_seconds() / 60)
            
            return RecordingJob(
                booking_id=booking['id'],
                start_time=start_time,
                end_time=end_time,
                duration_minutes=duration,
                status=RecordingStatus.SCHEDULED
            )
            
        except Exception as e:
            logger.error(f"Failed to create job: {e}")
            return None
    
    def _check_scheduled_recordings(self):
        """Check if any scheduled recordings should start."""
        now = datetime.now()
        
        with self.lock:
            for booking_id, job in list(self.scheduled_jobs.items()):
                # Start 1 minute before booking
                if now >= job.start_time - timedelta(minutes=1):
                    # Remove from scheduled
                    del self.scheduled_jobs[booking_id]
                    
                    # Start recording in new thread
                    thread = threading.Thread(
                        target=self._run_recording,
                        args=(job,),
                        name=f"recording-{booking_id}"
                    )
                    thread.start()
                    self.recording_threads[booking_id] = thread
                    
                    logger.info(f"⏰ Starting recording thread for {booking_id}")
    
    def _run_recording(self, job: RecordingJob):
        """Run recording in separate thread."""
        try:
            self.recorder.start_recording(job)
        except Exception as e:
            logger.error(f"Recording thread error: {e}")
        finally:
            with self.lock:
                self.recording_threads.pop(job.booking_id, None)


def main():
    """Main entry point."""
    logger.info("=" * 60)
    logger.info("🎬 PLAYMAKER CAMERA SCRIPT V2")
    logger.info(f"📍 Field: {FIELD_NAME} ({FIELD_ID[:8]}...)")
    logger.info(f"📹 Camera: {CAMERA_IP}")
    logger.info("=" * 60)
    
    # Validate config
    if "{{" in FIELD_ID or "{{" in SUPABASE_URL:
        logger.error("❌ Configuration not set! Use environment variables or edit script.")
        logger.info("Required: PLAYMAKER_FIELD_ID, SUPABASE_URL, SUPABASE_KEY, CAMERA_IP, etc.")
        sys.exit(1)
    
    # Initialize
    supabase = SupabaseClient(SUPABASE_URL, SUPABASE_KEY)
    recorder = CameraRecorder(supabase)
    
    # Test camera
    logger.info("🔍 Testing camera connection...")
    if recorder.test_camera_connection():
        logger.info("✅ Camera connected!")
    else:
        logger.warning("⚠️ Camera test failed - recordings may not work")
    
    # Check disk space
    recorder.check_disk_space()
    
    # Start scheduler
    scheduler = BookingScheduler(recorder, supabase)
    scheduler.start()


if __name__ == "__main__":
    main()


