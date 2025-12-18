#!/bin/bash

# harden_wifi.sh - Harden WiFi to only allow current network
# Requires sudo/admin privileges

set -e

ALLOWED_NETWORK="Spectrum-Setup-A1-p"
WIFI_INTERFACE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[WiFi Hardening]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

# Check if running as root/sudo
check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        error "This script requires sudo privileges"
        echo "Usage: sudo $0"
        exit 1
    fi
}

# Find WiFi interface
find_wifi_interface() {
    log "Detecting WiFi interface..."
    
    # Try common WiFi interfaces
    for iface in en0 en1 en2; do
        if networksetup -getairportnetwork "$iface" >/dev/null 2>&1; then
            WIFI_INTERFACE="$iface"
            log "Found WiFi interface: $WIFI_INTERFACE"
            return 0
        fi
    done
    
    error "Could not find WiFi interface"
    exit 1
}

# Get current WiFi network
get_current_network() {
    local current=$(networksetup -getairportnetwork "$WIFI_INTERFACE" 2>/dev/null | cut -d: -f2 | xargs)
    if [ -n "$current" ]; then
        echo "$current"
    else
        echo ""
    fi
}

# Remove all preferred networks except allowed one
remove_other_networks() {
    log "Removing all WiFi networks except: $ALLOWED_NETWORK"
    
    local preferred_networks
    preferred_networks=$(networksetup -listpreferredwirelessnetworks "$WIFI_INTERFACE" 2>/dev/null | tail -n +2)
    
    if [ -z "$preferred_networks" ]; then
        warn "No preferred networks found"
        return 0
    fi
    
    local removed_count=0
    while IFS= read -r network; do
        network=$(echo "$network" | xargs)  # Trim whitespace
        if [ -z "$network" ]; then
            continue
        fi
        
        # Keep the allowed network, remove everything else
        if [[ ! "$network" =~ ^$ALLOWED_NETWORK ]]; then
            log "Removing network: $network"
            networksetup -removepreferredwirelessnetwork "$WIFI_INTERFACE" "$network" 2>/dev/null || true
            removed_count=$((removed_count + 1))
        else
            log "Keeping network: $network"
        fi
    done <<< "$preferred_networks"
    
    log "Removed $removed_count networks"
}

# Disable auto-join for all networks except allowed
disable_autojoin_others() {
    log "Disabling auto-join for non-allowed networks..."
    
    local preferred_networks
    preferred_networks=$(networksetup -listpreferredwirelessnetworks "$WIFI_INTERFACE" 2>/dev/null | tail -n +2)
    
    while IFS= read -r network; do
        network=$(echo "$network" | xargs)
        if [ -z "$network" ]; then
            continue
        fi
        
        if [[ ! "$network" =~ ^$ALLOWED_NETWORK ]]; then
            log "Disabling auto-join for: $network"
            networksetup -setairportnetwork "$WIFI_INTERFACE" "$network" off 2>/dev/null || true
        fi
    done <<< "$preferred_networks"
}

# Verify current connection
verify_connection() {
    local current=$(get_current_network)
    
    if [ -z "$current" ]; then
        warn "Not currently connected to any WiFi network"
        return 1
    fi
    
    if [[ "$current" =~ ^$ALLOWED_NETWORK ]]; then
        log "✓ Connected to allowed network: $current"
        return 0
    else
        warn "Currently connected to non-allowed network: $current"
        warn "Consider disconnecting manually or this script will disconnect"
        return 1
    fi
}

# Disconnect from non-allowed networks
disconnect_if_needed() {
    local current=$(get_current_network)
    
    if [ -z "$current" ]; then
        return 0
    fi
    
    if [[ ! "$current" =~ ^$ALLOWED_NETWORK ]]; then
        warn "Disconnecting from non-allowed network: $current"
        networksetup -setairportpower "$WIFI_INTERFACE" off
        sleep 2
        networksetup -setairportpower "$WIFI_INTERFACE" on
        log "WiFi restarted - reconnect to allowed network manually"
    fi
}

# Main execution
main() {
    log "Starting WiFi hardening..."
    log "Allowed network pattern: $ALLOWED_NETWORK*"
    
    check_privileges
    find_wifi_interface
    
    local current=$(get_current_network)
    if [ -n "$current" ]; then
        log "Current network: $current"
    fi
    
    # Remove other networks
    remove_other_networks
    
    # Disable auto-join for others
    disable_autojoin_others
    
    # Verify/Disconnect if needed
    if ! verify_connection; then
        read -p "Disconnect from current network? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            disconnect_if_needed
        fi
    fi
    
    log ""
    log "WiFi hardening complete!"
    log "Only networks matching '$ALLOWED_NETWORK*' are allowed"
    log ""
    log "To reconnect to allowed network:"
    log "  networksetup -setairportnetwork $WIFI_INTERFACE 'Spectrum-Setup-A1-p...'"
}

main "$@"
