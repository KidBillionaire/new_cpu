#!/bin/bash

# macOS Security Enhancement Script
# - Configure Application Firewall
# - Implement DNS Security

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}macOS Security Enhancement${NC}"
echo "=================================="
echo ""

# Check for sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script requires sudo privileges.${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

# ============================================================================
# 1. APPLICATION FIREWALL CONFIGURATION
# ============================================================================
echo -e "${YELLOW}[1/4] Configuring Application Firewall...${NC}"

# Enable firewall globally
echo "  - Enabling global firewall state..."
/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Block all incoming connections by default
echo "  - Blocking all incoming connections..."
/usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on

# Enable stealth mode (makes computer invisible to ping probes, etc.)
echo "  - Enabling stealth mode..."
/usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

# Prevent signed applications from automatically being allowed
echo "  - Disabling automatic allow for signed apps..."
/usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off

# Enable logging
echo "  - Enabling firewall logging..."
/usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on

echo -e "${GREEN}✓ Firewall baseline configuration complete${NC}"

# Add specific allowed applications
echo ""
echo "  - Adding allowed applications..."

# Terminal
if [ -f "/Applications/Utilities/Terminal.app" ]; then
    /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Utilities/Terminal.app
    /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /Applications/Utilities/Terminal.app
    echo "    ✓ Terminal allowed"
fi

# Safari (for browsing)
if [ -f "/Applications/Safari.app" ]; then
    /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Safari.app
    /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /Applications/Safari.app
    echo "    ✓ Safari allowed"
fi

# System Preferences (needed for admin tasks)
if [ -f "/Applications/System Preferences.app" ]; then
    /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/System\ Preferences.app
    /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /Applications/System\ Preferences.app
    echo "    ✓ System Preferences allowed"
fi

# Activity Monitor (for system monitoring)
if [ -f "/Applications/Utilities/Activity Monitor.app" ]; then
    /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Utilities/Activity\ Monitor.app
    /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /Applications/Utilities/Activity\ Monitor.app
    echo "    ✓ Activity Monitor allowed"
fi

echo -e "${GREEN}✓ Application firewall configuration complete${NC}"

# ============================================================================
# 2. SHOW FIREWALL CONFIGURATION
# ============================================================================
echo ""
echo -e "${YELLOW}[2/4] Current Firewall Configuration:${NC}"
echo ""

# Get firewall status
FIREWALL_GLOBAL_STATE=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate)
FIREWALL_BLOCK_ALL=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getblockall)
FIREWALL_STEALTH=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode)
FIREWALL_ALLOW_SIGNED=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getallowsigned)
FIREWALL_LOGGING=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getloggingmode)

echo "  Global State: $FIREWALL_GLOBAL_STATE"
echo "  Block All: $FIREWALL_BLOCK_ALL"
echo "  Stealth Mode: $FIREWALL_STEALTH"
echo "  Allow Signed: $FIREWALL_ALLOW_SIGNED"
echo "  Logging Mode: $FIREWALL_LOGGING"

# List allowed applications
echo ""
echo "  Allowed Applications:"
/usr/libexec/ApplicationFirewall/socketfilterfw --listapps | while read line; do
    if [[ $line == *"ALLOW"* ]]; then
        echo "    ✓ $line"
    fi
done

# ============================================================================
# 3. DNS SECURITY CONFIGURATION
# ============================================================================
echo ""
echo -e "${YELLOW}[3/4] Configuring DNS Security...${NC}"

# Set DNS servers for all services
echo "  - Configuring secure DNS servers..."

# Get all network services
SERVICES=$(networksetup -listallnetworkservices | tail -n +2)

for service in $SERVICES; do
    # Skip services that don't support DNS
    if [[ "$service" == *"Bluetooth"* ]] || [[ "$service" == *"Thunderbolt"* ]]; then
        continue
    fi

    echo "    Configuring $service..."

    # Set secure DNS servers (Quad9 and Cloudflare primary/secondary)
    networksetup -setdnsservers "$service" 9.9.9.9 1.1.1.1 8.8.8.8

    # Note: Encrypted DNS (DoH) requires manual configuration via System Settings
    # on macOS 11+, but we can set the foundation with secure DNS servers
done

echo -e "${GREEN}✓ DNS servers configured${NC}"

# Clear and reset DNS cache
echo ""
echo "  - Clearing DNS cache..."

# Try different cache clearing commands for different macOS versions
dscacheutil -flushcache 2>/dev/null || true
killall -HUP mDNSResponder 2>/dev/null || true
sudo discoveryutil udnsflushcaches 2>/dev/null || true

echo -e "${GREEN}✓ DNS cache cleared${NC}"

# ============================================================================
# 4. DNS RESOLUTION TESTING
# ============================================================================
echo ""
echo -e "${YELLOW}[4/4] Testing DNS Resolution...${NC}"

# Test basic DNS resolution
echo "  - Testing basic DNS resolution..."
if nslookup google.com >/dev/null 2>&1; then
    echo -e "    ${GREEN}✓ Basic DNS resolution working${NC}"
else
    echo -e "    ${RED}✗ Basic DNS resolution failed${NC}"
fi

# Test DNS resolution to configured servers
echo "  - Testing resolution via configured DNS servers..."
if nslookup google.com 9.9.9.9 >/dev/null 2>&1; then
    echo -e "    ${GREEN}✓ Resolution via Quad9 (9.9.9.9) working${NC}"
else
    echo -e "    ${YELLOW}⚠ Resolution via Quad9 failed${NC}"
fi

if nslookup google.com 1.1.1.1 >/dev/null 2>&1; then
    echo -e "    ${GREEN}✓ Resolution via Cloudflare (1.1.1.1) working${NC}"
else
    echo -e "    ${YELLOW}⚠ Resolution via Cloudflare failed${NC}"
fi

# Show current DNS servers
echo ""
echo "  Current DNS configuration:"
for service in $SERVICES; do
    if [[ "$service" == *"Bluetooth"* ]] || [[ "$service" == *"Thunderbolt"* ]]; then
        continue
    fi

    DNS_SERVERS=$(networksetup -getdnsservers "$service" 2>/dev/null || echo "Not configured")
    echo "    $service: $DNS_SERVERS"
done

# ============================================================================
# SUMMARY AND NEXT STEPS
# ============================================================================
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Security Enhancement Complete${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Firewall Status:"
echo "  - ${GREEN}✓ Enabled globally${NC}"
echo "  - ${GREEN}✓ Blocking all incoming connections${NC}"
echo "  - ${GREEN}✓ Stealth mode enabled${NC}"
echo "  - ${GREEN}✓ Logging enabled${NC}"
echo ""
echo "DNS Security:"
echo "  - ${GREEN}✓ Secure DNS servers configured${NC}"
echo "    • Quad9 (9.9.9.9) - Privacy and security focused"
echo "    • Cloudflare (1.1.1.1) - Fast and privacy focused"
echo "    • Google (8.8.8.8) - Reliable backup"
echo "  - ${GREEN}✓ DNS cache cleared${NC}"
echo ""
echo -e "${YELLOW}Next Steps (Manual Configuration):${NC}"
echo "1. For encrypted DNS (DoH), go to:"
echo "   System Settings > Network > [Your Connection] > Details... > DNS"
echo "2. Enable 'Encrypted DNS' and select:"
echo "   - Cloudflare (1.1.1.1) or Quad9 (9.9.9.9)"
echo ""
echo -e "${BLUE}Firewall Management:${NC}"
echo "• To add apps: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /path/to/app"
echo "• To block apps: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --blockapp /path/to/app"
echo "• To view rules: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --listapps"
echo ""