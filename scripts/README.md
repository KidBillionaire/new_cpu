# Scripts

This directory contains all executable scripts for the sandbox system.

## Scripts

### Main CLI
- **sb** - Main command-line interface for managing sandbox containers
  - Usage: `./scripts/sb [command] [options]`
  - Commands: start, stop, status, shell, snapshot, restore, ai

### Installation & Setup
- **install.sh** - Complete installation script
  - Builds Docker images
  - Creates directory structure
  - Starts containers
  - Sets up LaunchAgent for snapshots

- **setup-directories.sh** - Creates required directory structure
  - Creates `~/.sandbox/` directories
  - Sets proper permissions

### Maintenance
- **snapshot.sh** - Creates container snapshots
  - Used by LaunchAgent for automatic hourly snapshots
  - Can be run manually: `./scripts/snapshot.sh sb-dev`

- **harden_macos.sh** - macOS host hardening script
  - Disables Bluetooth
  - Configures WiFi (one network at a time)
  - Sets up lightweight process monitoring
  - See `docs/HARDENING_README.md` for details

## Usage

All scripts should be run from the repository root:

```bash
# Install the sandbox system
./scripts/install.sh

# Use the CLI
./scripts/sb start
./scripts/sb status

# Create snapshot manually
./scripts/snapshot.sh sb-dev

# Harden macOS host
sudo ./scripts/harden_macos.sh
```

## Permissions

- Most scripts can be run as regular user
- `harden_macos.sh` requires `sudo` privileges
- `sb` script should be executable: `chmod +x scripts/sb`
