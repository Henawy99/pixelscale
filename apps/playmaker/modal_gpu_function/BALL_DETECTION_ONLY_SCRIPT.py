# ==============================================================================
# BALL DETECTION + DIGITAL CROP — Horizontal panning within field mask
# ==============================================================================

DETECTION_SIZE = 640            # Cost-effective: 640 vs 1280 (~4x faster inference)
DETECTION_CONF = 0.25           # Higher confidence = fewer false positives & wasted GPU time
KALMAN_MEMORY = 30              # Keep predicting ~1.2 sec at 25fps (was 60)
TRAIL_LENGTH = 5
GLOW_RADIUS = 25
GLOW_ALPHA = 0.2
CROP_RATIO = 0.45               # Fixed crop width ratio
CAM_SMOOTH = 0.06               # Much smoother camera panning (lower is slower)
MAX_TELEPORT_PX = 350           # Prevent ball from "flying off" to false detections
FOLLOW_PREDICTION_LIMIT = 6     # Only follow Kalman prediction for 6 frames before stopping camera
VELOCITY_DECAY = 0.95           # Slow down Kalman velocity when ball is lost
DETECT_EVERY_N_FRAMES = 2       # Cost-effective: run YOLO detection every 2nd frame (~50% GPU savings)
HSV_GREEN_MASK = True           # Pre-filter green grass to reduce false positives

def hsv_green_mask(frame):
    """Remove green grass → only ball, players, lines remain."""
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    green_mask = cv2.inRange(hsv, (35, 40, 40), (85, 255, 255))
    return cv2.bitwise_and(frame, frame, mask=cv2.bitwise_not(green_mask))

# --- FRAME EXTENSION (Vertical 9:16) ---
EXTEND_FRAME = True             # Enable 9:16 vertical output
EXTENDED_BACKGROUND_PATH = None # Path to AI-extended 9:16 background image
# ---------------------------------------

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
    
    # Calculate horizontal bounds for camera clamping
    F_MIN_X = np.min(_pts[:, 0])
    F_MAX_X = np.max(_pts[:, 0])
else:
    def is_in_field(x, y):
        return 0 <= x < W and 0 <= y < H
    F_MIN_X, F_MAX_X = 0, W

# Digital Crop Setup
CROP_W = int(W * CROP_RATIO)
# Clamp camera center so the crop FOV stays within the field mask
CAM_MIN_X = max(CROP_W / 2, F_MIN_X + CROP_W / 2)
CAM_MAX_X = min(W - CROP_W / 2, F_MAX_X - CROP_W / 2)

# If field is narrower than the crop, center on field
if CAM_MIN_X > CAM_MAX_X:
    CAM_MIN_X = CAM_MAX_X = (F_MIN_X + F_MAX_X) / 2

cam_x = (CAM_MIN_X + CAM_MAX_X) / 2

# ==============================================================================
# KALMAN FILTER
# ==============================================================================
class BallKalmanFilter:
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
        self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * 0.2    # Lower = smoother, less aggressive trajectory changes
        self.kf.measurementNoiseCov = np.eye(2, dtype=np.float32) * 2.0 # Higher = trust YOLO less, trust Kalman prediction more
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

    def is_valid(self):
        return self.initialized and self.frames_since < KALMAN_MEMORY

    def no_detection(self):
        self.frames_since += 1
        # Decay velocity so prediction doesn't fly off forever
        self.kf.statePost[2] *= VELOCITY_DECAY
        self.kf.statePost[3] *= VELOCITY_DECAY

# ==============================================================================
# INIT
# ==============================================================================
kalman = BallKalmanFilter()
ball_trail = []
fourcc = cv2.VideoWriter_fourcc(*'mp4v')

# Calculate vertical output dimensions
CROP_W = int(W * CROP_RATIO)
if EXTEND_FRAME:
    OUT_W = CROP_W
    OUT_H = int(CROP_W * 16 / 9)
    log(f"Vertical 9:16 Mode: Output {OUT_W}x{OUT_H}")
else:
    OUT_W = CROP_W
    OUT_H = H
    log(f"Horizontal 16:9 Mode: Output {OUT_W}x{OUT_H}")

out = cv2.VideoWriter(output_path, fourcc, FPS, (OUT_W, OUT_H))

# Load or Prepare Background
bg_image = None
if EXTEND_FRAME and EXTENDED_BACKGROUND_PATH:
    if os.path.exists(EXTENDED_BACKGROUND_PATH):
        bg_image = cv2.imread(EXTENDED_BACKGROUND_PATH)
        if bg_image is not None:
            bg_image = cv2.resize(bg_image, (OUT_W, OUT_H))
            log(f"✅ Loaded custom background: {EXTENDED_BACKGROUND_PATH}")
        else:
            log(f"⚠️ Failed to load background: {EXTENDED_BACKGROUND_PATH}")
    else:
        log(f"⚠️ Background path not found: {EXTENDED_BACKGROUND_PATH}")

frames_with_ball = 0
frame_idx = 0
last_progress = 19

def run_detection(img, conf_thresh, pred_x=None, pred_y=None):
    best_ball, best_score = None, -1e9
    # Apply HSV green masking before detection
    detect_img = hsv_green_mask(img) if HSV_GREEN_MASK else img
    results = model(detect_img, conf=conf_thresh, imgsz=DETECTION_SIZE, verbose=False)
    for r in results:
        for box in r.boxes:
            cls_idx = int(box.cls[0])
            cls_name = model.names.get(cls_idx, "").lower()
            # Accept standard YOLO sports ball (32), anything named 'ball', or class 0 if it's a single-class model
            if cls_idx != 32 and "ball" not in cls_name and not (cls_idx == 0 and len(model.names) == 1):
                continue
            x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
            cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
            if not is_in_field(cx, cy):
                continue
            conf = float(box.conf[0])
            dist = np.sqrt((cx - pred_x)**2 + (cy - pred_y)**2) if pred_x is not None and pred_y is not None else 0
            score = conf - (dist * 0.002)
            if score > best_score:
                best_ball, best_score = (cx, cy), score
    return best_ball

log(f"Starting ball detection (COST-OPTIMIZED: size={DETECTION_SIZE}, conf={DETECTION_CONF}, every {DETECT_EVERY_N_FRAMES} frames)...")
_start = time.time()

while True:
    ret, frame = cap.read()
    if not ret:
        break
    frame_idx += 1
    
    pred = kalman.predict() if kalman.is_valid() else None
    pred_x, pred_y = pred if pred else (None, None)
    
    # Cost optimization: only run YOLO on every Nth frame; use Kalman on skipped frames
    best_ball = None
    if frame_idx % DETECT_EVERY_N_FRAMES == 0:
        best_ball = run_detection(frame, DETECTION_CONF, pred_x=pred_x, pred_y=pred_y)
    
    # Teleport guard: Ignore detections too far from prediction
    if best_ball and pred_x is not None:
        dist = np.sqrt((best_ball[0] - pred_x)**2 + (best_ball[1] - pred_y)**2)
        if dist > MAX_TELEPORT_PX:
            best_ball = None

    ball_x, ball_y = None, None
    is_real_detection = False
    if best_ball:
        ball_x, ball_y = best_ball
        kalman.update(ball_x, ball_y)
        frames_with_ball += 1
        is_real_detection = True
    else:
        kalman.no_detection()
        if kalman.is_valid():
            p = kalman.predict()
            if p:
                ball_x, ball_y = p

    # Draw debug dots
    if ball_x is not None and ball_y is not None:
        bx, by = int(ball_x), int(ball_y)
        color = (0, 0, 255) if is_real_detection else (255, 0, 0) # RED for Real, BLUE for Kalman
        
        if 0 <= bx < W and 0 <= by < H:
            ball_trail.append((bx, by, is_real_detection))
            if len(ball_trail) > TRAIL_LENGTH:
                ball_trail.pop(0)
            
            # Trail
            for i, (tx, ty, was_real) in enumerate(ball_trail):
                r = int(max(4, 12 - (len(ball_trail) - 1 - i) * 2))
                tr_color = (0, 0, 255) if was_real else (255, 0, 0)
                cv2.circle(frame, (tx, ty), r, tr_color, -1)
            
            # Glow
            overlay = frame.copy()
            cv2.circle(overlay, (bx, by), GLOW_RADIUS, color, -1)
            cv2.addWeighted(overlay, GLOW_ALPHA, frame, 1 - GLOW_ALPHA, 0, frame)
            
            # Sharp dot
            cv2.circle(frame, (bx, by), 12, color, -1)
            cv2.circle(frame, (bx, by), 14, (255, 255, 255), 2)
            
            # Debug Label
            label = "REAL" if is_real_detection else "PREDICT"
            cv2.putText(frame, label, (bx + 20, by), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1, cv2.LINE_AA)
    else:
        ball_trail.clear()

    # --- DIGITAL CROP CAMERA UPDATE ---
    # Only follow REAL detections, or predictions within a short grace period.
    # This prevents the camera from "runaway" guessing.
    if is_real_detection or (kalman.is_valid() and kalman.frames_since < FOLLOW_PREDICTION_LIMIT):
        if ball_x is not None:
            target_cam_x = np.clip(ball_x, CAM_MIN_X, CAM_MAX_X)
            cam_x = cam_x * (1 - CAM_SMOOTH) + target_cam_x * CAM_SMOOTH
    
    # Final clamp and crop
    cam_x = np.clip(cam_x, CAM_MIN_X, CAM_MAX_X)
    x1 = int(cam_x - CROP_W / 2)
    x2 = x1 + CROP_W
    
    # Safety slice: ensure we don't exceed frame width
    if x2 > W:
        x2 = W
        x1 = W - CROP_W
    if x1 < 0:
        x1 = 0
        x2 = CROP_W
        
    cropped_frame = frame[:, x1:x2]
    
    # If the slice is slightly off by 1px due to rounding, resize it
    if cropped_frame.shape[1] != CROP_W:
        cropped_frame = cv2.resize(cropped_frame, (CROP_W, H))

    # --- VERTICAL COMPOSITION ---
    if EXTEND_FRAME:
        if bg_image is not None:
            canvas = bg_image.copy()
        else:
            # Fallback: Create blurred background from the current frame
            # 1. Take a center vertical 9:16 slice of the original frame
            bg_w_full = int(H * 9 / 16)
            bg_x1 = max(0, W // 2 - bg_w_full // 2)
            bg_x2 = min(W, bg_x1 + bg_w_full)
            bg_crop = frame[0:H, bg_x1:bg_x2].copy()
            
            # 2. Apply heavy blur + darkness (Optimized)
            # Downscale heavily to blur fast, apply smaller blur, then upscale to canvas
            small_w, small_h = max(1, OUT_W // 8), max(1, OUT_H // 8)
            small_bg = cv2.resize(bg_crop, (small_w, small_h))
            small_bg = cv2.GaussianBlur(small_bg, (15, 15), 0)
            canvas = cv2.resize(small_bg, (OUT_W, OUT_H), interpolation=cv2.INTER_LINEAR)
            canvas = cv2.convertScaleAbs(canvas, alpha=0.45, beta=0) # 55% darker
        
        # 4. Paste the tracked crop in the vertical center
        y_offset = (OUT_H - H) // 2
        canvas[y_offset:y_offset + H, 0:OUT_W] = cropped_frame
        final_frame = canvas
    else:
        final_frame = cropped_frame

    out.write(final_frame)

    # Progress update every 1%
    if frame_idx % max(1, TOTAL // 100) == 0:
        progress = 20 + int((frame_idx / TOTAL) * 75)
        if progress > last_progress:
            update_job("processing", progress=progress)
            last_progress = progress
            if frame_idx % 500 == 0:
                log(f"💓 Processing: {frame_idx}/{TOTAL} frames ({(frame_idx/TOTAL)*100:.1f}%)")

cap.release()
out.release()

elapsed = time.time() - _start
log(f"DETECTION COMPLETE! Time: {elapsed:.1f}s | FPS: {frame_idx / max(1, elapsed):.1f} | Frames with ball: {frames_with_ball}")
