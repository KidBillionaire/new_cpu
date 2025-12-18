#!/bin/bash

# install.sh - Install sandbox system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOME_DIR="${HOME}"
SANDBOX_DIR="${HOME_DIR}/.sandbox"
LAUNCHAGENTS_DIR="${HOME_DIR}/Library/LaunchAgents"
PLIST_FILE="${LAUNCHAGENTS_DIR}/com.sandbox.snapshot.plist"
PLIST_SOURCE="${REPO_ROOT}/config/com.sandbox.snapshot.plist"
DOCKER_DIR="${REPO_ROOT}/docker"

log() {
    echo "[INSTALL] $*"
}

error() {
    echo "[ERROR] $*" >&2
}

check_docker() {
    log "Checking for Docker/OrbStack..."
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            log "Docker is installed and running"
            return 0
        else
            error "Docker is installed but not running"
            return 1
        fi
    elif command -v orbstack >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            log "OrbStack is installed and running"
            return 0
        else
            error "OrbStack is installed but not running"
            return 1
        fi
    else
        error "Docker or OrbStack not found. Please install Docker or OrbStack first."
        exit 1
    fi
}

create_directories() {
    log "Creating directory structure..."
    if [ -f "${SCRIPT_DIR}/setup-directories.sh" ]; then
        bash "${SCRIPT_DIR}/setup-directories.sh" || {
            error "Failed to create directory structure"
            exit 3
        }
        log "Directory structure created"
    else
        error "setup-directories.sh not found"
        exit 3
    fi
}

build_images() {
    log "Building Docker images..."
    
    if [ ! -f "${DOCKER_DIR}/Dockerfile.sb-dev" ]; then
        error "Dockerfile.sb-dev not found"
        exit 2
    fi
    if [ ! -f "${DOCKER_DIR}/Dockerfile.sb-life" ]; then
        error "Dockerfile.sb-life not found"
        exit 2
    fi
    if [ ! -f "${DOCKER_DIR}/Dockerfile.sb-core" ]; then
        error "Dockerfile.sb-core not found"
        exit 2
    fi
    
    cd "${DOCKER_DIR}"
    
    log "Building sb-dev image..."
    if ! docker build -f Dockerfile.sb-dev -t sb-dev:1.0.0 .; then
        error "Failed to build sb-dev image"
        exit 2
    fi
    
    log "Building sb-life image..."
    if ! docker build -f Dockerfile.sb-life -t sb-life:1.0.0 .; then
        error "Failed to build sb-life image"
        exit 2
    fi
    
    log "Building sb-core image..."
    if ! docker build -f Dockerfile.sb-core -t sb-core:1.0.0 .; then
        error "Failed to build sb-core image"
        exit 2
    fi
    
    log "All images built successfully"
}

validate_compose() {
    log "Validating docker-compose.yml..."
    if [ ! -f "${DOCKER_DIR}/docker-compose.yml" ]; then
        error "docker-compose.yml not found"
        exit 2
    fi
    
    if command -v docker-compose >/dev/null 2>&1; then
        if ! docker-compose -f "${DOCKER_DIR}/docker-compose.yml" config >/dev/null 2>&1; then
            error "docker-compose.yml validation failed"
            exit 2
        fi
    elif docker compose version >/dev/null 2>&1; then
        if ! docker compose -f "${DOCKER_DIR}/docker-compose.yml" config >/dev/null 2>&1; then
            error "docker-compose.yml validation failed"
            exit 2
        fi
    else
        log "Warning: docker-compose not found, skipping validation"
    fi
    
    log "docker-compose.yml is valid"
}

start_containers() {
    log "Starting containers..."
    cd "${DOCKER_DIR}"
    
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose -f docker-compose.yml up -d || {
            error "Failed to start containers"
            exit 2
        }
    elif docker compose version >/dev/null 2>&1; then
        docker compose -f docker-compose.yml up -d || {
            error "Failed to start containers"
            exit 2
        }
    else
        error "docker-compose not found"
        exit 2
    fi
    
    log "Containers started"
}

create_launchagent() {
    log "Creating LaunchAgent..."
    
    if [ ! -d "${LAUNCHAGENTS_DIR}" ]; then
        if ! mkdir -p "${LAUNCHAGENTS_DIR}"; then
            error "Failed to create LaunchAgents directory. You may need to run: mkdir -p ${LAUNCHAGENTS_DIR}"
            exit 3
        fi
    fi
    
    if [ ! -f "${PLIST_SOURCE}" ]; then
        error "LaunchAgent plist source not found: ${PLIST_SOURCE}"
        exit 2
    fi
    
    # Update plist with correct paths before copying
    if ! sed -e "s|REPO_ROOT_PLACEHOLDER|${REPO_ROOT}|g" -e "s|HOME_PLACEHOLDER|${HOME_DIR}|g" "${PLIST_SOURCE}" > "${PLIST_FILE}"; then
        error "Failed to copy LaunchAgent plist"
        exit 3
    fi
    
    # Validate plist syntax
    if ! plutil -lint "${PLIST_FILE}" >/dev/null 2>&1; then
        error "LaunchAgent plist syntax invalid"
        exit 2
    fi
    
    log "LaunchAgent created: ${PLIST_FILE}"
    log "Note: Load with: launchctl load ${PLIST_FILE}"
}

main() {
    log "Starting sandbox installation..."
    
    check_docker
    create_directories
    build_images
    validate_compose
    start_containers
    create_launchagent
    
    log ""
    log "Installation complete!"
    log ""
    log "Next steps:"
    log "  1. Load LaunchAgent: launchctl load ${PLIST_FILE}"
    log "  2. Use 'sb' command to manage containers"
    log "  3. Check status: sb status"
    log ""
}

main "$@"
