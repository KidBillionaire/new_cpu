# The Sandbox — Solutions for Critical Flaws

## Critical Security Flaws — Solutions

### 1. Container Escape = Complete Host Compromise

#### Solution A: Host Hardening Layer
**Approach:** Add comprehensive macOS host hardening before container deployment
- Disable SSH, Remote Desktop, Bluetooth (except iPhone)
- Enable SIP, FileVault, Gatekeeper
- Implement firewall rules blocking Docker socket from containers
- Use `sudo` restrictions, remove Docker from sudoers
- Process monitoring with `ps aux` loops

**Justification:** Defense in depth. Even if container escapes, host is hardened. Docker socket protected by firewall. Multiple layers reduce attack surface.

**Rating: 8/10**
- Pros: Addresses root cause, comprehensive protection
- Cons: Complex, requires ongoing maintenance, doesn't prevent escape itself

#### Solution B: Rootless Docker + User Namespaces
**Approach:** Run Docker in rootless mode with strict user namespaces
- Install Docker rootless (`dockerd-rootless-setuptool.sh install`)
- Containers run as non-root user on host
- Even if escape occurs, attacker has limited host privileges
- Combine with AppArmor/SECCOMP profiles

**Justification:** Limits blast radius. Container escape doesn't grant root. User namespace isolation prevents privilege escalation to host root.

**Rating: 9/10**
- Pros: Architectural fix, prevents root access, modern best practice
- Cons: Some Docker features may not work, requires Docker rootless setup

---

### 2. Host Filesystem Exposed via Volume Mounts

#### Solution A: Read-Only Mounts + Copy-on-Write
**Approach:** Mount volumes as read-only, use copy-on-write for writes
- Mount `~/Code` as `:ro` (read-only)
- Use `docker volume` with copy-on-write for container writes
- Sync changes back via explicit `sb sync` command
- Audit all file changes before sync

**Justification:** Prevents malicious writes to host. Copy-on-write isolates changes. Explicit sync gives user control over what gets written back.

**Rating: 7/10**
- Pros: Prevents backdoor planting, user controls sync
- Cons: Workflow friction, sync process can be complex, may break dev tools

#### Solution B: Minimal Bind Mounts + File Filtering
**Approach:** Mount only specific subdirectories, filter file types
- Mount `~/Code/project1` not `~/Code` (granular)
- Use `docker run --read-only` with tmpfs for writes
- Block execution of files from mounts (`.git/hooks`, scripts)
- Scan mounted files with ClamAV/antivirus

**Justification:** Reduces attack surface. Granular mounts limit exposure. File filtering prevents execution of malicious code from mounts.

**Rating: 8/10**
- Pros: Flexible, maintains usability, prevents common attack vectors
- Cons: Requires careful configuration, file filtering can be bypassed

---

### 3. Shared Directory is Attack Vector

#### Solution A: Per-Container Isolated Shares
**Approach:** Remove global shared directory, use per-container shares
- `~/.sandbox/shared-dev` (dev only)
- `~/.sandbox/shared-life` (life only)  
- `~/.sandbox/shared-core` (core only)
- Use `sb transfer` command to move files between shares with scanning

**Justification:** Complete isolation. No cross-container contamination. Explicit transfer with scanning adds security layer.

**Rating: 9/10**
- Pros: True isolation, prevents lateral movement, explicit control
- Cons: More complex workflow, requires transfer mechanism

#### Solution B: Shared Directory with Access Control Lists
**Approach:** Keep shared directory but add ACLs and monitoring
- Implement file-level ACLs (dev:rw, life:r, core:r)
- Log all file access to shared directory
- Scan files on write with antivirus
- Alert on suspicious patterns (executables, scripts)

**Justification:** Maintains convenience while adding security. ACLs prevent unauthorized access. Monitoring detects attacks.

**Rating: 6/10**
- Pros: Maintains workflow, adds security layer
- Cons: ACLs can be complex, monitoring adds overhead, not true isolation

---

### 4. AI Permission System is File-Based (Trivial to Bypass)

#### Solution A: Cryptographic Permission Tokens
**Approach:** Replace file checks with signed tokens
- Generate cryptographic tokens per container: `sb ai token generate dev`
- Store tokens in macOS Keychain (encrypted)
- AI agent must present valid token to execute commands
- Tokens expire after 1 hour, require re-authentication
- Audit all AI operations with token ID

**Justification:** Cryptographically secure. Keychain integration uses macOS security. Expiration limits exposure. Audit trail enables forensics.

**Rating: 9/10**
- Pros: Secure, integrates with macOS, auditable
- Cons: More complex implementation, requires Keychain integration

#### Solution B: Process-Based Enforcement + TCC Integration
**Approach:** Check AI permissions at process level, integrate with TCC
- AI agent runs as separate process with specific entitlements
- Check permissions via `csrutil` or TCC database
- Block AI process from accessing containers without explicit grant
- Use macOS Privacy preferences to enforce

**Justification:** Uses native macOS security (TCC). Process-level enforcement harder to bypass. Integrates with system security model.

**Rating: 8/10**
- Pros: Native macOS integration, process-level security
- Cons: TCC integration complex, may require SIP modifications

---

### 5. Docker/OrbStack as Single Point of Failure

#### Solution A: Multi-Runtime Support + Fallback
**Approach:** Support multiple container runtimes with fallback
- Primary: Docker rootless
- Fallback: Podman (rootless, daemonless)
- Fallback: OrbStack (macOS-native)
- Runtime health checks, auto-switch on failure
- Abstract runtime behind `sb` CLI

**Justification:** Redundancy reduces single point of failure. Multiple runtimes = multiple attack surfaces, but also multiple fallbacks. Health checks ensure availability.

**Rating: 7/10**
- Pros: Redundancy, runtime diversity
- Cons: More complexity, larger attack surface, maintenance burden

#### Solution B: VM-Based Isolation Instead of Containers
**Approach:** Replace containers with lightweight VMs
- Use macOS Virtualization framework (native, no Docker)
- Each sandbox = separate VM (dev, life, core)
- VMs have stronger isolation than containers
- Snapshots via VM snapshots (faster than Docker commits)

**Justification:** VMs provide stronger isolation than containers. No Docker dependency. Native macOS integration. Harder to escape.

**Rating: 9/10**
- Pros: Stronger isolation, no Docker dependency, native macOS
- Cons: Higher resource usage, more complex implementation

---

### 6. Dev Container Has ALL Capabilities

#### Solution A: Capability Whitelist
**Approach:** Replace `cap_add: ALL` with specific capabilities
- Only grant needed caps: `NET_ADMIN`, `SYS_ADMIN` (if needed)
- Drop all others: `cap_drop: ALL` then `cap_add: [specific]`
- Document why each capability is needed
- Regular audit of capability usage

**Justification:** Principle of least privilege. Only grant what's needed. Reduces attack surface. Easier to audit.

**Rating: 9/10**
- Pros: Security best practice, reduces risk, auditable
- Cons: May break some dev tools, requires testing

#### Solution B: Separate Dev Containers by Task
**Approach:** Multiple specialized dev containers instead of one
- `sb-dev-code` (code editing, no network admin)
- `sb-dev-build` (build tools, no file system admin)
- `sb-dev-test` (testing, isolated network)
- Each has minimal capabilities for its task

**Justification:** Further reduces attack surface. Task-specific containers = minimal privileges per task. Compromise of one doesn't affect others.

**Rating: 8/10**
- Pros: Minimal privileges, task isolation
- Cons: More containers to manage, workflow complexity

---

### 7. No Monitoring or Alerting

#### Solution A: Comprehensive Logging + SIEM Integration
**Approach:** Add logging at all layers with SIEM
- Container logs → centralized logging (Loki, ELK)
- Host process monitoring → `ps aux` loops → log files
- Network monitoring → `tcpdump` on Docker bridge
- File system monitoring → `fs_usage` for mounted volumes
- Integrate with SIEM (Splunk, Elastic) for alerting
- Alert on: container escape attempts, privilege escalation, suspicious network

**Justification:** Visibility is security. Logging enables detection. SIEM provides correlation and alerting. File system monitoring catches backdoors.

**Rating: 8/10**
- Pros: Comprehensive visibility, enables detection, industry standard
- Cons: Complex setup, resource intensive, requires SIEM infrastructure

#### Solution B: Lightweight Built-in Monitoring
**Approach:** Simple monitoring built into `sb` CLI
- `sb monitor` command shows real-time stats
- Log container starts/stops to `~/.sandbox/monitor.log`
- Alert on: new processes in containers, network connections, file modifications
- Simple email/webhook alerts (no SIEM)
- `sb audit` command reviews logs

**Justification:** Simpler than SIEM, still provides visibility. Built-in means no external dependencies. Good enough for single-user setup.

**Rating: 7/10**
- Pros: Simple, no external deps, built-in
- Cons: Less sophisticated than SIEM, manual review required

---

### 8. Snapshots Don't Protect Mounted Volumes

#### Solution A: Volume Snapshots + Git Integration
**Approach:** Snapshot volumes separately, use Git for code
- Snapshot container images (as before)
- Snapshot volumes using `docker volume` snapshots
- For code: require Git, snapshot Git state
- `sb restore` restores both container and volumes
- Verify volume integrity before restore

**Justification:** Protects volumes too. Git integration for code is natural. Complete restore capability. Integrity checks prevent corruption.

**Rating: 8/10**
- Pros: Complete protection, Git integration natural
- Cons: More complex, volume snapshots can be large

#### Solution B: Copy-on-Write Volumes + Snapshot Metadata
**Approach:** Use copy-on-write volumes, snapshot metadata tracks changes
- All volumes are copy-on-write (CoW)
- Snapshot includes volume state metadata
- Restore reverts CoW layers
- Track which files changed between snapshots
- `sb diff` shows what changed

**Justification:** CoW is efficient. Metadata enables precise restore. Diff shows what changed, helps detect backdoors.

**Rating: 9/10**
- Pros: Efficient, precise restore, change tracking
- Cons: CoW implementation complex, requires storage driver support

---

### 9. No Network Isolation Between Containers

#### Solution A: Per-Container Networks + Firewall Rules
**Approach:** Each container on separate network, firewall between
- `sb-dev` → `dev-net` (isolated)
- `sb-life` → `life-net` (isolated)
- `sb-core` → no network (already)
- Firewall rules block inter-container communication
- Use `docker network` with `--internal` flag

**Justification:** Complete network isolation. Firewall provides defense in depth. Prevents lateral movement.

**Rating: 9/10**
- Pros: True isolation, prevents lateral movement
- Cons: Containers can't communicate (may break workflows)

#### Solution B: Network Policies + Service Mesh
**Approach:** Keep shared network but add policies
- Use Docker network policies or Cilium
- Define allowed connections (dev → shared service only)
- Encrypt inter-container traffic
- Monitor all network traffic
- Block suspicious connections

**Justification:** Maintains connectivity while adding security. Policies are flexible. Encryption protects data in transit.

**Rating: 7/10**
- Pros: Flexible, maintains connectivity, encrypted
- Cons: Complex setup, policies can be misconfigured

---

### 10. No Secret Management Integration

#### Solution A: macOS Keychain Integration
**Approach:** Store secrets in macOS Keychain, mount read-only
- Secrets stored in Keychain, not files
- `sb secrets set <key> <value>` stores in Keychain
- Containers access via `keychain-access` tool (read-only)
- No secrets in filesystem
- Keychain encryption + FileVault = double encryption

**Justification:** Uses native macOS security (Keychain). No secrets in files. Keychain encryption is strong. FileVault adds layer.

**Rating: 9/10**
- Pros: Native macOS, strong encryption, no file secrets
- Cons: Keychain integration requires macOS APIs

#### Solution B: Encrypted Volume + Key Management
**Approach:** Encrypt secrets volume, separate key management
- Create encrypted volume: `hdiutil create -encryption AES-256`
- Mount volume with password/key
- Store keys separately (hardware token, separate machine)
- Containers mount encrypted volume read-only
- Key rotation via `sb secrets rotate`

**Justification:** Strong encryption. Key separation adds security. Rotation capability. Works cross-platform.

**Rating: 8/10**
- Pros: Strong encryption, key separation, rotation
- Cons: More complex, key management overhead

---

## Design Flaws — Solutions

### 11. No Resource Limits

#### Solution A: Docker Resource Limits
**Approach:** Add resource limits to docker-compose.yml
```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 4G
    reservations:
      cpus: '1'
      memory: 2G
```

**Justification:** Prevents resource exhaustion. Standard Docker feature. Easy to implement.

**Rating: 10/10**
- Pros: Simple, effective, standard feature
- Cons: None

#### Solution B: Dynamic Resource Allocation
**Approach:** Monitor resource usage, dynamically adjust limits
- Track CPU/memory usage per container
- Auto-adjust limits based on usage patterns
- Alert on high usage
- `sb limits` command to view/adjust

**Justification:** More flexible than static limits. Adapts to workload. Prevents waste.

**Rating: 7/10**
- Pros: Flexible, adaptive
- Cons: Complex, may cause instability

---

### 12. Automatic Snapshots Can Fill Disk

#### Solution A: Snapshot Retention + Disk Space Monitoring
**Approach:** Monitor disk space, auto-cleanup old snapshots
- Check disk space before snapshot
- Keep only last N snapshots (configurable)
- Delete oldest when disk > 80% full
- Alert on low disk space
- `sb cleanup` manual cleanup command

**Justification:** Prevents disk full. Automatic cleanup reduces manual work. Alerts prevent surprises.

**Rating: 9/10**
- Pros: Prevents disk full, automatic, configurable
- Cons: May delete snapshots user wants to keep

#### Solution B: Compressed Snapshots + External Storage
**Approach:** Compress snapshots, option to store externally
- Compress snapshots (gzip, zstd)
- Option to store on external drive/cloud
- `sb snapshot --compress --backup s3://bucket`
- Local snapshots are compressed
- Restore from backup if local deleted

**Justification:** Reduces disk usage. External backup adds redundancy. Compression is efficient.

**Rating: 8/10**
- Pros: Saves space, backup capability
- Cons: Compression adds time, external storage complexity

---

### 13. No Update Mechanism

#### Solution A: Automated Base Image Updates
**Approach:** Regularly rebuild containers with updated base images
- `sb update` command rebuilds all containers
- Check for base image updates weekly
- Scan for vulnerabilities (Trivy, Snyk)
- Update packages in Dockerfiles
- Test before applying updates

**Justification:** Keeps containers secure. Automated reduces manual work. Vulnerability scanning finds issues.

**Rating: 8/10**
- Pros: Keeps secure, automated, scanning
- Cons: Updates may break things, requires testing

#### Solution B: Immutable Containers + Rebuild on Change
**Approach:** Containers are immutable, rebuild on any change
- No `apt-get upgrade` in running containers
- Changes trigger rebuild
- Base images updated via CI/CD
- Containers pulled from registry (versioned)
- `sb rebuild` forces rebuild

**Justification:** Immutability is security best practice. Rebuild ensures clean state. Versioned images enable rollback.

**Rating: 9/10**
- Pros: Immutable = secure, versioned, rollback capability
- Cons: Rebuilds take time, requires CI/CD

---

## Architecture Flaws — Solutions

### 14. Host macOS Completely Unprotected

#### Solution A: Integrated Host Hardening Script
**Approach:** Bundle host hardening with Sandbox install
- `sb harden` command applies macOS hardening
- Disables SSH, Remote Desktop, Bluetooth (except iPhone)
- Enables SIP, FileVault, Gatekeeper
- Configures firewall
- Sets up process monitoring
- Documents all changes

**Justification:** Addresses root cause. Integrated means one command. Comprehensive protection.

**Rating: 9/10**
- Pros: Comprehensive, integrated, addresses root cause
- Cons: May break user workflows, requires careful testing

#### Solution B: Host Hardening as Separate Module
**Approach:** Separate `sb-host` tool for host hardening
- `sb-host` is optional but recommended
- Can run independently of containers
- Provides hardening, monitoring, alerting
- Integrates with `sb` for unified view
- User chooses what to enable

**Justification:** Separation of concerns. Optional = less intrusive. User control.

**Rating: 7/10**
- Pros: Optional, user control, separation
- Cons: May not be used, less integrated

---

### 15. No Defense in Depth

#### Solution A: Multi-Layer Security Architecture
**Approach:** Implement security at multiple layers
- Layer 1: Host hardening (SIP, firewall, etc.)
- Layer 2: Container isolation (Docker/VM)
- Layer 3: Application sandboxing (within containers)
- Layer 4: Network segmentation
- Layer 5: Monitoring and alerting
- Each layer independently secure

**Justification:** Defense in depth is security best practice. Multiple layers = multiple failures needed. Reduces single point of failure.

**Rating: 10/10**
- Pros: Industry best practice, multiple failures needed
- Cons: More complex, more to maintain

#### Solution B: Security Profiles + Runtime Policies
**Approach:** Define security profiles, enforce at runtime
- Profiles: "paranoid", "secure", "permissive"
- Each profile applies different restrictions
- Runtime policies enforce restrictions
- `sb profile set paranoid` applies all restrictions
- Policies checked before container start

**Justification:** Flexible security levels. Profiles make it easy. Runtime enforcement ensures compliance.

**Rating: 8/10**
- Pros: Flexible, easy to use, enforced
- Cons: Profile management complexity

---

## Summary: Top Solutions by Rating

### 10/10 Solutions
1. **Docker Resource Limits** (Solution A for #11) - Simple, effective
2. **Multi-Layer Security Architecture** (Solution A for #15) - Best practice

### 9/10 Solutions
1. **Rootless Docker + User Namespaces** (#1-B) - Architectural fix
2. **VM-Based Isolation** (#5-B) - Stronger isolation
3. **Capability Whitelist** (#6-A) - Least privilege
4. **Cryptographic Permission Tokens** (#4-A) - Secure AI permissions
5. **Copy-on-Write Volumes** (#8-B) - Efficient protection
6. **Per-Container Networks** (#9-A) - True isolation
7. **macOS Keychain Integration** (#10-A) - Native security
8. **Immutable Containers** (#13-B) - Security best practice
9. **Integrated Host Hardening** (#14-A) - Addresses root cause

### Implementation Priority

**Phase 1 (Critical - Do First):**
- Host hardening (#14-A)
- Rootless Docker (#1-B) or VM isolation (#5-B)
- Capability restrictions (#6-A)
- Resource limits (#11-A)

**Phase 2 (High Priority):**
- Cryptographic AI permissions (#4-A)
- Volume protection (#8-B)
- Network isolation (#9-A)
- Monitoring (#7-A or #7-B)

**Phase 3 (Important):**
- Secret management (#10-A)
- Snapshot improvements (#12-A)
- Update mechanism (#13-B)

