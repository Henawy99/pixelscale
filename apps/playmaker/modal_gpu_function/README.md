# ⚽ Ball Tracking GPU Function (Modal.com)

This directory contains the Modal.com serverless GPU function for processing football match videos with YOLO ball tracking.

## 🚀 Quick Start

```bash
# 1. Install Modal CLI
pip install modal

# 2. Authenticate
modal token new

# 3. Add Supabase secrets
modal secret create supabase-credentials \
  SUPABASE_URL="https://your-project.supabase.co" \
  SUPABASE_SERVICE_KEY="your-service-role-key"

# 4. Deploy
./deploy.sh
```

## 📁 Files

- `ball_tracking_processor.py` - Main Modal function with YOLO tracking
- `requirements.txt` - Python dependencies
- `deploy.sh` - Quick deployment script
- `README.md` - This file

## 💰 Cost

- **GPU:** NVIDIA A10G (~$0.30/hour)
- **Billing:** Per-second, scales to zero when idle
- **Example:** 1-minute video = ~$0.03

## 🔧 Configuration

Edit `script_config` in the webhook payload to customize:

```json
{
  "zoom_base": 1.75,
  "zoom_far": 2.1,
  "smoothing": 0.07,
  "detect_every_frames": 2,
  "yolo_conf": 0.35,
  "yolo_model": "yolov8l",
  "yolo_img_size": 960
}
```

## 📊 What It Does

1. Downloads video from Supabase Storage
2. Loads YOLO model (cached across runs)
3. Detects ball using YOLOv8
4. Tracks ball with OpenCV trackers + Kalman filter
5. Applies dynamic zoom and smooth camera
6. Uploads processed video to Supabase Storage
7. Updates job with metrics (accuracy, cost, time)

## 🐛 Debugging

```bash
# View logs
modal app logs ball-tracking-processor

# List deployed apps
modal app list

# Redeploy
modal deploy ball_tracking_processor.py
```

## 📖 Full Documentation

See `../BALL_TRACKING_SETUP.md` for complete setup guide.







