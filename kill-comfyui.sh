#!/usr/bin/env bash
# kill-comfyui.sh
set -euo pipefail

detect_engine() {
    local engine=${CONTAINER_ENGINE:-}

    if [[ -n ${engine} ]]; then
        if ! command -v "${engine}" >/dev/null 2>&1; then
            echo "[!] Requested container engine '${engine}' not found on PATH" >&2
            exit 1
        fi
    else
        if command -v podman >/dev/null 2>&1; then
            engine=podman
        elif command -v docker >/dev/null 2>&1; then
            engine=docker
        else
            echo "[!] Neither podman nor docker is available. Install one of them first." >&2
            exit 1
        fi
    fi

    printf '%s' "${engine}"
}

detect_compose() {
    local engine=$1

    if [[ ${engine} == podman ]]; then
        if podman compose version >/dev/null 2>&1; then
            COMPOSE_CMD=(podman compose)
            return
        elif command -v podman-compose >/dev/null 2>&1; then
            COMPOSE_CMD=(podman-compose)
            return
        fi
    else
        if docker compose version >/dev/null 2>&1; then
            COMPOSE_CMD=(docker compose)
            return
        elif command -v docker-compose >/dev/null 2>&1; then
            COMPOSE_CMD=(docker-compose)
            return
        fi
    fi

    echo "[!] No compose plugin/binary found for '${engine}'." >&2
    exit 1
}

ENGINE=$(detect_engine)
detect_compose "${ENGINE}"

COMPOSE_FILES=(-f docker-compose.yml)
if [[ ${ENGINE} == podman && -f docker-compose.podman.yml ]]; then
    COMPOSE_FILES+=(-f docker-compose.podman.yml)
fi

echo ">>> Stopping ComfyUI stack via ${COMPOSE_CMD[*]}"
"${COMPOSE_CMD[@]}" "${COMPOSE_FILES[@]}" down --remove-orphans || true

echo ">>> Removing leftover containers (if any)"
if [[ ${ENGINE} == podman ]]; then
    "${ENGINE}" rm -f --depend comfyui comfyui-proxy 2>/dev/null || true
else
    "${ENGINE}" rm -f comfyui comfyui-proxy 2>/dev/null || true
fi

