# macOS Hardening - Practical Edition

## What It Does

1. **Bluetooth: BURNED** 🔥
   - Completely disabled, removed plists, service stopped
   - No Bluetooth, period.

2. **WiFi: One Network at a Time** 📡
   - Connect to cafe in Paris → all other networks burned
   - Auto-monitor: when you connect to new network, old ones deleted
   - Manual: `wifi-connect <SSID> [password]`

3. **Process Monitoring: Lightweight** 👁️
   - Runs every 5 minutes (not intensive)
   - Logs suspicious processes only
   - Logs active network connections count
   - Auto-rotates log (keeps last 100 lines)

## Usage

### Install Hardening

```bash
sudo ./harden_macos.sh
```

### Connect to WiFi (Burns Others)

```bash
# Connect to new network, burns all others
wifi-connect "Cafe Paris WiFi" "password123"

# Or connect without password (will prompt)
wifi-connect "Cafe Paris WiFi"
```

### Check Process Monitor Log

```bash
cat ~/.sandbox/process-monitor.log
```

### Manual WiFi Burn (Burn All Except Current)

The script auto-burns when you connect, but you can manually burn:

```bash
# The monitor runs automatically, but you can trigger:
/usr/local/bin/wifi-burn-monitor.sh
```

## How WiFi Burning Works

1. You connect to new network (via System Preferences or `wifi-connect`)
2. Monitor detects network change
3. Removes all other networks from preferred list
4. Deletes all other network passwords from Keychain
5. Only current network remains

**Example:**
- You're at home on "HomeWiFi"
- You go to cafe, connect to "CafeParis"
- "HomeWiFi" is automatically deleted (burned)
- Only "CafeParis" exists now
- When you leave cafe, connect to new network → "CafeParis" gets burned

## Process Monitoring

**Not intensive** - runs every 5 minutes, not every second.

Logs:
- Suspicious processes (ssh, vnc, remote, backdoor patterns)
- Active network connection count
- Timestamp for each entry

Log auto-rotates to last 100 lines (stays small).

## Disable Monitoring (If Needed)

```bash
launchctl unload ~/Library/LaunchAgents/com.process.monitor.plist
launchctl unload ~/Library/LaunchAgents/com.wifi.burn.monitor.plist
```

## Re-enable Bluetooth (If You Change Your Mind)

```bash
blueutil --power 1
defaults write /Library/Preferences/com.apple.Bluetooth ControllerPowerState -int 1
```

## Files Created

- `/usr/local/bin/wifi-connect` - WiFi connect helper
- `/usr/local/bin/wifi-burn-monitor.sh` - WiFi monitor daemon
- `/usr/local/bin/process-monitor.sh` - Process monitor script
- `~/Library/LaunchAgents/com.wifi.burn.monitor.plist` - WiFi monitor LaunchAgent
- `~/Library/LaunchAgents/com.process.monitor.plist` - Process monitor LaunchAgent
- `~/.sandbox/process-monitor.log` - Process monitor log

## That's It

Simple, practical, not over-engineered. Bluetooth burned. WiFi one-at-a-time. Light monitoring.

