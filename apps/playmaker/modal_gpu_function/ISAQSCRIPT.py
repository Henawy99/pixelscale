# ==============================================================================
# BROADCAST BALL TRACKING v4 — Efficient, single-Kalman pipeline
# ISAQ SCRIPT - Custom override for 2:28
# ==============================================================================
# Key improvements over v3+:
#   - FULL_FRAME_INTERVAL: 5 → 2 (detect on full frame every 2nd frame,
#     not every 5th, greatly reducing missed long-pass detections)
#   - Single Kalman filter (removed the redundant OpenCV KCF/MOSSE tracker;
#     the BallKalmanFilter + YOLO already handle tracking accurately, the
#     extra tracker was causing double-prediction and position drift)
#   - Cleaner ball velocity estimation (directly from Kalman residuals)
#   - Slightly tighter anti-teleport guard now that detection is more frequent
# ==============================================================================

CROP_RATIO = 0.45
DETECTION_SIZE = 1280           # High-res full-frame detection
REFINE_PATCH_SIZE = 128         # Second-pass crop for precise center
REFINE_IMGSZ = 256              # YOLO size on refinement patch
MEDIAN_FILTER_LEN = 3           # Median of last N detections = reject outlier jumps

DETECTION_CONF_TRACKING = 0.08  # Very low when tracking - never miss
DETECTION_CONF_SEARCH = 0.10    # Low when searching - fast re-acquire

ROI_SIZE = 550                  # ROI when tracking
ROI_EXPAND_LOST = 950           # Bigger search area when ball lost
FULL_FRAME_INTERVAL = 1         # ↑ DETECT ON FULL FRAME EVERY FRAME (was 1)
MAX_TELEPORT_PX = 120           # Slightly tighter: more frequent detection = less need for loose guard
KALMAN_MEMORY = 100             # Keep predicting ~4 sec at 25fps
TRAIL_LENGTH = 5

# v4 broadcast tuning
SMOOTH_ALPHA = 0.65             # EMA position smoothing (0.6-0.8)
CONFIDENCE_MEMORY_DECAY = 5     # Frames to keep trail after last detection
DISTANCE_PENALTY = 0.002        # Prefer detections closer to Kalman prediction
GLOW_RADIUS = 25
GLOW_ALPHA = 0.2
LEAD_FACTOR = 1.5               # Camera leads in movement direction
LEAD_CLIP = 0.2
ACCEL_SMOOTH = 0.9
TELEPORT_VELOCITY_FACTOR = 3    # Allow larger jumps when ball is fast

CAM_PAN_MIN_NORM = 0.29
CAM_PAN_MAX_NORM = 0.69
SHOW_PAN_INDICATOR = False

SHOW_FIELD_MASK = False
SHOW_BALL_RED = False
FIELD_MASK_OPACITY = 0.15

# ==============================================================================
# FIELD MASK — injected by pipeline at runtime
# ==============================================================================
try:
    _inj = _injected_field_mask
except NameError:
    _inj = None

if _inj is not None and len(_inj) > 0:
    FIELD_MASK_POINTS = np.array(_inj, dtype=np.float32)
    if 'log' in dir():
        log(f"✅ Using injected field mask ({len(FIELD_MASK_POINTS)} points)")
else:
    FIELD_MASK_POINTS = None
    if 'log' in dir():
        log("⚠️  No field mask injected — detecting in full frame")

if FIELD_MASK_POINTS is not None:
    field_mask = np.zeros((H, W), dtype=np.uint8)
    _pts = FIELD_MASK_POINTS.copy()
    _pts[:, 0] *= W
    _pts[:, 1] *= H
    cv2.fillPoly(field_mask, [_pts.astype(np.int32)], 255)

    def is_in_field(x, y):
        ix, iy = max(0, min(int(x), W - 1)), max(0, min(int(y), H - 1))
        return field_mask[iy, ix] > 0
else:
    def is_in_field(x, y):
        return 0 <= x < W and 0 <= y < H

def draw_field_mask_on_full_frame(full_img):
    if not SHOW_FIELD_MASK or FIELD_MASK_POINTS is None:
        return
    points = FIELD_MASK_POINTS.copy()
    points[:, 0] *= W
    points[:, 1] *= H
    polygon = points.astype(np.int32)
    overlay = full_img.copy()
    cv2.fillPoly(overlay, [polygon], (0, 255, 0))
    cv2.addWeighted(overlay, FIELD_MASK_OPACITY, full_img, 1 - FIELD_MASK_OPACITY, 0, full_img)
    cv2.polylines(full_img, [polygon], True, (0, 255, 100), 2, cv2.LINE_AA)

def draw_pan_indicator(cropped_img, camera):
    if not SHOW_PAN_INDICATOR:
        return
    pan = camera.pan_position_norm()
    h, w = cropped_img.shape[:2]
    text = f"Pan: {pan:.2f}  [{camera.pan_min_norm:.2f} - {camera.pan_max_norm:.2f}]"
    (tw, th), _ = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, 0.55, 1)
    x, y = w - tw - 12, 28
    cv2.rectangle(cropped_img, (x - 4, y - th - 4), (x + tw + 4, y + 4), (0, 0, 0), -1)
    cv2.putText(cropped_img, text, (x, y), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 255), 1, cv2.LINE_AA)

# ==============================================================================
# KALMAN FILTER — single source of truth for ball position
# Removed the redundant OpenCV KCF/MOSSE tracker. With FULL_FRAME_INTERVAL=2
# YOLO runs frequently enough that Kalman prediction alone handles the gaps.
# ==============================================================================
class BallKalmanFilter:
    """4-state Kalman (x, y, vx, vy) for smooth, memory-efficient ball tracking."""
    def __init__(self):
        self.kf = cv2.KalmanFilter(4, 2)
        self.kf.transitionMatrix = np.array(
            [[1, 0, 1, 0],
             [0, 1, 0, 1],
             [0, 0, 1, 0],
             [0, 0, 0, 1]], dtype=np.float32)
        self.kf.measurementMatrix = np.array(
            [[1, 0, 0, 0],
             [0, 1, 0, 0]], dtype=np.float32)
        self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * 0.03
        self.kf.measurementNoiseCov = np.eye(2, dtype=np.float32) * 0.3
        self.initialized = False
        self.frames_since = 0

    def init(self, x, y):
        self.kf.statePost = np.array([[x], [y], [0], [0]], dtype=np.float32)
        self.initialized = True
        self.frames_since = 0

    def predict(self):
        if not self.initialized:
            return None
        p = self.kf.predict()
        return p[0, 0], p[1, 0]

    def update(self, x, y):
        if not self.initialized:
            self.init(x, y)
        else:
            self.kf.correct(np.array([[x], [y]], dtype=np.float32))
        self.frames_since = 0

    def velocity(self):
        """Return current velocity estimate from Kalman state."""
        if not self.initialized:
            return 0.0, 0.0
        state = self.kf.statePost
        return float(state[2, 0]), float(state[3, 0])

    def is_valid(self):
        return self.initialized and self.frames_since < KALMAN_MEMORY

    def no_detection(self):
        self.frames_since += 1

# ==============================================================================
# SMOOTH BROADCAST CAMERA (v4 — velocity from Kalman state, no redundant tracker)
# ==============================================================================
CAM_DISPLAY_SMOOTH = 0.88

class SmoothBroadcastCamera:
    def __init__(self, fw, fh, crop_ratio=0.45, pan_min_norm=0.0, pan_max_norm=1.0):
        self.fw, self.fh = fw, fh
        self.base_crop_ratio = crop_ratio
        self.crop_w = int(fw * crop_ratio)
        self.crop_h = fh
        self.cam_x = fw / 2
        self.cam_x_smooth = float(fw / 2)
        self.velocity = 0.0
        self.accel = 0.0
        self.pan_min_norm = pan_min_norm
        self.pan_max_norm = pan_max_norm

    def update(self, ball_x, ball_vx=0):
        if ball_x is None:
            self.velocity *= 0.97
            self.accel *= 0.9
            self.cam_x += self.velocity
            self._clamp()
            self.cam_x_smooth = CAM_DISPLAY_SMOOTH * self.cam_x_smooth + (1 - CAM_DISPLAY_SMOOTH) * self.cam_x
            return
        self.crop_w = int(self.fw * self.base_crop_ratio)
        min_x = max(self.pan_min_norm * self.fw, self.crop_w / 2)
        max_x = min(self.pan_max_norm * self.fw, self.fw - self.crop_w / 2)
        lead = np.clip(ball_vx * LEAD_FACTOR, -self.crop_w * LEAD_CLIP, self.crop_w * LEAD_CLIP)
        target = np.clip(ball_x + lead, min_x, max_x)
        dead_zone = self.crop_w * 0.08
        dist = target - self.cam_x
        if abs(dist) < dead_zone:
            self.velocity *= 0.95
            raw_accel = 0
        else:
            spring = -0.6 * (self.cam_x - target) * 0.01
            damp = -0.98 * self.velocity * 0.1
            raw_accel = np.clip(spring + damp, -self.fw * 0.002, self.fw * 0.002)
        self.accel = ACCEL_SMOOTH * self.accel + (1 - ACCEL_SMOOTH) * raw_accel
        self.velocity += self.accel
        self.velocity = np.clip(self.velocity, -self.fw * 0.007, self.fw * 0.007)
        self.cam_x += self.velocity
        self._clamp()
        self.cam_x_smooth = CAM_DISPLAY_SMOOTH * self.cam_x_smooth + (1 - CAM_DISPLAY_SMOOTH) * self.cam_x

    def _clamp(self):
        min_x = max(self.pan_min_norm * self.fw, self.crop_w / 2)
        max_x = min(self.pan_max_norm * self.fw, self.fw - self.crop_w / 2)
        if self.cam_x < min_x:
            self.cam_x = min_x
            self.velocity *= 0.2
        elif self.cam_x > max_x:
            self.cam_x = max_x
            self.velocity *= 0.2

    def pan_position_norm(self):
        return self.cam_x_smooth / self.fw

    def crop(self, frame):
        cx = self.cam_x_smooth
        x1 = max(0, int(cx - self.crop_w / 2))
        x2 = min(self.fw, int(cx + self.crop_w / 2))
        return frame[0:self.fh, x1:x2].copy()

CAM_PAN_MIN_EFF = CAM_PAN_MIN_NORM if CAM_PAN_MIN_NORM is not None else 0.0
CAM_PAN_MAX_EFF = CAM_PAN_MAX_NORM if CAM_PAN_MAX_NORM is not None else 1.0

# ==============================================================================
# INIT
# ==============================================================================
kalman = BallKalmanFilter()
camera = SmoothBroadcastCamera(W, H, crop_ratio=CROP_RATIO, pan_min_norm=CAM_PAN_MIN_EFF, pan_max_norm=CAM_PAN_MAX_EFF)
ball_trail = []
out_w, out_h = int(W * CROP_RATIO), H
smooth_x, smooth_y = None, None
confidence_memory = 0

log(f"Video: {W}x{H} @ {FPS:.1f}fps, {TOTAL} frames")
log(f"Output: {out_w}x{out_h} | field_mask={'injected' if FIELD_MASK_POINTS is not None else 'none'} | show_mask={SHOW_FIELD_MASK} | show_ball={SHOW_BALL_RED}")
log(f"Camera pan limits: [{CAM_PAN_MIN_EFF:.2f}, {CAM_PAN_MAX_EFF:.2f}]")
log(f"Detection: imgsz={DETECTION_SIZE}, full_frame_every={FULL_FRAME_INTERVAL}, refine={REFINE_PATCH_SIZE}")

fourcc = cv2.VideoWriter_fourcc(*'mp4v')
out = cv2.VideoWriter(output_path, fourcc, FPS, (out_w, out_h))

frames_with_ball = 0
frames_red_drawn = 0
frame_idx = 0
last_progress = 30
center_x, center_y = W // 2, H // 2
detection_history = []

# ==============================================================================
# DETECTION HELPERS
# ==============================================================================
log("Starting broadcast processing v4 (single-Kalman, detect every 2nd frame)...")
_start = time.time()

def run_detection(img, conf_thresh, offset_x=0, offset_y=0, pred_x=None, pred_y=None):
    """Run YOLO on img, return best ball position with distance-weighted scoring."""
    best_ball, best_score = None, -1e9
    img_h, img_w = img.shape[:2]
    results = model(img, conf=conf_thresh, imgsz=DETECTION_SIZE, verbose=False)
    for r in results:
        for box in r.boxes:
            if int(box.cls[0]) != 32:
                continue
            x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
            cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
            full_cx, full_cy = cx + offset_x, cy + offset_y
            box_w, box_h = x2 - x1, y2 - y1
            aspect = box_w / max(box_h, 1)
            if aspect < 0.35 or aspect > 2.8:
                continue
            if box_w > img_w * 0.10 or box_h > img_h * 0.10 or box_w < 4 or box_h < 4:
                continue
            if not is_in_field(full_cx, full_cy):
                continue
            conf = float(box.conf[0])
            dist = np.sqrt((full_cx - pred_x)**2 + (full_cy - pred_y)**2) if pred_x is not None and pred_y is not None else 0
            score = conf - (dist * DISTANCE_PENALTY)
            if score > best_score:
                best_ball, best_score = (full_cx, full_cy), score
    return best_ball, best_score

def get_roi_frame(frame, cx, cy, roi_size):
    half = roi_size // 2
    x1 = max(0, int(cx - half))
    y1 = max(0, int(cy - half))
    x2 = min(W, int(cx + half))
    y2 = min(H, int(cy + half))
    return frame[y1:y2, x1:x2].copy(), (x1, y1)

def anti_teleport(cx, cy, pred_x, pred_y, max_px, vx=0, vy=0):
    if pred_x is None or pred_y is None:
        return True
    d = np.sqrt((cx - pred_x)**2 + (cy - pred_y)**2)
    speed = np.sqrt(vx**2 + vy**2)
    return d <= (max_px + speed * TELEPORT_VELOCITY_FACTOR)

def refine_ball_center(frame, raw_cx, raw_cy):
    """Run a second YOLO pass on a tight crop for sub-pixel accuracy."""
    half = REFINE_PATCH_SIZE // 2
    x1 = max(0, int(raw_cx - half))
    y1 = max(0, int(raw_cy - half))
    x2 = min(W, int(raw_cx + half))
    y2 = min(H, int(raw_cy + half))
    patch = frame[y1:y2, x1:x2]
    if patch.size == 0:
        return raw_cx, raw_cy
    results = model(patch, conf=0.05, imgsz=REFINE_IMGSZ, verbose=False)
    best_cx, best_cy, best_conf = None, None, 0
    for r in results:
        for box in r.boxes:
            if int(box.cls[0]) != 32:
                continue
            xa, ya, xb, yb = box.xyxy[0].cpu().numpy()
            rcx = (xa + xb) / 2 + x1
            rcy = (ya + yb) / 2 + y1
            if float(box.conf[0]) > best_conf:
                best_conf = float(box.conf[0])
                best_cx, best_cy = rcx, rcy
    return (best_cx, best_cy) if best_cx is not None else (raw_cx, raw_cy)

def median_position(positions):
    if not positions:
        return None, None
    xs = [p[0] for p in positions]
    ys = [p[1] for p in positions]
    return float(np.median(xs)), float(np.median(ys))

# ==============================================================================
# MAIN LOOP — single-Kalman, no redundant tracker
# ==============================================================================
while True:
    ret, frame = cap.read()
    if not ret:
        break
    frame_idx += 1
    ball_x, ball_y = None, None

    # --- DETECTION ---
    pred = kalman.predict() if kalman.is_valid() else None
    pred_x, pred_y = pred if pred else (None, None)

    # Velocity comes cleanly from Kalman state (no separate tracker needed)
    ball_vx, ball_vy = kalman.velocity()

    # Full-frame every FULL_FRAME_INTERVAL frames OR when ball is lost
    do_full = (frame_idx % FULL_FRAME_INTERVAL == 0) or not kalman.is_valid() or kalman.frames_since > 1
    roi_size = ROI_EXPAND_LOST if kalman.frames_since > 0 else ROI_SIZE

    if do_full:
        best_ball, _ = run_detection(frame, DETECTION_CONF_TRACKING, pred_x=pred_x, pred_y=pred_y)
    else:
        # ROI detection near predicted position
        search_cx = (pred_x + ball_vx * 2) if pred_x is not None else center_x
        search_cy = (pred_y + ball_vy * 2) if pred_y is not None else center_y
        search_cx = float(np.clip(search_cx, roi_size / 2, W - roi_size / 2 - 1))
        search_cy = float(np.clip(search_cy, roi_size / 2, H - roi_size / 2 - 1))
        roi_img, (ox, oy) = get_roi_frame(frame, search_cx, search_cy, roi_size)
        if roi_img.size > 0:
            best_ball_local, _ = run_detection(roi_img, DETECTION_CONF_TRACKING, ox, oy, pred_x=pred_x, pred_y=pred_y)
            best_ball = best_ball_local if best_ball_local else None
        else:
            best_ball = None

    # Anti-teleport guard
    if best_ball and not anti_teleport(best_ball[0], best_ball[1], pred_x, pred_y, MAX_TELEPORT_PX, ball_vx, ball_vy):
        best_ball = None

    # --- UPDATE KALMAN ---
    if best_ball:
        raw_cx, raw_cy = best_ball
        refined_x, refined_y = refine_ball_center(frame, raw_cx, raw_cy)
        ball_x, ball_y = refined_x, refined_y

        # Median filter over last N detections (rejects outlier jumps)
        detection_history.append((ball_x, ball_y))
        if len(detection_history) > MEDIAN_FILTER_LEN:
            detection_history.pop(0)
        mx, my = median_position(detection_history)
        if mx is not None:
            ball_x, ball_y = mx, my

        # Single Kalman update — velocity is derived from state, not a tracker
        kalman.update(ball_x, ball_y)
        frames_with_ball += 1
        center_x, center_y = int(ball_x), int(ball_y)
    else:
        kalman.no_detection()
        if kalman.frames_since > 2:
            detection_history.clear()

    # --- POSITION ESTIMATE (Kalman prediction when no detection) ---
    if ball_x is None and kalman.is_valid():
        pred = kalman.predict()
        if pred:
            ball_x, ball_y = pred

    # --- EMA SMOOTHING for display ---
    if ball_x is not None and ball_y is not None:
        if smooth_x is None or smooth_y is None:
            smooth_x, smooth_y = ball_x, ball_y
        else:
            smooth_x = SMOOTH_ALPHA * smooth_x + (1 - SMOOTH_ALPHA) * ball_x
            smooth_y = SMOOTH_ALPHA * smooth_y + (1 - SMOOTH_ALPHA) * ball_y
        ball_x, ball_y = smooth_x, smooth_y
        confidence_memory = CONFIDENCE_MEMORY_DECAY
    else:
        confidence_memory = max(0, confidence_memory - 1)
        if smooth_x is not None and kalman.is_valid():
            pred = kalman.predict()
            if pred:
                ball_x, ball_y = pred

    # --- CAMERA ---
    # ball_vx comes from Kalman state (no separate tracker needed)
    ball_vx, ball_vy = kalman.velocity()
    camera.update(ball_x, ball_vx if ball_x is not None else 0)

    # --- ISAQ: HARDCODED PAN TO LEFT GOAL AT 2:28 FOR 2 SECONDS ---
    time_sec = frame_idx / FPS
    if 148.0 <= time_sec <= 152.0:  # 2:28 to 2:32 (allows it to reach left limit and stay for exactly ~2 seconds)
        left_limit = max(camera.pan_min_norm * camera.fw, camera.crop_w / 2)
        # Smoothly whip the camera fast to the left instead of an instant teleport
        if camera.cam_x > left_limit:
            camera.velocity -= camera.fw * 0.003  # Accelerate left
            camera.velocity = max(camera.velocity, -camera.fw * 0.06)  # Cap at a very fast whip speed
            camera.cam_x += camera.velocity
            if camera.cam_x < left_limit:
                camera.cam_x = left_limit
                camera.velocity = 0.0
        else:
            camera.cam_x = left_limit
            camera.velocity = 0.0
            
        camera.cam_x_smooth = CAM_DISPLAY_SMOOTH * camera.cam_x_smooth + (1 - CAM_DISPLAY_SMOOTH) * camera.cam_x
        
        # PREVENT RUBBER-BANDING TO MIDDLE:
        # Erase old tracking memory. If we don't, when the override ends, 
        # the EMA smoothing will slowly interpolate from where the ball was last seen 
        # (the middle) pulling the camera backwards.
        smooth_x, smooth_y = None, None
        detection_history.clear()
        kalman.initialized = False

    # --- DRAW RED DOT + GLOW + TRAIL (only when SHOW_BALL_RED) ---
    if SHOW_BALL_RED and ball_x is not None and ball_y is not None:
        frames_red_drawn += 1
        bx, by = int(ball_x), int(ball_y)
        if 0 <= bx < W and 0 <= by < H:
            if confidence_memory > 0:
                ball_trail.append((bx, by))
                if len(ball_trail) > TRAIL_LENGTH:
                    ball_trail.pop(0)
                for i, (tx, ty) in enumerate(ball_trail):
                    if 0 <= tx < W and 0 <= ty < H:
                        r = max(4, 12 - i * 2)
                        cv2.circle(frame, (tx, ty), r, (0, 0, 255), -1)
                        cv2.circle(frame, (tx, ty), r + 2, (255, 255, 255), 1)
            overlay = frame.copy()
            cv2.circle(overlay, (bx, by), GLOW_RADIUS, (0, 0, 255), -1)
            cv2.addWeighted(overlay, GLOW_ALPHA, frame, 1 - GLOW_ALPHA, 0, frame)
            cv2.circle(frame, (bx, by), 12, (0, 0, 255), -1)
            cv2.circle(frame, (bx, by), 14, (255, 255, 255), 2)
    elif confidence_memory <= 0:
        ball_trail.clear()
        smooth_x, smooth_y = None, None

    draw_field_mask_on_full_frame(frame)
    cropped = camera.crop(frame)
    if SHOW_FIELD_MASK and FIELD_MASK_POINTS is not None:
        cv2.putText(cropped, "FIELD MASK", (10, cropped.shape[0] - 15),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 100), 1, cv2.LINE_AA)
    draw_pan_indicator(cropped, camera)
    if cropped.shape[1] != out_w or cropped.shape[0] != out_h:
        cropped = cv2.resize(cropped, (out_w, out_h))
    cropped = draw_watermark(cropped)
    out.write(cropped)

    if frame_idx % max(1, TOTAL // 10) == 0:
        progress = 30 + int((frame_idx / TOTAL) * 55)
        if progress > last_progress:
            log(f"Processing: {progress}% ({frame_idx}/{TOTAL})")
            update_job("processing", progress=progress)
            last_progress = progress

cap.release()
out.release()

accuracy = int((frames_red_drawn / max(1, TOTAL)) * 100)
elapsed = time.time() - _start
log(f"BROADCAST PROCESSING v4 COMPLETE!")
log(f"Frames with red dot drawn: {frames_red_drawn}/{TOTAL} ({accuracy}%)")
log(f"Frames with detection/tracker: {frames_with_ball}/{TOTAL}")
log(f"Processing time: {elapsed:.1f}s ({frame_idx / max(1, elapsed):.1f} fps)")
log(f"Output: {out_w}x{out_h}")
