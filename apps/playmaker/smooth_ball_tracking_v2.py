"""
ULTRA-SMOOTH Ball Tracking with Player Heuristics
- Improved camera smoothing (temporal consistency)
- Zoom smoothing (no jitter)
- ROI-based detection (faster)
- Better fallback prediction
- Temporal filtering
"""

import cv2
import numpy as np
import time

# ----------------- CONFIG -----------------
YOLO_CONF = 0.30
IMG_SZ = 640
DETECT_EVERY = 5           # Detect every 5 frames
ROI_SIZE = 800             # ROI size for faster detection

# Camera smoothing (LOWER = SMOOTHER)
SMOOTH_CAM = 0.06          # Camera position smoothing (was 0.12)
SMOOTH_ZOOM = 0.08         # Zoom smoothing (NEW!)
SMOOTH_BALL = 0.15         # Ball position smoothing when lost

# Zoom parameters
ZOOM_BASE = 1.6
ZOOM_MIN = 1.3
ZOOM_MAX = 1.9

# Memory
BALL_MEMORY = 8
PLAYER_VEL_MEMORY = 6
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

# Initialize state
frame_idx = 0
tracker = None
ball_center = np.array([W/2, H/2], dtype=np.float32)
ball_history = []
lost_frames = 0
players_memory = []

# Camera state (smoothed)
cam_x, cam_y = W/2.0, H/2.0
zoom_current = ZOOM_BASE  # Current zoom (smoothed)

# Output video
fourcc = cv2.VideoWriter_fourcc(*"mp4v")
out = cv2.VideoWriter(output_path, fourcc, FPS, (W, H))

tracker_ok_count = 0
t0 = time.time()

print(f"⚽ Ultra-Smooth Ball Tracking ({W}x{H} @ {FPS}fps)")
print(f"📊 Config: YOLO Conf={YOLO_CONF}, ROI={ROI_SIZE}px, Detect Every={DETECT_EVERY}")

while True:
    ret, frame = cap.read()
    if not ret:
        break
    
    frame_idx += 1
    target_center = None
    do_detect = (tracker is None) or (frame_idx % DETECT_EVERY == 1)
    
    # -------------------------------------------------
    # YOLO DETECTION (with ROI optimization)
    # -------------------------------------------------
    if do_detect:
        # Define ROI around last known ball position
        roi_cx, roi_cy = int(ball_center[0]), int(ball_center[1])
        x1 = max(0, roi_cx - ROI_SIZE // 2)
        y1 = max(0, roi_cy - ROI_SIZE // 2)
        x2 = min(W, roi_cx + ROI_SIZE // 2)
        y2 = min(H, roi_cy + ROI_SIZE // 2)
        
        # Use ROI for detection (faster!)
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
                
                # Convert ROI coordinates back to full frame
                if roi_frame.shape != frame.shape:
                    bx1 += x1
                    by1 += y1
                    bx2 += x1
                    by2 += y1
                
                cx, cy = (bx1 + bx2) / 2, (by1 + by2) / 2
                
                if cls == 32:  # Ball
                    # Prioritize detections near last known position
                    dist = np.linalg.norm(np.array([cx, cy]) - ball_center)
                    ball_dets.append(((cx, cy), conf, (bx1, by1, bx2, by2), dist))
                elif cls == 0:  # Person
                    players.append(np.array([cx, cy], dtype=np.float32))
        
        # Store player centers for motion prediction
        players_memory.append(players)
        if len(players_memory) > PLAYER_VEL_MEMORY:
            players_memory.pop(0)
        
        # Best ball detection (prioritize confidence + proximity)
        if len(ball_dets) > 0:
            # Sort by confidence, but prefer nearby detections
            ball_dets.sort(key=lambda x: x[1] * (1.0 + 0.01 * max(0, 200 - x[3])), reverse=True)
            (cx, cy), conf, (bx1, by1, bx2, by2), dist = ball_dets[0]
            target_center = np.array([cx, cy], dtype=np.float32)
            
            # Init tracker
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
    # TEMPORAL SMOOTHING & FALLBACK
    # -------------------------------------------------
    if target_center is not None:
        # Smooth ball position (temporal filter)
        if len(ball_history) > 0:
            # Don't jump too far from last position
            delta = target_center - ball_center
            max_jump = 100  # Max pixels per frame
            if np.linalg.norm(delta) > max_jump:
                # Likely false detection, smooth heavily
                ball_center = ball_center + 0.3 * delta
            else:
                # Good detection, update normally
                ball_center = ball_center * 0.7 + target_center * 0.3
        else:
            ball_center = target_center
        
        ball_history.append(ball_center.copy())
        if len(ball_history) > BALL_MEMORY:
            ball_history.pop(0)
    else:
        # Ball lost - use prediction
        lost_frames += 1
        predicted = None
        
        # 1. Predict using ball velocity (smoothed)
        if len(ball_history) >= 3:
            # Use average velocity of last 3 frames (smoother)
            velocities = []
            for i in range(1, min(4, len(ball_history))):
                velocities.append(ball_history[-i] - ball_history[-i-1])
            avg_vel = np.mean(velocities, axis=0)
            predicted = ball_history[-1] + avg_vel * 1.2  # Anticipate
        
        # 2. Predict using player group motion (smoothed)
        if len(players_memory) >= 3:
            avg_positions = []
            for pl in players_memory:
                if len(pl) > 0:
                    avg_positions.append(np.mean(pl, axis=0))
            
            if len(avg_positions) >= 3:
                # Smooth player velocity
                v1 = avg_positions[-1] - avg_positions[-2]
                v2 = avg_positions[-2] - avg_positions[-3]
                v_players = (v1 + v2) / 2  # Average velocity
                vote = avg_positions[-1] + v_players * 0.6
                
                if predicted is None:
                    predicted = vote
                else:
                    # Blend ball velocity + player motion
                    predicted = 0.7*predicted + 0.3*vote
        
        # 3. Fallback: keep last position with decay
        if predicted is None and len(ball_history) > 0:
            predicted = ball_history[-1]
        
        # Apply prediction with heavy smoothing
        if predicted is not None:
            ball_center = ball_center * (1 - SMOOTH_BALL) + predicted * SMOOTH_BALL
            ball_history.append(ball_center.copy())
            if len(ball_history) > BALL_MEMORY:
                ball_history.pop(0)
    
    # -------------------------------------------------
    # ULTRA-SMOOTH CAMERA (Exponential smoothing)
    # -------------------------------------------------
    cam_x = cam_x * (1 - SMOOTH_CAM) + ball_center[0] * SMOOTH_CAM
    cam_y = cam_y * (1 - SMOOTH_CAM) + ball_center[1] * SMOOTH_CAM
    
    # -------------------------------------------------
    # SMOOTH ZOOM (Dynamic with temporal filter)
    # -------------------------------------------------
    # Factor 1: Ball speed
    speed = 0.0
    if len(ball_history) >= 2:
        speed = np.linalg.norm(ball_history[-1] - ball_history[-2])
    
    # Factor 2: Distance from center
    dist_center = np.linalg.norm(np.array([cam_x, cam_y]) - np.array([W/2, H/2]))
    norm_dist = np.clip(dist_center / (W*0.4), 0, 1)
    
    # Compute target zoom
    zoom_target = ZOOM_BASE
    zoom_target += (ZOOM_MAX - ZOOM_BASE) * (1 - norm_dist) * 0.5  # Zoom in near center
    zoom_target -= min(0.3, speed / 80.0)  # Zoom out when ball is fast
    zoom_target = np.clip(zoom_target, ZOOM_MIN, ZOOM_MAX)
    
    # SMOOTH ZOOM (exponential smoothing - key to no jitter!)
    zoom_current = zoom_current * (1 - SMOOTH_ZOOM) + zoom_target * SMOOTH_ZOOM
    
    # -------------------------------------------------
    # CROP & RESIZE
    # -------------------------------------------------
    crop_w = int(W / zoom_current)
    crop_h = int(H / zoom_current)
    sx = int(np.clip(cam_x - crop_w//2, 0, W - crop_w))
    sy = int(np.clip(cam_y - crop_h//2, 0, H - crop_h))
    
    cropped = frame[sy:sy+crop_h, sx:sx+crop_w]
    out_frame = cv2.resize(cropped, (W, H), interpolation=cv2.INTER_LINEAR)
    out.write(out_frame)
    
    # Progress update
    if frame_idx % max(10, int(FPS*3)) == 0:
        progress = int(20 + (frame_idx/TOTAL)*70)
        update_job("processing", progress=progress)

cap.release()
out.release()

# Dashboard metrics
accuracy = int((tracker_ok_count / max(1, TOTAL)) * 100)
elapsed = time.time() - t0

print(f"✅ Processing complete in {elapsed:.1f}s")
print(f"✅ Tracker OK frames: {tracker_ok_count}/{TOTAL} ({accuracy}%)")
print(f"✅ Lost frames handled: {TOTAL - tracker_ok_count}")
print(f"✅ Output: {output_path}")

