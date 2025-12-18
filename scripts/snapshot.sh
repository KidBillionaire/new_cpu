#!/bin/bash

# snapshot.sh - Create container snapshots with 24-snapshot retention

set -e

SANDBOX_DIR="${HOME}/.sandbox"
LOG_FILE="${SANDBOX_DIR}/snapshots.log"
CONTAINER_WHITELIST=("sb-dev" "sb-life" "sb-core")

# Ensure log directory exists
mkdir -p "${SANDBOX_DIR}"
touch "${LOG_FILE}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

validate_container() {
    local container="$1"
    for valid in "${CONTAINER_WHITELIST[@]}"; do
        if [ "${container}" = "${valid}" ]; then
            return 0
        fi
    done
    echo "Error: Invalid container name '${container}'. Must be one of: ${CONTAINER_WHITELIST[*]}" >&2
    exit 2
}

check_disk_space() {
    local available_space
    if command -v df >/dev/null 2>&1; then
        # Check available space in GB (macOS uses df -g, Linux uses df -BG or df -h)
        if df -g . >/dev/null 2>&1; then
            available_space=$(df -g . | tail -1 | awk '{print $4}')
        else
            available_space=$(df -BG . 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//' || df -h . | tail -1 | awk '{print $4}' | sed 's/G//')
        fi
        if [ -z "${available_space}" ] || [ "${available_space}" -lt 1 ]; then
            echo "Error: Insufficient disk space (less than 1GB available)" >&2
            exit 2
        fi
    fi
}

check_container_running() {
    local container="$1"
    if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        echo "Error: Container ${container} is not running" >&2
        exit 1
    fi
}

create_snapshot() {
    local container="$1"
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    local snapshot_name="${container}-${timestamp}-auto"
    
    log "Creating snapshot: ${snapshot_name} for container: ${container}"
    
    if docker commit "${container}" "${snapshot_name}"; then
        # Verify snapshot was created
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${snapshot_name}$"; then
            log "Snapshot created successfully: ${snapshot_name}"
            echo "${snapshot_name}"
            return 0
        else
            log "Error: Snapshot verification failed for: ${snapshot_name}"
            return 1
        fi
    else
        log "Error: Failed to create snapshot: ${snapshot_name}"
        return 1
    fi
}

cleanup_old_snapshots() {
    local container="$1"
    local keep_count=24
    
    log "Cleaning up old snapshots for ${container}, keeping latest ${keep_count}"
    
    # Get all snapshots for this container, sort by creation date (newest first)
    local snapshots
    snapshots=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^${container}-" | sort -r)
    
    local count=0
    local to_delete=""
    
    while IFS= read -r snapshot; do
        if [ -z "${snapshot}" ]; then
            continue
        fi
        count=$((count + 1))
        if [ "${count}" -gt "${keep_count}" ]; then
            to_delete="${to_delete} ${snapshot}"
        fi
    done <<< "${snapshots}"
    
    if [ -n "${to_delete}" ]; then
        for snapshot in ${to_delete}; do
            log "Deleting old snapshot: ${snapshot}"
            docker rmi "${snapshot}" 2>/dev/null || log "Warning: Failed to delete ${snapshot}"
        done
    else
        log "No snapshots to delete (${count} total, keeping ${keep_count})"
    fi
}

main() {
    local container="$1"
    
    if [ -z "${container}" ]; then
        echo "Error: Container name required. Usage: snapshot.sh [sb-dev|sb-life|sb-core]" >&2
        exit 2
    fi
    
    validate_container "${container}"
    check_disk_space
    check_container_running "${container}"
    
    # Create snapshot (atomic operation)
    local snapshot_name
    if snapshot_name=$(create_snapshot "${container}"); then
        # Only cleanup if snapshot creation succeeded
        cleanup_old_snapshots "${container}"
        log "Snapshot operation completed successfully for ${container}"
        exit 0
    else
        log "Snapshot operation failed for ${container}"
        exit 1
    fi
}

main "$@"
