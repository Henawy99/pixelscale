"""
ACCURATE Ball Tracking with Kalman Filter + Perspective Correction

- Uses yolov8l for ACCURACY (can detect small/fast balls)
- Kalman filter for smooth prediction
- OpenCV tracker as fallback
- Handles high-mounted camera perspective
- Adjusts zoom based on ball position in frame

NOTE: Test ACCURATE_ball_tracking.py first! This is only if you need SMOOTHER tracking.
"""

import cv2
import numpy as np
import time
import subprocess
import os

# ----------------- CONFIG -----------------
YOLO_CONF = 0.12
IMG_SZ = 960
DETECT_EVERY = 3
ROI_SIZE = 1200

SMOOTH_CAM = 0.08
SMOOTH_ZOOM = 0.10

ZOOM_BASE = 1.8
ZOOM_MIN = 1.3
ZOOM_MAX = 2.4

BALL_MEMORY = 20
VELOCITY_MEMORY = 10

OUTPUT_WIDTH = W
OUTPUT_HEIGHT = H
COMPRESSION_QUALITY = 23

NEAR_SIDE_THRESHOLD = 0.6
FAR_SIDE_THRESHOLD = 0.3

# Kalman filter parameters
PROCESS_NOISE = 1.0      # How much we trust the model (lower = trust model more)
MEASUREMENT_NOISE = 25.0 # How much we trust detections (lower = trust detections more)

# ------------------------------------------

class KalmanBallTracker:
    """
    Kalman filter for ball tracking.
    State: [x, y, vx, vy] (position + velocity)
    """
    def __init__(self, initial_x, initial_y):
        # State vector: [x, y, vx, vy]
        self.state = np.array([initial_x, initial_y, 0.0, 0.0], dtype=np.float32)
        
        # Covariance matrix (uncertainty in state)
        self.P = np.eye(4, dtype=np.float32) * 100.0
        
        # Process noise (model uncertainty)
        self.Q = np.eye(4, dtype=np.float32) * PROCESS_NOISE
        
        # Measurement noise (detection uncertainty)
        self.R = np.eye(2, dtype=np.float32) * MEASUREMENT_NOISE
        
        # State transition matrix (constant velocity model)
        self.F = np.array([
            [1, 0, 1, 0],  # x_new = x + vx
            [0, 1, 0, 1],  # y_new = y + vy
            [0, 0, 1, 0],  # vx_new = vx
            [0, 0, 0, 1],  # vy_new = vy
        ], dtype=np.float32)
        
        # Measurement matrix (we only observe position, not velocity)
        self.H = np.array([
            [1, 0, 0, 0],  # measure x
            [0, 1, 0, 0],  # measure y
        ], dtype=np.float32)
    
    def predict(self):
        """Predict next state (called every frame)."""
        # State prediction
        self.state = self.F @ self.state
        
        # Covariance prediction
        self.P = self.F @ self.P @ self.F.T + self.Q
        
        return self.state[:2].copy()  # Return [x, y]
    
    def update(self, measurement_x, measurement_y):
        """Update with new detection."""
        z = np.array([measurement_x, measurement_y], dtype=np.float32)
        
        # Innovation (difference between measurement and prediction)
        y = z - (self.H @ self.state)
        
        # Innovation covariance
        S = self.H @ self.P @ self.H.T + self.R
        
        # Kalman gain (how much to trust the measurement)
        K = self.P @ self.H.T @ np.linalg.inv(S)
        
        # State update
        self.state = self.state + (K @ y)
        
        # Covariance update
        I = np.eye(4, dtype=np.float32)
        self.P = (I - K @ self.H) @ self.P
        
        return self.state[:2].copy()  # Return [x, y]
    
    def get_position(self):
        """Get current estimated position."""
        return self.state[:2].copy()
    
    def get_velocity(self):
        """Get current estimated velocity."""
        return self.state[2:].copy()

def create_tracker():
    """Create OpenCV tracker (fallback)."""
    for fn in (
        "legacy.TrackerCSRT_create",
        "TrackerCSRT_create",
        "legacy.TrackerKCF_create",
        "TrackerKCF_create"
    ):
        try:
            parts = fn.split(".")
            if len(parts) == 2:
                tracker = getattr(getattr(cv2, parts[0]), parts[1])()
            else:
                tracker = getattr(cv2, fn)()
            return tracker
        except Exception:
            pass
    return None

def calculate_perspective_zoom(ball_y, ball_speed):
    """Calculate zoom based on ball's Y position."""
    y_norm = ball_y / H
    
    if y_norm > NEAR_SIDE_THRESHOLD:
        distance_into_near = (y_norm - NEAR_SIDE_THRESHOLD) / (1.0 - NEAR_SIDE_THRESHOLD)
        zoom_adjust = -0.4 * distance_into_near
    elif y_norm < FAR_SIDE_THRESHOLD:
        distance_into_far = (FAR_SIDE_THRESHOLD - y_norm) / FAR_SIDE_THRESHOLD
        zoom_adjust = 0.3 * distance_into_far
    else:
        transition = (y_norm - FAR_SIDE_THRESHOLD) / (NEAR_SIDE_THRESHOLD - FAR_SIDE_THRESHOLD)
        zoom_adjust = 0.3 - (transition * 0.7)
    
    speed_adjust = -min(0.2, ball_speed / 100.0)
    zoom_target = ZOOM_BASE + zoom_adjust + speed_adjust
    zoom_target = np.clip(zoom_target, ZOOM_MIN, ZOOM_MAX)
    
    return zoom_target

def calculate_perspective_camera_offset(ball_y, cam_y_current):
    """Adjust camera Y position based on perspective."""
    y_norm = ball_y / H
    
    if y_norm > NEAR_SIDE_THRESHOLD:
        distance_into_near = (y_norm - NEAR_SIDE_THRESHOLD) / (1.0 - NEAR_SIDE_THRESHOLD)
        y_offset = H * 0.15 * distance_into_near
        return cam_y_current + y_offset
    elif y_norm < FAR_SIDE_THRESHOLD:
        distance_into_far = (FAR_SIDE_THRESHOLD - y_norm) / FAR_SIDE_THRESHOLD
        y_offset = -H * 0.05 * distance_into_far
        return cam_y_current + y_offset
    else:
        return cam_y_current

print(f"⚽ ACCURATE Ball Tracking with KALMAN FILTER")
print(f"📹 Input: {W}x{H} @ {FPS}fps")
print(f"📹 Output: {OUTPUT_WIDTH}x{OUTPUT_HEIGHT}")
print(f"🔍 Detection: Every {DETECT_EVERY} frames")
print(f"🎯 Kalman Filter: Process Noise={PROCESS_NOISE}, Measurement Noise={MEASUREMENT_NOISE}")
print(f"🏆 Using pre-loaded yolov8l model")

# Initialize state
frame_idx = 0
opencv_tracker = None
kalman_filter = None
ball_center = np.array([W/2, H/2], dtype=np.float32)
ball_history = []

# Camera state
cam_x, cam_y = W/2.0, H/2.0
zoom_current = ZOOM_BASE

# Stats
detections_count = 0
kalman_count = 0
opencv_tracker_count = 0

# Output video
codecs_to_try = [
    ('avc1', cv2.VideoWriter_fourcc(*'avc1')),
    ('H264', cv2.VideoWriter_fourcc(*'H264')),
    ('X264', cv2.VideoWriter_fourcc(*'X264')),
    ('mp4v', cv2.VideoWriter_fourcc(*'mp4v')),
]

out = None
working_codec = None

for codec_name, fourcc in codecs_to_try:
    out = cv2.VideoWriter(output_path, fourcc, FPS, (OUTPUT_WIDTH, OUTPUT_HEIGHT))
    if out.isOpened():
        working_codec = codec_name
        print(f"✅ Using codec: {codec_name}")
        break

if not out or not out.isOpened():
    raise RuntimeError("Cannot create output video")

tracker_ok_count = 0
t0 = time.time()

while True:
    ret, frame = cap.read()
    if not ret:
        break
    
    frame_idx += 1
    target_center = None
    detected_this_frame = False
    
    # KALMAN PREDICTION (every frame)
    if kalman_filter is not None:
        predicted_pos = kalman_filter.predict()
        target_center = predicted_pos
        kalman_count += 1
    
    # YOLO DETECTION (every N frames)
    do_detect = (kalman_filter is None) or (frame_idx % DETECT_EVERY == 1)
    
    if do_detect:
        if len(ball_history) > 0:
            roi_cx, roi_cy = int(ball_center[0]), int(ball_center[1])
        else:
            roi_cx, roi_cy = W // 2, H // 2
        
        x1 = max(0, roi_cx - ROI_SIZE // 2)
        y1 = max(0, roi_cy - ROI_SIZE // 2)
        x2 = min(W, roi_cx + ROI_SIZE // 2)
        y2 = min(H, roi_cy + ROI_SIZE // 2)
        
        # Safety check: ensure ROI has valid dimensions
        if x2 <= x1 or y2 <= y1:
            continue
        
        if (x2 - x1) < W * 0.8 and (y2 - y1) < H * 0.8:
            roi_frame = frame[y1:y2, x1:x2]
            roi_offset_x, roi_offset_y = x1, y1
        else:
            roi_frame = frame
            roi_offset_x, roi_offset_y = 0, 0
        
        # Safety check: ensure ROI is not empty
        if roi_frame is None or roi_frame.size == 0:
            continue
        
        results = model(roi_frame, conf=YOLO_CONF, imgsz=IMG_SZ, classes=[32], verbose=False)[0]
        boxes = results.boxes
        
        ball_dets = []
        
        if boxes is not None and len(boxes) > 0:
            for b in boxes:
                conf = float(b.conf[0])
                bx1, by1, bx2, by2 = map(int, b.xyxy[0].tolist())
                
                bx1 += roi_offset_x
                by1 += roi_offset_y
                bx2 += roi_offset_x
                by2 += roi_offset_y
                
                cx, cy = (bx1 + bx2) / 2, (by1 + by2) / 2
                dist = np.linalg.norm(np.array([cx, cy]) - ball_center)
                
                size = (bx2 - bx1) * (by2 - by1)
                if size > 3000:
                    size_score = 0.3
                elif size < 100:
                    size_score = 0.5
                else:
                    size_score = 1.0
                
                if len(ball_history) > 0:
                    proximity_score = 1.0 / (1.0 + dist / 200.0)
                else:
                    proximity_score = 1.0
                
                combined_score = conf * size_score * proximity_score
                ball_dets.append(((cx, cy), combined_score, (bx1, by1, bx2, by2), dist))
        
        if len(ball_dets) > 0:
            ball_dets.sort(key=lambda x: x[1], reverse=True)
            (cx, cy), score, (bx1, by1, bx2, by2), dist = ball_dets[0]
            
            # Initialize or update Kalman filter
            if kalman_filter is None:
                kalman_filter = KalmanBallTracker(cx, cy)
            else:
                kalman_filter.update(cx, cy)
            
            target_center = np.array([cx, cy], dtype=np.float32)
            detected_this_frame = True
            detections_count += 1
            
            # Re-initialize OpenCV tracker (fallback)
            bbox = (int(bx1), int(by1), int(bx2-bx1), int(by2-by1))
            tr = create_tracker()
            if tr is not None:
                try:
                    if tr.init(frame, bbox):
                        opencv_tracker = tr
                except Exception:
                    opencv_tracker = None
    
    # OPENCV TRACKER (fallback if Kalman seems wrong)
    if opencv_tracker is not None and not detected_this_frame and kalman_filter is not None:
        ok, box = opencv_tracker.update(frame)
        if ok:
            x, y, wbox, hbox = map(int, box)
            cx, cy = x + wbox/2, y + hbox/2
            
            # Check if OpenCV tracker agrees with Kalman
            kalman_pos = kalman_filter.get_position()
            dist = np.linalg.norm(np.array([cx, cy]) - kalman_pos)
            
            if dist > 200:  # They disagree - trust OpenCV tracker
                target_center = np.array([cx, cy], dtype=np.float32)
                opencv_tracker_count += 1
                # Update Kalman with OpenCV tracker position
                kalman_filter.update(cx, cy)
    
    # UPDATE BALL POSITION
    if target_center is not None:
        ball_center = target_center
        ball_history.append(ball_center.copy())
        if len(ball_history) > BALL_MEMORY:
            ball_history.pop(0)
    elif len(ball_history) > 0:
        ball_center = ball_history[-1].copy()
    
    # CAMERA MOVEMENT
    cam_x = cam_x * (1 - SMOOTH_CAM) + ball_center[0] * SMOOTH_CAM
    cam_y_target = ball_center[1]
    
    cam_y_adjusted = calculate_perspective_camera_offset(ball_center[1], cam_y_target)
    cam_y = cam_y * (1 - SMOOTH_CAM) + cam_y_adjusted * SMOOTH_CAM
    
    # PERSPECTIVE-AWARE ZOOM
    if kalman_filter is not None:
        velocity = kalman_filter.get_velocity()
        avg_speed = np.linalg.norm(velocity)
    else:
        avg_speed = 0
    
    zoom_target = calculate_perspective_zoom(ball_center[1], avg_speed)
    zoom_current = zoom_current * (1 - SMOOTH_ZOOM) + zoom_target * SMOOTH_ZOOM
    
    # CROP & RESIZE
    crop_w = int(W / zoom_current)
    crop_h = int(H / zoom_current)
    
    sx = int(np.clip(cam_x - crop_w//2, 0, W - crop_w))
    sy = int(np.clip(cam_y - crop_h//2, 0, H - crop_h))
    
    cropped = frame[sy:sy+crop_h, sx:sx+crop_w]
    out_frame = cv2.resize(cropped, (OUTPUT_WIDTH, OUTPUT_HEIGHT), interpolation=cv2.INTER_LINEAR)
    out.write(out_frame)
    
    # Progress update
    if frame_idx % max(10, int(FPS*3)) == 0:
        progress = int(20 + (frame_idx/TOTAL)*60)
        update_job("processing", progress=progress)

cap.release()
out.release()

processing_time = time.time() - t0
print(f"✅ Frame processing complete in {processing_time:.1f}s")

# FFMPEG POST-PROCESSING
print(f"🔄 Re-encoding with ffmpeg...")
update_job("processing", progress=85)

temp_output = output_path + ".temp.mp4"
os.rename(output_path, temp_output)

ffmpeg_cmd = [
    "ffmpeg", "-y",
    "-i", temp_output,
    "-c:v", "libx264",
    "-preset", "faster",
    "-crf", str(COMPRESSION_QUALITY),
    "-movflags", "+faststart",
    "-pix_fmt", "yuv420p",
    output_path
]

try:
    result = subprocess.run(ffmpeg_cmd, check=True, capture_output=True, text=True)
    os.remove(temp_output)
    output_size = os.path.getsize(output_path) / (1024*1024)
    print(f"✅ Ffmpeg re-encoding complete: {output_size:.1f} MB")
    update_job("processing", progress=95)
except subprocess.CalledProcessError as e:
    print(f"⚠️ Ffmpeg failed: {e.stderr}")
    if os.path.exists(temp_output):
        os.rename(temp_output, output_path)

# Metrics
total_tracked = detections_count + kalman_count
accuracy = int((total_tracked / max(1, TOTAL)) * 100)
elapsed = time.time() - t0

print(f"✅ Kalman Filter Ball Tracking complete in {elapsed:.1f}s")
print(f"✅ YOLO detections: {detections_count}/{TOTAL}")
print(f"✅ Kalman predictions: {kalman_count}/{TOTAL}")
print(f"✅ OpenCV tracker corrections: {opencv_tracker_count}/{TOTAL}")
print(f"✅ Total tracked: {total_tracked}/{TOTAL} ({accuracy}%)")
print(f"✅ Output: {OUTPUT_WIDTH}x{OUTPUT_HEIGHT}")

# Set metrics for dashboard
tracker_ok_count = total_tracked

