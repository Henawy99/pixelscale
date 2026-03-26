"""
REAL-TIME ACCURATE Ball Tracking with FFmpeg Pipe
- Uses FFmpeg subprocess to write H264 frames directly (NO huge temp file!)
- Prevents timeout by avoiding massive mp4v files
- SAME accuracy as ACCURATE_ball_tracking.py but ROBUST for long videos
"""

import cv2
import numpy as np
import time
import subprocess
import os

# ----------------- CONFIG -----------------
YOLO_CONF = 0.12
IMG_SZ = 960
DETECT_EVERY = 3  # Accurate detection
ROI_SIZE = 1200

# Smoothing
SMOOTH_CAM = 0.08
SMOOTH_ZOOM = 0.10

# Zoom - PERSPECTIVE-AWARE
ZOOM_BASE = 1.8
ZOOM_MIN = 1.3
ZOOM_MAX = 2.4

# Memory
BALL_MEMORY = 25
VELOCITY_MEMORY = 12

# Perspective correction
NEAR_SIDE_THRESHOLD = 0.6
FAR_SIDE_THRESHOLD = 0.3

# Output - Use original resolution
OUTPUT_WIDTH = W
OUTPUT_HEIGHT = H

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

print(f"⚡ REAL-TIME ACCURATE Ball Tracking (FFmpeg Pipe)")
print(f"📹 Input: {W}x{H} @ {FPS}fps")
print(f"📹 Output: {OUTPUT_WIDTH}x{OUTPUT_HEIGHT} (landscape)")
print(f"🔍 Detection: Every {DETECT_EVERY} frames, Conf={YOLO_CONF}, ROI={ROI_SIZE}px")
print(f"🎯 Perspective: Near side (bottom) zoom out, Far side (top) zoom in")
print(f"🔍 Zoom: {ZOOM_MIN:.1f}x - {ZOOM_MAX:.1f}x (Base: {ZOOM_BASE:.1f}x)")
print(f"🏆 Using pre-loaded yolov8l model for ACCURACY")
print(f"⚡ CRITICAL: Writing H264 frames directly with FFmpeg (NO huge temp file!)")

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

# -------------------------------------------------
# FFMPEG PIPE FOR REAL-TIME H264 ENCODING
# -------------------------------------------------
print(f"🔧 Starting FFmpeg subprocess for real-time H264 encoding...")

ffmpeg_cmd = [
    'ffmpeg',
    '-y',  # Overwrite output file
    '-f', 'rawvideo',  # Input format
    '-vcodec', 'rawvideo',
    '-s', f'{OUTPUT_WIDTH}x{OUTPUT_HEIGHT}',  # Size of one frame
    '-pix_fmt', 'bgr24',  # Pixel format (OpenCV uses BGR)
    '-r', str(FPS),  # Frames per second
    '-i', '-',  # Input comes from stdin
    '-c:v', 'libx264',  # Output codec
    '-preset', 'ultrafast',  # Fast encoding (important for real-time!)
    '-crf', '23',  # Quality (18-28, lower = better)
    '-pix_fmt', 'yuv420p',  # Output pixel format
    '-movflags', '+faststart',  # Web compatibility
    output_path
]

# Start FFmpeg process
ffmpeg_process = subprocess.Popen(
    ffmpeg_cmd,
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    bufsize=10**8  # Large buffer for performance
)

print(f"✅ FFmpeg subprocess started (PID: {ffmpeg_process.pid})")

tracker_ok_count = 0
t0 = time.time()

try:
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        
        frame_idx += 1
        target_center = None
        detected_this_frame = False
        
        # -------------------------------------------------
        # YOLO DETECTION
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
            
            # Safety check: ensure ROI has valid dimensions
            if x2 <= x1 or y2 <= y1:
                continue
            
            # If ROI would be too small, use full frame
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
                    
                    # Adjust coordinates if using ROI
                    bx1 += roi_offset_x
                    by1 += roi_offset_y
                    bx2 += roi_offset_x
                    by2 += roi_offset_y
                    
                    cx, cy = (bx1 + bx2) / 2, (by1 + by2) / 2
                    
                    # Distance from expected position
                    dist = np.linalg.norm(np.array([cx, cy]) - ball_center)
                    
                    # Size filtering
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
        # TRACKER UPDATE
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
        # UPDATE BALL POSITION
        # -------------------------------------------------
        if target_center is not None:
            if len(ball_history) > 0:
                delta = target_center - ball_center
                movement_size = np.linalg.norm(delta)
                
                # Adaptive filtering
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
        # CAMERA MOVEMENT
        # -------------------------------------------------
        cam_x = cam_x * (1 - SMOOTH_CAM) + ball_center[0] * SMOOTH_CAM
        cam_y_target = ball_center[1]
        
        # Apply perspective correction
        cam_y_adjusted = calculate_perspective_camera_offset(ball_center[1], cam_y_target)
        cam_y = cam_y * (1 - SMOOTH_CAM) + cam_y_adjusted * SMOOTH_CAM
        
        # -------------------------------------------------
        # PERSPECTIVE-AWARE ZOOM
        # -------------------------------------------------
        if len(velocity_history) > 0:
            avg_speed = np.mean([np.linalg.norm(v) for v in velocity_history])
        else:
            avg_speed = 0
        
        zoom_target = calculate_perspective_zoom(ball_center[1], avg_speed)
        zoom_current = zoom_current * (1 - SMOOTH_ZOOM) + zoom_target * SMOOTH_ZOOM
        
        # -------------------------------------------------
        # CROP & RESIZE
        # -------------------------------------------------
        crop_w = int(W / zoom_current)
        crop_h = int(H / zoom_current)
        
        sx = int(np.clip(cam_x - crop_w//2, 0, W - crop_w))
        sy = int(np.clip(cam_y - crop_h//2, 0, H - crop_h))
        
        cropped = frame[sy:sy+crop_h, sx:sx+crop_w]
        out_frame = cv2.resize(cropped, (OUTPUT_WIDTH, OUTPUT_HEIGHT), interpolation=cv2.INTER_LINEAR)
        
        # -------------------------------------------------
        # WRITE FRAME TO FFMPEG PIPE (Real-time H264!)
        # -------------------------------------------------
        try:
            ffmpeg_process.stdin.write(out_frame.tobytes())
        except BrokenPipeError:
            print("❌ FFmpeg pipe broken!")
            break
        
        # Progress update
        if frame_idx % max(10, int(FPS*3)) == 0:
            progress = int(20 + (frame_idx/TOTAL)*75)
            update_job("processing", progress=progress)
            
            # Check if FFmpeg is still running
            if ffmpeg_process.poll() is not None:
                print(f"❌ FFmpeg process died! Return code: {ffmpeg_process.returncode}")
                break

except Exception as e:
    print(f"❌ Error during processing: {e}")
    import traceback
    traceback.print_exc()
finally:
    # Close FFmpeg pipe and wait for it to finish
    print(f"🔧 Closing FFmpeg pipe and finalizing video...")
    if ffmpeg_process.stdin:
        ffmpeg_process.stdin.close()
    
    # Wait for FFmpeg to finish (with timeout)
    try:
        stdout, stderr = ffmpeg_process.communicate(timeout=60)
        if ffmpeg_process.returncode != 0:
            print(f"⚠️ FFmpeg stderr: {stderr.decode('utf-8', errors='ignore')}")
    except subprocess.TimeoutExpired:
        print(f"⚠️ FFmpeg didn't finish in time, terminating...")
        ffmpeg_process.terminate()
        ffmpeg_process.wait()
    
    cap.release()

processing_time = time.time() - t0
print(f"✅ Video processing complete in {processing_time:.1f}s")

# Check if output file exists
if os.path.exists(output_path):
    output_size = os.path.getsize(output_path) / (1024*1024)
    print(f"✅ Output video: {output_size:.1f} MB")
else:
    raise RuntimeError("Output video file was not created!")

# Metrics
accuracy = int(((detections_count + tracker_count) / max(1, TOTAL)) * 100)
detection_rate = int((detections_count / max(1, TOTAL)) * 100)

print(f"✅ REAL-TIME ACCURATE Ball Tracking complete!")
print(f"✅ YOLO detections: {detections_count}/{TOTAL} ({detection_rate}%)")
print(f"✅ Tracker frames: {tracker_count}/{TOTAL}")
print(f"✅ Total tracked: {detections_count + tracker_count}/{TOTAL} ({accuracy}%)")
print(f"✅ Output: {OUTPUT_WIDTH}x{OUTPUT_HEIGHT} (landscape, H264)")
print(f"⚡ NO huge temp file - frames written directly to H264!")

# Set metrics for dashboard
tracker_ok_count = detections_count + tracker_count

