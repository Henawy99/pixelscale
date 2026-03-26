# ==============================================================================
# BROADCAST BALL TRACKING v3+ BULLETPROOF - RED ALWAYS ON BALL
# ==============================================================================
# Goal: viewer always sees the red dot on the ball. ACCURACY: dot on ball center.
# - Higher-res detection (1280), two-pass refinement, median filter, KCF tracker
# - Dot drawn whenever we have position (detection, tracker, OR Kalman)
# - Kalman memory 100 frames, low conf, full-frame when lost
# + All v3+ broadcast-quality: EMA, dynamic zoom, glow, lead, accel damping
# ==============================================================================

CROP_RATIO = 0.45
DETECTION_INTERVAL = 1
# ACCURACY: higher res = better ball center (1280 catches small/distant balls)
DETECTION_SIZE = 1280
REFINE_PATCH_SIZE = 128         # Second-pass crop around detection for precise center
REFINE_IMGSZ = 256              # YOLO size on patch (ball is large in patch = accurate)
MEDIAN_FILTER_LEN = 3           # Median of last N detections = reject outlier jumps
# BULLETPROOF: lower conf = catch more balls (red always on ball)
DETECTION_CONF_TRACKING = 0.08   # Very low when tracking - never miss
DETECTION_CONF_SEARCH = 0.10     # Low when searching - fast re-acquire
ROI_SIZE = 550                   # Slightly larger ROI when tracking
ROI_EXPAND_LOST = 950            # Big search area when ball lost
FULL_FRAME_INTERVAL = 5          # Full-frame often (catch long passes)
MAX_TELEPORT_PX = 150            # Allow bigger jumps (fast play)
KALMAN_MEMORY = 100              # Keep predicting ~4 sec at 25fps - dot stays on
TRAIL_LENGTH = 5

# v3+ Broadcast-quality tuning
SMOOTH_ALPHA = 0.65             # EMA on position (0.6-0.8) - buttery movement
CONFIDENCE_MEMORY_DECAY = 5     # Frames to keep trail after last detection
DISTANCE_PENALTY = 0.002        # Confidence weighting: prefer closer-to-pred
GLOW_RADIUS = 25                # Soft glow around ball (broadcast look)
GLOW_ALPHA = 0.2                # Glow strength
LEAD_FACTOR = 1.5               # Camera leads in direction of movement
LEAD_CLIP = 0.2                 # Max lead as fraction of crop width
ACCEL_SMOOTH = 0.9              # Acceleration damping (human feel)
TELEPORT_VELOCITY_FACTOR = 3     # Allow larger jumps when ball is fast (bulletproof long passes)

# Camera pan limits (normalized 0-1). Applied to camera center (pan position).
CAM_PAN_MIN_NORM = 0.29         # Left: do not pan less than this
CAM_PAN_MAX_NORM = 0.69         # Right: do not pan past this
SHOW_PAN_INDICATOR = True        # Draw current pan position (0-1) on output for tuning.

# Field mask from Supabase (draw on output, filter detections to inside mask)
SHOW_FIELD_MASK = True           # Draw field mask overlay on output (green polygon)
FIELD_MASK_OPACITY = 0.15       # Green fill opacity

# ==============================================================================
# FIELD MASK (injected by pipeline, or load from Supabase, fallback default)
# When run from chunk_processor, _injected_field_mask (normalized 0-1 points) may be set.
# ==============================================================================
DEFAULT_FIELD_MASK = np.array([
    [0.7094, 0.3214], [0.9169, 0.6337], [0.7619, 0.8321], [0.4965, 0.8303],
    [0.2582, 0.8277], [0.1916, 0.8337], [0.0512, 0.6403], [0.2682, 0.3280],
    [0.3480, 0.2944], [0.4433, 0.2690], [0.4935, 0.2659], [0.5407, 0.2677],
    [0.6075, 0.2809], [0.6570, 0.2975],
], dtype=np.float32)

try:
    _inj = _injected_field_mask
except NameError:
    _inj = None
if _inj is not None and len(_inj) > 0:
    FIELD_MASK_POINTS = np.array(_inj, dtype=np.float32)
    if 'log' in dir():
        log(f"Using injected field mask ({len(FIELD_MASK_POINTS)} points)")
else:
    FIELD_MASK_POINTS = DEFAULT_FIELD_MASK.copy()
    try:
        _key = os.environ.get("SUPABASE_KEY")
        if _key:
            _mask_resp = requests.get(
                "https://upooyypqhftzzwjrfyra.supabase.co/rest/v1/field_masks?select=mask_points&limit=1",
                headers={"apikey": _key, "Authorization": f"Bearer {_key}"},
                timeout=10,
            )
            _mask_data = _mask_resp.json()
            if _mask_data and _mask_data[0].get("mask_points"):
                FIELD_MASK_POINTS = np.array([[p["x"], p["y"]] for p in _mask_data[0]["mask_points"]], dtype=np.float32)
                log(f"Loaded custom field mask from Supabase ({len(FIELD_MASK_POINTS)} points)")
    except Exception as e:
        log(f"Using default field mask ({e})")

field_mask = np.zeros((H, W), dtype=np.uint8)
_pts = FIELD_MASK_POINTS.copy()
_pts[:, 0] *= W
_pts[:, 1] *= H
cv2.fillPoly(field_mask, [_pts.astype(np.int32)], 255)

def is_in_field(x, y):
    """True if (x,y) is inside the field mask (full-frame pixels)."""
    ix, iy = max(0, min(int(x), W - 1)), max(0, min(int(y), H - 1))
    return field_mask[iy, ix] > 0

def draw_field_mask_on_crop(cropped_img, crop_left_x, full_w, full_h):
    """Draw field mask on the cropped frame (normalized mask -> crop pixels)."""
    if not SHOW_FIELD_MASK:
        return
    points = FIELD_MASK_POINTS.copy()
    points[:, 0] = points[:, 0] * full_w - crop_left_x
    points[:, 1] = points[:, 1] * full_h
    polygon = points.astype(np.int32)
    overlay = cropped_img.copy()
    cv2.fillPoly(overlay, [polygon], (0, 255, 0))
    cv2.addWeighted(overlay, FIELD_MASK_OPACITY, cropped_img, 1 - FIELD_MASK_OPACITY, 0, cropped_img)
    cv2.polylines(cropped_img, [polygon], True, (0, 255, 100), 2, cv2.LINE_AA)

def draw_pan_indicator(cropped_img, camera):
    """Draw current pan position (0-1) and allowed range so you can tune CAM_PAN_*_NORM."""
    if not SHOW_PAN_INDICATOR:
        return
    pan = camera.pan_position_norm()
    # Top-right: "Pan: 0.45 [0.06 - 0.94]"
    h, w = cropped_img.shape[:2]
    text = f"Pan: {pan:.2f}  [{camera.pan_min_norm:.2f} - {camera.pan_max_norm:.2f}]"
    (tw, th), _ = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, 0.55, 1)
    x, y = w - tw - 12, 28
    cv2.rectangle(cropped_img, (x - 4, y - th - 4), (x + tw + 4, y + 4), (0, 0, 0), -1)
    cv2.putText(cropped_img, text, (x, y), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 255), 1, cv2.LINE_AA)

# ==============================================================================
# KALMAN FILTER (extended memory when lost)
# ==============================================================================
class BallKalmanFilter:
    def __init__(self):
        self.kf = cv2.KalmanFilter(4, 2)
        self.kf.transitionMatrix = np.array([[1,0,1,0],[0,1,0,1],[0,0,1,0],[0,0,0,1]], dtype=np.float32)
        self.kf.measurementMatrix = np.array([[1,0,0,0],[0,1,0,0]], dtype=np.float32)
        self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * 0.03
        self.kf.measurementNoiseCov = np.eye(2, dtype=np.float32) * 0.3
        self.initialized = False
        self.frames_since = 0

    def init(self, x, y):
        self.kf.statePost = np.array([[x],[y],[0],[0]], dtype=np.float32)
        self.initialized = True
        self.frames_since = 0

    def predict(self):
        if not self.initialized:
            return None
        p = self.kf.predict()
        return p[0,0], p[1,0]

    def update(self, x, y):
        if not self.initialized:
            self.init(x, y)
        else:
            self.kf.correct(np.array([[x],[y]], dtype=np.float32))
        self.frames_since = 0

    def is_valid(self):
        return self.initialized and self.frames_since < KALMAN_MEMORY

    def no_detection(self):
        self.frames_since += 1

# ==============================================================================
# SMOOTH BROADCAST CAMERA (v3+ dynamic zoom, lead, accel damping)
# ==============================================================================
# Smoothing for displayed camera position (stops crop flicker from sub-pixel jitter)
CAM_DISPLAY_SMOOTH = 0.88   # EMA: 0.88 = very smooth display, 0.12 = new value

class SmoothBroadcastCamera:
    def __init__(self, fw, fh, crop_ratio=0.45, pan_min_norm=0.0, pan_max_norm=1.0):
        self.fw, self.fh = fw, fh
        self.base_crop_ratio = crop_ratio
        self.crop_w = int(fw * crop_ratio)
        self.crop_h = fh
        self.cam_x = fw / 2
        self.cam_x_smooth = float(fw / 2)  # Smoothed position for crop/display (stops flicker)
        self.velocity = 0.0
        self.accel = 0.0  # Acceleration damping (human-operated feel)
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
        # Fixed crop width (no dynamic zoom)
        self.crop_w = int(self.fw * self.base_crop_ratio)
        # Pan limits apply to CAMERA CENTER (pan position 0-1), not crop edges. So pan can go up to 0.69.
        min_x = max(self.pan_min_norm * self.fw, self.crop_w / 2)
        max_x = min(self.pan_max_norm * self.fw, self.fw - self.crop_w / 2)
        # Clamp target to allowed range - prevents camera fighting the limit and flickering
        lead = np.clip(ball_vx * LEAD_FACTOR, -self.crop_w * LEAD_CLIP, self.crop_w * LEAD_CLIP)
        target = np.clip(ball_x + lead, min_x, max_x)
        dist = target - self.cam_x
        dead_zone = self.crop_w * 0.08
        if abs(dist) < dead_zone:
            self.velocity *= 0.95
            raw_accel = 0
        else:
            spring = -0.6 * (self.cam_x - target) * 0.01
            damp = -0.98 * self.velocity * 0.1
            raw_accel = np.clip(spring + damp, -self.fw * 0.002, self.fw * 0.002)
        # Acceleration damping (no robotic feel)
        self.accel = ACCEL_SMOOTH * self.accel + (1 - ACCEL_SMOOTH) * raw_accel
        self.velocity += self.accel
        self.velocity = np.clip(self.velocity, -self.fw * 0.007, self.fw * 0.007)
        self.cam_x += self.velocity
        self._clamp()
        # EMA on displayed position so the crop does not flicker (sub-pixel jitter -> integer crop jumps)
        self.cam_x_smooth = CAM_DISPLAY_SMOOTH * self.cam_x_smooth + (1 - CAM_DISPLAY_SMOOTH) * self.cam_x

    def _clamp(self):
        # Pan limits are for camera CENTER (so pan display goes up to 0.69). Also keep crop inside frame.
        min_x = max(self.pan_min_norm * self.fw, self.crop_w / 2)
        max_x = min(self.pan_max_norm * self.fw, self.fw - self.crop_w / 2)
        if self.cam_x < min_x:
            self.cam_x = min_x
            self.velocity *= 0.2  # soft stop instead of 0 to avoid next-frame jerk
        elif self.cam_x > max_x:
            self.cam_x = max_x
            self.velocity *= 0.2

    def pan_position_norm(self):
        """Current camera center as normalized 0-1 (0=left, 1=right). Uses smoothed position."""
        return self.cam_x_smooth / self.fw

    def crop(self, frame):
        # Use smoothed position so integer crop bounds don't jump frame-to-frame (stops flicker)
        cx = self.cam_x_smooth
        x1 = max(0, int(cx - self.crop_w / 2))
        x2 = min(self.fw, int(cx + self.crop_w / 2))
        return frame[0:self.fh, x1:x2].copy()

# Pan limits (normalized 0-1)
CAM_PAN_MIN_EFF = CAM_PAN_MIN_NORM if CAM_PAN_MIN_NORM is not None else 0.0
CAM_PAN_MAX_EFF = CAM_PAN_MAX_NORM if CAM_PAN_MAX_NORM is not None else 1.0

# ==============================================================================
# INIT
# ==============================================================================
kalman = BallKalmanFilter()
camera = SmoothBroadcastCamera(W, H, crop_ratio=CROP_RATIO, pan_min_norm=CAM_PAN_MIN_EFF, pan_max_norm=CAM_PAN_MAX_EFF)
tracker = None
ball_trail = []
# Fixed output size for writer (camera may zoom; we resize cropped frame to this)
out_w, out_h = int(W * CROP_RATIO), H
smooth_x, smooth_y = None, None  # EMA position smoothing
confidence_memory = 0            # Trail only clears when this <= 0

log(f"Video: {W}x{H} @ {FPS:.1f}fps, {TOTAL} frames")
log(f"Output: {out_w}x{out_h} | v3+ field_mask={SHOW_FIELD_MASK}")
log(f"Camera pan limits (norm): [{CAM_PAN_MIN_EFF:.2f}, {CAM_PAN_MAX_EFF:.2f}]")
log(f"Detection: imgsz={DETECTION_SIZE}, refine={REFINE_PATCH_SIZE}, median={MEDIAN_FILTER_LEN}")

fourcc = cv2.VideoWriter_fourcc(*'mp4v')
out = cv2.VideoWriter(output_path, fourcc, FPS, (out_w, out_h))

frames_with_ball = 0
frames_red_drawn = 0   # Frames where the red dot was actually drawn on output (what you see)
ball_vx, ball_vy = 0.0, 0.0
last_ball_x, last_ball_y = None, None
frame_idx = 0
last_progress = 30
center_x, center_y = W // 2, H // 2  # For ROI center when kalman invalid

# ==============================================================================
# MAIN LOOP (v3 - Stronger recognition)
# ==============================================================================
log("Starting broadcast processing v3+ (broadcast-quality feel)...")
_start = time.time()

def run_detection(img, conf_thresh, offset_x=0, offset_y=0, pred_x=None, pred_y=None):
    """Run YOLO; return best ball (cx, cy) in img coords. Confidence + distance scoring."""
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
            if aspect < 0.35 or aspect > 2.8:   # Slightly looser - catch more balls
                continue
            if box_w > img_w * 0.10 or box_h > img_h * 0.10 or box_w < 4 or box_h < 4:
                continue
            if not is_in_field(full_cx, full_cy):
                continue
            conf = float(box.conf[0])
            # Score: prefer closer-to-prediction (reduces crowd noise)
            dist = np.sqrt((full_cx - pred_x)**2 + (full_cy - pred_y)**2) if pred_x is not None and pred_y is not None else 0
            score = conf - (dist * DISTANCE_PENALTY)
            if score > best_score:
                best_ball, best_score = (cx, cy), score
    return best_ball, best_score

def get_roi_frame(frame, cx, cy, roi_size):
    """Extract ROI region. cx,cy in full-frame coords."""
    half = roi_size // 2
    x1 = max(0, int(cx - half))
    y1 = max(0, int(cy - half))
    x2 = min(W, int(cx + half))
    y2 = min(H, int(cy + half))
    return frame[y1:y2, x1:x2].copy(), (x1, y1)

def anti_teleport(cx, cy, pred_x, pred_y, max_px, ball_vx=0, ball_vy=0):
    """Reject if detection too far from prediction. Velocity-aware (allow long passes)."""
    if pred_x is None or pred_y is None:
        return True
    d = np.sqrt((cx - pred_x)**2 + (cy - pred_y)**2)
    speed = np.sqrt(ball_vx**2 + ball_vy**2)
    dynamic_limit = max_px + speed * TELEPORT_VELOCITY_FACTOR
    return d <= dynamic_limit

def refine_ball_center(frame, raw_cx, raw_cy):
    """Second-pass: crop around detection, run YOLO at high relative res for precise center."""
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
            cx = (xa + xb) / 2
            cy = (ya + yb) / 2
            if float(box.conf[0]) > best_conf:
                best_conf = float(box.conf[0])
                best_cx, best_cy = cx + x1, cy + y1
    if best_cx is not None:
        return best_cx, best_cy
    return raw_cx, raw_cy

def median_position(positions):
    """Return (median_x, median_y) to reject single-frame outliers."""
    if not positions:
        return None, None
    xs = [p[0] for p in positions]
    ys = [p[1] for p in positions]
    return float(np.median(xs)), float(np.median(ys))

detection_history = []  # Last N raw positions for median filter

while True:
    ret, frame = cap.read()
    if not ret:
        break
    frame_idx += 1
    ball_x, ball_y = None, None

    # BULLETPROOF: lower conf = more detections. Aggressive re-acquire when lost 4+ frames
    conf = 0.06 if kalman.frames_since > 3 else DETECTION_CONF_TRACKING
    pred = kalman.predict() if kalman.is_valid() else None
    pred_x, pred_y = pred if pred else (None, None)

    # BULLETPROOF: full-frame whenever we might have lost the ball (re-acquire fast)
    do_full = (frame_idx % FULL_FRAME_INTERVAL == 0) or not kalman.is_valid() or kalman.frames_since > 1
    roi_size = ROI_EXPAND_LOST if kalman.frames_since > 0 else ROI_SIZE

    if do_full:
        best_ball, _ = run_detection(frame, conf, pred_x=pred_x, pred_y=pred_y)
    else:
        search_cx = pred_x if pred_x is not None else center_x
        search_cy = pred_y if pred_y is not None else center_y
        search_cx = search_cx + ball_vx * 2
        search_cy = search_cy + ball_vy * 2
        search_cx = np.clip(search_cx, roi_size/2, W - roi_size/2 - 1)
        search_cy = np.clip(search_cy, roi_size/2, H - roi_size/2 - 1)

        roi_img, (ox, oy) = get_roi_frame(frame, search_cx, search_cy, roi_size)
        if roi_img.size > 0:
            best_ball_local, _ = run_detection(roi_img, conf, ox, oy, pred_x=pred_x, pred_y=pred_y)
            if best_ball_local:
                best_ball = (best_ball_local[0] + ox, best_ball_local[1] + oy)
        else:
            best_ball = None

    # Anti-teleport: velocity-aware (allow long passes when ball is fast)
    if best_ball and not anti_teleport(best_ball[0], best_ball[1], pred_x, pred_y, MAX_TELEPORT_PX, ball_vx, ball_vy):
        best_ball = None

    # ACCURACY: two-pass refinement + median filter when we have a detection
    if best_ball:
        raw_cx, raw_cy = best_ball[0], best_ball[1]
        ball_x, ball_y = refine_ball_center(frame, raw_cx, raw_cy)
        detection_history.append((ball_x, ball_y))
        if len(detection_history) > MEDIAN_FILTER_LEN:
            detection_history.pop(0)
        mx, my = median_position(detection_history)
        if mx is not None:
            ball_x, ball_y = mx, my
        bx, by = int(ball_x), int(ball_y)
        box_size = max(40, int(min(W, H) * 0.04))
        x1 = max(0, bx - box_size)
        y1 = max(0, by - box_size)
        x2 = min(W, bx + box_size)
        y2 = min(H, by + box_size)
        bbox = (x1, y1, x2 - x1, y2 - y1)
        try:
            # KCF is more accurate than MOSSE (fallback=True -> KCF)
            tracker = create_tracker(fallback=True)
            if tracker.init(frame, bbox):
                pass
        except:
            try:
                tracker = create_tracker()
                if tracker.init(frame, bbox):
                    pass
            except:
                tracker = None

        if last_ball_x is not None:
            ball_vx = ball_vx * 0.7 + (ball_x - last_ball_x) * 0.3
            ball_vy = ball_vy * 0.7 + (ball_y - last_ball_y) * 0.3
        last_ball_x, last_ball_y = ball_x, ball_y
        kalman.update(ball_x, ball_y)
        frames_with_ball += 1
        center_x, center_y = int(ball_x), int(ball_y)
    else:
        kalman.no_detection()
        if kalman.frames_since > 2:
            detection_history.clear()  # Don't blend new re-acquire with stale positions
        # Try tracker to fill gap
        if tracker is not None:
            try:
                ok, bbox = tracker.update(frame)
                if ok:
                    x, y, w, h = map(int, bbox)
                    ball_x = x + w / 2
                    ball_y = y + h / 2
                    if is_in_field(ball_x, ball_y):
                        kalman.update(ball_x, ball_y)
                        kalman.frames_since = 0  # Reset since we have tracker position
                        frames_with_ball += 1
                        center_x, center_y = int(ball_x), int(ball_y)
                    else:
                        ball_x, ball_y = None, None
                else:
                    tracker = None
            except:
                tracker = None

    # Use Kalman prediction when no direct measurement
    if ball_x is None and kalman.is_valid():
        pred = kalman.predict()
        if pred:
            ball_x, ball_y = pred

    # EMA position smoothing (kills micro-jitter - buttery movement)
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
        # BULLETPROOF: always use Kalman prediction when valid (dot never disappears)
        if ball_x is None and kalman.is_valid():
            pred = kalman.predict()
            if pred:
                ball_x, ball_y = pred

    # Update camera (dynamic zoom + momentum lead + accel damping)
    camera.update(ball_x, ball_vx if ball_x is not None else 0)

    # BULLETPROOF: ALWAYS draw red on ball whenever we have a position (detection, tracker, or Kalman)
    if ball_x is not None and ball_y is not None:
        frames_red_drawn += 1   # Count every frame the red dot is drawn (reported as % in job)
        bx, by = int(ball_x), int(ball_y)
        if 0 <= bx < W and 0 <= by < H:
            # Trail only when we had recent detection (avoids long stale trails)
            if confidence_memory > 0:
                ball_trail.append((bx, by))
                if len(ball_trail) > TRAIL_LENGTH:
                    ball_trail.pop(0)
                for i, (tx, ty) in enumerate(ball_trail):
                    if 0 <= tx < W and 0 <= ty < H:
                        r = max(4, 12 - i * 2)
                        cv2.circle(frame, (tx, ty), r, (0, 0, 255), -1)
                        cv2.circle(frame, (tx, ty), r + 2, (255, 255, 255), 1)
            # ALWAYS draw glow + dot (from detection, tracker, OR Kalman - red always visible)
            overlay = frame.copy()
            cv2.circle(overlay, (bx, by), GLOW_RADIUS, (0, 0, 255), -1)
            cv2.addWeighted(overlay, GLOW_ALPHA, frame, 1 - GLOW_ALPHA, 0, frame)
            cv2.circle(frame, (bx, by), 12, (0, 0, 255), -1)
            cv2.circle(frame, (bx, by), 14, (255, 255, 255), 2)
    elif confidence_memory <= 0:
        ball_trail.clear()
        smooth_x, smooth_y = None, None

    cropped = camera.crop(frame)
    crop_left_x = camera.cam_x_smooth - camera.crop_w / 2
    draw_field_mask_on_crop(cropped, crop_left_x, W, H)
    if SHOW_FIELD_MASK:
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

detection_frames = TOTAL // DETECTION_INTERVAL
# Report % of frames where red dot was DRAWN (what you see in the video), not just raw detections
accuracy = int((frames_red_drawn / max(1, TOTAL)) * 100)
tracker_ok_count = frames_red_drawn
elapsed = time.time() - _start

log(f"BROADCAST PROCESSING v3+ COMPLETE!")
log(f"Frames with red dot drawn: {frames_red_drawn}/{TOTAL} ({accuracy}%)")
log(f"Frames with detection/tracker: {frames_with_ball}/{TOTAL}")
log(f"Processing time: {elapsed:.1f}s ({frame_idx/elapsed:.1f} fps)")
log(f"Output: {out_w}x{out_h}")
