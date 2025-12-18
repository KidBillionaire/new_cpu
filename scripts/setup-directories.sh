#!/bin/bash

# setup-directories.sh - Create sandbox directory structure
# Idempotent: Safe to run multiple times

set -e

HOME_DIR="${HOME}"
SANDBOX_DIR="${HOME_DIR}/.sandbox"
SHARED_DIR="${SANDBOX_DIR}/shared"
CORE_DIR="${SANDBOX_DIR}/core"
SECRETS_DIR="${CORE_DIR}/secrets"

# Verify home directory exists and is writable
if [ ! -d "${HOME_DIR}" ] || [ ! -w "${HOME_DIR}" ]; then
    echo "Error: Home directory ${HOME_DIR} does not exist or is not writable" >&2
    exit 1
fi

# Create ~/.sandbox with permissions 700
if [ ! -d "${SANDBOX_DIR}" ]; then
    if ! mkdir -p "${SANDBOX_DIR}"; then
        echo "Error: Failed to create ${SANDBOX_DIR}" >&2
        exit 2
    fi
fi
chmod 700 "${SANDBOX_DIR}"

# Create ~/.sandbox/shared with permissions 755
if [ ! -d "${SHARED_DIR}" ]; then
    if ! mkdir -p "${SHARED_DIR}"; then
        echo "Error: Failed to create ${SHARED_DIR}" >&2
        exit 2
    fi
fi
chmod 755 "${SHARED_DIR}"

# Create ~/.sandbox/core with permissions 700
if [ ! -d "${CORE_DIR}" ]; then
    if ! mkdir -p "${CORE_DIR}"; then
        echo "Error: Failed to create ${CORE_DIR}" >&2
        exit 2
    fi
fi
chmod 700 "${CORE_DIR}"

# Create ~/.sandbox/core/secrets with permissions 700
if [ ! -d "${SECRETS_DIR}" ]; then
    if ! mkdir -p "${SECRETS_DIR}"; then
        echo "Error: Failed to create ${SECRETS_DIR}" >&2
        exit 2
    fi
fi
chmod 700 "${SECRETS_DIR}"

# Verify permissions
if [ "$(stat -f '%A' "${SANDBOX_DIR}" 2>/dev/null || stat -c '%a' "${SANDBOX_DIR}" 2>/dev/null)" != "700" ]; then
    echo "Warning: ${SANDBOX_DIR} permissions may be incorrect" >&2
fi

if [ "$(stat -f '%A' "${SHARED_DIR}" 2>/dev/null || stat -c '%a' "${SHARED_DIR}" 2>/dev/null)" != "755" ]; then
    echo "Warning: ${SHARED_DIR} permissions may be incorrect" >&2
fi

if [ "$(stat -f '%A' "${CORE_DIR}" 2>/dev/null || stat -c '%a' "${CORE_DIR}" 2>/dev/null)" != "700" ]; then
    echo "Warning: ${CORE_DIR} permissions may be incorrect" >&2
fi

if [ "$(stat -f '%A' "${SECRETS_DIR}" 2>/dev/null || stat -c '%a' "${SECRETS_DIR}" 2>/dev/null)" != "700" ]; then
    echo "Warning: ${SECRETS_DIR} permissions may be incorrect" >&2
fi

exit 0
