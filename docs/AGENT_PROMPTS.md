# Agent Prompts for Sandbox Build

## 🚨 CRITICAL CONSTRAINTS FOR ALL AGENTS
- **NO** wildcard mounts (`*`, `**`)
- **NO** `cap_add: ALL` in production containers
- **NO** host Docker socket mounts
- **NO** passwordless sudo without explicit justification
- **NO** unverified downloads (checksums required)
- **NO** secrets in plaintext
- **NO** network access for sb-core
- **ALL** file paths must be explicit and absolute
- **ALL** scripts must validate inputs
- **ALL** operations must be idempotent

---

## Agent 1: Docker Compose Configuration

**Prompt:**
```
Create a docker-compose.yml file for a three-tier container sandbox system with these EXACT constraints:

REQUIREMENTS:
1. Three services: sb-dev, sb-life, sb-core
2. Network: Create bridge network "sandbox-net" - sb-core MUST have network_mode: none
3. sb-dev: cap_add: ALL (documented security risk), user: root, restart: unless-stopped
4. sb-life: cap_drop: ALL, user: sandbox (non-root), restart: unless-stopped, no sudo
5. sb-core: read_only: true, cap_drop: ALL, network_mode: none, tmpfs: /tmp, restart: unless-stopped

VOLUME MOUNTS (EXPLICIT PATHS ONLY):
- sb-dev & sb-life: 
  - ~/Code:/home/user/Code:rw
  - ~/Documents:/home/user/Documents:rw
  - ~/Desktop:/home/user/Desktop:rw
  - ~/.sandbox/shared:/shared:rw
- sb-core:
  - ~/.sandbox/core/secrets:/secrets:ro
  - ~/.sandbox/shared:/shared:ro

CONSTRAINTS:
- NO host Docker socket mounts
- NO wildcard paths
- NO system directory mounts (/usr, /bin, /etc, etc.)
- NO network_mode for sb-core (must be "none")
- Explicit image tags (no :latest)
- Environment: SANDBOX_ENV=production
- Labels: com.sandbox.type={dev|life|core}, com.sandbox.version=1.0.0

OUTPUT: Only docker-compose.yml, no explanations.
```

---

## Agent 2: sb-dev Dockerfile

**Prompt:**
```
Create Dockerfile.sb-dev for development container with these EXACT constraints:

BASE: ubuntu:24.04 (explicit tag, no :latest)

REQUIREMENTS:
1. Install: git, curl, vim, zsh, build-essential, sudo
2. Create user "dev" with UID 1000, GID 1000
3. Passwordless sudo for dev user (document security risk in comments)
4. Install oh-my-zsh BUT verify checksum: SHA256 must match published value
5. Set working directory: /home/dev
6. Default user: root (will run as root per docker-compose)

CONSTRAINTS:
- NO package version pinning required BUT document why
- NO downloads without checksum verification
- NO hardcoded secrets
- NO network services exposed
- All RUN commands must be idempotent
- Use explicit package versions where security-critical
- Add security comment: "# SECURITY RISK: cap_add: ALL allows container escape"

OUTPUT: Only Dockerfile.sb-dev, no explanations.
```

---

## Agent 3: sb-life Dockerfile

**Prompt:**
```
Create Dockerfile.sb-life for restricted daily-use container with these EXACT constraints:

BASE: ubuntu:24.04 (explicit tag)

REQUIREMENTS:
1. Install: git, curl, wget, vim, less (minimal toolset)
2. Create user "sandbox" with UID 1001, GID 1001
3. NO sudo installation
4. NO build tools
5. NO root capabilities
6. Set working directory: /home/sandbox
7. Default user: sandbox

CONSTRAINTS:
- cap_drop: ALL enforced (no capabilities)
- NO passwordless sudo
- NO development tools
- NO network daemons
- All packages must be from official Ubuntu repos
- User must NOT be in sudo group
- Add comment: "# SECURITY: Restricted user, no sudo, cap_drop: ALL"

OUTPUT: Only Dockerfile.sb-life, no explanations.
```

---

## Agent 4: sb-core Dockerfile

**Prompt:**
```
Create Dockerfile.sb-core for read-only secrets container with these EXACT constraints:

BASE: ubuntu:24.04 (explicit tag)

REQUIREMENTS:
1. Install ONLY: vim, less (minimal for secret viewing)
2. Create user "core" with UID 1002, GID 1002
3. NO network tools (no curl, wget, git)
4. NO sudo
5. Create directory: /secrets (will be mounted read-only)
6. Set working directory: /secrets
7. Default user: core

CONSTRAINTS:
- read_only: true enforced
- network_mode: none (no network)
- cap_drop: ALL
- tmpfs: /tmp (only writable location)
- NO packages that require network at runtime
- NO build tools
- Minimal attack surface
- Add comment: "# SECURITY: Read-only, no network, cap_drop: ALL, tmpfs: /tmp only"

OUTPUT: Only Dockerfile.sb-core, no explanations.
```

---

## Agent 5: CLI Script (sb)

**Prompt:**
```
Create a bash script "sb" for managing the sandbox with these EXACT constraints:

COMMANDS REQUIRED:
1. `sb start [dev|life|core]` - Start container(s)
2. `sb stop [dev|life|core]` - Stop container(s)
3. `sb status` - Show status of all containers
4. `sb shell [dev|life|core]` - Open shell in container
5. `sb snapshot [dev|life|core] [name]` - Create snapshot
6. `sb restore [dev|life|core] [snapshot-name]` - Restore snapshot
7. `sb ai allow [dev|life|core]` - Allow AI access
8. `sb ai deny [dev|life|core]` - Deny AI access
9. `sb ai status` - Show AI permissions

CONSTRAINTS:
- MUST validate all inputs (container names, snapshot names)
- MUST check Docker/OrbStack is running before operations
- MUST use explicit container names: sb-dev, sb-life, sb-core
- MUST create ~/.sandbox directory structure if missing
- AI permissions: Create/delete ~/.sandbox/ai-allowed-{box} files
- Snapshot names: Format: {container}-{timestamp}-{name}
- NO command injection vulnerabilities (quote all variables)
- NO operations on non-existent containers
- Exit codes: 0=success, 1=error, 2=invalid input
- All docker commands must use explicit container names
- Error messages must be clear and actionable

SECURITY:
- Validate container names against whitelist: dev, life, core
- Sanitize snapshot names (alphanumeric, dash, underscore only)
- Check file permissions on ~/.sandbox directory
- Log all operations to ~/.sandbox/sb.log

OUTPUT: Only the sb script, executable, no explanations.
```

---

## Agent 6: Snapshot Script

**Prompt:**
```
Create snapshot.sh script for automated snapshots with these EXACT constraints:

FUNCTIONALITY:
1. Create snapshot of specified container: sb-dev, sb-life, or sb-core
2. Snapshot name format: {container}-{YYYYMMDD-HHMMSS}-auto
3. Keep only last 24 snapshots per container
4. Delete oldest snapshots beyond limit
5. Log all operations to ~/.sandbox/snapshots.log

CONSTRAINTS:
- MUST validate container name (whitelist: sb-dev, sb-life, sb-core)
- MUST check container exists and is running
- MUST use docker commit with explicit tag format
- MUST handle errors gracefully (no partial snapshots)
- MUST verify snapshot creation succeeded before cleanup
- Cleanup: List snapshots, sort by date, keep newest 24, delete rest
- NO snapshots if disk space < 1GB free (check first)
- Atomic operations: Create snapshot, verify, then cleanup
- Exit codes: 0=success, 1=error, 2=insufficient space

SECURITY:
- Validate container names (prevent injection)
- Check disk space before operations
- Verify docker commit succeeded (check image exists)
- Log all snapshot operations with timestamps

OUTPUT: Only snapshot.sh script, executable, no explanations.
```

---

## Agent 7: Install Script

**Prompt:**
```
Create install.sh script for sandbox installation with these EXACT constraints:

INSTALLATION STEPS:
1. Check Docker/OrbStack is installed and running
2. Create directory structure: ~/.sandbox/{shared,core/secrets}
3. Set permissions: 700 for ~/.sandbox, 755 for subdirs
4. Build Docker images: sb-dev, sb-life, sb-core
5. Create docker-compose.yml if not exists
6. Start containers
7. Create LaunchAgent for hourly snapshots

CONSTRAINTS:
- MUST verify Docker/OrbStack before proceeding
- MUST check if directories exist (idempotent)
- MUST verify docker build succeeded for each image
- MUST validate docker-compose.yml syntax
- MUST create LaunchAgent plist with correct paths
- NO operations if Docker not running
- Rollback: If any step fails, stop and report error
- Exit codes: 0=success, 1=docker not found, 2=build failed, 3=permission error

SECURITY:
- Check Docker socket permissions
- Verify user has permission to create ~/.sandbox
- Validate LaunchAgent plist syntax
- No sudo required (user-level installation)

DIRECTORY STRUCTURE:
- ~/.sandbox/ (700)
- ~/.sandbox/shared/ (755)
- ~/.sandbox/core/ (700)
- ~/.sandbox/core/secrets/ (700)

OUTPUT: Only install.sh script, executable, no explanations.
```

---

## Agent 8: LaunchAgent Plist

**Prompt:**
```
Create LaunchAgent plist file for hourly snapshots with these EXACT constraints:

FILE: ~/Library/LaunchAgents/com.sandbox.snapshot.plist

REQUIREMENTS:
1. Run snapshot.sh every hour
2. Rotate snapshots for all three containers: sb-dev, sb-life, sb-core
3. Log output to ~/.sandbox/snapshots.log
4. Start on user login
5. Keep running if script fails (restart on failure)

CONSTRAINTS:
- MUST use absolute paths for all executables
- MUST specify WorkingDirectory
- MUST redirect stdout/stderr to log file
- MUST use StartInterval (3600 seconds)
- MUST set RunAtLoad: true
- NO hardcoded usernames (use ~ expansion or $HOME)
- StandardOutput and StandardError must point to log file
- ProgramArguments must call snapshot.sh with container names

SECURITY:
- No elevated privileges
- User-level agent only
- No network access required
- Validate plist syntax (plutil -lint)

OUTPUT: Only the plist XML, no explanations.
```

---

## Agent 9: Directory Structure Setup

**Prompt:**
```
Create setup-directories.sh script to create sandbox directory structure with these EXACT constraints:

DIRECTORIES TO CREATE:
1. ~/.sandbox/ (permissions: 700)
2. ~/.sandbox/shared/ (permissions: 755)
3. ~/.sandbox/core/ (permissions: 700)
4. ~/.sandbox/core/secrets/ (permissions: 700)

CONSTRAINTS:
- MUST be idempotent (safe to run multiple times)
- MUST check if directories exist before creating
- MUST set correct permissions (chmod)
- MUST handle errors gracefully
- MUST verify permissions after creation
- NO operations if parent directory doesn't exist
- Exit codes: 0=success, 1=permission error, 2=creation failed

SECURITY:
- Verify ~ (home directory) exists and is writable
- Check current user owns ~/.sandbox (or will own it)
- Set restrictive permissions (700 for secrets, 755 for shared)
- No sudo required

OUTPUT: Only setup-directories.sh script, executable, no explanations.
```

---

## Agent 10: README Update

**Prompt:**
```
Update README.md with installation and usage instructions with these EXACT constraints:

SECTIONS REQUIRED:
1. Installation (run install.sh)
2. Usage (sb command reference)
3. Security Warnings (document known risks)
4. File Structure (directory layout)
5. Troubleshooting (common issues)

CONSTRAINTS:
- MUST document security risks (cap_add: ALL, volume mounts, etc.)
- MUST include all sb commands with examples
- MUST explain three-tier architecture
- MUST warn about host filesystem exposure
- MUST include security limitations section
- NO false security claims
- Clear about what is/isn't protected

SECURITY DISCLOSURES REQUIRED:
- sb-dev has cap_add: ALL (container escape risk)
- Volume mounts expose host filesystem
- Shared directory is cross-container attack vector
- AI permissions are file-based (bypassable)
- Snapshots don't protect mounted volumes
- Host macOS still vulnerable

OUTPUT: Updated README.md section, no explanations.
```

---

## 🎯 EXECUTION ORDER

1. **Agent 9** → Setup directories first
2. **Agent 2, 3, 4** → Build Dockerfiles (can be parallel)
3. **Agent 1** → Create docker-compose.yml
4. **Agent 5** → Create sb CLI script
5. **Agent 6** → Create snapshot.sh
6. **Agent 8** → Create LaunchAgent plist
7. **Agent 7** → Create install.sh (depends on all above)
8. **Agent 10** → Update README

---

## 🔒 VALIDATION CHECKLIST (Run After Build)

- [ ] No `cap_add: ALL` except sb-dev (documented)
- [ ] sb-core has `network_mode: none`
- [ ] All volume mounts use explicit paths (no wildcards)
- [ ] No Docker socket mounts
- [ ] All scripts validate inputs
- [ ] All scripts check Docker is running
- [ ] Snapshot cleanup works (24 limit)
- [ ] AI permission files created correctly
- [ ] Directory permissions correct (700 for secrets, 755 for shared)
- [ ] LaunchAgent plist syntax valid
- [ ] No secrets in plaintext in code
- [ ] All file paths are absolute or use ~ expansion

---

## ⚠️ CRITICAL SECURITY REMINDERS

1. **sb-dev is DANGEROUS** - cap_add: ALL = container escape = host root
2. **Volume mounts expose host** - Compromised container = host file access
3. **Shared directory is attack vector** - Cross-container contamination possible
4. **AI permissions are bypassable** - File-based, no cryptographic enforcement
5. **Snapshots don't protect volumes** - Mounted directories persist across snapshots
6. **Host macOS unprotected** - Sandbox only protects containers, not host system

**DO NOT** claim this is "secure" or "production-ready" without host hardening.
