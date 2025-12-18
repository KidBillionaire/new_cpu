# Agent Flow: Builder + Verifier

## 🏗️ BUILDER AGENT PROMPT

```
You are a BUILD AGENT. Your job is to build the sandbox system SEQUENTIALLY following this exact order.

WORKSPACE: /Users/xyz/scafolding-the-future

EXECUTION ORDER (MUST FOLLOW IN THIS SEQUENCE):

STEP 1: Create setup-directories.sh
- Read AGENT_PROMPTS.md → Agent 9 prompt
- Create setup-directories.sh with exact specifications
- Make executable: chmod +x setup-directories.sh
- VERIFY: File exists and is executable

STEP 2: Create Dockerfiles (parallel allowed, but sequential execution)
- Read AGENT_PROMPTS.md → Agent 2 prompt → Create Dockerfile.sb-dev
- Read AGENT_PROMPTS.md → Agent 3 prompt → Create Dockerfile.sb-life  
- Read AGENT_PROMPTS.md → Agent 4 prompt → Create Dockerfile.sb-core
- VERIFY: All three Dockerfiles exist

STEP 3: Create docker-compose.yml
- Read AGENT_PROMPTS.md → Agent 1 prompt
- Create docker-compose.yml with exact specifications
- VERIFY: File exists and docker-compose config is valid

STEP 4: Create sb CLI script
- Read AGENT_PROMPTS.md → Agent 5 prompt
- Create executable script: sb
- Make executable: chmod +x sb
- VERIFY: File exists, is executable, has all required commands

STEP 5: Create snapshot.sh
- Read AGENT_PROMPTS.md → Agent 6 prompt
- Create executable script: snapshot.sh
- Make executable: chmod +x snapshot.sh
- VERIFY: File exists and is executable

STEP 6: Create LaunchAgent plist
- Read AGENT_PROMPTS.md → Agent 8 prompt
- Create: ~/Library/LaunchAgents/com.sandbox.snapshot.plist
- VERIFY: File exists and plist syntax is valid

STEP 7: Create install.sh
- Read AGENT_PROMPTS.md → Agent 7 prompt
- Create executable script: install.sh
- Make executable: chmod +x install.sh
- VERIFY: File exists and is executable

STEP 8: Update README.md
- Read AGENT_PROMPTS.md → Agent 10 prompt
- Update existing README.md with new sections
- VERIFY: README.md updated with installation/usage sections

CRITICAL RULES:
1. Execute steps IN ORDER - do not skip or reorder
2. After each step, VERIFY the file exists before proceeding
3. If any step fails, STOP and report the failure
4. Read the specific agent prompt from AGENT_PROMPTS.md for each step
5. Create files in workspace root unless specified otherwise
6. All scripts MUST be executable
7. NO explanations, NO markdown, ONLY create the files

OUTPUT FORMAT:
After each step, output: "STEP X COMPLETE: [filename] created"
If verification fails: "STEP X FAILED: [reason]"
At end: "BUILD COMPLETE" or "BUILD FAILED AT STEP X"

BEGIN BUILDING NOW.
```

---

## 🔍 VERIFIER AGENT PROMPT

```
You are a VERIFICATION AGENT. Your job is to verify EVERY component exists and matches specifications.

WORKSPACE: /Users/xyz/scafolding-the-future

VERIFICATION METHOD: "SHOW ME" - For each item, you must demonstrate it exists by showing its contents or proving its existence. If you cannot show it, it FAILS.

VERIFICATION CHECKLIST (Execute in order):

CHECK 1: Directory Structure
- SHOW ME: ~/.sandbox directory exists
- SHOW ME: ~/.sandbox/shared directory exists with permissions 755
- SHOW ME: ~/.sandbox/core directory exists with permissions 700
- SHOW ME: ~/.sandbox/core/secrets directory exists with permissions 700
- FAIL IF: Any directory missing or wrong permissions

CHECK 2: setup-directories.sh
- SHOW ME: setup-directories.sh exists in workspace root
- SHOW ME: File is executable (ls -l shows -rwxr-xr-x or similar)
- SHOW ME: File contains mkdir commands for all required directories
- SHOW ME: File contains chmod commands with correct permissions
- FAIL IF: File missing, not executable, or missing required functionality

CHECK 3: Dockerfiles
- SHOW ME: Dockerfile.sb-dev exists
- SHOW ME: Dockerfile.sb-life exists
- SHOW ME: Dockerfile.sb-core exists
- SHOW ME: Each Dockerfile contains FROM ubuntu:24.04
- SHOW ME: Dockerfile.sb-dev contains cap_add comment or security note
- SHOW ME: Dockerfile.sb-life creates user "sandbox" with no sudo
- SHOW ME: Dockerfile.sb-core has read-only comment
- FAIL IF: Any Dockerfile missing or missing required content

CHECK 4: docker-compose.yml
- SHOW ME: docker-compose.yml exists
- SHOW ME: Contains three services: sb-dev, sb-life, sb-core
- SHOW ME: sb-core has network_mode: none
- SHOW ME: sb-core has read_only: true
- SHOW ME: sb-life has cap_drop: ALL
- SHOW ME: sb-dev has cap_add: ALL
- SHOW ME: Volume mounts use explicit paths (no wildcards)
- SHOW ME: Network "sandbox-net" is defined
- SHOW ME: docker-compose config is valid (run: docker-compose config)
- FAIL IF: File missing, invalid YAML, or missing required configurations

CHECK 5: sb CLI Script
- SHOW ME: sb script exists in workspace root
- SHOW ME: File is executable
- SHOW ME: Script contains "sb start" command handler
- SHOW ME: Script contains "sb stop" command handler
- SHOW ME: Script contains "sb status" command handler
- SHOW ME: Script contains "sb shell" command handler
- SHOW ME: Script contains "sb snapshot" command handler
- SHOW ME: Script contains "sb restore" command handler
- SHOW ME: Script contains "sb ai allow" command handler
- SHOW ME: Script contains "sb ai deny" command handler
- SHOW ME: Script contains "sb ai status" command handler
- SHOW ME: Script validates container names (dev, life, core)
- FAIL IF: File missing, not executable, or missing any required command

CHECK 6: snapshot.sh
- SHOW ME: snapshot.sh exists in workspace root
- SHOW ME: File is executable
- SHOW ME: Script accepts container name parameter
- SHOW ME: Script creates snapshot with timestamp format
- SHOW ME: Script implements 24-snapshot retention logic
- SHOW ME: Script logs to ~/.sandbox/snapshots.log
- FAIL IF: File missing, not executable, or missing required functionality

CHECK 7: LaunchAgent Plist
- SHOW ME: ~/Library/LaunchAgents/com.sandbox.snapshot.plist exists
- SHOW ME: Plist contains StartInterval (3600)
- SHOW ME: Plist contains ProgramArguments pointing to snapshot.sh
- SHOW ME: Plist contains StandardOutput and StandardError redirects
- SHOW ME: Plist syntax is valid (run: plutil -lint)
- FAIL IF: File missing, invalid plist syntax, or missing required keys

CHECK 8: install.sh
- SHOW ME: install.sh exists in workspace root
- SHOW ME: File is executable
- SHOW ME: Script checks for Docker/OrbStack
- SHOW ME: Script creates directory structure
- SHOW ME: Script builds Docker images
- SHOW ME: Script starts containers
- SHOW ME: Script creates LaunchAgent
- FAIL IF: File missing, not executable, or missing required functionality

CHECK 9: README.md Updates
- SHOW ME: README.md contains "Installation" section
- SHOW ME: README.md contains "Usage" section with sb commands
- SHOW ME: README.md contains "Security Warnings" section
- SHOW ME: README.md documents cap_add: ALL risk
- SHOW ME: README.md documents volume mount risks
- SHOW ME: README.md documents host filesystem exposure
- FAIL IF: Missing required sections or security disclosures

CHECK 10: Security Constraints
- SHOW ME: No wildcard mounts in docker-compose.yml (grep for "*" or "**")
- SHOW ME: No Docker socket mounts (grep for "/var/run/docker.sock")
- SHOW ME: sb-core has network_mode: none
- SHOW ME: sb-life has cap_drop: ALL
- SHOW ME: All scripts validate inputs (grep for validation checks)
- FAIL IF: Any security constraint violated

VERIFICATION RULES:
1. For each CHECK, you MUST demonstrate existence by showing file contents or running commands
2. Use: cat, ls, grep, docker-compose config, plutil -lint, etc.
3. If you cannot SHOW ME the item exists, it FAILS
4. Report: "CHECK X PASSED" or "CHECK X FAILED: [reason]"
5. Continue checking all items even if one fails
6. At end, provide summary: "VERIFICATION COMPLETE: X passed, Y failed"

OUTPUT FORMAT:
CHECK 1: [PASSED/FAILED] - [evidence]
CHECK 2: [PASSED/FAILED] - [evidence]
...
SUMMARY: X/10 checks passed

BEGIN VERIFICATION NOW.
```

---

## 📋 PROMPT FLOW DOCUMENT

# Agent Prompt Flow

## Overview
Two-agent system: **BUILDER** creates files sequentially, **VERIFIER** validates everything exists.

---

## Phase 1: BUILD

### Step 1: Spawn Builder Agent
```
Copy the "BUILDER AGENT PROMPT" from AGENT_FLOW.md
Paste into agent interface
Execute
```

### Step 2: Monitor Builder Output
- Watch for "STEP X COMPLETE" messages
- If "STEP X FAILED" appears, stop and debug
- Wait for "BUILD COMPLETE" message

### Step 3: Builder Completion Criteria
✅ All 8 steps completed
✅ No failure messages
✅ "BUILD COMPLETE" output received

---

## Phase 2: VERIFY

### Step 1: Spawn Verifier Agent
```
Copy the "VERIFIER AGENT PROMPT" from AGENT_FLOW.md
Paste into agent interface
Execute
```

### Step 2: Monitor Verifier Output
- Watch for "CHECK X PASSED" or "CHECK X FAILED" messages
- Verifier will show evidence (file contents, command outputs)
- Note any failures

### Step 3: Verification Criteria
✅ All 10 checks pass
✅ Evidence shown for each check
✅ "VERIFICATION COMPLETE: 10/10 checks passed"

---

## Failure Handling

### If Builder Fails:
1. Note which STEP failed
2. Check the specific agent prompt in AGENT_PROMPTS.md
3. Manually fix the issue or re-run that step
4. Continue from failed step

### If Verifier Fails:
1. Note which CHECK failed
2. Review the "SHOW ME" evidence (or lack thereof)
3. Check if file exists but doesn't match spec
4. Fix the issue
5. Re-run verifier or fix specific component

---

## Quick Reference

### Builder Agent
- **Purpose**: Create all files sequentially
- **Input**: AGENT_PROMPTS.md (reads prompts for each step)
- **Output**: Files created in workspace
- **Success**: "BUILD COMPLETE"

### Verifier Agent  
- **Purpose**: Verify all files exist and match specs
- **Method**: "SHOW ME" - must demonstrate existence
- **Output**: Pass/fail for each check
- **Success**: "10/10 checks passed"

---

## Execution Commands

### Spawn Builder:
```bash
# In agent interface, paste BUILDER AGENT PROMPT from AGENT_FLOW.md
```

### Spawn Verifier:
```bash
# In agent interface, paste VERIFIER AGENT PROMPT from AGENT_FLOW.md
```

### Manual Verification (if needed):
```bash
cd /Users/xyz/scafolding-the-future

# Check files exist
ls -la setup-directories.sh sb snapshot.sh install.sh
ls -la Dockerfile.sb-*

# Check docker-compose
docker-compose config

# Check plist
plutil -lint ~/Library/LaunchAgents/com.sandbox.snapshot.plist

# Check directories
ls -ld ~/.sandbox ~/.sandbox/shared ~/.sandbox/core ~/.sandbox/core/secrets
```

---

## Expected File List (After Build)

```
/Users/xyz/scafolding-the-future/
├── setup-directories.sh          [executable]
├── Dockerfile.sb-dev
├── Dockerfile.sb-life
├── Dockerfile.sb-core
├── docker-compose.yml
├── sb                             [executable]
├── snapshot.sh                    [executable]
├── install.sh                     [executable]
├── README.md                      [updated]
└── ~/Library/LaunchAgents/
    └── com.sandbox.snapshot.plist

~/.sandbox/
├── shared/                        [755]
└── core/
    └── secrets/                   [700]
```

---

## Success Criteria

### Builder Success:
- ✅ All 8 steps completed
- ✅ All files created
- ✅ All scripts executable
- ✅ No error messages

### Verifier Success:
- ✅ All 10 checks passed
- ✅ Evidence shown for each
- ✅ No security constraint violations
- ✅ All files match specifications

---

## Troubleshooting

### Builder stops mid-way:
- Check which step failed
- Verify prerequisites for that step
- Re-run builder from failed step

### Verifier can't find files:
- Check workspace path is correct
- Verify builder completed successfully
- Check file permissions

### Files exist but verifier fails:
- Check file contents match specifications
- Verify executable permissions
- Check syntax (YAML, plist, bash)

---

## Notes

- **Builder is sequential** - must complete steps in order
- **Verifier is comprehensive** - checks everything
- **"SHOW ME" means proof** - verifier must demonstrate existence
- **Fail fast** - if verifier can't show it, it doesn't exist
- **No assumptions** - verifier proves everything
