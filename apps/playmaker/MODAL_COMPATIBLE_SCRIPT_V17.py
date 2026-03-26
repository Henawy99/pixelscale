# ==========================================
# MODAL-COMPATIBLE V17 - HIGH ACCURACY
# OPTIMIZED FOR WIDE PANORAMIC CAMERAS
# ==========================================
# 
# KEY IMPROVEMENTS:
# 1. Multi-scale detection (different resolutions)
# 2. Tiled detection for ultra-wide frames (NOW ACTUALLY USED!)
# 3. Better ball size filtering for panoramic cameras
# 4. Motion-based ball candidate detection
# 5. Smarter confidence thresholds
# 6. Detect EVERY frame when tracking is poor
# 7. Better handling of fast-moving balls
#
# ==========================================

import cv2
import numpy as np
import time

# ==========================================
# 1. OUTPUT CONFIGURATION - 16:9 for wider view
# ==========================================
BASE_OUTPUT_W, BASE_OUTPUT_H = 1920, 1080  # 16:9 HD

# ==========================================
# 2. ZOOM SETTINGS
# ==========================================
ZOOM_FACTOR_TRACKING = 0.60   # Show 60% when tracking (more zoomed in)
ZOOM_FACTOR_LOST = 0.85       # Show 85% when lost (wider view)
ZOOM_SMOOTHING = 0.03

# ==========================================
# 3. CAMERA MOVEMENT
# ==========================================
CAMERA_SMOOTHING_NORMAL = 0.06
CAMERA_SMOOTHING_CATCHUP = 0.15
CAMERA_SMOOTHING_LOST = 0.01

SAFE_MARGIN_X = 200
SAFE_MARGIN_Y = 150

# ==========================================
# 4. DETECTION SETTINGS - IMPROVED FOR ACCURACY
# ==========================================
DETECT_EVERY_N_NORMAL = 2     # Every 2nd frame when tracking well
DETECT_EVERY_N_POOR = 1       # EVERY frame when accuracy is low
ACCURACY_THRESHOLD = 50       # Below this %, switch to aggressive detection

# Multi-confidence detection
CONF_HIGH = 0.25      # Very confident (fast)
CONF_MEDIUM = 0.12    # Medium confidence
CONF_LOW = 0.06       # Rescue mode
CONF_ULTRA_LOW = 0.03 # Desperate rescue

# Multi-scale detection sizes
DETECT_SIZES = [640, 960, 1280]  # Try multiple resolutions

# ==========================================
# 5. TRACKING SETTINGS
# ==========================================
MAX_BALL_JUMP = 350           # Allow larger jumps for fast balls
MAX_KALMAN_COAST = 45         # Coast shorter before losing track
VELOCITY_SMOOTHING = 0.4

# Ball size constraints for wide cameras
MIN_BALL_AREA_RATIO = 0.00005  # Min 0.005% of frame area
MAX_BALL_AREA_RATIO = 0.003    # Max 0.3% of frame area

# ==========================================
# 6. BALL MARKER
# ==========================================
MARK_BALL = True
MARKER_RADIUS = 12
MARKER_COLOR = (0, 0, 255)

# ==========================================
# Motion detection settings
# ==========================================
USE_MOTION_DETECTION = True
MOTION_THRESHOLD = 25
MIN_MOTION_AREA = 100
MAX_MOTION_AREA = 5000

# ==========================================
# HELPER: Improved ball tracker with velocity prediction
# ==========================================
class ImprovedBallTracker:
    def __init__(self, x, y, frame_w, frame_h):
        self.x = float(x)
        self.y = float(y)
        self.vx = 0.0
        self.vy = 0.0
        self.ax = 0.0  # Acceleration
        self.ay = 0.0
        self.missed = 0
        self.confidence = 1.0
        self.frame_w = frame_w
        self.frame_h = frame_h
        
        self.history = [(x, y)]
        self.velocity_history = []
        self.max_history = 8
        self.total_detections = 0
        self.good_detections = 0
    
    def predict(self):
        """Predict next position using velocity and acceleration."""
        # Apply physics-based prediction
        pred_x = self.x + self.vx + 0.5 * self.ax
        pred_y = self.y + self.vy + 0.5 * self.ay
        
        # Decay velocity (friction)
        self.vx *= 0.90
        self.vy *= 0.90
        self.ax *= 0.85
        self.ay *= 0.85
        
        # Gravity effect on y
        self.vy += 0.3  # Slight downward bias
        
        # Clamp to frame bounds
        pred_x = np.clip(pred_x, 50, self.frame_w - 50)
        pred_y = np.clip(pred_y, 50, self.frame_h - 50)
        
        return pred_x, pred_y
    
    def update(self, det_x, det_y, conf=1.0):
        """Update with new detection."""
        self.total_detections += 1
        
        # Calculate velocity
        new_vx = det_x - self.x
        new_vy = det_y - self.y
        
        # Calculate acceleration
        if self.velocity_history:
            old_vx, old_vy = self.velocity_history[-1]
            new_ax = new_vx - old_vx
            new_ay = new_vy - old_vy
            self.ax = self.ax * 0.5 + new_ax * 0.5
            self.ay = self.ay * 0.5 + new_ay * 0.5
        
        # Update velocity (weighted by confidence)
        weight = min(conf * 1.2 + 0.3, 1.0)
        self.vx = self.vx * (1 - weight * VELOCITY_SMOOTHING) + new_vx * weight * VELOCITY_SMOOTHING
        self.vy = self.vy * (1 - weight * VELOCITY_SMOOTHING) + new_vy * weight * VELOCITY_SMOOTHING
        
        # Update position
        self.x = self.x * (1 - weight) + det_x * weight
        self.y = self.y * (1 - weight) + det_y * weight
        
        self.confidence = conf
        self.missed = 0
        self.good_detections += 1
        
        # Update history
        self.history.append((det_x, det_y))
        self.velocity_history.append((new_vx, new_vy))
        
        if len(self.history) > self.max_history:
            self.history.pop(0)
        if len(self.velocity_history) > self.max_history:
            self.velocity_history.pop(0)
    
    def get_smoothed_position(self):
        if len(self.history) < 2:
            return self.x, self.y
        
        weights = [0.05, 0.08, 0.12, 0.15, 0.18, 0.18, 0.12, 0.12][-len(self.history):]
        total = sum(weights)
        
        sx = sum(h[0] * w for h, w in zip(self.history, weights)) / total
        sy = sum(h[1] * w for h, w in zip(self.history, weights)) / total
        
        return sx, sy
    
    def get_accuracy(self):
        if self.total_detections == 0:
            return 0
        return (self.good_detections / self.total_detections) * 100
    
    def get_speed(self):
        return np.sqrt(self.vx**2 + self.vy**2)


# ==========================================
# HELPER: Multi-scale ball detection
# ==========================================
def detect_ball_multiscale(yolo_model, frame, base_confidence, sizes=DETECT_SIZES):
    """Run detection at multiple scales for better accuracy."""
    all_detections = []
    h, w = frame.shape[:2]
    
    for size in sizes:
        try:
            # Scale down for detection, then scale coords back up
            scale = size / max(w, h)
            if scale >= 1.0:
                results = yolo_model.predict(frame, conf=base_confidence, classes=[32], 
                                            imgsz=size, verbose=False)
            else:
                # Resize for detection
                small = cv2.resize(frame, None, fx=scale, fy=scale)
                results = yolo_model.predict(small, conf=base_confidence, classes=[32], 
                                            imgsz=size, verbose=False)
            
            boxes = results[0].boxes
            if boxes is None or len(boxes) == 0:
                continue
            
            for box in boxes:
                data = box.data.cpu().numpy()[0]
                x1, y1, x2, y2, conf, cls = data
                
                # Scale coordinates back to original size
                if scale < 1.0:
                    x1, y1, x2, y2 = x1/scale, y1/scale, x2/scale, y2/scale
                
                cx = (x1 + x2) / 2
                cy = (y1 + y2) / 2
                bw = x2 - x1
                bh = y2 - y1
                
                all_detections.append({
                    'x': cx, 'y': cy,
                    'w': bw, 'h': bh,
                    'conf': conf,
                    'area': bw * bh,
                    'scale': size
                })
                
        except Exception as e:
            continue
    
    return all_detections


def detect_ball_tiled(yolo_model, frame, confidence):
    """Detect ball using tiles for ultra-wide frames."""
    h, w = frame.shape[:2]
    all_detections = []
    
    # ALWAYS do full frame first
    dets = detect_ball_multiscale(yolo_model, frame, confidence, [960])
    all_detections.extend(dets)
    
    # For wide frames, add overlapping tiles
    if w > 2000:
        n_tiles = max(3, w // 1500)  # More tiles for wider frames
        tile_width = int(w / (n_tiles - 0.5))  # Overlap
        
        for i in range(n_tiles):
            start_x = max(0, int(i * (w - tile_width) / (n_tiles - 1)))
            end_x = min(w, start_x + tile_width)
            
            tile = frame[:, start_x:end_x]
            tile_dets = detect_ball_multiscale(yolo_model, tile, confidence * 0.9, [640, 960])
            
            # Offset coordinates to full frame
            for d in tile_dets:
                d['x'] += start_x
            
            all_detections.extend(tile_dets)
    
    # Remove duplicates (detections within 50px of each other)
    return remove_duplicate_detections(all_detections)


def remove_duplicate_detections(detections, min_dist=50):
    """Remove duplicate detections that are very close together."""
    if not detections:
        return []
    
    # Sort by confidence
    sorted_dets = sorted(detections, key=lambda d: d['conf'], reverse=True)
    unique = []
    
    for det in sorted_dets:
        is_duplicate = False
        for u in unique:
            dist = np.sqrt((det['x'] - u['x'])**2 + (det['y'] - u['y'])**2)
            if dist < min_dist:
                is_duplicate = True
                break
        
        if not is_duplicate:
            unique.append(det)
    
    return unique


def detect_motion_candidates(prev_frame, curr_frame, min_area=MIN_MOTION_AREA, max_area=MAX_MOTION_AREA):
    """Use motion detection to find ball candidates."""
    if prev_frame is None:
        return []
    
    try:
        # Convert to grayscale
        if len(prev_frame.shape) == 3:
            prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)
            curr_gray = cv2.cvtColor(curr_frame, cv2.COLOR_BGR2GRAY)
        else:
            prev_gray = prev_frame
            curr_gray = curr_frame
        
        # Blur to reduce noise
        prev_blur = cv2.GaussianBlur(prev_gray, (21, 21), 0)
        curr_blur = cv2.GaussianBlur(curr_gray, (21, 21), 0)
        
        # Frame difference
        diff = cv2.absdiff(prev_blur, curr_blur)
        thresh = cv2.threshold(diff, MOTION_THRESHOLD, 255, cv2.THRESH_BINARY)[1]
        
        # Find contours
        thresh = cv2.dilate(thresh, None, iterations=2)
        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        candidates = []
        for contour in contours:
            area = cv2.contourArea(contour)
            if min_area < area < max_area:
                M = cv2.moments(contour)
                if M["m00"] > 0:
                    cx = int(M["m10"] / M["m00"])
                    cy = int(M["m01"] / M["m00"])
                    candidates.append({'x': cx, 'y': cy, 'area': area})
        
        return candidates
        
    except Exception as e:
        return []


def select_best_detection(detections, pred_x, pred_y, last_x, last_y, frame_shape, tracker=None):
    """Select most likely ball from detections with improved logic."""
    if not detections:
        return None
    
    h, w = frame_shape[:2]
    frame_area = w * h
    
    # Dynamic size constraints based on frame size
    min_area = frame_area * MIN_BALL_AREA_RATIO
    max_area = frame_area * MAX_BALL_AREA_RATIO
    
    scored = []
    for det in detections:
        # Size filter
        if det['area'] < min_area or det['area'] > max_area:
            continue
        
        # Aspect ratio filter (balls should be roughly circular)
        aspect = det['w'] / max(det['h'], 1)
        if aspect < 0.5 or aspect > 2.0:
            continue
        
        # Distance scoring
        dist_pred = np.sqrt((det['x'] - pred_x)**2 + (det['y'] - pred_y)**2)
        dist_last = np.sqrt((det['x'] - last_x)**2 + (det['y'] - last_y)**2)
        
        # More lenient distance filter for first detection
        max_jump = MAX_BALL_JUMP * 2 if tracker is None else MAX_BALL_JUMP
        if dist_pred > max_jump and dist_last > max_jump:
            continue
        
        # Score calculation
        score = 0.0
        
        # Confidence (40%)
        score += det['conf'] * 0.4
        
        # Distance to prediction (30%)
        score += (1.0 / (1.0 + dist_pred / 300)) * 0.3
        
        # Distance to last position (20%)
        score += (1.0 / (1.0 + dist_last / 400)) * 0.2
        
        # Size preference - prefer medium-sized balls (10%)
        ideal_size = frame_area * 0.0008  # ~0.08% of frame
        size_diff = abs(det['area'] - ideal_size) / ideal_size
        score += (1.0 / (1.0 + size_diff)) * 0.1
        
        # Velocity consistency bonus
        if tracker and tracker.get_speed() > 5:
            # Predict where ball should be based on velocity
            expected_x = last_x + tracker.vx
            expected_y = last_y + tracker.vy
            dist_velocity = np.sqrt((det['x'] - expected_x)**2 + (det['y'] - expected_y)**2)
            score += (1.0 / (1.0 + dist_velocity / 200)) * 0.1
        
        scored.append((score, det))
    
    if not scored:
        return None
    
    # Return best
    scored.sort(key=lambda x: x[0], reverse=True)
    return scored[0][1]


# ==========================================
# HELPER: Guaranteed ball camera
# ==========================================
class GuaranteedBallCamera:
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
    
    def update(self, ball_x, ball_y, is_tracking):
        self.target_zoom = ZOOM_FACTOR_TRACKING if is_tracking else ZOOM_FACTOR_LOST
        self.zoom += (self.target_zoom - self.zoom) * ZOOM_SMOOTHING
        
        crop_w, crop_h = self.get_crop_dimensions()
        
        if is_tracking and ball_x is not None:
            self.frames_since_ball = 0
            
            dist = np.sqrt((ball_x - self.last_ball_x)**2 + (ball_y - self.last_ball_y)**2)
            if dist > MAX_BALL_JUMP:
                ball_x = self.last_ball_x + (ball_x - self.last_ball_x) * 0.3
                ball_y = self.last_ball_y + (ball_y - self.last_ball_y) * 0.3
            
            self.last_ball_x = ball_x
            self.last_ball_y = ball_y
            
            target_cam_x = ball_x
            target_cam_y = ball_y
            
            if self.is_ball_safe(ball_x, ball_y, crop_w, crop_h):
                smoothing = CAMERA_SMOOTHING_NORMAL
            elif self.is_ball_visible(ball_x, ball_y, crop_w, crop_h):
                smoothing = CAMERA_SMOOTHING_CATCHUP
            else:
                smoothing = 0.4
            
            self.cam_x += (target_cam_x - self.cam_x) * smoothing
            self.cam_y += (target_cam_y - self.cam_y) * smoothing
            
            if not self.is_ball_visible(ball_x, ball_y, crop_w, crop_h):
                rel_x, rel_y = self.ball_position_in_frame(ball_x, ball_y, crop_w, crop_h)
                if rel_x < 0:
                    self.cam_x += rel_x - SAFE_MARGIN_X
                elif rel_x > crop_w:
                    self.cam_x += rel_x - crop_w + SAFE_MARGIN_X
                if rel_y < 0:
                    self.cam_y += rel_y - SAFE_MARGIN_Y
                elif rel_y > crop_h:
                    self.cam_y += rel_y - crop_h + SAFE_MARGIN_Y
        else:
            self.frames_since_ball += 1
            if self.frames_since_ball > 60:
                center_x = self.frame_w / 2
                center_y = self.frame_h / 2
                self.cam_x += (center_x - self.cam_x) * 0.01
                self.cam_y += (center_y - self.cam_y) * 0.01
        
        half_w = crop_w / 2
        half_h = crop_h / 2
        self.cam_x = np.clip(self.cam_x, half_w, self.frame_w - half_w)
        self.cam_y = np.clip(self.cam_y, half_h, self.frame_h - half_h)
        
        return int(self.cam_x), int(self.cam_y), crop_w, crop_h


def draw_marker(frame, x, y, conf, is_prediction=False):
    if not MARK_BALL:
        return frame
    
    x, y = int(x), int(y)
    
    if is_prediction:
        cv2.circle(frame, (x, y), MARKER_RADIUS, (0, 255, 255), 2)
    else:
        cv2.circle(frame, (x, y), MARKER_RADIUS + 2, MARKER_COLOR, 3)
        cv2.circle(frame, (x, y), 5, MARKER_COLOR, -1)
        
        if conf > 0:
            angle = int(360 * min(conf, 1.0))
            cv2.ellipse(frame, (x, y), (MARKER_RADIUS + 5, MARKER_RADIUS + 5),
                       0, 0, angle, (0, 255, 0), 2)
    
    return frame


# ==========================================
# MAIN PROCESSING LOOP
# ==========================================
print("=" * 60)
print("🎬 V17 HIGH ACCURACY - Optimized for Wide Cameras")
print("=" * 60)
print(f"📹 Input: {W}x{H} @ {FPS}fps, {TOTAL} frames")
print(f"📹 Output: {BASE_OUTPUT_W}x{BASE_OUTPUT_H} (16:9)")
print(f"🔭 Zoom: {ZOOM_FACTOR_TRACKING} tracking / {ZOOM_FACTOR_LOST} lost")
print(f"🔍 Detection: Multi-scale {DETECT_SIZES}")
print(f"🔍 Confidence: {CONF_HIGH}/{CONF_MEDIUM}/{CONF_LOW}")
print(f"📐 Ball size: {MIN_BALL_AREA_RATIO*100:.4f}% - {MAX_BALL_AREA_RATIO*100:.2f}% of frame")
print(f"🎯 Motion detection: {USE_MOTION_DETECTION}")
print("=" * 60)

# Initialize
camera = GuaranteedBallCamera(W, H)
tracker = None
tracker_ok_count = 0

fourcc = cv2.VideoWriter_fourcc(*'mp4v')
out = cv2.VideoWriter(output_path, fourcc, FPS, (BASE_OUTPUT_W, BASE_OUTPUT_H))

if not out.isOpened():
    raise RuntimeError(f"Failed to open VideoWriter for {output_path}")

frame_idx = 0
last_detection_frame = -999
consecutive_misses = 0
prev_frame = None
running_accuracy = 50  # Start with assumed 50%

print("🎬 Starting processing...")
start_time = time.time()

try:
    while True:
        ret, frame = cap.read()
        if not ret or frame is None:
            print(f"📹 End of video at frame {frame_idx}/{TOTAL}")
            break
        
        frame_idx += 1
        
        # ===== 1. GET PREDICTION =====
        if tracker is not None:
            pred_x, pred_y = tracker.predict()
        else:
            pred_x, pred_y = camera.last_ball_x, camera.last_ball_y
        
        # ===== 2. DETECT BALL =====
        best_det = None
        
        # Adaptive detection frequency based on accuracy
        if running_accuracy < ACCURACY_THRESHOLD:
            detect_every = DETECT_EVERY_N_POOR  # Every frame when struggling
        else:
            detect_every = DETECT_EVERY_N_NORMAL
        
        should_detect = (frame_idx % detect_every == 0) or (tracker is None) or (consecutive_misses > 5)
        
        if should_detect:
            # Stage 1: High confidence with tiled detection
            detections = detect_ball_tiled(model, frame, CONF_HIGH)
            if detections:
                best_det = select_best_detection(detections, pred_x, pred_y,
                                                camera.last_ball_x, camera.last_ball_y,
                                                frame.shape, tracker)
            
            # Stage 2: Medium confidence
            if best_det is None:
                detections = detect_ball_tiled(model, frame, CONF_MEDIUM)
                if detections:
                    best_det = select_best_detection(detections, pred_x, pred_y,
                                                    camera.last_ball_x, camera.last_ball_y,
                                                    frame.shape, tracker)
            
            # Stage 3: Low confidence with ROI
            if best_det is None and tracker is not None:
                roi_size = 800
                x1 = max(0, int(pred_x - roi_size/2))
                y1 = max(0, int(pred_y - roi_size/2))
                x2 = min(W, int(pred_x + roi_size/2))
                y2 = min(H, int(pred_y + roi_size/2))
                
                if x2 > x1 + 100 and y2 > y1 + 100:
                    roi = frame[y1:y2, x1:x2]
                    detections = detect_ball_multiscale(model, roi, CONF_LOW, [640])
                    for d in detections:
                        d['x'] += x1
                        d['y'] += y1
                    if detections:
                        best_det = select_best_detection(detections, pred_x, pred_y,
                                                        camera.last_ball_x, camera.last_ball_y,
                                                        frame.shape, tracker)
            
            # Stage 4: Ultra-low confidence + motion detection (desperate)
            if best_det is None and consecutive_misses > 15 and USE_MOTION_DETECTION:
                motion_candidates = detect_motion_candidates(prev_frame, frame)
                
                if motion_candidates:
                    # Run detection on motion areas
                    for mc in motion_candidates[:3]:  # Top 3 motion areas
                        roi_size = 400
                        x1 = max(0, int(mc['x'] - roi_size/2))
                        y1 = max(0, int(mc['y'] - roi_size/2))
                        x2 = min(W, int(mc['x'] + roi_size/2))
                        y2 = min(H, int(mc['y'] + roi_size/2))
                        
                        if x2 > x1 + 50 and y2 > y1 + 50:
                            roi = frame[y1:y2, x1:x2]
                            detections = detect_ball_multiscale(model, roi, CONF_ULTRA_LOW, [640])
                            for d in detections:
                                d['x'] += x1
                                d['y'] += y1
                            if detections:
                                best_det = select_best_detection(detections, pred_x, pred_y,
                                                                camera.last_ball_x, camera.last_ball_y,
                                                                frame.shape, tracker)
                                if best_det:
                                    break
        
        # ===== 3. UPDATE TRACKER =====
        ball_x, ball_y = None, None
        is_tracking = False
        is_prediction = False
        best_conf = 0
        
        if best_det is not None:
            ball_x = best_det['x']
            ball_y = best_det['y']
            best_conf = best_det['conf']
            
            if tracker is None:
                tracker = ImprovedBallTracker(ball_x, ball_y, W, H)
                print(f"✅ Tracker started at frame {frame_idx}")
            else:
                tracker.update(ball_x, ball_y, best_conf)
            
            ball_x, ball_y = tracker.get_smoothed_position()
            is_tracking = True
            tracker_ok_count += 1
            last_detection_frame = frame_idx
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
                    print(f"⚠️ Tracker lost at frame {frame_idx}")
                tracker = None
        
        # Update running accuracy
        if frame_idx > 0:
            running_accuracy = (tracker_ok_count / frame_idx) * 100
        
        # ===== 4. DRAW MARKER =====
        if is_tracking and ball_x is not None:
            frame = draw_marker(frame, ball_x, ball_y, best_conf, is_prediction)
        
        # ===== 5. UPDATE CAMERA =====
        cam_x, cam_y, crop_w, crop_h = camera.update(ball_x, ball_y, is_tracking)
        
        # ===== 6. CROP AND RESIZE =====
        try:
            tl_x = max(0, min(int(cam_x - crop_w / 2), W - crop_w))
            tl_y = max(0, min(int(cam_y - crop_h / 2), H - crop_h))
            
            crop = frame[tl_y:tl_y+crop_h, tl_x:tl_x+crop_w]
            
            if crop.size == 0 or crop.shape[0] < 10:
                crop_h = min(H, int(W / camera.output_aspect))
                crop_w = int(crop_h * camera.output_aspect)
                tl_x = (W - crop_w) // 2
                tl_y = (H - crop_h) // 2
                crop = frame[tl_y:tl_y+crop_h, tl_x:tl_x+crop_w]
            
            output = cv2.resize(crop, (BASE_OUTPUT_W, BASE_OUTPUT_H), interpolation=cv2.INTER_LINEAR)
            out.write(output)
            
        except Exception as e:
            print(f"❌ Crop error frame {frame_idx}: {e}")
            output = cv2.resize(frame, (BASE_OUTPUT_W, BASE_OUTPUT_H))
            out.write(output)
        
        # ===== 7. PROGRESS =====
        if frame_idx % 100 == 0:
            pct = int(frame_idx / max(1, TOTAL) * 100)
            mode = "DETECT" if not is_prediction else "KALMAN" if is_tracking else "LOST"
            
            elapsed = time.time() - start_time
            if elapsed > 1:
                fps_actual = frame_idx / elapsed
                eta_seconds = (TOTAL - frame_idx) / max(1, fps_actual)
                eta_min = int(eta_seconds / 60)
                print(f"📊 {frame_idx}/{TOTAL} ({pct}%) [{mode}] Acc:{running_accuracy:.0f}% ETA:{eta_min}m @{fps_actual:.1f}fps")
            
            update_job("processing", progress=pct)
        
        # Store frame for motion detection
        prev_frame = frame.copy()

except Exception as e:
    print(f"❌ Fatal error at frame {frame_idx}: {e}")
    import traceback
    traceback.print_exc()

# ===== CLEANUP =====
print(f"\n📊 Processing complete: {frame_idx} frames processed")
print(f"🎯 Final accuracy: {tracker_ok_count}/{frame_idx} = {running_accuracy:.1f}%")

cap.release()
print("✅ VideoCapture released")

out.release()
print("✅ VideoWriter released")

# ===== VERIFY OUTPUT =====
import os
if not os.path.exists(output_path):
    raise RuntimeError("Output file not created!")

output_size = os.path.getsize(output_path) / (1024 * 1024)
print(f"✅ Output file: {output_size:.1f} MB")

# ===== FFMPEG RE-ENCODE =====
print("🔄 Re-encoding for web compatibility...")
update_job("processing", progress=90)

temp_path = output_path + ".temp.mp4"
os.rename(output_path, temp_path)

import subprocess
ffmpeg_cmd = [
    "ffmpeg", "-y",
    "-i", temp_path,
    "-c:v", "libx264",
    "-preset", "fast",
    "-crf", "22",
    "-movflags", "+faststart",
    "-pix_fmt", "yuv420p",
    output_path
]

try:
    result = subprocess.run(ffmpeg_cmd, capture_output=True, text=True, timeout=600)
    if result.returncode == 0:
        os.remove(temp_path)
        final_size = os.path.getsize(output_path) / (1024 * 1024)
        print(f"✅ FFmpeg re-encode complete: {final_size:.1f} MB")
    else:
        print(f"⚠️ FFmpeg error, using raw output: {result.stderr[:300]}")
        os.rename(temp_path, output_path)
except Exception as e:
    print(f"⚠️ FFmpeg failed: {e}")
    if os.path.exists(temp_path):
        os.rename(temp_path, output_path)

update_job("processing", progress=95)

# ===== FINAL STATS =====
accuracy = int(tracker_ok_count / max(1, frame_idx) * 100)
processing_time = time.time() - start_time

print("\n" + "=" * 60)
print("🎉 PROCESSING COMPLETE!")
print(f"📊 Final Accuracy: {accuracy}% ({tracker_ok_count}/{frame_idx} frames)")
print(f"⏱️ Processing Time: {processing_time:.1f}s")
print(f"📹 Duration: {frame_idx/FPS:.1f}s @ {FPS}fps")
print(f"📐 Output: {BASE_OUTPUT_W}x{BASE_OUTPUT_H}")
print("=" * 60)


