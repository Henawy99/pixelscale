#!/usr/bin/env python3
"""
==========================================
PLAYMAKER FIELD CAMERA RECORDING SCRIPT
==========================================

This script runs on a Raspberry Pi at a football field.
It monitors Supabase for bookings and automatically:
1. Starts recording when a booking begins
2. Records in 20-minute chunks
3. Uploads chunks to Supabase storage
4. Stitches chunks together
5. Triggers Modal ball tracking pipeline
6. Updates booking with processed video URL

SETUP:
1. Copy this script to your Raspberry Pi
2. Fill in the FIELD CONFIGURATION section below
3. Install dependencies: pip3 install supabase python-dateutil requests
4. Run: python3 field_camera_script.py

==========================================
"""

import os
import sys
import time
import json
import subprocess
import threading
import logging
from datetime import datetime, timedelta
from pathlib import Path
import requests
import hashlib

# ==========================================
# FIELD CONFIGURATION - FILL THESE IN!
# ==========================================
FIELD_ID = "{{FIELD_ID}}"
FIELD_NAME = "{{FIELD_NAME}}"

# Supabase Configuration
SUPABASE_URL = "{{SUPABASE_URL}}"
SUPABASE_KEY = "{{SUPABASE_KEY}}"

# Camera Configuration
CAMERA_IP = "{{CAMERA_IP}}"
CAMERA_USERNAME = "{{CAMERA_USERNAME}}"
CAMERA_PASSWORD = "{{CAMERA_PASSWORD}}"
CAMERA_RTSP_PORT = "{{CAMERA_RTSP_PORT}}"  # Usually 554

# Recording Configuration
CHUNK_DURATION_MINUTES = 20
RECORDING_DIR = "/home/pi/recordings"
TEMP_DIR = "/home/pi/temp"

# Modal Configuration
MODAL_WEBHOOK_URL = "https://youssefelhenawy0--playmaker-ball-tracking-trigger-job.modal.run"

# ==========================================
# END CONFIGURATION
# ==========================================

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'/home/pi/logs/camera_{FIELD_ID}.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Ensure directories exist
Path(RECORDING_DIR).mkdir(parents=True, exist_ok=True)
Path(TEMP_DIR).mkdir(parents=True, exist_ok=True)
Path('/home/pi/logs').mkdir(parents=True, exist_ok=True)

# Initialize Supabase client
try:
    from supabase import create_client, Client
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    logger.info(f"✅ Supabase client initialized for field: {FIELD_NAME}")
except Exception as e:
    logger.error(f"❌ Failed to initialize Supabase: {e}")
    sys.exit(1)


class CameraRecorder:
    """
    Handles camera recording via RTSP stream using FFmpeg.
    Records in chunks to prevent memory issues and enable partial uploads.
    """
    
    def __init__(self):
        self.is_recording = False
        self.current_process = None
        self.chunks = []
        self.current_booking_id = None
        
    def get_rtsp_url(self):
        """Build RTSP URL for the camera."""
        # Common RTSP URL patterns - adjust based on your camera model
        # Hikvision: rtsp://user:pass@ip:554/Streaming/Channels/101
        # Dahua: rtsp://user:pass@ip:554/cam/realmonitor?channel=1&subtype=0
        # Generic: rtsp://user:pass@ip:554/stream1
        
        return f"rtsp://{CAMERA_USERNAME}:{CAMERA_PASSWORD}@{CAMERA_IP}:{CAMERA_RTSP_PORT}/Streaming/Channels/101"
    
    def start_recording(self, booking_id: str, duration_minutes: int):
        """
        Start recording the camera stream in chunks.
        
        Args:
            booking_id: The booking ID to associate with this recording
            duration_minutes: Total duration to record in minutes
        """
        if self.is_recording:
            logger.warning("Already recording, skipping start request")
            return
        
        self.is_recording = True
        self.current_booking_id = booking_id
        self.chunks = []
        
        logger.info(f"🎬 Starting recording for booking {booking_id}")
        logger.info(f"📹 Duration: {duration_minutes} minutes, Chunk size: {CHUNK_DURATION_MINUTES} minutes")
        
        # Calculate number of chunks needed
        num_chunks = (duration_minutes + CHUNK_DURATION_MINUTES - 1) // CHUNK_DURATION_MINUTES
        
        # Update booking status to recording
        self._update_booking_status(booking_id, 'recording')
        
        # Record each chunk
        for chunk_num in range(num_chunks):
            if not self.is_recording:
                logger.warning("Recording stopped early")
                break
            
            # Calculate chunk duration (last chunk might be shorter)
            remaining_minutes = duration_minutes - (chunk_num * CHUNK_DURATION_MINUTES)
            chunk_duration = min(CHUNK_DURATION_MINUTES, remaining_minutes)
            
            chunk_path = self._record_chunk(booking_id, chunk_num + 1, chunk_duration)
            
            if chunk_path:
                self.chunks.append(chunk_path)
                logger.info(f"✅ Chunk {chunk_num + 1}/{num_chunks} recorded: {chunk_path}")
                
                # Upload chunk immediately to free disk space
                self._upload_chunk(chunk_path, booking_id, chunk_num + 1)
            else:
                logger.error(f"❌ Failed to record chunk {chunk_num + 1}")
        
        self.is_recording = False
        
        # Process completed recording
        if self.chunks:
            self._process_recording(booking_id)
        else:
            logger.error("No chunks recorded!")
            self._update_booking_status(booking_id, 'recording_failed')
    
    def _record_chunk(self, booking_id: str, chunk_num: int, duration_minutes: int) -> str:
        """
        Record a single chunk using FFmpeg.
        
        Returns the path to the recorded chunk file.
        """
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        chunk_filename = f"{booking_id}_chunk{chunk_num:03d}_{timestamp}.mp4"
        chunk_path = os.path.join(RECORDING_DIR, chunk_filename)
        
        rtsp_url = self.get_rtsp_url()
        duration_seconds = duration_minutes * 60
        
        # FFmpeg command for RTSP recording
        # -rtsp_transport tcp: Use TCP for more reliable streaming
        # -c:v copy: Copy video codec (no re-encoding for speed)
        # -c:a aac: Encode audio to AAC
        # -movflags +faststart: Enable fast start for web playback
        ffmpeg_cmd = [
            'ffmpeg',
            '-y',  # Overwrite output
            '-rtsp_transport', 'tcp',
            '-i', rtsp_url,
            '-t', str(duration_seconds),
            '-c:v', 'copy',  # Copy video stream without re-encoding
            '-c:a', 'aac',   # Encode audio to AAC
            '-movflags', '+faststart',
            '-f', 'mp4',
            chunk_path
        ]
        
        logger.info(f"📹 Recording chunk {chunk_num} for {duration_minutes} minutes...")
        logger.debug(f"FFmpeg command: {' '.join(ffmpeg_cmd)}")
        
        try:
            self.current_process = subprocess.Popen(
                ffmpeg_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            # Wait for recording to complete
            stdout, stderr = self.current_process.communicate(timeout=duration_seconds + 60)
            
            if self.current_process.returncode != 0:
                logger.error(f"FFmpeg error: {stderr.decode()}")
                return None
            
            if os.path.exists(chunk_path) and os.path.getsize(chunk_path) > 0:
                return chunk_path
            else:
                logger.error("Chunk file not created or empty")
                return None
                
        except subprocess.TimeoutExpired:
            logger.warning("Recording timeout - killing FFmpeg")
            self.current_process.kill()
            return chunk_path if os.path.exists(chunk_path) else None
        except Exception as e:
            logger.error(f"Recording error: {e}")
            return None
        finally:
            self.current_process = None
    
    def _upload_chunk(self, chunk_path: str, booking_id: str, chunk_num: int):
        """Upload a chunk to Supabase storage."""
        try:
            filename = os.path.basename(chunk_path)
            storage_path = f"recording-chunks/{FIELD_ID}/{booking_id}/{filename}"
            
            with open(chunk_path, 'rb') as f:
                supabase.storage.from_('videos').upload(
                    storage_path,
                    f,
                    file_options={"content-type": "video/mp4"}
                )
            
            logger.info(f"☁️ Uploaded chunk {chunk_num}: {storage_path}")
            
            # Delete local chunk to save space
            os.remove(chunk_path)
            logger.info(f"🗑️ Deleted local chunk: {chunk_path}")
            
        except Exception as e:
            logger.error(f"Failed to upload chunk: {e}")
    
    def _process_recording(self, booking_id: str):
        """
        Process the complete recording:
        1. Stitch chunks together
        2. Upload final video
        3. Trigger ball tracking
        """
        logger.info(f"🔄 Processing recording for booking {booking_id}")
        
        try:
            # Update status
            self._update_booking_status(booking_id, 'processing')
            
            # Get all chunks from storage
            chunk_urls = self._get_chunk_urls(booking_id)
            
            if not chunk_urls:
                logger.error("No chunks found in storage!")
                self._update_booking_status(booking_id, 'recording_failed')
                return
            
            # Download chunks for stitching
            local_chunks = self._download_chunks(chunk_urls, booking_id)
            
            if len(local_chunks) == 1:
                # Single chunk - no stitching needed
                final_video = local_chunks[0]
            else:
                # Stitch chunks together
                final_video = self._stitch_chunks(local_chunks, booking_id)
            
            if not final_video:
                logger.error("Failed to create final video")
                self._update_booking_status(booking_id, 'recording_failed')
                return
            
            # Upload final video
            video_url = self._upload_final_video(final_video, booking_id)
            
            if not video_url:
                logger.error("Failed to upload final video")
                self._update_booking_status(booking_id, 'recording_failed')
                return
            
            # Create ball tracking job and trigger Modal
            job_id = self._create_ball_tracking_job(booking_id, video_url)
            
            if job_id:
                logger.info(f"🚀 Ball tracking job created: {job_id}")
                self._trigger_ball_tracking(job_id, video_url)
            else:
                # Still update with raw video if ball tracking fails
                self._update_booking_with_video(booking_id, video_url)
            
            # Cleanup
            self._cleanup_local_files(booking_id)
            
            logger.info(f"✅ Recording processing complete for {booking_id}")
            
        except Exception as e:
            logger.error(f"Processing error: {e}")
            self._update_booking_status(booking_id, 'recording_failed')
    
    def _get_chunk_urls(self, booking_id: str) -> list:
        """Get URLs for all uploaded chunks."""
        try:
            storage_path = f"recording-chunks/{FIELD_ID}/{booking_id}"
            files = supabase.storage.from_('videos').list(storage_path)
            
            urls = []
            for file in sorted(files, key=lambda x: x['name']):
                url = supabase.storage.from_('videos').get_public_url(
                    f"{storage_path}/{file['name']}"
                )
                urls.append(url)
            
            return urls
        except Exception as e:
            logger.error(f"Failed to get chunk URLs: {e}")
            return []
    
    def _download_chunks(self, chunk_urls: list, booking_id: str) -> list:
        """Download chunks from storage for processing."""
        local_paths = []
        
        for i, url in enumerate(chunk_urls):
            local_path = os.path.join(TEMP_DIR, f"{booking_id}_chunk{i:03d}.mp4")
            
            try:
                response = requests.get(url, stream=True)
                response.raise_for_status()
                
                with open(local_path, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        f.write(chunk)
                
                local_paths.append(local_path)
                logger.info(f"📥 Downloaded chunk {i + 1}/{len(chunk_urls)}")
                
            except Exception as e:
                logger.error(f"Failed to download chunk: {e}")
        
        return local_paths
    
    def _stitch_chunks(self, chunk_paths: list, booking_id: str) -> str:
        """Stitch video chunks together using FFmpeg."""
        
        # Create concat file
        concat_file = os.path.join(TEMP_DIR, f"{booking_id}_concat.txt")
        with open(concat_file, 'w') as f:
            for path in chunk_paths:
                f.write(f"file '{path}'\n")
        
        output_path = os.path.join(TEMP_DIR, f"{booking_id}_full.mp4")
        
        # FFmpeg concat command
        ffmpeg_cmd = [
            'ffmpeg',
            '-y',
            '-f', 'concat',
            '-safe', '0',
            '-i', concat_file,
            '-c', 'copy',  # No re-encoding
            '-movflags', '+faststart',
            output_path
        ]
        
        logger.info(f"🔗 Stitching {len(chunk_paths)} chunks...")
        
        try:
            result = subprocess.run(ffmpeg_cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                logger.error(f"FFmpeg stitch error: {result.stderr}")
                return None
            
            if os.path.exists(output_path):
                logger.info(f"✅ Stitched video created: {output_path}")
                return output_path
            
        except Exception as e:
            logger.error(f"Stitch error: {e}")
        
        return None
    
    def _upload_final_video(self, video_path: str, booking_id: str) -> str:
        """Upload the final stitched video to Supabase."""
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"{FIELD_ID}_{booking_id}_{timestamp}_raw.mp4"
            storage_path = f"raw-recordings/{FIELD_ID}/{filename}"
            
            with open(video_path, 'rb') as f:
                supabase.storage.from_('videos').upload(
                    storage_path,
                    f,
                    file_options={"content-type": "video/mp4"}
                )
            
            url = supabase.storage.from_('videos').get_public_url(storage_path)
            logger.info(f"☁️ Uploaded final video: {url}")
            return url
            
        except Exception as e:
            logger.error(f"Failed to upload final video: {e}")
            return None
    
    def _create_ball_tracking_job(self, booking_id: str, video_url: str) -> str:
        """Create a ball tracking job in Supabase."""
        try:
            result = supabase.table('ball_tracking_jobs').insert({
                'input_video_url': video_url,
                'video_name': f"field_{FIELD_ID}_booking_{booking_id}",
                'status': 'pending',
                'progress_percent': 0,
                'script_config': {
                    'zoom_base': 1.75,
                    'detect_every_frames': 3,
                    'yolo_conf': 0.12,
                    'yolo_model': 'yolov8l'
                },
                'script_version': '1.0',
                'booking_id': booking_id,
                'field_id': FIELD_ID
            }).execute()
            
            if result.data:
                return result.data[0]['id']
            
        except Exception as e:
            logger.error(f"Failed to create ball tracking job: {e}")
        
        return None
    
    def _trigger_ball_tracking(self, job_id: str, video_url: str):
        """Trigger Modal ball tracking pipeline."""
        try:
            response = requests.post(
                MODAL_WEBHOOK_URL,
                json={
                    'job_id': job_id,
                    'video_url': video_url,
                    'config': {
                        'zoom_base': 1.75,
                        'detect_every_frames': 3,
                        'yolo_conf': 0.12,
                        'yolo_model': 'yolov8l'
                    }
                },
                timeout=180  # 3 minute timeout for Modal cold start
            )
            
            if response.status_code == 200:
                logger.info(f"✅ Ball tracking triggered: {response.json()}")
            else:
                logger.error(f"Modal error: {response.status_code} - {response.text}")
                
        except Exception as e:
            logger.error(f"Failed to trigger ball tracking: {e}")
    
    def _update_booking_status(self, booking_id: str, status: str):
        """Update booking status in Supabase."""
        try:
            supabase.table('bookings').update({
                'status': status
            }).eq('id', booking_id).execute()
            
            logger.info(f"📝 Updated booking {booking_id} status to: {status}")
        except Exception as e:
            logger.error(f"Failed to update booking status: {e}")
    
    def _update_booking_with_video(self, booking_id: str, video_url: str):
        """Update booking with recording URL."""
        try:
            supabase.table('bookings').update({
                'recording_url': video_url,
                'status': 'recorded'
            }).eq('id', booking_id).execute()
            
            logger.info(f"📝 Updated booking {booking_id} with video URL")
        except Exception as e:
            logger.error(f"Failed to update booking with video: {e}")
    
    def _cleanup_local_files(self, booking_id: str):
        """Clean up local temporary files."""
        try:
            for filename in os.listdir(TEMP_DIR):
                if booking_id in filename:
                    filepath = os.path.join(TEMP_DIR, filename)
                    os.remove(filepath)
                    logger.info(f"🗑️ Cleaned up: {filepath}")
        except Exception as e:
            logger.error(f"Cleanup error: {e}")
    
    def stop_recording(self):
        """Stop current recording."""
        self.is_recording = False
        if self.current_process:
            self.current_process.terminate()
            logger.info("⏹️ Recording stopped")


class BookingMonitor:
    """
    Monitors Supabase for bookings at this field and triggers recordings.
    Uses real-time subscriptions when available, falls back to polling.
    """
    
    def __init__(self, recorder: CameraRecorder):
        self.recorder = recorder
        self.active_booking = None
        self.scheduled_recordings = {}
        
    def start(self):
        """Start monitoring for bookings."""
        logger.info(f"👀 Starting booking monitor for field: {FIELD_NAME}")
        
        # Initial check for upcoming bookings
        self._check_upcoming_bookings()
        
        # Start polling loop
        while True:
            try:
                self._check_and_process_bookings()
                time.sleep(30)  # Check every 30 seconds
            except KeyboardInterrupt:
                logger.info("Monitor stopped by user")
                break
            except Exception as e:
                logger.error(f"Monitor error: {e}")
                time.sleep(60)  # Wait longer on error
    
    def _check_upcoming_bookings(self):
        """Check for bookings in the next 24 hours and schedule them."""
        try:
            now = datetime.now()
            today = now.strftime('%Y-%m-%d')
            tomorrow = (now + timedelta(days=1)).strftime('%Y-%m-%d')
            
            # Query bookings for today and tomorrow
            result = supabase.table('bookings').select('*').eq(
                'footballFieldId', FIELD_ID
            ).eq(
                'isRecordingEnabled', True
            ).in_(
                'date', [today, tomorrow]
            ).in_(
                'status', ['confirmed', 'pending']
            ).execute()
            
            if result.data:
                logger.info(f"📅 Found {len(result.data)} upcoming bookings")
                for booking in result.data:
                    self._schedule_booking(booking)
                    
        except Exception as e:
            logger.error(f"Failed to check upcoming bookings: {e}")
    
    def _schedule_booking(self, booking: dict):
        """Schedule a recording for a booking."""
        booking_id = booking['id']
        
        if booking_id in self.scheduled_recordings:
            return  # Already scheduled
        
        try:
            # Parse booking time
            booking_date = datetime.strptime(booking['date'], '%Y-%m-%d')
            time_slot = booking['timeSlot']  # e.g., "18:00-19:00"
            start_time_str, end_time_str = time_slot.split('-')
            
            start_hour, start_min = map(int, start_time_str.split(':'))
            end_hour, end_min = map(int, end_time_str.split(':'))
            
            start_datetime = booking_date.replace(hour=start_hour, minute=start_min)
            end_datetime = booking_date.replace(hour=end_hour, minute=end_min)
            
            # Handle overnight bookings
            if end_datetime <= start_datetime:
                end_datetime += timedelta(days=1)
            
            duration_minutes = int((end_datetime - start_datetime).total_seconds() / 60)
            
            logger.info(f"📆 Scheduled: {booking['footballFieldName']} on {booking['date']} {time_slot}")
            
            self.scheduled_recordings[booking_id] = {
                'start_time': start_datetime,
                'duration_minutes': duration_minutes,
                'booking': booking
            }
            
        except Exception as e:
            logger.error(f"Failed to schedule booking {booking_id}: {e}")
    
    def _check_and_process_bookings(self):
        """Check if any scheduled recordings should start."""
        now = datetime.now()
        
        for booking_id, scheduled in list(self.scheduled_recordings.items()):
            start_time = scheduled['start_time']
            
            # Start recording 1 minute before booking time
            if now >= start_time - timedelta(minutes=1):
                if self.active_booking is None:
                    logger.info(f"⏰ Starting scheduled recording: {booking_id}")
                    
                    self.active_booking = booking_id
                    
                    # Start recording in a separate thread
                    thread = threading.Thread(
                        target=self._run_recording,
                        args=(booking_id, scheduled['duration_minutes'])
                    )
                    thread.start()
                    
                    # Remove from scheduled
                    del self.scheduled_recordings[booking_id]
    
    def _run_recording(self, booking_id: str, duration_minutes: int):
        """Run recording in a separate thread."""
        try:
            self.recorder.start_recording(booking_id, duration_minutes)
        except Exception as e:
            logger.error(f"Recording thread error: {e}")
        finally:
            self.active_booking = None


def main():
    """Main entry point."""
    logger.info("=" * 60)
    logger.info("🎬 PLAYMAKER FIELD CAMERA SCRIPT")
    logger.info(f"📍 Field: {FIELD_NAME} ({FIELD_ID})")
    logger.info(f"📹 Camera: {CAMERA_IP}")
    logger.info("=" * 60)
    
    # Validate configuration
    if "{{" in FIELD_ID or "{{" in SUPABASE_URL:
        logger.error("❌ Configuration not set! Please fill in the configuration section.")
        sys.exit(1)
    
    # Test camera connection
    logger.info("🔍 Testing camera connection...")
    recorder = CameraRecorder()
    rtsp_url = recorder.get_rtsp_url()
    
    # Quick ffprobe test
    try:
        result = subprocess.run(
            ['ffprobe', '-v', 'error', '-rtsp_transport', 'tcp', '-i', rtsp_url],
            capture_output=True,
            timeout=10
        )
        if result.returncode == 0:
            logger.info("✅ Camera connection successful!")
        else:
            logger.warning("⚠️ Camera connection test failed - recording may not work")
    except Exception as e:
        logger.warning(f"⚠️ Could not test camera connection: {e}")
    
    # Start monitoring
    monitor = BookingMonitor(recorder)
    monitor.start()


if __name__ == "__main__":
    main()


