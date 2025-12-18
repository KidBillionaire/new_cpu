# WiFi Hardening - Manual Test Commands

**IMPORTANT:** Run these commands **ONE AT A TIME** in your terminal. The `-60008` error means authorization failed - make sure you use `sudo` for commands that need it.

---

## Testing Options

### Option 1: Automated Verifier (Recommended First)

Run the enhanced verifier with different modes:

```bash
# Standard verification (prerequisites only)
./scripts/verify_wifi.sh

# Dry-run mode (see what would be tested)
./scripts/verify_wifi.sh --dry-run

# End-to-end testing with safe operations
./scripts/verify_wifi.sh --test

# Get help
./scripts/verify_wifi.sh --help
```

The verifier now includes:
- **Standard Mode**: 10 prerequisite checks
- **Test Mode**: 15 total checks with actual command testing
- **Dry-Run Mode**: Shows what would be tested without executing
- **State Backup**: Saves network state before testing
- **Rollback Capability**: Can restore original configuration

### Option 2: Manual Testing (Below)

Follow the step-by-step manual process if you prefer individual command testing.

---

## Step-by-Step Manual Test (Run One at a Time)

### Step 1: Find WiFi Interface [NO SUDO]

```bash
for iface in en0 en1 en2; do networksetup -getairportnetwork $iface 2>&1 && echo "Found: $iface" && break; done
```

This will tell you which interface (en0, en1, or en2) is your WiFi interface.

---

### Step 2: Get Current Network (if connected) [NO SUDO]

Replace `en0` with your interface from Step 1:

```bash
networksetup -getairportnetwork en0
```

Or for en1:
```bash
networksetup -getairportnetwork en1
```

---

### Step 3: List ALL Preferred Networks [NO SUDO]

```bash
networksetup -listpreferredwirelessnetworks en0
```

Replace `en0` with your interface. This shows all saved WiFi networks.

---

### Step 4: Test Removing ONE Network [SUDO - Run Individually]

Replace `NETWORK_NAME` with an actual network name from Step 3:

```bash
sudo networksetup -removepreferredwirelessnetwork en0 "NETWORK_NAME"
```

**Example:**
```bash
sudo networksetup -removepreferredwirelessnetwork en0 "MyTestNetwork"
```

**Note:** If you get `-60008` error, try:
1. Run `sudo -v` first to refresh sudo credentials
2. Make sure Terminal has Full Disk Access (System Settings > Privacy & Security > Full Disk Access)

---

### Step 5: Verify the Network Was Removed [NO SUDO]

```bash
networksetup -listpreferredwirelessnetworks en0
```

Check that the network you removed is no longer in the list.

---

### Step 6: Remove ALL Networks Except Spectrum-Setup-A1-p* [SUDO]

**ONE-LINER** (copy entire line):

```bash
networksetup -listpreferredwirelessnetworks en0 | tail -n +2 | while read net; do net=$(echo "$net" | xargs); if [[ ! "$net" =~ ^Spectrum-Setup-A1-p ]]; then echo "Removing: $net"; sudo networksetup -removepreferredwirelessnetwork en0 "$net" 2>/dev/null || true; else echo "Keeping: $net"; fi; done
```

Replace `en0` with your interface. This removes all networks except those starting with `Spectrum-Setup-A1-p`.

---

### Step 7: Verify Only Spectrum Networks Remain [NO SUDO]

```bash
networksetup -listpreferredwirelessnetworks en0
```

You should only see networks starting with `Spectrum-Setup-A1-p`.

---

## Alternative: Test Block (Copy/Paste All at Once)

If you prefer to run everything together, use this block:

```bash
WIFI_IFACE="en0"
echo "=== Current Networks ==="
networksetup -listpreferredwirelessnetworks "$WIFI_IFACE"
echo ""
echo "=== Removing non-Spectrum networks ==="
networksetup -listpreferredwirelessnetworks "$WIFI_IFACE" | tail -n +2 | while read net; do
    net=$(echo "$net" | xargs)
    if [[ ! "$net" =~ ^Spectrum-Setup-A1-p ]]; then
        echo "Removing: $net"
        sudo networksetup -removepreferredwirelessnetwork "$WIFI_IFACE" "$net" 2>/dev/null || true
    else
        echo "Keeping: $net"
    fi
done
echo ""
echo "=== Remaining Networks ==="
networksetup -listpreferredwirelessnetworks "$WIFI_IFACE"
```

**Remember:** Replace `en0` with your actual WiFi interface from Step 1.

---

## Rollback Procedures

### Using the Verifier's Rollback

The enhanced verifier automatically saves network state when using `--test` mode:

```bash
# Run test mode (automatically saves state)
./scripts/verify_wifi.sh --test

# State is saved to /tmp/wifi_rollback_[PID]
```

### Manual Rollback

If you need to restore your previous network configuration manually:

1. **Check Current State**:
```bash
networksetup -listpreferredwirelessnetworks en0
```

2. **Re-add Networks** (if you removed them):
```bash
sudo networksetup -addpreferredwirelessnetwork en0 "NETWORK_NAME" WPA2
```

3. **Connect to Network** (if needed):
```bash
sudo networksetup -setairportnetwork en0 "NETWORK_NAME"
```

### Important Notes

- **Backup First**: Always run the verifier in `--test` mode before making changes
- **One at a Time**: Test commands individually to understand their effects
- **Network Names**: Keep a list of your important network names before removal
- **Connectivity**: Ensure you have alternative internet access during testing

---

## Testing Mode Failure Troubleshooting

### If Test Mode Fails

1. **Check Interface Detection**:
   - Ensure WiFi is enabled on your Mac
   - Try running with sudo: `sudo ./scripts/verify_wifi.sh --test`

2. **Permission Issues**:
   - Give Terminal Full Disk Access
   - Run `sudo -v` to refresh credentials

3. **Network State Issues**:
   - Restart WiFi: Turn off/on WiFi from menu bar
   - Restart Terminal and try again

4. **Rollback File Issues**:
   - Check /tmp for rollback files: `ls -la /tmp/wifi_rollback_*`
   - Manual cleanup: `rm -f /tmp/wifi_rollback_*`

---

## Troubleshooting Authorization Errors (-60008)

If you get `AuthorizationCreate() failed: -60008`:

1. **Use sudo:** Commands that modify networks require `sudo`
2. **Refresh sudo:** Run `sudo -v` first to refresh your sudo credentials
3. **Check permissions:** Some commands don't need sudo:
   - ✅ Listing networks: `networksetup -listpreferredwirelessnetworks en0` (no sudo)
   - ✅ Getting current network: `networksetup -getairportnetwork en0` (no sudo)
   - ❌ Removing networks: `sudo networksetup -removepreferredwirelessnetwork ...` (needs sudo)
4. **Full Disk Access:** If authorization still fails:
   - System Settings > Privacy & Security > Full Disk Access
   - Add Terminal.app (or iTerm2 if you use it)
   - Restart Terminal

---

## Quick Reference

| Command | Sudo Needed? | Purpose |
|---------|-------------|---------|
| `networksetup -getairportnetwork en0` | ❌ No | Get current network |
| `networksetup -listpreferredwirelessnetworks en0` | ❌ No | List all saved networks |
| `sudo networksetup -removepreferredwirelessnetwork en0 "NAME"` | ✅ Yes | Remove one network |
| `sudo networksetup -setairportnetwork en0 "NAME"` | ✅ Yes | Connect to network |
