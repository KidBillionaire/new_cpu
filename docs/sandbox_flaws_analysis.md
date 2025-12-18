# The Sandbox — Critical Flaws Analysis

## Critical Security Flaws

### 1. **Container Escape = Complete Host Compromise**
**Severity: CRITICAL**

- If attacker escapes `sb-dev` (which has `cap_add: ALL`), they have full access to Docker socket
- Docker socket access = root on host macOS
- No additional host hardening means complete system takeover
- **Impact**: One container escape = total compromise

**Attack Path:**
```
sb-dev (cap_add: ALL) → Docker socket access → Host root → Everything
```

### 2. **Host Filesystem Exposed via Volume Mounts**
**Severity: CRITICAL**

- `~/Code`, `~/Documents`, `~/Desktop` are mounted with full read/write
- If container compromised, attacker can:
  - Plant backdoors in user directories
  - Access all user files
  - Modify code repositories
  - Access `.ssh/`, `.aws/`, other credentials in home directory
- No file-level access control or monitoring

**Example Attack:**
```bash
# From compromised sb-dev:
echo "malicious code" >> ~/Code/project/.git/hooks/pre-commit
# Now runs on every git commit on host
```

### 3. **Shared Directory is Attack Vector**
**Severity: HIGH**

- `~/.sandbox/shared` mounted in ALL containers (dev, life, core)
- Compromised `sb-dev` can write to shared
- `sb-life` or `sb-core` can read malicious files
- No access control, no scanning, no isolation
- **Cross-container contamination vector**

### 4. **AI Permission System is File-Based (Trivial to Bypass)**
**Severity: HIGH**

- AI permissions stored as simple files: `~/.sandbox/ai-allowed-{box}`
- No enforcement mechanism - just file existence check
- If AI agent has host access, can create/delete these files
- No cryptographic signing, no audit trail
- **Completely bypassable**

**Bypass:**
```bash
# AI agent on host (not in container):
touch ~/.sandbox/ai-allowed-core
# Now "allowed" in core, despite architecture
```

### 5. **No Network Isolation Between Containers**
**Severity: MEDIUM-HIGH**

- All containers on `sandbox-net` bridge network
- `sb-dev` can potentially access `sb-life` or `sb-core` services
- No firewall rules between containers
- Network traffic not encrypted
- **Lateral movement possible**

### 6. **Snapshot System Doesn't Protect Against Persistence**
**Severity: HIGH**

- Snapshots are container images only
- **Volume mounts persist across snapshots**
- Attacker can:
  1. Compromise container
  2. Plant backdoor in mounted volume (`~/Code`, `~/Documents`)
  3. Snapshot taken (includes backdoor)
  4. Restore snapshot → backdoor still in mounted volume
- **Snapshots give false sense of security**

### 7. **Core Container "Read-Only" is Misleading**
**Severity: MEDIUM**

- Core has `read_only: true` but has `tmpfs: /tmp`
- Attacker can write to `/tmp` (temporary files)
- Can execute scripts from `/tmp`
- Can download tools to `/tmp` and run them
- **Not actually read-only for execution**

### 8. **No Secret Management Integration**
**Severity: MEDIUM**

- Secrets stored in `~/.sandbox/core/secrets` on **host filesystem**
- Host compromise = secret compromise
- No encryption at rest
- No key management
- No rotation mechanism
- **Secrets only as secure as host**

### 9. **Docker/OrbStack as Single Point of Failure**
**Severity: CRITICAL**

- Entire security model depends on Docker/OrbStack security
- Docker daemon runs as root on host
- Docker vulnerabilities = complete bypass
- No defense in depth
- **All eggs in one basket**

### 10. **No Monitoring or Alerting**
**Severity: MEDIUM**

- No detection of container escape attempts
- No logging of suspicious activity
- No alerts on privilege escalation
- No network traffic monitoring
- **Blind to attacks**

## Design Flaws

### 11. **Dev Container Has ALL Capabilities**
**Severity: HIGH**

- `cap_add: ALL` in dev container
- Can mount host filesystems
- Can access host devices
- Can modify kernel parameters
- Can escape container easily
- **Defeats purpose of isolation**

### 12. **No Resource Limits**
**Severity: MEDIUM**

- No CPU limits
- No memory limits
- No disk quotas
- Malicious container can DoS host
- **Resource exhaustion attacks possible**

### 13. **Automatic Snapshots Can Fill Disk**
**Severity: LOW-MEDIUM**

- Hourly snapshots with only 24 retention
- But if containers are large, 24 snapshots = significant disk
- No cleanup on disk full
- No warning before disk full
- **Can crash system**

### 14. **Install Script Has No Verification**
**Severity: MEDIUM**

- Downloads/installs without checksums
- No signature verification
- No integrity checks
- **Supply chain attack vector**

### 15. **No Update Mechanism**
**Severity: MEDIUM**

- Containers built once, never updated
- Base images (ubuntu:24.04) will have vulnerabilities
- No automated patching
- **Stale, vulnerable containers**

## Operational Flaws

### 16. **No Backup of Snapshots**
**Severity: MEDIUM**

- Snapshots stored locally only
- Host disk failure = lose all snapshots
- No offsite backup
- **Single point of failure**

### 17. **Restore Process is Manual and Error-Prone**
**Severity: MEDIUM**

- Restore requires manual snapshot selection
- No verification that restore worked
- No rollback if restore breaks things
- **High risk of mistakes**

### 18. **No Health Checks**
**Severity: LOW-MEDIUM**

- Containers can be running but broken
- No automatic restart on failure
- No status monitoring
- **Silent failures**

### 19. **CLI Script Has No Input Validation**
**Severity: LOW-MEDIUM**

- `sb` script doesn't validate inputs
- Can pass malicious arguments
- Potential command injection
- **Script injection risk**

### 20. **No Multi-User Support**
**Severity: LOW**

- Designed for single user
- All containers share same user context
- No user isolation
- **Not suitable for shared systems**

## Architecture Flaws

### 21. **Host macOS Completely Unprotected**
**Severity: CRITICAL**

- The Sandbox protects containers, not host
- Host WiFi, Bluetooth, SSH still vulnerable
- Host keychain still accessible
- Host processes still running
- **Host is weakest link**

### 22. **No Defense in Depth**
**Severity: HIGH**

- Single layer of protection (containers)
- No host hardening
- No network segmentation
- No application-level controls
- **All-or-nothing security**

### 23. **False Sense of Security**
**Severity: HIGH**

- Users may think they're "fully protected"
- Actually only protected from container-based attacks
- Host attacks still work
- **Complacency risk**

### 24. **No Integration with macOS Security Features**
**Severity: MEDIUM**

- Doesn't use SIP
- Doesn't use Gatekeeper
- Doesn't use TCC
- Doesn't use FileVault
- **Ignores native security**

### 25. **Container Images Are Large Attack Surface**
**Severity: MEDIUM**

- Ubuntu base images have many packages
- Each package = potential vulnerability
- No minimal base images
- No scanning for vulnerabilities
- **Large attack surface**

## Specific Implementation Flaws

### 26. **Dockerfile Security Issues**

**sb-dev Dockerfile:**
- Installs packages without pinning versions
- Downloads oh-my-zsh without verification
- No security updates after install
- Creates passwordless sudo (security risk)

**sb-life Dockerfile:**
- Installs curl/wget (can download malware)
- No package version pinning

**sb-core Dockerfile:**
- Minimal but still has vim/less (unnecessary)

### 27. **docker-compose.yml Issues**

- `restart: unless-stopped` means containers auto-start
- No health checks
- No resource limits
- No security options (seccomp, apparmor)
- Network bridge allows inter-container communication

### 28. **CLI Script (`sb`) Issues**

- No error handling in many places
- Uses `docker ps | grep` (fragile)
- No validation of container names
- Snapshot names use timestamps (collision risk)
- No atomic operations

### 29. **Snapshot Script Issues**

- `snapshot.sh` doesn't handle errors
- Cleanup logic is complex and error-prone
- No verification snapshots are valid
- No compression (wasteful)

### 30. **Install Script Issues**

- Assumes Docker/OrbStack installed (no check)
- Creates directories without checking permissions
- Copies files without verification
- No rollback on failure
- No uninstall mechanism

## Threat Model Gaps

### 31. **Doesn't Address Original Threat Vectors**

From your original threat model, The Sandbox **doesn't solve**:

- ❌ **WiFi attacks** - Host WiFi still vulnerable
- ❌ **Bluetooth attacks** - Host Bluetooth still vulnerable  
- ❌ **SSH attacks** - Host SSH still vulnerable
- ❌ **Remote Desktop** - Host RDP still vulnerable
- ❌ **Notification spoofing** - Host notifications still vulnerable
- ❌ **Keychain attacks** - Host keychain still accessible
- ❌ **Kernel attacks** - Host kernel still vulnerable
- ❌ **Plist modification** - Host plists still modifiable
- ❌ **Handoff attacks** - Host Continuity still active
- ❌ **Keyboard attacks** - Host keyboard still vulnerable
- ❌ **Agent attacks** - Host LaunchDaemons still vulnerable

**The Sandbox only protects containerized workloads, not the host system.**

## Summary: Critical Flaws

### Must Fix (P0)
1. Container escape = host compromise (no host hardening)
2. Volume mounts expose host filesystem
3. Shared directory is cross-container attack vector
4. AI permissions are trivial to bypass
5. Docker as single point of failure

### Should Fix (P1)
6. Dev container has ALL capabilities
7. No monitoring/alerting
8. Snapshots don't protect mounted volumes
9. No network isolation between containers
10. No secret encryption

### Nice to Fix (P2)
11. No resource limits
12. No health checks
13. No backup mechanism
14. Stale container images
15. No input validation

## Recommendations

1. **Add host hardening** - Don't rely on containers alone
2. **Restrict dev capabilities** - Remove `cap_add: ALL`
3. **Encrypt secrets** - Use proper key management
4. **Add monitoring** - Detect container escapes
5. **Isolate networks** - Firewall between containers
6. **Scan images** - Vulnerability scanning
7. **Limit volumes** - Minimal, read-only mounts
8. **Add defense in depth** - Multiple security layers
9. **Integrate with macOS** - Use SIP, Gatekeeper, TCC
10. **Document limitations** - Clear about what it doesn't protect


