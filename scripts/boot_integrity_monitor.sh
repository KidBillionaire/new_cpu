#!/bin/bash

# Boot Integrity Monitor - Monitor and validate early boot processes
# Detects anomalous process spawning and validates launchd daemon order

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
BOOT_PROCESS_BASELINE="${BASELINE_DIR}/boot_process_baseline.json"
BOOT_MONITOR_LOG="${BASELINE_DIR}/boot_monitor.log"
BOOT_ALERTS="${BASELINE_DIR}/boot_process_alerts.log"

# Critical early-boot system daemons that should spawn first
CRITICAL_DAEMONS=(
    "logd"                    # Logging daemon
    "securityd"              # Security framework
    "amfid"                  # Apple Mobile File Integrity
    "launchservicesd"        # Launch services
    "configd"                # Configuration management
    "diskarbitrationd"       # Disk arbitration
    "fseventsd"              # File system events
    "opendirectoryd"         # Directory services
    "powerd"                 # Power management
    "thermald"               # Temperature monitoring (on supported systems)
    "bluetoothd"             # Bluetooth daemon
    "mDNSResponder"          # DNS responder
    "WindowServer"           # Window server
    "loginwindow"            # Login window
)

# Suspicious process patterns
SUSPICIOUS_PATTERNS=(
    ".*[Hh]ook.*"
    ".*[Ii]njec.*"
    ".*[Pp]atch.*"
    ".*[Bb]ypass.*"
    ".*[Rr]ootkit.*"
    ".*[Kk]eylog.*"
    ".*[Bb]ackdoor.*"
    ".*[Cc]2.*"
    ".*netcat|nc "
    ".*bash.*-i"
    ".*sh.*-i"
)

# Ensure directories exist
mkdir -p "${BASELINE_DIR}"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${BOOT_MONITOR_LOG}"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "${BOOT_MONITOR_LOG}"
}

log_alert() {
    echo -e "${RED}[ALERT]${NC} $*" | tee -a "${BOOT_MONITOR_LOG}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "${BOOT_ALERTS}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${BOOT_MONITOR_LOG}"
}

# Get current boot time
get_boot_time() {
    # Use sysctl to get boot time
    local boot_sec=$(sysctl -n kern.boottime | sed 's/.* sec = \([0-9]*\).*/\1/')
    if [ -n "$boot_sec" ]; then
        date -r "$boot_sec" "+%Y-%m-%d %H:%M:%S"
    else
        date "+%Y-%m-%d %H:%M:%S"
    fi
}

# Get process start time
get_process_start() {
    local pid="$1"
    if [ -n "$pid" ] && [ "$pid" != "-" ]; then
        # Get process start time in seconds since epoch
        ps -o lstart= -p "$pid" 2>/dev/null | awk '{print $1, $2, $3, $4, $5}' | xargs -I {} date -j -f "%b %d %H:%M:%S %Y" "{}" "+%s" 2>/dev/null
    fi
}

# Parse launchd logs for process spawning information
parse_launchd_logs() {
    local launchd_log="/var/log/com.apple.xpc.launchd/launchd.log"
    local since_boot="$1"

    if [ ! -f "$launchd_log" ]; then
        log_warn "Launchd log not found: $launchd_log"
        return 1
    fi

    log_info "Parsing launchd logs since boot..."

    # Get recent boot time to filter logs
    local current_boot_time
    current_boot_time=$(date -j -f "%Y-%m-%d %H:%M:%S" "$(get_boot_time)" "+%s" 2>/dev/null)

    # Extract process spawn information from launchd logs
    grep "Successfully spawned" "$launchd_log" | while IFS= read -r line; do
        local log_timestamp=$(echo "$line" | awk '{print $1, $2, $3}')
        local log_time_sec
        log_time_sec=$(date -j -f "%Y-%m-%d %H:%M:%S" "$log_timestamp" "+%s" 2>/dev/null)

        # Filter processes spawned after current boot
        if [ -n "$log_time_sec" ] && [ -n "$current_boot_time" ] && [ "$log_time_sec" -ge "$current_boot_time" ]; then
            local service_name=$(echo "$line" | sed 's/.*Successfully spawned \(.*\)\[.*/\1/')
            local process_info=$(echo "$line" | sed 's/.*\[\(.*\)\]/\1/')
            local pid=$(echo "$process_info" | cut -d':' -f1)
            local user=$(echo "$process_info" | cut -d':' -f2)

            echo "$log_timestamp\t$service_name\t$pid\t$user"
        fi
    done
}

# Create baseline of normal boot process order
create_boot_baseline() {
    log_info "Creating boot process baseline..."

    local baseline_json="{"
    baseline_json+='"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'",'
    baseline_json+='"boot_time":"'$(get_boot_time)'",'
    baseline_json+='"system":"'$(uname -s) $(uname -r)'",'
    baseline_json+='"critical_sequence":{'

    # Get current process list
    local temp_processes=$(mktemp)
    ps aux | awk 'NR>1 {print $2, $11, $1}' | sort -n > "$temp_processes"

    # Map critical daemon PIDs to their names
    local first=true
    for daemon in "${CRITICAL_DAEMONS[@]}"; do
        local daemon_pid=$(ps aux | grep -v grep | grep "$daemon" | head -1 | awk '{print $2}')
        if [ -n "$daemon_pid" ]; then
            local start_time=$(get_process_start "$daemon_pid")
            local parent_pid=$(ps -o ppid= -p "$daemon_pid" 2>/dev/null | tr -d ' ')
            local user=$(ps -o user= -p "$daemon_pid" 2>/dev/null | tr -d ' ')

            if [ "$first" = true ]; then
                first=false
            else
                baseline_json+=","
            fi

            baseline_json+='"'"$daemon"'":{'
            baseline_json+='"pid":'"$daemon_pid"','
            baseline_json+='"start_time":'"$start_time"','
            baseline_json+='"parent_pid":'"$parent_pid"','
            baseline_json+='"user":"'"$user"'",'
            baseline_json+='"expected":true'
            baseline_json+='}'
        fi
    done

    baseline_json+='},"process_tree":{'

    # Build process tree snapshot
    first=true
    while IFS=' ' read -r pid command user; do
        if [ "$first" = true ]; then
            first=false
        else
            baseline_json+=","
        fi

        local parent_pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        local start_time=$(get_process_start "$pid")
        local command_safe=$(echo "$command" | sed 's/"/\\"/g')

        baseline_json+='"'"$pid"'":{'
        baseline_json+='"command":"'"$command_safe"'",'
        baseline_json+='"user":"'"$user"'",'
        baseline_json+='"parent":'"$parent_pid"','
        baseline_json+='"start_time":'"$start_time"''
        baseline_json+='}'

    done < "$temp_processes"

    baseline_json+='},"launchd_log_analysis":{'

    # Analyze launchd logs for spawn sequence
    first=true
    parse_launchd_logs | while IFS=$'\t' read -r timestamp service pid user; do
        if [ -n "$service" ]; then
            if [ "$first" = true ]; then
                first=false
            else
                baseline_json+=","
            fi

            local service_safe=$(echo "$service" | sed 's/"/\\"/g')
            baseline_json+='"'"$(echo "$timestamp" | sed 's/[: ]/-/g')"'":{'
            baseline_json+='"service":"'"$service_safe"'",'
            baseline_json+='"pid":"'"$pid"'",'
            baseline_json+='"user":"'"$user"'"'
            baseline_json+='}'
        fi
    done

    baseline_json+='}}'

    # Write baseline
    echo "$baseline_json" > "$BOOT_PROCESS_BASELINE"
    chmod 600 "$BOOT_PROCESS_BASELINE"
    rm -f "$temp_processes"

    log_success "Boot process baseline created at $BOOT_PROCESS_BASELINE"

    # Show summary
    local daemon_count=$(echo "$baseline_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(len(data.get('critical_sequence', {})))
except:
    print(0)
" <<< "$baseline_json")

    log_info "Baseline contains $daemon_count critical daemons"
}

# Load existing baseline
load_boot_baseline() {
    if [ ! -f "$BOOT_PROCESS_BASELINE" ]; then
        log_warn "No boot process baseline found. Run with --create-baseline first."
        return 1
    fi

    if ! python3 -c "import json; json.load(open('$BOOT_PROCESS_BASELINE'))" 2>/dev/null; then
        log_alert "Boot process baseline is corrupted"
        return 1
    fi

    return 0
}

# Verify critical daemon spawn order
verify_critical_sequence() {
    log_info "Verifying critical daemon spawn sequence..."

    if ! load_boot_baseline; then
        return 1
    fi

    local violations=false
    local missing_daemons=""

    # Check each critical daemon
    for daemon in "${CRITICAL_DAEMONS[@]}"; do
        local daemon_pid=$(ps aux | grep -v grep | grep "$daemon" | head -1 | awk '{print $2}')

        if [ -z "$daemon_pid" ]; then
            missing_daemons="$missing_daemons $daemon"
            violations=true
            continue
        fi

        # Check baseline info for this daemon
        local baseline_info=$(python3 -c "
import json
with open('$BOOT_PROCESS_BASELINE') as f:
    baseline = json.load(f)
    info = baseline.get('critical_sequence', {}).get('$daemon')
    if info:
        print(f'{info[\"pid\"]}\t{info[\"user\"]}\t{info[\"parent_pid\"]}')
" 2>/dev/null)

        if [ -n "$baseline_info" ]; then
            local baseline_pid=$(echo "$baseline_info" | cut -d$'\t' -f1)
            local baseline_user=$(echo "$baseline_info" | cut -d$'\t' -f2)
            local baseline_parent=$(echo "$baseline_info" | cut -d$'\t' -f3)

            local current_user=$(ps -o user= -p "$daemon_pid" 2>/dev/null | tr -d ' ')
            local current_parent=$(ps -o ppid= -p "$daemon_pid" 2>/dev/null | tr -d ' ')

            # Check for user changes
            if [ "$current_user" != "$baseline_user" ]; then
                log_alert "Critical daemon user changed: $daemon"
                log_alert "  Expected user: $baseline_user"
                log_alert "  Current user:  $current_user"
                violations=true
            fi

            # Check for parent PID changes (suspicious)
            if [ "$current_parent" != "$baseline_parent" ]; then
                log_warn "Critical daemon parent changed: $daemon"
                log_warn "  Expected parent: $baseline_parent"
                log_warn "  Current parent:  $current_parent"
            fi
        fi
    done

    if [ -n "$missing_daemons" ]; then
        log_alert "Missing critical daemons:$missing_daemons"
    fi

    if [ "$violations" = false ]; then
        log_success "Critical daemon sequence verified"
    else
        log_alert "Critical daemon sequence violations detected"
        return 1
    fi
}

# Detect anomalous processes
detect_anomalous_processes() {
    log_info "Scanning for anomalous processes..."

    local anomalies=false

    # Check for suspicious process names
    for pattern in "${SUSPICIOUS_PATTERNS[@]}"; do
        local suspicious_procs=$(ps aux | grep -E "$pattern" | grep -v grep)
        if [ -n "$suspicious_procs" ]; then
            log_alert "Suspicious processes detected (pattern: $pattern):"
            echo "$suspicious_procs" | while IFS= read -r line; do
                log_alert "  $line"
            done
            anomalies=true
        fi
    done

    # Check for processes with unusual parents
    while IFS= read -r pid; do
        if [ -n "$pid" ]; then
            local parent=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
            local parent_name=$(ps -o comm= -p "$parent" 2>/dev/null)

            # Check if parent is a legitimate system process
            case "$parent_name" in
                "launchd"|1)
                    # Legitimate
                    ;;
                *)
                    # Check if parent exists and is legitimate
                    if [ -n "$parent_name" ]; then
                        # Could be suspicious parentage
                        local cmd=$(ps -o comm= -p "$pid" 2>/dev/null)
                        log_warn "Process with unusual parent: $cmd (PID: $pid, Parent: $parent_name)"
                        anomalies=true
                    fi
                    ;;
            esac
        fi
    done < <(ps axo pid | awk 'NR>1')

    # Check for processes running from unusual locations
    local unusual_procs=$(ps aux | grep -E "/tmp|/var/tmp|/private/tmp" | grep -v grep)
    if [ -n "$unusual_procs" ]; then
        log_alert "Processes running from temporary directories:"
        echo "$unusual_procs" | while IFS= read -r line; do
            log_alert "  $line"
        done
        anomalies=true
    fi

    # Check for processes with setuid/setgid bits
    local setuid_procs=$(find /usr/bin /usr/sbin /bin /sbin -type f -perm +4000 -ls 2>/dev/null)
    if [ -n "$setuid_procs" ]; then
        log_info "SUID/SGID executables found (normal for system):"
        echo "$setuid_procs" | head -5 | while IFS= read -r line; do
            log_info "  $(echo "$line" | awk '{print $11}')"
        done
    fi

    if [ "$anomalies" = false ]; then
        log_success "No anomalous processes detected"
    else
        log_alert "Anomalous processes detected - system may be compromised"
        return 1
    fi
}

# Analyze process tree integrity
analyze_process_tree() {
    log_info "Analyzing process tree integrity..."

    if ! load_boot_baseline; then
        return 1
    fi

    # Compare current process tree with baseline
    local current_processes=$(ps aux | awk 'NR>1 {print $2, $11, $1}' | sort -n)
    local baseline_process_count=$(python3 -c "
import json
with open('$BOOT_PROCESS_BASELINE') as f:
    baseline = json.load(f)
    print(len(baseline.get('process_tree', {})))
" 2>/dev/null)

    local current_process_count=$(echo "$current_processes" | wc -l | tr -d ' ')

    log_info "Process count comparison:"
    log_info "  Baseline: $baseline_process_count processes"
    log_info "  Current:  $current_process_count processes"

    # Check for significant deviation in process count
    local process_diff=$((current_process_count - baseline_process_count))
    if [ "$process_diff" -gt 50 ]; then
        log_alert "Unusual increase in process count: +$process_diff processes"
    elif [ "$process_diff" -lt -50 ]; then
        log_alert "Unusual decrease in process count: $process_diff processes"
    fi

    # Check for processes running as unusual users
    local unusual_users=$(ps aux | awk '{print $1}' | sort | uniq -c | sort -nr | awk '$1 < 3 && $1 > 1')
    if [ -n "$unusual_users" ]; then
        log_warn "Processes running from unusual user accounts:"
        echo "$unusual_users" | while IFS= read -r line; do
            log_warn "  $line"
        done
    fi
}

# Monitor real-time process spawning
monitor_realtime() {
    log_info "Starting real-time process monitoring..."
    log_info "Press Ctrl+C to stop monitoring"

    # Monitor launchd logs in real-time
    local launchd_log="/var/log/com.apple.xpc.launchd/launchd.log"
    if [ -f "$launchd_log" ]; then
        tail -f "$launchd_log" | grep --line-buffered "Successfully spawned" | while IFS= read -r line; do
            local service=$(echo "$line" | sed 's/.*Successfully spawned \(.*\)\[.*/\1/')
            local process_info=$(echo "$line" | sed 's/.*\[\(.*\)\]/\1/')
            local pid=$(echo "$process_info" | cut -d':' -f1)
            local user=$(echo "$process_info" | cut -d':' -f2)

            # Check if this is a known critical daemon
            local is_critical=false
            for daemon in "${CRITICAL_DAEMONS[@]}"; do
                if [[ "$service" == *"$daemon"* ]]; then
                    is_critical=true
                    break
                fi
            done

            if [ "$is_critical" = true ]; then
                log_info "Critical daemon spawned: $service (PID: $pid, User: $user)"
            else
                log_info "Process spawned: $service (PID: $pid, User: $user)"

                # Check for suspicious patterns
                for pattern in "${SUSPICIOUS_PATTERNS[@]}"; do
                    if [[ "$service" =~ $pattern ]]; then
                        log_alert "Suspicious process spawn detected: $service"
                        break
                    fi
                done
            fi
        done
    else
        log_warn "Launchd log not found, falling back to polling mode"

        # Fallback: poll every 5 seconds
        while true; do
            local new_processes=$(ps aux | tail -n +2)
            sleep 5
        done
    fi
}

# Generate boot monitoring report
generate_boot_report() {
    log_info "Generating boot integrity monitoring report..."

    local report_file="${BASELINE_DIR}/boot_monitoring_report.txt"

    {
        echo "Boot Integrity Monitoring Report"
        echo "==============================="
        echo "Generated: $(date)"
        echo "System: $(uname -s) $(uname -r)"
        echo "Boot Time: $(get_boot_time)"
        echo ""

        echo "Critical Daemon Status:"
        echo "-----------------------"
        for daemon in "${CRITICAL_DAEMONS[@]}"; do
            local daemon_pid=$(ps aux | grep -v grep | grep "$daemon" | head -1 | awk '{print $2}')
            if [ -n "$daemon_pid" ]; then
                local daemon_user=$(ps -o user= -p "$daemon_pid" 2>/dev/null | tr -d ' ')
                local daemon_parent=$(ps -o ppid= -p "$daemon_pid" 2>/dev/null | tr -d ' ')
                echo "$daemon: RUNNING (PID: $daemon_pid, User: $daemon_user, Parent: $daemon_parent)"
            else
                echo "$daemon: MISSING"
            fi
        done
        echo ""

        echo "Process Summary:"
        echo "---------------"
        echo "Total processes: $(ps aux | wc -l)"
        echo "User processes: $(ps aux | awk '$1 != "root" && $1 != "daemon" && $1 != "_windowserver" {print $1}' | sort -u | wc -l | tr -d ' ') different users"
        echo ""

        echo "System Resources:"
        echo "----------------"
        echo "Memory usage: $(vm_stat | head -1)"
        echo "Load average: $(uptime | awk -F'load average:' '{print $2}')"
        echo ""

        echo "Recent Alerts:"
        echo "--------------"
        if [ -f "$BOOT_ALERTS" ]; then
            tail -10 "$BOOT_ALERTS" 2>/dev/null || echo "No recent alerts"
        else
            echo "No alerts logged"
        fi

    } > "$report_file"

    log_success "Boot monitoring report generated: $report_file"
}

# Main function
main() {
    local action="${1:-verify}"

    case "$action" in
        "--create-baseline"|"baseline")
            create_boot_baseline
            ;;
        "--verify"|"check"|"verify")
            verify_critical_sequence
            detect_anomalous_processes
            analyze_process_tree
            ;;
        "--monitor"|"monitor")
            monitor_realtime
            ;;
        "--quick"|"quick")
            verify_critical_sequence
            detect_anomalous_processes
            ;;
        "--report"|"report")
            generate_boot_report
            ;;
        "--help"|"help"|"-h")
            echo "Boot Integrity Monitor"
            echo "====================="
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  baseline     Create boot process baseline"
            echo "  verify       Verify boot process integrity (default)"
            echo "  monitor      Real-time process monitoring"
            echo "  quick        Quick verification check"
            echo "  report       Generate monitoring report"
            echo "  help         Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 baseline                    # Create baseline"
            echo "  $0                             # Verify boot processes"
            echo "  $0 monitor                     # Real-time monitoring"
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