#!/bin/bash
# ============================================================
# RASPBERRY PI FAN & CAMERA STATIC IP SETUP
# ============================================================
# Run this script on your Raspberry Pi:
#   chmod +x setup_fan_and_camera_ip.sh
#   sudo ./setup_fan_and_camera_ip.sh
# ============================================================

set -e

echo "=============================================="
echo "🍓 RASPBERRY PI FAN & CAMERA IP SETUP"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================
# PART 1: FAN SETUP
# ============================================================
echo -e "${BLUE}=== PART 1: FAN SETUP ===${NC}"
echo ""

# Check current temperature
echo -e "${YELLOW}Current CPU Temperature:${NC}"
if command -v vcgencmd &> /dev/null; then
    vcgencmd measure_temp
else
    TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
    echo "temp=$((TEMP/1000))'C"
fi
echo ""

# Check what type of fan might be connected
echo -e "${YELLOW}Checking fan configuration...${NC}"

# Check if fan overlay is already in config.txt
if grep -q "gpio-fan" /boot/config.txt 2>/dev/null || grep -q "gpio-fan" /boot/firmware/config.txt 2>/dev/null; then
    echo -e "${GREEN}✓ Fan overlay already configured in config.txt${NC}"
else
    echo -e "${YELLOW}Fan overlay not found in config.txt${NC}"
fi

# Determine config.txt location (differs between Pi OS versions)
CONFIG_FILE="/boot/config.txt"
if [ -f "/boot/firmware/config.txt" ]; then
    CONFIG_FILE="/boot/firmware/config.txt"
fi

echo ""
echo -e "${BLUE}Choose your fan type:${NC}"
echo "1) PWM/GPIO controlled fan (official Raspberry Pi fan, Argon case, etc.)"
echo "2) Simple DC fan (2-wire, always on when connected to power)"
echo "3) Skip fan setup"
echo ""
read -p "Enter choice (1-3): " fan_choice

case $fan_choice in
    1)
        echo ""
        echo -e "${YELLOW}Which GPIO pin is your fan connected to?${NC}"
        echo "  - Official Pi fan: GPIO 14 (physical pin 8)"
        echo "  - Argon case: GPIO 18"
        echo "  - Check your case manual for other options"
        echo ""
        read -p "Enter GPIO pin number (default: 14): " gpio_pin
        gpio_pin=${gpio_pin:-14}
        
        echo ""
        read -p "At what temperature should the fan turn ON? (default: 55°C): " fan_temp
        fan_temp=${fan_temp:-55}
        fan_temp_milli=$((fan_temp * 1000))
        
        # Add fan overlay to config.txt
        echo ""
        echo -e "${YELLOW}Adding fan configuration to $CONFIG_FILE...${NC}"
        
        # Remove any existing fan config
        sudo sed -i '/dtoverlay=gpio-fan/d' "$CONFIG_FILE"
        
        # Add new fan config
        echo "" | sudo tee -a "$CONFIG_FILE" > /dev/null
        echo "# Raspberry Pi Fan Control - Added by setup script" | sudo tee -a "$CONFIG_FILE" > /dev/null
        echo "dtoverlay=gpio-fan,gpiopin=${gpio_pin},temp=${fan_temp_milli}" | sudo tee -a "$CONFIG_FILE" > /dev/null
        
        echo -e "${GREEN}✓ Fan configuration added!${NC}"
        echo -e "${YELLOW}Fan will turn ON when CPU reaches ${fan_temp}°C${NC}"
        FAN_CONFIGURED=true
        ;;
    2)
        echo ""
        echo -e "${BLUE}For a simple DC fan (2 wires):${NC}"
        echo ""
        echo "Connect your fan directly to these pins:"
        echo "  - RED wire  → Pin 4 (5V power)"
        echo "  - BLACK wire → Pin 6 (Ground)"
        echo ""
        echo "┌─────────────────────────────────┐"
        echo "│  Raspberry Pi GPIO Header       │"
        echo "│                                 │"
        echo "│   (1) 3.3V    ●  ● (2) 5V      │"
        echo "│   (3) GPIO2   ●  ● (4) 5V ←RED │"
        echo "│   (5) GPIO3   ●  ● (6) GND←BLK │"
        echo "│   ...                          │"
        echo "└─────────────────────────────────┘"
        echo ""
        echo -e "${YELLOW}If fan is connected correctly to 5V + GND, it should spin immediately.${NC}"
        echo -e "${YELLOW}If not spinning, check:${NC}"
        echo "  1. Wire connections are secure"
        echo "  2. Fan is not damaged"
        echo "  3. Try swapping 5V pins (Pin 2 vs Pin 4)"
        ;;
    3)
        echo "Skipping fan setup..."
        ;;
esac

# ============================================================
# PART 2: CAMERA STATIC IP SETUP
# ============================================================
echo ""
echo ""
echo -e "${BLUE}=== PART 2: CAMERA STATIC IP SETUP ===${NC}"
echo ""

echo -e "${YELLOW}You have 2 options for keeping your camera IP static:${NC}"
echo ""
echo "OPTION A: Configure static IP directly on the camera (RECOMMENDED)"
echo "OPTION B: Set up DHCP reservation on your router"
echo ""

echo -e "${BLUE}=== OPTION A: Configure Camera's Static IP ===${NC}"
echo ""
echo "Most IP cameras (Reolink, Hikvision, Dahua, etc.) have a web interface:"
echo ""
echo "1. Find the camera's current IP:"
echo "   - Check your router's connected devices"
echo "   - Or use: sudo nmap -sn 192.168.1.0/24"
echo ""
echo "2. Access camera web interface:"
echo "   - Open browser: http://CAMERA_IP"
echo "   - Login (default: admin / admin or check manual)"
echo ""
echo "3. Navigate to: Network Settings → TCP/IP or Network → Basic"
echo ""
echo "4. Change from DHCP to Static/Manual and set:"
echo "   - IP Address: 192.168.1.100 (or any unused IP)"
echo "   - Subnet Mask: 255.255.255.0"
echo "   - Gateway: 192.168.1.1 (your router IP)"
echo "   - DNS: 8.8.8.8"
echo ""
echo "5. Save and reboot camera"
echo ""

echo -e "${BLUE}=== OPTION B: Router DHCP Reservation ===${NC}"
echo ""
echo "1. Find camera's MAC address:"
echo "   - Check router's connected devices"
echo "   - Or from camera web interface"
echo ""
echo "2. In your router settings:"
echo "   - Go to DHCP settings / Address Reservation"
echo "   - Add new reservation:"
echo "     MAC: [camera's MAC address]"
echo "     IP: 192.168.1.100 (your chosen IP)"
echo ""
echo "3. Reboot router and camera"
echo ""

# ============================================================
# PART 3: CREATE CAMERA IP CONFIG HELPER
# ============================================================
echo ""
echo -e "${BLUE}=== Setting up camera IP detection ===${NC}"
echo ""

read -p "What static IP will you assign to your camera? (default: 192.168.1.100): " camera_ip
camera_ip=${camera_ip:-192.168.1.100}

read -p "Camera username (default: admin): " camera_user
camera_user=${camera_user:-admin}

read -p "Camera password: " camera_pass

# Create a config file for the recording script
CAMERA_CONFIG="/home/pi/camera_config.env"
echo ""
echo -e "${YELLOW}Saving camera configuration to $CAMERA_CONFIG...${NC}"

cat > "$CAMERA_CONFIG" << EOFCONFIG
# Camera Configuration
# Generated by setup script on $(date)
CAMERA_IP=$camera_ip
CAMERA_USER=$camera_user
CAMERA_PASS=$camera_pass
CAMERA_RTSP_URL=rtsp://$camera_user:$camera_pass@$camera_ip:554/h264Preview_01_main
EOFCONFIG

chmod 600 "$CAMERA_CONFIG"
echo -e "${GREEN}✓ Camera config saved to $CAMERA_CONFIG${NC}"

# ============================================================
# PART 4: RELIABILITY IMPROVEMENTS
# ============================================================
echo ""
echo ""
echo -e "${BLUE}=== PART 4: RELIABILITY IMPROVEMENTS ===${NC}"
echo ""

echo -e "${YELLOW}Installing reliability packages...${NC}"
sudo apt update
sudo apt install -y watchdog htop iotop || true

# Enable watchdog to auto-reboot if system hangs
echo -e "${YELLOW}Configuring watchdog (auto-reboot on hang)...${NC}"
if ! grep -q "dtparam=watchdog=on" "$CONFIG_FILE"; then
    echo "dtparam=watchdog=on" | sudo tee -a "$CONFIG_FILE" > /dev/null
fi

# Configure watchdog service
sudo tee /etc/watchdog.conf > /dev/null << 'EOFWATCHDOG'
# Watchdog configuration
watchdog-device = /dev/watchdog
watchdog-timeout = 15
max-load-1 = 24
min-memory = 1
EOFWATCHDOG

sudo systemctl enable watchdog || true

# ============================================================
# PART 5: VERIFY SETUP
# ============================================================
echo ""
echo ""
echo -e "${BLUE}=== SETUP COMPLETE ===${NC}"
echo ""

echo -e "${GREEN}✓ Setup complete! Here's your configuration:${NC}"
echo ""
echo "Camera IP: $camera_ip"
echo "Camera RTSP URL: rtsp://$camera_user:****@$camera_ip:554/h264Preview_01_main"
echo "Camera Config: $CAMERA_CONFIG"
echo ""

if [ "$FAN_CONFIGURED" = true ]; then
    echo -e "${YELLOW}⚠️  REBOOT REQUIRED for fan configuration to take effect!${NC}"
fi

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Configure static IP on your camera (see Option A above)"
echo "2. Update your recording script with the new camera IP"
echo "3. Reboot the Raspberry Pi: sudo reboot"
echo ""
echo "To test camera connection after setup:"
echo "  ffprobe rtsp://$camera_user:$camera_pass@$camera_ip:554/h264Preview_01_main"
echo ""
