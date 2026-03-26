const String kRobustBallTrackingScript = r'''
# ==================================================================================
# 🔬 MICROSCOPIC REOLINK PANORAMIC v7.2
# ==================================================================================
# DESIGNED FOR: 4608x1728 Panoramic Videos where ball is TINY (<5 pixels)
#
# FIXES vs v7.1:
# 1. DISABLED all size/shape filters (Accepts any detection)
# 2. HIGHER Resolution (1280px) to keep ball visible
# 3. Lower Confidence (0.10) to catch faint balls
# 4. Letterbox resize + Exact coordinate mapping
# ==================================================================================

# --- CONFIGURATION ---
try: YOLO_MODEL
except NameError: YOLO_MODEL = "yolov8l"

try: YOLO_IMG_SIZE
except NameError: YOLO_IMG_SIZE = 1280  # Increased from 960 to see tiny balls

try: YOLO_CONF
except NameError: YOLO_CONF = 0.10        # Lower confidence

try: DETECT_EVERY
except NameError: DETECT_EVERY = 2

# --- CONSTANTS ---
OUTPUT_WIDTH = W
OUTPUT_HEIGHT = H

# Camera
ZOOM_BASE = 2.5
ZOOM_IDLE = 1.5
SMOOTH_FACTOR = 1.0
DEADZONE_X = 0.0
DEADZONE_Y = 0.0

# Physics - FILTERS DISABLED
MAX_SPEED_PIXELS = 600   # Allow very fast movement
# MIN_BALL_AREA and ASPECT_RATIO checks removed!

tracker_ok_count = 0
accuracy = 0

# ==================================================================================
# HELPER: LETTERBOX RESIZE
# ==================================================================================
def letterbox(im, new_shape=(1280, 1280), color=(114, 114, 114)):
    shape = im.shape[:2]
    if isinstance(new_shape, int): new_shape = (new_shape, new_shape)
    r = min(new_shape[0] / shape[0], new_shape[1] / shape[1])
    new_unpad = int(round(shape[1] * r)), int(round(shape[0] * r))
    dw, dh = new_shape[1] - new_unpad[0], new_shape[0] - new_unpad[1]
    dw /= 2; dh /= 2
    if shape[::-1] != new_unpad:
        im = cv2.resize(im, new_unpad, interpolation=cv2.INTER_LINEAR)
    top, bottom = int(round(dh - 0.1)), int(round(dh + 0.1))
    left, right = int(round(dw - 0.1)), int(round(dw + 0.1))
    im = cv2.copyMakeBorder(im, top, bottom, left, right, cv2.BORDER_CONSTANT, value=color)
    return im, r, (dw, dh)

# ==================================================================================
# CLASSES
# ==================================================================================

class AdvancedKalmanFilter:
    def __init__(self, x, y):
        self.kf = cv2.KalmanFilter(4, 2)
        self.kf.measurementMatrix = np.array([[1,0,0,0], [0,1,0,0]], np.float32)
        self.kf.transitionMatrix = np.array([[1,0,1,0], [0,1,0,1], [0,0,1,0], [0,0,0,1]], np.float32)
        self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * 0.05
        self.kf.processNoiseCov[2:, 2:] *= 20.0
        self.kf.measurementNoiseCov = np.eye(2, dtype=np.float32) * 0.05
        self.kf.statePost = np.array([[x], [y], [0], [0]], np.float32)
        self.kf.errorCovPost = np.eye(4, dtype=np.float32) * 1.0

    def predict(self):
        p = self.kf.predict()
        px = float(p[0]) if p.ndim == 1 else float(p[0, 0])
        py = float(p[1]) if p.ndim == 1 else float(p[1, 0])
        return (px, py)

    def update(self, x, y):
        self.kf.correct(np.array([[x], [y]], np.float32))
        px = float(self.kf.statePost[0]) if self.kf.statePost.ndim == 1 else float(self.kf.statePost[0, 0])
        py = float(self.kf.statePost[1]) if self.kf.statePost.ndim == 1 else float(self.kf.statePost[1, 0])
        return (px, py)

class InstantCamera:
    def __init__(self, w, h, out_w, out_h):
        self.W, self.H = w, h
        self.out_w, self.out_h = out_w, out_h
        self.cam_x = w / 2
        self.cam_y = h / 2
        self.current_zoom = ZOOM_IDLE
        
    def update(self, target_x, target_y, is_tracking):
        target_zoom = ZOOM_BASE if is_tracking else ZOOM_IDLE
        self.current_zoom += (target_zoom - self.current_zoom) * 0.2
        
        if target_x is not None:
            self.cam_x = target_x
            self.cam_y = target_y
        
        half_w = (self.W / self.current_zoom) / 2
        half_h = (self.H / self.current_zoom) / 2
        self.cam_x = np.clip(self.cam_x, half_w, self.W - half_w)
        self.cam_y = np.clip(self.cam_y, half_h, self.H - half_h)
        
        return int(self.cam_x), int(self.cam_y), self.current_zoom

# ==================================================================================
# INITIALIZATION
# ==================================================================================
print("🔬 MICROSCOPIC TRACKING v7.2")
print(f"Using High-Res {YOLO_IMG_SIZE}px for tiny ball detection")

fourcc = cv2.VideoWriter_fourcc(*'mp4v')
out = cv2.VideoWriter(output_path, fourcc, FPS, (OUTPUT_WIDTH, OUTPUT_HEIGHT))

tracker = None
cam = InstantCamera(W, H, OUTPUT_WIDTH, OUTPUT_HEIGHT)
ball_history = []
lost_frames = 0
max_lost_frames = int(FPS * 3.0)

# ==================================================================================
# PROCESSING LOOP
# ==================================================================================
frame_idx = 0
start_time = time.time()

while True:
    ret, frame = cap.read()
    if not ret: break
    frame_idx += 1
    
    predicted_pos = None
    if tracker:
        predicted_pos = tracker.predict()
    
    detections = []
    
    if frame_idx % DETECT_EVERY == 0 or tracker is None:
        # 1. Letterbox resize to 1280px (bigger image = bigger ball pixels)
        img_letterbox, ratio, (dw, dh) = letterbox(frame, new_shape=YOLO_IMG_SIZE, color=(114, 114, 114))
        
        # 2. Run YOLO
        results = model(img_letterbox, conf=YOLO_CONF, verbose=False, classes=[32])
        
        # 3. If nothing found, try EXTREME sensitivity
        if len(results[0].boxes) == 0:
             results = model(img_letterbox, conf=0.01, verbose=False, classes=[32])
        
        # 4. Map coordinates
        if len(results[0].boxes) > 0:
            boxes = results[0].boxes.xyxy.cpu().numpy()
            confs = results[0].boxes.conf.cpu().numpy()
            
            boxes[:, [0, 2]] -= dw
            boxes[:, [1, 3]] -= dh
            boxes[:, :4] /= ratio
            
            for i, box in enumerate(boxes):
                bx1, by1, bx2, by2 = box
                conf = float(confs[i])
                
                w_b, h_b = bx2 - bx1, by2 - by1
                area = w_b * h_b
                
                # Accept anything YOLO considers a ball (microscopic mode)
                
                cx, cy = (bx1 + bx2)/2, (by1 + by2)/2
                
                # Bounds check
                cx = max(0, min(cx, W))
                cy = max(0, min(cy, H))
                
                detections.append({'pos': (cx, cy), 'score': conf})

    # --- ASSOCIATION ---
    best_det = None
    if detections:
        # Sort by score
        detections.sort(key=lambda x: x['score'], reverse=True)
        
        # If we have a tracker, prefer the one closest to prediction
        if predicted_pos:
            best_dist = float('inf')
            for det in detections:
                dist = np.sqrt((det['pos'][0] - predicted_pos[0])**2 + (det['pos'][1] - predicted_pos[1])**2)
                if dist < best_dist and dist < MAX_SPEED_PIXELS:
                    best_dist = dist
                    best_det = det
        
        # If no tracker or no close detection, take the highest score
        if best_det is None:
            best_det = detections[0]
    
    # --- TRACKER UPDATE ---
    current_ball_pos = None
    
    if best_det:
        cx, cy = best_det['pos']
        if tracker is None:
            tracker = AdvancedKalmanFilter(cx, cy)
        else:
            tracker.update(cx, cy)
        
        current_ball_pos = (cx, cy)
        lost_frames = 0
        tracker_ok_count += 1
        
    elif tracker:
        if lost_frames < max_lost_frames:
            current_ball_pos = predicted_pos
            tracker_ok_count += 1
            lost_frames += 1
        else:
            tracker = None
            lost_frames = 0
    
    # --- CAMERA UPDATE ---
    target_x, target_y = None, None
    is_tracking = False
    
    if current_ball_pos:
        target_x, target_y = current_ball_pos
        is_tracking = True
        ball_history.append(current_ball_pos)
        if len(ball_history) > 90: ball_history.pop(0)
    elif len(ball_history) > 0:
        target_x, target_y = ball_history[-1]
    
    cx, cy, zoom = cam.update(target_x, target_y, is_tracking)
    
    # --- RENDER ---
    view_w = int(W / zoom)
    view_h = int(H / zoom)
    x1 = max(0, min(int(cx - view_w/2), W - view_w))
    y1 = max(0, min(int(cy - view_h/2), H - view_h))
    x2 = x1 + view_w
    y2 = y1 + view_h
    
    crop = frame[y1:y2, x1:x2]
    
    if crop.size > 0:
        final_frame = cv2.resize(crop, (OUTPUT_WIDTH, OUTPUT_HEIGHT), interpolation=cv2.INTER_LINEAR)
        out.write(final_frame)
    else:
        out.write(cv2.resize(frame, (OUTPUT_WIDTH, OUTPUT_HEIGHT)))
    
    if frame_idx % 30 == 0:
        pct = int(frame_idx/TOTAL * 100)
        update_job("processing", progress=pct)

cap.release()
out.release()

accuracy = int((tracker_ok_count / max(1, TOTAL)) * 100)
print(f"✅ DONE. Accuracy: {accuracy}%")

print("🔄 Optimizing video...")
tmp_out = output_path + ".tmp.mp4"
os.rename(output_path, tmp_out)
subprocess.run([
    "ffmpeg", "-y", "-i", tmp_out, 
    "-c:v", "libx264", "-crf", "23", "-preset", "fast", 
    "-movflags", "+faststart",
    output_path
], check=False)
if os.path.exists(tmp_out): os.remove(tmp_out)
''';

const String kWorkingBallTrackingScript = r'''
# ==================================================================================
# ✅ WORKING SCRIPT (Hybrid: YOLO tiling + Motion rescue + Kalman + Smooth PTZ)
# Adapted for Modal exec env. Uses provided cap/W/H/FPS/TOTAL/output_path/update_job.
# NOTE: YOLO thresholds are defined here (CONF_STRONG/CONF_WEAK). We use the YOLO
#       model instance provided by the backend (variable: model) and do not change
#       any global settings outside this script.
# ==================================================================================

import numpy as np
import cv2

# -----------------------------
# 1) CONFIG - keep as provided
# -----------------------------
BASE_OUTPUT_W, BASE_OUTPUT_H = W, H
ZOOM_FACTOR_MAX = 0.6    # zoomed-in crop when tracking (0.6 * W/H)
ZOOM_FACTOR_LOST = 1.0   # full frame when lost
ZOOM_SMOOTHING = 0.05
CONF_STRONG = 0.4         # high-confidence acceptance
CONF_WEAK = 0.05          # rescue threshold
FIELD_MAX_X_RATIO = 1.0   # exclusion zone (1.0 disables filter)
MAX_MISSED_FRAMES = 40
CAMERA_SMOOTHING = 0.06

# -----------------------------
# 2) YOLO tiling (4 tiles)
# -----------------------------
def detect_with_tiling(yolo_model, frame, confidence_threshold):
    img_h, img_w = frame.shape[:2]
    tile_w = int(img_w * 0.40)
    tiles = [
        (0, 0, tile_w, img_h),
        (int(img_w * 0.20), 0, tile_w, img_h),
        (int(img_w * 0.40), 0, tile_w, img_h),
        (img_w - tile_w, 0, tile_w, img_h),
    ]
    all_dets = []
    for tx, ty, tw, th in tiles:
        tile_img = frame[ty:ty+th, tx:tx+tw]
        res = yolo_model.predict(tile_img, conf=confidence_threshold, classes=[32], verbose=False)
        boxes = res[0].boxes
        if boxes is not None and len(boxes) > 0:
            det = boxes.data.cpu().numpy()  # xyxy, conf, cls
            if det.size == 0:
                continue
            det[:, 0] += tx
            det[:, 2] += tx
            all_dets.append(det)
    if not all_dets:
        return np.array([])
    return np.vstack(all_dets)

# -------------------------------------
# 3) Motion cue via background subtr.
# -------------------------------------
def get_motion_cue_MOG2(frame, backSub, prediction_center):
    fgMask = backSub.apply(frame, learningRate=0.01)
    px, py = int(prediction_center[0]), int(prediction_center[1])
    search_size = 250
    x1 = max(0, px - search_size)
    y1 = max(0, py - search_size)
    x2 = min(frame.shape[1], px + search_size)
    x2 = min(x2, int(frame.shape[1] * FIELD_MAX_X_RATIO))
    y2 = min(frame.shape[0], py + search_size)
    if x1 >= x2 or y1 >= y2:
        return None
    motion_window = fgMask[y1:y2, x1:x2]
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    motion_window = cv2.morphologyEx(motion_window, cv2.MORPH_OPEN, kernel)
    contours, _ = cv2.findContours(motion_window, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    best_motion_center = None
    max_area = 0
    for c in contours:
        area = cv2.contourArea(c)
        if area > 100 and area > max_area:
            M = cv2.moments(c)
            if M["m00"] != 0:
                cx = int(M["m10"] / M["m00"]) + x1
                cy = int(M["m01"] / M["m00"]) + y1
                best_motion_center = (cx, cy)
                max_area = area
    return best_motion_center

# -----------------------------
# 4) Kalman (OpenCV 4D: x,y,vx,vy)
# -----------------------------
class BallTracker:
    def __init__(self):
        self.kf = cv2.KalmanFilter(4, 2)
        self.kf.transitionMatrix = np.array([[1,0,1,0],
                                             [0,1,0,1],
                                             [0,0,1,0],
                                             [0,0,0,1]], np.float32)
        self.kf.measurementMatrix = np.array([[1,0,0,0],
                                              [0,1,0,0]], np.float32)
        # Higher process noise: allow sudden changes (kicks)
        self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * 25.0
        # Smaller measurement noise: trust detections
        self.kf.measurementNoiseCov = np.eye(2, dtype=np.float32) * 10.0
        self.kf.errorCovPost = np.eye(4, dtype=np.float32) * 1000.0
        self.kf.statePost = np.array([[BASE_OUTPUT_W/2],
                                      [BASE_OUTPUT_H/2],
                                      [0],
                                      [0]], np.float32)
        self.missed_frames = 0
    def predict(self):
        p = self.kf.predict()
        return p[0][0], p[1][0]
    def update(self, detection_xy):
        meas = np.array([[np.float32(detection_xy[0])],
                         [np.float32(detection_xy[1])]])
        self.kf.correct(meas)
        self.missed_frames = 0

# -----------------------------
# 5) Main execution
# -----------------------------
print("🎥 WORKING SCRIPT starting...")
fourcc = cv2.VideoWriter_fourcc(*'mp4v')
out = cv2.VideoWriter(output_path, fourcc, FPS, (BASE_OUTPUT_W, BASE_OUTPUT_H))

orig_w, orig_h = W, H
EXCLUSION_X = int(orig_w * FIELD_MAX_X_RATIO)

backSub = cv2.createBackgroundSubtractorMOG2(history=500, varThreshold=50, detectShadows=True)
cam_x, cam_y = orig_w / 2.0, orig_h / 2.0
tracker = BallTracker()
tracker_initialized = False
current_zoom_factor = ZOOM_FACTOR_MAX

frame_idx = 0
tracker_ok_count = 0
while True:
    ret, frame = cap.read()
    if not ret:
        break
    frame_idx += 1

    # 1) Predict
    pred_x, pred_y = cam_x, cam_y
    if tracker_initialized:
        px, py = tracker.predict()
        pred_x, pred_y = float(px), float(py)

    # 2) YOLO (tiling) with rescue threshold
    yolo_dets = detect_with_tiling(model, frame, CONF_WEAK)
    # Fallback: full-frame pass if tiles found nothing
    if yolo_dets.size == 0:
        res_full = model.predict(frame, conf=CONF_WEAK, classes=[32], verbose=False)
        boxes_full = res_full[0].boxes
        if boxes_full is not None and len(boxes_full) > 0:
            yolo_dets = boxes_full.data.cpu().numpy()
    best_ball = None
    if yolo_dets.size > 0:
        # Apply exclusion only if enabled (< 1.0)
        if FIELD_MAX_X_RATIO < 0.999:
            centers_x = (yolo_dets[:, 0] + yolo_dets[:, 2]) / 2.0
            yolo_dets = yolo_dets[centers_x < EXCLUSION_X]
        if yolo_dets.size > 0:
            strong = yolo_dets[yolo_dets[:, 4] >= CONF_STRONG]
            weak = yolo_dets[yolo_dets[:, 4] < CONF_STRONG]
            # A) choose strong closest to prediction
            if strong.size > 0:
                centers = np.stack([(strong[:,0]+strong[:,2])/2.0, (strong[:,1]+strong[:,3])/2.0], axis=1)
                if tracker_initialized:
                    dists = np.linalg.norm(centers - np.array([pred_x, pred_y]), axis=1)
                    best_idx = int(np.argmin(dists))
                    if dists[best_idx] < 1000:
                        best_ball = centers[best_idx]
                else:
                    best_det = strong[int(np.argmax(strong[:,4]))]
                    best_ball = [(best_det[0]+best_det[2])/2.0, (best_det[1]+best_det[3])/2.0]
            # B) fallback to weak near prediction
            if best_ball is None and tracker_initialized and weak.size > 0:
                centers = np.stack([(weak[:,0]+weak[:,2])/2.0, (weak[:,1]+weak[:,3])/2.0], axis=1)
                dists = np.linalg.norm(centers - np.array([pred_x, pred_y]), axis=1)
                best_idx = int(np.argmin(dists))
                if dists[best_idx] < 300:
                    best_ball = centers[best_idx]

    # 3) Motion rescue if still lost
    if best_ball is None and tracker_initialized:
        motion_center = get_motion_cue_MOG2(frame, backSub, (pred_x, pred_y))
        if motion_center is not None:
            motion_dist = np.linalg.norm(np.array(motion_center) - np.array([pred_x, pred_y]))
            if motion_dist < 200:
                best_ball = motion_center

    # 4) Update tracker / zoom logic
    target_x, target_y = cam_x, cam_y
    target_zoom_factor = ZOOM_FACTOR_MAX
    if best_ball is not None:
        tracker.update(best_ball)
        tracker_initialized = True
        target_x, target_y = best_ball
        tracker_ok_count += 1
    elif tracker_initialized and tracker.missed_frames < MAX_MISSED_FRAMES:
        tracker.missed_frames += 1
        target_x, target_y = pred_x, pred_y
        target_zoom_factor = ZOOM_FACTOR_LOST
        tracker_ok_count += 1
    else:
        tracker_initialized = False
        target_x = cam_x + (orig_w/2.0 - cam_x) * 0.01
        target_y = cam_y + (orig_h/2.0 - cam_y) * 0.01
        target_zoom_factor = ZOOM_FACTOR_LOST

    # 5) Move camera + zoom
    cam_x += (target_x - cam_x) * CAMERA_SMOOTHING
    cam_y += (target_y - cam_y) * CAMERA_SMOOTHING
    current_zoom_factor += (target_zoom_factor - current_zoom_factor) * ZOOM_SMOOTHING

    # 6) Crop and write
    # Crop relative to input frame size so zoom is visible even if output size == input
    current_crop_w = int(W * current_zoom_factor)
    current_crop_h = int(H * current_zoom_factor)
    tl_x = int(cam_x - current_crop_w / 2.0)
    tl_y = int(cam_y - current_crop_h / 2.0)
    tl_x = max(0, min(tl_x, orig_w - current_crop_w))
    tl_y = max(0, min(tl_y, orig_h - current_crop_h))
    view = frame[tl_y:tl_y+current_crop_h, tl_x:tl_x+current_crop_w]
    if view.shape[0] != BASE_OUTPUT_H or view.shape[1] != BASE_OUTPUT_W:
        view = cv2.resize(view, (BASE_OUTPUT_W, BASE_OUTPUT_H), interpolation=cv2.INTER_LINEAR)
    out.write(view)

    if frame_idx % 30 == 0:
        pct = int(frame_idx / max(1, TOTAL) * 100)
        update_job("processing", progress=pct)

cap.release()
out.release()

# Metrics for backend
accuracy = int(tracker_ok_count / max(1, TOTAL) * 100)
print("✅ WORKING SCRIPT finished.")
''';
// Alias: use CHATGPT pipeline for FINEDININGSCRIPT button
const String kFineDiningBallTrackingScript = kChatgptBallTrackingScript;

const String kDebugBallTrackingScript = r'''
# ==================================================================================
# 🐞 DEBUG MICROSCOPIC REOLINK v7.2 (VISUALIZATION)
# ==================================================================================
# DESIGNED FOR: 4608x1728 Panoramic Videos where ball is TINY (<5 pixels)
# FIXES vs v7.1: DISABLED all size/shape filters, Higher Res (1280px)
# ==================================================================================

# --- CONFIGURATION ---
try: YOLO_MODEL
except NameError: YOLO_MODEL = "yolov8l"

try: YOLO_IMG_SIZE
except NameError: YOLO_IMG_SIZE = 1280  # Increased resolution

try: YOLO_CONF
except NameError: YOLO_CONF = 0.10

try: DETECT_EVERY
except NameError: DETECT_EVERY = 2

# --- CONSTANTS ---
OUTPUT_WIDTH = W
OUTPUT_HEIGHT = H

ZOOM_BASE = 2.5
ZOOM_IDLE = 1.5
SMOOTH_FACTOR = 1.0
DEADZONE_X = 0.0
DEADZONE_Y = 0.0

MAX_SPEED_PIXELS = 600
# FILTERS REMOVED

tracker_ok_count = 0
accuracy = 0

# ==================================================================================
# HELPER: LETTERBOX RESIZE
# ==================================================================================
def letterbox(im, new_shape=(1280, 1280), color=(114, 114, 114)):
    shape = im.shape[:2]
    if isinstance(new_shape, int): new_shape = (new_shape, new_shape)
    r = min(new_shape[0] / shape[0], new_shape[1] / shape[1])
    new_unpad = int(round(shape[1] * r)), int(round(shape[0] * r))
    dw, dh = new_shape[1] - new_unpad[0], new_shape[0] - new_unpad[1]
    dw /= 2; dh /= 2
    if shape[::-1] != new_unpad:
        im = cv2.resize(im, new_unpad, interpolation=cv2.INTER_LINEAR)
    top, bottom = int(round(dh - 0.1)), int(round(dh + 0.1))
    left, right = int(round(dw - 0.1)), int(round(dw + 0.1))
    im = cv2.copyMakeBorder(im, top, bottom, left, right, cv2.BORDER_CONSTANT, value=color)
    return im, r, (dw, dh)

# ==================================================================================
# CLASSES
# ==================================================================================

class AdvancedKalmanFilter:
    def __init__(self, x, y):
        self.kf = cv2.KalmanFilter(4, 2)
        self.kf.measurementMatrix = np.array([[1,0,0,0], [0,1,0,0]], np.float32)
        self.kf.transitionMatrix = np.array([[1,0,1,0], [0,1,0,1], [0,0,1,0], [0,0,0,1]], np.float32)
        self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * 0.05
        self.kf.processNoiseCov[2:, 2:] *= 20.0
        self.kf.measurementNoiseCov = np.eye(2, dtype=np.float32) * 0.05
        self.kf.statePost = np.array([[x], [y], [0], [0]], np.float32)
        self.kf.errorCovPost = np.eye(4, dtype=np.float32) * 1.0

    def predict(self):
        p = self.kf.predict()
        px = float(p[0]) if p.ndim == 1 else float(p[0, 0])
        py = float(p[1]) if p.ndim == 1 else float(p[1, 0])
        return (px, py)

    def update(self, x, y):
        self.kf.correct(np.array([[x], [y]], np.float32))
        px = float(self.kf.statePost[0]) if self.kf.statePost.ndim == 1 else float(self.kf.statePost[0, 0])
        py = float(self.kf.statePost[1]) if self.kf.statePost.ndim == 1 else float(self.kf.statePost[1, 0])
        return (px, py)

class InstantCamera:
    def __init__(self, w, h, out_w, out_h):
        self.W, self.H = w, h
        self.out_w, self.out_h = out_w, out_h
        self.cam_x = w / 2
        self.cam_y = h / 2
        self.current_zoom = ZOOM_IDLE
        
    def update(self, target_x, target_y, is_tracking):
        target_zoom = ZOOM_BASE if is_tracking else ZOOM_IDLE
        self.current_zoom += (target_zoom - self.current_zoom) * 0.2
        
        if target_x is not None:
            self.cam_x = target_x
            self.cam_y = target_y
        
        half_w = (self.W / self.current_zoom) / 2
        half_h = (self.H / self.current_zoom) / 2
        self.cam_x = np.clip(self.cam_x, half_w, self.W - half_w)
        self.cam_y = np.clip(self.cam_y, half_h, self.H - half_h)
        
        return int(self.cam_x), int(self.cam_y), self.current_zoom

# ==================================================================================
# INITIALIZATION
# ==================================================================================
print("🐞 DEBUG MICROSCOPIC REOLINK v7.2")

fourcc = cv2.VideoWriter_fourcc(*'mp4v')
out = cv2.VideoWriter(output_path, fourcc, FPS, (OUTPUT_WIDTH, OUTPUT_HEIGHT))

tracker = None
cam = InstantCamera(W, H, OUTPUT_WIDTH, OUTPUT_HEIGHT)
ball_history = []
lost_frames = 0
max_lost_frames = int(FPS * 3.0)

# ==================================================================================
# PROCESSING LOOP
# ==================================================================================
frame_idx = 0
start_time = time.time()

while True:
    ret, frame = cap.read()
    if not ret: break
    frame_idx += 1
    
    predicted_pos = None
    if tracker:
        predicted_pos = tracker.predict()
    
    detections = []
    
    if frame_idx % DETECT_EVERY == 0 or tracker is None:
        img_letterbox, ratio, (dw, dh) = letterbox(frame, new_shape=YOLO_IMG_SIZE, color=(114, 114, 114))
        results = model(img_letterbox, conf=YOLO_CONF, verbose=False, classes=[32])
        
        if len(results[0].boxes) == 0:
             results = model(img_letterbox, conf=0.01, verbose=False, classes=[32])
        
        if len(results[0].boxes) > 0:
            boxes = results[0].boxes.xyxy.cpu().numpy()
            confs = results[0].boxes.conf.cpu().numpy()
            
            boxes[:, [0, 2]] -= dw
            boxes[:, [1, 3]] -= dh
            boxes[:, :4] /= ratio
            
            for i, box in enumerate(boxes):
                bx1, by1, bx2, by2 = box
                conf = float(confs[i])
                w_b, h_b = bx2 - bx1, by2 - by1
                area = w_b * h_b
                
                # Accept anything YOLO considers a ball (microscopic mode)
                
                cx, cy = (bx1 + bx2)/2, (by1 + by2)/2
                detections.append({'pos': (cx, cy), 'score': conf})

    best_det = None
    if detections:
        detections.sort(key=lambda x: x['score'], reverse=True)
        if predicted_pos:
            best_dist = float('inf')
            for det in detections:
                dist = np.sqrt((det['pos'][0] - predicted_pos[0])**2 + (det['pos'][1] - predicted_pos[1])**2)
                if dist < best_dist and dist < MAX_SPEED_PIXELS:
                    best_dist = dist
                    best_det = det
        if best_det is None:
            best_det = detections[0]
    
    current_ball_pos = None
    if best_det:
        cx, cy = best_det['pos']
        if tracker is None:
            tracker = AdvancedKalmanFilter(cx, cy)
        else:
            tracker.update(cx, cy)
        current_ball_pos = (cx, cy)
        lost_frames = 0
        tracker_ok_count += 1
    elif tracker:
        if lost_frames < max_lost_frames:
            current_ball_pos = predicted_pos
            tracker_ok_count += 1
            lost_frames += 1
        else:
            tracker = None
            lost_frames = 0
    
    target_x, target_y = None, None
    is_tracking = False
    
    if current_ball_pos:
        target_x, target_y = current_ball_pos
        is_tracking = True
        ball_history.append(current_ball_pos)
        if len(ball_history) > 90: ball_history.pop(0)
    elif len(ball_history) > 0:
        target_x, target_y = ball_history[-1]
    
    cx, cy, zoom = cam.update(target_x, target_y, is_tracking)
    
    # 🐞 VISUALIZATION
    if current_ball_pos:
        cv2.circle(frame, (int(current_ball_pos[0]), int(current_ball_pos[1])), 30, (0, 255, 0), 6)
        cv2.putText(frame, "BALL", (int(current_ball_pos[0])-40, int(current_ball_pos[1])-40), 
                    cv2.FONT_HERSHEY_SIMPLEX, 2.0, (0, 255, 0), 4)
    elif predicted_pos and tracker:
        cv2.circle(frame, (int(predicted_pos[0]), int(predicted_pos[1])), 30, (0, 255, 255), 6)
        cv2.putText(frame, "PRED", (int(predicted_pos[0])-40, int(predicted_pos[1])-40), 
                    cv2.FONT_HERSHEY_SIMPLEX, 2.0, (0, 255, 255), 4)
    
    # --- RENDER ---
    view_w = int(W / zoom)
    view_h = int(H / zoom)
    x1 = max(0, min(int(cx - view_w/2), W - view_w))
    y1 = max(0, min(int(cy - view_h/2), H - view_h))
    x2 = x1 + view_w
    y2 = y1 + view_h
    
    crop = frame[y1:y2, x1:x2]
    
    if crop.size > 0:
        final_frame = cv2.resize(crop, (OUTPUT_WIDTH, OUTPUT_HEIGHT), interpolation=cv2.INTER_LINEAR)
        out.write(final_frame)
    else:
        out.write(cv2.resize(frame, (OUTPUT_WIDTH, OUTPUT_HEIGHT)))
    
    if frame_idx % 30 == 0:
        pct = int(frame_idx/TOTAL * 100)
        update_job("processing", progress=pct)

cap.release()
out.release()

accuracy = int((tracker_ok_count / max(1, TOTAL)) * 100)
print(f"✅ DONE. Accuracy: {accuracy}%")

print("🔄 Optimizing video...")
tmp_out = output_path + ".tmp.mp4"
os.rename(output_path, tmp_out)
subprocess.run([
    "ffmpeg", "-y", "-i", tmp_out, 
    "-c:v", "libx264", "-crf", "23", "-preset", "fast", 
    "-movflags", "+faststart",
    output_path
], check=False)
if os.path.exists(tmp_out): os.remove(tmp_out)
''';

const String kChatgptBallTrackingScript = r'''
# ==================================================================================
# 🟢 CHATGPT TV-ZOOM BALL TRACKING (Single-pass, Modal-compatible)
# ==================================================================================
# Based on user's offline design:
# - Color/Contour + Hough fallback detector (white-ish ball focus)
# - Optional short occlusion bridging via Lucas-Kanade optical flow
# - 6-state Kalman (position/velocity/acceleration) for smoothing
# - Digital crop (PTZ-like) around smoothed ball, resized to OUTPUT_WIDTH/HEIGHT
# Notes:
# - Adapted to Modal exec() environment: uses provided cap, W, H, FPS, TOTAL, output_path
# - Single-pass (no RTS backward smoother; uses exponential smoothing + Kalman)
# - No CLI, no re-opening input by path
# ==================================================================================

# -------------------------
# CONFIG / TUNING
# -------------------------
TUNING = {
    "fps": FPS,                      # use host FPS
    "min_ball_radius": 4,            # pixels (smallest to consider)
    "max_ball_radius": 140,          # pixels (largest)
    "blur_ksize": 7,
    "hsv_lower": np.array([0, 0, 120]),    # white-ish in HSV
    "hsv_upper": np.array([180, 70, 255]),
    "morph_kernel": 5,
    "min_contour_area": 18,
    "lk_win_size": (21, 21),
    "lk_max_level": 3,
    "lk_criteria": (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 30, 0.01),
    "max_flow_age": 6,                # frames to keep using flow without new detection
    "max_miss_frames_for_reset": 40,  # drop history if missed long
}

# Ensure 'math' is available in the exec environment
try:
    math
except NameError:
    import math

# Dimensions from host (ensure available before use)
try:
    OUTPUT_WIDTH
except NameError:
    OUTPUT_WIDTH = W
try:
    OUTPUT_HEIGHT
except NameError:
    OUTPUT_HEIGHT = H

# Quick mode toggles (speed up processing)
try:
    QUICK_MODE
except NameError:
    QUICK_MODE = True  # set False for high-quality full runs
try:
    FRAME_STRIDE
except NameError:
    FRAME_STRIDE = 2 if QUICK_MODE else 1  # process every Nth frame
try:
    PREVIEW_SECONDS
except NameError:
    PREVIEW_SECONDS = 0  # 0 disables early stop
try:
    SKIP_REENCODE
except NameError:
    SKIP_REENCODE = QUICK_MODE  # skip final ffmpeg in quick mode

# Output crop / zoom tuning
CROP = {
    "aspect": OUTPUT_WIDTH / float(max(1, OUTPUT_HEIGHT)),
    "zoom_padding": 1.8,
    "min_zoom": 1.0,
    "max_zoom": 6.0,
    "smooth_center_alpha": 0.18,
    "smooth_zoom_alpha": 0.12,
}

# Kalman noise tuning
KF_CFG = {
    "proc_noise_pos": 1e-3,
    "proc_noise_vel": 1e-2,
    "proc_noise_acc": 5e-3,
    "meas_noise": 5e-1,
    "P0_scale": 1.0
}

# Metrics for Modal
tracker_ok_count = 0
accuracy = 0

# -------------------------
# Utilities
# -------------------------
def _build_state_matrices(dt):
    # 6-state constant-accel
    F = np.eye(6, dtype=np.float32)
    F[0,2] = dt; F[1,3] = dt
    F[0,4] = 0.5 * dt * dt; F[1,5] = 0.5 * dt * dt
    F[2,4] = dt; F[3,5] = dt
    Hm = np.zeros((2,6), dtype=np.float32)
    Hm[0,0] = 1.0; Hm[1,1] = 1.0
    return F, Hm

def _build_process_noise(dt):
    q = np.zeros((6,6), dtype=np.float32)
    q[0,0] = KF_CFG["proc_noise_pos"]; q[1,1] = KF_CFG["proc_noise_pos"]
    q[2,2] = KF_CFG["proc_noise_vel"]; q[3,3] = KF_CFG["proc_noise_vel"]
    q[4,4] = KF_CFG["proc_noise_acc"]; q[5,5] = KF_CFG["proc_noise_acc"]
    return q

def _letterbox(im, new_shape, color=(114,114,114)):
    shape = im.shape[:2]  # h,w
    if isinstance(new_shape, int):
        new_shape = (new_shape, new_shape)
    r = min(new_shape[0]/shape[0], new_shape[1]/shape[1])
    new_unpad = (int(round(shape[1]*r)), int(round(shape[0]*r)))
    dw, dh = new_shape[1]-new_unpad[0], new_shape[0]-new_unpad[1]
    dw /= 2.0; dh /= 2.0
    if shape[::-1] != new_unpad:
        im = cv2.resize(im, new_unpad, interpolation=cv2.INTER_LINEAR)
    top, bottom = int(round(dh-0.1)), int(round(dh+0.1))
    left, right = int(round(dw-0.1)), int(round(dw+0.1))
    im = cv2.copyMakeBorder(im, top, bottom, left, right, cv2.BORDER_CONSTANT, value=color)
    return im, r, (dw, dh)

def _detect_ball(frame_bgr):
    # Color-based mask (white-ish)
    blur = cv2.GaussianBlur(frame_bgr, (TUNING["blur_ksize"],)*2, 0)
    hsv = cv2.cvtColor(blur, cv2.COLOR_BGR2HSV)
    mask = cv2.inRange(hsv, TUNING["hsv_lower"], TUNING["hsv_upper"])
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (TUNING["morph_kernel"],)*2)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=1)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=1)
    cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    best = None; best_score = 0.0
    for c in cnts:
        area = cv2.contourArea(c)
        if area < TUNING["min_contour_area"]:
            continue
        (x,y), r = cv2.minEnclosingCircle(c)
        if r < TUNING["min_ball_radius"] or r > TUNING["max_ball_radius"]:
            continue
        circle_area = max(1e-6, math.pi * (r**2))
        conf = min(1.0, area / circle_area)
        score = conf * r
        if score > best_score:
            best_score = score
            best = (int(x), int(y), int(r), float(conf))
    if best is not None:
        return best
    # Hough fallback on brightness
    gray = cv2.cvtColor(blur, cv2.COLOR_BGR2GRAY)
    _, th = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY)
    th = cv2.medianBlur(th, 5)
    circles = cv2.HoughCircles(th, cv2.HOUGH_GRADIENT, dp=1.2, minDist=20,
                               param1=100, param2=18,
                               minRadius=TUNING["min_ball_radius"],
                               maxRadius=TUNING["max_ball_radius"])
    if circles is not None:
        circles = np.round(circles[0]).astype(int)
        best_b = None; bb = -1
        for (x,y,r) in circles:
            x0, x1 = max(0,x-r), min(gray.shape[1], x+r)
            y0, y1 = max(0,y-r), min(gray.shape[0], y+r)
            roi = gray[y0:y1, x0:x1]
            if roi.size==0: 
                continue
            brightness = roi.mean()
            if brightness > bb:
                bb = brightness
                best_b = (x,y,r, min(1.0, (brightness-120)/130.0))
        if best_b is not None:
            return best_b
    return None

def _estimate_with_optical_flow(prev_gray, cur_gray, prev_pt):
    # Lucas-Kanade to track single point
    p0 = np.array([[prev_pt]], dtype=np.float32)  # (1,1,2)
    p1, st, err = cv2.calcOpticalFlowPyrLK(prev_gray, cur_gray, p0, None,
                                           winSize=TUNING["lk_win_size"],
                                           maxLevel=TUNING["lk_max_level"],
                                           criteria=TUNING["lk_criteria"])
    if p1 is None:
        return prev_pt[0], prev_pt[1], False
    x, y = float(p1[0,0,0]), float(p1[0,0,1])
    status = bool(st[0,0] == 1)
    return x, y, status

class Kalman6:
    def __init__(self, dt):
        self.dt = float(dt)
        self.F, self.H = _build_state_matrices(self.dt)
        self.Q = _build_process_noise(self.dt)
        self.R = np.eye(2, dtype=np.float32) * KF_CFG["meas_noise"]
        self.P = np.eye(6, dtype=np.float32) * KF_CFG["P0_scale"]
        self.x = np.zeros((6,1), dtype=np.float32)
        self.initialized = False
    def init_state(self, x, y):
        self.x[:] = 0
        self.x[0,0] = x; self.x[1,0] = y
        self.initialized = True
    def predict(self):
        self.x = self.F.dot(self.x)
        self.P = self.F.dot(self.P).dot(self.F.T) + self.Q
        return self.x.copy(), self.P.copy()
    def update(self, meas_x, meas_y):
        z = np.array([[meas_x],[meas_y]], dtype=np.float32)
        S = self.H.dot(self.P).dot(self.H.T) + self.R
        K = self.P.dot(self.H.T).dot(np.linalg.inv(S))
        yv = z - self.H.dot(self.x)
        self.x = self.x + K.dot(yv)
        I = np.eye(6, dtype=np.float32)
        self.P = (I - K.dot(self.H)).dot(self.P)
        return self.x.copy(), self.P.copy()

def _compute_crop_from_center(cx, cy, r, frame_w, frame_h, aspect, zoom_padding):
    half = max(r * zoom_padding, 20)
    x0 = int(cx - half); y0 = int(cy - half)
    x1 = int(cx + half); y1 = int(cy + half)
    w = x1 - x0; h = y1 - y0
    current_aspect = w / float(max(1, h))
    if current_aspect > aspect:
        new_h = int(w / aspect)
        dh = new_h - h
        y0 -= dh//2; y1 += dh - dh//2
    else:
        new_w = int(h * aspect)
        dw = new_w - w
        x0 -= dw//2; x1 += dw - dw//2
    # clamp
    x0 = max(0, x0); y0 = max(0, y0)
    x1 = min(frame_w, x1); y1 = min(frame_h, y1)
    crop_w = max(1, x1-x0); crop_h = max(1, y1-y0)
    zoom = max(1.0, math.sqrt((frame_w*frame_h) / float(max(1, crop_w*crop_h))))
    return x0, y0, x1, y1, zoom

# ==================================================================================
# MAIN (Single-pass generation)
# ==================================================================================
print("📺 CHATGPT TV-ZOOM | Single-pass Kalman + optical-flow + color/Hough detect")
print(f"Input: {W}x{H} @ {FPS}fps | Output: {OUTPUT_WIDTH}x{OUTPUT_HEIGHT}")

fourcc = cv2.VideoWriter_fourcc(*'mp4v')
out = cv2.VideoWriter(output_path, fourcc, FPS, (OUTPUT_WIDTH, OUTPUT_HEIGHT))

frame_w, frame_h = W, H
fps = TUNING["fps"] or FPS
dt = 1.0 / max(1e-6, fps)

kf = Kalman6(dt)
prev_gray = None
last_detect_pos = None
last_detect_r = 20.0
flow_age = 0
miss_count = 0

# smoother state
scx, scy = frame_w/2.0, frame_h/2.0
sz = 1.0

frame_idx = 0
while True:
    ret, frame = cap.read()
    if not ret:
        break
    frame_idx += 1

    # Fast path: skip frames for speed
    if FRAME_STRIDE > 1 and (frame_idx % FRAME_STRIDE):
        if PREVIEW_SECONDS and frame_idx >= PREVIEW_SECONDS * FPS:
            break
        continue

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    # Detect
    det = _detect_ball(frame)
    measurement = None
    det_r = None
    if det is not None:
        mx, my, mr, conf = det
        measurement = (float(mx), float(my))
        det_r = float(mr)
        last_detect_pos = measurement
        last_detect_r = det_r
        flow_age = 0; miss_count = 0
    else:
        if last_detect_pos is not None and prev_gray is not None and flow_age < TUNING["max_flow_age"]:
            x_est, y_est, ok = _estimate_with_optical_flow(prev_gray, gray, last_detect_pos)
            if ok:
                measurement = (float(x_est), float(y_est))
                det_r = last_detect_r * 0.98
                last_detect_pos = measurement
                flow_age += 1
            else:
                flow_age += 1; miss_count += 1
        else:
            miss_count += 1

    # Kalman predict/update
    if not kf.initialized:
        if measurement is not None:
            kf.init_state(measurement[0], measurement[1])
        else:
            prev_gray = gray
            # Cannot update without initialization; write full frame
            out.write(cv2.resize(frame, (OUTPUT_WIDTH, OUTPUT_HEIGHT), interpolation=cv2.INTER_LINEAR))
            continue

    x_pred, P_pred = kf.predict()
    cx_k, cy_k = float(x_pred[0,0]), float(x_pred[1,0])
    if measurement is not None:
        x_upd, P_upd = kf.update(measurement[0], measurement[1])
        cx_k, cy_k = float(x_upd[0,0]), float(x_upd[1,0])
        tracker_ok_count += 1
    else:
        tracker_ok_count += 1  # predicting

    # Use last radius or fallback
    r_use = last_detect_r if last_detect_r is not None else 25.0

    # Desired crop from Kalman center
    x0, y0, x1, y1, desired_zoom = _compute_crop_from_center(
        cx_k, cy_k, r_use, frame_w, frame_h,
        aspect=CROP["aspect"], zoom_padding=CROP["zoom_padding"]
    )
    desired_zoom = float(np.clip(desired_zoom, CROP["min_zoom"], CROP["max_zoom"]))

    # Smooth center and zoom
    scx = scx * (1.0 - CROP["smooth_center_alpha"]) + cx_k * CROP["smooth_center_alpha"]
    scy = scy * (1.0 - CROP["smooth_center_alpha"]) + cy_k * CROP["smooth_center_alpha"]
    sz = sz * (1.0 - CROP["smooth_zoom_alpha"]) + desired_zoom * CROP["smooth_zoom_alpha"]

    # Build crop around smoothed center
    half_w = int((frame_w / sz) / 2)
    half_h = int((frame_h / sz) / 2)
    scx_i = int(max(half_w, min(frame_w - half_w, scx)))
    scy_i = int(max(half_h, min(frame_h - half_h, scy)))
    fx0 = scx_i - half_w; fy0 = scy_i - half_h
    fx1 = scx_i + half_w; fy1 = scy_i + half_h
    crop = frame[fy0:fy1, fx0:fx1]
    if crop.size == 0:
        out_frame = cv2.resize(frame, (OUTPUT_WIDTH, OUTPUT_HEIGHT), interpolation=cv2.INTER_LINEAR)
    else:
        out_frame = cv2.resize(crop, (OUTPUT_WIDTH, OUTPUT_HEIGHT), interpolation=cv2.INTER_LINEAR)

    # Optional tiny overlay
    cv2.putText(out_frame, f"f:{frame_idx} z:{sz:.2f}", (12, 24), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255,255,255), 2)
    rx = int((cx_k - fx0) / max(1, (fx1 - fx0)) * OUTPUT_WIDTH)
    ry = int((cy_k - fy0) / max(1, (fy1 - fy0)) * OUTPUT_HEIGHT)
    if 0 <= rx < OUTPUT_WIDTH and 0 <= ry < OUTPUT_HEIGHT:
        cv2.circle(out_frame, (rx, ry), 6, (0,255,255), -1)

    out.write(out_frame)

    prev_gray = gray

    if frame_idx % 30 == 0:
        pct = int(frame_idx / max(1, TOTAL) * 100)
        update_job("processing", progress=pct)
    if PREVIEW_SECONDS and frame_idx >= PREVIEW_SECONDS * FPS:
        break

cap.release()
out.release()

accuracy = int((tracker_ok_count / max(1, TOTAL)) * 100)
print(f"✅ DONE. Accuracy (frames processed/tracked): {accuracy}%")

if not SKIP_REENCODE:
    print("🔄 Optimizing video for web...")
    tmp_out = output_path + ".tmp.mp4"
    os.rename(output_path, tmp_out)
    subprocess.run([
        "ffmpeg", "-y", "-i", tmp_out,
        "-c:v", "libx264", "-crf", "23", "-preset", "fast",
        "-movflags", "+faststart",
        output_path
    ], check=False)
    if os.path.exists(tmp_out): os.remove(tmp_out)
''';
