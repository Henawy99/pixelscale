# ==========================================
# PROMO SCRIPT - YOLOV8X MAXIMUM ACCURACY
# ==========================================
# MUST USE: yolov8x (best model)
# RED CIRCLE marker
# EVERY frame detection
# ==========================================

import cv2
import numpy as np
import time

# ==========================================
# FORCE YOLOV8X MODEL (BEST ACCURACY)
# ==========================================
from ultralytics import YOLO
print("🔄 Loading YOLOv8x (BEST model)...")
model = YOLO('yolov8x.pt')
print("✅ YOLOv8x loaded!")

# ==========================================
# OUTPUT - FULL HD
# ==========================================
BASE_OUTPUT_W, BASE_OUTPUT_H = 1920, 1080

# ==========================================
# DETECTION - MAXIMUM ACCURACY
# ==========================================
DETECT_EVERY_N = 1        # EVERY FRAME!
CONF_HIGH = 0.12          # Primary
CONF_MEDIUM = 0.06        # Secondary  
CONF_LOW = 0.03           # Rescue
YOLO_IMG_SIZE = 1280      # Larger = more accurate

# ==========================================
# CAMERA - SMOOTH
# ==========================================
ZOOM_TRACKING = 0.50
ZOOM_LOST = 0.75
ZOOM_SMOOTHING = 0.02
CAMERA_SMOOTHING = 0.04
SAFE_MARGIN = 180

# ==========================================
# TRACKING
# ==========================================
MAX_BALL_JUMP = 350
MAX_KALMAN_COAST = 60
VELOCITY_SMOOTH = 0.3

# ==========================================
# RED CIRCLE MARKER
# ==========================================
MARKER_COLOR = (0, 0, 255)  # RED (BGR)
MARKER_RADIUS = 15
MARKER_THICKNESS = 3

# ==========================================
# TRACKER
# ==========================================
class BallTracker:
    def __init__(self, x, y):
        self.x = float(x)
        self.y = float(y)
        self.vx = 0.0
        self.vy = 0.0
        self.missed = 0
        self.history = [(x, y)]
    
    def predict(self):
        self.x += self.vx
        self.y += self.vy
        self.vx *= 0.92
        self.vy *= 0.92
        return self.x, self.y
    
    def update(self, dx, dy, conf=1.0):
        self.vx = self.vx * 0.6 + (dx - self.x) * VELOCITY_SMOOTH * 0.4
        self.vy = self.vy * 0.6 + (dy - self.y) * VELOCITY_SMOOTH * 0.4
        
        w = min(conf + 0.3, 1.0)
        self.x = self.x * (1 - w) + dx * w
        self.y = self.y * (1 - w) + dy * w
        
        self.missed = 0
        self.history.append((dx, dy))
        if len(self.history) > 8:
            self.history.pop(0)
    
    def smooth_pos(self):
        if len(self.history) < 2:
            return self.x, self.y
        weights = [0.1, 0.12, 0.15, 0.18, 0.20, 0.25][-len(self.history):]
        tw = sum(weights)
        sx = sum(h[0] * w for h, w in zip(self.history, weights)) / tw
        sy = sum(h[1] * w for h, w in zip(self.history, weights)) / tw
        return sx, sy

# ==========================================
# DETECTION FUNCTIONS
# ==========================================
def detect(frame, conf, img_size=YOLO_IMG_SIZE):
    try:
        results = model.predict(frame, conf=conf, classes=[32], imgsz=img_size, verbose=False)
        boxes = results[0].boxes
        if boxes is None or len(boxes) == 0:
            return []
        
        dets = []
        for box in boxes:
            data = box.data.cpu().numpy()[0]
            x1, y1, x2, y2, c, _ = data
            cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
            w, h = x2 - x1, y2 - y1
            dets.append({'x': cx, 'y': cy, 'w': w, 'h': h, 'conf': c, 'area': w * h})
        return dets
    except:
        return []

def detect_tiled(frame, conf):
    h, w = frame.shape[:2]
    all_dets = []
    
    # Full frame at multiple sizes
    all_dets.extend(detect(frame, conf, 1280))
    all_dets.extend(detect(frame, conf, 960))
    
    # Tiles for wide frames
    if w > 2000:
        # Left
        left = frame[:, :int(w * 0.45)]
        for d in detect(left, conf * 0.85, 960):
            all_dets.append(d)
        
        # Center
        center = frame[:, int(w * 0.25):int(w * 0.75)]
        for d in detect(center, conf * 0.85, 960):
            d['x'] += int(w * 0.25)
            all_dets.append(d)
        
        # Right
        right = frame[:, int(w * 0.55):]
        for d in detect(right, conf * 0.85, 960):
            d['x'] += int(w * 0.55)
            all_dets.append(d)
    
    # Remove duplicates
    unique = []
    for d in sorted(all_dets, key=lambda x: x['conf'], reverse=True):
        is_dup = False
        for u in unique:
            if np.sqrt((d['x'] - u['x'])**2 + (d['y'] - u['y'])**2) < 50:
                is_dup = True
                break
        if not is_dup:
            unique.append(d)
    
    return unique

def select_best(dets, pred_x, pred_y, last_x, last_y, shape):
    if not dets:
        return None
    
    h, w = shape[:2]
    scored = []
    
    for d in dets:
        # Size filter
        if d['area'] < 30 or d['area'] > (min(w, h) * 0.12) ** 2:
            continue
        
        # Distance
        dist_p = np.sqrt((d['x'] - pred_x)**2 + (d['y'] - pred_y)**2)
        dist_l = np.sqrt((d['x'] - last_x)**2 + (d['y'] - last_y)**2)
        
        if dist_p > MAX_BALL_JUMP * 2 and dist_l > MAX_BALL_JUMP * 2:
            continue
        
        # Score
        score = d['conf'] * 0.4 + (1 / (1 + dist_p / 200)) * 0.4 + (1 / (1 + dist_l / 300)) * 0.2
        scored.append((score, d))
    
    if not scored:
        return None
    
    scored.sort(reverse=True)
    return scored[0][1]

# ==========================================
# CAMERA
# ==========================================
class Camera:
    def __init__(self, fw, fh):
        self.fw, self.fh = fw, fh
        self.cx, self.cy = fw / 2, fh / 2
        self.zoom = ZOOM_LOST
        self.aspect = BASE_OUTPUT_W / BASE_OUTPUT_H
        self.last_x, self.last_y = fw / 2, fh / 2
    
    def update(self, bx, by, tracking):
        target = ZOOM_TRACKING if tracking else ZOOM_LOST
        self.zoom += (target - self.zoom) * ZOOM_SMOOTHING
        
        if tracking and bx is not None:
            dist = np.sqrt((bx - self.last_x)**2 + (by - self.last_y)**2)
            if dist < MAX_BALL_JUMP:
                self.last_x, self.last_y = bx, by
                self.cx += (bx - self.cx) * CAMERA_SMOOTHING
                self.cy += (by - self.cy) * CAMERA_SMOOTHING
        
        crop_h = int(self.fh * self.zoom)
        crop_w = int(crop_h * self.aspect)
        if crop_w > self.fw:
            crop_w = int(self.fw * self.zoom)
            crop_h = int(crop_w / self.aspect)
        
        hw, hh = crop_w / 2, crop_h / 2
        self.cx = np.clip(self.cx, hw, self.fw - hw)
        self.cy = np.clip(self.cy, hh, self.fh - hh)
        
        return int(self.cx), int(self.cy), crop_w, crop_h

# ==========================================
# DRAW RED CIRCLE
# ==========================================
def draw_red_circle(frame, x, y, is_pred=False):
    x, y = int(x), int(y)
    
    if is_pred:
        # Yellow dashed circle for prediction
        cv2.circle(frame, (x, y), MARKER_RADIUS, (0, 200, 255), 2)
    else:
        # RED SOLID CIRCLE
        cv2.circle(frame, (x, y), MARKER_RADIUS, MARKER_COLOR, MARKER_THICKNESS)
        cv2.circle(frame, (x, y), 5, MARKER_COLOR, -1)  # Center dot
    
    return frame

# ==========================================
# MAIN
# ==========================================
print("=" * 60)
print("🎬 PROMO VIDEO - YOLOV8X MAXIMUM ACCURACY")
print("=" * 60)
print(f"📹 Input: {W}x{H} @ {FPS}fps, {TOTAL} frames")
print(f"📹 Output: {BASE_OUTPUT_W}x{BASE_OUTPUT_H}")
print(f"🤖 Model: YOLOv8x (BEST)")
print(f"🎯 Detection: EVERY frame")
print(f"🎯 Confidence: {CONF_HIGH}/{CONF_MEDIUM}/{CONF_LOW}")
print(f"🔴 Marker: RED CIRCLE")
print("=" * 60)

camera = Camera(W, H)
tracker = None
tracked = 0
detected = 0

fourcc = cv2.VideoWriter_fourcc(*'mp4v')
out = cv2.VideoWriter(output_path, fourcc, FPS, (BASE_OUTPUT_W, BASE_OUTPUT_H))

if not out.isOpened():
    raise RuntimeError("VideoWriter failed!")

frame_idx = 0
misses = 0

print("🎬 Processing...")
start = time.time()

while True:
    ret, frame = cap.read()
    if not ret or frame is None:
        print(f"📹 End at frame {frame_idx}")
        break
    
    frame_idx += 1
    
    # Predict
    if tracker:
        pred_x, pred_y = tracker.predict()
    else:
        pred_x, pred_y = camera.last_x, camera.last_y
    
    # ===== MULTI-STAGE DETECTION =====
    best = None
    
    # Stage 1: High conf + tiled + multi-scale
    dets = detect_tiled(frame, CONF_HIGH)
    best = select_best(dets, pred_x, pred_y, camera.last_x, camera.last_y, frame.shape)
    
    # Stage 2: Medium conf
    if best is None:
        dets = detect_tiled(frame, CONF_MEDIUM)
        best = select_best(dets, pred_x, pred_y, camera.last_x, camera.last_y, frame.shape)
    
    # Stage 3: ROI search
    if best is None and tracker:
        roi_size = 900
        x1 = max(0, int(pred_x - roi_size/2))
        y1 = max(0, int(pred_y - roi_size/2))
        x2 = min(W, int(pred_x + roi_size/2))
        y2 = min(H, int(pred_y + roi_size/2))
        
        if x2 > x1 + 100 and y2 > y1 + 100:
            roi = frame[y1:y2, x1:x2]
            dets = detect(roi, CONF_LOW, 640)
            for d in dets:
                d['x'] += x1
                d['y'] += y1
            best = select_best(dets, pred_x, pred_y, camera.last_x, camera.last_y, frame.shape)
    
    # Stage 4: Full rescue
    if best is None:
        dets = detect(frame, CONF_LOW, 1280)
        best = select_best(dets, pred_x, pred_y, camera.last_x, camera.last_y, frame.shape)
    
    # ===== UPDATE =====
    ball_x, ball_y = None, None
    is_tracking = False
    is_pred = False
    
    if best:
        detected += 1
        
        if tracker is None:
            tracker = BallTracker(best['x'], best['y'])
            print(f"✅ Ball found at frame {frame_idx}!")
        else:
            tracker.update(best['x'], best['y'], best['conf'])
        
        ball_x, ball_y = tracker.smooth_pos()
        is_tracking = True
        tracked += 1
        misses = 0
    
    elif tracker:
        misses += 1
        if misses < MAX_KALMAN_COAST:
            ball_x, ball_y = pred_x, pred_y
            is_tracking = True
            is_pred = True
            tracked += 1
            tracker.missed += 1
        else:
            if misses == MAX_KALMAN_COAST:
                print(f"⚠️ Lost at frame {frame_idx}")
            tracker = None
    
    # Draw RED CIRCLE
    if is_tracking and ball_x is not None:
        frame = draw_red_circle(frame, ball_x, ball_y, is_pred)
    
    # Camera
    cx, cy, cw, ch = camera.update(ball_x, ball_y, is_tracking)
    
    # Crop
    try:
        x1 = max(0, min(cx - cw // 2, W - cw))
        y1 = max(0, min(cy - ch // 2, H - ch))
        crop = frame[y1:y1+ch, x1:x1+cw]
        
        if crop.size > 0 and crop.shape[0] > 10:
            output = cv2.resize(crop, (BASE_OUTPUT_W, BASE_OUTPUT_H), interpolation=cv2.INTER_LANCZOS4)
            out.write(output)
        else:
            out.write(cv2.resize(frame, (BASE_OUTPUT_W, BASE_OUTPUT_H)))
    except:
        out.write(cv2.resize(frame, (BASE_OUTPUT_W, BASE_OUTPUT_H)))
    
    # Progress
    if frame_idx % 20 == 0:
        pct = int(frame_idx / TOTAL * 100)
        elapsed = time.time() - start
        fps_act = frame_idx / max(0.1, elapsed)
        det_rate = int(detected / frame_idx * 100)
        trk_rate = int(tracked / frame_idx * 100)
        mode = "DETECT" if best else ("KALMAN" if is_tracking else "LOST")
        print(f"📊 {pct}% | {fps_act:.1f}fps | Det:{det_rate}% Trk:{trk_rate}% [{mode}]")
        update_job("processing", progress=pct)

# Cleanup
elapsed = time.time() - start
print(f"\n📊 Done: {frame_idx} frames in {elapsed:.1f}s")

cap.release()
print("✅ cap.release()")

out.release()
print("✅ out.release()")

# Verify
import os
if not os.path.exists(output_path):
    raise RuntimeError("No output!")

print(f"📁 Output: {os.path.getsize(output_path) / 1024 / 1024:.1f} MB")

# FFmpeg
print("🔄 Re-encoding...")
update_job("processing", progress=90)

import subprocess
temp = output_path + ".tmp.mp4"
os.rename(output_path, temp)

cmd = ["ffmpeg", "-y", "-i", temp, "-c:v", "libx264", "-preset", "slow", "-crf", "18",
       "-r", str(int(FPS)), "-movflags", "+faststart", "-pix_fmt", "yuv420p", output_path]

try:
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    if r.returncode == 0:
        os.remove(temp)
        print(f"✅ FFmpeg done: {os.path.getsize(output_path) / 1024 / 1024:.1f} MB")
    else:
        os.rename(temp, output_path)
except:
    if os.path.exists(temp):
        os.rename(temp, output_path)

update_job("processing", progress=95)

# Final
det_acc = int(detected / max(1, frame_idx) * 100)
trk_acc = int(tracked / max(1, frame_idx) * 100)

print("\n" + "=" * 60)
print("🎉 PROMO COMPLETE!")
print(f"🎯 Detection: {det_acc}%")
print(f"🎯 Tracking: {trk_acc}%")
print(f"🤖 Model: YOLOv8x")
print(f"🔴 Marker: RED CIRCLE")
print("=" * 60)
