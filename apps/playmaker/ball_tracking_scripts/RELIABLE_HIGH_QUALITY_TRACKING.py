"""
⚡ RELIABLE + HIGH QUALITY BALL TRACKING
- YOLOv8s (small) - Good balance of speed and accuracy
- 800px resolution - Better detection for small balls
- Detect every 3 frames - More frequent detection
- Lower confidence (0.15) - Catch distant/small balls
- Adaptive Kalman Filter - Handles perspective
- CRF 18 encoding - Near-lossless quality
- Target: 60-80% tracking rate
- Speed: 20-25 fps (still fast!)
- Cost: ~$0.40-0.50 per hour of video
"""

import cv2
import numpy as np
import time
import subprocess
import os

# ============================================================
# BALANCED CONFIG - RELIABILITY + QUALITY
# ============================================================
YOLO_MODEL = 'yolov8s'          # Small model - good balance
YOLO_CONF = 0.15                # Lower conf - catch MORE balls
YOLO_IMG_SIZE = 800             # Higher resolution - better detection
DETECT_EVERY = 3                # Detect every 3 frames (more frequent)

ROI_SEARCH_BASE = 800           # Larger ROI = better search
ZOOM_BASE = 2.0                 # Base zoom level
ZOOM_MIN = 1.4
ZOOM_MAX = 2.4
CAMERA_SMOOTHNESS = 0.20        # Higher = smoother but slight lag
ZOOM_SMOOTHNESS = 0.15

BALL_MEMORY = 20                # Track last 20 ball positions (more memory)
OUTPUT_WIDTH = W
OUTPUT_HEIGHT = H
COMPRESSION_QUALITY = 18        # CRF 18 = near-lossless quality

# Perspective zones
Y_FAR_THRESHOLD = 0.25          # Top 25% of frame (far from camera)
Y_NEAR_THRESHOLD = 0.65         # Bottom 35% of frame (close to camera)

# Initial camera position (start lower where ball is more likely)
INITIAL_CAM_Y_RATIO = 0.55      # Start at 55% down the frame (middle-low)

# Validation thresholds (more lenient)
MIN_BALL_SIZE = 40              # Smaller minimum (was 50)
MAX_BALL_SIZE = 5000            # Larger maximum (was 4000)
MAX_LOST_FRAMES = 120           # Allow longer loss (was 150)

# ============================================================
# ADAPTIVE KALMAN FILTER
# ============================================================
class AdaptiveKalmanTracker:
    """
    Kalman filter with adaptive measurement noise based on Y position.
    Far balls (small, top of frame) = high noise (trust model more).
    Near balls (large, bottom of frame) = low noise (trust detections more).
    """
    def __init__(self, initial_x, initial_y, frame_height):
        self.frame_height = frame_height
        
        # State: [x, y, vx, vy]
        self.state = np.array([initial_x, initial_y, 0.0, 0.0], dtype=np.float32)
        
        # Covariance matrix
        self.P = np.eye(4, dtype=np.float32) * 100.0
        
        # Process noise - slightly higher for sudden movements
        self.Q = np.eye(4, dtype=np.float32) * 3.0
        
        # Measurement noise - ADAPTIVE based on Y position
        self.R = self._get_measurement_noise(initial_y)
        
        # State transition (constant velocity model)
        dt = DETECT_EVERY / FPS
        self.F = np.array([
            [1, 0, dt, 0],
            [0, 1, 0, dt],
            [0, 0, 1, 0],
            [0, 0, 0, 1],
        ], dtype=np.float32)
        
        # Measurement matrix (we only observe position)
        self.H = np.array([
            [1, 0, 0, 0],
            [0, 1, 0, 0],
        ], dtype=np.float32)
    
    def _get_measurement_noise(self, y_pos):
        """
        Calculate adaptive measurement noise based on Y position.
        Far (top): High noise (70-90) - trust model more
        Middle: Medium noise (25-30)
        Near (bottom): Low noise (10-15) - trust detections more
        """
        y_norm = y_pos / self.frame_height
        
        if y_norm < Y_FAR_THRESHOLD:
            # Far zone - ball is small, detections are noisy
            r = 90.0
        elif y_norm > Y_NEAR_THRESHOLD:
            # Near zone - ball is large, detections are accurate
            r = 12.0
        else:
            # Transition zone - linear interpolation
            progress = (y_norm - Y_FAR_THRESHOLD) / (Y_NEAR_THRESHOLD - Y_FAR_THRESHOLD)
            r = 90.0 - (progress * 78.0)  # 90 -> 12
        
        return np.eye(2, dtype=np.float32) * r
    
    def predict(self):
        """Predict next state."""
        self.state = self.F @ self.state
        self.P = self.F @ self.P @ self.F.T + self.Q
        return self.state[:2].copy()
    
    def update(self, measurement_x, measurement_y):
        """Update with new detection."""
        # Update measurement noise based on Y position
        self.R = self._get_measurement_noise(measurement_y)
        
        z = np.array([measurement_x, measurement_y], dtype=np.float32)
        
        # Innovation
        y = z - (self.H @ self.state)
        
        # Innovation covariance
        S = self.H @ self.P @ self.H.T + self.R
        
        # Kalman gain
        K = self.P @ self.H.T @ np.linalg.inv(S)
        
        # Update state
        self.state = self.state + (K @ y)
        
        # Update covariance
        I = np.eye(4, dtype=np.float32)
        self.P = (I - K @ self.H) @ self.P
        
        return self.state[:2].copy()
    
    def get_position(self):
        return self.state[:2].copy()
    
    def get_velocity(self):
        return self.state[2:].copy()

# ============================================================
# PERSPECTIVE-AWARE ZOOM
# ============================================================
def calculate_zoom(ball_y, ball_speed):
    """Calculate zoom based on ball's Y position and speed."""
    y_norm = ball_y / H
    
    # Base zoom adjustment based on Y position
    if y_norm < Y_FAR_THRESHOLD:
        # Far zone - zoom in more to see the small ball
        distance_into_far = (Y_FAR_THRESHOLD - y_norm) / Y_FAR_THRESHOLD
        zoom_adjust = 0.3 * distance_into_far
    elif y_norm > Y_NEAR_THRESHOLD:
        # Near zone - zoom out to show more context
        distance_into_near = (y_norm - Y_NEAR_THRESHOLD) / (1.0 - Y_NEAR_THRESHOLD)
        zoom_adjust = -0.35 * distance_into_near
    else:
        # Middle zone - transition smoothly
        transition = (y_norm - Y_FAR_THRESHOLD) / (Y_NEAR_THRESHOLD - Y_FAR_THRESHOLD)
        zoom_adjust = 0.3 - (transition * 0.65)
    
    # Speed adjustment - zoom out slightly for fast ball
    speed_adjust = -min(0.15, ball_speed / 150.0)
    
    zoom_target = ZOOM_BASE + zoom_adjust + speed_adjust
    return np.clip(zoom_target, ZOOM_MIN, ZOOM_MAX)

# ============================================================
# MAIN PROCESSING
# ============================================================
print("=" * 70)
print("⚡ RELIABLE + HIGH QUALITY BALL TRACKING")
print("=" * 70)
print(f"📹 Input: {W}x{H} @ {FPS} fps")
print(f"📹 Output: {OUTPUT_WIDTH}x{OUTPUT_HEIGHT} (LANCZOS4 interpolation)")
print(f"🎯 Model: {YOLO_MODEL} @ {YOLO_IMG_SIZE}px (RELIABLE!)")
print(f"🎯 Detection: Every {DETECT_EVERY} frames (every 2 at start)")
print(f"🎯 Confidence: {YOLO_CONF} (lower = catch more balls)")
print(f"🎯 Encoding: CRF {COMPRESSION_QUALITY} (near-lossless)")
print(f"📍 Initial position: Lower in frame (y={int(H * INITIAL_CAM_Y_RATIO)})")
print(f"⚡ Target: 60-80% tracking, 20-25 fps processing")
print("=" * 70)

# Initialize
frame_idx = 0
kalman = None
ball_center = np.array([W/2, H * INITIAL_CAM_Y_RATIO], dtype=np.float32)
ball_history = []

# Camera state (start lower, wider zoom)
cam_x, cam_y = W/2.0, H * INITIAL_CAM_Y_RATIO
zoom_current = ZOOM_MIN  # Start with wider view to see more field

# Stats
detections = 0
predictions = 0
frames_since_detection = 999

# Output video
codecs = [
    ('avc1', cv2.VideoWriter_fourcc(*'avc1')),
    ('H264', cv2.VideoWriter_fourcc(*'H264')),
    ('mp4v', cv2.VideoWriter_fourcc(*'mp4v')),
]

out = None
for codec_name, fourcc in codecs:
    out = cv2.VideoWriter(output_path, fourcc, FPS, (OUTPUT_WIDTH, OUTPUT_HEIGHT))
    if out.isOpened():
        print(f"✅ Using codec: {codec_name}")
        break

if not out or not out.isOpened():
    raise RuntimeError("Cannot create output video")

print("✅ Output video initialized\n")

t0 = time.time()
last_progress_update = 0

# ============================================================
# FRAME LOOP
# ============================================================
while True:
    ret, frame = cap.read()
    if not ret:
        break
    
    frame_idx += 1
    frames_since_detection += 1
    
    # Progress update
    if frame_idx % max(10, int(FPS*3)) == 0:
        elapsed = time.time() - t0
        fps_actual = frame_idx / elapsed
        progress = int(20 + (frame_idx/TOTAL)*60)
        
        if progress != last_progress_update:
            update_job("processing", progress=progress)
            last_progress_update = progress
        
        tracking_pct = int((detections + predictions) / max(1, frame_idx) * 100)
        print(f"⏱️ Frame {frame_idx}/{TOTAL} ({int(frame_idx/TOTAL*100)}%)")
        print(f"   Processing: {fps_actual:.1f} fps")
        print(f"   Tracking: {tracking_pct}%\n")
    
    target_center = None
    detected_this_frame = False
    
    # KALMAN PREDICTION (every frame)
    if kalman is not None:
        predicted_pos = kalman.predict()
        target_center = predicted_pos
        predictions += 1
    
    # YOLO DETECTION (every N frames)
    # At start: detect more aggressively (every 2 frames until first detection)
    if kalman is None and frame_idx < 200:
        do_detect = (frame_idx % 2 == 1)  # Detect every 2 frames at start
    else:
        do_detect = (frame_idx % DETECT_EVERY == 1) or frames_since_detection > 80
    
    if do_detect:
        # Define ROI around last known ball position
        if len(ball_history) > 0:
            roi_cx, roi_cy = int(ball_center[0]), int(ball_center[1])
        else:
            # At start, use initial position (lower in frame)
            roi_cx, roi_cy = W // 2, int(H * INITIAL_CAM_Y_RATIO)
        
        # Use wider ROI at start to find the ball faster
        roi_size = ROI_SEARCH_BASE * 2 if kalman is None else ROI_SEARCH_BASE
        
        x1 = max(0, roi_cx - roi_size // 2)
        y1 = max(0, roi_cy - roi_size // 2)
        x2 = min(W, roi_cx + roi_size // 2)
        y2 = min(H, roi_cy + roi_size // 2)
        
        # Safety check - if ROI is too small or invalid, use full frame
        if x2 <= x1 or y2 <= y1 or (x2 - x1) < 50 or (y2 - y1) < 50 or kalman is None:
            roi_frame = frame
            roi_offset_x, roi_offset_y = 0, 0
        else:
            roi_frame = frame[y1:y2, x1:x2]
            roi_offset_x, roi_offset_y = x1, y1
        
        # YOLO detection
        if roi_frame.size > 0:
            results = model(roi_frame, conf=YOLO_CONF, imgsz=YOLO_IMG_SIZE, classes=[32], verbose=False)[0]
            boxes = results.boxes
            
            if boxes is not None and len(boxes) > 0:
                ball_dets = []
                
                for b in boxes:
                    conf = float(b.conf[0])
                    bx1, by1, bx2, by2 = map(int, b.xyxy[0].tolist())
                    
                    # Convert to full frame coordinates
                    bx1 += roi_offset_x
                    by1 += roi_offset_y
                    bx2 += roi_offset_x
                    by2 += roi_offset_y
                    
                    cx, cy = (bx1 + bx2) / 2, (by1 + by2) / 2
                    size = (bx2 - bx1) * (by2 - by1)
                    
                    # More lenient size validation
                    if size < MIN_BALL_SIZE or size > MAX_BALL_SIZE:
                        continue
                    
                    # Proximity score
                    dist = np.linalg.norm(np.array([cx, cy]) - ball_center)
                    proximity_score = 1.0 / (1.0 + dist / 250.0) if len(ball_history) > 0 else 1.0
                    
                    # Combined score (prioritize confidence and proximity)
                    combined_score = (conf * 0.7) + (proximity_score * 0.3)
                    ball_dets.append(((cx, cy), combined_score, dist))
                
                if len(ball_dets) > 0:
                    # Take best detection
                    ball_dets.sort(key=lambda x: x[1], reverse=True)
                    (cx, cy), score, dist = ball_dets[0]
                    
                    # Initialize or update Kalman
                    if kalman is None:
                        kalman = AdaptiveKalmanTracker(cx, cy, H)
                        print(f"✅ Ball detected! Starting tracking at ({int(cx)}, {int(cy)})\n")
                    else:
                        kalman.update(cx, cy)
                    
                    target_center = np.array([cx, cy], dtype=np.float32)
                    detected_this_frame = True
                    detections += 1
                    frames_since_detection = 0
    
    # Reinitialize if lost for too long
    if frames_since_detection > MAX_LOST_FRAMES:
        if kalman is not None:
            print(f"⚠️ Ball lost at frame {frame_idx}, reinitializing...\n")
        kalman = None
        frames_since_detection = 0
    
    # UPDATE BALL POSITION
    if target_center is not None:
        ball_center = target_center
        ball_history.append(ball_center.copy())
        if len(ball_history) > BALL_MEMORY:
            ball_history.pop(0)
    elif len(ball_history) > 0:
        ball_center = ball_history[-1].copy()
    
    # CAMERA MOVEMENT
    cam_x = cam_x * (1 - CAMERA_SMOOTHNESS) + ball_center[0] * CAMERA_SMOOTHNESS
    cam_y = cam_y * (1 - CAMERA_SMOOTHNESS) + ball_center[1] * CAMERA_SMOOTHNESS
    
    # ZOOM (perspective-aware)
    if kalman is not None:
        velocity = kalman.get_velocity()
        ball_speed = np.linalg.norm(velocity)
    else:
        ball_speed = 0
    
    zoom_target = calculate_zoom(ball_center[1], ball_speed)
    zoom_current = zoom_current * (1 - ZOOM_SMOOTHNESS) + zoom_target * ZOOM_SMOOTHNESS
    
    # CROP & RESIZE
    crop_w = int(W / zoom_current)
    crop_h = int(H / zoom_current)
    sx = int(np.clip(cam_x - crop_w//2, 0, W - crop_w))
    sy = int(np.clip(cam_y - crop_h//2, 0, H - crop_h))
    
    cropped = frame[sy:sy+crop_h, sx:sx+crop_w]
    # Use LANCZOS4 for highest quality resizing
    out_frame = cv2.resize(cropped, (OUTPUT_WIDTH, OUTPUT_HEIGHT), interpolation=cv2.INTER_LANCZOS4)
    
    out.write(out_frame)

cap.release()
out.release()

processing_time = time.time() - t0
processing_fps = TOTAL / processing_time

print("=" * 70)
print("✅ FRAME PROCESSING COMPLETE!")
print("=" * 70)
print(f"⏱️ Time: {processing_time:.1f}s")
print(f"⚡ Processing Speed: {processing_fps:.1f} fps")
print(f"🎯 Detections: {detections}")
print(f"🎯 Predictions: {predictions}")
print(f"📊 Tracking Rate: {int((detections + predictions) / TOTAL * 100)}%")
print("=" * 70)

# ============================================================
# FFMPEG RE-ENCODING (HIGH QUALITY)
# ============================================================
print("🔄 Re-encoding with ffmpeg for maximum quality...")
update_job("processing", progress=85)

temp_output = output_path + ".temp.mp4"
os.rename(output_path, temp_output)

ffmpeg_cmd = [
    "ffmpeg", "-y",
    "-i", temp_output,
    "-c:v", "libx264",
    "-preset", "slow",  # Slower but better quality
    "-crf", str(COMPRESSION_QUALITY),
    "-movflags", "+faststart",
    "-pix_fmt", "yuv420p",
    output_path
]

try:
    subprocess.run(ffmpeg_cmd, check=True, capture_output=True, text=True)
    os.remove(temp_output)
    output_size = os.path.getsize(output_path) / (1024*1024)
    print(f"✅ Ffmpeg complete! Output: {output_size:.1f} MB")
    update_job("processing", progress=95)
except subprocess.CalledProcessError as e:
    print(f"⚠️ Ffmpeg failed: {e.stderr}")
    if os.path.exists(temp_output):
        os.rename(temp_output, output_path)

# ============================================================
# FINAL METRICS
# ============================================================
elapsed = time.time() - t0
tracking_pct = int((detections + predictions) / TOTAL * 100)

print("=" * 70)
print("📊 FINAL METRICS")
print("=" * 70)
print(f"✅ Tracking Rate: {tracking_pct}%")
print(f"✅ Detection Rate: {int(detections / TOTAL * 100)}%")
print(f"⚡ Processing Speed: {processing_fps:.1f} fps")
print(f"⏱️ Total Time: {elapsed:.1f}s")
print(f"💰 Estimated Cost: ~${(elapsed / 3600) * 0.45:.3f}")
print("=" * 70)
print("⚡ RELIABLE + HIGH QUALITY TRACKING COMPLETE!")





