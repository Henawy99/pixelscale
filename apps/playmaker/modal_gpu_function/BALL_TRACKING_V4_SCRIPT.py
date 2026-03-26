# ==============================================================================
# BALL TRACKING v4.0 - BROADCAST QUALITY & COST OPTIMIZED
# ==============================================================================
# - Red dot and field mask overlays are now toggleable.
# - Optimized detection size (960px) for $0.60-$0.80/hr cost range.
# - Improved Kalman filter and camera smoothing.
# ==============================================================================

import numpy as np
import cv2
import time
import os

# Configurable Overlays (Can be injected via globals)
SHOW_RED_BALL = globals().get('SHOW_RED_BALL', True)
SHOW_FIELD_MASK = globals().get('SHOW_FIELD_MASK', True)

# OPTIMIZATION: Balanced size (960) provides excellent accuracy at ~1.7x speed of 1280
DETECTION_SIZE = 960
DETECTION_CONF = 0.12
CROP_RATIO = 0.45
KALMAN_MEMORY = 60
GLOW_RADIUS = 20
GLOW_ALPHA = 0.25

# ==============================================================================
# FIELD MASK (Injected or Default)
# ==============================================================================
DEFAULT_FIELD_MASK = np.array([
    [0.7094, 0.3214], [0.9169, 0.6337], [0.7619, 0.8321], [0.4965, 0.8303],
    [0.2582, 0.8277], [0.1916, 0.8337], [0.0512, 0.6403], [0.2682, 0.3280],
    [0.3480, 0.2944], [0.4433, 0.2690], [0.4935, 0.2659], [0.5407, 0.2677],
    [0.6075, 0.2809], [0.6570, 0.2975],
], dtype=np.float32)

FIELD_MASK_POINTS = globals().get('_injected_field_mask', DEFAULT_FIELD_MASK)
if isinstance(FIELD_MASK_POINTS, list):
    FIELD_MASK_POINTS = np.array(FIELD_MASK_POINTS, dtype=np.float32)

# Global W, H are provided by chunk_processor
# Create binary mask for filtering detections
field_mask_img = np.zeros((H, W), dtype=np.uint8)
scaled_pts = FIELD_MASK_POINTS.copy()
scaled_pts[:, 0] *= W
scaled_pts[:, 1] *= H
cv2.fillPoly(field_mask_img, [scaled_pts.astype(np.int32)], 255)

def is_in_field(x, y):
    ix, iy = max(0, min(int(x)), W - 1)), max(0, min(int(y), H - 1))
    return field_mask_img[iy, ix] > 0

# ==============================================================================
# UTILITIES
# ==============================================================================
def draw_overlays(frame, bx, by, camera_x, full_w, full_h):
    # 1. Draw Field Mask (if enabled)
    if SHOW_FIELD_MASK:
        overlay = frame.copy()
        pts = FIELD_MASK_POINTS.copy()
        pts[:, 0] = pts[:, 0] * full_w - (camera_x - (full_w * CROP_RATIO / 2))
        pts[:, 1] = pts[:, 1] * full_h
        cv2.fillPoly(overlay, [pts.astype(np.int32)], (0, 255, 0))
        cv2.addWeighted(overlay, 0.15, frame, 0.85, 0, frame)
        cv2.polylines(frame, [pts.astype(np.int32)], True, (0, 255, 100), 2, cv2.LINE_AA)

    # 2. Draw Red Ball (if enabled)
    if SHOW_RED_BALL and bx is not None:
        # Glow
        glow = frame.copy()
        cv2.circle(glow, (int(bx), int(by)), GLOW_RADIUS, (0, 0, 255), -1)
        cv2.addWeighted(glow, GLOW_ALPHA, frame, 1 - GLOW_ALPHA, 0, frame)
        # Core
        cv2.circle(frame, (int(bx), int(by)), 10, (0, 0, 255), -1)
        cv2.circle(frame, (int(bx), int(by)), 12, (255, 255, 255), 2, cv2.LINE_AA)
