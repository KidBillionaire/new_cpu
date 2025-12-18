#!/bin/bash

# Boot Chain Verification - Validate bootloader and kernel integrity
# Detects bootkits, modified boot loaders, and kernel-level compromises

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASELINE_DIR="${HOME}/.sandbox/security"
BOOT_BASELINE="${BASELINE_DIR}/boot_chain_baseline.json"
BOOT_LOG="${BASELINE_DIR}/boot_chain.log"
BOOT_ALERTS="${BASELINE_DIR}/boot_chain_alerts.log"

# Critical boot components to verify
BOOT_COMPONENTS=(
    "/System/Library/CoreServices/boot.efi"
    "/System/Library/CoreServices/SystemVersion.plist"
    "/System/Library/Kernels/kernel"
    "/System/Library/Extensions/*"
    "/Library/Extensions/*"
    "/usr/standalone/i386/boot.efi"
)

# SIP-protected directories (should never be modified)
PROTECTED_DIRECTORIES=(
    "/System/Library"
    "/usr/libexec"
    "/bin"
    "/sbin"
    "/usr/bin"
    "/usr/sbin"
)

# Ensure directories exist
mkdir -p "${BASELINE_DIR}"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${BOOT_LOG}"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "${BOOT_LOG}"
}

log_alert() {
    echo -e "${RED}[ALERT]${NC} $*" | tee -a "${BOOT_LOG}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "${BOOT_ALERTS}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${BOOT_LOG}"
}

# Calculate cryptographic hash of file
calculate_hash() {
    local file="$1"
    local hash_type="${2:-sha256}"

    if [ ! -f "$file" ]; then
        return 1
    fi

    case "$hash_type" in
        "sha256")
            shasum -a 256 "$file" 2>/dev/null | cut -d' ' -f1
            ;;
        "sha1")
            shasum -a 1 "$file" 2>/dev/null | cut -d' ' -f1
            ;;
        "md5")
            md5 -q "$file" 2>/dev/null
            ;;
        *)
            log_warn "Unsupported hash type: $hash_type"
            return 1
            ;;
    esac
}

# Verify file integrity against baseline
verify_file_integrity() {
    local file="$1"
    local expected_hash="$2"

    if [ ! -f "$file" ]; then
        log_alert "Critical boot component missing: $file"
        return 1
    fi

    local current_hash=$(calculate_hash "$file")
    if [ "$current_hash" != "$expected_hash" ]; then
        log_alert "File integrity violation: $file"
        log_alert "  Expected: $expected_hash"
        log_alert "  Current:  $current_hash"
        return 1
    fi

    return 0
}

# Create baseline of boot components
create_boot_baseline() {
    log_info "Creating boot chain baseline..."

    local baseline_json="{"
    baseline_json+='"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'",'
    baseline_json+='"system":"'$(uname -s) $(uname -r)'",'
    baseline_json+='"boot_rom":"'$(system_profiler SPHardwareDataType | grep "Boot ROM Version" | cut -d: -f2 | xargs)'",'
    baseline_json+='"components":{'

    local first=true

    # System files
    local system_files=(
        "/System/Library/CoreServices/boot.efi"
        "/System/Library/CoreServices/SystemVersion.plist"
        "/System/Library/PrelinkedKernels/prelinkedkernel"
    )

    for file in "${system_files[@]}"; do
        if [ -f "$file" ]; then
            local hash=$(calculate_hash "$file")
            local size=$(stat -f%z "$file" 2>/dev/null || echo "0")
            local mtime=$(stat -f%m "$file" 2>/dev/null || echo "0")

            if [ "$first" = true ]; then
                first=false
            else
                baseline_json+=","
            fi

            baseline_json+='"'"$(echo "$file" | sed 's/"/\\"/g')"'":{'
            baseline_json+='"hash":"'"$hash"'",'
            baseline_json+='"size":'"$size"','
            baseline_json+='"mtime":'"$mtime"','
            baseline_json+='"type":"system"'
            baseline_json+='}'
        fi
    done

    # Kernel extensions (kexts)
    baseline_json+='},"kexts":{'
    first=true

    # Find all loaded kernel extensions
    if command -v kextstat >/dev/null 2>&1; then
        while IFS= read -r line; do
            local kext_name=$(echo "$line" | awk '{print $6}')
            local kext_path

            # Try to find the kext path
            kext_path=$(kextstat -l | grep "$kext_name" | head -1 | awk '{print $7}' | sed 's/<[^>]*>//')

            if [ -n "$kext_path" ] && [ -f "$kext_path" ]; then
                local hash=$(calculate_hash "$kext_path")
                local bundle_id=$(plutil -p "$kext_path/Contents/Info.plist" 2>/dev/null | grep "CFBundleIdentifier" | cut -d'"' -f4 || echo "$kext_name")

                if [ "$first" = true ]; then
                    first=false
                else
                    baseline_json+=","
                fi

                baseline_json+='"'"$(echo "$bundle_id" | sed 's/"/\\"/g')"'":{'
                baseline_json+='"path":"'"$(echo "$kext_path" | sed 's/"/\\"/g')"'",'
                baseline_json+='"hash":"'"$hash"'",'
                baseline_json+'"name":"'"$(echo "$kext_name" | sed 's/"/\\"/g')"'",'
                baseline_json+='"type":"kext"'
                baseline_json+='}'
            fi
        done < <(kextstat | grep -v "^Index" | grep -v "Name")
    fi

    baseline_json+='},"launchd":{'

    # Launchd and critical system daemons
    local critical_daemons=(
        "/sbin/launchd"
        "/usr/libexec/amfid"
        "/usr/libexec/securityd"
        "/usr/sbin/securityd"
        "/usr/libexec/kernelmanagerd"
    )

    first=true
    for daemon in "${critical_daemons[@]}"; do
        if [ -f "$daemon" ]; then
            local hash=$(calculate_hash "$daemon")
            local codesign_info

            # Check code signature
            if command -v codesign >/dev/null 2>&1; then
                if codesign -v "$daemon" 2>/dev/null; then
                    codesign_info="valid"
                else
                    codesign_info="invalid"
                fi
            else
                codesign_info="unknown"
            fi

            if [ "$first" = true ]; then
                first=false
            else
                baseline_json+=","
            fi

            baseline_json+='"'"$(basename "$daemon")"'":{'
            baseline_json+='"path":"'"$daemon"'",'
            baseline_json+='"hash":"'"$hash"'",'
            baseline_json+='"codesign":"'"$codesign_info"'",'
            baseline_json+='"type":"daemon"'
            baseline_json+='}'
        fi
    done

    baseline_json+='}}'

    # Write baseline
    echo "$baseline_json" > "$BOOT_BASELINE"
    chmod 600 "$BOOT_BASELINE"

    log_success "Boot chain baseline created at $BOOT_BASELINE"

    # Show summary
    local components_count=$(echo "$baseline_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(len(data.get('components', {})))
except:
    print(0)
" <<< "$baseline_json")

    local kexts_count=$(echo "$baseline_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(len(data.get('kexts', {})))
except:
    print(0)
" <<< "$baseline_json")

    log_info "Baseline contains $components_count system components and $kexts_count kernel extensions"
}

# Load existing baseline
load_boot_baseline() {
    if [ ! -f "$BOOT_BASELINE" ]; then
        log_warn "No boot chain baseline found. Run with --create-baseline first."
        return 1
    fi

    if ! python3 -c "import json; json.load(open('$BOOT_BASELINE'))" 2>/dev/null; then
        log_alert "Boot chain baseline is corrupted"
        return 1
    fi

    return 0
}

# Verify system file integrity
verify_system_files() {
    log_info "Verifying system file integrity..."

    if ! load_boot_baseline; then
        return 1
    fi

    local violations=false

    # Extract components from baseline
    python3 -c "
import json
with open('$BOOT_BASELINE') as f:
    baseline = json.load(f)
    for path, info in baseline.get('components', {}).items():
        print(f'{path}\t{info[\"hash\"]}\t{info[\"size\"]}')
" | while IFS=$'\t' read -r path expected_hash expected_size; do
        if [ -n "$path" ]; then
            if ! verify_file_integrity "$path" "$expected_hash"; then
                violations=true
            else
                # Check file size
                local current_size=$(stat -f%z "$path" 2>/dev/null || echo "0")
                if [ "$current_size" != "$expected_size" ]; then
                    log_alert "File size mismatch: $path"
                    log_alert "  Expected: $expected_size bytes"
                    log_alert "  Current:  $current_size bytes"
                    violations=true
                fi
            fi
        fi
    done

    if [ "$violations" = false ]; then
        log_success "All system files passed integrity check"
    else
        log_alert "System file integrity violations detected"
        return 1
    fi
}

# Verify kernel extensions
verify_kernel_extensions() {
    log_info "Verifying kernel extensions..."

    if ! load_boot_baseline; then
        return 1
    fi

    local violations=false
    local unsigned_count=0
    local suspicious_count=0

    # Get currently loaded kexts
    while IFS= read -r line; do
        local kext_name=$(echo "$line" | awk '{print $6}')
        local kext_index=$(echo "$line" | awk '{print $1}')

        # Skip header
        [ "$kext_name" = "Name" ] && continue

        # Check if kext exists in baseline
        local baseline_info=$(python3 -c "
import json
with open('$BOOT_BASELINE') as f:
    baseline = json.load(f)
    for name, info in baseline.get('kexts', {}).items():
        if info.get('name') == '$kext_name' or name == '$kext_name':
            print(f'{info[\"path\"]}\t{info[\"hash\"]}')
            break
" 2>/dev/null)

        if [ -n "$baseline_info" ]; then
            local baseline_path=$(echo "$baseline_info" | cut -d$'\t' -f1)
            local baseline_hash=$(echo "$baseline_info" | cut -d$'\t' -f2)

            if [ -f "$baseline_path" ]; then
                local current_hash=$(calculate_hash "$baseline_path")
                if [ "$current_hash" != "$baseline_hash" ]; then
                    log_alert "Kernel extension modified: $kext_name"
                    log_alert "  Path: $baseline_path"
                    log_alert "  Expected hash: $baseline_hash"
                    log_alert "  Current hash:  $current_hash"
                    violations=true
                fi
            fi
        else
            # Check if it's a known system kext
            if [[ "$kext_name" =~ ^(com\.apple\.|org\.darwinsys\.|Apple) ]]; then
                log_alert "Unknown system kernel extension: $kext_name"
                violations=true
            else
                log_warn "Third-party kernel extension: $kext_name"
            fi
        fi

        # Check for suspicious kexts
        if [[ "$kext_name" =~ (hack|crack|patch|bypass|rootkit|keylog) ]]; then
            log_alert "Suspicious kernel extension detected: $kext_name"
            violations=true
            suspicious_count=$((suspicious_count + 1))
        fi

    done < <(kextstat | grep -v "^Index" | grep -v "Name")

    # Check code signatures of kexts
    if command -v kextutil >/dev/null 2>&1; then
        while IFS= read -r kext_path; do
            if [ -f "$kext_path" ]; then
                if ! kextutil -nt "$kext_path" 2>/dev/null; then
                    log_alert "Unsigned kernel extension: $kext_path"
                    violations=true
                    unsigned_count=$((unsigned_count + 1))
                fi
            fi
        done < <(kextstat -l | awk '{print $7}' | grep -v "<" | sort -u)
    fi

    if [ "$violations" = false ]; then
        log_success "All kernel extensions passed verification"
    else
        log_alert "Kernel extension violations detected"
        log_alert "  Unsigned kexts: $unsigned_count"
        log_alert "  Suspicious kexts: $suspicious_count"
        return 1
    fi
}

# Verify critical daemons
verify_critical_daemons() {
    log_info "Verifying critical system daemons..."

    if ! load_boot_baseline; then
        return 1
    fi

    local violations=false

    # Extract daemons from baseline and verify
    python3 -c "
import json
with open('$BOOT_BASELINE') as f:
    baseline = json.load(f)
    for name, info in baseline.get('launchd', {}).items():
        print(f'{info[\"path\"]}\t{info[\"hash\"]}\t{info[\"codesign\"]}')
" | while IFS=$'\t' read -r daemon_path expected_hash expected_codesign; do
        if [ -n "$daemon_path" ] && [ -f "$daemon_path" ]; then
            # Verify hash
            local current_hash=$(calculate_hash "$daemon_path")
            if [ "$current_hash" != "$expected_hash" ]; then
                log_alert "Critical daemon modified: $(basename "$daemon_path")"
                log_alert "  Path: $daemon_path"
                violations=true
            fi

            # Verify code signature
            if command -v codesign >/dev/null 2>&1; then
                if codesign -v "$daemon_path" 2>/dev/null; then
                    current_codesign="valid"
                else
                    current_codesign="invalid"
                fi

                if [ "$current_codesign" != "$expected_codesign" ]; then
                    log_alert "Code signature changed: $(basename "$daemon_path")"
                    log_alert "  Expected: $expected_codesign"
                    log_alert "  Current:  $current_codesign"
                    violations=true
                fi
            fi
        fi
    done

    if [ "$violations" = false ]; then
        log_success "All critical daemons passed verification"
    else
        log_alert "Critical daemon violations detected"
        return 1
    fi
}

# Check for boot loader modifications
check_boot_loader() {
    log_info "Checking boot loader integrity..."

    local violations=false

    # Check EFI boot loader
    local efi_paths=(
        "/System/Library/CoreServices/boot.efi"
        "/usr/standalone/i386/boot.efi"
    )

    for efi_path in "${efi_paths[@]}"; do
        if [ -f "$efi_path" ]; then
            if ! load_boot_baseline; then
                log_warn "Cannot verify $efi_path without baseline"
                continue
            fi

            local baseline_hash=$(python3 -c "
import json
with open('$BOOT_BASELINE') as f:
    baseline = json.load(f)
    info = baseline.get('components', {}).get('$efi_path')
    if info:
        print(info['hash'])
" 2>/dev/null)

            if [ -n "$baseline_hash" ]; then
                if ! verify_file_integrity "$efi_path" "$baseline_hash"; then
                    violations=true
                fi
            fi

            # Check for suspicious strings in boot loader
            if grep -q -i "hook\|patch\|bypass\|debug" "$efi_path" 2>/dev/null; then
                log_alert "Suspicious strings found in boot loader: $efi_path"
                violations=true
            fi
        fi
    done

    # Check for custom boot arguments
    local boot_args=$(nvram boot-args 2>/dev/null | cut -d$'\t' -f2)
    if [ -n "$boot_args" ]; then
        if [[ "$boot_args" =~ (rootless|kext-dev-mode|keepsyms|debug) ]]; then
            log_alert "Suspicious boot arguments detected: $boot_args"
            violations=true
        fi
    fi

    if [ "$violations" = false ]; then
        log_success "Boot loader integrity verified"
    else
        log_alert "Boot loader violations detected"
        return 1
    fi
}

# Analyze boot timeline
analyze_boot_timeline() {
    log_info "Analyzing boot timeline..."

    # Check launchd logs for boot sequence
    local launchd_log="/var/log/com.apple.xpc.launchd/launchd.log"
    local current_boot_time

    if [ -f "$launchd_log" ]; then
        # Extract boot time from launchd log
        current_boot_time=$(grep "launchd.*started" "$launchd_log" | tail -1 | awk '{print $1, $2, $3}')

        if [ -n "$current_boot_time" ]; then
            log_info "Current boot time: $current_boot_time"

            # Check for unusual delays in critical service startup
            local suspicious_delays=$(grep -E "(securityd|amfid|launchd)" "$launchd_log" | \
                grep -A5 -B5 "successfully spawned" | \
                awk '{print $1, $2}' | sort | uniq -c | \
                awk '$1 > 10 {print "High spawn count for: " $2}')

            if [ -n "$suspicious_delays" ]; then
                log_alert "Unusual service spawning patterns detected:"
                echo "$suspicious_delays" | while read line; do
                    log_alert "  $line"
                done
            fi
        fi
    fi

    # Check system boot time
    local system_uptime=$(sysctl -n kern.boottime 2>/dev/null | sed 's/{ sec = //;s, .*,,,')
    if [ -n "$system_uptime" ]; then
        local boot_date=$(date -r "$system_uptime" 2>/dev/null)
        log_info "System boot time: $boot_date"
    fi
}

# Generate boot security report
generate_boot_report() {
    log_info "Generating boot chain security report..."

    local report_file="${BASELINE_DIR}/boot_security_report.txt"

    {
        echo "Boot Chain Security Report"
        echo "=========================="
        echo "Generated: $(date)"
        echo "System: $(uname -s) $(uname -r)"
        echo ""

        echo "Boot Information:"
        echo "----------------"
        system_profiler SPHardwareDataType | grep -E "(Model Name|Boot ROM Version|SMC Version)"
        echo ""

        echo "Boot Time Analysis:"
        echo "------------------"
        sysctl -n kern.boottime | sed 's/{ sec = //;s,.*,,;$' | xargs -I {} date -r {}
        echo ""

        echo "System Integrity Protection:"
        echo "----------------------------"
        if command -v csrutil >/dev/null 2>&1; then
            csrutil status
        else
            echo "csrutil not available"
        fi
        echo ""

        echo "Kernel Extensions Summary:"
        echo "-------------------------"
        echo "Loaded kexts: $(kextstat | grep -v "^Index" | grep -v "Name" | wc -l | tr -d ' ')"
        echo "Unsigned kexts: $(kextstat -l | awk '{print $7}' | xargs -I {} kextutil -nt {} 2>&1 | grep -c "not signed" || echo "0")"
        echo ""

        echo "Critical Daemons Status:"
        echo "------------------------"
        local daemons=("/sbin/launchd" "/usr/sbin/securityd" "/usr/libexec/amfid")
        for daemon in "${daemons[@]}"; do
            if [ -f "$daemon" ]; then
                echo -n "$(basename "$daemon"): "
                if codesign -v "$daemon" 2>/dev/null; then
                    echo "Valid signature"
                else
                    echo "INVALID SIGNATURE"
                fi
            fi
        done
        echo ""

        echo "Recent Alerts:"
        echo "--------------"
        if [ -f "$BOOT_ALERTS" ]; then
            tail -10 "$BOOT_ALERTS" 2>/dev/null || echo "No recent alerts"
        else
            echo "No alerts logged"
        fi

    } > "$report_file"

    log_success "Boot security report generated: $report_file"
}

# Main function
main() {
    local action="${1:-verify}"

    case "$action" in
        "--create-baseline"|"baseline")
            create_boot_baseline
            ;;
        "--verify"|"check"|"verify")
            verify_system_files
            verify_kernel_extensions
            verify_critical_daemons
            check_boot_loader
            analyze_boot_timeline
            ;;
        "--quick"|"quick")
            check_boot_loader
            verify_critical_daemons
            ;;
        "--report"|"report")
            generate_boot_report
            ;;
        "--help"|"help"|"-h")
            echo "Boot Chain Verification"
            echo "======================="
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  baseline     Create boot chain baseline"
            echo "  verify       Verify all boot components (default)"
            echo "  quick        Quick verification of critical components"
            echo "  report       Generate security report"
            echo "  help         Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 baseline                    # Create baseline"
            echo "  $0                             # Full verification"
            echo "  $0 quick                       # Quick check"
            ;;
        *)
            log_warn "Unknown command: $action"
            log_info "Use --help for usage information"
            exit 1
            ;;
    esac
}

main "$@"