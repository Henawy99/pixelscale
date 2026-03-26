# ==========================================
# MODAL BALANCED SCRIPT V2
# ==========================================
# 
# GOAL: Good accuracy + Reasonable speed
# 
# KEY FIXES:
# 1. Larger detection size (960px) for wide cameras
# 2. Tiled detection for panoramic frames
# 3. Lower confidence threshold
# 4. Correct FPS handling
# 5. Better ball size filtering
#
# ==========================================

import cv2
import numpy as np
import time

# ==========================================
# OUTPUT CONFIGURATION
# ==========================================
BASE_OUTPUT_W, BASE_OUTPUT_H = 1920, 1080

# ==========================================
# DETECTION SETTINGS - BALANCED FOR ACCURACY
# ==========================================
DETECT_EVERY_N = 2            # Every 2nd frame (good balance)
YOLO_IMG_SIZE = 960           # Larger = better for wide cameras
YOLO_CONF_HIGH = 0.20         # High confidence
YOLO_CONF_LOW = 0.08          # Rescue mode

# Ball size constraints (as ratio of frame area)
MIN_BALL_RATIO = 0.00003      # Very small balls
MAX_BALL_RATIO = 0.005        # Max size

# ==========================================
# ZOOM & CAMERA
# ==========================================
ZOOM_TRACKING = 0.55
ZOOM_LOST = 0.80
ZOOM_SMOOTHING = 0.04
CAMERA_SMOOTHING = 0.08

# ==========================================
# TRACKING
# ==========================================
MAX_COAST_FRAMES = 50
MAX_JUMP = 400

# ==========================================
# TRACKER CLASS
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
        self.vx *= 0.90
        self.vy *= 0.90
        self.missed += 1
        return self.x, self.y
    
    def update(self, dx, dy, conf=1.0):
        # Velocity
        self.vx = self.vx * 0.5 + (dx - self.x) * 0.5
        self.vy = self.vy * 0.5 + (dy - self.y) * 0.5
        
        # Position (weighted by confidence)
        w = min(conf + 0.3, 1.0)
        self.x = self.x * (1 - w) + dx * w
        self.y = self.y * (1 - w) + dy * w
        
        self.missed = 0
        self.history.append((dx, dy))
        if len(self.history) > 5:
            self.history.pop(0)
    
    def get_smooth(self):
        if len(self.history) < 2:
            return self.x, self.y
        weights = [0.1, 0.15, 0.2, 0.25, 0.3][-len(self.history):]
        total = sum(weights)
        sx = sum(h[0] * w for h, w in zip(self.history, weights)) / total
        sy = sum(h[1] * w for h, w in zip(self.history, weights)) / total
        return sx, sy


# ==========================================
# DETECTION FUNCTIONS
# ==========================================
def detect_ball(model, frame, conf):
    """Basic YOLO detection."""
    try:
        results = model.predict(frame, conf=conf, classes=[32], 
                               imgsz=YOLO_IMG_SIZE, verbose=False)
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


def detect_tiled(model, frame, conf):
    """Tiled detection for wide frames."""
    h, w = frame.shape[:2]
    all_dets = []
    
    # Full frame
    all_dets.extend(detect_ball(model, frame, conf))
    
    # Add tiles for wide frames (>2000px)
    if w > 2000:
        # Left third
        left = frame[:, :int(w * 0.4)]
        for d in detect_ball(model, left, conf * 0.9):
            all_dets.append(d)
        
        # Middle third
        mid = frame[:, int(w * 0.3):int(w * 0.7)]
        for d in detect_ball(model, mid, conf * 0.9):
            d['x'] += int(w * 0.3)
            all_dets.append(d)
        
        # Right third
        right = frame[:, int(w * 0.6):]
        for d in detect_ball(model, right, conf * 0.9):
            d['x'] += int(w * 0.6)
            all_dets.append(d)
    
    # Remove duplicates
    return remove_duplicates(all_dets)


def remove_duplicates(dets, min_dist=60):
    """Remove duplicate detections."""
    if not dets:
        return []
    
    dets = sorted(dets, key=lambda d: d['conf'], reverse=True)
    unique = []
    
    for d in dets:
        is_dup = False
        for u in unique:
            dist = np.sqrt((d['x'] - u['x'])**2 + (d['y'] - u['y'])**2)
            if dist < min_dist:
                is_dup = True
                break
        if not is_dup:
            unique.append(d)
    
    return unique


def select_best(dets, pred_x, pred_y, last_x, last_y, frame_area):
    """Select best detection."""
    if not dets:
        return None
    
    min_area = frame_area * MIN_BALL_RATIO
    max_area = frame_area * MAX_BALL_RATIO
    
    scored = []
    for d in dets:
        # Size filter
        if d['area'] < min_area or d['area'] > max_area:
            continue
        
        # Aspect ratio (ball should be round-ish)
        aspect = d['w'] / max(d['h'], 1)
        if aspect < 0.4 or aspect > 2.5:
            continue
        
        # Distance
        dist_pred = np.sqrt((d['x'] - pred_x)**2 + (d['y'] - pred_y)**2)
        dist_last = np.sqrt((d['x'] - last_x)**2 + (d['y'] - last_y)**2)
        
        if dist_pred > MAX_JUMP * 2 and dist_last > MAX_JUMP * 2:
            continue
        
        # Score
        score = d['conf'] * 0.4
        score += (1 / (1 + dist_pred / 300)) * 0.35
        score += (1 / (1 + dist_last / 400)) * 0.25
        
        scored.append((score, d))
    
    if not scored:
        return None
    
    scored.sort(reverse=True)
    return scored[0][1]


# ==========================================
# CAMERA CLASS
# ==========================================
class Camera:
    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.cx = w / 2
        self.cy = h / 2
        self.zoom = ZOOM_LOST
        self.aspect = BASE_OUTPUT_W / BASE_OUTPUT_H
        self.last_x = w / 2
        self.last_y = h / 2
    
    def update(self, ball_x, ball_y, tracking):
        target_zoom = ZOOM_TRACKING if tracking else ZOOM_LOST
        self.zoom += (target_zoom - self.zoom) * ZOOM_SMOOTHING
        
        if tracking and ball_x is not None:
            self.last_x = ball_x
            self.last_y = ball_y
            self.cx += (ball_x - self.cx) * CAMERA_SMOOTHING
            self.cy += (ball_y - self.cy) * CAMERA_SMOOTHING
        
        crop_h = int(self.h * self.zoom)
        crop_w = int(crop_h * self.aspect)
        if crop_w > self.w:
            crop_w = int(self.w * self.zoom)
            crop_h = int(crop_w / self.aspect)
        
        half_w, half_h = crop_w / 2, crop_h / 2
        self.cx = np.clip(self.cx, half_w, self.w - half_w)
        self.cy = np.clip(self.cy, half_h, self.h - half_h)
        
        return int(self.cx), int(self.cy), crop_w, crop_h


# ==========================================
# MAIN PROCESSING
# ==========================================
print("=" * 60)
print("🎬 BALANCED BALL TRACKING V2")
print("=" * 60)
print(f"📹 Input: {W}x{H} @ {FPS}fps, {TOTAL} frames")
print(f"📹 Output: {BASE_OUTPUT_W}x{BASE_OUTPUT_H} @ {FPS}fps")
print(f"🔍 Detection: Every {DETECT_EVERY_N} frames @ {YOLO_IMG_SIZE}px")
print(f"🔍 Confidence: {YOLO_CONF_HIGH} / {YOLO_CONF_LOW}")
print(f"📐 Ball size: {MIN_BALL_RATIO*100:.4f}% - {MAX_BALL_RATIO*100:.2f}%")
print(f"🎯 Tiles: {'YES (wide camera)' if W > 2000 else 'NO'}")
print("=" * 60)

camera = Camera(W, H)
tracker = None
tracked_frames = 0
frame_area = W * H

# IMPORTANT: Use correct FPS from input video
output_fps = FPS  # Must match input FPS for correct playback speed!
fourcc = cv2.VideoWriter_fourcc(*'mp4v')
out = cv2.VideoWriter(output_path, fourcc, output_fps, (BASE_OUTPUT_W, BASE_OUTPUT_H))

if not out.isOpened():
    raise RuntimeError(f"Failed to create VideoWriter!")

frame_idx = 0
misses = 0
ball_x, ball_y = W / 2, H / 2
pred_x, pred_y = W / 2, H / 2

print("🎬 Processing...")
start = time.time()

try:
    while True:
        ret, frame = cap.read()
        if not ret or frame is None:
            print(f"📹 End of video at frame {frame_idx}")
            break
        
        frame_idx += 1
        is_tracking = False
        det = None
        
        # ===== DETECTION =====
        should_detect = (frame_idx % DETECT_EVERY_N == 0) or (tracker is None) or (misses > 10)
        
        if should_detect:
            # Stage 1: High confidence with tiling
            dets = detect_tiled(model, frame, YOLO_CONF_HIGH)
            det = select_best(dets, pred_x, pred_y, camera.last_x, camera.last_y, frame_area)
            
            # Stage 2: Low confidence rescue
            if det is None:
                dets = detect_tiled(model, frame, YOLO_CONF_LOW)
                det = select_best(dets, pred_x, pred_y, camera.last_x, camera.last_y, frame_area)
            
            # Stage 3: ROI search around prediction
            if det is None and tracker is not None:
                roi_size = 700
                x1 = max(0, int(pred_x - roi_size/2))
                y1 = max(0, int(pred_y - roi_size/2))
                x2 = min(W, int(pred_x + roi_size/2))
                y2 = min(H, int(pred_y + roi_size/2))
                
                if x2 > x1 + 100 and y2 > y1 + 100:
                    roi = frame[y1:y2, x1:x2]
                    dets = detect_ball(model, roi, YOLO_CONF_LOW * 0.7)
                    for d in dets:
                        d['x'] += x1
                        d['y'] += y1
                    det = select_best(dets, pred_x, pred_y, camera.last_x, camera.last_y, frame_area)
        
        # ===== UPDATE TRACKER =====
        if det is not None:
            # Validate jump
            dist = np.sqrt((det['x'] - camera.last_x)**2 + (det['y'] - camera.last_y)**2)
            if tracker is None or dist < MAX_JUMP:
                if tracker is None:
                    tracker = BallTracker(det['x'], det['y'])
                    print(f"✅ Ball found at frame {frame_idx}!")
                else:
                    tracker.update(det['x'], det['y'], det['conf'])
                
                ball_x, ball_y = tracker.get_smooth()
                pred_x, pred_y = ball_x, ball_y
                is_tracking = True
                tracked_frames += 1
                misses = 0
        
        # ===== PREDICTION (between detections) =====
        if tracker and not is_tracking:
            if misses < MAX_COAST_FRAMES:
                pred_x, pred_y = tracker.predict()
                ball_x, ball_y = pred_x, pred_y
                is_tracking = True
                tracked_frames += 1
                misses += 1
            else:
                if misses == MAX_COAST_FRAMES:
                    print(f"⚠️ Lost ball at frame {frame_idx}")
                tracker = None
        
        # ===== DRAW MARKER =====
        if is_tracking:
            bx, by = int(ball_x), int(ball_y)
            cv2.circle(frame, (bx, by), 15, (0, 0, 255), 3)
            cv2.circle(frame, (bx, by), 5, (0, 0, 255), -1)
        
        # ===== CAMERA & CROP =====
        cx, cy, cw, ch = camera.update(ball_x if is_tracking else None,
                                        ball_y if is_tracking else None,
                                        is_tracking)
        
        x1 = max(0, min(cx - cw // 2, W - cw))
        y1 = max(0, min(cy - ch // 2, H - ch))
        
        try:
            crop = frame[y1:y1+ch, x1:x1+cw]
            if crop.size > 0 and crop.shape[0] > 10 and crop.shape[1] > 10:
                output = cv2.resize(crop, (BASE_OUTPUT_W, BASE_OUTPUT_H), 
                                   interpolation=cv2.INTER_LINEAR)
                out.write(output)
            else:
                # Fallback
                output = cv2.resize(frame, (BASE_OUTPUT_W, BASE_OUTPUT_H))
                out.write(output)
        except Exception as e:
            output = cv2.resize(frame, (BASE_OUTPUT_W, BASE_OUTPUT_H))
            out.write(output)
        
        # ===== PROGRESS =====
        if frame_idx % 200 == 0:
            elapsed = time.time() - start
            fps_actual = frame_idx / elapsed
            pct = int(frame_idx / max(1, TOTAL) * 100)
            acc = int(tracked_frames / max(1, frame_idx) * 100)
            eta_min = int((TOTAL - frame_idx) / max(1, fps_actual) / 60)
            
            status = "DETECT" if det else ("KALMAN" if is_tracking else "LOST")
            print(f"📊 {pct}% | {fps_actual:.1f}fps | Acc:{acc}% | [{status}] | ETA:{eta_min}m")
            update_job("processing", progress=pct)

except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()

# ===== CLEANUP =====
elapsed = time.time() - start
print(f"\n📊 Processing complete: {frame_idx} frames")
print(f"⚡ Speed: {frame_idx/max(1,elapsed):.1f} fps")

cap.release()
print("✅ cap.release()")

out.release()
print("✅ out.release()")

# ===== VERIFY =====
import os
if not os.path.exists(output_path):
    raise RuntimeError("Output file not created!")

output_size = os.path.getsize(output_path) / (1024 * 1024)
print(f"📁 Output size: {output_size:.1f} MB")

# ===== FFMPEG RE-ENCODE =====
print("🔄 Re-encoding for web...")
update_job("processing", progress=90)

import subprocess
temp = output_path + ".temp.mp4"
os.rename(output_path, temp)

# CRITICAL: Preserve FPS in FFmpeg!
ffmpeg_cmd = [
    "ffmpeg", "-y",
    "-i", temp,
    "-c:v", "libx264",
    "-preset", "fast",
    "-crf", "22",
    "-r", str(int(FPS)),  # FORCE correct FPS!
    "-movflags", "+faststart",
    "-pix_fmt", "yuv420p",
    output_path
]

try:
    result = subprocess.run(ffmpeg_cmd, capture_output=True, text=True, timeout=600)
    if result.returncode == 0:
        os.remove(temp)
        print("✅ FFmpeg complete")
    else:
        print(f"⚠️ FFmpeg error: {result.stderr[:200]}")
        os.rename(temp, output_path)
except Exception as e:
    print(f"⚠️ FFmpeg failed: {e}")
    if os.path.exists(temp):
        os.rename(temp, output_path)

# ===== FINAL STATS =====
accuracy = int(tracked_frames / max(1, frame_idx) * 100)
update_job("processing", progress=95)

print("\n" + "=" * 60)
print("🎉 COMPLETE!")
print(f"📊 Accuracy: {accuracy}% ({tracked_frames}/{frame_idx} frames)")
print(f"⏱️ Time: {elapsed:.1f}s")
print(f"📹 Output: {BASE_OUTPUT_W}x{BASE_OUTPUT_H} @ {FPS}fps")
print(f"⚡ Speed ratio: {(frame_idx/max(1,elapsed))/FPS:.2f}x real-time")
print("=" * 60)


