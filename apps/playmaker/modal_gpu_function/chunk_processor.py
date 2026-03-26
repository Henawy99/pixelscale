"""
Modal GPU Chunk Processor for Playmaker v2.2 - WATERMARK FIX
- FULL BROADCAST PROCESSING:
  - Smooth camera following the ball
  - Playmaker watermark from Supabase
  - Field mask for accurate detection
  - Kalman filter smoothing
  - Audio preservation
  
OPTIMIZATIONS:
- Model loaded once per container (not per invocation)
- Reduced detection resolution (640px vs 1280px) - still accurate for ball
- Increased frame skip (every 3rd frame with Kalman compensation)
- Container warmup to reduce cold starts
- Full cost tracking (GPU + CPU functions)

WATERMARK DEBUG v2.2: Added detailed logging for watermark download
"""

import modal
import os
import tempfile
import subprocess
import urllib.request
from pathlib import Path

# Modal app configuration
app = modal.App("playmakerstart")

# Image with dependencies + V3 broadcast script (used when ball tracking is enabled)
_image_dir = Path(__file__).parent
image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install(
        "opencv-python-headless",
        "numpy",
        "requests",
        "ultralytics",
        "fastapi",
        "roboflow",
    )
    .apt_install("ffmpeg")
    .add_local_file(_image_dir / "BROADCAST_BALL_TRACKING_V4_SCRIPT.py", "/root/BROADCAST_BALL_TRACKING_V4_SCRIPT.py")
)

# Secrets
supabase_secret = modal.Secret.from_name("supabase-credentials")
bunny_secret = modal.Secret.from_name("bunny-credentials")
# roboflow_secret = modal.Secret.from_name("roboflow-secret") # Removed mandatory secret to allow deployment without it

# Configuration
BUNNY_STORAGE_ZONE = "playmaker-raw"
BUNNY_CDN_URL = "https://playmaker-raw.b-cdn.net"
SUPABASE_URL = "https://upooyypqhftzzwjrfyra.supabase.co"
SUPABASE_STORAGE_URL = "https://upooyypqhftzzwjrfyra.supabase.co/storage/v1/object/public/videos"
LOGO_URL = f"{SUPABASE_STORAGE_URL}/assets/watermark.png"

# Cost rates (Modal pricing)
T4_GPU_RATE = 0.000164  # ~$0.59/hour for T4 (Modal's actual rate)
CPU_RATE = 0.000012     # ~$0.043/hour for CPU-only


def update_chunk_status(chunk_id: str, data: dict, supabase_key: str):
    """Update chunk status in Supabase"""
    import requests
    if not chunk_id:
        return
    
    update_data = {}
    status_value = data.get('status') or data.get('gpu_status')
    if status_value:
        update_data['status'] = status_value
        gpu_status_map = {'gpu_processing': 'processing', 'completed': 'completed', 'gpu_failed': 'failed'}
        update_data['gpu_status'] = gpu_status_map.get(status_value, status_value)
    if 'gpu_progress' in data:
        update_data['gpu_progress'] = data['gpu_progress']
    if 'processed_url' in data:
        update_data['processed_url'] = data['processed_url']
    if 'thumbnail_url' in data:
        update_data['thumbnail_url'] = data['thumbnail_url']
    if 'processing_time_seconds' in data:
        update_data['processing_time_seconds'] = data['processing_time_seconds']
    if 'gpu_cost_usd' in data:
        update_data['gpu_cost_usd'] = data['gpu_cost_usd']
    if 'gpu_started_at' in data:
        update_data['gpu_started_at'] = data['gpu_started_at']
    if 'gpu_finished_at' in data:
        update_data['gpu_finished_at'] = data['gpu_finished_at']
    
    if not update_data:
        return
    
    try:
        headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}", "Content-Type": "application/json", "Prefer": "return=minimal"}
        print(f"📝 DB Update: {update_data}")
        response = requests.patch(f"{SUPABASE_URL}/rest/v1/camera_recording_chunks?id=eq.{chunk_id}", headers=headers, json=update_data, timeout=30)
        if response.status_code in [200, 204]:
            print(f"✅ DB Updated")
        else:
            print(f"❌ DB Update failed: {response.status_code}")
    except Exception as e:
        print(f"❌ DB Error: {e}")


def log_to_supabase(schedule_id: str, field_id: str, message: str, level: str, supabase_key: str):
    """Log message to camera_logs table"""
    import requests
    try:
        headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}", "Content-Type": "application/json", "Prefer": "return=minimal"}
        log_data = {"field_id": field_id, "schedule_id": schedule_id, "level": level, "message": f"[GPU] {message}", "source": "modal_gpu"}
        requests.post(f"{SUPABASE_URL}/rest/v1/camera_logs", headers=headers, json=log_data, timeout=10)
    except:
        pass


def download_video(url: str, output_path: Path, max_retries: int = 3) -> bool:
    """Download video from BunnyCDN with retry logic"""
    import requests
    import time
    
    for attempt in range(max_retries):
        try:
            if attempt > 0:
                wait_time = 10 * attempt  # 10s, 20s, 30s
                print(f"⏳ Retry {attempt + 1}/{max_retries} - waiting {wait_time}s...")
                time.sleep(wait_time)
            
            print(f"📥 Downloading (attempt {attempt + 1}/{max_retries}): {url[:80]}...")
            response = requests.get(url, stream=True, timeout=900)  # 15 min timeout
            response.raise_for_status()
            total_size = int(response.headers.get('content-length', 0))
            downloaded = 0
            last_pct = 0
            
            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=65536):
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_size > 0:
                        pct = int((downloaded / total_size) * 100)
                        if pct >= last_pct + 20:
                            print(f"   Download: {pct}%")
                            last_pct = pct
            
            file_size = output_path.stat().st_size / (1024*1024)
            print(f"✅ Downloaded: {file_size:.1f} MB")
            
            # Verify file size is reasonable (at least 1MB)
            if file_size < 1:
                print(f"⚠️ File too small ({file_size:.1f} MB), retrying...")
                continue
                
            return True
            
        except requests.exceptions.Timeout:
            print(f"❌ Download timeout on attempt {attempt + 1}")
        except requests.exceptions.ConnectionError as e:
            print(f"❌ Connection error on attempt {attempt + 1}: {e}")
        except Exception as e:
            print(f"❌ Download failed on attempt {attempt + 1}: {e}")
    
    print(f"❌ DOWNLOAD FAILED after {max_retries} attempts!")
    return False


def upload_to_bunny(local_path: Path, remote_path: str, api_key: str) -> str:
    """Upload processed video to BunnyCDN"""
    import requests
    url = f"https://storage.bunnycdn.com/{BUNNY_STORAGE_ZONE}/{remote_path}"
    try:
        print(f"📤 Uploading: {remote_path}")
        with open(local_path, 'rb') as f:
            response = requests.put(url, headers={'AccessKey': api_key, 'Content-Type': 'application/octet-stream'}, data=f, timeout=1800)
        if response.status_code in [200, 201]:
            cdn_url = f"{BUNNY_CDN_URL}/{remote_path}"
            print(f"✅ Uploaded: {cdn_url}")
            return cdn_url
        print(f"❌ Upload failed: {response.status_code}")
        return None
    except Exception as e:
        print(f"❌ Upload error: {e}")
        return None


def generate_thumbnail(video_path: Path, output_path: Path, timestamp_pct: float = 0.3) -> bool:
    """Generate a thumbnail from a video at the specified percentage point"""
    import cv2
    try:
        cap = cv2.VideoCapture(str(video_path))
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        target_frame = int(total_frames * timestamp_pct)
        
        cap.set(cv2.CAP_PROP_POS_FRAMES, target_frame)
        ret, frame = cap.read()
        cap.release()
        
        if ret and frame is not None:
            # Resize to reasonable thumbnail size (720p width)
            h, w = frame.shape[:2]
            new_w = 1280
            new_h = int(h * (new_w / w))
            frame = cv2.resize(frame, (new_w, new_h))
            
            # Save as JPEG
            cv2.imwrite(str(output_path), frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
            print(f"🖼️ Thumbnail generated: {output_path.stat().st_size / 1024:.1f} KB")
            return True
        return False
    except Exception as e:
        print(f"❌ Thumbnail generation error: {e}")
        return False


def upload_thumbnail_to_supabase(local_path: Path, remote_path: str, supabase_key: str) -> str:
    """Upload thumbnail to Supabase storage"""
    import requests
    try:
        url = f"{SUPABASE_URL}/storage/v1/object/thumbnails/{remote_path}"
        headers = {
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "image/jpeg"
        }
        
        with open(local_path, 'rb') as f:
            response = requests.post(url, headers=headers, data=f, timeout=60)
        
        if response.status_code in [200, 201]:
            public_url = f"{SUPABASE_URL}/storage/v1/object/public/thumbnails/{remote_path}"
            print(f"✅ Thumbnail uploaded: {public_url}")
            return public_url
        else:
            print(f"⚠️ Thumbnail upload failed: {response.status_code} - {response.text[:200]}")
            return None
    except Exception as e:
        print(f"❌ Thumbnail upload error: {e}")
        return None


def get_field_id_from_schedule(schedule_id: str, supabase_key: str) -> str:
    """Get field_id from schedule"""
    import requests
    try:
        headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
        response = requests.get(f"{SUPABASE_URL}/rest/v1/camera_recording_schedules?id=eq.{schedule_id}&select=field_id", headers=headers, timeout=10)
        data = response.json()
        if data:
            return data[0].get('field_id')
    except:
        pass
    return None


def get_schedule_settings(schedule_id: str, supabase_key: str) -> dict:
    """Get schedule settings including show_field_mask"""
    import requests
    try:
        headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
        response = requests.get(
            f"{SUPABASE_URL}/rest/v1/camera_recording_schedules?id=eq.{schedule_id}&select=field_id,enable_ball_tracking,show_field_mask,show_red_ball",
            headers=headers, timeout=10
        )
        data = response.json()
        if data:
            return {
                'field_id': data[0].get('field_id'),
                'enable_ball_tracking': data[0].get('enable_ball_tracking', True),
                'show_field_mask': data[0].get('show_field_mask', False),
                'show_red_ball': data[0].get('show_red_ball', False),
            }
    except Exception as e:
        print(f"⚠️ Error getting schedule settings: {e}")
    return {'field_id': None, 'enable_ball_tracking': True, 'show_field_mask': False, 'show_red_ball': False}


def get_custom_field_mask(field_id: str, supabase_key: str) -> list:
    """Get custom field mask from Supabase if it exists"""
    import requests
    import numpy as np
    
    if not field_id:
        return None
    
    try:
        headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
        response = requests.get(
            f"{SUPABASE_URL}/rest/v1/field_masks?field_id=eq.{field_id}&select=mask_points",
            headers=headers, timeout=10
        )
        data = response.json()
        if data and data[0].get('mask_points'):
            mask_points = data[0]['mask_points']
            # Convert to numpy array format [[x, y], [x, y], ...]
            points = np.array([[p['x'], p['y']] for p in mask_points], dtype=np.float32)
            print(f"✅ Loaded custom field mask with {len(points)} points")
            return points
    except Exception as e:
        print(f"⚠️ Custom field mask not found or error: {e}")
    
    return None


# ═══════════════════════════════════════════════════════════════════════════════
# OPTIMIZED: Use modal.Cls to load model ONCE per container (saves ~30 sec per job)
# ═══════════════════════════════════════════════════════════════════════════════
@app.cls(
    image=image,
    gpu="T4",
    timeout=7200,  # 2 hours for long videos
    secrets=[supabase_secret, bunny_secret],
    scaledown_window=60,  # v4.7: 60s idle (was 300s) — saves ~$0.04/job on idle billing
)
class ChunkProcessor:
    """
    Chunk processor with model loaded once per container.
    This eliminates 20-30 second cold start per chunk!
    """
    
    @modal.enter()
    def load_model(self):
        """Load Roboflow model when container starts"""
        print("🤖 Loading Roboflow model (soccer-ball-tracker-sgt32/4)...")
        from ultralytics import YOLO
        import os
        import tempfile
        from pathlib import Path
        
        model_id = "soccer-ball-tracker-sgt32/4"
        rf_api_key = "TsZ58QXSmc6pkBSsklrJ"
        
        try:
            # Strategy 1: Direct .pt download from Roboflow API
            import urllib.request
            import tempfile as _tmpfile
            weights_file = Path(_tmpfile.gettempdir()) / "rf_soccer_ball.pt"
            direct_url = f"https://api.roboflow.com/{model_id}/yolov8/pt?api_key={rf_api_key}"
            print(f"🔽 Trying direct weights download: {direct_url[:70]}...")
            urllib.request.urlretrieve(direct_url, str(weights_file))
            if weights_file.exists() and weights_file.stat().st_size > 100_000:
                self.default_model = YOLO(str(weights_file))
                self.current_model = self.default_model
                self.current_model_path = model_id
                print(f"✅ Roboflow model {model_id} loaded via direct download ({weights_file.stat().st_size//1024}KB)!")
            else:
                raise Exception(f"Downloaded file too small ({weights_file.stat().st_size if weights_file.exists() else 0} bytes) — likely an error page")
        except Exception as e1:
            print(f"⚠️ Direct download failed: {e1}")
            # Strategy 2: Roboflow SDK
            try:
                from roboflow import Roboflow
                rf = Roboflow(api_key=rf_api_key)
                project_name, version = model_id.split("/")
                project = rf.workspace().project(project_name)
                model_instance = project.version(int(version)).model
                rf_model_dir = Path(tempfile.gettempdir()) / f"rf_model_{model_id.replace('/', '_')}"
                rf_model_dir.mkdir(parents=True, exist_ok=True)
                original_dir = os.getcwd()
                os.chdir(rf_model_dir)
                model_instance.download("yolov8")
                os.chdir(original_dir)
                weights_path = list(rf_model_dir.glob("**/best.pt")) or list(rf_model_dir.glob("**/*.pt"))
                if weights_path:
                    self.default_model = YOLO(str(weights_path[0]))
                    self.current_model = self.default_model
                    self.current_model_path = model_id
                    print(f"✅ Roboflow model {model_id} loaded via SDK!")
                else:
                    raise Exception("No .pt weights found after SDK download")
            except Exception as e2:
                print(f"❌ Roboflow SDK also failed: {e2}")
                # ⚡ Fallback: yolov8n (NANO — 4x faster than yolov8l, acceptable quality at 640px)
                print("⚠️ Falling back to yolov8n.pt (fast nano model)")
                self.default_model = YOLO('yolov8n.pt')
                self.current_model = self.default_model
                self.current_model_path = 'yolov8n'
        
        # Pre-download watermark with detailed logging
        self.logo_img = None
        try:
            import requests
            import cv2
            import tempfile
            
            print(f"🖼️ Downloading watermark from: {LOGO_URL}")
            
            # Use requests instead of urllib for better error handling
            response = requests.get(LOGO_URL, timeout=30)
            print(f"   HTTP Status: {response.status_code}")
            print(f"   Content-Type: {response.headers.get('content-type', 'unknown')}")
            print(f"   Content-Length: {len(response.content)} bytes")
            
            if response.status_code == 200:
                logo_path = Path(tempfile.gettempdir()) / "watermark.png"
                with open(logo_path, 'wb') as f:
                    f.write(response.content)
                print(f"   Saved to: {logo_path}")
                print(f"   File size: {logo_path.stat().st_size} bytes")
                
                self.logo_img = cv2.imread(str(logo_path), cv2.IMREAD_UNCHANGED)
                if self.logo_img is not None:
                    print(f"✅ Watermark pre-loaded: shape={self.logo_img.shape}, dtype={self.logo_img.dtype}")
                else:
                    print(f"❌ cv2.imread returned None - file might not be a valid image")
                    # Try to read first bytes to see what the file contains
                    with open(logo_path, 'rb') as f:
                        first_bytes = f.read(20)
                    print(f"   First bytes: {first_bytes[:20]}")
            else:
                print(f"❌ HTTP error: {response.status_code} - {response.text[:200]}")
        except Exception as e:
            import traceback
            print(f"⚠️ Watermark pre-load failed: {e}")
            traceback.print_exc()
    
    @modal.method()
    def process(self, chunk_id: str, video_url: str, schedule_id: str, chunk_number: int = 0, 
                enable_ball_tracking: bool = True, show_field_mask: bool = False, show_red_ball: bool = False,
                custom_model_url: str = None, roboflow_api_key: str = None):
        import os
        import cv2
        import numpy as np
        import time
        from ultralytics import YOLO
        
        # Track processing time
        start_time = time.time()
        
        supabase_key = os.environ.get("SUPABASE_KEY") or os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        bunny_key = os.environ.get("BUNNY_API_KEY")
        rf_api_key = roboflow_api_key or os.environ.get("ROBOFLOW_API_KEY")

        # ═══════════════════════════════════════════════════════════════
        # MODEL SELECTION
        # ═══════════════════════════════════════════════════════════════
        # We now use the model loaded in @modal.enter() by default.
        # It's a hardcoded Roboflow model "soccer-ball-tracker-sgt32/4".
        active_model = self.default_model
        model_name_log = getattr(self, "current_model_path", "soccer-ball-tracker")
        
        # Get schedule settings (including show_field_mask from database)
        schedule_settings = get_schedule_settings(schedule_id, supabase_key)
        field_id = schedule_settings['field_id']
        # Always prefer True from EITHER the explicit parameter OR the schedule DB setting.
        # (The old `x if x is not None` check silently ignored the DB value because bool
        #  `False` is truthy for `is not None`, so the parameter always won even when the
        #  schedule had show_field_mask=True.)
        show_field_mask = show_field_mask or schedule_settings.get('show_field_mask', False)
        show_red_ball   = show_red_ball   or schedule_settings.get('show_red_ball', False)
        
        def log(msg, level="INFO"):
            print(f"[{level}] {msg}")
            if field_id:
                log_to_supabase(schedule_id, field_id, f"[Chunk {chunk_number}] {msg}", level, supabase_key)
        
        log("🎬 SMOOTH BROADCAST PROCESSOR v2.2 (IMPROVED)")
        if show_field_mask:
            log("📐 Field mask overlay ENABLED")
        log(f"Video: {video_url[:60]}...")
        
        # Record GPU start time
        from datetime import datetime
        gpu_started_at = datetime.utcnow().isoformat()
        
        update_chunk_status(chunk_id, {
            'status': 'gpu_processing',
            'gpu_progress': 5,
            'gpu_started_at': gpu_started_at
        }, supabase_key)
        
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir = Path(tmpdir)
            input_path = tmpdir / "input.mp4"
            temp_video_path = tmpdir / "temp_video.mp4"
            audio_path = tmpdir / "audio.aac"
            output_path = tmpdir / "output.mp4"
            
            # Download video
            log("📥 Downloading video...")
            if not download_video(video_url, input_path):
                log("❌ Download failed!", "ERROR")
                update_chunk_status(chunk_id, {'status': 'gpu_failed'}, supabase_key)
                return {"error": "Download failed"}
            
            update_chunk_status(chunk_id, {'gpu_progress': 15}, supabase_key)
            
            # ═══════════════════════════════════════════════════════════════
            # FIELD MASK - Only detect ball within field boundaries
            # ═══════════════════════════════════════════════════════════════
            # Try to load custom field mask from database
            custom_mask = get_custom_field_mask(field_id, supabase_key)
            
            # Default field mask (fallback)
            DEFAULT_FIELD_MASK = np.array([
                [0.2756, 0.1777], [0.3737, 0.0969], [0.4884, 0.0653], [0.5629, 0.0600],
                [0.6920, 0.1212], [0.7272, 0.1435], [0.7990, 0.3257], [0.8406, 0.4415],
                [0.8785, 0.5593], [0.9202, 0.6517], [0.8502, 0.7684], [0.7673, 0.8662],
                [0.7197, 0.9278], [0.6520, 0.9668], [0.6225, 0.9901], [0.3859, 0.9944],
                [0.3260, 0.9709], [0.2498, 0.8915], [0.2130, 0.8411], [0.1710, 0.8004],
                [0.1366, 0.7317], [0.1066, 0.6896], [0.0943, 0.6766]
            ], dtype=np.float32)
            
            # Use custom mask if available, otherwise use default
            FIELD_MASK_POINTS_NORMALIZED = custom_mask if custom_mask is not None else DEFAULT_FIELD_MASK
            using_custom_mask = custom_mask is not None
            if using_custom_mask:
                log(f"📐 Using CUSTOM field mask ({len(FIELD_MASK_POINTS_NORMALIZED)} points)")
            else:
                log("📐 Using DEFAULT field mask")
            
            field_mask = None
            field_mask_polygon_scaled = None  # For drawing overlay
            
            def create_field_mask(w, h):
                nonlocal field_mask, field_mask_polygon_scaled
                points = FIELD_MASK_POINTS_NORMALIZED.copy()
                points[:, 0] *= w
                points[:, 1] *= h
                field_mask_polygon_scaled = points.astype(np.int32)
                field_mask = np.zeros((h, w), dtype=np.uint8)
                cv2.fillPoly(field_mask, [field_mask_polygon_scaled], 255)
            
            def is_in_field(x, y, w, h):
                if field_mask is None:
                    create_field_mask(w, h)
                x, y = max(0, min(int(x), w-1)), max(0, min(int(y), h-1))
                return field_mask[y, x] > 0
            
            # ── PRE-RENDERED field mask — built once after video dimensions are known ──
            # Per-frame cost: ~0.3MB numpy index vs 24MB frame.copy()+addWeighted (~80x faster)
            _fm_prerendered = {}  # {(w,h): (bool_mask, green_blend_pixels)}

            def _ensure_field_mask_prerendered(w, h):
                key = (w, h)
                if key not in _fm_prerendered:
                    points = FIELD_MASK_POINTS_NORMALIZED.copy()
                    points[:, 0] *= w
                    points[:, 1] *= h
                    polygon_i32 = points.astype(np.int32)
                    # Build bool mask for the polygon interior
                    mask_img = np.zeros((h, w), dtype=np.uint8)
                    cv2.fillPoly(mask_img, [polygon_i32], 255)
                    bool_mask = mask_img > 0          # shape (H,W) bool
                    # Pre-compute the pure green pixels at 15% opacity blend
                    # blend = 0.15*green + 0.85*frame  →  precomputed green part = 0.15*[0,255,0]
                    green_part = np.array([0.0, 255.0 * 0.15, 0.0], dtype=np.float32)  # BGR
                    _fm_prerendered[key] = (bool_mask, green_part, polygon_i32)
                return _fm_prerendered[key]

            def draw_field_mask_overlay_on_original(frame, original_w, original_h):
                """Apply pre-rendered field mask overlay — no frame.copy(), no addWeighted.
                Per-frame cost: numpy fancy-index on polygon pixels only (~80x faster)."""
                if not show_field_mask:
                    return frame
                bool_mask, green_part, polygon_i32 = _ensure_field_mask_prerendered(original_w, original_h)
                # In-place blend: out[mask] = 0.85*in[mask] + green_part
                frame_f = frame[bool_mask].astype(np.float32)
                frame[bool_mask] = np.clip(frame_f * 0.85 + green_part, 0, 255).astype(np.uint8)
                # Crisp outline (cheap polylines, no copy)
                cv2.polylines(frame, [polygon_i32], True, (0, 255, 100), 3, cv2.LINE_AA)
                return frame
            
            # ═══════════════════════════════════════════════════════════════
            # WATERMARK - Playmaker logo with App Store badges (TOP LEFT)
            # ═══════════════════════════════════════════════════════════════
            logo_img = self.logo_img
            
            # If pre-loaded watermark failed, try loading it now
            if logo_img is None:
                log("⚠️ Pre-loaded watermark is None, attempting runtime load...")
                try:
                    import requests
                    logo_response = requests.get(LOGO_URL, timeout=30)
                    log(f"   Runtime HTTP Status: {logo_response.status_code}")
                    if logo_response.status_code == 200:
                        runtime_logo_path = tmpdir / "watermark.png"
                        with open(runtime_logo_path, 'wb') as f:
                            f.write(logo_response.content)
                        logo_img = cv2.imread(str(runtime_logo_path), cv2.IMREAD_UNCHANGED)
                        if logo_img is not None:
                            log(f"✅ Runtime watermark loaded: shape={logo_img.shape}")
                        else:
                            log(f"❌ Runtime cv2.imread failed")
                except Exception as e:
                    log(f"❌ Runtime watermark load failed: {e}")
            
            watermark_cache = {}
            def create_watermark_overlay(fw, fh):
                # Clean, professional watermark size (12% of frame width)
                target_width = int(fw * 0.12)
                target_width = max(120, min(target_width, 200))  # Clamp 120-200px
                
                if logo_img is not None:
                    # Maintain aspect ratio
                    orig_h, orig_w = logo_img.shape[:2]
                    aspect = orig_w / orig_h
                    target_height = int(target_width / aspect)
                    
                    resized = cv2.resize(logo_img, (target_width, target_height), interpolation=cv2.INTER_AREA)
                    if len(resized.shape) == 2:
                        resized = cv2.cvtColor(resized, cv2.COLOR_GRAY2BGR)
                    if resized.shape[2] == 3:
                        alpha = np.ones((target_height, target_width, 1), dtype=np.uint8) * 255
                        resized = np.concatenate([resized, alpha], axis=2)
                    return resized
                else:
                    # Fallback: Clean text watermark with rounded background
                    target_height = 40
                    wm = np.zeros((target_height, target_width, 4), dtype=np.uint8)
                    # Semi-transparent dark background
                    cv2.rectangle(wm, (0, 0), (target_width, target_height), (40, 40, 40, 180), -1)
                    # Playmaker text
                    cv2.putText(wm, "playmaker", (8, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 191, 99, 255), 2, cv2.LINE_AA)
                    return wm
            
            def draw_watermark(frame):
                h, w = frame.shape[:2]
                if (w, h) not in watermark_cache:
                    watermark_cache[(w, h)] = create_watermark_overlay(w, h)
                wm = watermark_cache[(w, h)]
                wh, ww = wm.shape[:2]
                
                # TOP LEFT position with padding
                x, y = 15, 15
                
                if x + ww > w or y + wh > h:
                    return frame
                
                alpha = wm[:, :, 3:4] / 255.0
                roi = frame[y:y+wh, x:x+ww]
                blended = (alpha * wm[:, :, :3] + (1 - alpha) * roi).astype(np.uint8)
                frame[y:y+wh, x:x+ww] = blended
                return frame
            
            # ═══════════════════════════════════════════════════════════════
            # KALMAN FILTER - v2: tighter tuning, less lag
            # ═══════════════════════════════════════════════════════════════
            class BallKalmanFilter:
                def __init__(self):
                    self.kf = cv2.KalmanFilter(4, 2)
                    self.kf.transitionMatrix = np.array([[1,0,1,0],[0,1,0,1],[0,0,1,0],[0,0,0,1]], dtype=np.float32)
                    self.kf.measurementMatrix = np.array([[1,0,0,0],[0,1,0,0]], dtype=np.float32)
                    # v2: Lower noise = trusts detections more, less lag
                    self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * 0.03
                    self.kf.measurementNoiseCov = np.eye(2, dtype=np.float32) * 0.3
                    self.initialized = False
                    self.frames_since = 0
                
                def init(self, x, y):
                    self.kf.statePost = np.array([[x],[y],[0],[0]], dtype=np.float32)
                    self.initialized = True
                    self.frames_since = 0
                
                def predict(self):
                    if not self.initialized:
                        return None
                    p = self.kf.predict()
                    return p[0,0], p[1,0]
                
                def update(self, x, y):
                    if not self.initialized:
                        self.init(x, y)
                    else:
                        self.kf.correct(np.array([[x],[y]], dtype=np.float32))
                    self.frames_since = 0
                
                def is_valid(self):
                    return self.initialized and self.frames_since < 45
                
                def no_detection(self):
                    self.frames_since += 1
            
            # ═══════════════════════════════════════════════════════════════
            # SMOOTH BROADCAST CAMERA - v2: more responsive following
            # ═══════════════════════════════════════════════════════════════
            class SmoothBroadcastCamera:
                def __init__(self, fw, fh, crop_ratio=0.45):
                    self.fw, self.fh = fw, fh
                    self.crop_w = int(fw * crop_ratio)
                    self.crop_h = fh
                    self.cam_x = fw / 2
                    self.velocity = 0.0
                
                def update(self, ball_x, ball_vx=0):
                    if ball_x is None:
                        self.velocity *= 0.97
                        self.cam_x += self.velocity
                        self._clamp()
                        return
                    
                    target = ball_x + ball_vx * 1.0
                    dist = target - self.cam_x
                    # v2: smaller dead zone for snappier response
                    dead_zone = self.crop_w * 0.08
                    
                    if abs(dist) < dead_zone:
                        self.velocity *= 0.95
                    else:
                        spring = -0.6 * (self.cam_x - target) * 0.01
                        damp = -0.98 * self.velocity * 0.1
                        # v2: higher acceleration limits
                        accel = np.clip(spring + damp, -self.fw * 0.002, self.fw * 0.002)
                        self.velocity = (self.velocity + accel) * 0.96
                    
                    # v2: higher max velocity
                    self.velocity = np.clip(self.velocity, -self.fw * 0.007, self.fw * 0.007)
                    self.cam_x += self.velocity
                    self._clamp()
                
                def _clamp(self):
                    min_x, max_x = self.crop_w / 2, self.fw - self.crop_w / 2
                    if self.cam_x < min_x:
                        self.cam_x, self.velocity = min_x, 0
                    elif self.cam_x > max_x:
                        self.cam_x, self.velocity = max_x, 0
                
                def crop(self, frame):
                    x1 = max(0, int(self.cam_x - self.crop_w / 2))
                    x2 = min(self.fw, int(self.cam_x + self.crop_w / 2))
                    return frame[0:self.fh, x1:x2].copy()
            
            # ═══════════════════════════════════════════════════════════════
            # EXTRACT AUDIO
            # ═══════════════════════════════════════════════════════════════
            log("🔊 Checking for audio...")
            has_audio = False
            try:
                result = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'a', '-show_entries', 'stream=codec_name', '-of', 'default=nw=1', str(input_path)], capture_output=True, text=True, timeout=30)
                if result.stdout.strip():
                    has_audio = True
                    subprocess.run(['ffmpeg', '-y', '-i', str(input_path), '-vn', '-acodec', 'aac', '-b:a', '192k', str(audio_path)], capture_output=True, timeout=120)
                    if audio_path.exists() and audio_path.stat().st_size > 1000:
                        log("✅ Audio extracted")
                    else:
                        has_audio = False
            except:
                has_audio = False
            
            # ═══════════════════════════════════════════════════════════════
            # MAIN PROCESSING (V3 broadcast script when ball tracking enabled)
            # ═══════════════════════════════════════════════════════════════
            log(f"🤖 Using model: {model_name_log}")
            model = active_model  # Use either default or custom model

            cap = cv2.VideoCapture(str(input_path))
            fps = cap.get(cv2.CAP_PROP_FPS) or 25
            W = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            H = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            TOTAL = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

            log(f"📹 Video: {W}x{H} @ {fps:.1f}fps, {TOTAL} frames")
            update_chunk_status(chunk_id, {'gpu_progress': 20}, supabase_key)

            create_field_mask(W, H)

            if enable_ball_tracking:
                # Run BROADCAST_BALL_TRACKING_V3_SCRIPT (bulletproof, red always on ball)
                log("🎬 Using BROADCAST BALL TRACKING v4 (efficient pipeline)")
                import time as _time_mod
                def _update_job(status, progress=None):
                    if progress is not None:
                        update_chunk_status(chunk_id, {'gpu_progress': progress}, supabase_key)
                def _create_tracker(fallback=False):
                    try:
                        if fallback:
                            return cv2.legacy.TrackerKCF_create()
                        return cv2.legacy.TrackerMOSSE_create()
                    except Exception:
                        return cv2.legacy.TrackerKCF_create()
                v4_path = Path("/root/BROADCAST_BALL_TRACKING_V4_SCRIPT.py")
                v4_content = v4_path.read_text()
                exec_globals = {
                    'np': np, 'cv2': cv2, 'os': os, 'requests': __import__('requests'),
                    'time': _time_mod, 'model': model, 'cap': cap,
                    'output_path': str(temp_video_path),
                    'W': W, 'H': H, 'FPS': fps, 'TOTAL': TOTAL,
                    'log': log,
                    'update_job': _update_job,
                    'draw_watermark': draw_watermark,
                    'create_tracker': _create_tracker,
                    '_injected_field_mask': FIELD_MASK_POINTS_NORMALIZED,
                    'SHOW_FIELD_MASK': show_field_mask,
                    'SHOW_BALL_RED': show_red_ball,
                    # ── Field mask overlay function (injected so v4 script can call it) ──
                    'draw_field_mask_overlay_on_original': draw_field_mask_overlay_on_original,
                    # ── Variables required by v4.3 script ──
                    'DETECTION_SIZE': 960,          # YOLO inference size
                    'FULL_FRAME_INTERVAL': 6,        # v4.7: DETECT_EVERY=max(30,6*10)=60 (was 3→30)
                    'DETECTION_CONF_TRACKING': 0.28, # v4.7: slightly lower conf for faster rates
                }

                exec(v4_content, exec_globals)
                update_chunk_status(chunk_id, {'gpu_progress': 85}, supabase_key)
            else:
                # Legacy v2 loop (ball tracking disabled)
                kalman = BallKalmanFilter()
                camera = SmoothBroadcastCamera(W, H, crop_ratio=0.45)
                out_w, out_h = camera.crop_w, camera.crop_h
                log(f"📐 Output: {out_w}x{out_h}")
                fourcc = cv2.VideoWriter_fourcc(*'mp4v')
                out = cv2.VideoWriter(str(temp_video_path), fourcc, fps, (out_w, out_h))
                frames_with_ball = 0
                ball_vx = 0
                last_ball_x = None
                frame_idx = 0
                last_progress = 20
                DETECTION_INTERVAL = 2
                DETECTION_SIZE = 960
                DETECTION_CONF = 0.15
                while True:
                    ret, frame = cap.read()
                    if not ret:
                        break
                    frame_idx += 1
                    ball_x, ball_y = None, None
                    if frame_idx % DETECTION_INTERVAL == 0:
                        results = model(frame, conf=DETECTION_CONF, imgsz=DETECTION_SIZE, verbose=False)
                        best_ball, best_conf = None, 0
                        for r in results:
                            for box in r.boxes:
                                if int(box.cls[0]) == 32 and float(box.conf[0]) > best_conf:
                                    x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                                    cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
                                    box_w = x2 - x1
                                    box_h = y2 - y1
                                    aspect = box_w / max(box_h, 1)
                                    if aspect < 0.4 or aspect > 2.5:
                                        continue
                                    if box_w > W * 0.08 or box_h > H * 0.08:
                                        continue
                                    if box_w < 5 or box_h < 5:
                                        continue
                                    if is_in_field(cx, cy, W, H):
                                        best_ball, best_conf = (cx, cy), float(box.conf[0])
                        if best_ball:
                            ball_x, ball_y = best_ball
                            if last_ball_x is not None:
                                ball_vx = ball_vx * 0.7 + (ball_x - last_ball_x) * 0.3
                            last_ball_x = ball_x
                            kalman.update(ball_x, ball_y)
                            frames_with_ball += 1
                        else:
                            kalman.no_detection()
                    if kalman.is_valid():
                        pred = kalman.predict()
                        if pred:
                            ball_x, ball_y = pred
                    if pred and ball_x and ball_y and show_red_ball:
                        # Draw red circle at tracked position
                        cv2.circle(frame, (int(ball_x), int(ball_y)), 10, (0, 0, 255), 3)

                    camera.update(ball_x, ball_vx if ball_x else 0)
                    frame = draw_field_mask_overlay_on_original(frame, W, H)
                    cropped = camera.crop(frame)
                    if cropped.shape[1] != out_w or cropped.shape[0] != out_h:
                        cropped = cv2.resize(cropped, (out_w, out_h))
                    if show_field_mask:
                        cv2.putText(cropped, "FIELD MASK", (10, out_h - 15),
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 100), 1, cv2.LINE_AA)
                    cropped = draw_watermark(cropped)
                    out.write(cropped)
                    if frame_idx % max(1, TOTAL // 10) == 0:
                        progress = 20 + int((frame_idx / TOTAL) * 60)
                        if progress > last_progress:
                            log(f"⚙️ Processing: {progress}% ({frame_idx}/{TOTAL})")
                            update_chunk_status(chunk_id, {'gpu_progress': progress}, supabase_key)
                            last_progress = progress
                cap.release()
                out.release()
                detection_frames = TOTAL // DETECTION_INTERVAL
                accuracy = int((frames_with_ball / max(1, detection_frames)) * 100)
                log(f"✅ Processed {frame_idx} frames, ball found in {frames_with_ball}/{detection_frames} detections ({accuracy}%)")
                update_chunk_status(chunk_id, {'gpu_progress': 85}, supabase_key)

            # ═══════════════════════════════════════════════════════════════
            # FINAL ENCODING (with audio if available)
            # ═══════════════════════════════════════════════════════════════
            log("🔧 Final encoding...")
            if has_audio and audio_path.exists():
                log("🔊 Merging with audio...")
                subprocess.run([
                    'ffmpeg', '-y', '-i', str(temp_video_path), '-i', str(audio_path),
                    '-c:v', 'libx264', '-preset', 'fast', '-crf', '23',
                    '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart',
                    str(output_path)
                ], capture_output=True, timeout=600)
            else:
                subprocess.run([
                    'ffmpeg', '-y', '-i', str(temp_video_path),
                    '-c:v', 'libx264', '-preset', 'fast', '-crf', '23', '-movflags', '+faststart',
                    str(output_path)
                ], capture_output=True, timeout=600)
            
            if not output_path.exists():
                output_path = temp_video_path
            
            update_chunk_status(chunk_id, {'gpu_progress': 95}, supabase_key)
            
            # Upload video
            log("📤 Uploading processed video...")
            remote_path = f"processed/{schedule_id}/{chunk_id}.mp4"
            processed_url = upload_to_bunny(output_path, remote_path, bunny_key)
            
            # Generate and upload thumbnail
            thumbnail_url = None
            if processed_url:
                log("🖼️ Generating thumbnail...")
                thumbnail_path = tmpdir / "thumbnail.jpg"
                if generate_thumbnail(output_path, thumbnail_path):
                    thumbnail_remote = f"{schedule_id}/{chunk_id}.jpg"
                    thumbnail_url = upload_thumbnail_to_supabase(thumbnail_path, thumbnail_remote, supabase_key)
                    if thumbnail_url:
                        log(f"✅ Thumbnail: {thumbnail_url}")
                    else:
                        log("⚠️ Thumbnail upload failed, continuing without thumbnail", "WARNING")
            
            if processed_url:
                # Calculate processing time and cost (accurate T4 rate)
                processing_time = time.time() - start_time
                gpu_cost = processing_time * T4_GPU_RATE
                gpu_finished_at = datetime.utcnow().isoformat()
                
                chunk_update = {
                    'status': 'completed',
                    'processed_url': processed_url,
                    'gpu_progress': 100,
                    'processing_time_seconds': round(processing_time, 1),
                    'gpu_cost_usd': round(gpu_cost, 4),
                    'gpu_finished_at': gpu_finished_at
                }
                if thumbnail_url:
                    chunk_update['thumbnail_url'] = thumbnail_url
                
                update_chunk_status(chunk_id, chunk_update, supabase_key)
                
                minutes = int(processing_time // 60)
                seconds = int(processing_time % 60)
                log(f"🎉 BROADCAST PROCESSING COMPLETE!")
                log(f"⏱️ Processing time: {minutes}m {seconds}s")
                log(f"💰 GPU cost: ${gpu_cost:.4f}")
                log(f"📺 Video: {processed_url}")
                
                # Check if ALL chunks are complete and trigger merge
                try:
                    import requests
                    headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}", "Content-Type": "application/json"}
                    
                    # Get all chunks for this schedule
                    chunks_response = requests.get(
                        f"{SUPABASE_URL}/rest/v1/camera_recording_chunks?schedule_id=eq.{schedule_id}&select=id,status,gpu_status,processed_url,chunk_number",
                        headers=headers, timeout=30
                    )
                    
                    if chunks_response.status_code == 200:
                        chunks = chunks_response.json()
                        total_chunks = len(chunks)
                        completed_chunks = [c for c in chunks if c.get('processed_url') and (c.get('gpu_status') == 'completed' or c.get('status') == 'completed')]
                        
                        log(f"📊 Chunk status: {len(completed_chunks)}/{total_chunks} completed")
                        
                        if len(completed_chunks) == total_chunks and total_chunks > 0:
                            # ALL CHUNKS DONE! Trigger merge
                            log(f"🎬 ALL {total_chunks} CHUNKS COMPLETE! Starting merge...")
                            
                            # Sort by chunk number
                            completed_chunks.sort(key=lambda x: x.get('chunk_number', 0))
                            processed_urls = [c['processed_url'] for c in completed_chunks]
                            
                            # Spawn merge job
                            merge_chunks.spawn(schedule_id, processed_urls, field_id, supabase_key, bunny_key)
                            
                            # Update schedule status to merging
                            requests.patch(f"{SUPABASE_URL}/rest/v1/camera_recording_schedules?id=eq.{schedule_id}",
                                headers=headers, json={'status': 'merging'}, timeout=10)
                        else:
                            # Not all done yet
                            requests.patch(f"{SUPABASE_URL}/rest/v1/camera_recording_schedules?id=eq.{schedule_id}",
                                headers=headers, json={'status': 'processing'}, timeout=10)
                except Exception as e:
                    log(f"⚠️ Error checking chunks: {e}", "WARNING")
                
                return {"success": True, "processed_url": processed_url}
            else:
                log("❌ Upload failed!", "ERROR")
                update_chunk_status(chunk_id, {'status': 'gpu_failed'}, supabase_key)
                return {"error": "Upload failed"}


# ═══════════════════════════════════════════════════════════════════════════════
# MERGE CHUNKS - Combines all processed chunks into final video (CPU only)
# ═══════════════════════════════════════════════════════════════════════════════
@app.function(
    image=image,
    timeout=7200,  # 2 hours - for long recordings (1 hour = 6 chunks)
    secrets=[supabase_secret, bunny_secret],
    cpu=1.0,  # Explicit CPU allocation for cost tracking
)
def merge_chunks(schedule_id: str, processed_urls: list, field_id: str, supabase_key: str, bunny_key: str):
    """Merge all processed chunks into one final video"""
    import requests
    import time
    
    start_time = time.time()
    
    def log(msg, level="INFO"):
        print(f"[MERGE] {msg}")
        try:
            headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}", "Content-Type": "application/json"}
            log_data = {"field_id": field_id, "schedule_id": schedule_id, "level": level, "message": f"[MERGE] {msg}", "source": "modal_gpu"}
            requests.post(f"{SUPABASE_URL}/rest/v1/camera_logs", headers=headers, json=log_data, timeout=10)
        except:
            pass
    
    log(f"🎬 STARTING MERGE: {len(processed_urls)} chunks")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        chunk_files = []
        
        # Download all processed chunks
        for i, url in enumerate(processed_urls):
            chunk_path = tmpdir / f"chunk_{i:03d}.mp4"
            log(f"📥 Downloading chunk {i+1}/{len(processed_urls)}...")
            
            try:
                response = requests.get(url, stream=True, timeout=600)
                response.raise_for_status()
                with open(chunk_path, 'wb') as f:
                    for data in response.iter_content(chunk_size=65536):
                        f.write(data)
                chunk_files.append(chunk_path)
                log(f"✅ Chunk {i+1} downloaded: {chunk_path.stat().st_size / (1024*1024):.1f} MB")
            except Exception as e:
                log(f"❌ Failed to download chunk {i+1}: {e}", "ERROR")
                return {"error": f"Download failed for chunk {i+1}"}
        
        # Create concat list file
        concat_file = tmpdir / "concat.txt"
        with open(concat_file, 'w') as f:
            for chunk_path in chunk_files:
                f.write(f"file '{chunk_path}'\n")
        
        # Merge using ffmpeg concat demuxer
        output_path = tmpdir / "final_merged.mp4"
        log(f"🔗 Merging {len(chunk_files)} chunks...")
        
        try:
            result = subprocess.run([
                'ffmpeg', '-y', '-f', 'concat', '-safe', '0',
                '-i', str(concat_file),
                '-c', 'copy',  # No re-encoding - fast!
                '-movflags', '+faststart',
                str(output_path)
            ], capture_output=True, timeout=1800)
            
            if result.returncode != 0:
                log(f"❌ FFmpeg merge failed: {result.stderr.decode()[:500]}", "ERROR")
                return {"error": "Merge failed"}
            
            merged_size = output_path.stat().st_size / (1024 * 1024)
            log(f"✅ Merged video: {merged_size:.1f} MB")
            
        except Exception as e:
            log(f"❌ Merge error: {e}", "ERROR")
            return {"error": str(e)}
        
        # Upload merged video
        log("📤 Uploading final merged video...")
        remote_path = f"final/{schedule_id}/merged.mp4"
        final_url = upload_to_bunny(output_path, remote_path, bunny_key)
        
        # Generate thumbnail for final video
        final_thumbnail_url = None
        if final_url:
            log("🖼️ Generating final video thumbnail...")
            thumbnail_path = tmpdir / "final_thumbnail.jpg"
            if generate_thumbnail(output_path, thumbnail_path, timestamp_pct=0.2):
                thumbnail_remote = f"{schedule_id}/final.jpg"
                final_thumbnail_url = upload_thumbnail_to_supabase(thumbnail_path, thumbnail_remote, supabase_key)
                if final_thumbnail_url:
                    log(f"✅ Final thumbnail: {final_thumbnail_url}")
        
        if final_url:
            merge_time = time.time() - start_time
            # Calculate CPU cost for merge operation
            merge_cpu_cost = merge_time * CPU_RATE
            
            minutes = int(merge_time // 60)
            seconds = int(merge_time % 60)
            
            log(f"🎉 MERGE COMPLETE!")
            log(f"⏱️ Merge time: {minutes}m {seconds}s")
            log(f"💰 Merge CPU cost: ${merge_cpu_cost:.4f}")
            log(f"📺 Final video: {final_url}")
            
            # Update schedule with final URL, thumbnail, and MERGE COST
            try:
                from datetime import datetime
                headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}", "Content-Type": "application/json"}
                schedule_update = {
                    'status': 'completed',
                    'final_video_url': final_url,
                    'merge_time_seconds': round(merge_time, 1),
                    'merge_cost_usd': round(merge_cpu_cost, 4),  # Track merge cost
                    'completed_at': datetime.utcnow().isoformat()  # Mark completion time
                }
                if final_thumbnail_url:
                    schedule_update['thumbnail_url'] = final_thumbnail_url
                
                log(f"📝 Updating schedule {schedule_id} with: {schedule_update}")
                
                response = requests.patch(
                    f"{SUPABASE_URL}/rest/v1/camera_recording_schedules?id=eq.{schedule_id}",
                    headers=headers,
                    json=schedule_update,
                    timeout=30
                )
                
                if response.status_code in [200, 204]:
                    log(f"✅ Schedule updated successfully! Status: {response.status_code}")
                else:
                    log(f"❌ Schedule update FAILED! Status: {response.status_code}", "ERROR")
                    log(f"   Response: {response.text[:500]}", "ERROR")
            except Exception as e:
                log(f"❌ Failed to update schedule: {e}", "ERROR")
                import traceback
                traceback.print_exc()
            
            return {"success": True, "final_url": final_url, "merge_time": merge_time, "merge_cost": merge_cpu_cost}
        else:
            log("❌ Upload of merged video failed!", "ERROR")
            return {"error": "Upload failed"}


# ═══════════════════════════════════════════════════════════════════════════════
# LEGACY FUNCTION - Wrapper for backward compatibility
# ═══════════════════════════════════════════════════════════════════════════════
@app.function(
    image=image,
    gpu="T4",
    timeout=7200,
    secrets=[supabase_secret, bunny_secret],
)
def process_chunk(chunk_id: str, video_url: str, schedule_id: str, chunk_number: int = 0, enable_ball_tracking: bool = True, show_field_mask: bool = False):
    """Legacy wrapper - forwards to optimized class method"""
    # This wrapper exists for backward compatibility but uses the optimized processor
    processor = ChunkProcessor()
    return processor.process.remote(chunk_id, video_url, schedule_id, chunk_number, enable_ball_tracking, show_field_mask)


# HTTP endpoint for triggering from Pi
@app.function(image=image, secrets=[supabase_secret, bunny_secret])
@modal.fastapi_endpoint(method="POST")
def process_chunk_webhook(item: dict):
    """HTTP endpoint to trigger chunk processing"""
    chunk_id = item.get('chunk_id')
    video_url = item.get('video_url')
    schedule_id = item.get('schedule_id')
    chunk_number = item.get('chunk_number', 0)
    enable_ball_tracking = item.get('enable_ball_tracking', True)
    show_field_mask = item.get('show_field_mask', False)  # Show field mask overlay in output
    show_red_ball = item.get('show_red_ball', False)
    
    if not all([chunk_id, video_url, schedule_id]):
        return {"error": "Missing required fields"}
    
    # Use optimized class-based processor
    # Note: show_field_mask can be passed explicitly, but it's also read from schedule settings
    processor = ChunkProcessor()
    processor.process.spawn(chunk_id, video_url, schedule_id, chunk_number, enable_ball_tracking, show_field_mask, show_red_ball)
    return {"status": "queued", "chunk_id": chunk_id}


# ═══════════════════════════════════════════════════════════════════════════════
# BALL TRACKING WEBHOOK - For testing ball tracking scripts on uploaded videos
# ═══════════════════════════════════════════════════════════════════════════════
@app.cls(
    image=image,
    gpu="T4",
    timeout=7200,  # 2 hours for long videos
    secrets=[supabase_secret],
    scaledown_window=300,  # Updated from container_idle_timeout (Modal v1.0)
)
class BallTrackingProcessor:
    """
    Ball tracking processor for testing custom scripts on uploaded videos.
    Uses the same infrastructure as chunk processing for reliability.
    """
    
    @modal.enter()
    def load_model(self):
        """Load Roboflow model when container starts"""
        print("🤖 Loading Roboflow model for ball tracking (soccer-ball-tracker-sgt32/4)...")
        from ultralytics import YOLO
        import os
        import tempfile
        from pathlib import Path
        
        model_id = "soccer-ball-tracker-sgt32/4"
        rf_api_key = "TsZ58QXSmc6pkBSsklrJ"
        
        try:
            from roboflow import Roboflow
            rf = Roboflow(api_key=rf_api_key)
            project_name, version = model_id.split("/")
            project = rf.workspace().project(project_name)
            model_instance = project.version(int(version)).model
            
            rf_model_dir = Path(tempfile.gettempdir()) / f"rf_model_{model_id.replace('/', '_')}"
            rf_model_dir.mkdir(parents=True, exist_ok=True)
            
            original_dir = os.getcwd()
            os.chdir(rf_model_dir)
            model_instance.download("yolov8")
            os.chdir(original_dir)
            
            weights_path = list(rf_model_dir.glob("**/best.pt"))
            if not weights_path:
                weights_path = list(rf_model_dir.glob("**/*.pt"))
                
            if weights_path:
                self.default_model = YOLO(str(weights_path[0]))
                self.current_model = self.default_model
                self.current_model_path = model_id
                print(f"✅ Roboflow model {model_id} loaded successfully!")
            else:
                raise Exception("Could not find weights")
        except Exception as e:
            print(f"❌ Roboflow download failed: {e}")
            import traceback
            traceback.print_exc()
            print("⚠️ Falling back to yolov8l.pt")
            self.default_model = YOLO('yolov8l.pt')
            self.current_model = self.default_model
            self.current_model_path = 'yolov8l'
        
        # Pre-download watermark logo with detailed logging
        self.logo_img = None
        try:
            import requests
            import cv2
            
            print(f"🖼️ [BallTracking] Downloading watermark from: {LOGO_URL}")
            
            # Use requests instead of urllib for better error handling
            response = requests.get(LOGO_URL, timeout=30)
            print(f"   HTTP Status: {response.status_code}")
            print(f"   Content-Type: {response.headers.get('content-type', 'unknown')}")
            print(f"   Content-Length: {len(response.content)} bytes")
            
            if response.status_code == 200:
                logo_path = Path(tempfile.gettempdir()) / "watermark.png"
                with open(logo_path, 'wb') as f:
                    f.write(response.content)
                print(f"   Saved to: {logo_path}")
                print(f"   File size: {logo_path.stat().st_size} bytes")
                
                self.logo_img = cv2.imread(str(logo_path), cv2.IMREAD_UNCHANGED)
                if self.logo_img is not None:
                    print(f"✅ [BallTracking] Watermark pre-loaded: shape={self.logo_img.shape}, dtype={self.logo_img.dtype}")
                else:
                    print(f"❌ [BallTracking] cv2.imread returned None - file might not be a valid image")
                    # Try to read first bytes to see what the file contains
                    with open(logo_path, 'rb') as f:
                        first_bytes = f.read(20)
                    print(f"   First bytes: {first_bytes[:20]}")
            else:
                print(f"❌ [BallTracking] HTTP error: {response.status_code} - {response.text[:200]}")
        except Exception as e:
            import traceback
            print(f"⚠️ [BallTracking] Watermark pre-load failed: {e}")
            traceback.print_exc()
    
    @modal.method()
    def process(self, job_id: str, video_url: str, config: dict, 
                custom_script: str = None, roboflow_api_key: str = None):
        import os
        import cv2
        import numpy as np
        import time
        import requests
        from datetime import datetime
        
        start_time = time.time()
        supabase_key = os.environ.get("SUPABASE_KEY") or os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        
        # Log collector - stores all logs for display in UI
        processing_logs = []
        
        def log(message):
            """Add a log message and print it"""
            timestamp = datetime.now().strftime("%H:%M:%S")
            log_entry = f"[{timestamp}] {message}"
            processing_logs.append(log_entry)
            print(message)
        
        def get_logs_text():
            """Get all collected logs as a string (truncated if too large)"""
            logs = "\n".join(processing_logs)
            if len(logs) > 50000:
                return logs[-50000:] # Keep last 50KB to avoid Supabase rejection
            return logs
        
        def update_job(status, progress=None, error=None, save_logs=False, **kwargs):
            """Update job status in Supabase with robust error handling"""
            update_data = {"status": status, "updated_at": datetime.utcnow().isoformat()}
            if progress is not None:
                update_data["progress_percent"] = progress
            if error:
                update_data["error_message"] = str(error)
            if save_logs:
                update_data["processing_logs"] = get_logs_text()
            
            # Additional metrics for completed jobs
            if status == "completed":
                update_data["processing_time_seconds"] = time.time() - start_time
            
            update_data.update(kwargs)
            
            try:
                headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}", "Content-Type": "application/json"}
                response = requests.patch(
                    f"{SUPABASE_URL}/rest/v1/ball_tracking_jobs?id=eq.{job_id}",
                    headers=headers, json=update_data, timeout=30
                )
                if response.status_code not in [200, 204]:
                    print(f"⚠️ Job update failure ({status}): {response.status_code} - {response.text}")
                    # If it's a log-related failure, try updating without logs
                    if save_logs and (response.status_code == 413 or "payload too large" in response.text.lower()):
                        print("🔄 Retrying update without logs...")
                        update_data.pop("processing_logs", None)
                        requests.patch(
                            f"{SUPABASE_URL}/rest/v1/ball_tracking_jobs?id=eq.{job_id}",
                            headers=headers, json=update_data, timeout=30
                        )
                else:
                    print(f"📊 Job update: {status} {progress}% - OK")
            except Exception as e:
                print(f"⚠️ Job update catastrophic error: {e}")
        
        log(f"🚀 Ball Tracking Job: {job_id}")
        log(f"📹 Video URL: {video_url[:80]}...")
        
        # Initialize metrics to ensure they are always in scope for final update
        accuracy = 0
        tracker_ok_count = 0
        gpu_cost = 0.0
        model_name_log = "yolov8l"
        
        try:
            update_job("processing", progress=5, save_logs=True)
            
            # Extract config
            ZOOM_BASE = config.get("zoom_base", 1.75)
            ZOOM_FAR = config.get("zoom_far", 2.1)
            SMOOTHING = config.get("smoothing", 0.07)
            ZOOM_SMOOTH = config.get("zoom_smooth", 0.1)
            DETECT_EVERY_FRAMES = config.get("detect_every_frames", 2)
            YOLO_CONF = config.get("yolo_conf", 0.35)
            MEMORY = config.get("memory", 6)
            PREDICT_FACTOR = config.get("predict", 0.25)
            ROI_SIZE = config.get("roi_size", 400)
            SHOW_RED_BALL = config.get("show_red_ball", False)
            # ═══════════════════════════════════════════════════════════════
            # MODEL SELECTION
            # ═══════════════════════════════════════════════════════════════
            try:
                YOLO_MODEL = config.get("yolo_model", getattr(self, "current_model_path", "soccer-ball-tracker-sgt32/4"))
                active_model = self.default_model
                model_name_log = YOLO_MODEL
            except Exception as e:
                YOLO_MODEL = "yolov8l"
                active_model = getattr(self, "default_model", None)
                model_name_log = "Fallback"
                log(f"⚠️ Error preparing model variables: {e}")

            log(f"⚙️ Config: Model={model_name_log}, Conf={YOLO_CONF}, DetectEvery={DETECT_EVERY_FRAMES}, ShowRedBall={SHOW_RED_BALL}")
            
            with tempfile.TemporaryDirectory() as tmpdir:
                tmpdir = Path(tmpdir)
                input_path = tmpdir / "input.mp4"
                temp_video_path = tmpdir / "temp_video.mp4"  # Intermediate video without audio
                audio_path = tmpdir / "audio.aac"  # Extracted audio
                output_path = tmpdir / "output.mp4"  # Final video with audio
                
                # Download video
                log("📥 Downloading video...")
                update_job("processing", progress=10, save_logs=True)
                
                if not download_video(video_url, input_path):
                    raise Exception("Failed to download video")
                
                log("✅ Video downloaded successfully")
                
                # ═══════════════════════════════════════════════════════════════
                # EXTRACT AUDIO (preserve for final output)
                # ═══════════════════════════════════════════════════════════════
                log("🔊 Checking for audio...")
                has_audio = False
                try:
                    result = subprocess.run(
                        ['ffprobe', '-v', 'error', '-select_streams', 'a', '-show_entries', 'stream=codec_name', '-of', 'default=nw=1', str(input_path)],
                        capture_output=True, text=True, timeout=30
                    )
                    if result.stdout.strip():
                        has_audio = True
                        subprocess.run(
                            ['ffmpeg', '-y', '-i', str(input_path), '-vn', '-acodec', 'aac', '-b:a', '192k', str(audio_path)],
                            capture_output=True, timeout=120
                        )
                        if audio_path.exists() and audio_path.stat().st_size > 1000:
                            log("✅ Audio extracted successfully")
                        else:
                            has_audio = False
                            log("⚠️ Audio extraction failed, output will have no audio")
                except Exception as e:
                    has_audio = False
                    log(f"⚠️ Audio check error: {e}, output will have no audio")
                
                update_job("processing", progress=20, save_logs=True)
                
                # Open video
                cap = cv2.VideoCapture(str(input_path))
                if not cap.isOpened():
                    raise Exception("Cannot open input video")
                
                W = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
                H = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
                FPS = cap.get(cv2.CAP_PROP_FPS) or 25.0
                TOTAL = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
                dt = 1.0 / FPS
                
                log(f"🎬 Video: {W}x{H} @ {FPS:.1f}fps, {TOTAL} frames")
                
                duration = TOTAL / FPS
                update_job("processing", progress=25, save_logs=True, video_duration_seconds=duration, total_frames=TOTAL)
                
                model = active_model
                
                # ═══════════════════════════════════════════════════════════════
                # WATERMARK - Playmaker logo with App Store badges (TOP LEFT)
                # ═══════════════════════════════════════════════════════════════
                logo_img = self.logo_img
                
                # If pre-loaded watermark failed, try loading it now
                if logo_img is None:
                    log("⚠️ Pre-loaded watermark is None, attempting runtime load...")
                    try:
                        logo_response = requests.get(LOGO_URL, timeout=30)
                        log(f"   Runtime HTTP Status: {logo_response.status_code}")
                        log(f"   Content-Type: {logo_response.headers.get('content-type', 'unknown')}")
                        log(f"   Content-Length: {len(logo_response.content)} bytes")
                        if logo_response.status_code == 200:
                            runtime_logo_path = tmpdir / "watermark.png"
                            with open(runtime_logo_path, 'wb') as f:
                                f.write(logo_response.content)
                            logo_img = cv2.imread(str(runtime_logo_path), cv2.IMREAD_UNCHANGED)
                            if logo_img is not None:
                                log(f"✅ Runtime watermark loaded: shape={logo_img.shape}")
                            else:
                                log(f"❌ Runtime cv2.imread failed - file may not be a valid image")
                    except Exception as e:
                        log(f"❌ Runtime watermark load failed: {e}")
                else:
                    log(f"✅ Using pre-loaded watermark: shape={logo_img.shape}")
                
                watermark_cache = {}
                
                def create_watermark_overlay(fw, fh):
                    # Clean, professional watermark size (12% of frame width)
                    target_width = int(fw * 0.12)
                    target_width = max(120, min(target_width, 200))  # Clamp 120-200px
                    
                    if logo_img is not None:
                        # Maintain aspect ratio
                        orig_h, orig_w = logo_img.shape[:2]
                        aspect = orig_w / orig_h
                        target_height = int(target_width / aspect)
                        
                        resized = cv2.resize(logo_img, (target_width, target_height), interpolation=cv2.INTER_AREA)
                        if len(resized.shape) == 2:
                            resized = cv2.cvtColor(resized, cv2.COLOR_GRAY2BGR)
                        if resized.shape[2] == 3:
                            alpha = np.ones((target_height, target_width, 1), dtype=np.uint8) * 255
                            resized = np.concatenate([resized, alpha], axis=2)
                        return resized
                    else:
                        # Fallback: Clean text watermark with semi-transparent background
                        target_height = 40
                        wm = np.zeros((target_height, target_width, 4), dtype=np.uint8)
                        # Semi-transparent dark background
                        cv2.rectangle(wm, (0, 0), (target_width, target_height), (40, 40, 40, 180), -1)
                        # Playmaker text in green
                        cv2.putText(wm, "playmaker", (8, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 191, 99, 255), 2, cv2.LINE_AA)
                        return wm
                
                def draw_watermark(frame):
                    h, w = frame.shape[:2]
                    if (w, h) not in watermark_cache:
                        watermark_cache[(w, h)] = create_watermark_overlay(w, h)
                    wm = watermark_cache[(w, h)]
                    wh, ww = wm.shape[:2]
                    
                    # TOP LEFT position with padding
                    x, y = 15, 15
                    
                    if x + ww > w or y + wh > h:
                        return frame
                    
                    alpha = wm[:, :, 3:4] / 255.0
                    roi = frame[y:y+wh, x:x+ww]
                    blended = (alpha * wm[:, :, :3] + (1 - alpha) * roi).astype(np.uint8)
                    frame[y:y+wh, x:x+ww] = blended
                    return frame
                
                # ============================================================
                # CUSTOM SCRIPT EXECUTION (if provided)
                # ============================================================
                if custom_script:
                    log("🐍 Executing custom Python script...")
                    update_job("processing", progress=30, save_logs=True)
                    
                    # Helper functions for custom script
                    def create_tracker(fallback=False):
                        try:
                            if fallback:
                                return cv2.legacy.TrackerKCF_create()
                            return cv2.legacy.TrackerMOSSE_create()
                        except:
                            return cv2.legacy.TrackerKCF_create()
                    
                    def create_kalman_filter(x, y, dt_val):
                        kf = cv2.KalmanFilter(4, 2)
                        kf.transitionMatrix = np.array([[1,0,dt_val,0],[0,1,0,dt_val],[0,0,1,0],[0,0,0,1]], np.float32)
                        kf.measurementMatrix = np.array([[1,0,0,0],[0,1,0,0]], np.float32)
                        kf.statePost = np.array([[x],[y],[0],[0]], np.float32)
                        kf.processNoiseCov = np.diag([1.0,1.0,0.5,0.5]).astype(np.float32) * 0.2
                        kf.measurementNoiseCov = np.diag([1.0,1.0]).astype(np.float32) * 8
                        return kf
                    
                    # Prepare execution environment
                    # NOTE: output_path points to temp_video_path so audio can be merged later
                    exec_globals = {
                        'cv2': cv2,
                        'np': np,
                        'numpy': np,
                        'time': time,
                        'subprocess': subprocess,
                        'os': os,
                        'json': __import__('json'),  # For parsing ffprobe output
                        'urllib': urllib,  # For downloading files in custom scripts
                        'requests': requests,  # HTTP requests library
                        'Path': Path,  # Path utilities
                        'model': model,
                        'cap': cap,
                        'W': W,
                        'H': H,
                        'FPS': FPS,
                        'TOTAL': TOTAL,
                        'input_path': str(input_path),  # Path to downloaded input video
                        'output_path': str(temp_video_path),  # Write to temp, audio merged later
                        'audio_path': str(audio_path),  # Audio extraction path
                        'tmpdir': tmpdir,  # Temp directory for custom scripts
                        'has_audio': has_audio,  # Whether input video has audio (already extracted)
                        'update_job': update_job,
                        'log': log,  # Log function for UI display
                        'create_tracker': create_tracker,
                        'create_kalman_filter': create_kalman_filter,
                        'draw_watermark': draw_watermark,  # Watermark function available
                        'logo_img': logo_img,  # Pre-loaded watermark image (can be None)
                        'LOGO_URL': LOGO_URL,  # Watermark URL for manual download if needed
                        'tracker_ok_count': 0,
                        'accuracy': 0,
                        'show_red_ball': SHOW_RED_BALL,
                        # Pass all config variables for convenience in custom scripts
                        'YOLO_MODEL': YOLO_MODEL,
                        'YOLO_CONF': YOLO_CONF,
                        'DETECT_EVERY_FRAMES': DETECT_EVERY_FRAMES,
                        'ROI_SIZE': ROI_SIZE,
                        'SMOOTHING': SMOOTHING,
                        'ZOOM_BASE': ZOOM_BASE,
                        'MEMORY': MEMORY,
                    }
                    
                    try:
                        exec(custom_script, exec_globals)
                        tracker_ok_count = exec_globals.get('tracker_ok_count', 0)
                        accuracy = exec_globals.get('accuracy', 0)
                        log(f"✅ Custom script complete! Accuracy: {accuracy}%")
                    except Exception as e:
                        import traceback
                        error_details = traceback.format_exc()
                        log(f"❌ Custom script error: {e}")
                        log(error_details)
                        raise Exception(f"Custom script failed: {e}")
                
                else:
                    # ============================================================
                    # DEFAULT ALGORITHM (if no custom script)
                    # ============================================================
                    out = cv2.VideoWriter(str(temp_video_path), cv2.VideoWriter_fourcc(*"mp4v"), FPS, (W, H))
                    
                    tracker = None
                    kalman_filter = None
                    ball_memory = []
                    center_x, center_y = W // 2, H // 2
                    zoom_dynamic = ZOOM_BASE
                    frame_idx = 0
                    last_detection_frame = -999
                    tracker_ok_count = 0
                    
                    def create_tracker(fallback=False):
                        try:
                            if fallback:
                                return cv2.legacy.TrackerKCF_create()
                            return cv2.legacy.TrackerMOSSE_create()
                        except:
                            return cv2.legacy.TrackerKCF_create()
                    
                    def create_kalman_filter_local(x, y):
                        kf = cv2.KalmanFilter(4, 2)
                        kf.transitionMatrix = np.array([[1,0,dt,0],[0,1,0,dt],[0,0,1,0],[0,0,0,1]], np.float32)
                        kf.measurementMatrix = np.array([[1,0,0,0],[0,1,0,0]], np.float32)
                        kf.statePost = np.array([[x],[y],[0],[0]], np.float32)
                        kf.processNoiseCov = np.diag([1.0,1.0,0.5,0.5]).astype(np.float32) * 0.2
                        kf.measurementNoiseCov = np.diag([1.0,1.0]).astype(np.float32) * 8
                        return kf
                    
                    print("🏃 Starting ball tracking...")
                    
                    while True:
                        ret, frame = cap.read()
                        if not ret or frame is None:
                            break
                        
                        frame_idx += 1
                        
                        if frame_idx % 30 == 0:
                            progress = 30 + int((frame_idx / TOTAL) * 55)
                            update_job("processing", progress=progress)
                        
                        detected_center = None
                        
                        # Kalman prediction
                        if kalman_filter is not None:
                            pred = kalman_filter.predict()
                            target_x, target_y = int(pred[0][0]), int(pred[1][0])
                            if tracker is None:
                                center_x = target_x
                                center_y = target_y
                        
                        # YOLO Detection
                        do_detect = tracker is None or (frame_idx - last_detection_frame) >= DETECT_EVERY_FRAMES
                        if do_detect:
                            x1 = max(center_x - ROI_SIZE//2, 0)
                            y1 = max(center_y - ROI_SIZE//2, 0)
                            x2 = min(center_x + ROI_SIZE//2, W)
                            y2 = min(center_y + ROI_SIZE//2, H)
                            
                            if y2 > y1 and x2 > x1:
                                roi = frame[y1:y2, x1:x2]
                                
                                if roi is not None and roi.size > 0:
                                    results = model.predict(roi, imgsz=YOLO_IMG_SIZE, conf=YOLO_CONF, verbose=False)[0]
                                    for box in results.boxes:
                                        cls = int(box.cls[0])
                                        conf = float(box.conf[0])
                                        if cls == 32 and conf >= YOLO_CONF:
                                            bx1, by1, bx2, by2 = map(int, box.xyxy[0])
                                            bx1 += x1
                                            bx2 += x1
                                            by1 += y1
                                            by2 += y1
                                            bbox = (bx1, by1, bx2-bx1, by2-by1)
                                            
                                            tracker = create_tracker()
                                            try:
                                                ok = tracker.init(frame, bbox)
                                            except:
                                                ok = False
                                            
                                            if ok:
                                                detected_center = ((bx1+bx2)//2, (by1+by2)//2)
                                                last_detection_frame = frame_idx
                                                
                                                if kalman_filter is None:
                                                    kalman_filter = create_kalman_filter_local(detected_center[0], detected_center[1])
                                                break
                                            else:
                                                tracker = None
                        
                        # Tracker update
                        measured_center = None
                        if tracker is not None:
                            ok, bbox = tracker.update(frame)
                            if ok:
                                x, y, wbox, hbox = map(int, bbox)
                                measured_center = (x + wbox//2, y + hbox//2)
                                tracker_ok_count += 1
                            else:
                                tracker = create_tracker(fallback=True)
                        
                        # Kalman update
                        if measured_center is not None:
                            ball_memory.append(measured_center)
                            if len(ball_memory) > MEMORY:
                                ball_memory.pop(0)
                            measured = np.array([[np.float32(measured_center[0])],
                                                 [np.float32(measured_center[1])]])
                            corr = kalman_filter.correct(measured)
                            target_x, target_y = int(corr[0][0]), int(corr[1][0])
                        elif kalman_filter is None:
                            target_x, target_y = center_x, center_y
                        
                        # Visualization (Show Red Ball)
                        if SHOW_RED_BALL and measured_center:
                            cv2.circle(frame, measured_center, 8, (0, 0, 255), -1)
                        
                        # Smooth camera
                        center_x = int(center_x + SMOOTHING*(target_x - center_x))
                        center_y = int(center_y + SMOOTHING*(target_y - center_y))
                        
                        # Adaptive zoom
                        y_norm = center_y / H
                        desired_zoom = ZOOM_BASE + (ZOOM_FAR - ZOOM_BASE)*(1 - y_norm)
                        zoom_dynamic += ZOOM_SMOOTH*(desired_zoom - zoom_dynamic)
                        
                        # Crop + zoom
                        crop_w = int(W / zoom_dynamic)
                        crop_h = int(H / zoom_dynamic)
                        sx = max(0, min(W - crop_w, center_x - crop_w//2))
                        sy = max(0, min(H - crop_h, center_y - crop_h//2))
                        
                        if sy < H and sx < W:
                            cropped = frame[sy:sy+crop_h, sx:sx+crop_w]
                            if cropped is not None and cropped.size > 0:
                                zoomed = cv2.resize(cropped, (W, H), interpolation=cv2.INTER_LINEAR)
                                # Add watermark to frame (top left)
                                zoomed = draw_watermark(zoomed)
                                out.write(zoomed)
                    
                    cap.release()
                    out.release()
                    
                    accuracy = int(tracker_ok_count / TOTAL * 100) if TOTAL > 0 else 0
                    log(f"✅ Ball tracking complete! Accuracy: {accuracy}%")
                
                # ═══════════════════════════════════════════════════════════════
                # FINAL ENCODING (merge audio if available)
                # ═══════════════════════════════════════════════════════════════
                log("🔧 Final encoding...")
                update_job("processing", progress=85, save_logs=True)
                
                if has_audio and audio_path.exists():
                    log("🔊 Merging video with audio...")
                    subprocess.run([
                        'ffmpeg', '-y', '-i', str(temp_video_path), '-i', str(audio_path),
                        '-c:v', 'libx264', '-preset', 'fast', '-crf', '23',
                        '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart',
                        str(output_path)
                    ], capture_output=True, timeout=600)
                    log("✅ Audio merged successfully")
                else:
                    log("⚠️ No audio to merge, encoding video only...")
                    subprocess.run([
                        'ffmpeg', '-y', '-i', str(temp_video_path),
                        '-c:v', 'libx264', '-preset', 'fast', '-crf', '23', '-movflags', '+faststart',
                        str(output_path)
                    ], capture_output=True, timeout=600)
                
                # Fallback to temp video if encoding failed
                if not output_path.exists():
                    log("⚠️ Final encoding failed, using temp video")
                    output_path = temp_video_path
                
                # Calculate costs
                processing_time = time.time() - start_time
                gpu_cost = processing_time * T4_GPU_RATE
                
                log(f"⏱️ Processing time: {processing_time:.1f}s")
                log(f"💰 GPU cost: ${gpu_cost:.4f}")
                
                # Upload output video to Supabase Storage
                log("⬆️ Uploading output video...")
                update_job("processing", progress=90, save_logs=True)
                
                # Check if output exists
                if not output_path.exists():
                    raise Exception("Output video not generated")
                
                output_size_mb = output_path.stat().st_size / (1024 * 1024)
                log(f"📁 Output size: {output_size_mb:.1f} MB")
                
                # Upload to Supabase storage (Resumable TUS Protocol to bypass 50MB/500MB limits)
                output_filename = f"ball-tracking-output/{job_id}.mp4"
                bucket_name = "videos"
                object_name = output_filename
                
                try:
                    import base64
                    import os
                    
                    def b64_str(s):
                        return base64.b64encode(s.encode('utf-8')).decode('utf-8')
                        
                    file_size = output_path.stat().st_size
                    metadata_pieces = [
                        f"bucketName {b64_str(bucket_name)}",
                        f"objectName {b64_str(object_name)}",
                        f"contentType {b64_str('video/mp4')}"
                    ]
                    
                    init_url = f"{SUPABASE_URL}/storage/v1/upload/resumable"
                    init_headers = {
                        "Authorization": f"Bearer {supabase_key}",
                        "Tus-Resumable": "1.0.0",
                        "Upload-Length": str(file_size),
                        "Upload-Metadata": ",".join(metadata_pieces),
                    }
                    
                    log(f"🔄 Initializing TUS upload for {file_size} bytes...")
                    response = requests.post(init_url, headers=init_headers, timeout=30)
                    
                    if response.status_code not in [200, 201, 202, 204]:
                        log(f"⚠️ TUS Init failed: {response.status_code} {response.text[:200]}, falling back to standard upload")
                        # Fallback to standard upload
                        with open(output_path, "rb") as f:
                            output_bytes = f.read()
                        
                        fallback_headers = {
                            "Authorization": f"Bearer {supabase_key}",
                            "Content-Type": "video/mp4"
                        }
                        fallback_url = f"{SUPABASE_URL}/storage/v1/object/{bucket_name}/{output_filename}"
                        resp = requests.post(fallback_url, headers=fallback_headers, data=output_bytes, timeout=600)
                        if resp.status_code not in [200, 201]:
                            resp = requests.put(fallback_url, headers=fallback_headers, data=output_bytes, timeout=600)
                            if resp.status_code not in [200, 201]:
                                raise Exception(f"Fallback Upload failed: {resp.status_code} - {resp.text[:200]}")
                        output_video_url = f"{SUPABASE_STORAGE_URL}/{output_filename}"
                        log(f"✅ Uploaded (Standard): {output_video_url}")
                    else:
                        upload_url = response.headers.get("Location")
                        if not upload_url:
                            raise Exception("No Location header returned in TUS creation")
                            
                        if upload_url.startswith('/'):
                            upload_url = f"{SUPABASE_URL}{upload_url}"
                            
                        chunk_size = 50 * 1024 * 1024 # 50MB
                        offset = 0
                        
                        with open(output_path, "rb") as f:
                            while offset < file_size:
                                f.seek(offset)
                                chunk = f.read(chunk_size)
                                if not chunk:
                                    break
                                    
                                patch_headers = {
                                    "Authorization": f"Bearer {supabase_key}",
                                    "Tus-Resumable": "1.0.0",
                                    "Upload-Offset": str(offset),
                                    "Content-Type": "application/offset+octet-stream",
                                }
                                
                                patch_resp = requests.patch(upload_url, headers=patch_headers, data=chunk, timeout=600)
                                if patch_resp.status_code not in [200, 204]:
                                    raise Exception(f"TUS chunk upload failed: {patch_resp.status_code} {patch_resp.text[:200]}")
                                    
                                offset = int(patch_resp.headers.get("Upload-Offset"))
                                log(f"⬆️ TUS Uploaded {offset}/{file_size} bytes ({(offset/file_size)*100:.1f}%)")
                                update_job("processing", progress=90 + int((offset/file_size)*9))
                                
                        output_video_url = f"{SUPABASE_STORAGE_URL}/{output_filename}"
                        log(f"✅ Uploaded (TUS): {output_video_url}")

                except Exception as e:
                    log(f"⚠️ Upload error: {e}")
                    raise
                
                log(f"🎉 Job {job_id} completed!")
                
                # Update job with results - save ALL collected logs
                update_job(
                    "completed",
                    progress=100,
                    save_logs=True,
                    output_video_url=output_video_url,
                    tracking_accuracy_percent=int(accuracy),
                    frames_tracked=int(tracker_ok_count),
                    gpu_cost_usd=float(gpu_cost),
                    gpu_type="Modal T4",
                )
                
                return {"success": True, "output_url": output_video_url}
                
        except Exception as e:
            import traceback
            error_msg = f"Processing failed: {str(e)}"
            log(f"❌ {error_msg}")
            traceback.print_exc()
            update_job("failed", error=error_msg, save_logs=True)
            return {"error": error_msg}


# HTTP endpoint for ball tracking
@app.function(image=image, secrets=[supabase_secret])
@modal.fastapi_endpoint(method="POST")
def ball_tracking_webhook(item: dict):
    """HTTP endpoint to trigger ball tracking processing
    
    Payload:
    {
        "job_id": "uuid",
        "video_url": "https://...",
        "config": {...},
        "custom_script": "optional python code"
    }
    """
    job_id = item.get('job_id')
    video_url = item.get('video_url')
    config = item.get('config', {})
    custom_script = item.get('custom_script')
    
    if not all([job_id, video_url]):
        return {"error": "Missing required fields: job_id and video_url"}
    
    print(f"🎯 Ball Tracking webhook received: job_id={job_id}")
    
    # Spawn processing job
    processor = BallTrackingProcessor()
    processor.process.spawn(job_id, video_url, config, custom_script, item.get('roboflow_api_key'))
    
    return {"status": "processing", "job_id": job_id}


if __name__ == "__main__":
    print("Deploy with: modal deploy chunk_processor.py")
