#!/bin/bash

# quick_wifi_harden.sh - Quick WiFi hardening (10 min version)
# Kills all networks except current one

set -e

ALLOWED_NETWORK="Spectrum-Setup-A1-p"

echo "=== QUICK WiFi HARDENING ==="
echo "This will remove ALL WiFi networks except: $ALLOWED_NETWORK*"
echo ""

# Find WiFi interface
WIFI_IFACE=""
for iface in en0 en1 en2; do
    if networksetup -getairportnetwork "$iface" >/dev/null 2>&1; then
        WIFI_IFACE="$iface"
        break
    fi
done

if [ -z "$WIFI_IFACE" ]; then
    echo "ERROR: Could not find WiFi interface"
    exit 1
fi

echo "Found WiFi interface: $WIFI_IFACE"
CURRENT=$(networksetup -getairportnetwork "$WIFI_IFACE" 2>/dev/null | cut -d: -f2 | xargs || echo "")
echo "Current network: ${CURRENT:-'Not connected'}"

# Get all preferred networks
echo ""
echo "Removing all networks except $ALLOWED_NETWORK*..."
NETWORKS=$(networksetup -listpreferredwirelessnetworks "$WIFI_IFACE" 2>/dev/null | tail -n +2 || echo "")

REMOVED=0
KEPT=0

while IFS= read -r network; do
    network=$(echo "$network" | xargs)
    [ -z "$network" ] && continue
    
    if [[ "$network" =~ ^$ALLOWED_NETWORK ]]; then
        echo "  KEEP: $network"
        KEPT=$((KEPT + 1))
    else
        echo "  REMOVE: $network"
        sudo networksetup -removepreferredwirelessnetwork "$WIFI_IFACE" "$network" 2>/dev/null || true
        REMOVED=$((REMOVED + 1))
    fi
done <<< "$NETWORKS"

echo ""
echo "=== DONE ==="
echo "Removed: $REMOVED networks"
echo "Kept: $KEPT networks"
echo ""
echo "WiFi hardened! Only $ALLOWED_NETWORK* networks remain."
