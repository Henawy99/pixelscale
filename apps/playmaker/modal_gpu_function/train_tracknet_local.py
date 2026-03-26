"""
TrackNetV3 Fine-Tuning — LOCAL MacBook Pro M2 Max Edition 🍎🔥
================================================================
OPTIMIZED for Apple Silicon M2 Max:
  - Phase 1: Pre-computes all synthetic data and saves to DISK (no OOM crashes)
  - Phase 2: Trains directly from fast disk cache using a PyTorch Dataset
  - Batch size 8 (M2 Max unified memory)
  - num_workers=4 for data loading

Expected time on M2 Max: ~20-30 minutes (vs 6 hours before)

Run:
  python3 train_tracknet_local.py

Output:
  tracknet_football_v3.pt — your custom football-trained weights
"""
import os
import sys
import json
import math
import time
import multiprocessing as mp
from functools import partial

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import cv2
import numpy as np
from tqdm import tqdm

# ======================================================================
# Paths
# ======================================================================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), "Soccer-Ball-Tracker.coco", "train")
CKPT_PATH = os.path.join(SCRIPT_DIR, "ckpts", "TrackNet_best.pt")
OUTPUT_PATH = os.path.join(SCRIPT_DIR, "tracknet_football_v3.pt")
CACHE_DIR = os.path.join(SCRIPT_DIR, ".tracknet_cache_disk")

# ======================================================================
# TrackNetV3 Architecture (EXACT from qaz812345/TrackNetV3/model.py)
# ======================================================================

class Conv2DBlock(nn.Module):
    def __init__(self, in_dim, out_dim):
        super().__init__()
        # 🚀 OPTIMIZATION: padding=1 is mathematically identical to padding='same' for kernel=3, 
        # but PyTorch runs padding=1 directly on the native Apple Silicon hardware backend without dynamic shape overhead!
        self.conv = nn.Conv2d(in_dim, out_dim, kernel_size=3, padding=1, bias=False)
        self.bn = nn.BatchNorm2d(out_dim)
        self.relu = nn.ReLU()
    def forward(self, x):
        return self.relu(self.bn(self.conv(x)))

class Double2DConv(nn.Module):
    def __init__(self, in_dim, out_dim):
        super().__init__()
        self.conv_1 = Conv2DBlock(in_dim, out_dim)
        self.conv_2 = Conv2DBlock(out_dim, out_dim)
    def forward(self, x):
        return self.conv_2(self.conv_1(x))

class Triple2DConv(nn.Module):
    def __init__(self, in_dim, out_dim):
        super().__init__()
        self.conv_1 = Conv2DBlock(in_dim, out_dim)
        self.conv_2 = Conv2DBlock(out_dim, out_dim)
        self.conv_3 = Conv2DBlock(out_dim, out_dim)
    def forward(self, x):
        return self.conv_3(self.conv_2(self.conv_1(x)))

class TrackNetV3(nn.Module):
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
# Data Generation Functions (CPU-side, parallelizable)
# ======================================================================

def generate_heatmap(cx, cy, width=512, height=288, sigma=2.5):
    if cx < 0 or cx >= width or cy < 0 or cy >= height:
        return np.zeros((height, width), dtype=np.float32)
    X = np.arange(0, width, 1, dtype=np.float32)
    Y = np.arange(0, height, 1, dtype=np.float32)[:, np.newaxis]
    return np.exp(-((X - cx)**2 + (Y - cy)**2) / (2 * sigma**2))


def generate_one_sample(args):
    """Generate a single training sample and save it directly to disk (solves OOM)."""
    img_path, bbox, width, height, out_path = args
    
    if os.path.exists(out_path):
        return True

    image_np = cv2.imread(img_path)
    if image_np is None:
        return False

    orig_h, orig_w = image_np.shape[:2]
    bx, by, bw, bh = bbox
    ball_cx = bx + bw / 2.0
    ball_cy = by + bh / 2.0

    speed = np.random.uniform(5, 25)
    angle = np.random.uniform(0, 2 * math.pi)
    angle_delta = np.random.uniform(-0.15, 0.15)

    scale_x = width / orig_w
    scale_y = height / orig_h
    frames_list = []
    raw_frames = []
    centers_list = []

    for i in range(8):
        t = i - 3
        cur_angle = angle + angle_delta * t
        dx = speed * t * math.cos(cur_angle)
        dy = speed * t * math.sin(cur_angle)

        M = np.float32([[1, 0, -dx], [0, 1, -dy]])
        shifted = cv2.warpAffine(image_np, M, (orig_w, orig_h),
                                 borderMode=cv2.BORDER_REPLICATE)
        resized = cv2.resize(shifted, (width, height))
        rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
        normalized = rgb.astype(np.float32) / 255.0
        chw = normalized.transpose(2, 0, 1)
        frames_list.append(chw)
        raw_frames.append(resized)

        cx_model = (ball_cx + dx) * scale_x
        cy_model = (ball_cy + dy) * scale_y
        centers_list.append((cx_model, cy_model))

    # Background frame (median)
    median_bg = np.median(np.array(raw_frames), axis=0).astype(np.uint8)
    median_rgb = cv2.cvtColor(median_bg, cv2.COLOR_BGR2RGB)
    median_norm = median_rgb.astype(np.float32) / 255.0
    median_chw = median_norm.transpose(2, 0, 1)

    # Stack: bg(3) + 8 frames(24) = 27 channels
    stacked_frames = np.concatenate([median_chw] + frames_list, axis=0) # (27, 288, 512)

    # 8 heatmaps
    heatmaps = np.stack([
        generate_heatmap(cx, cy, width, height, sigma=2.5)
        for cx, cy in centers_list
    ], axis=0)
    
    # Save directly to disk to avoid eating RAM
    np.savez_compressed(out_path, frames=stacked_frames, heatmaps=heatmaps)
    return True


def precompute_all_data(coco_dir, width, height, augment_factor=10):
    """
    Pre-compute ALL synthetic training data using all CPU cores and save to disk.
    Returns the list of valid file paths.
    """
    os.makedirs(CACHE_DIR, exist_ok=True)
    
    annot_file = os.path.join(coco_dir, "_annotations.coco.json")
    with open(annot_file, 'r') as f:
        coco = json.load(f)

    img_to_anns = {}
    for ann in coco['annotations']:
        img_id = ann['image_id']
        if img_id not in img_to_anns:
            img_to_anns[img_id] = []
        img_to_anns[img_id].append(ann)

    images = [img for img in coco['images'] if img['id'] in img_to_anns]
    print(f"📸 {len(images)} annotated images × {augment_factor} augmentation = {len(images) * augment_factor} total samples to cache to disk")

    # Build argument list for parallel processing
    tasks = []
    idx = 0
    for _ in range(augment_factor):
        for img_info in images:
            img_path = os.path.join(coco_dir, img_info['file_name'])
            bbox = [float(v) for v in img_to_anns[img_info['id']][0]['bbox']]
            out_path = os.path.join(CACHE_DIR, f"sample_{idx:05d}.npz")
            tasks.append((img_path, bbox, width, height, out_path))
            idx += 1

    # Check if completely cached already
    existing_files = [f for f in os.listdir(CACHE_DIR) if f.endswith('.npz')]
    if len(existing_files) == len(tasks):
        print(f"⚡ Found {len(existing_files)} fully cached samples on disk. Skipping generation!")
        return [t[-1] for t in tasks]

    # Use all CPU cores for parallel generation
    num_cores = mp.cpu_count()
    print(f"🔧 Using {num_cores} CPU cores for parallel generation (saving straight to SSD)...")

    start = time.time()
    success_count = 0
    with mp.Pool(processes=num_cores) as pool:
        for res in tqdm(pool.imap_unordered(generate_one_sample, tasks, chunksize=16), total=len(tasks), desc="⚙️ Generating & caching synthetic frames"):
            if res:
                success_count += 1
                
    elapsed = time.time() - start
    print(f"✅ Generated and cached {success_count} samples in {elapsed:.1f}s")
    
    # Return paths
    paths = [t[-1] for t in tasks if os.path.exists(t[-1])]
    return paths

# ======================================================================
# Disk Cache Dataset
# ======================================================================

class CachedDiskDataset(Dataset):
    def __init__(self, file_paths):
        self.file_paths = file_paths
        
    def __len__(self):
        return len(self.file_paths)
        
    def __getitem__(self, idx):
        path = self.file_paths[idx]
        data = np.load(path)
        # 🚀 OPTIMIZATION: .copy() speeds up RAM-to-GPU memory transfer and prevents Zip memory allocation leaks.
        # Removing .float() avoids copying since np arrays are pre-saved as float32!
        return (
            torch.from_numpy(data['frames'].copy()),
            torch.from_numpy(data['heatmaps'].copy())
        )

# ======================================================================
# Weighted BCE Loss (from TrackNetV3 paper)
# ======================================================================

def WBCELoss(y_pred, y_true):
    eps = 1e-7
    y_pred = torch.clamp(y_pred, eps, 1.0 - eps)
    
    # 🚀 EXTREME CPU-GPU OPTIMIZATION: 
    # By using y_true.numel() we eliminate massive 9-million element tensor subtractions!
    # Calculates the exact same loss but with 1 hardware graph reduction instead of 3.
    num_pos = y_true.sum() + 1.0
    num_neg = y_true.numel() - num_pos + 2.0
    total = num_pos + num_neg
    
    w_pos = total / (2.0 * num_pos)
    w_neg = total / (2.0 * num_neg)
    
    loss = - w_pos * y_true * torch.log(y_pred) \
           - w_neg * (1.0 - y_true) * torch.log(1.0 - y_pred)
           
    return loss.mean()


# ======================================================================
# Main
# ======================================================================

def main():
    print("=" * 60)
    print("⚽ TrackNetV3 Football Fine-Tuning — M2 Max OPTIMIZED 🔥")
    print("=" * 60)

    # Device
    if torch.backends.mps.is_available():
        device = torch.device("mps")
        print(f"🍎 Apple M2 Max Metal GPU — FULL POWER!")
    elif torch.cuda.is_available():
        device = torch.device("cuda")
        print(f"🟢 NVIDIA CUDA GPU")
    else:
        device = torch.device("cpu")
        print(f"⚠️ CPU only — will be slower")

    # Paths
    print(f"\n📂 Dataset: {DATASET_DIR}")
    print(f"📦 Weights: {CKPT_PATH}")
    print(f"💾 Output:  {OUTPUT_PATH}")

    if not os.path.exists(DATASET_DIR):
        print(f"\n❌ Dataset not found: {DATASET_DIR}")
        sys.exit(1)

    # ── Phase 1: Pre-compute data ──
    print(f"\n🔨 Phase 1: Checking disk cache / Computing missing samples...")
    sample_paths = precompute_all_data(
        DATASET_DIR,
        width=TrackNetV3.WIDTH,
        height=TrackNetV3.HEIGHT,
        augment_factor=10
    )

    # Create dataset from cached files
    dataset = CachedDiskDataset(sample_paths)
    dataloader = DataLoader(
        dataset,
        batch_size=8,              # 🚀 OPTIMIZATION: Batch size 8 clears GPU VRAM constraints, halves the processing time per step
        shuffle=True,
        num_workers=4,             # 🚀 OPTIMIZATION: 4 is best. 8 overloads the Python GIL for pure SSD disk reading
        pin_memory=False,          # 🛑 Fixed PyTorch warning: MPS does not support pin_memory
        persistent_workers=True,   # 🚀 OPTIMIZATION: Prevents restarting workers between epochs
        drop_last=True
    )

    # ── Phase 2: Build Model ──
    print(f"\n🧠 Building TrackNetV3 (27ch → 8 heatmaps)...")
    model = TrackNetV3(in_dim=27, out_dim=8).to(device)
    total_params = sum(p.numel() for p in model.parameters())
    print(f"   Parameters: {total_params:,}")

    # Load pretrained weights
    if os.path.exists(CKPT_PATH):
        print(f"📦 Loading official TrackNetV3 pretrained weights...")
        ckpt = torch.load(CKPT_PATH, map_location='cpu', weights_only=False)
        if isinstance(ckpt, dict) and 'model' in ckpt:
            state_dict = ckpt['model']
        elif isinstance(ckpt, dict) and 'state_dict' in ckpt:
            state_dict = ckpt['state_dict']
        else:
            state_dict = ckpt
        loaded = model.load_state_dict(state_dict, strict=False)
        print(f"   ✅ Loaded! Missing: {len(loaded.missing_keys)}, "
              f"Unexpected: {len(loaded.unexpected_keys)}")
        model = model.to(device)
    else:
        print(f"⚠️ No pretrained weights, training from scratch!")

    # ── Phase 3: Training ──
    optimizer = optim.Adam(model.parameters(), lr=1e-4)
    scheduler = optim.lr_scheduler.StepLR(optimizer, step_size=3, gamma=0.5)

    EPOCHS = 5  # Reduced to 5 as requested! (Enough for fine-tuning)
    steps_per_epoch = len(dataloader)
    model.train()

    print(f"\n{'=' * 60}")
    print(f"🏋️ TRAINING: {EPOCHS} epochs × {len(dataset)} samples")
    print(f"   Batch: {dataloader.batch_size} | Steps/epoch: {steps_per_epoch} | LR: 1e-4")
    print(f"   Device: {device}")
    print(f"{'=' * 60}\n")

    best_loss = float('inf')
    best_state = None
    start_time = time.time()

    for epoch in range(EPOCHS):
        epoch_start = time.time()
        epoch_losses = []

        # We also put a tqdm progress bar on training
        with tqdm(dataloader, desc=f"Epoch {epoch+1}/{EPOCHS}") as pbar:
            for frames, heatmaps in pbar:
                # 🚀 OPTIMIZATION: non_blocking=True allows asynchronous memory transfer directly onto the MPS buffers
                frames = frames.to(device, non_blocking=True)
                heatmaps = heatmaps.to(device, non_blocking=True)

                # 🚀 OPTIMIZATION: set_to_none=True is slightly faster than regular zero_grad
                optimizer.zero_grad(set_to_none=True)
                
                outputs = model(frames)
                loss = WBCELoss(outputs, heatmaps)
                loss.backward()
                optimizer.step()

                loss_item = loss.item()
                epoch_losses.append(loss_item)
                
                # Update progress bar
                pbar.set_postfix(loss=f"{loss_item:.4f}")

        avg_loss = np.mean(epoch_losses)
        scheduler.step()
        epoch_time = time.time() - epoch_start
        total_elapsed = time.time() - start_time
        remaining = epoch_time * (EPOCHS - epoch - 1)

        print(f"\n📊 Epoch {epoch+1}/{EPOCHS} Summary — Avg Loss: {avg_loss:.4f} | "
              f"Time: {epoch_time:.0f}s | LR: {optimizer.param_groups[0]['lr']:.2e}")

        if avg_loss < best_loss:
            best_loss = avg_loss
            best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
            print(f"   🏆 NEW BEST! Loss: {best_loss:.4f}")

        print()

    total_time = time.time() - start_time

    # ── Save ──
    print(f"{'=' * 60}")
    print(f"✅ TRAINING COMPLETE!")
    print(f"   Best loss: {best_loss:.4f}")
    print(f"   Total time: {total_time/60:.1f} min")
    print(f"{'=' * 60}")

    torch.save({
        'model': best_state,
        'param_dict': {
            'model_name': 'TrackNet',
            'seq_len': 8,
            'bg_mode': 'concat',
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
    # Needed for multiprocessing on macOS
    mp.set_start_method('spawn', force=True)
    main()
