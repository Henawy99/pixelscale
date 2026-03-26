"""
TrackNetV3 Fine-Tuning Script — Football Edition
=================================================
Fine-tunes the OFFICIAL TrackNetV3 model (from qaz812345/TrackNetV3) on custom
Roboflow COCO football annotations.

Key Features:
  - Uses the REAL TrackNetV3 architecture (UNet encoder-decoder, 8-frame input)
  - Loads official V3 pretrained weights (ckpts/TrackNet_best.pt)
  - Synthesizes 8-frame motion sequences from single annotated images
  - Weighted BCE loss to handle tiny ball vs. large background pixel imbalance
  - Outputs tracknet_football_v3.pt for production use

Run: modal run train_tracknet.py
"""
import modal
import os
import io

app = modal.App("tracknet-v3-football-finetuner")

# --- Paths ---
DATASET_PATH = "/Users/youssefelhenawy/Desktop/pixelscale/apps/playmakerstart/Soccer-Ball-Tracker.coco"
CKPTS_PATH = "/Users/youssefelhenawy/Desktop/pixelscale/apps/playmakerstart/modal_gpu_function/ckpts"

# --- Modal Image ---
image = (
    modal.Image.debian_slim(python_version="3.10")
    .pip_install(
        "torch",
        "torchvision",
        "opencv-python-headless",
        "numpy",
        "Pillow",
        "tqdm",
    )
    .add_local_dir(
        local_path=DATASET_PATH,
        remote_path="/data/soccer-coco"
    )
    .add_local_dir(
        local_path=CKPTS_PATH,
        remote_path="/root/ckpts"
    )
)


# ======================================================================
# TrackNetV3 Architecture (EXACT copy from qaz812345/TrackNetV3/model.py)
# ======================================================================
# We inline it here so Modal can serialize everything in one file.

def _build_tracknetv3_class():
    """Returns the TrackNetV3 nn.Module class. Called inside Modal container."""
    import torch
    import torch.nn as nn

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
        Input:  (B, in_dim, 288, 512)
        Output: (B, out_dim, 288, 512)  — sigmoid heatmaps
        """
        HEIGHT = 288
        WIDTH = 512

        def __init__(self, in_dim=24, out_dim=8):
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

    return TrackNetV3


# ======================================================================
# Synthetic 8-Frame Sequence Generator
# ======================================================================

def generate_synthetic_8frame_sequence(image_np, bbox, width=512, height=288):
    """
    From a single annotated image + bbox, synthesize 8 consecutive frames
    by applying smooth affine shifts, simulating ball movement.

    Returns:
        stacked_frames: np.ndarray (8*3, H, W) = (24, 288, 512) normalized
        centers: list of 8 (cx, cy) tuples in model-space coordinates
    """
    import cv2
    import numpy as np
    import math

    orig_h, orig_w = image_np.shape[:2]
    bx, by, bw, bh = bbox
    ball_cx = bx + bw / 2.0
    ball_cy = by + bh / 2.0

    # Generate a smooth trajectory with 8 points
    # Random direction and speed for realistic ball motion
    speed = np.random.uniform(5, 25)  # pixels per frame
    angle = np.random.uniform(0, 2 * math.pi)
    # Add slight curve (acceleration/spin)
    angle_delta = np.random.uniform(-0.15, 0.15)

    offsets = []
    cum_dx, cum_dy = 0.0, 0.0
    for i in range(8):
        # Frame t=3 is the "original" position, others are shifted
        t = i - 3  # so frame 3 = original, frames 0-2 = before, 4-7 = after
        cur_angle = angle + angle_delta * t
        cum_dx = speed * t * math.cos(cur_angle)
        cum_dy = speed * t * math.sin(cur_angle)
        offsets.append((cum_dx, cum_dy))

    frames_list = []
    centers_list = []
    scale_x = width / orig_w
    scale_y = height / orig_h

    for dx, dy in offsets:
        # Shift the entire image by -dx, -dy (ball appears to move by +dx, +dy)
        M = np.float32([[1, 0, -dx], [0, 1, -dy]])
        shifted = cv2.warpAffine(image_np, M, (orig_w, orig_h),
                                 borderMode=cv2.BORDER_REPLICATE)
        # Resize to model input size
        resized = cv2.resize(shifted, (width, height))
        rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
        normalized = rgb.astype(np.float32) / 255.0
        chw = normalized.transpose(2, 0, 1)  # (3, H, W)
        frames_list.append(chw)

        # Ball center in model coordinates (ball stays at same image pos,
        # but image shifts, so effective ball pos = original + offset)
        cx_model = (ball_cx + dx) * scale_x
        cy_model = (ball_cy + dy) * scale_y
        centers_list.append((cx_model, cy_model))

    # Stack: (24, H, W) = 8 frames × 3 channels
    stacked = np.concatenate(frames_list, axis=0)
    return stacked, centers_list


def generate_heatmap(cx, cy, width=512, height=288, sigma=2.5):
    """Generate a 2D Gaussian heatmap. Returns (H, W) float32 array."""
    import numpy as np

    if cx < 0 or cx >= width or cy < 0 or cy >= height:
        return np.zeros((height, width), dtype=np.float32)

    X = np.arange(0, width, 1, dtype=np.float32)
    Y = np.arange(0, height, 1, dtype=np.float32)[:, np.newaxis]

    heatmap = np.exp(-((X - cx)**2 + (Y - cy)**2) / (2 * sigma**2))
    return heatmap


# ======================================================================
# PyTorch Dataset
# ======================================================================

def _build_dataset_class():
    """Returns the Dataset class. Called inside Modal container."""
    import os
    import json
    import numpy as np
    import cv2
    import torch
    from torch.utils.data import Dataset

    class FootballTrackNetDataset(Dataset):
        """
        Reads COCO annotations, generates synthetic 8-frame sequences
        with corresponding 8-channel heatmap targets.
        """
        def __init__(self, coco_dir, width=512, height=288, augment_factor=5):
            self.coco_dir = coco_dir
            self.width = width
            self.height = height
            self.augment_factor = augment_factor  # generate N sequences per image

            annot_file = os.path.join(coco_dir, "_annotations.coco.json")
            with open(annot_file, 'r') as f:
                coco = json.load(f)

            # Build image_id → annotations mapping
            self.img_to_anns = {}
            for ann in coco['annotations']:
                img_id = ann['image_id']
                if img_id not in self.img_to_anns:
                    self.img_to_anns[img_id] = []
                self.img_to_anns[img_id].append(ann)

            # Only use images that have annotations
            self.images = [img for img in coco['images'] if img['id'] in self.img_to_anns]
            print(f"[Dataset] {len(self.images)} images with annotations, "
                  f"×{augment_factor} augmentation = {len(self)} total samples")

        def __len__(self):
            return len(self.images) * self.augment_factor

        def __getitem__(self, idx):
            # Which base image
            img_idx = idx % len(self.images)
            img_info = self.images[img_idx]
            img_path = os.path.join(self.coco_dir, img_info['file_name'])

            image_np = cv2.imread(img_path)
            if image_np is None:
                raise ValueError(f"Cannot read {img_path}")

            # Get the first ball annotation
            anns = self.img_to_anns[img_info['id']]
            bbox = anns[0]['bbox']  # [x, y, w, h] in COCO format

            # Generate synthetic 8-frame sequence (each call is random)
            stacked_frames, centers = generate_synthetic_8frame_sequence(
                image_np, bbox, self.width, self.height
            )

            # Generate 8 heatmaps (one per frame)
            heatmaps = []
            for cx, cy in centers:
                hm = generate_heatmap(cx, cy, self.width, self.height, sigma=2.5)
                heatmaps.append(hm)

            stacked_heatmaps = np.stack(heatmaps, axis=0)  # (8, H, W)

            return (
                torch.from_numpy(stacked_frames).float(),    # (24, 288, 512)
                torch.from_numpy(stacked_heatmaps).float()   # (8, 288, 512)
            )

    return FootballTrackNetDataset


# ======================================================================
# Weighted BCE Loss (from TrackNetV3 official: utils/metric.py)
# ======================================================================

def WBCELoss(y_pred, y_true):
    """
    Weighted Binary Cross Entropy — exact formula from TrackNetV3 paper.
    Heavily penalizes missing the ball (false negatives).
    """
    import torch

    eps = 1e-7
    y_pred = torch.clamp(y_pred, eps, 1.0 - eps)

    # Count positive and negative pixels
    num_pos = torch.sum(y_true).item() + 1  # avoid div by zero
    num_neg = torch.sum(1.0 - y_true).item() + 1
    total = num_pos + num_neg

    # Weights: inverse frequency
    w_pos = total / (2.0 * num_pos)
    w_neg = total / (2.0 * num_neg)

    loss = - w_pos * y_true * torch.log(y_pred) \
           - w_neg * (1.0 - y_true) * torch.log(1.0 - y_pred)

    return torch.mean(loss)


# ======================================================================
# Modal Training Function
# ======================================================================

@app.function(
    image=image,
    gpu="A10G",
    timeout=7200,  # 2 hours
)
def train():
    import torch
    import torch.optim as optim
    from torch.utils.data import DataLoader
    import numpy as np

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"🚀 Device: {device}")
    print(f"🔥 TrackNetV3 Football Fine-Tuning — STARTING")

    # ── 1. Build Model ──
    TrackNetV3 = _build_tracknetv3_class()
    # Default V3: in_dim=8*3=24 (8 RGB frames), out_dim=8 (8 heatmaps)
    model = TrackNetV3(in_dim=24, out_dim=8).to(device)

    total_params = sum(p.numel() for p in model.parameters())
    print(f"📐 Model parameters: {total_params:,}")

    # ── 2. Load Pretrained V3 Weights ──
    ckpt_path = "/root/ckpts/TrackNet_best.pt"
    if os.path.exists(ckpt_path):
        print(f"📦 Loading official TrackNetV3 pretrained weights from {ckpt_path}...")
        ckpt = torch.load(ckpt_path, map_location=device)

        # The official checkpoint wraps state_dict inside a dict
        if isinstance(ckpt, dict) and 'model' in ckpt:
            state_dict = ckpt['model']
        elif isinstance(ckpt, dict) and 'state_dict' in ckpt:
            state_dict = ckpt['state_dict']
        else:
            state_dict = ckpt

        # Load with strict=False to handle any minor key mismatches
        loaded = model.load_state_dict(state_dict, strict=False)
        print(f"   ✅ Loaded! Missing keys: {len(loaded.missing_keys)}, "
              f"Unexpected keys: {len(loaded.unexpected_keys)}")
        if loaded.missing_keys:
            print(f"   Missing: {loaded.missing_keys[:5]}...")
        if loaded.unexpected_keys:
            print(f"   Unexpected: {loaded.unexpected_keys[:5]}...")
    else:
        print(f"⚠️ No pretrained weights at {ckpt_path}, training from scratch!")

    # ── 3. Dataset ──
    FootballDataset = _build_dataset_class()
    train_dir = "/data/soccer-coco/train"
    dataset = FootballDataset(
        coco_dir=train_dir,
        width=TrackNetV3.WIDTH,
        height=TrackNetV3.HEIGHT,
        augment_factor=10  # 488 images × 10 = 4880 samples per epoch
    )
    dataloader = DataLoader(
        dataset,
        batch_size=4,   # 8 frames × 3 ch = 24 channels per sample, need GPU RAM
        shuffle=True,
        num_workers=2,
        drop_last=True
    )

    # ── 4. Optimizer & Scheduler ──
    optimizer = optim.Adam(model.parameters(), lr=1e-4)
    scheduler = optim.lr_scheduler.StepLR(optimizer, step_size=5, gamma=0.5)

    # ── 5. Training Loop ──
    EPOCHS = 15
    model.train()
    print(f"\n{'='*60}")
    print(f"🏋️ Training for {EPOCHS} epochs on {len(dataset)} samples")
    print(f"   Batch size: 4 | LR: 1e-4 | GPU: A10G")
    print(f"{'='*60}\n")

    best_loss = float('inf')
    best_state = None

    for epoch in range(EPOCHS):
        epoch_losses = []
        for step, (frames, heatmaps) in enumerate(dataloader):
            frames = frames.to(device)      # (B, 24, 288, 512)
            heatmaps = heatmaps.to(device)  # (B, 8, 288, 512)

            optimizer.zero_grad()
            outputs = model(frames)  # (B, 8, 288, 512) — sigmoid output

            loss = WBCELoss(outputs, heatmaps)
            loss.backward()
            optimizer.step()

            epoch_losses.append(loss.item())

            if step % 50 == 0:
                print(f"  Epoch [{epoch+1}/{EPOCHS}] Step [{step}/{len(dataloader)}] "
                      f"Loss: {loss.item():.6f}")

        avg_loss = np.mean(epoch_losses)
        scheduler.step()
        current_lr = optimizer.param_groups[0]['lr']

        print(f"\n📊 Epoch {epoch+1}/{EPOCHS} — Avg Loss: {avg_loss:.6f} | LR: {current_lr:.2e}")

        # Track best
        if avg_loss < best_loss:
            best_loss = avg_loss
            best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
            print(f"   🏆 New best! Loss: {best_loss:.6f}")

        print()

    print(f"\n{'='*60}")
    print(f"✅ TRAINING COMPLETE! Best loss: {best_loss:.6f}")
    print(f"{'='*60}")

    # ── 6. Save Best Weights ──
    buffer = io.BytesIO()
    # Save in the same format as official TrackNetV3
    torch.save({
        'model': best_state,
        'param_dict': {
            'model_name': 'TrackNet',
            'seq_len': 8,
            'bg_mode': '',
            'fine_tuned_on': 'football',
            'best_loss': best_loss
        }
    }, buffer)

    return buffer.getvalue()


# ======================================================================
# Local Entrypoint — receives weights back from Modal
# ======================================================================

@app.local_entrypoint()
def main():
    print("🚀 Submitting TrackNetV3 football fine-tuning job to Modal GPU...")
    print("   This will take ~30-60 minutes on an A10G GPU.")
    print()

    weights_bytes = train.remote()

    out_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "tracknet_football_v3.pt"
    )
    with open(out_path, "wb") as f:
        f.write(weights_bytes)

    print(f"\n🎉 Saved football-trained TrackNetV3 weights to:")
    print(f"   {out_path}")
    print(f"   Size: {len(weights_bytes) / 1024 / 1024:.1f} MB")
    print()
    print("Next steps:")
    print("  1. Update ball_tracking_processor.py to load tracknet_football_v3.pt")
    print("  2. Deploy to Modal: modal deploy ball_tracking_processor.py")
    print("  3. Test with a football video!")
