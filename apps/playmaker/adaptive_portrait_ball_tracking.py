"""
ADAPTIVE SPEED + PORTRAIT Ball Tracking
- Fast tracking when ball is shot (responsive!)
- Smooth tracking when ball is slow (cinematic!)
- Portrait mode for phone viewing (1080x1920)
- Enhanced detection for better ball finding
- Optimized for Reolink wide-angle cameras
"""

import cv2
import numpy as np
import time

# ----------------- CONFIG -----------------
YOLO_CONF = 0.15           # Lower for better detection (was 0.25)
IMG_SZ = 960               # Detection resolution
DETECT_EVERY = 2           # More frequent (was 5) - better tracking
ROI_SIZE = 1500            # Larger ROI (was 1000) - finds ball easier

# === ADAPTIVE SMOOTHING (Changes based on ball speed!) ===
SMOOTH_CAM_SLOW = 0.03     # Ultra-smooth when ball is slow
SMOOTH_CAM_FAST = 0.12     # Responsive when ball is fast
SMOOTH_ZOOM_SLOW = 0.04    # Smooth zoom when slow
SMOOTH_ZOOM_FAST = 0.10    # Fast zoom when ball is fast
SPEED_THRESHOLD = 15       # Speed threshold to switch modes (pixels/frame)
# ========================================================

# === PORTRAIT MODE (Perfect for phones!) ===
PORTRAIT_MODE = True       # Set to False for landscape
PORTRAIT_WIDTH = 1080      # Width for portrait
PORTRAIT_HEIGHT = 1920     # Height for portrait (9:16 ratio)
# ==========================================

# === ZOOM for Wide-Angle ===
ZOOM_BASE = 2.4            # Slightly higher for portrait
ZOOM_MIN = 2.0             # Minimum zoom
ZOOM_MAX = 3.0             # Maximum zoom
# ==========================

# Memory for predictions
BALL_MEMORY = 15           # More memory for better speed detection
PLAYER_VEL_MEMORY = 10

# Compression
COMPRESSION_QUALITY = 26   # Good quality

# ------------------------------------------

def create_tracker():
    """Create tracker compatible with all OpenCV builds."""
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

# Determine output resolution
if PORTRAIT_MODE:
    out_w, out_h = PORTRAIT_WIDTH, PORTRAIT_HEIGHT
    print(f"📱 Portrait Mode: {out_w}x{out_h} (9:16 for phones!)")
else:
    out_w, out_h = W, H
    print(f"📺 Landscape Mode: {out_w}x{out_h}")

print(f"🎥 Adaptive Speed Ball Tracking")
print(f"📹 Input: {W}x{H} @ {FPS}fps")
print(f"🚀 Adaptive: Smooth ({SMOOTH_CAM_SLOW}) ↔ Fast ({SMOOTH_CAM_FAST})")
print(f"🔍 Enhanced Detection: Conf={YOLO_CONF}, ROI={ROI_SIZE}px")
print(f"🔍 Zoom: {ZOOM_MIN:.1f}x - {ZOOM_MAX:.1f}x (Base: {ZOOM_BASE:.1f}x)")

# Initialize state
frame_idx = 0
tracker = None
ball_center = np.array([W/2, H/2], dtype=np.float32)
ball_history = []
lost_frames = 0
players_memory = []

# Camera state
cam_x, cam_y = W/2.0, H/2.0
zoom_current = ZOOM_BASE

# Current ball speed (for adaptive smoothing)
ball_speed = 0.0

# Output video with H264 codec
codecs_to_try = [
    ('avc1', cv2.VideoWriter_fourcc(*'avc1')),
    ('H264', cv2.VideoWriter_fourcc(*'H264')),
    ('X264', cv2.VideoWriter_fourcc(*'X264')),
    ('mp4v', cv2.VideoWriter_fourcc(*'mp4v')),
]

out = None
working_codec = None

for codec_name, fourcc in codecs_to_try:
    out = cv2.VideoWriter(output_path, fourcc, FPS, (out_w, out_h))
    if out.isOpened():
        working_codec = codec_name
        print(f"✅ Using codec: {codec_name}")
        break

if not out or not out.isOpened():
    raise RuntimeError("Cannot create output video")

tracker_ok_count = 0
fast_mode_frames = 0  # Count frames in fast mode
t0 = time.time()

while True:
    ret, frame = cap.read()
    if not ret:
        break
    
    frame_idx += 1
    target_center = None
    do_detect = (tracker is None) or (frame_idx % DETECT_EVERY == 1)
    
    # -------------------------------------------------
    # YOLO DETECTION (Enhanced with larger ROI)
    # -------------------------------------------------
    if do_detect:
        roi_cx, roi_cy = int(ball_center[0]), int(ball_center[1])
        x1 = max(0, roi_cx - ROI_SIZE // 2)
        y1 = max(0, roi_cy - ROI_SIZE // 2)
        x2 = min(W, roi_cx + ROI_SIZE // 2)
        y2 = min(H, roi_cy + ROI_SIZE // 2)
        
        roi_frame = frame[y1:y2, x1:x2] if (x2 > x1 and y2 > y1) else frame
        
        results = model(roi_frame, conf=YOLO_CONF, imgsz=IMG_SZ, classes=[32, 0])[0]
        boxes = results.boxes
        
        ball_dets = []
        players = []
        
        if boxes is not None:
            for b in boxes:
                cls = int(b.cls[0])
                conf = float(b.conf[0])
                bx1, by1, bx2, by2 = map(int, b.xyxy[0].tolist())
                
                if roi_frame.shape != frame.shape:
                    bx1 += x1
                    by1 += y1
                    bx2 += x1
                    by2 += y1
                
                cx, cy = (bx1 + bx2) / 2, (by1 + by2) / 2
                
                if cls == 32:  # Ball
                    dist = np.linalg.norm(np.array([cx, cy]) - ball_center)
                    size = (bx2 - bx1) * (by2 - by1)
                    size_score = 1.0 if size < 2000 else 0.6  # Slightly larger threshold
                    ball_dets.append(((cx, cy), conf * size_score, (bx1, by1, bx2, by2), dist))
                elif cls == 0:  # Person
                    players.append(np.array([cx, cy], dtype=np.float32))
        
        players_memory.append(players)
        if len(players_memory) > PLAYER_VEL_MEMORY:
            players_memory.pop(0)
        
        if len(ball_dets) > 0:
            ball_dets.sort(key=lambda x: x[1] * (1.0 + 0.01 * max(0, 400 - x[3])), reverse=True)
            (cx, cy), conf, (bx1, by1, bx2, by2), dist = ball_dets[0]
            target_center = np.array([cx, cy], dtype=np.float32)
            
            bbox = (int(bx1), int(by1), int(bx2-bx1), int(by2-by1))
            tr = create_tracker()
            if tr is not None:
                try:
                    if tr.init(frame, bbox):
                        tracker = tr
                        lost_frames = 0
                except Exception:
                    tracker = None
    
    # -------------------------------------------------
    # TRACKER UPDATE
    # -------------------------------------------------
    if tracker is not None:
        ok, box = tracker.update(frame)
        if ok:
            x, y, wbox, hbox = map(int, box)
            cx, cy = x + wbox/2, y + hbox/2
            target_center = np.array([cx, cy], dtype=np.float32)
            tracker_ok_count += 1
            lost_frames = 0
        else:
            tracker = None
            lost_frames += 1
    
    # -------------------------------------------------
    # CALCULATE BALL SPEED (for adaptive smoothing)
    # -------------------------------------------------
    if len(ball_history) >= 2:
        # Average speed over last 3 frames for stability
        speeds = []
        for i in range(1, min(4, len(ball_history))):
            speeds.append(np.linalg.norm(ball_history[-i] - ball_history[-i-1]))
        ball_speed = np.mean(speeds)
    else:
        ball_speed = 0.0
    
    # -------------------------------------------------
    # ADAPTIVE SMOOTHING (Changes based on speed!)
    # -------------------------------------------------
    is_fast_mode = ball_speed > SPEED_THRESHOLD
    
    if is_fast_mode:
        # FAST MODE: Ball is moving quickly (shot, pass, etc.)
        SMOOTH_CAM = SMOOTH_CAM_FAST
        SMOOTH_ZOOM = SMOOTH_ZOOM_FAST
        fast_mode_frames += 1
    else:
        # SMOOTH MODE: Ball is moving slowly or stationary
        SMOOTH_CAM = SMOOTH_CAM_SLOW
        SMOOTH_ZOOM = SMOOTH_ZOOM_SLOW
    
    # -------------------------------------------------
    # TEMPORAL FILTERING
    # -------------------------------------------------
    if target_center is not None:
        if len(ball_history) > 0:
            delta = target_center - ball_center
            max_jump = 150  # Larger for fast movements
            
            if np.linalg.norm(delta) > max_jump:
                ball_center = ball_center + 0.25 * delta
            else:
                # Use adaptive blending
                if is_fast_mode:
                    ball_center = ball_center * 0.50 + target_center * 0.50  # More responsive
                else:
                    ball_center = ball_center * 0.70 + target_center * 0.30  # Smoother
        else:
            ball_center = target_center
        
        ball_history.append(ball_center.copy())
        if len(ball_history) > BALL_MEMORY:
            ball_history.pop(0)
    else:
        lost_frames += 1
        predicted = None
        
        # Enhanced prediction with more frames
        if len(ball_history) >= 5:
            velocities = []
            for i in range(1, min(6, len(ball_history))):
                velocities.append(ball_history[-i] - ball_history[-i-1])
            avg_vel = np.mean(velocities, axis=0)
            # Stronger prediction when in fast mode
            prediction_strength = 1.5 if is_fast_mode else 1.2
            predicted = ball_history[-1] + avg_vel * prediction_strength
        
        # Player motion prediction
        if len(players_memory) >= 4:
            avg_positions = []
            for pl in players_memory:
                if len(pl) > 0:
                    avg_positions.append(np.mean(pl, axis=0))
            
            if len(avg_positions) >= 4:
                velocities = []
                for i in range(1, min(4, len(avg_positions))):
                    velocities.append(avg_positions[-i] - avg_positions[-i-1])
                v_players = np.mean(velocities, axis=0)
                vote = avg_positions[-1] + v_players * 0.6
                
                if predicted is None:
                    predicted = vote
                else:
                    predicted = 0.70*predicted + 0.30*vote
        
        if predicted is None and len(ball_history) > 0:
            predicted = ball_history[-1]
        
        if predicted is not None:
            smooth_factor = 0.15 if is_fast_mode else 0.10
            ball_center = ball_center * (1 - smooth_factor) + predicted * smooth_factor
            ball_history.append(ball_center.copy())
            if len(ball_history) > BALL_MEMORY:
                ball_history.pop(0)
    
    # -------------------------------------------------
    # ADAPTIVE CAMERA (Uses adaptive smoothing)
    # -------------------------------------------------
    cam_x = cam_x * (1 - SMOOTH_CAM) + ball_center[0] * SMOOTH_CAM
    cam_y = cam_y * (1 - SMOOTH_CAM) + ball_center[1] * SMOOTH_CAM
    
    # -------------------------------------------------
    # ADAPTIVE ZOOM
    # -------------------------------------------------
    dist_center = np.linalg.norm(np.array([cam_x, cam_y]) - np.array([W/2, H/2]))
    norm_dist = np.clip(dist_center / (W*0.3), 0, 1)
    
    zoom_target = ZOOM_BASE
    zoom_target += (ZOOM_MAX - ZOOM_BASE) * (1 - norm_dist) * 0.7
    zoom_target -= min(0.3, ball_speed / 120.0)  # Less zoom-out when fast
    zoom_target = np.clip(zoom_target, ZOOM_MIN, ZOOM_MAX)
    
    zoom_current = zoom_current * (1 - SMOOTH_ZOOM) + zoom_target * SMOOTH_ZOOM
    
    # -------------------------------------------------
    # CROP & RESIZE (Portrait mode!)
    # -------------------------------------------------
    crop_w = int(W / zoom_current)
    crop_h = int(H / zoom_current)
    sx = int(np.clip(cam_x - crop_w//2, 0, W - crop_w))
    sy = int(np.clip(cam_y - crop_h//2, 0, H - crop_h))
    
    cropped = frame[sy:sy+crop_h, sx:sx+crop_w]
    
    # For portrait mode, we need to handle aspect ratio
    if PORTRAIT_MODE:
        # Crop to portrait aspect ratio (9:16)
        target_aspect = out_w / out_h  # 1080/1920 = 0.5625
        current_aspect = crop_w / crop_h
        
        if current_aspect > target_aspect:
            # Too wide, crop width
            new_crop_w = int(crop_h * target_aspect)
            offset = (crop_w - new_crop_w) // 2
            if offset > 0 and offset + new_crop_w <= crop_w:
                cropped = cropped[:, offset:offset+new_crop_w]
        elif current_aspect < target_aspect:
            # Too tall, crop height
            new_crop_h = int(crop_w / target_aspect)
            offset = (crop_h - new_crop_h) // 2
            if offset > 0 and offset + new_crop_h <= crop_h:
                cropped = cropped[offset:offset+new_crop_h, :]
    
    # Resize to output resolution
    out_frame = cv2.resize(cropped, (out_w, out_h), interpolation=cv2.INTER_LANCZOS4)
    out.write(out_frame)
    
    # Progress update
    if frame_idx % max(10, int(FPS*3)) == 0:
        progress = int(20 + (frame_idx/TOTAL)*70)
        update_job("processing", progress=progress)

cap.release()
out.release()

# Dashboard metrics
accuracy = int((tracker_ok_count / max(1, TOTAL)) * 100)
fast_mode_percent = int((fast_mode_frames / max(1, TOTAL)) * 100)
elapsed = time.time() - t0

print(f"✅ Adaptive Portrait Tracking complete in {elapsed:.1f}s")
print(f"✅ Tracker OK frames: {tracker_ok_count}/{TOTAL} ({accuracy}%)")
print(f"✅ Fast mode used: {fast_mode_percent}% of frames")
print(f"✅ Output: {out_w}x{out_h} ({'Portrait' if PORTRAIT_MODE else 'Landscape'})")
print(f"✅ Speed: {ball_speed:.1f} px/frame (threshold: {SPEED_THRESHOLD})")
print(f"✅ Codec: {working_codec}, CRF={COMPRESSION_QUALITY}")

