#!/usr/bin/env bash
set -e

# Build container image
podman-compose build

# Container start & follow Logs
podman-compose up -d --force-recreate --remove-orphans
podman logs -f comfyui_comfyui_1

