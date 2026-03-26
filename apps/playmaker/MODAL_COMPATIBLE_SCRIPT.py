# ==========================================
# MODAL V18 - ACCURATE + GOAL CELEBRATION
# ==========================================
# 
# FEATURES:
# 1. YOLOv8x for ball detection
# 2. Strict ball filtering (no false positives)
# 3. Goal detection (ball in goal area)
# 4. Zoom to celebrating players after goal
# 5. RED CIRCLE marker
#
# ==========================================

import cv2
import numpy as np
import time

# ==========================================
# FORCE YOLOV8X - BEST MODEL
# ==========================================
from ultralytics import YOLO
print("🔄 Loading YOLOv8x (BEST model)...")
model = YOLO('yolov8x.pt')
print("✅ YOLOv8x loaded!")

# ==========================================
# OUTPUT CONFIGURATION
# ==========================================
BASE_OUTPUT_W, BASE_OUTPUT_H = 1920, 1080

# ==========================================
# ZOOM SETTINGS
# ==========================================
ZOOM_FACTOR_TRACKING = 0.55
ZOOM_FACTOR_LOST = 0.75
ZOOM_FACTOR_CELEBRATION = 0.40  # Closer zoom for goal celebration!
ZOOM_SMOOTHING = 0.015

# ==========================================
# CAMERA MOVEMENT
# ==========================================
CAMERA_SMOOTHING_NORMAL = 0.03
CAMERA_SMOOTHING_CATCHUP = 0.10
CAMERA_SMOOTHING_LOST = 0.008
CAMERA_SMOOTHING_CELEBRATION = 0.06  # Follow celebration

SAFE_MARGIN_X = 180
SAFE_MARGIN_Y = 140

# ==========================================
# DETECTION - STRICT BALL FILTERING
# ==========================================
DETECT_EVERY_N = 1
CONF_HIGH = 0.15
CONF_MEDIUM = 0.08
CONF_LOW = 0.04

YOLO_SIZES = [1280, 960, 640]

# Ball size constraints (relative to frame)
MIN_BALL_SIZE = 0.003  # 0.3% of frame area minimum
MAX_BALL_SIZE = 0.015  # 1.5% of frame area maximum
MIN_BALL_PIXELS = 15   # Minimum pixel width
MAX_BALL_PIXELS = 80   # Maximum pixel width

# ==========================================
# TRACKING
# ==========================================
MAX_BALL_JUMP = 280
MAX_KALMAN_COAST = 70
VELOCITY_SMOOTHING = 0.25

# ==========================================
# GOAL DETECTION
# ==========================================
GOAL_ZONE_LEFT = 0.03   # Left 3% is left goal
GOAL_ZONE_RIGHT = 0.97  # Right 3% is right goal
GOAL_ZONE_Y_MIN = 0.25  # Goal vertical range
GOAL_ZONE_Y_MAX = 0.75
CELEBRATION_DURATION = 80  # Frames to zoom on celebration (4 sec @ 20fps)
GOAL_VELOCITY_THRESHOLD = 5  # Ball must slow down after goal

# ==========================================
# MARKER
# ==========================================
MARK_BALL = True
MARKER_RADIUS = 14
MARKER_COLOR = (0, 0, 255)  # RED
MARKER_THICKNESS = 3

# ==========================================
# TRACKER CLASS
# ==========================================
class SmoothBallTracker:
    def __init__(self, x, y):
        self.x = float(x)
        self.y = float(y)
        self.vx = 0.0
        self.vy = 0.0
        self.missed = 0
        self.confidence = 1.0
        self.history = [(x, y)]
        self.max_history = 8
        self.velocity_history = []
    
    def predict(self):
        pred_x = self.x + self.vx
        pred_y = self.y + self.vy
        self.vx *= 0.93
        self.vy *= 0.93
        return pred_x, pred_y
    
    def update(self, det_x, det_y, conf=1.0):
        new_vx = (det_x - self.x) * VELOCITY_SMOOTHING
        new_vy = (det_y - self.y) * VELOCITY_SMOOTHING
        
        self.vx = self.vx * 0.65 + new_vx * 0.35
        self.vy = self.vy * 0.65 + new_vy * 0.35
        
        # Track velocity for goal detection
        speed = np.sqrt(self.vx**2 + self.vy**2)
        self.velocity_history.append(speed)
        if len(self.velocity_history) > 20:
            self.velocity_history.pop(0)
        
        weight = min(conf + 0.3, 1.0)
        self.x = self.x * (1 - weight) + det_x * weight
        self.y = self.y * (1 - weight) + det_y * weight
        
        self.confidence = conf
        self.missed = 0
        
        self.history.append((det_x, det_y))
        if len(self.history) > self.max_history:
            self.history.pop(0)
    
    def get_smoothed_position(self):
        if len(self.history) < 2:
            return self.x, self.y
        
        weights = [0.08, 0.10, 0.12, 0.15, 0.18, 0.20, 0.22][-len(self.history):]
        total_weight = sum(weights)
        
        sx = sum(h[0] * w for h, w in zip(self.history, weights)) / total_weight
        sy = sum(h[1] * w for h, w in zip(self.history, weights)) / total_weight
        
        return sx, sy
    
    def get_speed(self):
        return np.sqrt(self.vx**2 + self.vy**2)
    
    def velocity_dropped(self):
        """Check if velocity suddenly dropped (ball stopped in goal)."""
        if len(self.velocity_history) < 10:
            return False
        
        recent = np.mean(self.velocity_history[-5:])
        earlier = np.mean(self.velocity_history[-10:-5])
        
        return earlier > 15 and recent < GOAL_VELOCITY_THRESHOLD

# ==========================================
# GOAL DETECTOR
# ==========================================
class GoalDetector:
    def __init__(self, frame_w, frame_h):
        self.frame_w = frame_w
        self.frame_h = frame_h
        self.celebration_frames_left = 0
        self.last_goal_position = None
        self.goals_scored = 0
    
    def check_goal(self, ball_x, ball_y, tracker):
        """Check if ball is in goal area and velocity dropped."""
        if ball_x is None or ball_y is None:
            return False
        
        # Normalize position
        norm_x = ball_x / self.frame_w
        norm_y = ball_y / self.frame_h
        
        # Check if in goal zone
        in_left_goal = norm_x < GOAL_ZONE_LEFT
        in_right_goal = norm_x > GOAL_ZONE_RIGHT
        in_goal_height = GOAL_ZONE_Y_MIN < norm_y < GOAL_ZONE_Y_MAX
        
        in_goal = (in_left_goal or in_right_goal) and in_goal_height
        
        if in_goal and tracker and tracker.velocity_dropped():
            if self.celebration_frames_left == 0:  # New goal
                self.goals_scored += 1
                self.celebration_frames_left = CELEBRATION_DURATION
                self.last_goal_position = (ball_x, ball_y)
                side = "LEFT" if in_left_goal else "RIGHT"
                print(f"⚽🎉 GOAL {self.goals_scored}! Ball in {side} goal at frame!")
                return True
        
        return False
    
    def is_celebrating(self):
        """Are we in celebration mode?"""
        if self.celebration_frames_left > 0:
            self.celebration_frames_left -= 1
            return True
        return False
    
    def get_celebration_position(self):
        """Return position to focus during celebration."""
        return self.last_goal_position

# ==========================================
# DETECTION FUNCTIONS
# ==========================================
def is_valid_ball(det, frame_w, frame_h):
    """Strict ball validation to filter false positives."""
    
    # Size in pixels
    if det['w'] < MIN_BALL_PIXELS or det['w'] > MAX_BALL_PIXELS:
        return False
    if det['h'] < MIN_BALL_PIXELS or det['h'] > MAX_BALL_PIXELS:
        return False
    
    # Size relative to frame
    frame_area = frame_w * frame_h
    ball_area_ratio = det['area'] / frame_area
    
    if ball_area_ratio < MIN_BALL_SIZE or ball_area_ratio > MAX_BALL_SIZE:
        return False
    
    # Aspect ratio (ball should be roughly circular)
    aspect = det['w'] / max(det['h'], 1)
    if aspect < 0.5 or aspect > 2.0:
        return False
    
    return True

def detect_ball(frame, confidence, img_size=1280):
    """Detect ball with YOLO."""
    try:
        results = model.predict(frame, conf=confidence, classes=[32], imgsz=img_size, verbose=False)
        boxes = results[0].boxes
        if boxes is None or len(boxes) == 0:
            return []
        
        detections = []
        for box in boxes:
            data = box.data.cpu().numpy()[0]
            x1, y1, x2, y2, conf, cls = data
            cx = (x1 + x2) / 2
            cy = (y1 + y2) / 2
            w = x2 - x1
            h = y2 - y1
            detections.append({
                'x': cx, 'y': cy, 
                'w': w, 'h': h, 
                'conf': conf,
                'area': w * h
            })
        return detections
    except:
        return []

def detect_players(frame):
    """Detect players for celebration zoom."""
    try:
        results = model.predict(frame, conf=0.3, classes=[0], imgsz=640, verbose=False)
        boxes = results[0].boxes
        if boxes is None or len(boxes) == 0:
            return []
        
        players = []
        for box in boxes:
            data = box.data.cpu().numpy()[0]
            x1, y1, x2, y2, conf, cls = data
            cx = (x1 + x2) / 2
            cy = (y1 + y2) / 2
            players.append({'x': cx, 'y': cy, 'conf': conf})
        return players
    except:
        return []

def find_player_cluster(players, goal_x, goal_y, frame_w):
    """Find cluster of players near goal (celebrating)."""
    if not players or goal_x is None:
        return None
    
    # Find players near the goal
    nearby = []
    for p in players:
        dist = np.sqrt((p['x'] - goal_x)**2 + (p['y'] - goal_y)**2)
        if dist < frame_w * 0.2:  # Within 20% of frame width
            nearby.append(p)
    
    if len(nearby) >= 2:
        # Return centroid of nearby players
        cx = np.mean([p['x'] for p in nearby])
        cy = np.mean([p['y'] for p in nearby])
        return (cx, cy)
    
    return None

def detect_multiscale(frame, confidence):
    """Multi-scale detection."""
    all_dets = []
    for size in YOLO_SIZES:
        all_dets.extend(detect_ball(frame, confidence, size))
    return all_dets

def detect_ball_tiled(frame, confidence):
    """Tiled detection for ultra-wide cameras."""
    h, w = frame.shape[:2]
    all_detections = []
    
    # Full frame at multiple scales
    all_detections.extend(detect_multiscale(frame, confidence))
    
    # Tiles for wide frames
    if w > 2000:
        tiles = [
            (0, 0.45),           # Left
            (0.20, 0.60),        # Left-center
            (0.35, 0.65),        # Center
            (0.40, 0.80),        # Right-center
            (0.55, 1.0),         # Right
        ]
        
        for start, end in tiles:
            tile = frame[:, int(w*start):int(w*end)]
            for d in detect_ball(tile, confidence * 0.85, 960):
                d['x'] += int(w * start)
                all_detections.append(d)
    
    return remove_duplicates(all_detections)

def remove_duplicates(detections, min_dist=60):
    """Remove duplicate detections."""
    if not detections:
        return []
    
    detections = sorted(detections, key=lambda d: d['conf'], reverse=True)
    unique = []
    
    for d in detections:
        is_dup = False
        for u in unique:
            dist = np.sqrt((d['x'] - u['x'])**2 + (d['y'] - u['y'])**2)
            if dist < min_dist:
                is_dup = True
                break
        if not is_dup:
            unique.append(d)
    
    return unique

def select_best_detection(detections, pred_x, pred_y, last_x, last_y, frame_shape):
    """Select most likely ball with strict filtering."""
    if not detections:
        return None
    
    h, w = frame_shape[:2]
    
    scored = []
    for det in detections:
        # STRICT validation
        if not is_valid_ball(det, w, h):
            continue
        
        # Distance to prediction
        dist_pred = np.sqrt((det['x'] - pred_x)**2 + (det['y'] - pred_y)**2)
        
        # Distance to last known position
        dist_last = np.sqrt((det['x'] - last_x)**2 + (det['y'] - last_y)**2)
        
        # Reject if too far
        if dist_pred > MAX_BALL_JUMP * 2 and dist_last > MAX_BALL_JUMP * 2:
            continue
        
        # Score: heavily favor proximity to prediction
        score = det['conf'] * 0.25
        score += (1.0 / (1.0 + dist_pred / 150)) * 0.50  # More weight on prediction
        score += (1.0 / (1.0 + dist_last / 200)) * 0.25
        
        scored.append((score, det))
    
    if not scored:
        return None
    
    scored.sort(key=lambda x: x[0], reverse=True)
    return scored[0][1]

# ==========================================
# CAMERA CLASS WITH CELEBRATION MODE
# ==========================================
class CinematicCamera:
    def __init__(self, frame_w, frame_h):
        self.frame_w = frame_w
        self.frame_h = frame_h
        self.cam_x = frame_w / 2
        self.cam_y = frame_h / 2
        self.zoom = ZOOM_FACTOR_LOST
        self.target_zoom = ZOOM_FACTOR_LOST
        self.output_aspect = BASE_OUTPUT_W / BASE_OUTPUT_H
        self.last_ball_x = frame_w / 2
        self.last_ball_y = frame_h / 2
        self.frames_since_ball = 999
        self.celebration_mode = False
    
    def get_crop_dimensions(self):
        crop_h = int(self.frame_h * self.zoom)
        crop_w = int(crop_h * self.output_aspect)
        
        if crop_w > self.frame_w:
            crop_w = int(self.frame_w * self.zoom)
            crop_h = int(crop_w / self.output_aspect)
        
        return max(100, crop_w), max(100, crop_h)
    
    def ball_position_in_frame(self, ball_x, ball_y, crop_w, crop_h):
        rel_x = ball_x - (self.cam_x - crop_w / 2)
        rel_y = ball_y - (self.cam_y - crop_h / 2)
        return rel_x, rel_y
    
    def is_ball_safe(self, ball_x, ball_y, crop_w, crop_h):
        rel_x, rel_y = self.ball_position_in_frame(ball_x, ball_y, crop_w, crop_h)
        return (SAFE_MARGIN_X < rel_x < crop_w - SAFE_MARGIN_X and 
                SAFE_MARGIN_Y < rel_y < crop_h - SAFE_MARGIN_Y)
    
    def is_ball_visible(self, ball_x, ball_y, crop_w, crop_h):
        rel_x, rel_y = self.ball_position_in_frame(ball_x, ball_y, crop_w, crop_h)
        return 0 <= rel_x <= crop_w and 0 <= rel_y <= crop_h
    
    def update(self, ball_x, ball_y, is_tracking, celebration_pos=None):
        # Celebration mode overrides normal tracking
        if celebration_pos is not None:
            self.celebration_mode = True
            self.target_zoom = ZOOM_FACTOR_CELEBRATION
            target_x, target_y = celebration_pos
            smoothing = CAMERA_SMOOTHING_CELEBRATION
        elif is_tracking and ball_x is not None:
            self.celebration_mode = False
            self.target_zoom = ZOOM_FACTOR_TRACKING
            target_x, target_y = ball_x, ball_y
            
            crop_w, crop_h = self.get_crop_dimensions()
            if self.is_ball_safe(ball_x, ball_y, crop_w, crop_h):
                smoothing = CAMERA_SMOOTHING_NORMAL
            else:
                smoothing = CAMERA_SMOOTHING_CATCHUP
            
            dist = np.sqrt((ball_x - self.last_ball_x)**2 + (ball_y - self.last_ball_y)**2)
            if dist > MAX_BALL_JUMP:
                target_x = self.last_ball_x + (ball_x - self.last_ball_x) * 0.25
                target_y = self.last_ball_y + (ball_y - self.last_ball_y) * 0.25
            
            self.last_ball_x = ball_x
            self.last_ball_y = ball_y
            self.frames_since_ball = 0
        else:
            self.celebration_mode = False
            self.frames_since_ball += 1
            self.target_zoom = ZOOM_FACTOR_LOST
            target_x, target_y = self.last_ball_x, self.last_ball_y
            smoothing = CAMERA_SMOOTHING_LOST
        
        # Apply zoom
        self.zoom += (self.target_zoom - self.zoom) * ZOOM_SMOOTHING
        
        # Apply camera movement
        self.cam_x += (target_x - self.cam_x) * smoothing
        self.cam_y += (target_y - self.cam_y) * smoothing
        
        crop_w, crop_h = self.get_crop_dimensions()
        
        # Clamp
        half_w = crop_w / 2
        half_h = crop_h / 2
        self.cam_x = np.clip(self.cam_x, half_w, self.frame_w - half_w)
        self.cam_y = np.clip(self.cam_y, half_h, self.frame_h - half_h)
        
        return int(self.cam_x), int(self.cam_y), crop_w, crop_h

# ==========================================
# DRAW MARKER
# ==========================================
def draw_marker(frame, x, y, conf, is_prediction=False, is_goal=False):
    if not MARK_BALL:
        return frame
    
    x, y = int(x), int(y)
    
    if is_goal:
        # Green for goal!
        cv2.circle(frame, (x, y), MARKER_RADIUS + 5, (0, 255, 0), 4)
        cv2.circle(frame, (x, y), MARKER_RADIUS, (0, 255, 0), -1)
    elif is_prediction:
        cv2.circle(frame, (x, y), MARKER_RADIUS, (0, 180, 255), 2)
    else:
        # RED SOLID CIRCLE
        cv2.circle(frame, (x, y), MARKER_RADIUS, MARKER_COLOR, MARKER_THICKNESS)
        cv2.circle(frame, (x, y), 5, MARKER_COLOR, -1)
    
    return frame

# ==========================================
# MAIN PROCESSING
# ==========================================
print("=" * 60)
print("🎬 V18 - ACCURATE + GOAL CELEBRATION")
print("=" * 60)
print(f"📹 Input: {W}x{H} @ {FPS}fps, {TOTAL} frames")
print(f"📹 Output: {BASE_OUTPUT_W}x{BASE_OUTPUT_H}")
print(f"🤖 Model: YOLOv8x")
print(f"⚽ Goal detection: ENABLED")
print(f"🎉 Celebration zoom: ENABLED")
print("=" * 60)

# Initialize
camera = CinematicCamera(W, H)
goal_detector = GoalDetector(W, H)
tracker = None
tracker_ok_count = 0
detection_count = 0

fourcc = cv2.VideoWriter_fourcc(*'mp4v')
out = cv2.VideoWriter(output_path, fourcc, FPS, (BASE_OUTPUT_W, BASE_OUTPUT_H))

if not out.isOpened():
    raise RuntimeError("Failed to create VideoWriter!")

frame_idx = 0
consecutive_misses = 0

print("🎬 Processing...")
start_time = time.time()

while True:
    try:
        ret, frame = cap.read()
        if not ret or frame is None:
            print(f"📹 End at frame {frame_idx}")
            break
        
        frame_idx += 1
        
        # Prediction
        if tracker is not None:
            pred_x, pred_y = tracker.predict()
        else:
            pred_x, pred_y = camera.last_ball_x, camera.last_ball_y
        
        # ===== DETECTION =====
        best_det = None
        
        # Stage 1: High confidence + tiled
        detections = detect_ball_tiled(frame, CONF_HIGH)
        if detections:
            best_det = select_best_detection(detections, pred_x, pred_y, 
                                            camera.last_ball_x, camera.last_ball_y, 
                                            frame.shape)
        
        # Stage 2: Medium confidence
        if best_det is None:
            detections = detect_ball_tiled(frame, CONF_MEDIUM)
            if detections:
                best_det = select_best_detection(detections, pred_x, pred_y,
                                                camera.last_ball_x, camera.last_ball_y,
                                                frame.shape)
        
        # Stage 3: ROI search
        if best_det is None and tracker is not None:
            roi_size = 800
            x1 = max(0, int(pred_x - roi_size/2))
            y1 = max(0, int(pred_y - roi_size/2))
            x2 = min(W, int(pred_x + roi_size/2))
            y2 = min(H, int(pred_y + roi_size/2))
            
            if x2 > x1 + 100 and y2 > y1 + 100:
                roi = frame[y1:y2, x1:x2]
                detections = detect_ball(roi, CONF_LOW, 640)
                for d in detections:
                    d['x'] += x1
                    d['y'] += y1
                if detections:
                    best_det = select_best_detection(detections, pred_x, pred_y,
                                                    camera.last_ball_x, camera.last_ball_y,
                                                    frame.shape)
        
        # Stage 4: Full rescue
        if best_det is None:
            detections = detect_multiscale(frame, CONF_LOW)
            if detections:
                best_det = select_best_detection(detections, pred_x, pred_y,
                                                camera.last_ball_x, camera.last_ball_y,
                                                frame.shape)
        
        # ===== UPDATE TRACKER =====
        ball_x, ball_y = None, None
        is_tracking = False
        is_prediction = False
        best_conf = 0
        is_goal = False
        
        if best_det is not None:
            ball_x = best_det['x']
            ball_y = best_det['y']
            best_conf = best_det['conf']
            detection_count += 1
            
            if tracker is None:
                tracker = SmoothBallTracker(ball_x, ball_y)
                print(f"✅ Ball found at frame {frame_idx}!")
            else:
                tracker.update(ball_x, ball_y, best_conf)
            
            ball_x, ball_y = tracker.get_smoothed_position()
            
            # Check for goal
            is_goal = goal_detector.check_goal(ball_x, ball_y, tracker)
            
            is_tracking = True
            tracker_ok_count += 1
            consecutive_misses = 0
            
        elif tracker is not None:
            consecutive_misses += 1
            
            if consecutive_misses < MAX_KALMAN_COAST:
                ball_x, ball_y = pred_x, pred_y
                is_tracking = True
                is_prediction = True
                tracker_ok_count += 1
                tracker.missed += 1
            else:
                if consecutive_misses == MAX_KALMAN_COAST:
                    print(f"⚠️ Lost ball at frame {frame_idx}")
                tracker = None
        
        # ===== CELEBRATION MODE =====
        celebration_pos = None
        if goal_detector.is_celebrating():
            # Find players to zoom on
            goal_pos = goal_detector.get_celebration_position()
            if goal_pos:
                players = detect_players(frame)
                cluster = find_player_cluster(players, goal_pos[0], goal_pos[1], W)
                if cluster:
                    celebration_pos = cluster
                else:
                    celebration_pos = goal_pos
        
        # ===== DRAW MARKER =====
        if is_tracking and ball_x is not None:
            frame = draw_marker(frame, ball_x, ball_y, best_conf, is_prediction, is_goal)
        
        # ===== CAMERA =====
        cam_x, cam_y, crop_w, crop_h = camera.update(ball_x, ball_y, is_tracking, celebration_pos)
        
        # ===== CROP =====
        try:
            tl_x = int(cam_x - crop_w / 2)
            tl_y = int(cam_y - crop_h / 2)
            
            tl_x = max(0, min(tl_x, W - crop_w))
            tl_y = max(0, min(tl_y, H - crop_h))
            
            crop = frame[tl_y:tl_y+crop_h, tl_x:tl_x+crop_w]
            
            if crop.size == 0 or crop.shape[0] < 10:
                crop = frame
            
            output = cv2.resize(crop, (BASE_OUTPUT_W, BASE_OUTPUT_H), 
                               interpolation=cv2.INTER_LANCZOS4)
            out.write(output)
            
        except Exception as e:
            output = cv2.resize(frame, (BASE_OUTPUT_W, BASE_OUTPUT_H))
            out.write(output)
        
        # ===== PROGRESS =====
        if frame_idx % 25 == 0:
            pct = int(frame_idx / max(1, TOTAL) * 100)
            elapsed = time.time() - start_time
            
            if elapsed > 1:
                fps_actual = frame_idx / elapsed
                det_rate = int(detection_count / frame_idx * 100)
                trk_rate = int(tracker_ok_count / frame_idx * 100)
                mode = "CELEBRATION" if celebration_pos else ("DETECT" if not is_prediction else "KALMAN")
                print(f"📊 {pct}% | {fps_actual:.1f}fps | Det:{det_rate}% Trk:{trk_rate}% [{mode}]")
            
            update_job("processing", progress=pct)
    
    except Exception as e:
        print(f"❌ Error frame {frame_idx}: {e}")
        continue

# ===== CLEANUP =====
elapsed = time.time() - start_time
print(f"\n📊 Done: {frame_idx} frames in {elapsed:.1f}s")

cap.release()
print("✅ cap.release()")

out.release()
print("✅ out.release()")

# ===== FFmpeg =====
import os
import subprocess

if not os.path.exists(output_path):
    raise RuntimeError("No output!")

print(f"📁 Output: {os.path.getsize(output_path) / 1024 / 1024:.1f} MB")

print("🔄 Re-encoding...")
update_job("processing", progress=90)

temp_path = output_path + ".temp.mp4"
os.rename(output_path, temp_path)

ffmpeg_cmd = [
    "ffmpeg", "-y", "-i", temp_path,
    "-c:v", "libx264", "-preset", "slow", "-crf", "18",
    "-r", str(int(FPS)), "-movflags", "+faststart",
    "-pix_fmt", "yuv420p", output_path
]

try:
    result = subprocess.run(ffmpeg_cmd, capture_output=True, text=True, timeout=300)
    if result.returncode == 0:
        os.remove(temp_path)
        print(f"✅ FFmpeg done: {os.path.getsize(output_path) / 1024 / 1024:.1f} MB")
    else:
        os.rename(temp_path, output_path)
except:
    if os.path.exists(temp_path):
        os.rename(temp_path, output_path)

update_job("processing", progress=95)

# ===== FINAL =====
det_acc = int(detection_count / max(1, frame_idx) * 100)
trk_acc = int(tracker_ok_count / max(1, frame_idx) * 100)

print("\n" + "=" * 60)
print("🎉 COMPLETE!")
print(f"⚽ Goals detected: {goal_detector.goals_scored}")
print(f"🎯 Detection: {det_acc}%")
print(f"🎯 Tracking: {trk_acc}%")
print("=" * 60)
