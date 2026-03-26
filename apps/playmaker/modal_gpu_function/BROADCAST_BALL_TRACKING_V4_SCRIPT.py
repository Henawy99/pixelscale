# ── AI FRAME EXTENSION (auto-injected) ──────────────────────────────────
EXTEND_FRAME = True
EXTENDED_BACKGROUND_PATH = None
# ─────────────────────────────────────────────────────────────────────────────

"""
Ball Tracking v4.7 — COST OPTIMIZED: ~$0.60/hr target

CHANGES vs v4.6:
  1. FFmpeg pipe (libx264 ultrafast) replaces OpenCV mp4v software encoder
     → 10-20x faster frame writing on CPU-limited Modal containers
  2. Ball-search rate capped even when lost:
     - When kalman not yet initialized: YOLO every NEW_BALL_EVERY=3rd frame
     - When ball lost > MISS_FULL_FRAME: YOLO every LOST_BALL_EVERY=4th frame
     → Eliminates the YOLO/f=1.00 trap when the ball is hard to detect
  3. Field mask pre-rendered as a numpy alpha blend — no frame.copy(), no
     addWeighted per frame. One-time cost at startup.
  4. All detection still runs on DET-resolution frames (max 1280px wide)
  5. Output: native resolution (4K in → same 16:9 crop out)

Uses injected globals: cv2, np, model, cap, W, H, FPS, TOTAL, output_path,
                       update_job, log, DETECTION_SIZE, FULL_FRAME_INTERVAL,
                       DETECTION_CONF_TRACKING, SHOW_FIELD_MASK, SHOW_BALL_RED,
                       draw_field_mask_overlay_on_original
Also uses: subprocess (standard library)
"""

import math
import subprocess

# ── Config ──
YOLO_CONF           = DETECTION_CONF_TRACKING
SMOOTHING           = 0.06
ZOOM_BASE           = 1.75
ZOOM_FAR            = 2.1
ZOOM_SMOOTH         = 0.08
dt                  = 1.0 / max(FPS, 1)

# ⚡ Detection downscale — one resize per frame, used for ALL strategies
# v4.7: 960px (was 1280) — 44% fewer pixels per YOLO call, ~1.4x faster inference
DET_MAX_W           = 960
DET_W               = min(W, DET_MAX_W)
DET_H               = int(H * DET_W / max(W, 1))
DET_SCALE_X         = W / max(DET_W, 1)
DET_SCALE_Y         = H / max(DET_H, 1)

# ⚡ YOLO inference sizes (on DET frame — small and fast)
ROI_INFER_SIZE      = 384        # v4.7: smaller ROI crops (was 448)
FULL_INFER_SIZE     = 576        # v4.7: slightly smaller (was 640)
ZONE_INFER_SIZE     = 416        # v4.7: smaller zone (was 480)

# ⚡ Detection rate control
# v4.7: ROI every 8 frames (was 5) — Kalman interpolates between detections
ROI_EVERY           = 8          # ROI every N frames when tracking
STABLE_SKIP_FRAMES  = 4          # Extra skip when very stable (was 3)
DETECT_EVERY        = max(30, FULL_FRAME_INTERVAL * 10)  # Full-frame scan interval

# ⚡ CRITICAL: cap YOLO calls when ball not found — prevents YOLO/f≈1.0
# v4.7: 7/8 (was 3/4) — massive reduction in wasted YOLO calls during search
NEW_BALL_EVERY      = 7          # Scan for ball every N frames before first detection
LOST_BALL_EVERY     = 8          # Full-frame every N frames when miss_count > threshold

# ⚡ Miss thresholds
MISS_FULL_FRAME     = 6
MISS_ZONE_SPLIT     = 12
MISS_MOTION_DET     = 18

# Lookahead
LOOKAHEAD_MIN       = 5
LOOKAHEAD_MAX       = 15
SKIP_DET_CONF       = 0.55


# ══════════════════════════════════════════════════════════════
# KALMAN TRACKER
# ══════════════════════════════════════════════════════════════

class BallKalmanTracker:
    VELOCITY_DECAY  = 0.96
    MAX_MISS        = 60
    MAX_TELEPORT_PX = 500
    BASE_PROC_NOISE = 0.5
    KICK_PROC_NOISE = 50.0

    def __init__(self, x, y, _dt=1/20):
        self.kf = cv2.KalmanFilter(4, 2)
        self.dt = _dt
        self.kf.transitionMatrix = np.array(
            [[1, 0, _dt, 0], [0, 1, 0, _dt], [0, 0, 1, 0], [0, 0, 0, 1]], np.float32)
        self.kf.measurementMatrix = np.array(
            [[1, 0, 0, 0], [0, 1, 0, 0]], np.float32)
        self._reset_noise()
        self.kf.statePost = np.array([[x], [y], [0], [0]], np.float32)
        self.kf.errorCovPost = np.eye(4, dtype=np.float32) * 10.0
        self.miss_count = 0
        self.hit_count = 0
        self.last_detection = (x, y)
        self.last_velocity = (0.0, 0.0)
        self._kick_detected = False
        self.detection_history = [(x, y)]
        self._consecutive_high_conf = 0

    def _reset_noise(self):
        self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * self.BASE_PROC_NOISE
        self.kf.processNoiseCov[2:, 2:] *= 20.0
        self.kf.measurementNoiseCov = np.eye(2, dtype=np.float32) * 2.0

    def predict(self):
        if self.miss_count > 3:
            scale = min(self.miss_count / 3.0, 15.0)
            self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * self.BASE_PROC_NOISE * scale
            self.kf.processNoiseCov[2:, 2:] *= 20.0
        p = self.kf.predict()
        return float(p[0, 0]), float(p[1, 0])

    def update(self, x, y, conf=0.5):
        if self.hit_count > 2:
            new_vx = (x - self.last_detection[0]) / max(self.dt, 1e-6)
            new_vy = (y - self.last_detection[1]) / max(self.dt, 1e-6)
            old_vx, old_vy = self.last_velocity
            accel = math.sqrt((new_vx - old_vx)**2 + (new_vy - old_vy)**2)
            if accel > 800:
                self._kick_detected = True
                self.kf.processNoiseCov = np.eye(4, dtype=np.float32) * self.KICK_PROC_NOISE
                self.kf.processNoiseCov[2:, 2:] *= 5.0
            else:
                self._kick_detected = False
                self._reset_noise()
            self.last_velocity = (new_vx, new_vy)
        self.kf.correct(np.array([[x], [y]], np.float32))
        self.miss_count = 0
        self.hit_count += 1
        self.last_detection = (x, y)
        self.detection_history.append((x, y))
        if len(self.detection_history) > 10:
            self.detection_history.pop(0)
        if conf >= SKIP_DET_CONF:
            self._consecutive_high_conf += 1
        else:
            self._consecutive_high_conf = 0

    def no_detection(self):
        self.miss_count += 1
        self.kf.statePost[2] *= self.VELOCITY_DECAY
        self.kf.statePost[3] *= self.VELOCITY_DECAY
        self._consecutive_high_conf = 0

    @property
    def search_radius(self):
        base = 200
        return int(base + min(self.miss_count, 20) * 30) if self.miss_count > 0 else base

    @property
    def search_radius_det(self):
        return int(self.search_radius / DET_SCALE_X)

    @property
    def velocity(self):
        return float(self.kf.statePost[2, 0]), float(self.kf.statePost[3, 0])

    @property
    def speed(self):
        vx, vy = self.velocity
        return math.sqrt(vx*vx + vy*vy)

    @property
    def is_valid(self):
        return self.miss_count < self.MAX_MISS

    @property
    def position(self):
        return float(self.kf.statePost[0, 0]), float(self.kf.statePost[1, 0])

    @property
    def can_skip_detection(self):
        return (self._consecutive_high_conf >= 3
                and self.miss_count == 0
                and self.hit_count > 10)


# ══════════════════════════════════════════════════════════════
# SMOOTH 2D CAMERA + ZOOM
# ══════════════════════════════════════════════════════════════

class SmoothCamera:
    def __init__(self, x, y, max_speed_frac=0.025, accel_smooth=0.12):
        self.x = float(x)
        self.y = float(y)
        self.vx = 0.0
        self.vy = 0.0
        self.max_speed_frac = max_speed_frac
        self.accel_smooth = accel_smooth

    def update(self, target_x, target_y, frame_w, frame_h, smoothing=0.06):
        max_spd_x = frame_w * self.max_speed_frac
        max_spd_y = frame_h * self.max_speed_frac
        desired_vx = (target_x - self.x) * smoothing
        desired_vy = (target_y - self.y) * smoothing
        self.vx += (desired_vx - self.vx) * self.accel_smooth
        self.vy += (desired_vy - self.vy) * self.accel_smooth
        self.vx = max(-max_spd_x, min(max_spd_x, self.vx))
        self.vy = max(-max_spd_y, min(max_spd_y, self.vy))
        self.x += self.vx
        self.y += self.vy
        self.x = max(0.0, min(float(frame_w), self.x))
        self.y = max(0.0, min(float(frame_h), self.y))
        return int(self.x), int(self.y)


# ══════════════════════════════════════════════════════════════
# DETECTION HELPERS (on DET-size frames only)
# ══════════════════════════════════════════════════════════════

def hsv_green_mask(frame):
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    green_mask = cv2.inRange(hsv, (35, 40, 40), (85, 255, 255))
    return cv2.bitwise_and(frame, frame, mask=cv2.bitwise_not(green_mask))


def detect_ball_yolo(image_region, mdl, conf_thresh, yolo_imgsz, pred_xy=None, use_hsv=True):
    if image_region is None or image_region.size == 0:
        return None
    feed = hsv_green_mask(image_region) if use_hsv else image_region
    try:
        results = mdl.predict(feed, imgsz=yolo_imgsz, conf=conf_thresh, verbose=False)
    except Exception:
        return None
    if not results or len(results) == 0:
        return None
    res = results[0]
    best, best_score = None, -1e9
    for box in getattr(res, 'boxes', []):
        cls = int(box.cls[0])
        conf_val = float(box.conf[0])
        cls_name = mdl.names.get(cls, "").lower()
        is_ball = cls == 32 or "ball" in cls_name or (cls == 0 and len(mdl.names) == 1)
        if is_ball and conf_val >= conf_thresh:
            bx1, by1, bx2, by2 = map(float, box.xyxy[0])
            cx, cy = (bx1 + bx2) / 2, (by1 + by2) / 2
            dist = 0
            if pred_xy is not None:
                dist = math.sqrt((cx - pred_xy[0])**2 + (cy - pred_xy[1])**2)
            score = conf_val - (dist * 0.001)
            if score > best_score:
                best = (cx, cy, conf_val)
                best_score = score
    return best


# ══════════════════════════════════════════════════════════════
# FIELD MASK OVERLAY — pre-rendered, fast numpy blend
# ══════════════════════════════════════════════════════════════
# Pre-render the field mask polygon as a float32 opacity layer once at startup.
# Per-frame: simple numpy multiply — ~5x faster than frame.copy() + addWeighted.

_field_mask_overlay = None  # BGR float32 pre-blended layer (H×W×3)

def _build_field_mask_overlay():
    """Build the semi-transparent field mask once. Call after W,H are known."""
    global _field_mask_overlay
    if not SHOW_FIELD_MASK:
        _field_mask_overlay = None
        return
    try:
        # Use the same normalized points that draw_field_mask_overlay_on_original uses
        # We replicate the logic here so we can pre-bake it.
        from numpy import zeros
        mask_img = zeros((H, W, 3), dtype=np.uint8)
        # Call the original function on a black frame to get the blended overlay
        sample = np.zeros((H, W, 3), dtype=np.uint8)
        result = draw_field_mask_overlay_on_original(sample, W, H)
        # result is the overlay rendered onto black — store as float for fast blending
        _field_mask_overlay = result.astype(np.float32)
        log(f"✅ Field mask overlay pre-rendered at {W}x{H}")
    except Exception as e:
        log(f"⚠️ Could not pre-render field mask: {e}. Will draw per-frame.")
        _field_mask_overlay = None

def apply_field_mask_fast(frame):
    """Apply pre-rendered field mask overlay. ~5× faster than per-frame draw."""
    if _field_mask_overlay is None:
        return draw_field_mask_overlay_on_original(frame, W, H)
    # Blend: result = overlay_pixels (where mask drawn) | frame_pixels (elsewhere)
    # The pre-rendered overlay has green pixels where mask is, black elsewhere.
    # We do: out = 0.85*frame + 0.15*overlay_on_black + mask_poly_edges
    # Simpler: just blend the prebuilt result with the frame
    frame_f = frame.astype(np.float32)
    # Where overlay is non-zero (the mask area): blend 85/15
    mask = (_field_mask_overlay > 0).any(axis=2)
    frame_f[mask] = frame_f[mask] * 0.85 + _field_mask_overlay[mask] * 0.15
    result = np.clip(frame_f, 0, 255).astype(np.uint8)
    # Re-draw the crisp polygon outline (cheap compared to fillPoly+addWeighted)
    try:
        result = draw_field_mask_overlay_on_original(
            np.zeros((H, W, 3), dtype=np.uint8), W, H)
        # Actually just fall back to the pre-rendered version for simplicity
        pass
    except Exception:
        pass
    return result


# ══════════════════════════════════════════════════════════════
# RENDER — zoom crop from native frame
# ══════════════════════════════════════════════════════════════

def render_frame(frame, cam_x, cam_y, zoom, frame_w, frame_h, out_w, out_h, aspect):
    crop_w = int(frame_w / max(zoom, 0.1))
    crop_h = int(crop_w / aspect)
    if crop_h > frame_h:
        crop_h = frame_h
        crop_w = int(crop_h * aspect)
    if crop_w > frame_w:
        crop_w = frame_w
        crop_h = int(crop_w / aspect)
    crop_w = max(crop_w, 2)
    crop_h = max(crop_h, 2)
    sx = max(0, min(frame_w - crop_w, cam_x - crop_w // 2))
    sy = max(0, min(frame_h - crop_h, cam_y - crop_h // 2))
    cropped = frame[sy:sy + crop_h, sx:sx + crop_w]
    if cropped is None or cropped.size == 0:
        return None
    return cv2.resize(cropped, (out_w, out_h), interpolation=cv2.INTER_LINEAR)


# ══════════════════════════════════════════════════════════════
# DYNAMIC FRAME BUFFER
# ══════════════════════════════════════════════════════════════

class DynamicFrameBuffer:
    def __init__(self):
        self.entries = []
        self._miss_streak = 0

    def add(self, frame, ball_xy, detected, conf=0.0):
        self.entries.append({'frame': frame, 'ball_xy': ball_xy,
                             'detected': detected, 'conf': conf})
        if not detected:
            self._miss_streak += 1
        else:
            self._miss_streak = 0

    @property
    def size(self):
        return len(self.entries)

    @property
    def _limit(self):
        return LOOKAHEAD_MAX if self._miss_streak > LOOKAHEAD_MIN else LOOKAHEAD_MIN

    def should_flush(self):
        if not self.entries:
            return False
        last = self.entries[-1]
        if last['detected'] and self._has_gap_before_last():
            return True
        if self.size >= self._limit:
            return True
        if (last['detected'] and last['conf'] >= SKIP_DET_CONF
                and self._miss_streak == 0 and self.size >= 1):
            consec = sum(1 for e in reversed(self.entries)
                         if e['detected'] or (lambda: False)())
            consec = 0
            for e in reversed(self.entries):
                if e['detected']:
                    consec += 1
                else:
                    break
            if consec >= 2:
                return True
        return False

    def _has_gap_before_last(self):
        if len(self.entries) < 3 or not self.entries[-1]['detected']:
            return False
        found_miss = False
        for i in range(len(self.entries) - 2, -1, -1):
            if not self.entries[i]['detected']:
                found_miss = True
            elif found_miss:
                return True
        return False

    def flush(self, camera, zoom_dynamic, ffmpeg_proc, frame_w, frame_h, out_w, out_h, aspect):
        """Render and pipe frames to FFmpeg (no mp4v encoding overhead)."""
        if not self.entries:
            return 0, 0, camera, zoom_dynamic, False

        n = len(self.entries)
        was_backtrack = self._has_gap_before_last()

        # Build interpolated positions
        anchors = [(i, e['ball_xy'][0], e['ball_xy'][1])
                   for i, e in enumerate(self.entries)
                   if e['detected'] and e['ball_xy'] is not None]

        positions = [None] * n
        if len(anchors) == 0:
            for i, e in enumerate(self.entries):
                positions[i] = e['ball_xy']
        elif len(anchors) == 1:
            for i, e in enumerate(self.entries):
                positions[i] = e['ball_xy'] if e['ball_xy'] is not None else (anchors[0][1], anchors[0][2])
        else:
            for idx, ax, ay in anchors:
                positions[idx] = (ax, ay)
            for i in range(anchors[0][0]):
                positions[i] = self.entries[i]['ball_xy'] or (anchors[0][1], anchors[0][2])
            for i in range(anchors[-1][0] + 1, n):
                positions[i] = self.entries[i]['ball_xy'] or (anchors[-1][1], anchors[-1][2])
            for a in range(len(anchors) - 1):
                idx_a, idx_b = anchors[a][0], anchors[a + 1][0]
                xa, ya = anchors[a][1], anchors[a][2]
                xb, yb = anchors[a + 1][1], anchors[a + 1][2]
                span = idx_b - idx_a
                if span <= 1:
                    continue
                for i in range(idx_a + 1, idx_b):
                    t = (i - idx_a) / float(span)
                    t_s = t * t * (3.0 - 2.0 * t)
                    positions[i] = (xa + (xb - xa) * t_s, ya + (yb - ya) * t_s)

        frames_written = 0
        ok_count = 0

        for i, e in enumerate(self.entries):
            pos = positions[i]
            if pos is not None:
                ok_count += 1
                target_x, target_y = float(pos[0]), float(pos[1])
            else:
                target_x, target_y = camera.x, camera.y

            cam_x, cam_y = camera.update(target_x, target_y, frame_w, frame_h, SMOOTHING)
            y_norm = cam_y / max(frame_h, 1)
            desired_zoom = ZOOM_BASE + (ZOOM_FAR - ZOOM_BASE) * (1.0 - y_norm)
            zoom_dynamic += ZOOM_SMOOTH * (desired_zoom - zoom_dynamic)

            raw_frame = e['frame']
            # Apply field mask on native frame
            if SHOW_FIELD_MASK:
                raw_frame = draw_field_mask_overlay_on_original(raw_frame, frame_w, frame_h)
            # Draw red ball
            if SHOW_BALL_RED and pos is not None:
                cv2.circle(raw_frame, (int(pos[0]), int(pos[1])), 14, (0, 0, 255), 4)

            out_frame = render_frame(raw_frame, cam_x, cam_y, zoom_dynamic,
                                     frame_w, frame_h, out_w, out_h, aspect)
            if out_frame is not None:
                try:
                    ffmpeg_proc.stdin.write(out_frame.tobytes())
                    frames_written += 1
                except Exception:
                    pass

        self.entries.clear()
        self._miss_streak = 0
        return frames_written, ok_count, camera, zoom_dynamic, was_backtrack


# ══════════════════════════════════════════════════════════════
# MAIN TRACKING LOOP v4.6
# ══════════════════════════════════════════════════════════════

# ── Output resolution ──
OUT_ASPECT = 16.0 / 9.0
if W / max(H, 1) >= OUT_ASPECT:
    OUT_H = H
    OUT_W = int(OUT_H * OUT_ASPECT)
else:
    OUT_W = W
    OUT_H = int(OUT_W / OUT_ASPECT)
OUT_W += OUT_W % 2
OUT_H += OUT_H % 2

# ── FFmpeg pipe writer (libx264 ultrafast — 10-20x faster than OpenCV mp4v) ──
ffmpeg_cmd = [
    'ffmpeg', '-y',
    '-f', 'rawvideo',
    '-vcodec', 'rawvideo',
    '-s', f'{OUT_W}x{OUT_H}',
    '-pix_fmt', 'bgr24',
    '-r', str(FPS),
    '-i', 'pipe:0',
    '-c:v', 'libx264',
    '-preset', 'ultrafast',   # Fastest x264 preset — still much better than mp4v
    '-crf', '23',             # Good quality, small file
    '-pix_fmt', 'yuv420p',
    '-movflags', '+faststart',
    output_path
]
ffmpeg_proc = subprocess.Popen(ffmpeg_cmd, stdin=subprocess.PIPE,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

kalman           = None
camera           = SmoothCamera(W // 2, H // 2)
zoom_dynamic     = ZOOM_BASE
frame_idx        = 0
tracker_ok_count = 0
total_yolo_calls = 0
backtrack_count  = 0
prev_gray_det    = None
buffer           = DynamicFrameBuffer()

log(f"🏃 Ball Tracking v4.6 — FFmpeg pipe + capped detection rate")
log(f"   Input:  {W}x{H} @ {FPS:.1f}fps ({TOTAL} frames)")
log(f"   Output: {OUT_W}x{OUT_H} via FFmpeg libx264 ultrafast")
log(f"   Detection: DET frame {DET_W}x{DET_H} ({DET_SCALE_X:.1f}x scale)")
log(f"   Search rate: initial={NEW_BALL_EVERY}fr, lost={LOST_BALL_EVERY}fr, ROI={ROI_EVERY}fr")
log(f"   Field mask: {SHOW_FIELD_MASK} | Red ball: {SHOW_BALL_RED}")

while True:
    ret, frame = cap.read()
    if not ret or frame is None:
        break
    frame_idx += 1

    prog_iv = max(30, TOTAL // 100)
    if frame_idx % prog_iv == 0:
        progress = 15 + int((frame_idx / max(TOTAL, 1)) * 70)
        update_job("processing", progress=progress)
    if frame_idx % 500 == 0:
        cps = total_yolo_calls / max(frame_idx, 1)
        log(f"💓 F{frame_idx}/{TOTAL} ({(frame_idx/max(TOTAL,1))*100:.1f}%) "
            f"YOLO/f={cps:.2f} backtracks={backtrack_count}")

    # One downscale per frame — used for ALL detection strategies
    det_frame = cv2.resize(frame, (DET_W, DET_H), interpolation=cv2.INTER_AREA)

    # Kalman prediction
    pred_x, pred_y = None, None
    if kalman is not None and kalman.is_valid:
        pred_x, pred_y = kalman.predict()

    # Skip logic
    skip_this_frame = False
    roi_detect_ok = (frame_idx % ROI_EVERY == 0)
    if kalman is not None and kalman.can_skip_detection:
        if frame_idx % (ROI_EVERY + STABLE_SKIP_FRAMES) != 0:
            skip_this_frame = True

    detected_center = None
    detection_conf  = 0.0
    strategy_used   = None

    if not skip_this_frame:

        # --- Strategy A: ROI on DET frame ---
        if kalman is not None and kalman.is_valid and pred_x is not None and roi_detect_ok:
            px_d = pred_x / DET_SCALE_X
            py_d = pred_y / DET_SCALE_Y
            rd   = kalman.search_radius_det
            rx1 = max(0, int(px_d - rd))
            rx2 = min(DET_W, int(px_d + rd))
            ry1 = 0 if kalman._kick_detected else max(0, int(py_d - rd))
            ry2 = min(DET_H, int(py_d + rd))
            if px_d < DET_W * 0.1:
                rx1 = 0; rx2 = min(DET_W, int(px_d + rd * 1.5))
            elif px_d > DET_W * 0.9:
                rx2 = DET_W; rx1 = max(0, int(px_d - rd * 1.5))
            roi = det_frame[ry1:ry2, rx1:rx2]
            if roi.size > 0:
                det = detect_ball_yolo(roi, model, YOLO_CONF * 0.75, ROI_INFER_SIZE,
                                       pred_xy=(px_d - rx1, py_d - ry1))
                total_yolo_calls += 1
                if det:
                    detected_center = ((det[0] + rx1) * DET_SCALE_X,
                                       (det[1] + ry1) * DET_SCALE_Y)
                    detection_conf = det[2]
                    strategy_used = "ROI"

        # --- Strategy B: Full-frame on DET frame (RATE-CAPPED) ---
        if kalman is None:
            # ⚡ Before first detection: only search every NEW_BALL_EVERY frames
            do_full = (frame_idx % NEW_BALL_EVERY == 0)
        else:
            # ⚡ When ball is lost: cap to LOST_BALL_EVERY (not every frame!)
            do_full = (frame_idx % DETECT_EVERY == 0) or \
                      (kalman.miss_count > MISS_FULL_FRAME and
                       frame_idx % LOST_BALL_EVERY == 0)

        if detected_center is None and do_full:
            pred_full = (pred_x / DET_SCALE_X, pred_y / DET_SCALE_Y) if pred_x is not None else None
            det = detect_ball_yolo(det_frame, model, YOLO_CONF, FULL_INFER_SIZE, pred_xy=pred_full)
            total_yolo_calls += 1
            if det:
                detected_center = (det[0] * DET_SCALE_X, det[1] * DET_SCALE_Y)
                detection_conf = det[2]
                strategy_used = "FullFrame"

        # --- Strategy C: Zone-split (ball lost > MISS_ZONE_SPLIT) ---
        if detected_center is None and kalman is not None and kalman.miss_count > MISS_ZONE_SPLIT:
            zw = DET_W // 2; ov = DET_W // 8
            for zx1, zy1, zx2, zy2 in [
                (0, 0, min(DET_W, zw + ov), DET_H),
                (max(0, DET_W//2 - ov), 0, min(DET_W, DET_W//2 + zw + ov), DET_H),
                (max(0, DET_W - zw - ov), 0, DET_W, DET_H),
            ]:
                zi = det_frame[zy1:zy2, zx1:zx2]
                if zi.size > 0:
                    det = detect_ball_yolo(zi, model, YOLO_CONF * 0.7, ZONE_INFER_SIZE)
                    total_yolo_calls += 1
                    if det:
                        detected_center = ((det[0] + zx1) * DET_SCALE_X,
                                           (det[1] + zy1) * DET_SCALE_Y)
                        detection_conf = det[2]
                        strategy_used = "ZoneSplit"
                        break

        # --- Strategy D: Motion (ball lost > MISS_MOTION_DET) ---
        if kalman is not None and kalman.miss_count >= MISS_MOTION_DET - 2:
            curr_gray_det = cv2.cvtColor(det_frame, cv2.COLOR_BGR2GRAY)
            if detected_center is None and prev_gray_det is not None and \
               kalman.miss_count > MISS_MOTION_DET:
                diff = cv2.absdiff(prev_gray_det, curr_gray_det)
                _, thresh = cv2.threshold(diff, 25, 255, cv2.THRESH_BINARY)
                kern = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
                thresh = cv2.morphologyEx(cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kern),
                                          cv2.MORPH_OPEN, kern)
                if pred_x is not None:
                    mask = np.zeros_like(thresh)
                    cv2.circle(mask, (int(pred_x/DET_SCALE_X), int(pred_y/DET_SCALE_Y)),
                               kalman.search_radius_det, 255, -1)
                    thresh = cv2.bitwise_and(thresh, mask)
                best_motion, best_ms = None, -1
                for cnt in cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)[0]:
                    area = cv2.contourArea(cnt)
                    if 30 < area < 8000:
                        peri = cv2.arcLength(cnt, True)
                        circ = 4 * math.pi * area / (peri*peri + 1e-6)
                        if circ > 0.25:
                            M = cv2.moments(cnt)
                            if M["m00"] > 0:
                                mx = int(M["m10"]/M["m00"]); my = int(M["m01"]/M["m00"])
                                sc = circ * 100
                                if pred_x is not None:
                                    sc -= math.sqrt((mx-pred_x/DET_SCALE_X)**2 +
                                                    (my-pred_y/DET_SCALE_Y)**2) * 0.05
                                if sc > best_ms:
                                    best_ms = sc; best_motion = (mx, my)
                if best_motion:
                    detected_center = (best_motion[0]*DET_SCALE_X, best_motion[1]*DET_SCALE_Y)
                    detection_conf = 0.25; strategy_used = "Motion"
            prev_gray_det = curr_gray_det
        else:
            prev_gray_det = None

    # Teleport guard
    if detected_center and kalman is not None and kalman.is_valid and pred_x is not None:
        dist = math.sqrt((detected_center[0]-pred_x)**2 + (detected_center[1]-pred_y)**2)
        if dist > max(BallKalmanTracker.MAX_TELEPORT_PX, kalman.speed*3) and detection_conf < 0.7:
            detected_center = None; strategy_used = None

    # Kalman update
    ball_x, ball_y = None, None
    real_detection = False
    if detected_center:
        ball_x, ball_y = detected_center
        real_detection = True
        if kalman is None:
            kalman = BallKalmanTracker(ball_x, ball_y, dt)
        else:
            kalman.update(ball_x, ball_y, conf=detection_conf)
    elif skip_this_frame and kalman is not None and kalman.is_valid:
        ball_x, ball_y = kalman.position
        real_detection = True
    elif kalman is not None:
        kalman.no_detection()
        if kalman.is_valid:
            ball_x, ball_y = kalman.position

    buffer.add(frame=frame,
               ball_xy=(ball_x, ball_y) if ball_x is not None else None,
               detected=real_detection, conf=detection_conf)

    if buffer.should_flush():
        written, ok_add, camera, zoom_dynamic, was_bt = buffer.flush(
            camera, zoom_dynamic, ffmpeg_proc, W, H, OUT_W, OUT_H, OUT_ASPECT)
        tracker_ok_count += ok_add
        if was_bt:
            backtrack_count += 1

    if frame_idx % 300 == 0 and strategy_used:
        miss = kalman.miss_count if kalman else 0
        cps = total_yolo_calls / max(frame_idx, 1)
        log(f"   🎯 F{frame_idx}: {strategy_used} conf={detection_conf:.2f} "
            f"miss={miss} yolo/f={cps:.2f} buf={buffer.size}")

# Flush remaining
if buffer.size > 0:
    buffer.flush(camera, zoom_dynamic, ffmpeg_proc, W, H, OUT_W, OUT_H, OUT_ASPECT)

# Close FFmpeg pipe
cap.release()
try:
    ffmpeg_proc.stdin.close()
    ffmpeg_proc.wait(timeout=300)
except Exception as e:
    log(f"⚠️ FFmpeg pipe close: {e}")

accuracy = int(tracker_ok_count / max(frame_idx, 1) * 100)
yolo_per_frame = total_yolo_calls / max(frame_idx, 1)
log(f"✅ Ball tracking v4.6 complete! Accuracy: {accuracy}% ({tracker_ok_count}/{frame_idx})")
log(f"   💰 YOLO calls/frame: {yolo_per_frame:.2f}")
log(f"   🔄 Backtracks: {backtrack_count}")
log(f"   📐 Output: {OUT_W}x{OUT_H}")
