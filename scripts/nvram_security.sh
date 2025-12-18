#!/bin/bash

# NVRAM Security Module - Monitor and secure NVRAM variables
# Detects persistence mechanisms and unauthorized firmware modifications

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
BASELINE_FILE="${BASELINE_DIR}/nvram_baseline.json"
LOG_FILE="${BASELINE_DIR}/nvram_security.log"
ALERT_FILE="${BASELINE_DIR}/nvram_alerts.log"

# Suspicious NVRAM variables that indicate persistence
SUSPICIOUS_VARIABLES=(
    "boot-args"
    "run-args"
    "keepsyms"
    "kext-dev-mode"
    "rootless"
    "csr-active-config"
    "fmm-computer-name"
    "fmm-mobileme-token-FMM"
    "bluetoothHostControllerSwitchBehavior"
)

# Variables that should be monitored for changes
MONITORED_VARIABLES=(
    "auto-boot"
    "supervised"
    "prev-lang:kbd"
    "SystemAudioVolume"
    "LocationServicesEnabled"
    "ota-updateType"
)

# Ensure directories exist
mkdir -p "${BASELINE_DIR}"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${LOG_FILE}"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "${LOG_FILE}"
}

log_alert() {
    echo -e "${RED}[ALERT]${NC} $*" | tee -a "${LOG_FILE}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "${ALERT_FILE}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${LOG_FILE}"
}

# Check if running with appropriate privileges
check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        log_warn "Some NVRAM operations require sudo privileges"
        log_info "Running in read-only mode. Use sudo for full functionality."
        return 1
    fi
    return 0
}

# Get all NVRAM variables
get_nvram_variables() {
    if ! nvram -p 2>/dev/null; then
        log_warn "Failed to read NVRAM variables"
        return 1
    fi
}

# Create baseline of current NVRAM state
create_baseline() {
    log_info "Creating NVRAM baseline..."

    local temp_file=$(mktemp)
    local baseline_json="{"
    baseline_json+='"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'",'
    baseline_json+='"system":"'$(uname -s) $(uname -r)'",'
    baseline_json+='"hardware":"'$(system_profiler SPHardwareDataType | grep "Model Name" | cut -d: -f2 | xargs)'",'
    baseline_json+='"serial":"'$(system_profiler SPHardwareDataType | grep "Serial Number" | cut -d: -f2 | xargs)'",'
    baseline_json+='"variables":{'

    local first=true
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local var_name=$(echo "$line" | cut -d$'\t' -f1)
        local var_value=$(echo "$line" | cut -d$'\t' -f2-)

        # Skip empty values or malformed lines
        [ -z "$var_name" ] || [ -z "$var_value" ] && continue

        if [ "$first" = true ]; then
            first=false
        else
            baseline_json+=","
        fi

        # Escape JSON characters in values
        var_value=$(echo "$var_value" | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n')
        baseline_json+='"'"$var_name"'":"'"$var_value"'"'

    done < "$temp_file"

    baseline_json+='}}'

    # Write baseline
    echo "$baseline_json" > "$BASELINE_FILE"
    rm -f "$temp_file"

    chmod 600 "$BASELINE_FILE"
    log_success "NVRAM baseline created at $BASELINE_FILE"

    # Display summary
    local var_count=$(get_nvram_variables | wc -l)
    log_info "Baseline contains $var_count NVRAM variables"
}

# Load existing baseline
load_baseline() {
    if [ ! -f "$BASELINE_FILE" ]; then
        log_warn "No NVRAM baseline found. Run with --create-baseline first."
        return 1
    fi

    if ! python3 -c "import json; json.load(open('$BASELINE_FILE'))" 2>/dev/null; then
        log_alert "NVRAM baseline is corrupted"
        return 1
    fi

    return 0
}

# Check for suspicious NVRAM variables
check_suspicious_variables() {
    log_info "Checking for suspicious NVRAM variables..."

    local found_suspicious=false

    # Check for suspicious variables
    for var in "${SUSPICIOUS_VARIABLES[@]}"; do
        local value=$(nvram "$var" 2>/dev/null | cut -d$'\t' -f2-)
        if [ -n "$value" ]; then
            log_alert "Suspicious NVRAM variable found: $var = $value"
            found_suspicious=true

            # Special handling for specific variables
            case "$var" in
                "boot-args")
                    if [[ "$value" =~ (rootless|kext-dev-mode|keepsyms) ]]; then
                        log_alert "Boot arguments indicate potential SIP bypass attempt"
                    fi
                    ;;
                "bluetoothHostControllerSwitchBehavior")
                    if [ "$value" != "never" ]; then
                        log_alert "Bluetooth controller switching enabled - potential attack vector"
                    fi
                    ;;
            esac
        fi
    done

    if [ "$found_suspicious" = false ]; then
        log_success "No suspicious NVRAM variables detected"
    fi
}

# Compare current state with baseline
compare_with_baseline() {
    log_info "Comparing current NVRAM state with baseline..."

    # Create temporary current state
    local temp_current=$(mktemp)
    get_nvram_variables > "$temp_current"

    # Extract baseline variables using Python for proper JSON parsing
    local baseline_vars=$(python3 -c "
import json
try:
    with open('$BASELINE_FILE') as f:
        baseline = json.load(f)
        for var_name, var_value in baseline['variables'].items():
            print(f'{var_name}\t{var_value}')
except Exception as e:
    print(f'Error reading baseline: {e}', file=sys.stderr)
" 2>/dev/null)

    if [ -z "$baseline_vars" ]; then
        log_warn "Failed to parse baseline for comparison"
        rm -f "$temp_current"
        return 1
    fi

    local changes_detected=false

    # Check for new variables
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local var_name=$(echo "$line" | cut -d$'\t' -f1)
        local var_value=$(echo "$line" | cut -d$'\t' -f2-)

        # Check if variable exists in baseline
        if ! echo "$baseline_vars" | grep -q "^${var_name}\t"; then
            log_alert "New NVRAM variable detected: $var_name = $var_value"
            changes_detected=true
        else
            # Check if value changed
            local baseline_value=$(echo "$baseline_vars" | grep "^${var_name}\t" | cut -d$'\t' -f2-)
            if [ "$var_value" != "$baseline_value" ]; then
                log_alert "NVRAM variable changed: $var_name"
                log_alert "  Old value: $baseline_value"
                log_alert "  New value: $var_value"
                changes_detected=true
            fi
        fi
    done < "$temp_current"

    # Check for removed variables
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local var_name=$(echo "$line" | cut -d$'\t' -f1)

        if ! grep -q "^${var_name}\t" "$temp_current"; then
            log_alert "NVRAM variable removed: $var_name"
            changes_detected=true
        fi
    done <<< "$baseline_vars"

    rm -f "$temp_current"

    if [ "$changes_detected" = false ]; then
        log_success "No NVRAM changes detected"
    else
        log_alert "NVRAM changes detected - system may be compromised"
        return 1
    fi
}

# Monitor specific variables for changes
monitor_specific_variables() {
    log_info "Monitoring critical NVRAM variables..."

    for var in "${MONITORED_VARIABLES[@]}"; do
        local value=$(nvram "$var" 2>/dev/null | cut -d$'\t' -f2-)
        if [ -n "$value" ]; then
            log_info "$var: $value"

            # Check for suspicious values
            case "$var" in
                "auto-boot")
                    if [ "$value" != "true" ]; then
                        log_warn "Auto-boot disabled - potential security configuration"
                    fi
                    ;;
                "supervised")
                    if [ "$value" = "true" ]; then
                        log_alert "Device supervision detected - potential MDM persistence"
                    fi
                    ;;
                "LocationServicesEnabled")
                    if [[ "$value" =~ %01 ]]; then
                        log_info "Location services enabled - consider privacy implications"
                    fi
                    ;;
            esac
        fi
    done
}

# Secure NVRAM by removing suspicious variables
secure_nvram() {
    if ! check_privileges; then
        log_warn "Cannot secure NVRAM without sudo privileges"
        return 1
    fi

    log_info "Securing NVRAM..."

    local secured=false

    # Remove suspicious variables
    for var in "${SUSPICIOUS_VARIABLES[@]}"; do
        if nvram "$var" >/dev/null 2>&1; then
            log_warn "Removing suspicious NVRAM variable: $var"
            nvram -d "$var" 2>/dev/null || true
            secured=true
        fi
    done

    # Set secure defaults
    nvram bluetoothHostControllerSwitchBehavior=never 2>/dev/null || true
    nvram auto-boot=true 2>/dev/null || true

    if [ "$secured" = true ]; then
        log_success "NVRAM security hardening completed"
    else
        log_info "NVRAM already secure"
    fi
}

# Validate System Integrity Protection status
validate_sip() {
    log_info "Validating System Integrity Protection status..."

    # Check SIP status using csrutil
    local sip_status
    if command -v csrutil >/dev/null 2>&1; then
        sip_status=$(csrutil status 2>/dev/null | grep "System Integrity Protection status" | cut -d: -f2 | xargs)
        case "$sip_status" in
            "enabled.")
                log_success "SIP is enabled - system protection active"
                ;;
            "disabled."*)
                log_alert "SIP is disabled - system vulnerable to rootkits"
                return 1
                ;;
            *)
                log_warn "Could not determine SIP status"
                ;;
        esac
    else
        log_warn "csrutil not available - cannot verify SIP status"
    fi

    # Check NVRAM SIP configuration
    local csr_config=$(nvram csr-active-config 2>/dev/null | cut -d$'\t' -f2)
    if [ -n "$csr_config" ]; then
        if [ "$csr_config" != "%00%00%00%00" ]; then
            log_alert "SIP configuration modified: $csr_config"
            log_alert "This may indicate SIP bypass attempt"
            return 1
        else
            log_success "SIP NVRAM configuration is secure"
        fi
    fi
}

# Generate comprehensive security report
generate_report() {
    log_info "Generating NVRAM security report..."

    local report_file="${BASELINE_DIR}/nvram_security_report.txt"

    {
        echo "NVRAM Security Report"
        echo "====================="
        echo "Generated: $(date)"
        echo "System: $(uname -s) $(uname -r)"
        echo ""

        echo "System Information:"
        echo "------------------"
        system_profiler SPHardwareDataType | grep -E "(Model Name|Serial Number|Boot ROM Version|SMC Version)"
        echo ""

        echo "NVRAM Variables Summary:"
        echo "------------------------"
        echo "Total variables: $(get_nvram_variables | wc -l)"
        echo ""

        echo "Critical Status:"
        echo "---------------"
        echo -n "SIP Status: "
        if command -v csrutil >/dev/null 2>&1; then
            csrutil status | grep "System Integrity Protection status" | cut -d: -f2 | xargs
        else
            echo "Unknown"
        fi

        echo -n "Auto-boot: "
        nvram auto-boot 2>/dev/null | cut -d$'\t' -f2 || echo "Not set"

        echo -n "Supervised: "
        nvram supervised 2>/dev/null | cut -d$'\t' -f2 || echo "Not set"
        echo ""

        echo "Suspicious Variables:"
        echo "--------------------"
        local found=false
        for var in "${SUSPICIOUS_VARIABLES[@]}"; do
            local value=$(nvram "$var" 2>/dev/null | cut -d$'\t' -f2-)
            if [ -n "$value" ]; then
                echo "$var: $value"
                found=true
            fi
        done
        if [ "$found" = false ]; then
            echo "None detected"
        fi
        echo ""

        echo "Recent Alerts:"
        echo "--------------"
        if [ -f "$ALERT_FILE" ]; then
            tail -10 "$ALERT_FILE" 2>/dev/null || echo "No recent alerts"
        else
            echo "No alerts logged"
        fi

    } > "$report_file"

    log_success "Security report generated: $report_file"
}

# Main function
main() {
    local action="${1:-monitor}"

    case "$action" in
        "--create-baseline"|"baseline")
            create_baseline
            ;;
        "--check"|"monitor")
            if load_baseline; then
                compare_with_baseline
            fi
            check_suspicious_variables
            monitor_specific_variables
            validate_sip
            ;;
        "--secure"|"harden")
            secure_nvram
            ;;
        "--report"|"report")
            generate_report
            ;;
        "--help"|"help"|"-h")
            echo "NVRAM Security Module"
            echo "===================="
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  baseline     Create NVRAM baseline"
            echo "  monitor      Monitor for changes (default)"
            echo "  secure       Remove suspicious variables"
            echo "  report       Generate security report"
            echo "  help         Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 baseline                    # Create baseline"
            echo "  $0                             # Monitor current state"
            echo "  sudo $0 secure                 # Secure NVRAM (requires sudo)"
            ;;
        *)
            log_warn "Unknown command: $action"
            log_info "Use --help for usage information"
            exit 1
            ;;
    esac
}

main "$@"