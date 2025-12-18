#!/bin/bash

# macOS Security Hardening - Practical Edition
# - Burn Bluetooth completely
# - WiFi: One network at a time (burn others on new connection)
# - Lightweight process monitoring (not intensive)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}macOS Security Hardening${NC}"
echo "================================"

# Check for sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}This script requires sudo privileges${NC}"
    exit 1
fi

# ============================================================================
# 1. BURN BLUETOOTH - COMPLETE DISABLE
# ============================================================================
echo ""
echo -e "${YELLOW}[1/3] Burning Bluetooth...${NC}"

# Turn off Bluetooth
blueutil --power 0 2>/dev/null || echo "blueutil not found, using system commands"

# Disable Bluetooth via system preferences
defaults write /Library/Preferences/com.apple.Bluetooth ControllerPowerState -int 0
killall -HUP blued 2>/dev/null || true

# Remove Bluetooth plist (burn it)
rm -f ~/Library/Preferences/com.apple.Bluetooth.plist
rm -f /Library/Preferences/com.apple.Bluetooth.plist 2>/dev/null || true

# Disable Bluetooth service
launchctl unload /System/Library/LaunchDaemons/com.apple.blued.plist 2>/dev/null || true

echo -e "${GREEN}✓ Bluetooth completely disabled${NC}"

# ============================================================================
# 2. WIFI - ONE NETWORK AT A TIME (BURN OTHERS)
# ============================================================================
echo ""
echo -e "${YELLOW}[2/3] Configuring WiFi (one network at a time)...${NC}"

# Function to burn all WiFi networks except current
burn_wifi_networks() {
    local current_ssid=$(networksetup -getairportnetwork en0 2>/dev/null | cut -d: -f2 | xargs)
    
    if [ -z "$current_ssid" ]; then
        echo -e "${YELLOW}No current WiFi connection${NC}"
        return
    fi
    
    echo -e "${BLUE}Current network: ${current_ssid}${NC}"
    echo -e "${YELLOW}Burning all other networks...${NC}"
    
    # Get all known networks
    local all_networks=$(networksetup -listpreferredwirelessnetworks en0 | tail -n +2 | awk '{print $2}')
    
    for network in $all_networks; do
        if [ "$network" != "$current_ssid" ]; then
            echo "  Removing: $network"
            networksetup -removepreferredwirelessnetwork en0 "$network" 2>/dev/null || true
            
            # Also remove from keychain
            security delete-generic-password -l "$network" "/Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist" 2>/dev/null || true
            security delete-generic-password -l "$network" 2>/dev/null || true
        fi
    done
    
    echo -e "${GREEN}✓ Only ${current_ssid} remains${NC}"
}

# Function to connect to new network and burn others
connect_and_burn() {
    local ssid=$1
    local password=$2
    
    if [ -z "$ssid" ]; then
        echo -e "${RED}Usage: connect_and_burn <SSID> [password]${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Connecting to: ${ssid}${NC}"
    
    # Connect to new network
    if [ -n "$password" ]; then
        networksetup -setairportnetwork en0 "$ssid" "$password"
    else
        networksetup -setairportnetwork en0 "$ssid"
    fi
    
    sleep 2
    
    # Burn all others
    burn_wifi_networks
    
    echo -e "${GREEN}✓ Connected to ${ssid}, all others burned${NC}"
}

# Set up WiFi monitoring (burn others when new network connected)
setup_wifi_monitor() {
    cat > /usr/local/bin/wifi-burn-monitor.sh << 'EOF'
#!/bin/bash
# Monitor WiFi changes and burn old networks

LAST_SSID=""
while true; do
    CURRENT_SSID=$(networksetup -getairportnetwork en0 2>/dev/null | cut -d: -f2 | xargs)
    
    if [ -n "$CURRENT_SSID" ] && [ "$CURRENT_SSID" != "$LAST_SSID" ] && [ -n "$LAST_SSID" ]; then
        echo "$(date): Network changed from $LAST_SSID to $CURRENT_SSID - burning old networks"
        
        # Burn all networks except current
        for network in $(networksetup -listpreferredwirelessnetworks en0 | tail -n +2 | awk '{print $2}'); do
            if [ "$network" != "$CURRENT_SSID" ]; then
                networksetup -removepreferredwirelessnetwork en0 "$network" 2>/dev/null || true
                security delete-generic-password -l "$network" 2>/dev/null || true
            fi
        done
    fi
    
    LAST_SSID="$CURRENT_SSID"
    sleep 5
done
EOF
    
    chmod +x /usr/local/bin/wifi-burn-monitor.sh
    
    # Create LaunchAgent to run monitor
    cat > ~/Library/LaunchAgents/com.wifi.burn.monitor.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.wifi.burn.monitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/wifi-burn-monitor.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
    
    launchctl load ~/Library/LaunchAgents/com.wifi.burn.monitor.plist 2>/dev/null || true
    
    echo -e "${GREEN}✓ WiFi burn monitor installed${NC}"
}

# Initial burn
burn_wifi_networks
setup_wifi_monitor

# Create helper script for manual connect-and-burn
cat > /usr/local/bin/wifi-connect << 'EOF'
#!/bin/bash
# Connect to WiFi and burn all others
# Usage: wifi-connect <SSID> [password]

if [ -z "$1" ]; then
    echo "Usage: wifi-connect <SSID> [password]"
    exit 1
fi

SSID="$1"
PASSWORD="$2"

echo "Connecting to $SSID..."
if [ -n "$PASSWORD" ]; then
    networksetup -setairportnetwork en0 "$SSID" "$PASSWORD"
else
    networksetup -setairportnetwork en0 "$SSID"
fi

sleep 2

# Burn all others
CURRENT=$(networksetup -getairportnetwork en0 | cut -d: -f2 | xargs)
for network in $(networksetup -listpreferredwirelessnetworks en0 | tail -n +2 | awk '{print $2}'); do
    if [ "$network" != "$CURRENT" ]; then
        networksetup -removepreferredwirelessnetwork en0 "$network" 2>/dev/null || true
        security delete-generic-password -l "$network" 2>/dev/null || true
    fi
done

echo "✓ Connected to $CURRENT, all others burned"
EOF

chmod +x /usr/local/bin/wifi-connect
echo -e "${GREEN}✓ Use 'wifi-connect <SSID> [password]' to connect and burn others${NC}"

# ============================================================================
# 3. LIGHTWEIGHT PROCESS MONITORING (NOT INTENSIVE)
# ============================================================================
echo ""
echo -e "${YELLOW}[3/3] Setting up lightweight process monitoring...${NC}"

# Create simple process monitor (not intensive ps aux loop)
cat > /usr/local/bin/process-monitor.sh << 'EOF'
#!/bin/bash
# Lightweight process monitoring - runs every 5 minutes, not intensive

LOG_FILE="$HOME/.sandbox/process-monitor.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Log suspicious processes (not full ps aux dump)
SUSPICIOUS_PATTERNS="ssh|vnc|remote|backdoor|malware"

# Check for suspicious processes
ps aux | grep -iE "$SUSPICIOUS_PATTERNS" | grep -v grep | while read line; do
    echo "$(date): SUSPICIOUS: $line" >> "$LOG_FILE"
done

# Log new network connections (lightweight)
netstat -an | grep ESTABLISHED | wc -l | xargs -I {} echo "$(date): Active connections: {}" >> "$LOG_FILE"

# Keep log small (last 100 lines)
tail -n 100 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
EOF

chmod +x /usr/local/bin/process-monitor.sh

# Create LaunchAgent (runs every 5 minutes, not every second)
cat > ~/Library/LaunchAgents/com.process.monitor.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.process.monitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/process-monitor.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.process.monitor.plist 2>/dev/null || true

echo -e "${GREEN}✓ Lightweight process monitoring installed (every 5 min)${NC}"
echo -e "${BLUE}  Log: ~/.sandbox/process-monitor.log${NC}"

# ============================================================================
# SUMMARY
# ============================================================================
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Hardening Complete${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Bluetooth: ${RED}BURNED${NC} (completely disabled)"
echo "WiFi: ${GREEN}One network at a time${NC} (others auto-burned)"
echo "  - Use: ${BLUE}wifi-connect <SSID> [password]${NC}"
echo "Process Monitor: ${GREEN}Lightweight${NC} (every 5 min, not intensive)"
echo "  - Log: ${BLUE}~/.sandbox/process-monitor.log${NC}"
echo ""

