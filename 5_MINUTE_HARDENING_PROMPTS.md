# 5-Minute Parallel Security Hardening Prompts

## 🚀 **EXECUTION STRATEGY**
- **Parallel Execution**: Run multiple prompts simultaneously
- **Time Constraint**: Each prompt designed for 5-minute completion
- **Tuned Constraints**: Highly specific, minimal dependencies
- **Immediate Impact**: Each prompt delivers tangible security improvement

---

## **PHASE 1: SYSTEM HARDENING (2 prompts × 5 min)**

### **Prompt 1: Gatekeeper & SIP Configuration**
```
Create a bash script called `harden_system_security.sh` that:

1. Configures Gatekeeper with strict settings:
   - Enable global Gatekeeper
   - Allow only App Store and identified developers
   - Block unsigned applications
   - Show current status before/after

2. Checks SIP (System Integrity Protection) status:
   - Display current SIP configuration
   - Enable all SIP protections if disabled
   - Show reboot requirement if needed
   - Provide verification commands

3. Include safety mechanisms:
   - Backup current settings before changes
   - Require sudo with proper error handling
   - Provide rollback capability
   - Clear success/failure indicators

Constraints:
- Use only built-in macOS commands (spctl, csrutil)
- Must work on macOS Monterey+ (12.x+)
- Include status output for each command
- Complete in 5 minutes of execution time
- Handle authorization errors gracefully
```

### **Prompt 2: Privacy Controls & Audit Setup**
```
Create a bash script called `setup_privacy_controls.sh` that:

1. Configures TCC (Transparency, Consent, and Control) privacy:
   - Reset and configure Camera access
   - Reset and configure Microphone access
   - Reset and configure Screen Recording access
   - Reset and configure Files and Folders access
   - Show current privacy settings

2. Enable and configure audit logging:
   - Enable audit daemon if disabled
   - Configure basic audit rules for security events
   - Set log rotation to prevent disk bloat
   - Display current audit configuration

3. Set basic security preferences:
   - Disable automatic file sharing
   - Configure secure screensaver settings
   - Disable remote login if enabled
   - Show current vs new settings

Constraints:
- Use only built-in macOS commands (tccutil, audit, defaults)
- Must run in 5 minutes on macOS Monterey+
- Include backup/rollback for changed settings
- Provide clear status output for each operation
- Handle permission errors with helpful messages
```

---

## **PHASE 2: NETWORK SECURITY (2 prompts × 5 min)**

### **Prompt 3: Firewall & DNS Hardening**
```
Create a bash script called `harden_network_security.sh` that:

1. Configures Application Firewall:
   - Enable global firewall state
   - Block all incoming connections by default
   - Enable stealth mode
   - Add specific allowed applications (Terminal, etc.)
   - Show current firewall configuration

2. Implement basic DNS security:
   - Configure encrypted DNS (if available)
   - Set fallback DNS servers (9.9.9.9, 1.1.1.1)
   - Clear and reset DNS cache
   - Test DNS resolution

3. Configure network privacy:
   - Disable Bonjour advertising if not needed
   - Configure netbios name services
   - Show network interface security status
   - Provide verification commands

Constraints:
- Use socketfilterfw and networksetup commands
- Must complete in 5 minutes
- Support macOS Monterey+ (12.x+)
- Include firewall rule verification
- Handle DNS configuration safely
```

### **Prompt 4: Host File & Network Monitoring**
```
Create a bash script called `setup_host_monitoring.sh` that:

1. Hardens /etc/hosts file:
   - Backup current hosts file
   - Add security-focused entries (block malware domains)
   - Set proper file permissions (read-only)
   - Validate hosts file syntax

2. Set up basic network monitoring:
   - Enable network connection logging
   - Configure process network monitoring
   - Set up basic intrusion detection rules
   - Create monitoring log directory

3. Configure network time security:
   - Enable time synchronization with secure servers
   - Configure NTP authentication if available
   - Show current time synchronization status
   - Test connectivity to time servers

Constraints:
- Use only built-in macOS commands
- Must run in 5 minutes
- Include validation for hosts file
- Set up proper log rotation
- Provide verification of each configuration
```

---

## **PHASE 3: ADVANCED CONTROLS (2 prompts × 5 min)**

### **Prompt 5: File Integrity Monitoring**
```
Create a bash script called `setup_file_integrity.sh` that:

1. Set up file integrity monitoring:
   - Configure monitoring for critical system files
   - Monitor /etc, /usr/bin, /Applications directories
   - Create baseline hash database
   - Set up monitoring scripts with checksums

2. Configure security notification:
   - Create alert mechanisms for file changes
   - Set up logging for integrity violations
   - Configure notification thresholds
   - Test monitoring system

3. Implement scheduled verification:
   - Set up daily integrity checks
   - Configure automated reporting
   - Create backup of integrity data
   - Provide verification commands

Constraints:
- Use built-in tools (shasum, find, launchd)
- Must complete in 5 minutes execution time
- Support macOS Monterey+ (12.x+)
- Include proper error handling
- Provide clear status output
```

### **Prompt 6: Kernel Extension & Security**
```
Create a bash script called `harden_kernel_security.sh` that:

1. Audit and secure kernel extensions:
   - List all currently loaded kernel extensions
   - Identify unsigned or suspicious extensions
   - Configure system extension policies
   - Show extension security status

2. Configure secure startup settings:
   - Check and set secure boot configuration
   - Configure external boot restrictions
   - Set password requirements for firmware
   - Show current secure boot status

3. Implement system extension monitoring:
   - Set up monitoring for new extensions
   - Configure alerts for extension changes
   - Create baseline of approved extensions
   - Test monitoring system

Constraints:
- Use kextstat, systemextensionsctl commands
- Must run in 5 minutes on macOS Monterey+
- Include backup of current configurations
- Provide rollback capability
- Handle authorization errors gracefully
```

---

## **PARALLEL EXECUTION PLAN**

### **Wave 1 (Immediate - 2 prompts)**
```bash
# Terminal 1: System Security
# Prompt 1: Gatekeeper & SIP Configuration

# Terminal 2: Privacy Controls
# Prompt 2: TCC & Audit Setup
```

### **Wave 2 (After Wave 1 - 2 prompts)**
```bash
# Terminal 3: Network Security
# Prompt 3: Firewall & DNS Hardening

# Terminal 4: Host Monitoring
# Prompt 4: Host File & Network Monitoring
```

### **Wave 3 (After Wave 2 - 2 prompts)**
```bash
# Terminal 5: File Integrity
# Prompt 5: File Integrity Monitoring

# Terminal 6: Kernel Security
# Prompt 6: Kernel Extension & Security
```

## 🎯 **EXPECTED OUTCOMES**

### **After 15 minutes (3 waves):**
- ✅ **System Hardening**: Gatekeeper, SIP, Privacy Controls configured
- ✅ **Network Security**: Firewall, DNS, Monitoring setup
- ✅ **Advanced Controls**: File integrity, Kernel security implemented

### **Security Improvement: +15%**
- **Current**: 85% → **Target**: 100%
- **Attack Surface Reduction**: Significant
- **Compliance**: Enterprise-level security posture

## 📋 **EXECUTION CHECKLIST**

### **Before Starting:**
- [ ] Full system backup (Time Machine)
- [ ] Sudo access available
- [ ] Terminal with multiple tabs ready
- [ ] Internet connectivity for verification

### **During Execution:**
- [ ] Run scripts in parallel waves
- [ ] Monitor for error messages
- [ ] Verify each script completion
- [ ] Document any issues encountered

### **After Completion:**
- [ ] Run verification script
- [ ] Test system functionality
- [ ] Review security status
- [ ] Document final configuration

## ⚡ **SPEED OPTIMIZATION**

### **5-Minute Constraints:**
- **Minimal Dependencies**: Use only built-in macOS tools
- **Efficient Commands**: Combine operations where possible
- **Parallel Processing**: Run multiple configurations simultaneously
- **Pre-written Logic**: Complex decision trees pre-implemented
- **Status Optimization**: Clear, concise output formatting

### **Tuned Parameters:**
- **Timeout Settings**: 30-second command timeouts
- **Error Recovery**: Automated rollback on failure
- **Verification**: Built-in success/failure detection
- **Logging**: Minimal overhead logging
- **Resource Usage**: Low CPU/memory footprint

---

**Total Time Investment: 15 minutes**
**Security Improvement: 15 percentage points**
**Risk Reduction: Significant immediate security posture enhancement**