# Scaffolding the Future

Security analysis and sandbox solution for macOS threat mitigation.

## Overview

This repository contains analysis of attack vectors and a container-based sandbox solution for isolating and protecting development and production environments on macOS. It includes comprehensive WiFi hardening tools with advanced verification and rollback capabilities.

## Repository Structure

```
scafolding-the-future/
├── README.md                    # This file - project overview
├── LICENSE                      # License file
├── .gitignore                   # Git ignore rules
├── .gitattributes              # Git attributes for line endings
│
├── docs/                       # Documentation
│   ├── WIFI_VERIFIER.md             # WiFi verifier feature documentation
│   ├── attack_vectors_analysis.md    # macOS attack vectors analysis
│   ├── sandbox_flaws_analysis.md     # Critical security flaws
│   ├── sandbox_solutions.md          # Solutions for identified flaws
│   ├── HARDENING_README.md            # macOS hardening guide
│   ├── AGENT_FLOW.md                 # AI agent workflow documentation
│   ├── AGENT_PROMPTS.md              # AI agent prompts
│   └── QUICK_START.md                # Quick start guide
│
├── scripts/                    # Executable scripts
│   ├── sb                      # Main CLI tool (sandbox management)
│   ├── install.sh              # Installation script
│   ├── setup-directories.sh    # Directory setup script
│   ├── snapshot.sh             # Snapshot creation script
│   ├── harden_macos.sh         # macOS hardening script
│   ├── harden_wifi.sh          # WiFi hardening script
│   ├── quick_wifi_harden.sh    # Quick WiFi setup script
│   ├── test_wifi_manual.sh     # Manual WiFi testing commands
│   └── verify_wifi.sh          # Enhanced WiFi verifier (3 modes)
│
├── docker/                     # Docker configuration
│   ├── docker-compose.yml      # Container orchestration
│   ├── Dockerfile.sb-dev       # Development container
│   ├── Dockerfile.sb-life      # Life/work container
│   └── Dockerfile.sb-core      # Core/secrets container
│
└── config/                     # Configuration files
    └── com.sandbox.snapshot.plist  # LaunchAgent for auto-snapshots
```

## Contents

- **Documentation** (`docs/`): Comprehensive analysis, guides, and workflows
- **Scripts** (`scripts/`): Installation, management, and hardening tools
- **Docker** (`docker/`): Container definitions and orchestration
- **Config** (`config/`): System configuration files

## The Sandbox Solution

A three-tier container isolation system using Docker/OrbStack:

1. **sb-dev**: Full capabilities, isolated development environment
2. **sb-life**: Restricted user, everyday work environment  
3. **sb-core**: Read-only, no network, protected secrets

## Key Features

- Complete filesystem isolation per container
- Network isolation (core has no network)
- AI permission boundaries
- Snapshot & restore capability
- Read-only secret access
- Capability dropping for security

## WiFi Hardening & Security

### Advanced WiFi Verifier

The repository includes an enhanced WiFi verification system with three testing modes:

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

### WiFi Hardening Capabilities

- **Network Interface Detection**: Automatically finds WiFi interfaces (en0, en1, en2)
- **Preferred Network Management**: Lists and filters saved WiFi networks
- **Safe Testing Environment**: Non-destructive testing with rollback capability
- **Authorization Error Handling**: Comprehensive -60008 error troubleshooting
- **State Backup & Restore**: Automatic network state snapshot before testing
- **Multi-Mode Verification**: Standard, Test, and Dry-run modes for different use cases

### Quick WiFi Setup

```bash
# Quick WiFi hardening
./scripts/quick_wifi_harden.sh

# Manual WiFi hardening with verification
./scripts/harden_wifi.sh

# Manual testing commands
./scripts/test_wifi_manual.sh
```

### Documentation

- `WIFI_TEST_COMMANDS.md` - Comprehensive WiFi testing guide
- `TEST_RESULTS.md` - Verification test results and capabilities
- Step-by-step instructions with sudo/no-sudo indicators
- Troubleshooting guide for authorization errors
- Rollback procedures and safety mechanisms

## Threat Coverage

- ✅ File System Attacks (100%)
- ✅ Network Attacks (95%)
- ✅ Privilege Escalation (90%)
- ✅ Persistent Backdoors (95%)
- ⚠️ Input Device Attacks (70%)
- ⚠️ Social Engineering (50%)

## Requirements

- macOS
- Docker or OrbStack
- Command line tools (for git operations)

## Installation

1. Ensure Docker/OrbStack is installed and running
2. Run the installation script:
   ```bash
   ./scripts/install.sh
   ```
3. The installation script will automatically:
   - Create the directory structure (`~/.sandbox/`)
   - Build Docker images for all three containers
   - Start the containers
   - Set up automatic hourly snapshots (LaunchAgent)


## Usage

### Basic Commands

```bash
# Start all containers
sb start

# Start specific container
sb start dev
sb start life
sb start core

# Stop containers
sb stop [dev|life|core]

# Check status
sb status

# Open shell in container
sb shell dev
sb shell life
sb shell core
```

### Snapshot Management

```bash
# Create snapshot
sb snapshot dev my-snapshot-name

# Restore snapshot
sb restore dev sb-dev-20241218-120000-my-snapshot-name

# Snapshots are automatically created hourly (via LaunchAgent)
```

### AI Permissions

```bash
# Allow AI access to container
sb ai allow dev
sb ai allow life
sb ai allow core

# Deny AI access
sb ai deny dev

# Check AI permissions
sb ai status
```

## File Structure

```
~/.sandbox/
├── shared/              # Shared directory (mounted in all containers)
├── core/
│   └── secrets/        # Secrets directory (read-only in sb-core)
└── sb.log              # CLI operation log
└── snapshots.log       # Snapshot operation log

~/Library/LaunchAgents/
└── com.sandbox.snapshot.plist  # Hourly snapshot automation
```

## Security Warnings

### ⚠️ CRITICAL SECURITY RISKS

This sandbox system has **known security limitations**:

1. **sb-dev Container is DANGEROUS**
   - Has `cap_add: ALL` - full kernel capabilities
   - Container escape = host root access
   - **DO NOT** use for untrusted workloads

2. **Volume Mounts Expose Host Filesystem**
   - `~/Code`, `~/Documents`, `~/Desktop` are mounted with read/write access
   - Compromised container can modify host files
   - Can plant backdoors in git hooks, config files, etc.

3. **Shared Directory is Attack Vector**
   - `~/.sandbox/shared` mounted in ALL containers
   - Compromised sb-dev can write malicious files
   - sb-life and sb-core can read those files
   - **Cross-container contamination possible**

4. **AI Permissions are Bypassable**
   - Stored as simple files: `~/.sandbox/ai-allowed-{box}`
   - No cryptographic enforcement
   - If AI agent has host access, can create/delete these files
   - **Completely bypassable**

5. **Snapshots Don't Protect Mounted Volumes**
   - Snapshots only capture container filesystem
   - Mounted host directories persist across snapshots
   - Backdoors in mounted volumes survive snapshot restore

6. **Host macOS Still Vulnerable**
   - Sandbox only protects containerized workloads
   - Host WiFi, Bluetooth, SSH still vulnerable
   - Host keychain still accessible
   - Host processes still running
   - **Host is weakest link**

### Recommendations

- **DO NOT** claim this is "secure" or "production-ready" without host hardening
- Use sb-dev only for trusted development work
- Monitor container activity
- Regularly review mounted volume contents
- Implement host-level security hardening
- Consider additional security layers (monitoring, alerting, etc.)

## Troubleshooting

### Containers won't start

1. Check Docker/OrbStack is running:
   ```bash
   docker info
   ```

2. Check docker-compose.yml syntax:
   ```bash
   docker-compose config
   ```

3. Check container logs:
   ```bash
   docker logs sb-dev
   docker logs sb-life
   docker logs sb-core
   ```

### Snapshot script fails

1. Check disk space (needs at least 1GB free)
2. Verify container is running: `sb status`
3. Check snapshot log: `cat ~/.sandbox/snapshots.log`

### LaunchAgent not running

1. Check if loaded:
   ```bash
   launchctl list | grep sandbox
   ```

2. Load manually:
   ```bash
   launchctl load ~/Library/LaunchAgents/com.sandbox.snapshot.plist
   ```

3. Check plist syntax:
   ```bash
   plutil -lint ~/Library/LaunchAgents/com.sandbox.snapshot.plist
   ```

### Permission errors

1. Ensure `~/.sandbox` directory exists and has correct permissions:
   ```bash
   ./scripts/setup-directories.sh
   ```

2. Check directory permissions:
   ```bash
   ls -ld ~/.sandbox
   ls -ld ~/.sandbox/shared
   ls -ld ~/.sandbox/core/secrets
   ```

## License

[Add your license here]
