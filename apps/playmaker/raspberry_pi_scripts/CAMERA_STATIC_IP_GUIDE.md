# Camera Static IP & Fan Setup Guide

## Quick Summary

### 1. Fan Not Spinning?

**If it's a simple 2-wire DC fan (red & black wires):**
Connect directly to power - no software needed:
```
Pin 4 (5V)  → RED wire
Pin 6 (GND) → BLACK wire
```
Fan should spin immediately when Pi is powered on.

**If it's a PWM/GPIO controlled fan:**
SSH into your Pi and run:
```bash
# Add to /boot/config.txt (or /boot/firmware/config.txt on newer Pi OS)
sudo nano /boot/config.txt

# Add this line at the end:
dtoverlay=gpio-fan,gpiopin=14,temp=55000

# Save and reboot
sudo reboot
```

---

### 2. Camera Static IP (MOST IMPORTANT)

Since you're moving the setup to the field, **configure the camera with a static IP** so it won't change when connected to a new router.

#### Step-by-Step for Reolink Camera:

1. **Find current camera IP:**
   ```bash
   # On your Raspberry Pi
   sudo nmap -sn 192.168.1.0/24
   # or check your router's connected devices
   ```

2. **Access camera web interface:**
   - Open browser: `http://CAMERA_CURRENT_IP`
   - Login (usually admin/admin)

3. **Set Static IP:**
   - Go to: **Settings → Network → Network General**
   - Change **Network Type** from `DHCP` to `Static`
   - Set:
     ```
     IP Address: 192.168.1.100
     Subnet Mask: 255.255.255.0
     Default Gateway: 192.168.1.1
     Primary DNS: 8.8.8.8
     ```
   - Click **Save**

4. **Update your recording script:**
   ```bash
   # Edit your .env file
   nano /home/pi/.env
   
   # Change CAMERA_IP to:
   CAMERA_IP=192.168.1.100
   ```

---

### 3. Recommended Network Setup for Field

```
┌─────────────────────────────────────────────────┐
│                  FIELD SETUP                     │
├─────────────────────────────────────────────────┤
│                                                  │
│   📡 Mobile Router (4G/5G)                      │
│   └── IP: 192.168.1.1                           │
│       │                                          │
│       ├── 📷 Camera (STATIC IP)                 │
│       │   └── IP: 192.168.1.100                 │
│       │                                          │
│       └── 🍓 Raspberry Pi (Tailscale)           │
│           └── Local: 192.168.1.x (DHCP OK)      │
│           └── Tailscale: 100.x.x.x (remote)    │
│                                                  │
└─────────────────────────────────────────────────┘
```

**Key Points:**
- Camera: **STATIC IP** (always 192.168.1.100)
- Raspberry Pi: DHCP is fine (you access via Tailscale anyway)
- Router: Acts as gateway at 192.168.1.1

---

### 4. Verify Camera Connection

After setting static IP, test from Raspberry Pi:
```bash
# Ping camera
ping 192.168.1.100

# Test RTSP stream
ffprobe rtsp://admin:YOUR_PASSWORD@192.168.1.100:554/h264Preview_01_main
```

---

### 5. Update Recording Script

Make sure your recording script uses the static IP:

```bash
# Edit your environment file
nano /home/pi/.env

# Ensure these values:
CAMERA_IP=192.168.1.100
CAMERA_USERNAME=admin
CAMERA_PASSWORD=your_password
```

---

### 6. Reliability Tips for Field Deployment

```bash
# Enable watchdog (auto-reboot if Pi hangs)
sudo nano /boot/config.txt
# Add: dtparam=watchdog=on

# Monitor temperature
watch -n 1 vcgencmd measure_temp

# Check disk space (recordings can fill up!)
df -h

# Auto-cleanup old recordings (add to crontab)
crontab -e
# Add: 0 4 * * * find /home/pi/recordings -mtime +7 -delete
```

---

## Quick Commands Reference

```bash
# SSH to your Pi via Tailscale
ssh pi@YOUR_TAILSCALE_IP

# Check temperature
vcgencmd measure_temp

# Check if camera is reachable
ping 192.168.1.100

# Test camera stream
ffprobe rtsp://admin:password@192.168.1.100:554/h264Preview_01_main

# Check recording script status
systemctl status camera_recorder

# View logs
journalctl -u camera_recorder -f

# Reboot Pi
sudo reboot
```
