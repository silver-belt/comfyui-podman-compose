#!/usr/bin/env bash
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
  echo "    Install the matching compose implementation (e.g. docker compose, docker-compose, podman compose, podman-compose)." >&2
  exit 1
}

ENGINE=$(detect_engine)
detect_compose "${ENGINE}"

COMPOSE_FILES=(-f docker-compose.yml)
if [[ ${ENGINE} == podman && -f docker-compose.podman.yml ]]; then
  COMPOSE_FILES+=(-f docker-compose.podman.yml)
fi

echo "[+] Using container engine : ${ENGINE}"
echo "[+] Using compose command  : ${COMPOSE_CMD[*]}"
echo "[+] Compose files          : ${COMPOSE_FILES[*]//-f /}"

# Ensure bind-mount targets exist with appropriate permissions
prepare_bind_mount_dir() {
  local dir=$1
  local mode=${2:-}

  mkdir -p "${dir}"
  chown "$(id -u):$(id -g)" "${dir}"

  if [[ -n ${mode} ]]; then
    chmod "${mode}" "${dir}"
  fi
}

prepare_bind_mount_dir tmp_disk 1777
prepare_bind_mount_dir temp_disk 1777

# Build container image
"${COMPOSE_CMD[@]}" "${COMPOSE_FILES[@]}" build

# Container start & follow logs
"${COMPOSE_CMD[@]}" "${COMPOSE_FILES[@]}" up -d --force-recreate --remove-orphans
"${ENGINE}" logs -f comfyui

