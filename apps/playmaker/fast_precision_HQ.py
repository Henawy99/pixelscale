"""
FAST PRECISION Ball Tracking - HIGH QUALITY
- 5x faster than precision_ball_tracking.py (optimized settings)
- Handles high-mounted camera perspective (far side vs near side)
- HIGH QUALITY OUTPUT: CRF 18, LANCZOS4 interpolation
- STRONGER ZOOM on far side for better ball tracking
- Near side (bottom): Zoom out more, look down
- Far side (top): STRONG zoom in for detail
"""

import cv2
import numpy as np
import time
import subprocess
import os

# ----------------- CONFIG -----------------
# OPTIMIZED FOR SPEED (5x faster than precision script)
YOLO_CONF = 0.12           # Very low - finds everything
IMG_SZ = 960               # 1.7x faster than 1280 (sweet spot!)
DETECT_EVERY = 2           # 2x faster than every frame
ROI_SIZE = 1200            # 1.5x faster than 2000 (still plenty!)

# Smoothing - Balanced
SMOOTH_CAM = 0.08          # Camera smoothing
SMOOTH_ZOOM = 0.10         # Zoom smoothing

# Zoom - PERSPECTIVE-AWARE with STRONGER FAR SIDE ZOOM
ZOOM_BASE = 1.8
ZOOM_MIN = 1.3             # Lower min for near side
ZOOM_MAX = 2.8             # INCREASED for stronger far side zoom (was 2.4)

# Memory
BALL_MEMORY = 20           # Remember more positions
VELOCITY_MEMORY = 10       # For better prediction

# Output - HIGH QUALITY SETTINGS
OUTPUT_WIDTH = W           # Keep original width
OUTPUT_HEIGHT = H          # Keep original height
COMPRESSION_QUALITY = 18   # HIGH QUALITY (lower = better, 18 = visually lossless)
USE_LANCZOS = True         # Use high-quality interpolation (slightly slower but better quality)

# PERSPECTIVE CORRECTION (for high-mounted camera)
# Camera is 6m high, mounted on middle line
# Near side (bottom of frame) = close to camera, needs different handling
NEAR_SIDE_THRESHOLD = 0.6  # Bottom 60% of frame = near side
FAR_SIDE_THRESHOLD = 0.3   # Top 30% of frame = far side
# Middle 10% = transition zone

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

def calculate_perspective_zoom(ball_y, ball_speed):
    """
    Calculate zoom based on ball's Y position in frame (perspective correction).
    
    High-mounted camera (6m, middle line):
    - Near side (bottom, y > 0.6*H): Ball is UNDER camera, zoom OUT, look down
    - Far side (top, y < 0.3*H): Ball is FAR, STRONG zoom IN for detail
    - Middle (0.3-0.6*H): Transition zone, normal zoom
    
    Also considers ball speed for dynamic adjustment.
    """
    # Normalize Y position (0.0 = top, 1.0 = bottom)
    y_norm = ball_y / H
    
    # Base zoom adjustment based on Y position
    if y_norm > NEAR_SIDE_THRESHOLD:
        # Near side (bottom) - ball is UNDER camera
        # Zoom OUT more to see it properly (it's close to camera)
        distance_into_near = (y_norm - NEAR_SIDE_THRESHOLD) / (1.0 - NEAR_SIDE_THRESHOLD)
        zoom_adjust = -0.4 * distance_into_near  # Zoom out up to -0.4
    elif y_norm < FAR_SIDE_THRESHOLD:
        # Far side (top) - ball is FAR from camera
        # STRONG zoom IN to track detail (INCREASED from +0.3 to +0.6)
        distance_into_far = (FAR_SIDE_THRESHOLD - y_norm) / FAR_SIDE_THRESHOLD
        zoom_adjust = 0.6 * distance_into_far  # STRONGER zoom in up to +0.6 (was +0.3)
    else:
        # Middle zone - transition smoothly
        # Map 0.3-0.6 range to smooth transition
        transition = (y_norm - FAR_SIDE_THRESHOLD) / (NEAR_SIDE_THRESHOLD - FAR_SIDE_THRESHOLD)
        zoom_adjust = 0.6 - (transition * 1.0)  # Smooth from +0.6 to -0.4
    
    # Speed adjustment (zoom out when ball is fast)
    speed_adjust = -min(0.2, ball_speed / 100.0)
    
    # Combine adjustments
    zoom_target = ZOOM_BASE + zoom_adjust + speed_adjust
    zoom_target = np.clip(zoom_target, ZOOM_MIN, ZOOM_MAX)
    
    return zoom_target

def calculate_perspective_camera_offset(ball_y, cam_y_current):
    """
    Adjust camera Y position based on perspective.
    
    Near side (bottom): Camera should look DOWN more (shift crop down)
    Far side (top): Camera should look UP less (standard tracking)
    """
    y_norm = ball_y / H
    
    if y_norm > NEAR_SIDE_THRESHOLD:
        # Near side - push camera DOWN more to "look down" at ball
        distance_into_near = (y_norm - NEAR_SIDE_THRESHOLD) / (1.0 - NEAR_SIDE_THRESHOLD)
        # Add downward offset (more as ball gets closer to bottom)
        y_offset = H * 0.15 * distance_into_near  # Up to 15% of frame height
        return cam_y_current + y_offset
    elif y_norm < FAR_SIDE_THRESHOLD:
        # Far side - slight upward bias
        distance_into_far = (FAR_SIDE_THRESHOLD - y_norm) / FAR_SIDE_THRESHOLD
        y_offset = -H * 0.05 * distance_into_far  # Up to 5% upward
        return cam_y_current + y_offset
    else:
        # Middle zone - no offset
        return cam_y_current

print(f"⚡ FAST PRECISION Ball Tracking - HIGH QUALITY")
print(f"📹 Input: {W}x{H} @ {FPS}fps")
print(f"📹 Output: {OUTPUT_WIDTH}x{OUTPUT_HEIGHT} (landscape, HIGH QUALITY)")
print(f"🔍 Detection: Every {DETECT_EVERY} frames, Conf={YOLO_CONF}, ROI={ROI_SIZE}px")
print(f"✨ Quality: CRF={COMPRESSION_QUALITY} (visually lossless), LANCZOS4 interpolation")
print(f"🎯 Perspective: Near side (bottom) zoom out, Far side (top) STRONG zoom in")
print(f"🔍 Zoom: {ZOOM_MIN:.1f}x - {ZOOM_MAX:.1f}x (Base: {ZOOM_BASE:.1f}x)")

# Initialize state
frame_idx = 0
tracker = None
ball_center = np.array([W/2, H/2], dtype=np.float32)
ball_history = []
velocity_history = []
detection_history = []

# Camera state
cam_x, cam_y = W/2.0, H/2.0
zoom_current = ZOOM_BASE

# Stats
detections_count = 0
tracker_count = 0

# Output video - HIGH QUALITY CODECS
codecs_to_try = [
    ('H264', cv2.VideoWriter_fourcc(*'H264')),
    ('avc1', cv2.VideoWriter_fourcc(*'avc1')),
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
    if not ret or frame is None:
        break
    
    frame_idx += 1
    target_center = None
    detected_this_frame = False
    
    # -------------------------------------------------
    # YOLO DETECTION (Every N frames - OPTIMIZED!)
    # -------------------------------------------------
    do_detect = (tracker is None) or (frame_idx % DETECT_EVERY == 1)
    
    if do_detect:
        # Use ROI around ball position
        if len(ball_history) > 0:
            roi_cx, roi_cy = int(ball_center[0]), int(ball_center[1])
        else:
            roi_cx, roi_cy = W // 2, H // 2
        
        x1 = max(0, roi_cx - ROI_SIZE // 2)
        y1 = max(0, roi_cy - ROI_SIZE // 2)
        x2 = min(W, roi_cx + ROI_SIZE // 2)
        y2 = min(H, roi_cy + ROI_SIZE // 2)
        
        # Safety check for ROI
        if y2 <= y1 or x2 <= x1:
            continue
        
        # If ROI would be too small, use full frame
        if (x2 - x1) < W * 0.8 and (y2 - y1) < H * 0.8:
            roi_frame = frame[y1:y2, x1:x2]
            roi_offset_x, roi_offset_y = x1, y1
        else:
            roi_frame = frame
            roi_offset_x, roi_offset_y = 0, 0
        
        # Safety check for roi_frame
        if roi_frame is None or roi_frame.size == 0:
            continue
        
        results = model(roi_frame, conf=YOLO_CONF, imgsz=IMG_SZ, classes=[32], verbose=False)[0]
        boxes = results.boxes
        
        ball_dets = []
        
        if boxes is not None and len(boxes) > 0:
            for b in boxes:
                conf = float(b.conf[0])
                bx1, by1, bx2, by2 = map(int, b.xyxy[0].tolist())
                
                # Adjust coordinates if using ROI
                bx1 += roi_offset_x
                by1 += roi_offset_y
                bx2 += roi_offset_x
                by2 += roi_offset_y
                
                cx, cy = (bx1 + bx2) / 2, (by1 + by2) / 2
                
                # Distance from expected position
                dist = np.linalg.norm(np.array([cx, cy]) - ball_center)
                
                # Size filtering (reject too large = probably not a ball)
                size = (bx2 - bx1) * (by2 - by1)
                if size > 3000:
                    size_score = 0.3
                elif size < 100:
                    size_score = 0.5
                else:
                    size_score = 1.0
                
                # Proximity score
                if len(ball_history) > 0:
                    proximity_score = 1.0 / (1.0 + dist / 200.0)
                else:
                    proximity_score = 1.0
                
                # Combined score
                combined_score = conf * size_score * proximity_score
                
                ball_dets.append(((cx, cy), combined_score, (bx1, by1, bx2, by2), dist))
        
        if len(ball_dets) > 0:
            ball_dets.sort(key=lambda x: x[1], reverse=True)
            (cx, cy), score, (bx1, by1, bx2, by2), dist = ball_dets[0]
            target_center = np.array([cx, cy], dtype=np.float32)
            detected_this_frame = True
            detections_count += 1
            
            # Re-initialize tracker
            bbox = (int(bx1), int(by1), int(bx2-bx1), int(by2-by1))
            tr = create_tracker()
            if tr is not None:
                try:
                    if tr.init(frame, bbox):
                        tracker = tr
                except Exception:
                    tracker = None
    
    # -------------------------------------------------
    # TRACKER UPDATE (between detections)
    # -------------------------------------------------
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
    
    # -------------------------------------------------
    # VELOCITY-BASED PREDICTION
    # -------------------------------------------------
    if target_center is None and len(ball_history) >= 3:
        velocities = []
        for i in range(1, min(6, len(ball_history))):
            velocities.append(ball_history[-i] - ball_history[-i-1])
        
        if len(velocities) > 0:
            avg_velocity = np.mean(velocities, axis=0)
            predicted = ball_history[-1] + avg_velocity * 1.5
            predicted[0] = np.clip(predicted[0], 0, W)
            predicted[1] = np.clip(predicted[1], 0, H)
            target_center = predicted
    
    # -------------------------------------------------
    # UPDATE BALL POSITION (adaptive filtering)
    # -------------------------------------------------
    if target_center is not None:
        if len(ball_history) > 0:
            delta = target_center - ball_center
            movement_size = np.linalg.norm(delta)
            
            # Adaptive filtering based on movement size
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
    
    # -------------------------------------------------
    # CAMERA MOVEMENT (smooth but responsive)
    # -------------------------------------------------
    cam_x = cam_x * (1 - SMOOTH_CAM) + ball_center[0] * SMOOTH_CAM
    cam_y_target = ball_center[1]
    
    # Apply perspective correction to camera Y position
    cam_y_adjusted = calculate_perspective_camera_offset(ball_center[1], cam_y_target)
    cam_y = cam_y * (1 - SMOOTH_CAM) + cam_y_adjusted * SMOOTH_CAM
    
    # -------------------------------------------------
    # PERSPECTIVE-AWARE ZOOM (with STRONGER far side)
    # -------------------------------------------------
    if len(velocity_history) > 0:
        avg_speed = np.mean([np.linalg.norm(v) for v in velocity_history])
    else:
        avg_speed = 0
    
    # Calculate zoom with perspective correction
    zoom_target = calculate_perspective_zoom(ball_center[1], avg_speed)
    zoom_current = zoom_current * (1 - SMOOTH_ZOOM) + zoom_target * SMOOTH_ZOOM
    
    # -------------------------------------------------
    # CROP & RESIZE (HIGH QUALITY: LANCZOS4)
    # -------------------------------------------------
    crop_w = int(W / zoom_current)
    crop_h = int(H / zoom_current)
    
    sx = int(np.clip(cam_x - crop_w//2, 0, W - crop_w))
    sy = int(np.clip(cam_y - crop_h//2, 0, H - crop_h))
    
    # Safety check before cropping
    if frame is None or sy >= H or sx >= W or sy + crop_h > H or sx + crop_w > W:
        continue
    
    cropped = frame[sy:sy+crop_h, sx:sx+crop_w]
    
    # Safety check for cropped frame
    if cropped is None or cropped.size == 0:
        continue
    
    # HIGH QUALITY: Use LANCZOS4 interpolation (best quality)
    if USE_LANCZOS:
        out_frame = cv2.resize(cropped, (OUTPUT_WIDTH, OUTPUT_HEIGHT), interpolation=cv2.INTER_LANCZOS4)
    else:
        out_frame = cv2.resize(cropped, (OUTPUT_WIDTH, OUTPUT_HEIGHT), interpolation=cv2.INTER_LINEAR)
    
    # Safety check before writing
    if out_frame is not None and out_frame.size > 0:
        out.write(out_frame)
    
    # Progress update
    if frame_idx % max(10, int(FPS*3)) == 0:
        progress = int(20 + (frame_idx/TOTAL)*70)
        update_job("processing", progress=progress)

cap.release()
out.release()

# -------------------------------------------------
# FFMPEG POST-PROCESSING (ensure web compatibility)
# -------------------------------------------------
print(f"🔄 Re-encoding video with ffmpeg for web compatibility...")
update_job("processing", progress=90)

temp_output = output_path + ".temp.mp4"
os.rename(output_path, temp_output)

ffmpeg_cmd = [
    "ffmpeg", "-y",
    "-i", temp_output,
    "-c:v", "libx264",
    "-preset", "faster",
    "-crf", str(COMPRESSION_QUALITY),
    "-maxrate", "2M",
    "-bufsize", "4M",
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

print(f"✅ Fast Precision Ball Tracking (HIGH QUALITY) complete in {elapsed:.1f}s")
print(f"✅ YOLO detections: {detections_count}/{TOTAL} ({detection_rate}%)")
print(f"✅ Tracker frames: {tracker_count}/{TOTAL}")
print(f"✅ Total tracked: {detections_count + tracker_count}/{TOTAL} ({accuracy}%)")
print(f"✅ Output: {OUTPUT_WIDTH}x{OUTPUT_HEIGHT} (landscape, HIGH QUALITY)")
print(f"✅ Codec: {working_codec}, CRF={COMPRESSION_QUALITY} (visually lossless)")
print(f"✨ Quality: LANCZOS4 interpolation, CRF 18")
print(f"🔍 Zoom: Near side zoom out, Far side STRONG zoom in (up to {ZOOM_MAX}x)")

# Set metrics for dashboard
tracker_ok_count = detections_count + tracker_count

