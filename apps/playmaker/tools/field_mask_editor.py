#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════════════════════
🎯 PLAYMAKER FIELD MASK EDITOR
═══════════════════════════════════════════════════════════════════════════════

Interactive tool to define field boundaries for ball tracking.
Click points on the video frame to create a polygon mask.

USAGE:
    python3 field_mask_editor.py <video_path_or_url>
    python3 field_mask_editor.py ./my_video.mp4
    python3 field_mask_editor.py "https://..."

CONTROLS:
    - LEFT CLICK: Add a point
    - RIGHT CLICK: Remove last point
    - ENTER: Finish and save
    - ESC: Cancel
    - R: Reset all points
    - S: Save current mask
    - P: Preview mask overlay

═══════════════════════════════════════════════════════════════════════════════
"""

import cv2
import numpy as np
import sys
import os
import urllib.request
import tempfile
from datetime import datetime

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

WINDOW_NAME = "🎯 Playmaker Field Mask Editor"
POINT_COLOR = (0, 255, 0)       # Green points
LINE_COLOR = (0, 200, 255)      # Orange lines
MASK_COLOR = (0, 255, 0)        # Green mask overlay
POINT_RADIUS = 8
LINE_THICKNESS = 2

# ═══════════════════════════════════════════════════════════════════════════════
# GLOBAL STATE
# ═══════════════════════════════════════════════════════════════════════════════

points = []
frame = None
original_frame = None
preview_mode = False

# ═══════════════════════════════════════════════════════════════════════════════
# MOUSE CALLBACK
# ═══════════════════════════════════════════════════════════════════════════════

def mouse_callback(event, x, y, flags, param):
    global points, frame, original_frame
    
    if event == cv2.EVENT_LBUTTONDOWN:
        # Add point
        points.append((x, y))
        print(f"✅ Point {len(points)}: ({x}, {y})")
        update_display()
        
    elif event == cv2.EVENT_RBUTTONDOWN:
        # Remove last point
        if points:
            removed = points.pop()
            print(f"❌ Removed point: {removed}")
            update_display()

# ═══════════════════════════════════════════════════════════════════════════════
# DISPLAY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def update_display():
    global frame, original_frame, points, preview_mode
    
    frame = original_frame.copy()
    h, w = frame.shape[:2]
    
    # Draw preview mask if enabled
    if preview_mode and len(points) >= 3:
        mask = np.zeros((h, w), dtype=np.uint8)
        pts = np.array(points, dtype=np.int32)
        cv2.fillPoly(mask, [pts], 255)
        
        # Create green overlay
        overlay = frame.copy()
        overlay[mask > 0] = (overlay[mask > 0] * 0.5 + np.array([0, 128, 0]) * 0.5).astype(np.uint8)
        frame = overlay
    
    # Draw polygon lines
    if len(points) >= 2:
        for i in range(len(points) - 1):
            cv2.line(frame, points[i], points[i + 1], LINE_COLOR, LINE_THICKNESS)
        # Close polygon
        if len(points) >= 3:
            cv2.line(frame, points[-1], points[0], LINE_COLOR, LINE_THICKNESS)
    
    # Draw points with numbers
    for i, (px, py) in enumerate(points):
        cv2.circle(frame, (px, py), POINT_RADIUS, POINT_COLOR, -1)
        cv2.circle(frame, (px, py), POINT_RADIUS, (255, 255, 255), 2)
        cv2.putText(frame, str(i + 1), (px + 10, py - 10), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 2)
    
    # Draw instructions
    instructions = [
        "LEFT CLICK: Add point | RIGHT CLICK: Remove last",
        "R: Reset | P: Preview mask | S: Save | ENTER: Finish | ESC: Cancel",
        f"Points: {len(points)} | Preview: {'ON' if preview_mode else 'OFF'}"
    ]
    
    y_offset = 30
    for text in instructions:
        cv2.putText(frame, text, (10, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                    0.6, (255, 255, 255), 2)
        cv2.putText(frame, text, (10, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                    0.6, (0, 0, 0), 1)
        y_offset += 25
    
    cv2.imshow(WINDOW_NAME, frame)

# ═══════════════════════════════════════════════════════════════════════════════
# SAVE FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def generate_normalized_points(points, width, height):
    """Convert pixel coordinates to normalized 0-1 coordinates."""
    normalized = []
    for (x, y) in points:
        nx = round(x / width, 4)
        ny = round(y / height, 4)
        normalized.append((nx, ny))
    return normalized

def save_mask_config(points, width, height, output_path="field_mask_config.py"):
    """Save the mask configuration to a Python file."""
    
    normalized = generate_normalized_points(points, width, height)
    
    # Format for Python code
    points_str = "[\n"
    for i, (nx, ny) in enumerate(normalized):
        points_str += f"            [{nx:.4f}, {ny:.4f}]"
        if i < len(normalized) - 1:
            points_str += ","
        points_str += "\n"
    points_str += "        ]"
    
    # Generate the config file
    config = f'''#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════════════════════
🎯 PLAYMAKER FIELD MASK CONFIGURATION
═══════════════════════════════════════════════════════════════════════════════

Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
Original resolution: {width}x{height}
Points: {len(points)}

To use this in chunk_processor.py, replace the FIELD_MASK_POINTS_NORMALIZED array.

═══════════════════════════════════════════════════════════════════════════════
"""

import numpy as np

# Normalized field mask coordinates (0-1 range)
# These coordinates define the polygon boundary of the playing field
FIELD_MASK_POINTS_NORMALIZED = np.array({points_str}, dtype=np.float32)

# ═══════════════════════════════════════════════════════════════════════════════
# COPY THE ARRAY ABOVE INTO chunk_processor.py
# Replace the existing FIELD_MASK_POINTS_NORMALIZED array around line 232
# ═══════════════════════════════════════════════════════════════════════════════

# Usage example:
def create_field_mask(w, h):
    """Create a binary mask from normalized points."""
    points = FIELD_MASK_POINTS_NORMALIZED.copy()
    points[:, 0] *= w
    points[:, 1] *= h
    
    import cv2
    mask = np.zeros((h, w), dtype=np.uint8)
    cv2.fillPoly(mask, [points.astype(np.int32)], 255)
    return mask

def is_in_field(x, y, mask):
    """Check if a point is inside the field."""
    h, w = mask.shape
    x, y = max(0, min(int(x), w-1)), max(0, min(int(y), h-1))
    return mask[y, x] > 0

if __name__ == "__main__":
    print("Field Mask Configuration")
    print(f"Points: {{len(FIELD_MASK_POINTS_NORMALIZED)}}")
    print("\\nNormalized coordinates:")
    for i, (x, y) in enumerate(FIELD_MASK_POINTS_NORMALIZED):
        print(f"  Point {{i+1}}: ({{x:.4f}}, {{y:.4f}})")
'''
    
    with open(output_path, 'w') as f:
        f.write(config)
    
    print(f"\n✅ Configuration saved to: {output_path}")
    return normalized

def print_for_chunk_processor(points, width, height):
    """Print the points in a format ready to paste into chunk_processor.py"""
    
    normalized = generate_normalized_points(points, width, height)
    
    print("\n" + "═" * 70)
    print("📋 COPY THIS INTO modal_gpu_function/chunk_processor.py")
    print("   Replace FIELD_MASK_POINTS_NORMALIZED around line 232")
    print("═" * 70 + "\n")
    
    print("        FIELD_MASK_POINTS_NORMALIZED = np.array([")
    for i, (nx, ny) in enumerate(normalized):
        comma = "," if i < len(normalized) - 1 else ""
        print(f"            [{nx:.4f}, {ny:.4f}]{comma}")
    print("        ], dtype=np.float32)")
    
    print("\n" + "═" * 70 + "\n")

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    global frame, original_frame, points, preview_mode
    
    if len(sys.argv) < 2:
        print(__doc__)
        print("ERROR: Please provide a video path or URL")
        print("\nUsage: python3 field_mask_editor.py <video_path_or_url>")
        sys.exit(1)
    
    video_source = sys.argv[1]
    
    # Handle URL or local file
    if video_source.startswith('http'):
        print(f"🌐 Downloading video from URL...")
        temp_file = tempfile.NamedTemporaryFile(suffix='.mp4', delete=False)
        try:
            urllib.request.urlretrieve(video_source, temp_file.name)
            video_path = temp_file.name
            print(f"✅ Downloaded to: {video_path}")
        except Exception as e:
            print(f"❌ Failed to download: {e}")
            sys.exit(1)
    else:
        video_path = video_source
    
    if not os.path.exists(video_path):
        print(f"❌ File not found: {video_path}")
        sys.exit(1)
    
    # Open video and get first frame
    print(f"📹 Opening video: {video_path}")
    cap = cv2.VideoCapture(video_path)
    
    if not cap.isOpened():
        print("❌ Failed to open video")
        sys.exit(1)
    
    ret, original_frame = cap.read()
    cap.release()
    
    if not ret:
        print("❌ Failed to read video frame")
        sys.exit(1)
    
    h, w = original_frame.shape[:2]
    print(f"📐 Video resolution: {w}x{h}")
    
    # Setup window
    cv2.namedWindow(WINDOW_NAME, cv2.WINDOW_NORMAL)
    cv2.resizeWindow(WINDOW_NAME, min(1600, w), min(900, h))
    cv2.setMouseCallback(WINDOW_NAME, mouse_callback)
    
    print("\n" + "═" * 50)
    print("🎯 FIELD MASK EDITOR - CONTROLS")
    print("═" * 50)
    print("  LEFT CLICK   : Add point")
    print("  RIGHT CLICK  : Remove last point")
    print("  R            : Reset all points")
    print("  P            : Toggle preview mode")
    print("  S            : Save configuration")
    print("  ENTER        : Finish and save")
    print("  ESC          : Cancel")
    print("═" * 50 + "\n")
    print("👆 Click points around the FIELD BOUNDARIES")
    print("   Start from one corner and go clockwise or counter-clockwise")
    print("")
    
    update_display()
    
    while True:
        key = cv2.waitKey(1) & 0xFF
        
        if key == 27:  # ESC
            print("❌ Cancelled")
            break
            
        elif key == 13 or key == 10:  # ENTER
            if len(points) >= 3:
                print_for_chunk_processor(points, w, h)
                save_mask_config(points, w, h)
                print("✅ Done! Copy the array above into chunk_processor.py")
            else:
                print("⚠️ Need at least 3 points to create a mask")
            break
            
        elif key == ord('r') or key == ord('R'):
            points = []
            print("🔄 Reset all points")
            update_display()
            
        elif key == ord('p') or key == ord('P'):
            preview_mode = not preview_mode
            print(f"👁️ Preview mode: {'ON' if preview_mode else 'OFF'}")
            update_display()
            
        elif key == ord('s') or key == ord('S'):
            if len(points) >= 3:
                print_for_chunk_processor(points, w, h)
                save_mask_config(points, w, h)
            else:
                print("⚠️ Need at least 3 points to save")
    
    cv2.destroyAllWindows()
    
    # Cleanup temp file if downloaded
    if video_source.startswith('http') and 'temp_file' in dir():
        try:
            os.unlink(temp_file.name)
        except:
            pass

if __name__ == "__main__":
    main()
