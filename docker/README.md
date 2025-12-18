# Docker Configuration

This directory contains all Docker-related configuration files.

## Files

- **docker-compose.yml** - Container orchestration configuration
  - Defines all three containers (sb-dev, sb-life, sb-core)
  - Network configuration
  - Volume mounts
  - Resource limits (if configured)

- **Dockerfile.sb-dev** - Development container image
  - Full capabilities (`cap_add: ALL`)
  - Root user
  - Development tools installed

- **Dockerfile.sb-life** - Life/work container image
  - Restricted user (no sudo)
  - All capabilities dropped
  - Everyday work environment

- **Dockerfile.sb-core** - Core/secrets container image
  - Read-only filesystem
  - No network access
  - Minimal tools
  - Secrets directory mounted read-only

## Building Images

Images are built automatically by `scripts/install.sh`, or manually:

```bash
cd docker/
docker build -f Dockerfile.sb-dev -t sb-dev:1.0.0 .
docker build -f Dockerfile.sb-life -t sb-life:1.0.0 .
docker build -f Dockerfile.sb-core -t sb-core:1.0.0 .
```

## Starting Containers

Use docker-compose from the docker directory:

```bash
cd docker/
docker-compose up -d
```

Or use the `sb` CLI tool from repository root:

```bash
./scripts/sb start
```

## Configuration

All containers share:
- Network: `sandbox-net` (bridge network)
- Shared volume: `~/.sandbox/shared`
- Host directories: `~/Code`, `~/Documents`, `~/Desktop`

Core container additionally has:
- Secrets volume: `~/.sandbox/core/secrets` (read-only)
- No network access (`network_mode: none`)
