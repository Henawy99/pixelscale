"""
TrackNetV2 — Ball Detection via Multi-Frame Heatmap Prediction
==============================================================
Exact architecture from ChgygLin/TrackNetV2-pytorch to ensure weight compatibility.

VGG16 encoder + UNet decoder. Takes 3 consecutive frames (9ch) → outputs 3
heatmaps (one per frame) where the peak = ball position.

Pre-trained weights: https://github.com/ChgygLin/TrackNetV2-pytorch/releases/download/v0.1/last.pt

Architecture:  ~10.3M params
Input:         3 × RGB frames concatenated → (B, 9, 288, 512)
Output:        3 heatmaps (B, 3, 288, 512) — one per input frame

Usage:
    model = TrackNet()
    model.load_state_dict(torch.load("tracknetv2.pt", map_location="cpu"))
    model.eval()
    heatmap = predict_from_frames(model, frame1, frame2, frame3, device)
    found, x, y = get_shuttle_position(heatmap)
"""

import torch
import torch.nn as nn
import numpy as np


# ── Architecture (exact match to ChgygLin/TrackNetV2-pytorch) ──

class Conv(nn.Module):
    """Conv2d + ReLU + BatchNorm (matches ChgygLin's order)."""
    def __init__(self, ic, oc, k=(3, 3), p="same", act=True):
        super().__init__()
        self.conv = nn.Conv2d(ic, oc, kernel_size=k, padding=p)
        self.bn = nn.BatchNorm2d(oc)
        self.act = nn.ReLU() if act else nn.Identity()

    def forward(self, x):
        return self.bn(self.act(self.conv(x)))


class TrackNet(nn.Module):
    """TrackNetV2: VGG16 encoder + UNet decoder.
    Input:  (B, 9, H, W)  — 3 consecutive RGB frames concatenated
    Output: (B, 3, H, W)  — 3 heatmaps (one per input frame)
    """
    
    INPUT_H = 288
    INPUT_W = 512

    def __init__(self):
        super().__init__()
        # ── VGG16 Encoder ──
        self.conv2d_1 = Conv(9, 64)
        self.conv2d_2 = Conv(64, 64)
        self.max_pooling_1 = nn.MaxPool2d((2, 2), stride=(2, 2))

        self.conv2d_3 = Conv(64, 128)
        self.conv2d_4 = Conv(128, 128)
        self.max_pooling_2 = nn.MaxPool2d((2, 2), stride=(2, 2))

        self.conv2d_5 = Conv(128, 256)
        self.conv2d_6 = Conv(256, 256)
        self.conv2d_7 = Conv(256, 256)
        self.max_pooling_3 = nn.MaxPool2d((2, 2), stride=(2, 2))

        self.conv2d_8 = Conv(256, 512)
        self.conv2d_9 = Conv(512, 512)
        self.conv2d_10 = Conv(512, 512)

        # ── UNet Decoder ──
        self.up_sampling_1 = nn.UpsamplingNearest2d(scale_factor=2)
        self.conv2d_11 = Conv(768, 256)   # 512 upsampled + 256 skip = 768
        self.conv2d_12 = Conv(256, 256)
        self.conv2d_13 = Conv(256, 256)

        self.up_sampling_2 = nn.UpsamplingNearest2d(scale_factor=2)
        self.conv2d_14 = Conv(384, 128)   # 256 upsampled + 128 skip = 384
        self.conv2d_15 = Conv(128, 128)

        self.up_sampling_3 = nn.UpsamplingNearest2d(scale_factor=2)
        self.conv2d_16 = Conv(192, 64)    # 128 upsampled + 64 skip = 192
        self.conv2d_17 = Conv(64, 64)
        self.conv2d_18 = nn.Conv2d(64, 3, kernel_size=(1, 1), padding='same')

    def forward(self, x):
        # Encoder
        x = self.conv2d_1(x)
        x1 = self.conv2d_2(x)
        x = self.max_pooling_1(x1)

        x = self.conv2d_3(x)
        x2 = self.conv2d_4(x)
        x = self.max_pooling_2(x2)

        x = self.conv2d_5(x)
        x = self.conv2d_6(x)
        x3 = self.conv2d_7(x)
        x = self.max_pooling_3(x3)

        x = self.conv2d_8(x)
        x = self.conv2d_9(x)
        x = self.conv2d_10(x)

        # Decoder with skip connections
        x = self.up_sampling_1(x)
        x = torch.concat([x, x3], dim=1)
        x = self.conv2d_11(x)
        x = self.conv2d_12(x)
        x = self.conv2d_13(x)

        x = self.up_sampling_2(x)
        x = torch.concat([x, x2], dim=1)
        x = self.conv2d_14(x)
        x = self.conv2d_15(x)

        x = self.up_sampling_3(x)
        x = torch.concat([x, x1], dim=1)
        x = self.conv2d_16(x)
        x = self.conv2d_17(x)
        x = self.conv2d_18(x)

        return torch.sigmoid(x)


# ── Utility functions ──

def preprocess_frames(frame1, frame2, frame3, target_w=512, target_h=288):
    """Convert 3 OpenCV BGR frames → model input tensor (1, 9, 288, 512)."""
    import cv2
    frames = []
    for f in [frame1, frame2, frame3]:
        f_rgb = cv2.cvtColor(f, cv2.COLOR_BGR2RGB)
        f_resized = cv2.resize(f_rgb, (target_w, target_h))
        f_norm = f_resized.astype(np.float32) / 255.0
        frames.append(f_norm.transpose(2, 0, 1))  # (3, H, W)

    stacked = np.concatenate(frames, axis=0)  # (9, H, W)
    return torch.from_numpy(stacked).unsqueeze(0)  # (1, 9, 288, 512)


@torch.no_grad()
def predict_from_frames(model, frame1, frame2, frame3, device='cuda'):
    """Run inference on 3 consecutive frames.
    Returns heatmap for the LAST frame as numpy (288, 512)."""
    inp = preprocess_frames(frame1, frame2, frame3,
                            target_w=TrackNet.INPUT_W,
                            target_h=TrackNet.INPUT_H).to(device)
    output = model(inp)  # (1, 3, 288, 512)
    # Use the last channel (frame t) — most relevant for ball position
    heatmap = output[0, 2].cpu().numpy()  # (288, 512), values 0-1
    return heatmap


def get_shuttle_position(heatmap, orig_w, orig_h, threshold=0.5):
    """Extract ball (x, y) in original frame coordinates from heatmap.
    Uses contour-based extraction (matches ChgygLin's approach).
    Returns (found, x, y, confidence)."""
    import cv2

    # Convert to uint8
    heatmap_uint8 = (heatmap * 255).astype(np.uint8)

    # Threshold
    _, thresh = cv2.threshold(heatmap_uint8, int(threshold * 255), 255, cv2.THRESH_BINARY)

    # Find contours
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    if len(contours) > 0:
        largest = max(contours, key=cv2.contourArea)
        M = cv2.moments(largest)
        if M['m00'] > 0:
            cx = int(M['m10'] / M['m00'])
            cy = int(M['m01'] / M['m00'])
            confidence = float(heatmap[cy, cx]) if 0 <= cy < heatmap.shape[0] and 0 <= cx < heatmap.shape[1] else 0.5

            # Scale to original resolution
            scale_x = orig_w / TrackNet.INPUT_W
            scale_y = orig_h / TrackNet.INPUT_H
            orig_x = cx * scale_x
            orig_y = cy * scale_y

            return True, orig_x, orig_y, confidence

    return False, 0, 0, 0.0
