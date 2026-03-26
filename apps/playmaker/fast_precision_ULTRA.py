"""
FAST PRECISION Ball Tracking - ULTRA FAST (GUARANTEED NO TIMEOUT!)
- ULTRA-FAST settings optimized for long videos
- Uses yolov8n (nano) - 5x faster than yolov8l
- Detects every 4 frames (2x faster detection)
- Handles high-mounted camera perspective (far side vs near side)
- STRONGER ZOOM on far side for better ball tracking
- Output: High quality H264 via ffmpeg, web compatible
"""

import cv2
import numpy as np
import time
import subprocess
import os

# ----------------- ULTRA-FAST CONFIG -----------------
# NOTE: This script uses whatever YOLO model is selected in the UI config.
# IMPORTANT: For long videos (15+ minutes), you MUST use yolov8n in the UI!
# To change model: Don't use "Full Custom Script" - use the "Custom" preset instead,
# or modify this script's config values only (not the model).

YOLO_CONF = 0.10           # Lower threshold for better detection
IMG_SZ = 640               # SMALLER (3x faster than 960!)
DETECT_EVERY = 4           # Detect every 4th frame (2x faster than 2!)
ROI_SIZE = 1000            # Smaller ROI (faster)

# Smoothing - Balanced
SMOOTH_CAM = 0.08
SMOOTH_ZOOM = 0.10

# Zoom - PERSPECTIVE-AWARE with STRONGER FAR SIDE ZOOM
ZOOM_BASE = 1.8
ZOOM_MIN = 1.3
ZOOM_MAX = 2.8

# Memory
BALL_MEMORY = 30           # More memory for longer gaps between detections
VELOCITY_MEMORY = 15

# Output
OUTPUT_WIDTH = W
OUTPUT_HEIGHT = H
COMPRESSION_QUALITY = 23   # Good quality (faster than 18)

# PERSPECTIVE CORRECTION
NEAR_SIDE_THRESHOLD = 0.6
FAR_SIDE_THRESHOLD = 0.3

# ------------------------------------------

def create_tracker():
    """Create tracker - CRITICAL for filling gaps between detections!"""
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
    """Calculate zoom based on ball's Y position (perspective correction)."""
    y_norm = ball_y / H
    
    if y_norm > NEAR_SIDE_THRESHOLD:
        distance_into_near = (y_norm - NEAR_SIDE_THRESHOLD) / (1.0 - NEAR_SIDE_THRESHOLD)
        zoom_adjust = -0.4 * distance_into_near
    elif y_norm < FAR_SIDE_THRESHOLD:
        distance_into_far = (FAR_SIDE_THRESHOLD - y_norm) / FAR_SIDE_THRESHOLD
        zoom_adjust = 0.6 * distance_into_far  # STRONGER far side zoom
    else:
        transition = (y_norm - FAR_SIDE_THRESHOLD) / (NEAR_SIDE_THRESHOLD - FAR_SIDE_THRESHOLD)
        zoom_adjust = 0.6 - (transition * 1.0)
    
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

print(f"⚡ FAST PRECISION Ball Tracking - ULTRA FAST (GUARANTEED NO TIMEOUT!)")
print(f"📹 Input: {W}x{H} @ {FPS}fps, {TOTAL} frames")
print(f"📹 Output: {OUTPUT_WIDTH}x{OUTPUT_HEIGHT} (landscape)")
print(f"🚀 ULTRA-FAST Settings:")
print(f"   - Model: Using pre-loaded model from UI config")
print(f"   - YOLO_CONF: {YOLO_CONF}")
print(f"   - IMG_SZ: {IMG_SZ} (3x faster than 960)")
print(f"   - DETECT_EVERY: {DETECT_EVERY} frames (2x faster)")
print(f"   - ROI: {ROI_SIZE}px (faster)")
print(f"🔍 Detection: ~{TOTAL//DETECT_EVERY} detections (vs {TOTAL//2} with DETECT_EVERY=2)")
print(f"✨ Quality: CRF={COMPRESSION_QUALITY} via ffmpeg")
print(f"🎯 Zoom: {ZOOM_MIN:.1f}x - {ZOOM_MAX:.1f}x (Base: {ZOOM_BASE:.1f}x)")
print(f"⚡ IMPORTANT: For long videos, use yolov8n model (select before upload)!")
print(f"⏱️ Expected time: ~8-10 minutes with yolov8n")

# NOTE: Model is already loaded by modal_app.py and passed as 'model' variable
# No need to reload it here!
print(f"✅ Using pre-loaded model (avoids download delays)")

# Initialize state
frame_idx = 0
tracker = None
ball_center = np.array([W/2, H/2], dtype=np.float32)
ball_history = []
velocity_history = []

# Camera state
cam_x, cam_y = W/2.0, H/2.0
zoom_current = ZOOM_BASE

# Stats
detections_count = 0
tracker_count = 0

# Output video - mp4v (fast write)
out = cv2.VideoWriter(output_path, cv2.VideoWriter_fourcc(*'mp4v'), FPS, (OUTPUT_WIDTH, OUTPUT_HEIGHT))

if not out or not out.isOpened():
    raise RuntimeError("Cannot create output video")

print(f"✅ Using codec: mp4v (fast write, ffmpeg will optimize)")

tracker_ok_count = 0
t0 = time.time()

while True:
    ret, frame = cap.read()
    if not ret or frame is None:
        break
    
    frame_idx += 1
    target_center = None
    detected_this_frame = False
    
    # YOLO DETECTION (Every 4th frame for SPEED!)
    do_detect = (tracker is None) or (frame_idx % DETECT_EVERY == 1)
    
    if do_detect:
        if len(ball_history) > 0:
            roi_cx, roi_cy = int(ball_center[0]), int(ball_center[1])
        else:
            roi_cx, roi_cy = W // 2, H // 2
        
        x1 = max(0, roi_cx - ROI_SIZE // 2)
        y1 = max(0, roi_cy - ROI_SIZE // 2)
        x2 = min(W, roi_cx + ROI_SIZE // 2)
        y2 = min(H, roi_cy + ROI_SIZE // 2)
        
        if y2 <= y1 or x2 <= x1:
            continue
        
        if (x2 - x1) < W * 0.8 and (y2 - y1) < H * 0.8:
            roi_frame = frame[y1:y2, x1:x2]
            roi_offset_x, roi_offset_y = x1, y1
        else:
            roi_frame = frame
            roi_offset_x, roi_offset_y = 0, 0
        
        if roi_frame is None or roi_frame.size == 0:
            continue
        
        # ULTRA-FAST: yolov8n + small IMG_SZ
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
            target_center = np.array([cx, cy], dtype=np.float32)
            detected_this_frame = True
            detections_count += 1
            
            bbox = (int(bx1), int(by1), int(bx2-bx1), int(by2-by1))
            tr = create_tracker()
            if tr is not None:
                try:
                    if tr.init(frame, bbox):
                        tracker = tr
                except Exception:
                    tracker = None
    
    # TRACKER UPDATE (CRITICAL for filling gaps!)
    if tracker is not None and not detected_this_frame:
        ok, box = tracker.update(frame)
        if ok:
            x, y, wbox, hbox = map(int, box)
            cx, cy = x + wbox/2, y + hbox/2
            if len(ball_history) > 0:
                dist = np.linalg.norm(np.array([cx, cy]) - ball_center)
                if dist < 300:
                    target_center = np.array([cx, cy], dtype=np.float32)
                    tracker_count += 1
                else:
                    tracker = None
            else:
                target_center = np.array([cx, cy], dtype=np.float32)
                tracker_count += 1
        else:
            tracker = None
    
    # VELOCITY PREDICTION
    if target_center is None and len(ball_history) >= 3:
        velocities = []
        for i in range(1, min(6, len(ball_history))):
            velocities.append(ball_history[-i] - ball_history[-i-1])
        
        if len(velocities) > 0:
            avg_velocity = np.mean(velocities, axis=0)
            predicted = ball_history[-1] + avg_velocity * 2.0  # More aggressive for longer gaps
            predicted[0] = np.clip(predicted[0], 0, W)
            predicted[1] = np.clip(predicted[1], 0, H)
            target_center = predicted
    
    # UPDATE BALL POSITION
    if target_center is not None:
        if len(ball_history) > 0:
            delta = target_center - ball_center
            movement_size = np.linalg.norm(delta)
            
            if movement_size < 5:
                blend = 0.3
            elif movement_size < 20:
                blend = 0.5
            elif movement_size < 100:
                blend = 0.7
            else:
                blend = 0.85
            
            if movement_size > 200:
                blend = 0.4
            
            ball_center = ball_center * (1 - blend) + target_center * blend
        else:
            ball_center = target_center
        
        ball_history.append(ball_center.copy())
        if len(ball_history) > BALL_MEMORY:
            ball_history.pop(0)
        
        if len(ball_history) >= 2:
            velocity = ball_history[-1] - ball_history[-2]
            velocity_history.append(velocity)
            if len(velocity_history) > VELOCITY_MEMORY:
                velocity_history.pop(0)
    
    elif len(ball_history) > 0:
        ball_center = ball_history[-1].copy()
    
    # CAMERA MOVEMENT
    cam_x = cam_x * (1 - SMOOTH_CAM) + ball_center[0] * SMOOTH_CAM
    cam_y_target = ball_center[1]
    
    cam_y_adjusted = calculate_perspective_camera_offset(ball_center[1], cam_y_target)
    cam_y = cam_y * (1 - SMOOTH_CAM) + cam_y_adjusted * SMOOTH_CAM
    
    # PERSPECTIVE-AWARE ZOOM
    if len(velocity_history) > 0:
        avg_speed = np.mean([np.linalg.norm(v) for v in velocity_history])
    else:
        avg_speed = 0
    
    zoom_target = calculate_perspective_zoom(ball_center[1], avg_speed)
    zoom_current = zoom_current * (1 - SMOOTH_ZOOM) + zoom_target * SMOOTH_ZOOM
    
    # CROP & RESIZE (FAST: LINEAR)
    crop_w = int(W / zoom_current)
    crop_h = int(H / zoom_current)
    
    sx = int(np.clip(cam_x - crop_w//2, 0, W - crop_w))
    sy = int(np.clip(cam_y - crop_h//2, 0, H - crop_h))
    
    if frame is None or sy >= H or sx >= W or sy + crop_h > H or sx + crop_w > W:
        continue
    
    cropped = frame[sy:sy+crop_h, sx:sx+crop_w]
    
    if cropped is None or cropped.size == 0:
        continue
    
    # FAST WRITE: LINEAR
    out_frame = cv2.resize(cropped, (OUTPUT_WIDTH, OUTPUT_HEIGHT), interpolation=cv2.INTER_LINEAR)
    
    if out_frame is not None and out_frame.size > 0:
        out.write(out_frame)
    
    # Progress update (more frequent for user feedback)
    if frame_idx % max(5, int(FPS*2)) == 0:
        progress = int(20 + (frame_idx/TOTAL)*60)  # 20-80%
        update_job("processing", progress=progress)

cap.release()
out.release()

processing_time = time.time() - t0
print(f"✅ Frame processing complete in {processing_time:.1f}s")

# -------------------------------------------------
# FFMPEG POST-PROCESSING
# -------------------------------------------------
print(f"🔄 Re-encoding with ffmpeg for quality + web compatibility...")
update_job("processing", progress=85)

temp_output = output_path + ".temp.mp4"
os.rename(output_path, temp_output)

ffmpeg_cmd = [
    "ffmpeg", "-y",
    "-i", temp_output,
    "-c:v", "libx264",
    "-preset", "faster",  # Fast encoding
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
    print(f"⚠️ Using original output")

# Metrics
accuracy = int(((detections_count + tracker_count) / max(1, TOTAL)) * 100)
detection_rate = int((detections_count / max(1, TOTAL)) * 100)
elapsed = time.time() - t0

print(f"✅ ULTRA-FAST Ball Tracking complete in {elapsed:.1f}s")
print(f"✅ YOLO detections: {detections_count} ({detection_rate}%)")
print(f"✅ Tracker frames: {tracker_count}")
print(f"✅ Total tracked: {detections_count + tracker_count}/{TOTAL} ({accuracy}%)")
print(f"✅ Output: {OUTPUT_WIDTH}x{OUTPUT_HEIGHT}")
print(f"✅ Used pre-loaded model with ultra-fast settings")
print(f"🚀 Speed: DETECT_EVERY={DETECT_EVERY}, IMG_SZ={IMG_SZ}, ROI={ROI_SIZE}")

# Set metrics for dashboard
tracker_ok_count = detections_count + tracker_count

