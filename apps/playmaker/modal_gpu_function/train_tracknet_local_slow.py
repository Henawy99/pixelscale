"""
TrackNetV3 Fine-Tuning — LOCAL MacBook Pro Edition 🍎
=====================================================
Trains TrackNetV3 on your football annotations LOCALLY using Apple MPS (Metal GPU).
No cloud, no upload, no waiting!

Run:
  python3 train_tracknet_local_slow.py

Output:
  tracknet_football_v3.pt — your custom football-trained weights
"""
import os
import io
import sys
import json
import math
import time

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import cv2
import numpy as np

# ======================================================================
# Paths — EDIT THESE IF NEEDED
# ======================================================================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), "Soccer-Ball-Tracker.coco", "train")
CKPT_PATH = os.path.join(SCRIPT_DIR, "ckpts", "TrackNet_best.pt")
OUTPUT_PATH = os.path.join(SCRIPT_DIR, "tracknet_football_v3.pt")

# ======================================================================
# TrackNetV3 Architecture (EXACT copy from qaz812345/TrackNetV3/model.py)
# ======================================================================

class Conv2DBlock(nn.Module):
    """Conv2D + BN + ReLU"""
    def __init__(self, in_dim, out_dim):
        super().__init__()
        self.conv = nn.Conv2d(in_dim, out_dim, kernel_size=3, padding='same', bias=False)
        self.bn = nn.BatchNorm2d(out_dim)
        self.relu = nn.ReLU()
    def forward(self, x):
        return self.relu(self.bn(self.conv(x)))

class Double2DConv(nn.Module):
    """Conv2DBlock × 2"""
    def __init__(self, in_dim, out_dim):
        super().__init__()
        self.conv_1 = Conv2DBlock(in_dim, out_dim)
        self.conv_2 = Conv2DBlock(out_dim, out_dim)
    def forward(self, x):
        return self.conv_2(self.conv_1(x))

class Triple2DConv(nn.Module):
    """Conv2DBlock × 3"""
    def __init__(self, in_dim, out_dim):
        super().__init__()
        self.conv_1 = Conv2DBlock(in_dim, out_dim)
        self.conv_2 = Conv2DBlock(out_dim, out_dim)
        self.conv_3 = Conv2DBlock(out_dim, out_dim)
    def forward(self, x):
        return self.conv_3(self.conv_2(self.conv_1(x)))

class TrackNetV3(nn.Module):
    """
    Official TrackNetV3 UNet architecture.
    Input:  (B, in_dim, 288, 512) — bg(3) + 8 RGB frames(24) = 27ch
    Output: (B, out_dim, 288, 512) — 8 heatmaps (one per frame)
    """
    HEIGHT = 288
    WIDTH = 512

    def __init__(self, in_dim=27, out_dim=8):
        super().__init__()
        self.down_block_1 = Double2DConv(in_dim, 64)
        self.down_block_2 = Double2DConv(64, 128)
        self.down_block_3 = Triple2DConv(128, 256)
        self.bottleneck   = Triple2DConv(256, 512)
        self.up_block_1   = Triple2DConv(768, 256)
        self.up_block_2   = Double2DConv(384, 128)
        self.up_block_3   = Double2DConv(192, 64)
        self.predictor    = nn.Conv2d(64, out_dim, (1, 1))
        self.sigmoid      = nn.Sigmoid()

    def forward(self, x):
        x1 = self.down_block_1(x)
        x = nn.MaxPool2d((2,2), stride=(2,2))(x1)
        x2 = self.down_block_2(x)
        x = nn.MaxPool2d((2,2), stride=(2,2))(x2)
        x3 = self.down_block_3(x)
        x = nn.MaxPool2d((2,2), stride=(2,2))(x3)
        x = self.bottleneck(x)
        x = torch.cat([nn.Upsample(scale_factor=2)(x), x3], dim=1)
        x = self.up_block_1(x)
        x = torch.cat([nn.Upsample(scale_factor=2)(x), x2], dim=1)
        x = self.up_block_2(x)
        x = torch.cat([nn.Upsample(scale_factor=2)(x), x1], dim=1)
        x = self.up_block_3(x)
        x = self.predictor(x)
        x = self.sigmoid(x)
        return x


# ======================================================================
# Synthetic 8-Frame Sequence Generator
# ======================================================================

def generate_synthetic_8frame_sequence(image_np, bbox, width=512, height=288):
    """
    From a single annotated image + bbox, synthesize 8 consecutive frames
    by applying smooth affine shifts, simulating realistic ball movement.
    """
    orig_h, orig_w = image_np.shape[:2]
    bx, by, bw, bh = bbox
    ball_cx = bx + bw / 2.0
    ball_cy = by + bh / 2.0

    # Random direction, speed, and slight curve
    speed = np.random.uniform(5, 25)
    angle = np.random.uniform(0, 2 * math.pi)
    angle_delta = np.random.uniform(-0.15, 0.15)

    scale_x = width / orig_w
    scale_y = height / orig_h
    frames_list = []
    centers_list = []

    # Generate the 8 shifted frames
    raw_frames = []
    for i in range(8):
        t = i - 3  # frame 3 = original position
        cur_angle = angle + angle_delta * t
        dx = speed * t * math.cos(cur_angle)
        dy = speed * t * math.sin(cur_angle)

        M = np.float32([[1, 0, -dx], [0, 1, -dy]])
        shifted = cv2.warpAffine(image_np, M, (orig_w, orig_h),
                                 borderMode=cv2.BORDER_REPLICATE)
        resized = cv2.resize(shifted, (width, height))
        rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
        normalized = rgb.astype(np.float32) / 255.0
        chw = normalized.transpose(2, 0, 1)  # (3, H, W)
        frames_list.append(chw)
        raw_frames.append(resized)  # Keep BGR resized for median

        cx_model = (ball_cx + dx) * scale_x
        cy_model = (ball_cy + dy) * scale_y
        centers_list.append((cx_model, cy_model))

    # Create background frame (median of all frames) — this is what TrackNetV3
    # uses with bg_mode='concat': prepend the background as first 3 channels
    median_bg = np.median(np.array(raw_frames), axis=0).astype(np.uint8)
    median_rgb = cv2.cvtColor(median_bg, cv2.COLOR_BGR2RGB)
    median_norm = median_rgb.astype(np.float32) / 255.0
    median_chw = median_norm.transpose(2, 0, 1)  # (3, H, W)

    # Stack: background(3) + 8 frames(24) = 27 channels
    stacked = np.concatenate([median_chw] + frames_list, axis=0)  # (27, H, W)
    return stacked, centers_list


def generate_heatmap(cx, cy, width=512, height=288, sigma=2.5):
    """Generate a 2D Gaussian heatmap."""
    if cx < 0 or cx >= width or cy < 0 or cy >= height:
        return np.zeros((height, width), dtype=np.float32)
    X = np.arange(0, width, 1, dtype=np.float32)
    Y = np.arange(0, height, 1, dtype=np.float32)[:, np.newaxis]
    heatmap = np.exp(-((X - cx)**2 + (Y - cy)**2) / (2 * sigma**2))
    return heatmap


# ======================================================================
# Dataset
# ======================================================================

class FootballTrackNetDataset(Dataset):
    def __init__(self, coco_dir, width=512, height=288, augment_factor=10):
        self.coco_dir = coco_dir
        self.width = width
        self.height = height
        self.augment_factor = augment_factor

        annot_file = os.path.join(coco_dir, "_annotations.coco.json")
        with open(annot_file, 'r') as f:
            coco = json.load(f)

        self.img_to_anns = {}
        for ann in coco['annotations']:
            img_id = ann['image_id']
            if img_id not in self.img_to_anns:
                self.img_to_anns[img_id] = []
            self.img_to_anns[img_id].append(ann)

        self.images = [img for img in coco['images'] if img['id'] in self.img_to_anns]
        print(f"📸 {len(self.images)} annotated images × {augment_factor} augmentation = {len(self)} samples/epoch")

    def __len__(self):
        return len(self.images) * self.augment_factor

    def __getitem__(self, idx):
        img_idx = idx % len(self.images)
        img_info = self.images[img_idx]
        img_path = os.path.join(self.coco_dir, img_info['file_name'])

        image_np = cv2.imread(img_path)
        if image_np is None:
            raise ValueError(f"Cannot read {img_path}")

        bbox = [float(v) for v in self.img_to_anns[img_info['id']][0]['bbox']]

        stacked_frames, centers = generate_synthetic_8frame_sequence(
            image_np, bbox, self.width, self.height
        )

        heatmaps = []
        for cx, cy in centers:
            hm = generate_heatmap(cx, cy, self.width, self.height, sigma=2.5)
            heatmaps.append(hm)

        stacked_heatmaps = np.stack(heatmaps, axis=0)

        return (
            torch.from_numpy(stacked_frames).float(),
            torch.from_numpy(stacked_heatmaps).float()
        )


# ======================================================================
# Weighted BCE Loss (from TrackNetV3 paper)
# ======================================================================

def WBCELoss(y_pred, y_true):
    """Weighted BCE — heavily penalizes missing the ball."""
    eps = 1e-7
    y_pred = torch.clamp(y_pred, eps, 1.0 - eps)
    num_pos = torch.sum(y_true).item() + 1
    num_neg = torch.sum(1.0 - y_true).item() + 1
    total = num_pos + num_neg
    w_pos = total / (2.0 * num_pos)
    w_neg = total / (2.0 * num_neg)
    loss = - w_pos * y_true * torch.log(y_pred) \
           - w_neg * (1.0 - y_true) * torch.log(1.0 - y_pred)
    return torch.mean(loss)


# ======================================================================
# Main Training
# ======================================================================

def main():
    print("=" * 60)
    print("⚽ TrackNetV3 Football Fine-Tuning — LOCAL MacBook Pro")
    print("=" * 60)

    # --- Device Selection ---
    if torch.backends.mps.is_available():
        device = torch.device("mps")
        print(f"🍎 Using Apple Metal (MPS) GPU — FAST!")
    elif torch.cuda.is_available():
        device = torch.device("cuda")
        print(f"🟢 Using NVIDIA CUDA GPU")
    else:
        device = torch.device("cpu")
        print(f"⚠️ Using CPU — this will be slow!")

    # --- Verify Paths ---
    print(f"\n📂 Dataset: {DATASET_DIR}")
    print(f"📦 Pretrained weights: {CKPT_PATH}")
    print(f"💾 Output: {OUTPUT_PATH}")

    if not os.path.exists(DATASET_DIR):
        print(f"\n❌ ERROR: Dataset not found at {DATASET_DIR}")
        sys.exit(1)

    # --- Build Model ---
    print(f"\n🧠 Building TrackNetV3 (8-frame + bg_concat, 27ch → 8 heatmaps)...")
    model = TrackNetV3(in_dim=27, out_dim=8).to(device)
    total_params = sum(p.numel() for p in model.parameters())
    print(f"   Parameters: {total_params:,}")

    # --- Load Pretrained Weights ---
    if os.path.exists(CKPT_PATH):
        print(f"\n📦 Loading official TrackNetV3 pretrained weights...")
        ckpt = torch.load(CKPT_PATH, map_location='cpu', weights_only=False)

        if isinstance(ckpt, dict) and 'model' in ckpt:
            state_dict = ckpt['model']
        elif isinstance(ckpt, dict) and 'state_dict' in ckpt:
            state_dict = ckpt['state_dict']
        else:
            state_dict = ckpt

        loaded = model.load_state_dict(state_dict, strict=False)
        print(f"   ✅ Loaded! Missing: {len(loaded.missing_keys)}, Unexpected: {len(loaded.unexpected_keys)}")
        model = model.to(device)
    else:
        print(f"\n⚠️ No pretrained weights found, training from scratch!")

    # --- Dataset ---
    print(f"\n📊 Loading dataset...")
    dataset = FootballTrackNetDataset(
        coco_dir=DATASET_DIR,
        width=TrackNetV3.WIDTH,
        height=TrackNetV3.HEIGHT,
        augment_factor=10
    )
    dataloader = DataLoader(
        dataset,
        batch_size=2,  # Small batch for MPS memory
        shuffle=True,
        num_workers=0,  # MPS works best with 0 workers
        drop_last=True
    )

    # --- Optimizer ---
    optimizer = optim.Adam(model.parameters(), lr=1e-4)
    scheduler = optim.lr_scheduler.StepLR(optimizer, step_size=5, gamma=0.5)

    # --- Training ---
    EPOCHS = 15
    model.train()

    print(f"\n{'=' * 60}")
    print(f"🏋️ TRAINING: {EPOCHS} epochs × {len(dataset)} samples")
    print(f"   Batch: 2 | LR: 1e-4 | Device: {device}")
    print(f"{'=' * 60}\n")

    best_loss = float('inf')
    best_state = None
    start_time = time.time()

    for epoch in range(EPOCHS):
        epoch_start = time.time()
        epoch_losses = []

        for step, (frames, heatmaps) in enumerate(dataloader):
            frames = frames.to(device)
            heatmaps = heatmaps.to(device)

            optimizer.zero_grad()
            outputs = model(frames)
            loss = WBCELoss(outputs, heatmaps)
            loss.backward()
            optimizer.step()

            epoch_losses.append(loss.item())

            if step % 100 == 0:
                elapsed = time.time() - epoch_start
                print(f"  Epoch [{epoch+1}/{EPOCHS}] Step [{step}/{len(dataloader)}] "
                      f"Loss: {loss.item():.6f} ({elapsed:.0f}s)")

        avg_loss = np.mean(epoch_losses)
        scheduler.step()
        epoch_time = time.time() - epoch_start

        print(f"\n📊 Epoch {epoch+1}/{EPOCHS} — Loss: {avg_loss:.6f} | "
              f"Time: {epoch_time:.0f}s | LR: {optimizer.param_groups[0]['lr']:.2e}")

        if avg_loss < best_loss:
            best_loss = avg_loss
            best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
            print(f"   🏆 NEW BEST! Loss: {best_loss:.6f}")

        print()

    total_time = time.time() - start_time

    # --- Save ---
    print(f"{'=' * 60}")
    print(f"✅ TRAINING COMPLETE!")
    print(f"   Best loss: {best_loss:.6f}")
    print(f"   Total time: {total_time/60:.1f} min")
    print(f"{'=' * 60}")

    torch.save({
        'model': best_state,
        'param_dict': {
            'model_name': 'TrackNet',
            'seq_len': 8,
            'bg_mode': '',
            'fine_tuned_on': 'football',
            'best_loss': best_loss,
            'training_time_min': total_time / 60
        }
    }, OUTPUT_PATH)

    file_size = os.path.getsize(OUTPUT_PATH) / 1024 / 1024
    print(f"\n🎉 Saved to: {OUTPUT_PATH}")
    print(f"   Size: {file_size:.1f} MB")
    print(f"\nNext steps:")
    print(f"  1. Update ball_tracking_processor.py to load tracknet_football_v3.pt")
    print(f"  2. Deploy: modal deploy ball_tracking_processor.py")
    print(f"  3. Test with a football video! ⚽")


if __name__ == "__main__":
    main()
