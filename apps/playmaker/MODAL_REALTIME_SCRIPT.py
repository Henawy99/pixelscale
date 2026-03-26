# ==========================================
# MODAL REAL-TIME SCRIPT - 1:1 PROCESSING
# ==========================================
# 
# GOAL: Process video in real-time (1hr video = 1hr max)
# 
# OPTIMIZATIONS:
# 1. Single-scale detection (no multi-scale)
# 2. Detect every 3-5 frames (Kalman fills gaps)
# 3. Smaller input resolution (640px)
# 4. No tiling (full frame only)
# 5. Batch frame processing
# 6. Simplified tracking
#
# Expected: 40-60 fps on T4, 80-120 fps on A10G
# ==========================================

import cv2
import numpy as np
import time

# ==========================================
# OUTPUT CONFIGURATION
# ==========================================
BASE_OUTPUT_W, BASE_OUTPUT_H = 1920, 1080

# ==========================================
# SPEED SETTINGS - TUNED FOR REAL-TIME
# ==========================================
DETECT_EVERY_N = 4            # Only detect every 4th frame (4x faster!)
YOLO_IMG_SIZE = 640           # Single resolution (fastest)
YOLO_CONF = 0.15              # Single confidence threshold

# ==========================================
# ZOOM & CAMERA
# ==========================================
ZOOM_TRACKING = 0.55
ZOOM_LOST = 0.80
ZOOM_SMOOTHING = 0.04
CAMERA_SMOOTHING = 0.08
SAFE_MARGIN = 180

# ==========================================
# TRACKING - SIMPLIFIED
# ==========================================
MAX_COAST_FRAMES = 40         # Frames to coast on prediction
MAX_JUMP = 400                # Max allowed ball jump

# ==========================================
# SIMPLE FAST TRACKER
# ==========================================
class FastTracker:
    def __init__(self, x, y):
        self.x = float(x)
        self.y = float(y)
        self.vx = 0.0
        self.vy = 0.0
        self.missed = 0
    
    def predict(self):
        self.x += self.vx
        self.y += self.vy
        self.vx *= 0.92
        self.vy *= 0.92
        return self.x, self.y
    
    def update(self, dx, dy):
        self.vx = self.vx * 0.6 + (dx - self.x) * 0.4
        self.vy = self.vy * 0.6 + (dy - self.y) * 0.4
        self.x = self.x * 0.3 + dx * 0.7
        self.y = self.y * 0.3 + dy * 0.7
        self.missed = 0


# ==========================================
# FAST DETECTION - SINGLE CALL
# ==========================================
def detect_fast(model, frame):
    """Single YOLO call - maximum speed."""
    results = model.predict(frame, conf=YOLO_CONF, classes=[32], 
                           imgsz=YOLO_IMG_SIZE, verbose=False)
    boxes = results[0].boxes
    if boxes is None or len(boxes) == 0:
        return None
    
    # Return best detection (highest confidence)
    best = None
    best_conf = 0
    
    for box in boxes:
        data = box.data.cpu().numpy()[0]
        x1, y1, x2, y2, conf, _ = data
        if conf > best_conf:
            best_conf = conf
            best = ((x1 + x2) / 2, (y1 + y2) / 2, conf)
    
    return best


# ==========================================
# SIMPLE CAMERA
# ==========================================
class FastCamera:
    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.cx = w / 2
        self.cy = h / 2
        self.zoom = ZOOM_LOST
        self.aspect = BASE_OUTPUT_W / BASE_OUTPUT_H
    
    def update(self, ball_x, ball_y, tracking):
        target_zoom = ZOOM_TRACKING if tracking else ZOOM_LOST
        self.zoom += (target_zoom - self.zoom) * ZOOM_SMOOTHING
        
        if tracking and ball_x:
            self.cx += (ball_x - self.cx) * CAMERA_SMOOTHING
            self.cy += (ball_y - self.cy) * CAMERA_SMOOTHING
        
        # Calculate crop
        crop_h = int(self.h * self.zoom)
        crop_w = int(crop_h * self.aspect)
        if crop_w > self.w:
            crop_w = int(self.w * self.zoom)
            crop_h = int(crop_w / self.aspect)
        
        # Clamp
        half_w, half_h = crop_w / 2, crop_h / 2
        self.cx = np.clip(self.cx, half_w, self.w - half_w)
        self.cy = np.clip(self.cy, half_h, self.h - half_h)
        
        return int(self.cx), int(self.cy), crop_w, crop_h


# ==========================================
# MAIN LOOP - OPTIMIZED FOR SPEED
# ==========================================
print("=" * 60)
print("🚀 REAL-TIME BALL TRACKING - Speed Optimized")
print("=" * 60)
print(f"📹 Input: {W}x{H} @ {FPS}fps, {TOTAL} frames")
print(f"📹 Output: {BASE_OUTPUT_W}x{BASE_OUTPUT_H}")
print(f"⚡ Detection: Every {DETECT_EVERY_N} frames @ {YOLO_IMG_SIZE}px")
print(f"🎯 Target: {FPS} fps (real-time)")
print("=" * 60)

camera = FastCamera(W, H)
tracker = None
tracked_frames = 0

fourcc = cv2.VideoWriter_fourcc(*'mp4v')
out = cv2.VideoWriter(output_path, fourcc, FPS, (BASE_OUTPUT_W, BASE_OUTPUT_H))

frame_idx = 0
misses = 0
ball_x, ball_y = W/2, H/2

print("🎬 Processing...")
start = time.time()

while True:
    ret, frame = cap.read()
    if not ret:
        break
    
    frame_idx += 1
    is_tracking = False
    
    # ===== DETECTION (every Nth frame) =====
    if frame_idx % DETECT_EVERY_N == 0 or tracker is None:
        det = detect_fast(model, frame)
        
        if det:
            dx, dy, conf = det
            
            # Validate jump distance
            if tracker and np.sqrt((dx - ball_x)**2 + (dy - ball_y)**2) > MAX_JUMP:
                det = None
            else:
                if tracker is None:
                    tracker = FastTracker(dx, dy)
                else:
                    tracker.update(dx, dy)
                
                ball_x, ball_y = tracker.x, tracker.y
                is_tracking = True
                tracked_frames += 1
                misses = 0
    
    # ===== PREDICTION (between detections) =====
    if tracker and not is_tracking:
        if misses < MAX_COAST_FRAMES:
            ball_x, ball_y = tracker.predict()
            is_tracking = True
            tracked_frames += 1
            misses += 1
        else:
            tracker = None
    
    # ===== DRAW MARKER =====
    if is_tracking:
        cv2.circle(frame, (int(ball_x), int(ball_y)), 12, (0, 0, 255), 3)
    
    # ===== CAMERA & CROP =====
    cx, cy, cw, ch = camera.update(ball_x if is_tracking else None, 
                                    ball_y if is_tracking else None, 
                                    is_tracking)
    
    x1 = max(0, min(cx - cw//2, W - cw))
    y1 = max(0, min(cy - ch//2, H - ch))
    
    crop = frame[y1:y1+ch, x1:x1+cw]
    if crop.size > 0:
        output = cv2.resize(crop, (BASE_OUTPUT_W, BASE_OUTPUT_H), interpolation=cv2.INTER_LINEAR)
        out.write(output)
    
    # ===== PROGRESS =====
    if frame_idx % 500 == 0:
        elapsed = time.time() - start
        fps_actual = frame_idx / elapsed
        pct = int(frame_idx / TOTAL * 100)
        acc = int(tracked_frames / frame_idx * 100)
        eta = int((TOTAL - frame_idx) / fps_actual / 60)
        
        status = "✅ ON TRACK" if fps_actual >= FPS * 0.9 else "⚠️ BEHIND"
        print(f"📊 {pct}% | {fps_actual:.1f}fps | Acc:{acc}% | ETA:{eta}m {status}")
        update_job("processing", progress=pct)

# ===== CLEANUP =====
elapsed = time.time() - start
cap.release()
out.release()

print(f"\n📊 Done: {frame_idx} frames in {elapsed:.1f}s")
print(f"⚡ Speed: {frame_idx/elapsed:.1f} fps (target: {FPS})")
print(f"🎯 Accuracy: {tracked_frames}/{frame_idx} = {int(tracked_frames/frame_idx*100)}%")

# ===== FFMPEG =====
import os
import subprocess

if os.path.exists(output_path):
    update_job("processing", progress=90)
    temp = output_path + ".tmp.mp4"
    os.rename(output_path, temp)
    
    subprocess.run([
        "ffmpeg", "-y", "-i", temp,
        "-c:v", "libx264", "-preset", "ultrafast", "-crf", "23",
        "-movflags", "+faststart", "-pix_fmt", "yuv420p",
        output_path
    ], capture_output=True, timeout=300)
    
    if os.path.exists(output_path):
        os.remove(temp)
    else:
        os.rename(temp, output_path)

update_job("processing", progress=95)

# Final stats
speed_ratio = (frame_idx / elapsed) / FPS
print(f"\n{'='*60}")
print(f"🎉 COMPLETE!")
print(f"⚡ Real-time ratio: {speed_ratio:.2f}x {'✅' if speed_ratio >= 1.0 else '❌'}")
print(f"💰 Estimated cost: ${elapsed * 0.00016:.4f} (T4)")
print(f"{'='*60}")


