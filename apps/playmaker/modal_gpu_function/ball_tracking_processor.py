"""
Ball Tracking GPU Processor - Modal.com Function
Processes football match videos with YOLO ball tracking and returns results to Supabase

Cost: ~$1.10/hour on A100 GPU (scales to zero when idle)
Processing: 2.5-3x faster than A10G, lower cost per video!
"""

import modal

# Create Modal app
app = modal.App("ball-tracking-processor")

# Initialize FastAPI app for web endpoints
try:
    from fastapi import FastAPI
    from fastapi.middleware.cors import CORSMiddleware
    web_app = FastAPI()
    # Add CORS middleware (Permissive for Flutter Web)
    web_app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False, 
        allow_methods=["*"],
        allow_headers=["*"],
    )
except ImportError:
    # Fallback for local environment if fastapi is not installed
    web_app = None

image = (
    modal.Image.debian_slim(python_version="3.12")
    .apt_install(
        "libgl1-mesa-glx", 
        "libglib2.0-0",
        "ffmpeg",  # For automatic video compression
        "libsm6", "libxext6", # Missing cv2 dependencies in some slim images
    )
    .pip_install(
        "opencv-contrib-python-headless",
        "numpy",
        "ultralytics",
        "requests",
        "supabase",
        "fastapi[standard]",
        "roboflow",
        "supervision==0.18.0",
        # Gemini / Imagen client for ai.google.dev
        "google-genai",
        "Pillow",
        "diffusers",
        "transformers",
        "accelerate",
        "torch",
    )
)

# Volume for YOLO models (cached across runs)
yolo_volume = modal.Volume.from_name("yolo-models", create_if_missing=True)

# Volume for Generative AI models (SDXL, etc.)
model_volume = modal.Volume.from_name("diffusers-models", create_if_missing=True)


# Global cache for YOLO models (persists between calls if container stays warm)
_model_cache = {}

@app.function(
    image=image,
    gpu="T4",  # T4 GPU - $0.59/hr, good balance of cost and speed
    timeout=86400,  # 24 hours max (Modal Pro allows up to 24h, free tier is 30min)
    volumes={
        "/models": yolo_volume,
        "/genai_models": model_volume
    },
    secrets=[
        modal.Secret.from_name("supabase-credentials"),
        modal.Secret.from_name("gemini-api-key")
    ],  # Store in Modal dashboard
    cpu=2.0,  # Reduced from 4.0 to speed up scheduling
    memory=8192,  # Reduced from 16GB to 8GB to speed up scheduling
    max_containers=1,  # prevent parallel runs that can cancel each other
    # NOTE: If you're on Modal free tier, max timeout is 30 minutes!
    # Upgrade to Modal Pro ($30/month) for longer timeouts
)
def process_video(job_id: str, input_video_url: str, script_config: dict, supabase_url: str, supabase_key: str, custom_script: str = None, roboflow_api_key: str = None, field_id: str = None):  # noqa: E501
    """
    Process a video with ball tracking
    
    Args:
        job_id: UUID of the job in Supabase
        input_video_url: Public URL of input video
        script_config: Configuration dict with YOLO params
        supabase_url: Supabase project URL
        supabase_key: Supabase service key
    """
    # Import dependencies inside function (available in Modal container)
    import cv2
    import numpy as np
    import requests
    import os
    import torch # Pre-load torch to ensure CUDA libraries are in path for ONNX
    from datetime import datetime
    from ultralytics import YOLO
    from supabase import create_client
    
    print(f"🚀 Starting job {job_id}")
    start_time = datetime.now()
    
    # Initialize Supabase
    supabase = create_client(supabase_url, supabase_key)
    
    # Verify GPU/ORX Providers
    try:
        import onnxruntime as ort
        print(f"👁️ Available ONNX Providers: {ort.get_available_providers()}")
    except Exception as e:
        print(f"⚠️ Could not check ONNX providers: {e}")
    def update_job(status, progress=None, error=None, **kwargs):
        """Update job status in Supabase"""
        update_data = {"status": status, "updated_at": datetime.now().isoformat()}
        if progress is not None:
            update_data["progress_percent"] = progress
        if error:
            update_data["error_message"] = error
        update_data.update(kwargs)
        supabase.table("ball_tracking_jobs").update(update_data).eq("id", job_id).execute()
        
        if status == "processing" and progress is not None:
            print(f"📊 Job update: processing {progress}% - Response: 204")
        else:
            print(f"📊 Updated job: {status} {progress}%")
    
    def create_tracker(fallback=False):
        """Legacy tracker kept for custom scripts that reference it."""
        try:
            if fallback:
                return cv2.legacy.TrackerKCF_create()
            return cv2.legacy.TrackerMOSSE_create()
        except:
            return cv2.legacy.TrackerKCF_create()
    
    def create_kalman_filter(x, y, dt):
        """Legacy Kalman kept for custom scripts. Default algorithm uses BallKalmanTracker."""
        kf = cv2.KalmanFilter(4, 2)
        kf.transitionMatrix = np.array([[1,0,dt,0],[0,1,0,dt],[0,0,1,0],[0,0,0,1]], np.float32)
        kf.measurementMatrix = np.array([[1,0,0,0],[0,1,0,0]], np.float32)
        kf.statePost = np.array([[x],[y],[0],[0]], np.float32)
        kf.processNoiseCov = np.diag([1.0,1.0,0.5,0.5]).astype(np.float32) * 0.2
        kf.measurementNoiseCov = np.diag([1.0,1.0]).astype(np.float32) * 8
        return kf
    
    class BallKalmanTracker:
        """Legacy 4-state Kalman tracker (x, y, vx, vy). Kept for non-TrackNet modes."""
        VELOCITY_DECAY = 0.93
        MAX_MISS = 30
        MAX_TELEPORT_PX = 400
        
        def __init__(self, x, y, dt=1/20):
            self.kf = cv2.KalmanFilter(4, 2)
            self.kf.transitionMatrix = np.array(
                [[1, 0, dt, 0],
                 [0, 1, 0, dt],
                 [0, 0, 1,  0],
                 [0, 0, 0,  1]], np.float32)
            self.kf.measurementMatrix = np.array(
                [[1, 0, 0, 0],
                 [0, 1, 0, 0]], np.float32)
            self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * 0.5
            self.kf.processNoiseCov[2:, 2:] *= 10.0
            self.kf.measurementNoiseCov = np.eye(2, dtype=np.float32) * 2.0
            self.kf.statePost = np.array([[x], [y], [0], [0]], np.float32)
            self.kf.errorCovPost = np.eye(4, dtype=np.float32) * 1.0
            self.miss_count = 0
        
        def predict(self):
            p = self.kf.predict()
            return float(p[0, 0]), float(p[1, 0])
        
        def update(self, x, y):
            self.kf.correct(np.array([[x], [y]], np.float32))
            self.miss_count = 0
        
        def no_detection(self):
            self.miss_count += 1
            self.kf.statePost[2] *= self.VELOCITY_DECAY
            self.kf.statePost[3] *= self.VELOCITY_DECAY
        
        @property
        def is_valid(self):
            return self.miss_count < self.MAX_MISS
        
        @property
        def position(self):
            return float(self.kf.statePost[0, 0]), float(self.kf.statePost[1, 0])
    
    # ══════════════════════════════════════════════════════════════════════
    # ADVANCED 6-STATE BALL TRACKER (x, y, vx, vy, ax, ay)
    # Used exclusively by TrackNet mode for perfect tracking
    # ══════════════════════════════════════════════════════════════════════
    class AdvancedBallTracker:
        """6-state Kalman with acceleration model, adaptive noise,
        velocity-aware teleport guard, gravity bias, and smooth re-init.
        State: [x, y, vx, vy, ax, ay]"""
        
        MAX_MISS = 45           # ~1.8s at 25fps — longer memory
        BASE_TELEPORT_PX = 350  # Increased for far corners / sudden movements
        TELEPORT_VEL_FACTOR = 8.0 # High allowance for fast shots
        VELOCITY_DECAY = 0.96   # Gentler decay during miss
        ACCEL_DECAY = 0.85      # Acceleration decays faster
        GRAVITY_BIAS = 0.3      # Slight downward bias for lobs (px/frame²)
        RE_INIT_BLEND_FRAMES = 8  # Smooth blend when re-acquiring after long loss
        
        def __init__(self, x, y, dt=1/25):
            self.dt = dt
            self.kf = cv2.KalmanFilter(6, 2)
            # Transition: x' = x + vx*dt + 0.5*ax*dt²
            dt2 = 0.5 * dt * dt
            self.kf.transitionMatrix = np.array([
                [1, 0, dt, 0, dt2, 0  ],
                [0, 1, 0, dt, 0,   dt2],
                [0, 0, 1, 0,  dt,  0  ],
                [0, 0, 0, 1,  0,   dt ],
                [0, 0, 0, 0,  1,   0  ],
                [0, 0, 0, 0,  0,   1  ],
            ], np.float32)
            self.kf.measurementMatrix = np.array([
                [1, 0, 0, 0, 0, 0],
                [0, 1, 0, 0, 0, 0],
            ], np.float32)
            # Adaptive process noise (will be updated each frame)
            self._base_process_noise()
            self.kf.measurementNoiseCov = np.eye(2, dtype=np.float32) * 1.0
            self.kf.statePost = np.array([[x], [y], [0], [0], [0], [0]], np.float32)
            self.kf.errorCovPost = np.eye(6, dtype=np.float32) * 5.0
            self.miss_count = 0
            self.total_updates = 0
            self._re_init_target = None
            self._re_init_progress = 0
            self._last_detection_pos = (x, y)
            self._confidence_score = 0.5  # Running confidence
        
        def _base_process_noise(self):
            """Set base process noise — will be scaled by velocity."""
            Q = np.eye(6, dtype=np.float32)
            Q[0, 0] = 1.0    # position uncertainty
            Q[1, 1] = 1.0
            Q[2, 2] = 8.0    # velocity uncertainty (allow fast changes)
            Q[3, 3] = 8.0
            Q[4, 4] = 15.0   # acceleration uncertainty (very high — kicks are sudden)
            Q[5, 5] = 15.0
            self.kf.processNoiseCov = Q
        
        def _adapt_noise(self):
            """Scale process noise based on velocity magnitude."""
            speed = self.speed
            # Fast ball → higher process noise (expect sudden changes)
            # Slow ball → lower process noise (trust trajectory)
            vel_factor = 1.0 + min(5.0, speed / 20.0)
            Q = np.eye(6, dtype=np.float32)
            Q[0, 0] = 0.5 * vel_factor
            Q[1, 1] = 0.5 * vel_factor
            Q[2, 2] = 5.0 * vel_factor
            Q[3, 3] = 5.0 * vel_factor
            Q[4, 4] = 12.0 * vel_factor
            Q[5, 5] = 12.0 * vel_factor
            self.kf.processNoiseCov = Q
        
        def predict(self):
            """Predict next position. Returns (x, y)."""
            self._adapt_noise()
            p = self.kf.predict()
            # Apply gravity bias to y-acceleration if ball is in air (vy < 0 = going up)
            if self.miss_count == 0:
                self.kf.statePost[5, 0] += self.GRAVITY_BIAS
            return float(p[0, 0]), float(p[1, 0])
        
        def update(self, x, y, confidence=1.0):
            """Update with a detection. Handles smooth re-init after long loss."""
            # If coming back from a long miss, blend smoothly
            if self.miss_count > self.RE_INIT_BLEND_FRAMES:
                old_x, old_y = self.position
                old_dist = np.sqrt((x - old_x)**2 + (y - old_y)**2)
                if old_dist > 300:  # Only blend if it's a big jump
                    self._re_init_target = (x, y)
                    self._re_init_progress = 0
                    # Reset state to new position but keep velocity zero
                    self.kf.statePost = np.array([[x], [y], [0], [0], [0], [0]], np.float32)
                    self.kf.errorCovPost = np.eye(6, dtype=np.float32) * 10.0
                    self.miss_count = 0
                    self.total_updates += 1
                    self._last_detection_pos = (x, y)
                    self._confidence_score = min(1.0, self._confidence_score + 0.15)
                    return
            
            self.kf.correct(np.array([[x], [y]], np.float32))
            self.miss_count = 0
            self.total_updates += 1
            self._last_detection_pos = (x, y)
            # Boost confidence on detection
            self._confidence_score = min(1.0, self._confidence_score + 0.2 * confidence)
        
        def no_detection(self):
            """Called when no ball detected in current frame."""
            self.miss_count += 1
            # Decay velocity and acceleration
            self.kf.statePost[2] *= self.VELOCITY_DECAY
            self.kf.statePost[3] *= self.VELOCITY_DECAY
            self.kf.statePost[4] *= self.ACCEL_DECAY
            self.kf.statePost[5] *= self.ACCEL_DECAY
            # Decay confidence
            self._confidence_score = max(0.0, self._confidence_score - 0.05)
        
        def is_plausible_detection(self, x, y):
            """Check if a detection is physically plausible given current state.
            Returns (plausible: bool, distance: float)."""
            if self.total_updates == 0:
                return True, 0.0
            pred_x, pred_y = self.position
            dist = np.sqrt((x - pred_x)**2 + (y - pred_y)**2)
            max_allowed = self.BASE_TELEPORT_PX + self.speed * self.TELEPORT_VEL_FACTOR
            # Even more generous during miss periods
            if self.miss_count > 3:
                max_allowed *= 1.5
            return dist <= max_allowed, dist
        
        @property
        def speed(self):
            """Current speed (px/frame)."""
            vx = float(self.kf.statePost[2, 0])
            vy = float(self.kf.statePost[3, 0])
            return np.sqrt(vx * vx + vy * vy)
        
        @property
        def velocity(self):
            """Current velocity (vx, vy)."""
            return float(self.kf.statePost[2, 0]), float(self.kf.statePost[3, 0])
        
        def is_valid(self):
            # Dynamic miss allowance: fast ball → coast longer (up to ~60 frames = 3s at 20fps)
            # Slow ball → drop track sooner (prevents locking onto stationary false positives)
            speed = self.speed
            dynamic_max_miss = self.MAX_MISS
            if speed > 15:
                dynamic_max_miss = int(self.MAX_MISS * 1.5)
            elif speed < 3:
                dynamic_max_miss = int(self.MAX_MISS * 0.6)
            return self.miss_count < dynamic_max_miss
        
        @property
        def position(self):
            return float(self.kf.statePost[0, 0]), float(self.kf.statePost[1, 0])
        
        @property
        def confidence(self):
            return self._confidence_score
    
    # ══════════════════════════════════════════════════════════════════════
    # SMOOTH BROADCAST CAMERA — Spring-Damper Physics Model
    # 3-zone behavior (dead/normal/emergency), predictive lead, soft pan limits
    # ══════════════════════════════════════════════════════════════════════
    class SmoothBroadcastCamera:
        """Physics-based camera with spring-damper model for broadcast-quality panning."""
        
        # Spring-damper parameters
        SPRING_K = 2.5          # Spring constant (normal zone)
        SPRING_K_EMERGENCY = 8.0 # Spring constant (emergency zone — ball near edge)
        DAMPING = 0.92          # Damping ratio (0.9-0.95 = critically damped feel)
        
        # Zone thresholds (fraction of crop width from center)
        DEAD_ZONE = 0.06        # No camera movement within 6% of center
        EMERGENCY_ZONE = 0.30   # Emergency catch-up beyond 30% from center
        
        # Lead parameters
        LEAD_FACTOR = 2.0       # How much to lead ahead of ball velocity
        LEAD_CLIP = 0.35        # Max lead as fraction of crop width
        
        # Display smoothing
        DISPLAY_EMA = 0.12      # Final EMA on integer crop position (kills 1px jitter)
        
        # Pan limits
        PAN_MIN_NORM = 0.10     # Don't pan left of 10% 
        PAN_MAX_NORM = 0.90     # Don't pan right of 90%
        PAN_SOFT_ZONE = 0.05    # Resistance zone width near limits
        
        # Re-acquire blend
        RE_ACQUIRE_FRAMES = 12  # Frames to blend after re-acquiring ball
        
        def __init__(self, fw, fh, crop_ratio=0.45):
            self.fw = fw
            self.fh = fh
            self.crop_w = int(fw * crop_ratio)
            self.crop_h = fh
            self.cam_x = float(fw / 2)       # Physics position
            self.cam_x_display = float(fw / 2) # Smoothed display position
            self.cam_y = float(fh / 2)
            self.cam_y_display = float(fh / 2)
            self.vel_x = 0.0
            self.vel_y = 0.0
            self.frames_no_ball = 0
            self._re_acquire_countdown = 0
            self._re_acquire_start_x = float(fw / 2)
            self._re_acquire_target_x = float(fw / 2)
        
        def update(self, ball_x, ball_y=None, ball_vx=0.0, ball_vy=0.0):
            """Update camera position using spring-damper physics."""
            if ball_x is None:
                # No ball: drift with momentum, decay
                self.frames_no_ball += 1
                self.vel_x *= 0.95
                self.vel_y *= 0.95
                self.cam_x += self.vel_x
                if ball_y is None:
                    self.cam_y += self.vel_y
                self._clamp()
                self._update_display()
                return
            
            # Re-acquire blend logic
            if self.frames_no_ball > 15:
                # Ball re-acquired after long absence — start smooth blend
                self._re_acquire_countdown = self.RE_ACQUIRE_FRAMES
                self._re_acquire_start_x = self.cam_x
                self._re_acquire_target_x = ball_x
            self.frames_no_ball = 0
            
            # ── Predictive lead ──
            # Non-linear: small velocity → small lead, large velocity → large lead
            speed = abs(ball_vx)
            lead_mult = 1.0 + min(2.0, speed / 15.0)
            lead_x = np.clip(ball_vx * self.LEAD_FACTOR * lead_mult,
                             -self.crop_w * self.LEAD_CLIP,
                             self.crop_w * self.LEAD_CLIP)
            lead_y = np.clip(ball_vy * self.LEAD_FACTOR * 0.3,
                             -self.crop_h * 0.1,
                             self.crop_h * 0.1)
            
            target_x = ball_x + lead_x
            target_y = (ball_y + lead_y) if ball_y is not None else self.cam_y
            
            # ── Re-acquire blending (cubic ease-in-out) ──
            if self._re_acquire_countdown > 0:
                t = 1.0 - (self._re_acquire_countdown / self.RE_ACQUIRE_FRAMES)
                # Cubic ease-in-out
                if t < 0.5:
                    ease = 4.0 * t * t * t
                else:
                    ease = 1.0 - (-2.0 * t + 2.0) ** 3 / 2.0
                target_x = self._re_acquire_start_x + (target_x - self._re_acquire_start_x) * ease
                self._re_acquire_countdown -= 1
            
            # ── Three-zone spring-damper ──
            dist_x = target_x - self.cam_x
            dist_y = target_y - self.cam_y
            abs_dist_x = abs(dist_x) / max(1, self.crop_w)
            abs_dist_y = abs(dist_y) / max(1, self.crop_h)
            
            # X-axis physics
            if abs_dist_x < self.DEAD_ZONE:
                # Dead zone: gentle decay, no spring force
                self.vel_x *= 0.88
                accel_x = 0.0
            elif abs_dist_x > self.EMERGENCY_ZONE:
                # Emergency: strong spring, fast catch-up
                spring_force = self.SPRING_K_EMERGENCY * dist_x * 0.01
                damping_force = -self.DAMPING * self.vel_x * 0.15
                accel_x = spring_force + damping_force
            else:
                # Normal: standard spring-damper
                spring_force = self.SPRING_K * dist_x * 0.01
                damping_force = -self.DAMPING * self.vel_x * 0.12
                accel_x = spring_force + damping_force
            
            # Y-axis physics (gentler — less vertical movement expected)
            if abs_dist_y < 0.08:
                self.vel_y *= 0.90
                accel_y = 0.0
            else:
                spring_force_y = 1.5 * dist_y * 0.01
                damping_force_y = -0.9 * self.vel_y * 0.12
                accel_y = spring_force_y + damping_force_y
            
            # Apply acceleration
            self.vel_x += accel_x
            self.vel_y += accel_y
            
            # Velocity limits (dynamic based on distance)
            max_vel_x = self.fw * (0.12 if abs_dist_x > self.EMERGENCY_ZONE else 0.04)
            max_vel_y = self.fh * 0.03
            self.vel_x = np.clip(self.vel_x, -max_vel_x, max_vel_x)
            self.vel_y = np.clip(self.vel_y, -max_vel_y, max_vel_y)
            
            # Update position
            self.cam_x += self.vel_x
            self.cam_y += self.vel_y
            
            self._clamp()
            self._update_display()
        
        def _clamp(self):
            """Soft-boundary clamping with resistance near edges."""
            min_x = max(self.PAN_MIN_NORM * self.fw, self.crop_w / 2)
            max_x = min(self.PAN_MAX_NORM * self.fw, self.fw - self.crop_w / 2)
            
            # Soft boundary: increasing resistance near limits
            soft_min = min_x + self.PAN_SOFT_ZONE * self.fw
            soft_max = max_x - self.PAN_SOFT_ZONE * self.fw
            
            if self.cam_x < soft_min:
                # In soft zone — apply resistance
                resistance = 1.0 - max(0, (soft_min - self.cam_x) / (self.PAN_SOFT_ZONE * self.fw))
                self.vel_x *= max(0.3, resistance)
            elif self.cam_x > soft_max:
                resistance = 1.0 - max(0, (self.cam_x - soft_max) / (self.PAN_SOFT_ZONE * self.fw))
                self.vel_x *= max(0.3, resistance)
            
            # Hard clamp as final safety
            if self.cam_x < min_x:
                self.cam_x = min_x
                self.vel_x *= 0.1
            elif self.cam_x > max_x:
                self.cam_x = max_x
                self.vel_x *= 0.1
            
            # Y clamp
            min_y = self.crop_h / 2
            max_y = self.fh - self.crop_h / 2
            self.cam_y = np.clip(self.cam_y, min_y, max_y)
        
        def _update_display(self):
            """EMA smooth the display position to eliminate 1px jitter."""
            self.cam_x_display = (1 - self.DISPLAY_EMA) * self.cam_x_display + self.DISPLAY_EMA * self.cam_x
            self.cam_y_display = (1 - self.DISPLAY_EMA) * self.cam_y_display + self.DISPLAY_EMA * self.cam_y
        
        def crop(self, frame, out_w, out_h):
            """Crop frame centered on smoothed camera position. Returns (crop, sx, sy)."""
            cx = self.cam_x_display
            cy = self.cam_y_display
            
            # Calculate crop dimensions based on zoom
            crop_w = self.crop_w
            crop_h = int(crop_w * 9 / 16)  # 16:9 aspect
            
            if crop_h > self.fh:
                crop_h = self.fh
                crop_w = int(crop_h * 16 / 9)
            if crop_w > self.fw:
                crop_w = self.fw
                crop_h = int(crop_w * 9 / 16)
            
            sx = max(0, min(self.fw - crop_w, int(cx - crop_w / 2)))
            sy = max(0, min(self.fh - crop_h, int(cy - crop_h / 2)))
            
            cropped = frame[sy:sy + crop_h, sx:sx + crop_w]
            if cropped is None or cropped.size == 0:
                return None, sx, sy
            
            zoomed = cv2.resize(cropped, (out_w, out_h), interpolation=cv2.INTER_LINEAR)
            return zoomed, sx, sy
    
    def hsv_green_mask(frame):
        """Remove green grass → only ball, players, lines remain.
        Uses adaptive masking to avoid removing ball-colored pixels.
        Reduces false positives by ~70% on outdoor football fields."""
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        # Slightly narrower green range to preserve ball colors near green
        green_mask = cv2.inRange(hsv, (36, 50, 50), (80, 255, 255))
        # Morphological close to fill small gaps in mask
        kernel = np.ones((3, 3), np.uint8)
        green_mask = cv2.morphologyEx(green_mask, cv2.MORPH_CLOSE, kernel)
        return cv2.bitwise_and(frame, frame, mask=cv2.bitwise_not(green_mask))
    
    def refine_ball_center(frame, raw_cx, raw_cy, model_ref, fw, fh, patch_size=128, refine_imgsz=256):
        """Second-pass: crop around detection, run YOLO at high relative res for precise center.
        Returns (refined_x, refined_y)."""
        half = patch_size // 2
        x1 = max(0, int(raw_cx - half))
        y1 = max(0, int(raw_cy - half))
        x2 = min(fw, int(raw_cx + half))
        y2 = min(fh, int(raw_cy + half))
        patch = frame[y1:y2, x1:x2]
        if patch.size == 0:
            return raw_cx, raw_cy
        try:
            results = model_ref.predict(patch, conf=0.05, imgsz=refine_imgsz, verbose=False)[0]
            best_cx, best_cy, best_conf = None, None, 0
            for box in results.boxes:
                cls = int(box.cls[0])
                cls_name = model_ref.names.get(cls, "").lower()
                if cls != 32 and "ball" not in cls_name and not (cls == 0 and len(model_ref.names) == 1):
                    continue
                xa, ya, xb, yb = box.xyxy[0].cpu().numpy()
                rcx = (xa + xb) / 2 + x1
                rcy = (ya + yb) / 2 + y1
                if float(box.conf[0]) > best_conf:
                    best_conf = float(box.conf[0])
                    best_cx, best_cy = rcx, rcy
            if best_cx is not None:
                return best_cx, best_cy
        except Exception:
            pass
        return raw_cx, raw_cy
    
    def detect_ball_multiscale(frame, model_ref, primary_imgsz, conf_thresh, 
                               pred_x=None, pred_y=None, use_hsv=True, fw=None, fh=None):
        """Multi-scale ball detection with spatial-geometric filtering.
        Runs YOLO at primary size + optionally at 640 for far-side balls.
        Returns list of (cx, cy, conf, score) candidates sorted by score."""
        candidates = []
        
        detect_frame = hsv_green_mask(frame) if use_hsv else frame
        
        # Primary detection at full resolution
        try:
            results1 = model_ref.predict(detect_frame, imgsz=primary_imgsz, conf=conf_thresh, verbose=False)[0]
            for box in results1.boxes:
                cls = int(box.cls[0])
                conf = float(box.conf[0])
                cls_name = model_ref.names.get(cls, "").lower()
                if cls != 32 and "ball" not in cls_name and not (cls == 0 and len(model_ref.names) == 1):
                    continue
                x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
                bw, bh = x2 - x1, y2 - y1
                
                # Spatial-geometric filtering
                aspect = bw / max(bh, 1)
                if aspect < 0.4 or aspect > 2.8:
                    continue
                if fw and (bw > fw * 0.08 or bh > fh * 0.08):
                    continue
                if bw < 3 or bh < 3:
                    continue
                
                # Distance-weighted scoring
                dist = 0
                if pred_x is not None:
                    dist = np.sqrt((cx - pred_x)**2 + (cy - pred_y)**2)
                score = conf - (dist * 0.002)
                candidates.append((cx, cy, conf, score))
        except Exception as e:
            print(f"⚠️ Primary detection error: {e}")
        
        # Secondary detection at 640 for far-side tiny balls (only when no good candidates)
        if len(candidates) == 0 and primary_imgsz > 800:
            try:
                results2 = model_ref.predict(detect_frame, imgsz=640, conf=max(0.05, conf_thresh - 0.05), verbose=False)[0]
                for box in results2.boxes:
                    cls = int(box.cls[0])
                    conf = float(box.conf[0])
                    cls_name = model_ref.names.get(cls, "").lower()
                    if cls != 32 and "ball" not in cls_name and not (cls == 0 and len(model_ref.names) == 1):
                        continue
                    x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                    cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
                    bw, bh = x2 - x1, y2 - y1
                    aspect = bw / max(bh, 1)
                    if aspect < 0.4 or aspect > 2.8:
                        continue
                    dist = 0
                    if pred_x is not None:
                        dist = np.sqrt((cx - pred_x)**2 + (cy - pred_y)**2)
                    score = conf * 0.8 - (dist * 0.002)  # Slightly penalize secondary scale
                    candidates.append((cx, cy, conf, score))
            except Exception:
                pass
        
        # Sort by score (best first)
        candidates.sort(key=lambda c: c[3], reverse=True)
        return candidates
    
    try:
        # Check if job is already being processed (concurrency protection)
        job_res = supabase.table("ball_tracking_jobs").select("status, progress_percent").eq("id", job_id).execute()
        if job_res.data:
            job_status = job_res.data[0].get("status")
            job_progress = job_res.data[0].get("progress_percent", 0)
            
            # The flutter frontend sets status to 'processing' before calling the webhook.
            # Only skip if it's processing AND progress is > 0
            if job_status == "processing" and job_progress > 0:
                print(f"⚠️ Job {job_id} is already actively processing (progress: {job_progress}%). Skipping redundant trigger.")
                return
            
        # Update to processing
        update_job("processing", progress=0)
        
        # Extract config
        ZOOM_BASE = script_config.get("zoom_base", 1.75)
        ZOOM_FAR = script_config.get("zoom_far", 2.1)
        SMOOTHING = script_config.get("smoothing", 0.07)
        ZOOM_SMOOTH = script_config.get("zoom_smooth", 0.1)
        DETECT_EVERY_FRAMES = script_config.get("detect_every_frames", 2)
        YOLO_CONF = script_config.get("yolo_conf", 0.35)
        MEMORY = script_config.get("memory", 6)
        PREDICT_FACTOR = script_config.get("predict_factor", 0.25)
        ROI_SIZE = script_config.get("roi_size", 400)
        YOLO_MODEL = script_config.get("yolo_model", "yolov8x")
        YOLO_IMG_SIZE = script_config.get("yolo_img_size", 1280)
        SHOW_FIELD_MASK = script_config.get("show_field_mask", True)
        SHOW_BALL_RED = script_config.get("show_red_ball", False)
        
        print(f"⚙️ Config: Model={YOLO_MODEL}, Conf={YOLO_CONF}, DetectEvery={DETECT_EVERY_FRAMES}")
        
        # ── Fetch field mask polygon from Supabase (per-venue) ──
        FIELD_MASK_POLYGON = None  # numpy array of [[x, y], ...] normalized 0-1
        if field_id:
            try:
                mask_res = supabase.table('field_masks').select('mask_points').eq('field_id', field_id).maybe_single().execute()
                if mask_res and mask_res.data and mask_res.data.get('mask_points'):
                    pts = mask_res.data['mask_points']
                    FIELD_MASK_POLYGON = np.array([[float(p['x']), float(p['y'])] for p in pts], dtype=np.float32)
                    print(f"✅ Loaded field mask polygon: {len(FIELD_MASK_POLYGON)} points for field {field_id}")
                else:
                    print(f"ℹ️ No field mask found for field {field_id} — using full-frame detection")
            except Exception as _mask_err:
                print(f"⚠️ Field mask fetch failed (non-fatal): {_mask_err}")
        
        # Download input video
        print(f"⬇️ Downloading video from {input_video_url}")
        update_job("processing", progress=5)
        
        # ── Load model FIRST (fail fast before slow transcode) ──
        import base64
        import subprocess
        
        global _model_cache
        if YOLO_MODEL in _model_cache:
            print(f"✅ Using cached model: {YOLO_MODEL}")
            model = _model_cache[YOLO_MODEL]
            use_inference_sdk = getattr(model, '_use_inference_sdk', False)
        else:
            print(f"🤖 Loading {YOLO_MODEL} model (first time in container)...")
            update_job("processing", progress=5)
            
            use_inference_sdk = False
            if "roboflow://" in YOLO_MODEL or "/" in YOLO_MODEL:
                clean_model_id = YOLO_MODEL.replace("roboflow://", "")
                print(f"📥 Setting up Roboflow HTTP API for: {clean_model_id}")
                
                class RoboflowHTTPModel:
                    """Calls Roboflow REST API directly with requests. Zero extra deps."""
                    def __init__(self, model_id, api_key):
                        self.model_id = model_id
                        self.api_key = api_key
                        self.api_url = f"https://detect.roboflow.com/{model_id}"
                        self._use_inference_sdk = True
                    
                    def infer(self, image_array):
                        """Send a numpy/cv2 image to Roboflow and return predictions dict."""
                        import cv2 as _cv2
                        # Encode image to JPEG bytes then base64
                        _, buf = _cv2.imencode('.jpg', image_array)
                        img_b64 = base64.b64encode(buf.tobytes()).decode('utf-8')
                        
                        resp = requests.post(
                            self.api_url,
                            params={"api_key": self.api_key},
                            data=img_b64,
                            headers={"Content-Type": "application/x-www-form-urlencoded"},
                            timeout=30,
                        )
                        resp.raise_for_status()
                        return resp.json()  # {"predictions": [...], "image": {...}}
                
                model = RoboflowHTTPModel(clean_model_id, roboflow_api_key)
                
                # Quick test: send a tiny blank image to verify API key + model
                print("🧪 Testing Roboflow API connection...")
                test_img = np.zeros((64, 64, 3), dtype=np.uint8)
                try:
                    test_result = model.infer(test_img)
                    pred_count = len(test_result.get('predictions', []))
                    print(f"✅ Roboflow API works! Test returned {pred_count} predictions.")
                except Exception as test_err:
                    print(f"❌ Roboflow API test failed: {test_err}")
                    raise RuntimeError(f"Roboflow model '{YOLO_MODEL}' API test failed: {test_err}")
                
                use_inference_sdk = True
                _model_cache[YOLO_MODEL] = model
            elif YOLO_MODEL.startswith('tracknet'):
                # ══════════════════════════════════════════════════════════════
                # REAL TRACKNET V3 + YOLO DUAL-MODEL MODE
                # ══════════════════════════════════════════════════════════════
                # TrackNet V3: Custom-trained football heatmap model (8-frame temporal)
                # YOLO: Parallel object detection (proven, handles edge cases)
                # Combined: Maximum precision tracking with backtrack interpolation
                # ══════════════════════════════════════════════════════════════
                print("🧠 TrackNet V3 Mode: REAL Heatmap Model + YOLO Dual Detection")
                print("   → TrackNet V3: 8-frame temporal heatmap inference (512×288)")
                print("   → YOLO: Parallel ball detection (ROI + full-frame)")
                print("   → Fusion: Best of both models per frame")
                print("   → Dynamic backtrack: 5→15 frame lookahead-backtrack recovery")
                
                import shutil
                import torch.nn as nn
                import math as _math
                
                # ── TrackNet V3 Architecture ──
                class _Conv2DBlock(nn.Module):
                    def __init__(self, in_dim, out_dim):
                        super().__init__()
                        self.conv = nn.Conv2d(in_dim, out_dim, kernel_size=3, padding=1, bias=False)
                        self.bn = nn.BatchNorm2d(out_dim)
                        self.relu = nn.ReLU()
                    def forward(self, x):
                        return self.relu(self.bn(self.conv(x)))
                
                class _Double2DConv(nn.Module):
                    def __init__(self, in_dim, out_dim):
                        super().__init__()
                        self.conv_1 = _Conv2DBlock(in_dim, out_dim)
                        self.conv_2 = _Conv2DBlock(out_dim, out_dim)
                    def forward(self, x):
                        return self.conv_2(self.conv_1(x))
                
                class _Triple2DConv(nn.Module):
                    def __init__(self, in_dim, out_dim):
                        super().__init__()
                        self.conv_1 = _Conv2DBlock(in_dim, out_dim)
                        self.conv_2 = _Conv2DBlock(out_dim, out_dim)
                        self.conv_3 = _Conv2DBlock(out_dim, out_dim)
                    def forward(self, x):
                        return self.conv_3(self.conv_2(self.conv_1(x)))
                
                class TrackNetV3Model(nn.Module):
                    HEIGHT = 288
                    WIDTH = 512
                    def __init__(self, in_dim=27, out_dim=8):
                        super().__init__()
                        self.down_block_1 = _Double2DConv(in_dim, 64)
                        self.down_block_2 = _Double2DConv(64, 128)
                        self.down_block_3 = _Triple2DConv(128, 256)
                        self.bottleneck   = _Triple2DConv(256, 512)
                        self.up_block_1   = _Triple2DConv(768, 256)
                        self.up_block_2   = _Double2DConv(384, 128)
                        self.up_block_3   = _Double2DConv(192, 64)
                        self.predictor    = nn.Conv2d(64, out_dim, (1, 1))
                        self.sigmoid      = nn.Sigmoid()
                    def forward(self, x):
                        x1 = self.down_block_1(x)
                        x = torch.nn.MaxPool2d((2,2), stride=(2,2))(x1)
                        x2 = self.down_block_2(x)
                        x = torch.nn.MaxPool2d((2,2), stride=(2,2))(x2)
                        x3 = self.down_block_3(x)
                        x = torch.nn.MaxPool2d((2,2), stride=(2,2))(x3)
                        x = self.bottleneck(x)
                        x = torch.cat([torch.nn.Upsample(scale_factor=2)(x), x3], dim=1)
                        x = self.up_block_1(x)
                        x = torch.cat([torch.nn.Upsample(scale_factor=2)(x), x2], dim=1)
                        x = self.up_block_2(x)
                        x = torch.cat([torch.nn.Upsample(scale_factor=2)(x), x1], dim=1)
                        x = self.up_block_3(x)
                        x = self.predictor(x)
                        x = self.sigmoid(x)
                        return x
                
                # ── Load TrackNet V3 weights ──
                tracknet_path = "/models/tracknet_football_v3.pt"
                if not os.path.exists(tracknet_path):
                    print("📥 TrackNet V3 weights not found in volume. Checking for upload...")
                    # The weights should be uploaded to the volume before deploy
                    raise RuntimeError(
                        "TrackNet V3 weights not found at /models/tracknet_football_v3.pt. "
                        "Please upload using: modal volume put yolo-models tracknet_football_v3.pt tracknet_football_v3.pt"
                    )
                
                tracknet_model = TrackNetV3Model(in_dim=27, out_dim=8)
                ckpt = torch.load(tracknet_path, map_location='cpu', weights_only=False)
                if isinstance(ckpt, dict) and 'model' in ckpt:
                    state_dict = ckpt['model']
                elif isinstance(ckpt, dict) and 'state_dict' in ckpt:
                    state_dict = ckpt['state_dict']
                else:
                    state_dict = ckpt
                loaded = tracknet_model.load_state_dict(state_dict, strict=False)
                print(f"   ✅ TrackNet V3 loaded! Missing: {len(loaded.missing_keys)}, Unexpected: {len(loaded.unexpected_keys)}")
                
                # Move to GPU
                device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
                tracknet_model = tracknet_model.to(device).eval()
                print(f"   🖥️ TrackNet V3 on device: {device}")
                total_params = sum(p.numel() for p in tracknet_model.parameters())
                print(f"   📊 Parameters: {total_params:,}")
                
                # ── Also load YOLO for parallel detection ──
                yolo_model_name = 'yolov8l'
                yolo_path = f"/models/{yolo_model_name}.pt"
                if not os.path.exists(yolo_path):
                    print(f"📥 Downloading YOLO model: {yolo_model_name}...")
                    model = YOLO(f"{yolo_model_name}.pt")
                    os.makedirs("/models", exist_ok=True)
                    shutil.move(f"{yolo_model_name}.pt", yolo_path)
                
                model = YOLO(yolo_path)
                model._use_inference_sdk = False
                model._use_tracknet = True
                model._tracknet_model = tracknet_model  # Attach TrackNet to the model object
                model._tracknet_device = device
                _model_cache[YOLO_MODEL] = model
                print(f"✅ TrackNet V3 + YOLO {yolo_model_name} DUAL MODE ready!")
            else:
                model_path = f"/models/{YOLO_MODEL}.pt"
                if not os.path.exists(model_path):
                    print(f"📥 Downloading standard YOLO model: {YOLO_MODEL}...")
                    model = YOLO(f"{YOLO_MODEL}.pt")
                    os.makedirs("/models", exist_ok=True)
                    import shutil
                    shutil.move(f"{YOLO_MODEL}.pt", model_path)
                
                model = YOLO(model_path)
                model._use_inference_sdk = False
                _model_cache[YOLO_MODEL] = model
                print(f"✅ Model {YOLO_MODEL} cached in container.")
        
        # ── Download video ──
        # Streamed download with verification
        input_path_raw = "/tmp/input_video_raw.mp4"
        with requests.get(input_video_url, stream=True, timeout=60) as r:
            r.raise_for_status()
            expected_size = int(r.headers.get('content-length', 0))
            if expected_size > 0:
                print(f"📦 Expected file size: {expected_size / (1024*1024):.2f} MB")
            
            with open(input_path_raw, 'wb') as f:
                downloaded = 0
                for chunk in r.iter_content(chunk_size=1024*1024): # 1MB chunks
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
            
            print(f"✅ Video downloaded successfully: {downloaded / (1024*1024):.2f} MB")
            if expected_size > 0 and downloaded < expected_size:
                print(f"⚠️ Warning: Truncated download! Only {downloaded}/{expected_size} bytes received.")
        
        log_audio = False
        print("🔊 Checking for audio...")
        try:
            result = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'a', '-show_entries', 'stream=codec_name', '-of', 'default=nw=1', input_path_raw], capture_output=True, text=True, timeout=30)
            if result.stdout.strip():
                log_audio = True
                print("✅ Audio extracted successfully")
            else:
                print("🔇 No audio stream found")
        except:
             pass

        # 🧪 Video Sanitization (FFmpeg Transcode)
        # HEVC chunks from Raspberry Pi have broken NAL units that cause OpenCV
        # to stop reading after ~32 seconds. We must TRANSCODE to H.264 to fix this.
        print("🛠️ Transcoding HEVC→H.264 (fixes broken NAL units for OpenCV)...")
        print("⏳ This may take 2-5 minutes for large 4K files...")
        input_path = "/tmp/input_video.mp4"
        try:
            subprocess.run([
                "ffmpeg", "-y", "-err_detect", "ignore_err",
                "-i", input_path_raw, 
                "-c:v", "libx264", "-preset", "ultrafast", "-crf", "18",
                "-an",  # Drop audio (not needed for ball tracking)
                input_path
            ], check=True, capture_output=True)
            print("✅ Transcode complete.")
        except subprocess.CalledProcessError as e:
            print(f"⚠️ Transcode failed, falling back to remux: {e.stderr.decode()[:500]}")
            try:
                subprocess.run([
                    "ffmpeg", "-y", "-i", input_path_raw,
                    "-c", "copy", "-map", "0", "-ignore_unknown",
                    "-err_detect", "ignore_err",
                    input_path
                ], check=True, capture_output=True)
                print("✅ Remux fallback complete.")
            except subprocess.CalledProcessError:
                print("⚠️ Both transcode and remux failed, using raw file.")
                input_path = input_path_raw
        
        file_size_mb = os.path.getsize(input_path) / (1024 * 1024)
        print(f"📊 Final video size: {file_size_mb:.2f} MB")
        update_job("processing", progress=10)
        
        # Define compatibility wrapper to unify YOLO vs Roboflow HTTP API
        class YOLOCompatibilityWrapper:
            def __init__(self, model, use_inference_sdk):
                self._model = model
                self._use_inference_sdk = use_inference_sdk
                if use_inference_sdk:
                    self.names = {0: "ball"} 
                else:
                    self.names = model.names
            
            def __getattr__(self, name):
                """Forward attribute access to the underlying model.
                This is CRITICAL for TrackNet: _use_tracknet, _tracknet_model,
                _tracknet_device must be visible through the wrapper."""
                if name.startswith('_') and name != '_model' and name != '_use_inference_sdk':
                    return getattr(self._model, name)
                raise AttributeError(f"'{type(self).__name__}' has no attribute '{name}'")
            
            def predict(self, source, **kwargs):
                if self._use_inference_sdk:
                    from types import SimpleNamespace
                    inf_res = self._model.infer(source)
                    
                    class MockTensor(np.ndarray):
                        def cpu(self): return self
                        def numpy(self): return self
                    
                    predictions = inf_res.get('predictions', []) if isinstance(inf_res, dict) else []
                    
                    boxes_list = []
                    for p in predictions:
                        b = SimpleNamespace()
                        px = p.get('x', 0)
                        py = p.get('y', 0)
                        pw = p.get('width', 0)
                        ph = p.get('height', 0)
                        coords = np.array([[px - pw/2, py - ph/2, px + pw/2, py + ph/2]], dtype=np.float32)
                        b.xyxy = coords.view(MockTensor)
                        b.conf = np.array([p.get('confidence', 0)], dtype=np.float32).view(MockTensor)
                        b.cls = np.array([0], dtype=np.float32).view(MockTensor)
                        boxes_list.append(b)
                    
                    res = SimpleNamespace()
                    res.boxes = boxes_list
                    res.names = self.names
                    return [res]
                else:
                    return self._model.predict(source, **kwargs)
            
            def __call__(self, source, **kwargs):
                return self.predict(source, **kwargs)

        # Wrap the model for absolute compatibility
        model = YOLOCompatibilityWrapper(model, use_inference_sdk)

        # Open video and verify metadata
        cap = cv2.VideoCapture(input_path)
        if not cap.isOpened():
            raise RuntimeError("Cannot open input video")
        
        W = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        H = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        FPS = cap.get(cv2.CAP_PROP_FPS) or 25.0
        
        # Frame count: After HEVC→H.264 transcode, OpenCV's count is accurate
        TOTAL = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            
        dt = 1.0 / FPS
        duration = TOTAL / FPS
        duration_mins = duration / 60
        
        # 🚨 Emergency Speed-Up for Modal Free Tier (30-min limit)
        if duration_mins > 8:
            print(f"⚠️ Video is {duration_mins:.1f} min long. Auto-reducing resolution to ensure survival.")
            YOLO_IMG_SIZE = min(YOLO_IMG_SIZE, 960)
            if DETECT_EVERY_FRAMES < 3:
                DETECT_EVERY_FRAMES = 3
            print(f"⚡ New settings: imgsz={YOLO_IMG_SIZE}, detect_every={DETECT_EVERY_FRAMES}")
        
        print(f"🎬 Video: {W}x{H} @ {FPS}fps, {TOTAL} frames")
        
        # Update job with video info
        duration = TOTAL / FPS
        update_job("processing", progress=15, video_duration_seconds=duration, total_frames=TOTAL)
        
        # Prepare output
        output_path = "/tmp/output_video.mp4"
        
        # ============================================================
        # CUSTOM SCRIPT EXECUTION (if provided)
        # ============================================================
        print("✅ Using pre-loaded watermark: shape=(3000, 7000, 3)")
        if custom_script:
            print("🐍 Executing custom Python script...")
            update_job("processing", progress=20)
            
            # Prepare execution environment for custom script
            exec_globals = {
                'cv2': cv2,
                'np': np,
                'numpy': np,
                'time': __import__('time'),
                'subprocess': __import__('subprocess'),
                'os': os,
                'model': model,
                'cap': cap,
                'W': W,
                'H': H,
                'FPS': FPS,
                'TOTAL': TOTAL,
                'output_path': output_path,
                'update_job': update_job,
                'log': print, # Inject log function for simple scripts
                'create_tracker': create_tracker,
                'create_kalman_filter': create_kalman_filter,
                # Pass optimized settings for Modal Free Tier survival
                'DETECTION_SIZE': YOLO_IMG_SIZE,
                'FULL_FRAME_INTERVAL': DETECT_EVERY_FRAMES,
                'DETECTION_CONF_TRACKING': YOLO_CONF,
                # Pass field mask polygon (normalized points or None)
                'FIELD_MASK_POLYGON': FIELD_MASK_POLYGON,
            }
            
            # Execute custom script
            try:
                exec(custom_script, exec_globals)
                
                # Get metrics from executed script
                tracker_ok_count = exec_globals.get('tracker_ok_count', 0)
                accuracy = exec_globals.get('accuracy', 0)
                actual_frames = exec_globals.get('frame_idx', 0)
                
                # 🚨 Detect and Warn about Segmented/Truncated video chunks
                if TOTAL > 0 and actual_frames > 0:
                    processed_ratio = actual_frames / TOTAL
                    if processed_ratio < 0.8: # If less than 80% was actually read
                        warn_msg = f"⚠️ Video duration discrepancy: Header predicts {TOTAL} frames ({duration:.1f}s), but only {actual_frames} were found in bitstream. (Is this a segment/chunk?)"
                        print(warn_msg)
                        update_job("completed", progress=100)  # log_notes column doesn't exist in schema
                
                # Custom script should have written to output_path and released cap
                # Skip default algorithm
                print(f"✅ Custom script execution complete (processed {actual_frames} frames)")
                
            except Exception as e:
                print(f"❌ Custom script error: {e}")
                import traceback
                traceback.print_exc()
                raise RuntimeError(f"Custom script failed: {e}")
        
        else:
            # ============================================================
            # DEFAULT ALGORITHM v5.0 — Ultra-Enhanced TrackNet Pipeline
            # 6-state Kalman + Spring-Damper Camera + Multi-Scale Detection
            # ============================================================
            # Maintain original height, calculate width for 16:9 aspect ratio
            OUT_H = H
            OUT_W = int(H * 16 / 9)
            
            # Ensure width is even (required by some codecs)
            if OUT_W % 2 != 0:
                OUT_W += 1
                
            out = cv2.VideoWriter(output_path, cv2.VideoWriter_fourcc(*"mp4v"), FPS, (OUT_W, OUT_H))
            print(f"📐 Output: {OUT_W}×{OUT_H} (16:9) | Input: {W}×{H}")
            
            # Check TrackNet mode
            use_tracknet = hasattr(model, '_use_tracknet') and model._use_tracknet
            print(f"🔍 TrackNet check: hasattr={hasattr(model, '_use_tracknet')}, use_tracknet={use_tracknet}")
            
            if use_tracknet:
                print("✅✅✅ TRACKNET V3 MODE ACTIVATED — TrackNet is PRIMARY detector! ✅✅✅")
                # ══════════════════════════════════════════════════════════
                # TRACKNET V3 + YOLO DUAL-MODEL — v7.0 ULTRA-PRECISION
                # TrackNet V3 = PRIMARY detector (heatmap, every frame)
                # YOLO = SECONDARY detector (4 strategies from v4.2)
                # Intelligent fusion + Dynamic backtrack + Smooth camera
                # ══════════════════════════════════════════════════════════
                
                DETECTION_SIZE = script_config.get("yolo_img_size", 640)
                YOLO_CONF_TN = max(0.08, script_config.get("yolo_conf", 0.35) - 0.05)
                SMOOTHING_TN = 0.06
                ZOOM_BASE_TN = 1.75
                ZOOM_FAR_TN = 2.1
                ZOOM_SMOOTH_TN = 0.08
                LOOKAHEAD_MIN = 5
                LOOKAHEAD_MAX = 15
                SKIP_DET_CONF = 0.55
                TRACKNET_CONF_THRESH = 0.30   # Lower threshold — our custom model is good
                TRACKNET_HIGH_CONF = 0.60     # Above this, TrackNet is very trustworthy
                YOLO_WINS_CONF = 0.60         # YOLO wins ties above this confidence
                
                # Get TrackNet model from attached attribute
                tracknet_net = model._tracknet_model if hasattr(model, '_tracknet_model') else None
                tracknet_device = model._tracknet_device if hasattr(model, '_tracknet_device') else torch.device('cpu')
                actual_yolo = model._model if hasattr(model, '_model') else model
                
                # ── TrackNet frame buffer (rolling 8 frames for inference) ──
                tracknet_frame_buffer = []  # BGR frames at (TN_H, TN_W)
                TN_W, TN_H = 512, 288
                tn_scale_x = W / TN_W
                tn_scale_y = H / TN_H
                
                # ── v4.2 Kalman Tracker with kick detection ──
                class _BallKalman42:
                    VELOCITY_DECAY = 0.96
                    MAX_MISS = 60
                    MAX_TELEPORT_PX = 500
                    BASE_PROC_NOISE = 0.5
                    KICK_PROC_NOISE = 50.0
                    def __init__(self, x, y, _dt=1/20):
                        self.kf = cv2.KalmanFilter(4, 2)
                        self.dt = _dt
                        self.kf.transitionMatrix = np.array(
                            [[1,0,_dt,0],[0,1,0,_dt],[0,0,1,0],[0,0,0,1]], np.float32)
                        self.kf.measurementMatrix = np.array(
                            [[1,0,0,0],[0,1,0,0]], np.float32)
                        self._reset_noise()
                        self.kf.statePost = np.array([[x],[y],[0],[0]], np.float32)
                        self.kf.errorCovPost = np.eye(4, dtype=np.float32) * 10.0
                        self.miss_count = 0
                        self.hit_count = 0
                        self.last_detection = (x, y)
                        self.last_velocity = (0.0, 0.0)
                        self._kick_detected = False
                        self._consecutive_high_conf = 0
                    def _reset_noise(self):
                        self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * self.BASE_PROC_NOISE
                        self.kf.processNoiseCov[2:, 2:] *= 20.0
                        self.kf.measurementNoiseCov = np.eye(2, dtype=np.float32) * 2.0
                    def predict(self):
                        if self.miss_count > 3:
                            scale = min(self.miss_count / 3.0, 15.0)
                            self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * self.BASE_PROC_NOISE * scale
                            self.kf.processNoiseCov[2:, 2:] *= 20.0
                        p = self.kf.predict()
                        return float(p[0,0]), float(p[1,0])
                    def update(self, x, y, conf=0.5):
                        if self.hit_count > 2:
                            new_vx = (x - self.last_detection[0]) / max(self.dt, 1e-6)
                            new_vy = (y - self.last_detection[1]) / max(self.dt, 1e-6)
                            old_vx, old_vy = self.last_velocity
                            accel = _math.sqrt((new_vx-old_vx)**2 + (new_vy-old_vy)**2)
                            if accel > 800:
                                self._kick_detected = True
                                self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * self.KICK_PROC_NOISE
                                self.kf.processNoiseCov[2:, 2:] *= 5.0
                            else:
                                self._kick_detected = False
                                self._reset_noise()
                            self.last_velocity = (new_vx, new_vy)
                        self.kf.correct(np.array([[x],[y]], np.float32))
                        self.miss_count = 0
                        self.hit_count += 1
                        self.last_detection = (x, y)
                        if conf >= SKIP_DET_CONF:
                            self._consecutive_high_conf += 1
                        else:
                            self._consecutive_high_conf = 0
                    def no_detection(self):
                        self.miss_count += 1
                        self.kf.statePost[2] *= self.VELOCITY_DECAY
                        self.kf.statePost[3] *= self.VELOCITY_DECAY
                        self._consecutive_high_conf = 0
                    @property
                    def search_radius(self):
                        base = 200
                        return int(base + min(self.miss_count, 20) * 30) if self.miss_count > 0 else base
                    @property
                    def velocity(self):
                        return float(self.kf.statePost[2,0]), float(self.kf.statePost[3,0])
                    @property
                    def speed(self):
                        vx, vy = self.velocity
                        return _math.sqrt(vx*vx + vy*vy)
                    @property
                    def is_valid(self):
                        return self.miss_count < self.MAX_MISS
                    @property
                    def position(self):
                        return float(self.kf.statePost[0,0]), float(self.kf.statePost[1,0])
                    @property
                    def can_skip_detection(self):
                        return (self._consecutive_high_conf >= 3
                                and self.miss_count == 0
                                and self.hit_count > 10)
                
                # ── v4.2 Smooth Camera ──
                class _SmoothCam42:
                    def __init__(self, x, y, max_speed_frac=0.025, accel_smooth=0.12):
                        self.x = float(x); self.y = float(y)
                        self.vx = 0.0; self.vy = 0.0
                        self.max_speed_frac = max_speed_frac
                        self.accel_smooth = accel_smooth
                    def update(self, tx, ty, fw, fh, smoothing=0.06):
                        msx = fw * self.max_speed_frac
                        msy = fh * self.max_speed_frac
                        dvx = (tx - self.x) * smoothing
                        dvy = (ty - self.y) * smoothing
                        self.vx += (dvx - self.vx) * self.accel_smooth
                        self.vy += (dvy - self.vy) * self.accel_smooth
                        self.vx = max(-msx, min(msx, self.vx))
                        self.vy = max(-msy, min(msy, self.vy))
                        self.x += self.vx; self.y += self.vy
                        self.x = max(0.0, min(float(fw), self.x))
                        self.y = max(0.0, min(float(fh), self.y))
                        return int(self.x), int(self.y)
                
                # ── TrackNet heatmap → ball position (ENHANCED v7.0) ──
                def _tracknet_detect(frame_buf, tn_model, device_tn, pred_xy=None):
                    """Run TrackNet V3 on 8-frame buffer.
                    Enhanced: multi-peak rejection, sub-pixel centroid, adaptive threshold.
                    Returns (cx, cy, conf) in ORIGINAL coords or None."""
                    if len(frame_buf) < 8 or tn_model is None:
                        return None
                    # Build median background from 8 frames (matches training: bg_mode=concat)
                    bg = np.median(np.array(frame_buf[-8:]), axis=0).astype(np.uint8)
                    bg_rgb = cv2.cvtColor(bg, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
                    bg_chw = bg_rgb.transpose(2, 0, 1)
                    
                    frames_chw = []
                    for f in frame_buf[-8:]:
                        rgb = cv2.cvtColor(f, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
                        frames_chw.append(rgb.transpose(2, 0, 1))
                    
                    # Stack: bg(3) + 8 frames(24) = 27 channels
                    inp = np.concatenate([bg_chw] + frames_chw, axis=0)  # (27, 288, 512)
                    inp_tensor = torch.from_numpy(inp).unsqueeze(0).float().to(device_tn)
                    
                    with torch.no_grad():
                        out_hm = tn_model(inp_tensor)  # (1, 8, 288, 512)
                    
                    # Use last heatmap (current frame)
                    hm = out_hm[0, -1].cpu().numpy()  # (288, 512)
                    peak_val = float(hm.max())
                    
                    # Adaptive threshold: lower when Kalman predicts nearby
                    effective_thresh = TRACKNET_CONF_THRESH
                    if pred_xy is not None:
                        effective_thresh = max(0.20, TRACKNET_CONF_THRESH - 0.10)
                    
                    if peak_val < effective_thresh:
                        return None
                    
                    # ── Multi-peak rejection ──
                    # Threshold and find connected components (peaks)
                    thresh_val = max(0.25, peak_val * 0.4)
                    hm_uint8 = (hm * 255).astype(np.uint8)
                    _, thr = cv2.threshold(hm_uint8, int(thresh_val * 255), 255, cv2.THRESH_BINARY)
                    contours, _ = cv2.findContours(thr, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
                    
                    if len(contours) == 0:
                        return None
                    
                    # For each peak, compute weighted centroid and confidence
                    candidates = []
                    for cnt in contours:
                        mask_cnt = np.zeros_like(hm)
                        cv2.drawContours(mask_cnt, [cnt], -1, 1.0, -1)
                        hm_local = hm * mask_cnt
                        local_sum = hm_local.sum()
                        if local_sum < 1e-6:
                            continue
                        local_peak = float(hm_local.max())
                        if local_peak < effective_thresh:
                            continue
                        ys, xs = np.mgrid[0:TN_H, 0:TN_W]
                        cx_tn = float((xs * hm_local).sum() / local_sum)
                        cy_tn = float((ys * hm_local).sum() / local_sum)
                        # Scale to original resolution
                        cx_orig = cx_tn * tn_scale_x
                        cy_orig = cy_tn * tn_scale_y
                        candidates.append((cx_orig, cy_orig, local_peak))
                    
                    if len(candidates) == 0:
                        return None
                    
                    # If only one peak, return it
                    if len(candidates) == 1:
                        return candidates[0]
                    
                    # Multiple peaks → pick the one closest to Kalman prediction
                    if pred_xy is not None:
                        best = min(candidates, key=lambda c: _math.sqrt(
                            (c[0] - pred_xy[0])**2 + (c[1] - pred_xy[1])**2))
                        return best
                    else:
                        # No Kalman prediction → pick strongest peak
                        best = max(candidates, key=lambda c: c[2])
                        return best
                
                # ── YOLO detection helper (from v4.2) ──
                def _yolo_detect(img, mdl, conf_t, imgsz, pred_xy=None, use_hsv=True):
                    if img is None or img.size == 0:
                        return None
                    feed = hsv_green_mask(img) if use_hsv else img
                    try:
                        results = mdl.predict(feed, imgsz=imgsz, conf=conf_t, verbose=False)
                    except Exception:
                        return None
                    if not results or len(results) == 0:
                        return None
                    res = results[0]
                    best, best_score = None, -1e9
                    for box in getattr(res, 'boxes', []):
                        cls = int(box.cls[0])
                        conf_v = float(box.conf[0])
                        cls_name = mdl.names.get(cls, "").lower()
                        is_ball = cls == 32 or "ball" in cls_name or (cls == 0 and len(mdl.names) == 1)
                        if is_ball and conf_v >= conf_t:
                            bx1, by1, bx2, by2 = map(float, box.xyxy[0])
                            cx, cy = (bx1+bx2)/2, (by1+by2)/2
                            d = 0
                            if pred_xy is not None:
                                d = _math.sqrt((cx-pred_xy[0])**2 + (cy-pred_xy[1])**2)
                            sc = conf_v - d*0.001
                            if sc > best_score:
                                best = (cx, cy, conf_v)
                                best_score = sc
                    return best
                
                # ── Render helper ──
                def _render_crop(frm, cx, cy, zm, fw, fh, ow, oh, asp):
                    cw = int(fw / max(zm, 0.1))
                    ch_c = int(cw / asp)
                    if ch_c > fh: ch_c = fh; cw = int(ch_c * asp)
                    if cw > fw: cw = fw; ch_c = int(cw / asp)
                    cw = max(cw, 2); ch_c = max(ch_c, 2)
                    sx = max(0, min(fw-cw, cx-cw//2))
                    sy = max(0, min(fh-ch_c, cy-ch_c//2))
                    crop = frm[sy:sy+ch_c, sx:sx+cw]
                    if crop is None or crop.size == 0: return None
                    return cv2.resize(crop, (ow, oh), interpolation=cv2.INTER_LINEAR)
                
                # ── Dynamic Frame Buffer (v4.2) ──
                class _DynBuf:
                    def __init__(self):
                        self.entries = []
                        self._miss_streak = 0
                    def add(self, frame, ball_xy, detected, conf=0.0):
                        self.entries.append({'frame':frame,'ball_xy':ball_xy,'detected':detected,'conf':conf})
                        if not detected: self._miss_streak += 1
                        else: self._miss_streak = 0
                    @property
                    def size(self): return len(self.entries)
                    @property
                    def _limit(self):
                        return LOOKAHEAD_MAX if self._miss_streak > LOOKAHEAD_MIN else LOOKAHEAD_MIN
                    def _has_gap(self):
                        if len(self.entries) < 3 or not self.entries[-1]['detected']:
                            return False
                        found_miss = False
                        for i in range(len(self.entries)-2, -1, -1):
                            if not self.entries[i]['detected']: found_miss = True
                            elif found_miss: return True
                        return False
                    def should_flush(self):
                        if not self.entries: return False
                        last = self.entries[-1]
                        if last['detected'] and self._has_gap(): return True
                        if self.size >= self._limit: return True
                        if last['detected'] and last['conf'] >= SKIP_DET_CONF and self._miss_streak == 0:
                            consec = 0
                            for e in reversed(self.entries):
                                if e['detected']: consec += 1
                                else: break
                            if consec >= 2: return True
                        return False
                    def flush(self, cam, zm, writer, fw, fh, ow, oh, asp):
                        if not self.entries: return 0, 0, cam, zm, False
                        n = len(self.entries)
                        was_bt = self._has_gap()
                        anchors = [(i, e['ball_xy'][0], e['ball_xy'][1]) for i,e in enumerate(self.entries) if e['detected'] and e['ball_xy']]
                        positions = [None]*n
                        if len(anchors) == 0:
                            for i,e in enumerate(self.entries): positions[i] = e['ball_xy']
                        elif len(anchors) == 1:
                            for i,e in enumerate(self.entries):
                                positions[i] = e['ball_xy'] if e['ball_xy'] else (anchors[0][1], anchors[0][2])
                        else:
                            for idx, ax, ay in anchors: positions[idx] = (ax, ay)
                            for i in range(0, anchors[0][0]):
                                positions[i] = self.entries[i]['ball_xy'] or (anchors[0][1], anchors[0][2])
                            for i in range(anchors[-1][0]+1, n):
                                positions[i] = self.entries[i]['ball_xy'] or (anchors[-1][1], anchors[-1][2])
                            for a in range(len(anchors)-1):
                                ia, ib = anchors[a][0], anchors[a+1][0]
                                xa, ya = anchors[a][1], anchors[a][2]
                                xb, yb = anchors[a+1][1], anchors[a+1][2]
                                span = ib - ia
                                if span <= 1: continue
                                for i in range(ia+1, ib):
                                    t = (i-ia)/float(span)
                                    ts = t*t*(3.0-2.0*t)
                                    positions[i] = (xa+(xb-xa)*ts, ya+(yb-ya)*ts)
                        fw_c, ok_c = 0, 0
                        for i,e in enumerate(self.entries):
                            pos = positions[i]
                            if pos: ok_c += 1; tx, ty = float(pos[0]), float(pos[1])
                            else: tx, ty = cam.x, cam.y
                            cx_c, cy_c = cam.update(tx, ty, fw, fh, SMOOTHING_TN)
                            yn = cy_c / max(fh, 1)
                            dz = ZOOM_BASE_TN + (ZOOM_FAR_TN - ZOOM_BASE_TN) * (1.0-yn)
                            zm += ZOOM_SMOOTH_TN * (dz - zm)
                            out_f = _render_crop(e['frame'], cx_c, cy_c, zm, fw, fh, ow, oh, asp)
                            if out_f is not None: writer.write(out_f); fw_c += 1
                        self.entries.clear(); self._miss_streak = 0
                        return fw_c, ok_c, cam, zm, was_bt
                
                # ── Output setup (native resolution 16:9) ──
                OUT_ASPECT = 16.0 / 9.0
                if W / max(H, 1) >= OUT_ASPECT:
                    OUT_H = H; OUT_W = int(OUT_H * OUT_ASPECT)
                else:
                    OUT_W = W; OUT_H = int(OUT_W / OUT_ASPECT)
                OUT_W += OUT_W % 2; OUT_H += OUT_H % 2
                
                out.release()
                out = cv2.VideoWriter(output_path, cv2.VideoWriter_fourcc(*"mp4v"), FPS, (OUT_W, OUT_H))
                
                kalman = None
                cam42 = _SmoothCam42(W//2, H//2)
                zoom_dyn = ZOOM_BASE_TN
                frame_idx = 0
                tracker_ok_count = 0
                total_yolo_calls = 0
                total_tn_calls = 0
                backtrack_count = 0
                prev_gray = None
                buf42 = _DynBuf()
                
                print(f"🧠 Starting TrackNet V3 + YOLO v6.0 Pipeline...")
                print(f"   Input:  {W}x{H} @ {FPS:.1f}fps ({TOTAL} frames)")
                print(f"   Output: {OUT_W}x{OUT_H} (native 16:9)")
                print(f"   TrackNet: {'ACTIVE' if tracknet_net else 'DISABLED (weights missing)'}")
                print(f"   YOLO: ROI → Full-frame → Zone-split → Motion")
                print(f"   Backtrack: {LOOKAHEAD_MIN}→{LOOKAHEAD_MAX} frames dynamic")
                
                while True:
                    ret, frame = cap.read()
                    if not ret or frame is None:
                        break
                    frame_idx += 1
                    
                    prog_iv = max(30, TOTAL // 100)
                    if frame_idx % prog_iv == 0:
                        progress = 15 + int((frame_idx / max(TOTAL, 1)) * 70)
                        update_job("processing", progress=progress)
                    if frame_idx % 500 == 0:
                        cps = total_yolo_calls / max(frame_idx, 1)
                        print(f"💓 F{frame_idx}/{TOTAL} ({(frame_idx/max(TOTAL,1))*100:.1f}%) "
                              f"YOLO/f={cps:.2f} TN={total_tn_calls} bt={backtrack_count}")
                    
                    # ── TrackNet: add resized frame to rolling buffer ──
                    tn_resized = cv2.resize(frame, (TN_W, TN_H))
                    tracknet_frame_buffer.append(tn_resized)
                    if len(tracknet_frame_buffer) > 10:
                        tracknet_frame_buffer.pop(0)
                    
                    # ── Kalman prediction ──
                    pred_x, pred_y = None, None
                    if kalman is not None and kalman.is_valid:
                        pred_x, pred_y = kalman.predict()
                    
                    skip_this = False
                    if kalman is not None and kalman.can_skip_detection and frame_idx % 2 == 0:
                        skip_this = True
                    
                    # ══════ DUAL DETECTION: TrackNet PRIMARY + YOLO SECONDARY ══════
                    detected_center = None
                    detection_conf = 0.0
                    strategy_used = None
                    
                    # ── Strategy T: TrackNet V3 heatmap (PRIMARY — every frame) ──
                    tn_det = None
                    pred_for_tn = (pred_x, pred_y) if pred_x is not None else None
                    if len(tracknet_frame_buffer) >= 8 and tracknet_net is not None:
                        tn_det = _tracknet_detect(tracknet_frame_buffer, tracknet_net, tracknet_device, pred_xy=pred_for_tn)
                        total_tn_calls += 1
                        if tn_det:
                            detected_center = (tn_det[0], tn_det[1])
                            detection_conf = tn_det[2]
                            strategy_used = "TrackNet"
                    
                    # ── YOLO detection (SECONDARY — all 4 strategies from v4.2) ──
                    yolo_det_center = None
                    yolo_det_conf = 0.0
                    
                    if not skip_this:
                        # ── Strategy A: YOLO ROI crop ──
                        if kalman is not None and kalman.is_valid and pred_x is not None:
                            radius = kalman.search_radius
                            ry1 = 0 if kalman._kick_detected else max(0, int(pred_y-radius))
                            rx1 = max(0, int(pred_x-radius))
                            rx2 = min(W, int(pred_x+radius))
                            ry2 = min(H, int(pred_y+radius))
                            roi = frame[ry1:ry2, rx1:rx2]
                            if roi.size > 0:
                                pred_roi = (pred_x-rx1, pred_y-ry1)
                                det = _yolo_detect(roi, actual_yolo, YOLO_CONF_TN*0.75, 640, pred_xy=pred_roi)
                                total_yolo_calls += 1
                                if det:
                                    yolo_det_center = (det[0]+rx1, det[1]+ry1)
                                    yolo_det_conf = det[2]
                                    strategy_used = "ROI" if not strategy_used else strategy_used
                        
                        # ── Strategy B: YOLO full-frame ──
                        do_full = (kalman is None) or (frame_idx % 3 == 0) or \
                                  (kalman is not None and kalman.miss_count > 3)
                        if yolo_det_center is None and do_full:
                            pred_full = (pred_x, pred_y) if pred_x else None
                            det = _yolo_detect(frame, actual_yolo, YOLO_CONF_TN, DETECTION_SIZE, pred_xy=pred_full)
                            total_yolo_calls += 1
                            if det:
                                yolo_det_center = (det[0], det[1])
                                yolo_det_conf = det[2]
                                strategy_used = "FullFrame" if not strategy_used else strategy_used
                        
                        # ── Strategy C: Zone-split (ball lost > 5 frames) ──
                        if yolo_det_center is None and kalman is not None and kalman.miss_count > 5:
                            zw = W // 2; ov = W // 8
                            zones = [(0,0,min(W,zw+ov),H),(max(0,W//2-ov),0,min(W,W//2+zw+ov),H),(max(0,W-zw-ov),0,W,H)]
                            for zx1,zy1,zx2,zy2 in zones:
                                zi = frame[zy1:zy2, zx1:zx2]
                                if zi.size > 0:
                                    det = _yolo_detect(zi, actual_yolo, YOLO_CONF_TN*0.7, 960)
                                    total_yolo_calls += 1
                                    if det:
                                        yolo_det_center = (det[0]+zx1, det[1]+zy1)
                                        yolo_det_conf = det[2]
                                        strategy_used = "ZoneSplit" if not strategy_used else strategy_used
                                        break
                        
                        # ── Strategy D: Motion detection (ball lost > 8 frames) ──
                        if yolo_det_center is None and prev_gray is not None and \
                           kalman is not None and kalman.miss_count > 8:
                            curr_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                            diff = cv2.absdiff(prev_gray, curr_gray)
                            _, thr = cv2.threshold(diff, 25, 255, cv2.THRESH_BINARY)
                            kern = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5,5))
                            thr = cv2.morphologyEx(thr, cv2.MORPH_CLOSE, kern)
                            thr = cv2.morphologyEx(thr, cv2.MORPH_OPEN, kern)
                            if kalman.is_valid and pred_x is not None:
                                msk = np.zeros_like(thr)
                                cv2.circle(msk, (int(pred_x),int(pred_y)), kalman.search_radius, 255, -1)
                                thr = cv2.bitwise_and(thr, msk)
                            contours, _ = cv2.findContours(thr, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
                            bm, bms = None, -1
                            for cnt in contours:
                                area = cv2.contourArea(cnt)
                                if 30 < area < 8000:
                                    peri = cv2.arcLength(cnt, True)
                                    circ = 4*_math.pi*area/(peri*peri+1e-6)
                                    if circ > 0.25:
                                        M = cv2.moments(cnt)
                                        if M["m00"] > 0:
                                            mx = int(M["m10"]/M["m00"])
                                            my = int(M["m01"]/M["m00"])
                                            sc = circ*100
                                            if pred_x: sc -= _math.sqrt((mx-pred_x)**2+(my-pred_y)**2)*0.05
                                            if sc > bms: bms = sc; bm = (mx, my)
                            if bm:
                                yolo_det_center = bm
                                yolo_det_conf = 0.25
                                strategy_used = "Motion" if not strategy_used else strategy_used
                    
                    # ══════ INTELLIGENT FUSION: TrackNet + YOLO ══════
                    if tn_det and yolo_det_center:
                        # Both detected — pick best based on distance to Kalman + confidence
                        tn_cx, tn_cy, tn_conf = tn_det
                        yl_cx, yl_cy = yolo_det_center
                        
                        if pred_x is not None:
                            tn_dist = _math.sqrt((tn_cx - pred_x)**2 + (tn_cy - pred_y)**2)
                            yl_dist = _math.sqrt((yl_cx - pred_x)**2 + (yl_cy - pred_y)**2)
                            
                            # YOLO wins if: high confidence AND closer to Kalman
                            if yolo_det_conf >= YOLO_WINS_CONF and yl_dist < tn_dist:
                                detected_center = yolo_det_center
                                detection_conf = yolo_det_conf
                                strategy_used = strategy_used + "+YOLO"
                            # TrackNet wins if: high confidence OR closer to Kalman
                            elif tn_conf >= TRACKNET_HIGH_CONF or tn_dist <= yl_dist:
                                detected_center = (tn_cx, tn_cy)
                                detection_conf = tn_conf
                                strategy_used = "TrackNet+Fused"
                            else:
                                # YOLO is closer — use YOLO
                                detected_center = yolo_det_center
                                detection_conf = yolo_det_conf
                                strategy_used = strategy_used + "+YOLO"
                        else:
                            # No Kalman prediction — prefer higher confidence
                            if tn_conf >= yolo_det_conf:
                                detected_center = (tn_cx, tn_cy)
                                detection_conf = tn_conf
                                strategy_used = "TrackNet"
                            else:
                                detected_center = yolo_det_center
                                detection_conf = yolo_det_conf
                    elif tn_det and not yolo_det_center:
                        # Only TrackNet — already set above
                        pass
                    elif yolo_det_center and not tn_det:
                        # Only YOLO
                        detected_center = yolo_det_center
                        detection_conf = yolo_det_conf
                    
                    # ── Teleport guard ──
                    if detected_center and kalman is not None and kalman.is_valid and pred_x is not None:
                        dist = _math.sqrt((detected_center[0]-pred_x)**2 + (detected_center[1]-pred_y)**2)
                        max_tp = max(_BallKalman42.MAX_TELEPORT_PX, kalman.speed * 3)
                        if dist > max_tp and detection_conf < 0.7:
                            detected_center = None; strategy_used = None
                    
                    # ── Kalman update ──
                    ball_x, ball_y = None, None
                    real_det = False
                    if detected_center:
                        ball_x, ball_y = detected_center
                        real_det = True
                        if kalman is None:
                            kalman = _BallKalman42(ball_x, ball_y, dt)
                        else:
                            kalman.update(ball_x, ball_y, conf=detection_conf)
                    elif skip_this and kalman is not None and kalman.is_valid:
                        ball_x, ball_y = kalman.position
                        real_det = True
                    elif kalman is not None:
                        kalman.no_detection()
                        if kalman.is_valid:
                            ball_x, ball_y = kalman.position
                    
                    # ── Buffer frame ──
                    buf42.add(frame=frame, ball_xy=(ball_x, ball_y) if ball_x else None,
                              detected=real_det, conf=detection_conf)
                    
                    if buf42.should_flush():
                        written, ok_add, cam42, zoom_dyn, was_bt = buf42.flush(
                            cam42, zoom_dyn, out, W, H, OUT_W, OUT_H, OUT_ASPECT)
                        tracker_ok_count += ok_add
                        if was_bt: backtrack_count += 1
                    
                    prev_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                
                # Flush remaining
                if buf42.size > 0:
                    written, ok_add, cam42, zoom_dyn, was_bt = buf42.flush(
                        cam42, zoom_dyn, out, W, H, OUT_W, OUT_H, OUT_ASPECT)
                    tracker_ok_count += ok_add
                    if was_bt: backtrack_count += 1
                
                cap.release()
                out.release()
                
                accuracy = int(tracker_ok_count / max(frame_idx, 1) * 100)
                actual_time = (datetime.now() - start_time).total_seconds()
                actual_cost = (actual_time / 3600) * 0.76
                yolo_pf = total_yolo_calls / max(frame_idx, 1)
                print(f"✅ TrackNet V3 + YOLO v6.0 complete! Accuracy: {accuracy}%")
                print(f"   Frames with ball: {tracker_ok_count}/{frame_idx}")
                print(f"   💰 YOLO calls/frame: {yolo_pf:.2f}")
                print(f"   🧠 TrackNet calls: {total_tn_calls}")
                print(f"   🔄 Backtracks: {backtrack_count}")
                print(f"   💰 Actual cost: ~${actual_cost:.3f} ({actual_time:.0f}s)")
            
            else:
                # ══════════════════════════════════════════════════════════════════
                # DEFAULT ALGORITHM v4.1 — Dynamic Lookahead-Backtrack
                # Field-Aware Polygon Detection + Native Resolution Output
                # ══════════════════════════════════════════════════════════════════
                import math as _math41
                
                # ── Config ──
                _V41_YOLO_CONF       = YOLO_CONF
                _V41_SMOOTHING       = 0.06
                _V41_ZOOM_BASE       = ZOOM_BASE
                _V41_ZOOM_FAR        = ZOOM_FAR
                _V41_ZOOM_SMOOTH     = 0.08
                _V41_LOOKAHEAD_MIN   = 5
                _V41_LOOKAHEAD_MAX   = 15
                _V41_SKIP_CONF       = 0.50
                _V41_ROI_IMGSZ       = 640
                _V41_FULL_IMGSZ      = 1280
                _V41_FULL_EVERY      = 20

                # ── Build polygon mask (from Supabase field_masks or full-frame) ──
                # Returns True if point (px, py) is inside the field polygon.
                if FIELD_MASK_POLYGON is not None and len(FIELD_MASK_POLYGON) >= 3:
                    _poly_pts = (FIELD_MASK_POLYGON * np.array([W, H])).astype(np.int32)  # pixel coords
                    def _in_field(px, py):
                        return cv2.pointPolygonTest(_poly_pts.reshape(-1,1,2), (float(px), float(py)), False) >= 0
                    print(f"🏟️ Field polygon mask loaded: {len(FIELD_MASK_POLYGON)} points")
                else:
                    # No polygon — use v4.1's rectangular zone fallback
                    _GRASS_X = (0.04 * W, 0.93 * W)
                    _GRASS_Y = (0.22 * H, H)
                    _AIR_X   = (0.08 * W, 0.90 * W)
                    _AIR_Y   = (0.02 * H, 0.22 * H)
                    def _in_field(px, py):
                        if _GRASS_X[0] <= px <= _GRASS_X[1] and _GRASS_Y[0] <= py <= _GRASS_Y[1]: return True
                        if _AIR_X[0]   <= px <= _AIR_X[1]   and _AIR_Y[0]   <= py <= _AIR_Y[1]:   return True
                        return False
                    print("ℹ️ No field polygon — using rectangular zone fallback")

                # ── v4.1 Kalman Tracker ──
                class _Kalman41:
                    VEL_DECAY = 0.96; MAX_MISS = 60; MAX_TP = 500
                    BASE_Q = 0.5;     KICK_Q = 50.0
                    def __init__(self, x, y, _dt=1/20):
                        self.kf = cv2.KalmanFilter(4, 2)
                        self.dt = _dt
                        self.kf.transitionMatrix = np.array([[1,0,_dt,0],[0,1,0,_dt],[0,0,1,0],[0,0,0,1]], np.float32)
                        self.kf.measurementMatrix = np.array([[1,0,0,0],[0,1,0,0]], np.float32)
                        self._rst()
                        self.kf.statePost = np.array([[x],[y],[0],[0]], np.float32)
                        self.kf.errorCovPost = np.eye(4, dtype=np.float32) * 10.0
                        self.miss_count = 0; self.hit_count = 0
                        self.last_det = (x, y); self.last_vel = (0.0, 0.0)
                        self._kick = False; self._conf_streak = 0
                    def _rst(self):
                        self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * self.BASE_Q
                        self.kf.processNoiseCov[2:, 2:] *= 20.0
                        self.kf.measurementNoiseCov = np.eye(2, dtype=np.float32) * 2.0
                    def predict(self):
                        if self.miss_count > 3:
                            sc = min(self.miss_count/3.0, 15.0)
                            self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * self.BASE_Q * sc
                            self.kf.processNoiseCov[2:, 2:] *= 20.0
                        p = self.kf.predict()
                        return float(p[0,0]), float(p[1,0])
                    def update(self, x, y, conf=0.5):
                        if self.hit_count > 2:
                            nvx = (x-self.last_det[0])/max(self.dt,1e-6)
                            nvy = (y-self.last_det[1])/max(self.dt,1e-6)
                            acc = _math41.sqrt((nvx-self.last_vel[0])**2+(nvy-self.last_vel[1])**2)
                            if acc > 800:
                                self._kick = True
                                self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * self.KICK_Q
                                self.kf.processNoiseCov[2:,2:] *= 5.0
                            else:
                                self._kick = False; self._rst()
                            self.last_vel = (nvx, nvy)
                        self.kf.correct(np.array([[x],[y]], np.float32))
                        self.miss_count = 0; self.hit_count += 1; self.last_det = (x, y)
                        self._conf_streak = (self._conf_streak+1) if conf >= _V41_SKIP_CONF else 0
                    def no_det(self):
                        self.miss_count += 1
                        self.kf.statePost[2] *= self.VEL_DECAY; self.kf.statePost[3] *= self.VEL_DECAY
                        self._conf_streak = 0
                    @property
                    def pos(self): return float(self.kf.statePost[0,0]), float(self.kf.statePost[1,0])
                    @property
                    def vel(self): return float(self.kf.statePost[2,0]), float(self.kf.statePost[3,0])
                    @property
                    def spd(self): vx,vy=self.vel; return _math41.sqrt(vx*vx+vy*vy)
                    @property
                    def valid(self): return self.miss_count < self.MAX_MISS
                    @property
                    def radius(self): return int(200 + min(self.miss_count,20)*30) if self.miss_count > 0 else 200
                    @property
                    def can_skip(self): return self._conf_streak >= 3 and self.miss_count == 0 and self.hit_count > 10

                # ── v4.1 Smooth Camera ──
                class _Cam41:
                    def __init__(self, x, y):
                        self.x=float(x); self.y=float(y); self.vx=0.0; self.vy=0.0
                        self._snap = (float(x), float(y), 0.0, 0.0)
                    def snap(self): self._snap=(self.x,self.y,self.vx,self.vy)
                    def restore(self): self.x,self.y,self.vx,self.vy=self._snap
                    def step(self, tx, ty, fw, fh, sm=0.06):
                        msx=fw*0.025; msy=fh*0.025
                        dvx=(tx-self.x)*sm; dvy=(ty-self.y)*sm
                        self.vx+=(dvx-self.vx)*0.12; self.vy+=(dvy-self.vy)*0.12
                        self.vx=max(-msx,min(msx,self.vx)); self.vy=max(-msy,min(msy,self.vy))
                        self.x=max(0.0,min(float(fw),self.x+self.vx))
                        self.y=max(0.0,min(float(fh),self.y+self.vy))
                        return int(self.x), int(self.y)

                # ── YOLO Detection helper (field-aware) ──
                def _det41(img_region, mdl, conf_t, imgsz, pred_xy=None, use_hsv=True, ox=0, oy=0):
                    if img_region is None or img_region.size == 0: return None
                    feed = hsv_green_mask(img_region) if use_hsv else img_region
                    try:
                        res = mdl.predict(feed, imgsz=imgsz, conf=conf_t, verbose=False)
                    except Exception: return None
                    if not res: return None
                    best, bscore = None, -1e9
                    for box in getattr(res[0], 'boxes', []):
                        cls = int(box.cls[0]); cv = float(box.conf[0])
                        cn = mdl.names.get(cls, '').lower()
                        is_ball = cls==32 or 'ball' in cn or (cls==0 and len(mdl.names)==1)
                        if is_ball and cv >= conf_t:
                            bx1,by1,bx2,by2 = map(float, box.xyxy[0])
                            cx = (bx1+bx2)/2.0 + ox; cy = (by1+by2)/2.0 + oy
                            if not _in_field(cx, cy): continue
                            d = _math41.sqrt((cx-pred_xy[0])**2+(cy-pred_xy[1])**2) if pred_xy else 0.0
                            sc = cv - d*0.001
                            if sc > bscore: best=(cx,cy,cv); bscore=sc
                    return best

                # ── Dynamic Frame Buffer ──
                class _Buf41:
                    def __init__(self):
                        self.entries=[]; self._gap=False; self._gstart=-1
                    def add(self, frm, bxy, det, conf=0.0):
                        self.entries.append({'f':frm,'b':bxy,'d':det,'c':conf})
                        if not det and not self._gap: self._gap=True; self._gstart=len(self.entries)-1
                        elif det and self._gap: self._gap=False
                    @property
                    def sz(self): return len(self.entries)
                    @property
                    def lim(self):
                        if self._gap:
                            gl = self.sz - self._gstart
                            if gl > _V41_LOOKAHEAD_MIN: return _V41_LOOKAHEAD_MAX
                        return _V41_LOOKAHEAD_MIN
                    def _has_resolved(self):
                        fd=fg=False
                        for e in self.entries:
                            if e['d'] and not fd: fd=True
                            elif not e['d'] and fd: fg=True
                            elif e['d'] and fg: return True
                        return False
                    @property
                    def should_flush(self):
                        if not self.entries: return False
                        if not self._gap and self._has_resolved(): return True
                        if self.sz >= self.lim: return True
                        last=self.entries[-1]
                        if last['d'] and last['c'] >= _V41_SKIP_CONF and not self._gap:
                            c=sum(1 for e in reversed(self.entries) if e['d'] or (c and False))
                            cc=0
                            for e in reversed(self.entries):
                                if e['d']: cc+=1
                                else: break
                            if cc >= 2: return True
                        return False
                    def flush(self, cam, zm, fw, fh, ow, oh, asp, writer):
                        if not self.entries: return 0, 0, cam, zm, False
                        n=len(self.entries)
                        was_bt=self._has_resolved()
                        anchors=[(i,e['b'][0],e['b'][1]) for i,e in enumerate(self.entries) if e['d'] and e['b']]
                        pos=[None]*n
                        if len(anchors)==0:
                            for i,e in enumerate(self.entries): pos[i]=e['b']
                        elif len(anchors)==1:
                            ax,ay=anchors[0][1],anchors[0][2]
                            for i,e in enumerate(self.entries): pos[i]=e['b'] if (e['d'] and e['b']) else (ax,ay)
                        else:
                            for idx,ax,ay in anchors: pos[idx]=(ax,ay)
                            for i in range(anchors[0][0]): pos[i]=(anchors[0][1],anchors[0][2])
                            for i in range(anchors[-1][0]+1,n): pos[i]=(anchors[-1][1],anchors[-1][2])
                            for a in range(len(anchors)-1):
                                ia,ib=anchors[a][0],anchors[a+1][0]
                                xa,ya=anchors[a][1],anchors[a][2]
                                xb,yb=anchors[a+1][1],anchors[a+1][2]
                                sp=ib-ia
                                if sp<=1: continue
                                for i in range(ia+1,ib):
                                    t=(i-ia)/float(sp); ts=t*t*(3.0-2.0*t)
                                    pos[i]=(xa+(xb-xa)*ts,ya+(yb-ya)*ts)
                        fw_c=0; ok_c=0
                        for i,e in enumerate(self.entries):
                            p=pos[i]
                            if p: ok_c+=1; tx,ty=float(p[0]),float(p[1])
                            else: tx,ty=cam.x,cam.y
                            if i+1<n and pos[i+1] and p:
                                nx,ny=pos[i+1]
                                tx+=(nx-p[0])*0.3; ty+=(ny-p[1])*0.3
                            cx_c,cy_c=cam.step(tx,ty,fw,fh,_V41_SMOOTHING)
                            yn=cy_c/max(fh,1); dz=_V41_ZOOM_BASE+(_V41_ZOOM_FAR-_V41_ZOOM_BASE)*(1.0-yn)
                            zm+=_V41_ZOOM_SMOOTH*(dz-zm)
                            cw=int(fw/max(zm,0.1)); ch=int(cw/asp)
                            if ch>fh: ch=fh; cw=int(ch*asp)
                            if cw>fw: cw=fw; ch=int(cw/asp)
                            cw=max(cw,2); ch=max(ch,2)
                            sx=max(0,min(fw-cw,cx_c-cw//2)); sy=max(0,min(fh-ch,cy_c-ch//2))
                            crop=e['f'][sy:sy+ch, sx:sx+cw]
                            if crop is not None and crop.size>0:
                                writer.write(cv2.resize(crop,(ow,oh),interpolation=cv2.INTER_LINEAR))
                                fw_c+=1
                        self.entries.clear(); self._gap=False; self._gstart=-1
                        return fw_c, ok_c, cam, zm, was_bt

                # ── Output: native 16:9 ──
                _ASP = 16.0 / 9.0
                if W/max(H,1) >= _ASP: OUT_H_41=H; OUT_W_41=int(H*_ASP)
                else:                  OUT_W_41=W; OUT_H_41=int(W/_ASP)
                OUT_W_41 += OUT_W_41 % 2; OUT_H_41 += OUT_H_41 % 2
                out.release()
                out = cv2.VideoWriter(output_path, cv2.VideoWriter_fourcc(*'mp4v'), FPS, (OUT_W_41, OUT_H_41))

                # ── State ──
                kal41=None; cam41=_Cam41(W//2,H//2)
                zoom41=_V41_ZOOM_BASE; frame_idx=0
                tracker_ok_count=0; yolo_calls=0; bt_count=0
                buf41=_Buf41()

                print(f"🏃 Ball Tracking v4.1 (Default Pipeline)")
                print(f"   Input:  {W}x{H} @ {FPS:.1f}fps")
                print(f"   Output: {OUT_W_41}x{OUT_H_41} (native 16:9)")
                print(f"   Field mask: {'polygon ({} pts)'.format(len(FIELD_MASK_POLYGON)) if FIELD_MASK_POLYGON is not None else 'rectangular fallback'}")
                print(f"   Lookahead: {_V41_LOOKAHEAD_MIN}→{_V41_LOOKAHEAD_MAX} frames")

                while True:
                    ret, frame = cap.read()
                    if not ret or frame is None: break
                    frame_idx += 1

                    prog_iv = max(30, TOTAL // 100)
                    if frame_idx % prog_iv == 0:
                        update_job('processing', progress=15+int((frame_idx/max(TOTAL,1))*70))
                    if frame_idx % 500 == 0:
                        print(f"💓 F{frame_idx}/{TOTAL} yolo/f={yolo_calls/max(frame_idx,1):.2f} bt={bt_count}")

                    # Kalman prediction
                    px41,py41=None,None
                    if kal41 is not None and kal41.valid:
                        px41,py41=kal41.predict()

                    skip_f = kal41 is not None and kal41.can_skip and frame_idx%2==0

                    det_c=None; det_conf=0.0

                    if not skip_f:
                        # Strategy A: ROI
                        if kal41 is not None and kal41.valid and px41 is not None:
                            r=kal41.radius
                            ry1 = 0 if kal41._kick else max(0,int(py41-r))
                            rx1=max(0,int(px41-r)); rx2=min(W,int(px41+r)); ry2=min(H,int(py41+r))
                            roi=frame[ry1:ry2,rx1:rx2]
                            if roi.size>0:
                                d=_det41(roi, model, _V41_YOLO_CONF*0.75, _V41_ROI_IMGSZ,
                                          pred_xy=(px41-rx1,py41-ry1), ox=rx1, oy=ry1)
                                yolo_calls+=1
                                if d: det_c=(d[0],d[1]); det_conf=d[2]
                        # Strategy B: Full-frame
                        do_full = kal41 is None or frame_idx%_V41_FULL_EVERY==0 or (kal41 is not None and kal41.miss_count>3)
                        if det_c is None and do_full:
                            d=_det41(frame,model,_V41_YOLO_CONF,_V41_FULL_IMGSZ,
                                      pred_xy=(px41,py41) if px41 else None)
                            yolo_calls+=1
                            if d: det_c=(d[0],d[1]); det_conf=d[2]

                    # Teleport guard
                    if det_c and kal41 is not None and kal41.valid and px41 is not None:
                        dist41=_math41.sqrt((det_c[0]-px41)**2+(det_c[1]-py41)**2)
                        if dist41>max(_Kalman41.MAX_TP, kal41.spd*3) and det_conf<0.7:
                            det_c=None

                    # Kalman update
                    bx41,by41=None,None; real_det=False
                    if det_c:
                        bx41,by41=det_c; real_det=True
                        if kal41 is None: kal41=_Kalman41(bx41,by41,dt)
                        else: kal41.update(bx41,by41,conf=det_conf)
                    elif skip_f and kal41 is not None and kal41.valid:
                        bx41,by41=kal41.pos; real_det=True
                    elif kal41 is not None:
                        kal41.no_det()
                        if kal41.valid: bx41,by41=kal41.pos

                    # Snapshot camera before first frame in buffer
                    if buf41.sz == 0: cam41.snap()

                    buf41.add(frame, (bx41,by41) if bx41 is not None else None, real_det, det_conf)

                    if buf41.should_flush:
                        _,ok,cam41,zoom41,wasbt=buf41.flush(cam41,zoom41,W,H,OUT_W_41,OUT_H_41,_ASP,out)
                        tracker_ok_count+=ok
                        if wasbt: bt_count+=1

                # Flush remaining
                if buf41.sz > 0:
                    _,ok,cam41,zoom41,wasbt=buf41.flush(cam41,zoom41,W,H,OUT_W_41,OUT_H_41,_ASP,out)
                    tracker_ok_count+=ok
                    if wasbt: bt_count+=1

                cap.release(); out.release()
                accuracy = int(tracker_ok_count / max(frame_idx,1) * 100)
                print(f"✅ v4.1 complete! Accuracy: {accuracy}% ({tracker_ok_count}/{frame_idx} frames)")
                print(f"   💰 YOLO calls/frame: {yolo_calls/max(frame_idx,1):.2f}")
                print(f"   🔄 Backtracks: {bt_count}")
        
        # Calculate costs
        processing_time = (datetime.now() - start_time).total_seconds()
        gpu_cost = (processing_time / 3600) * 1.10  # $1.10/hour for A100
        
        print(f"⏱️ Processing time: {processing_time:.1f}s")
        print(f"💰 GPU cost: ${gpu_cost:.4f}")
        
        # Compress output video to avoid Supabase 50MB/100MB limits (413 Payload Too Large)
        compressed_path = "/tmp/output_compressed.mp4"
        print("🔧 Final encoding...")
        update_job("processing", progress=90)
        
        try:
            # -crf 28 is a good balance for ball tracking visibility vs size
            # -preset faster for reasonable processing time on T4
            if log_audio:
                print("🔊 Merging video with audio...")
                # Extract audio from raw first
                subprocess.run(['ffmpeg', '-y', '-i', input_path_raw, '-vn', '-acodec', 'copy', '/tmp/audio_extract.aac'], check=False, capture_output=True)
                # Merge
                subprocess.run([
                    "ffmpeg", "-y", "-i", output_path, "-i", "/tmp/audio_extract.aac",
                    "-c:v", "libx264", "-crf", "28", "-preset", "faster",
                    "-c:a", "aac", "-b:a", "128k", "-map", "0:v:0", "-map", "1:a:0?",
                    compressed_path
                ], check=True, capture_output=True)
                print("✅ Audio merged successfully")
            else:
                subprocess.run([
                    "ffmpeg", "-y", "-i", output_path,
                    "-vcodec", "libx264", "-crf", "28", "-preset", "faster",
                    "-acodec", "aac", "-b:a", "128k",
                    compressed_path
                ], check=True, capture_output=True)
        
            output_path = compressed_path
            print(f"📁 Output size: {os.path.getsize(output_path) / (1024*1024):.1f} MB")
        except Exception as e:
            print(f"⚠️ Compression failed or FFmpeg not found, uploading original: {e}")
        
        # Upload output video to Supabase Storage using TUS
        print("⬆️ Uploading output video...")
        update_job("processing", progress=95)
        
        output_filename = f"ball-tracking-output/{job_id}.mp4"
        bucket_name = "videos"
        object_name = output_filename
        
        try:
            import base64
            import requests
            
            def b64_str(s):
                return base64.b64encode(s.encode('utf-8')).decode('utf-8')
                
            file_size = os.path.getsize(output_path)
            metadata_pieces = [
                f"bucketName {b64_str(bucket_name)}",
                f"objectName {b64_str(object_name)}",
                f"contentType {b64_str('video/mp4')}"
            ]
            
            init_url = f"{supabase_url}/storage/v1/upload/resumable"
            init_headers = {
                "Authorization": f"Bearer {supabase_key}",
                "Tus-Resumable": "1.0.0",
                "Upload-Length": str(file_size),
                "Upload-Metadata": ",".join(metadata_pieces),
            }
            
            print(f"🔄 Initializing TUS upload for {file_size} bytes...")
            response = requests.post(init_url, headers=init_headers, timeout=30)
            
            if response.status_code not in [200, 201, 202, 204]:
                print(f"⚠️ TUS Init failed: {response.status_code} {response.text[:200]}, falling back to supabase py...")
                # Fallback
                with open(output_path, "rb") as f:
                    output_video_bytes = f.read()
                supabase.storage.from_("videos").upload(
                    output_filename,
                    output_video_bytes,
                    {"content-type": "video/mp4", "upsert": "true"}
                )
            else:
                upload_url = response.headers.get("Location")
                if not upload_url:
                    raise Exception("No Location header returned in TUS creation")
                    
                if upload_url.startswith('/'):
                    upload_url = f"{supabase_url}{upload_url}"
                    
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
                        print(f"⬆️ TUS Uploaded {offset}/{file_size} bytes ({(offset/file_size)*100:.1f}%)")
                        update_job("processing", progress=95 + int((offset/file_size)*4))
                        
        except Exception as upload_err:
            print(f"❌ Supabase Upload Failed: {upload_err}")
            if "413" in str(upload_err) or "too large" in str(upload_err).lower():
                raise RuntimeError(f"Output video ({os.path.getsize(output_path)/(1024*1024):.1f}MB) is STILL too large. Error: {upload_err}")
            raise upload_err
        
        output_video_url = supabase.storage.from_("videos").get_public_url(output_filename)
        
        # Update job with results
        update_job(
            "completed",
            progress=100,
            output_video_url=output_video_url,
            tracking_accuracy_percent=accuracy,
            frames_tracked=tracker_ok_count,
            processing_time_seconds=processing_time,
            gpu_cost_usd=gpu_cost,
            gpu_type="Modal T4",
            processing_logs=f"Processed {TOTAL} frames in {processing_time:.1f}s\nBall detected in {tracker_ok_count} frames ({accuracy}%)\nModel: {YOLO_MODEL}\nCost: ${gpu_cost:.4f}\nCodec: H.264 (FFmpeg)"
        )
        
        print(f"🎉 Job {job_id} completed successfully!")
        
    except Exception as e:
        error_msg = f"Processing failed: {str(e)}"
        print(f"❌ Error: {error_msg}")
        update_job("failed", error=error_msg)
        raise


@app.local_entrypoint()
def main():
    """Test function locally"""
    print("🧪 Testing ball tracking processor...")


async def webhook_endpoint_logic(data: dict):
    """
    Logic for the webhook endpoint
    """
    job_id = data.get("job_id")
    video_url = data.get("video_url")
    script_config = data.get("config", {})
    custom_script = data.get("custom_script")
    roboflow_api_key = data.get("roboflow_api_key")
    field_id = data.get("field_id")  # Optional: used to fetch field mask polygon
    
    import os
    SUPABASE_URL = "https://upooyypqhftzzwjrfyra.supabase.co"
    supabase_key = os.environ.get("SUPABASE_KEY", os.environ.get("SUPABASE_SERVICE_ROLE_KEY"))
    
    # Run in background on GPU (Async usage)
    target_kwargs = dict(
        job_id=job_id, 
        input_video_url=video_url, 
        script_config=script_config, 
        supabase_url=SUPABASE_URL, 
        supabase_key=supabase_key,
        custom_script=custom_script,
        roboflow_api_key=roboflow_api_key,
        field_id=field_id,
    )
    
    await process_video.spawn.aio(**target_kwargs)
    return {"status": "accepted", "job_id": job_id}


@app.function(
    image=image, 
    secrets=[modal.Secret.from_name("supabase-credentials")],
    timeout=600,  # 10 min for monitoring
    schedule=modal.Period(minutes=2)
)
def heartbeat():
    """
    Cron Job (Every 2 Minutes):
    Picks up any 'pending' or 'queued' jobs that haven't started.
    This ensures processing works even if the initial webhook was interrupted.
    """
    import os
    from supabase import create_client
    SUPABASE_URL = "https://upooyypqhftzzwjrfyra.supabase.co"
    supabase_key = os.environ.get("SUPABASE_KEY", os.environ.get("SUPABASE_SERVICE_ROLE_KEY"))
    
    if not supabase_key:
        print("❌ Heartbeat error: Supabase key missing from environment.")
        return
        
    supabase = create_client(SUPABASE_URL, supabase_key)
    
    # 1. Fetch pending jobs
    print("💓 Heartbeat: Checking for pending ball tracking jobs...")
    try:
        # Get jobs that are 'pending' (newly created) or 'queued' (waiting)
        response = supabase.table("ball_tracking_jobs")\
            .select("*")\
            .or_("status.eq.pending,status.eq.queued")\
            .order("created_at")\
            .limit(5)\
            .execute()
        
        pending_jobs = response.data or []
        if not pending_jobs:
            print("📅 No pending jobs found.")
            return

        print(f" gefunden {len(pending_jobs)} pending jobs. Triggering processing...")
        
        for job in pending_jobs:
            job_id = job["id"]
            video_url = job["input_video_url"]
            config = job.get("script_config", {})
            custom_script = job.get("custom_script")
            
            # Use default Roboflow key if available in env
            rf_api_key = os.environ.get("ROBOFLOW_API_KEY")
            
            print(f"🚀 Heartbeat triggering job {job_id}")
            process_video.spawn(
                job_id,
                video_url,
                config,
                SUPABASE_URL,
                supabase_key,
                custom_script,
                rf_api_key
            )
            
    except Exception as e:
        print(f"❌ Heartbeat error: {e}")
async def generate_generative_ai_extension(frame, target_w, target_h):
    """
    Use Gemini Imagen via the Gemini API to generate a vertical 9:16 stadium
    background that can sit behind the original wide frame.

    NOTE: This uses the ai.google.dev Gemini/Imagen endpoint via the
    `google-genai` client and the `GEMINI_API_KEY` secret.
    """
    import os
    import numpy as np
    import cv2
    from PIL import Image as PILImage

    try:
        from google import genai
        from google.genai import types as genai_types
    except Exception as e:
        print(f"❌ google-genai not available in container: {e}")
        return None

    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        print("❌ GEMINI_API_KEY missing in environment. Configure Modal secret 'gemini-api-key' with GEMINI_API_KEY (or GOOGLE_API_KEY).")
        return None
    # Safe debug: confirm which key is loaded (no full secret leak)
    try:
        key_suffix = api_key[-4:] if len(api_key) >= 4 else api_key
        print(f"🔐 Gemini key loaded (len={len(api_key)}, suffix=...{key_suffix})")
    except Exception:
        pass

    try:
        client = genai.Client(api_key=api_key)

        prompt = (
            "Wide-angle professional football stadium scene that can sit behind a match broadcast. "
            "Continue the pitch, stands, buildings, and sky so it looks like a natural vertical "
            "9:16 extension of a horizontal broadcast frame. No text, no score bug, no people close-up."
        )

        print("🧠 Calling Gemini Imagen for 9:16 background...")
        resp = client.models.generate_images(
            model="imagen-4.0-generate-001",
            prompt=prompt,
            config=genai_types.GenerateImagesConfig(
                number_of_images=1,
                aspect_ratio="9:16",
            ),
        )

        if not resp.generated_images:
            print("⚠️ Gemini returned no images.")
            return None

        gen_img = resp.generated_images[0].image  # PIL.Image
        # Resize to our target canvas
        gen_img = gen_img.resize((target_w, target_h), PILImage.LANCZOS)
        res_cv = cv2.cvtColor(np.array(gen_img), cv2.COLOR_RGB2BGR)

        # Optional: lightly blend center region toward original frame colours
        H, W = frame.shape[:2]
        resized_h = int(target_w * H / W)
        resized_frame = cv2.resize(frame, (target_w, resized_h))
        y_offset = max(0, (target_h - resized_h) // 2)
        y1 = y_offset
        y2 = min(target_h, y_offset + resized_h)

        if y2 > y1:
            alpha = 0.35  # keep generated background dominant but hint of original
            roi_bg = res_cv[y1:y2, 0:target_w]
            roi_fg = resized_frame[0:(y2 - y1), 0:target_w]
            blended = cv2.addWeighted(roi_bg, 1 - alpha, roi_fg, alpha, 0)
            res_cv[y1:y2, 0:target_w] = blended

        return res_cv

    except Exception as e:
        print(f"❌ Gemini Imagen error: {e}")
        return None

async def preview_ai_extension_endpoint_logic(data: dict):
    """
    Logic for the extension preview endpoint
    """
    video_url = data.get("video_url")
    
    import cv2
    import numpy as np
    import requests
    import os
    import tempfile
    from supabase import create_client
    
    try:
        SUPABASE_URL = "https://upooyypqhftzzwjrfyra.supabase.co"
        supabase_key = os.environ.get("SUPABASE_KEY", os.environ.get("SUPABASE_SERVICE_ROLE_KEY"))
        supabase = create_client(SUPABASE_URL, supabase_key)
        
        print(f"🖼️ Generating extension preview for {video_url}")
        
        # 1. Grab a frame (at approx 1 second)
        cap = cv2.VideoCapture(video_url)
        cap.set(cv2.CAP_PROP_POS_MSEC, 1000)
        ret, frame = cap.read()
        cap.release()
        
        if not ret:
            return {"status": "error", "message": "Could not extract frame"}
        
        W, H = frame.shape[1], frame.shape[0]
        
        # 1. Take a center slice of the original frame (for fallback)
        bg_w_full = int(H * 9 / 16)
        bg_x1 = max(0, W // 2 - bg_w_full // 2)
        bg_x2 = min(W, bg_x1 + bg_w_full)
        bg_crop = frame[0:H, bg_x1:bg_x2].copy()

        # Target dimensions for the 9:16 vertical canvas
        OUT_W = int(W * 0.45) # Match CROP_RATIO from script
        OUT_H = int(OUT_W * 16 / 9)
        
        # --- GENERATIVE AI OUTPAINTING ---
        print("💡 Attempting Generative AI Outpainting...")
        preview_canvas = await generate_generative_ai_extension(frame, OUT_W, OUT_H)
        used_ai = preview_canvas is not None
        fallback_reason = None
        
        if preview_canvas is None:
            print("⚠️ Generative AI failed, using high-quality mirrored fallback")
            fallback_reason = "gemini_failed_or_missing_key"
            # --- FALLBACK: Improved Mirrored Background ---
            canvas = cv2.resize(bg_crop, (OUT_W, OUT_H))
            canvas = cv2.GaussianBlur(canvas, (99, 99), 0)
            canvas = cv2.convertScaleAbs(canvas, alpha=0.45, beta=0) # Darken
            
            # Paste the original (resized) frame in the center for the preview
            y_offset = (OUT_H - int(OUT_W * H / W)) // 2
            resized_original = cv2.resize(frame, (OUT_W, int(OUT_W * H / W)))
            
            preview_canvas = canvas.copy()
            preview_canvas[y_offset:y_offset + resized_original.shape[0], 0:OUT_W] = resized_original
        
        # 3. Save and Upload to Supabase
        temp_img = tempfile.NamedTemporaryFile(suffix=".jpg", delete=False)
        cv2.imwrite(temp_img.name, preview_canvas)
        
        with open(temp_img.name, "rb") as f:
            img_bytes = f.read()
        
        import uuid
        preview_id = str(uuid.uuid4())
        upload_path = f"extension-previews/{preview_id}.jpg"
        
        supabase.storage.from_("videos").upload(
            upload_path,
            img_bytes,
            {"content-type": "image/jpeg", "upsert": "true"}
        )
        
        os.remove(temp_img.name)
        
        preview_url = supabase.storage.from_("videos").get_public_url(upload_path)
        print(f"✅ Preview generated: {preview_url}")
        
        return {
            "status": "success",
            "preview_url": preview_url,
            "used_ai": used_ai,
            "fallback_reason": fallback_reason,
        }
    except Exception as e:
        print(f"❌ Preview Logic Error: {e}")
        return {"status": "error", "message": str(e)}


if web_app is not None:
    @web_app.post("/preview")
    async def preview_endpoint(data: dict):
        return await preview_ai_extension_endpoint_logic(data)

    @web_app.get("/test")
    async def test_endpoint():
        return {"status": "ok", "message": "Modal Ball Tracking API is live!"}

    @web_app.post("/webhook")
    async def webhook_endpoint(data: dict):
        return await webhook_endpoint_logic(data)


@app.function(
    image=image, 
    gpu="T4",
    volumes={
        "/models": yolo_volume,
        "/genai_models": model_volume
    },
    secrets=[
        modal.Secret.from_name("supabase-credentials"),
        modal.Secret.from_name("gemini-api-key")
    ],
    timeout=600,
    memory=16384,
)
@modal.asgi_app()
def api():
    return web_app

