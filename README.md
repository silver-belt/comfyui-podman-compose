# comfyui-podman-compose

## Introduction

This repository provides a containerised setup for running the **ComfyUI** image‑generation interface with GPU acceleration.
It supports both **Podman** and **Docker**, and can optionally serve the UI behind an `nginx` reverse proxy with **HTTPS** and **Basic Authentication**.

---

## Platform prerequisites

### Linux (Podman)

- A Linux host with **Podman** (v4.0+) and either the `podman compose` plugin or the standalone **podman-compose** tool installed.
- An **NVIDIA GPU** with the proprietary driver.
- The **NVIDIA Container Toolkit** (`nvidia-container-toolkit`) to expose GPUs via CDI:
  ```bash
  sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
  ```
  This generates the `nvidia.com/gpu` CDI specification consumed by the Podman override file.

### Windows (Docker Desktop)

- **Docker Desktop** with the WSL2-based engine enabled.
- GPU support enabled in Docker Desktop (Settings → Resources → GPU). An NVIDIA GPU with recent drivers is required.
- Windows Terminal or PowerShell with Git available. When running scripts, execute them from a **Git Bash** or **WSL** shell to ensure POSIX compatibility.

---

## Directory Layout

Create these directories in the repository root before starting:
- `custom_nodes/`
- `models/`
- `output/`
- `venv/`

---

## Engine-specific configuration

### Linux (Podman)

- `docker-compose.yml` is combined with `docker-compose.podman.yml` to inject the CDI GPU device (`nvidia.com/gpu=all`) and disable SELinux relabeling conflicts.
- Ensure `/etc/cdi/nvidia.yaml` exists (see prerequisites) so that the GPU becomes available inside the container.

### Windows (Docker Desktop)

- Only the base `docker-compose.yml` is used. Docker Desktop maps the GPU automatically when GPU support is enabled in the settings.
- Volume mounts rely on WSL2 paths. If you run the scripts from PowerShell, ensure the repository lives inside your WSL2 home directory or convert the paths with `wslpath`.

---

## Reverse Proxy with HTTPS & Basic Authentication

Optionally, the ComfyUI instance can be served through an `nginx` reverse proxy with HTTPS and Basic Auth:

1. **Create a password file** (example user `user` with password `changeme`):
   ```bash
   printf "user:$(openssl passwd -apr1 'changeme')\n" > nginx/htpasswd
   ```
2. **Provide a TLS certificate and key**:  
   - `nginx/certs/server.crt`  
   - `nginx/certs/server.key`  
   A self‑signed certificate for local testing can be generated with:
   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout nginx/certs/server.key \
     -out nginx/certs/server.crt \
     -subj "/CN=localhost"
   ```

**Note:** Both the password file and TLS certificate are ignored by Git and must be created locally.

---

## Starting the Services

1. Clone the repository and enter the directory:
   ```bash
   git clone <repo-url>
   cd comfyui-podman-compose
   ```
2. Create the required directories listed above.
3. Start the container:
    ```bash
    ./run_comfy.sh
    ```
   The helper script auto-detects the available container engine. Override the detection with `CONTAINER_ENGINE=docker ./run_comfy.sh` or `CONTAINER_ENGINE=podman ./run_comfy.sh` if multiple engines are installed.
   - **Standard (no proxy)** (Port 8188):
     → ComfyUI is available at <http://localhost:8188>
   - **With nginx reverse proxy** (Port 8443, HTTPS & Auth):
     → ComfyUI is available at <https://localhost:8443> (protected by credentials in `nginx/htpasswd`)

---

## Pinning the ComfyUI Version

The container respects the environment variable `COMFYUI_REF` to select the desired
branch, tag, or commit of the upstream ComfyUI repository during the initial clone
and subsequent updates. To pin the deployment to a specific version, export the variable
before running the helper scripts. Examples:

```bash
# Podman on Linux
COMFYUI_REF=v1.3.3 CONTAINER_ENGINE=podman ./run_comfy.sh

# Docker Desktop on Windows / WSL
COMFYUI_REF=v1.3.3 CONTAINER_ENGINE=docker ./run_comfy.sh
```

Omit the variable (or reset it to the default `master`) to follow the upstream default branch again.

---

## Stopping the Services

```bash
./kill-comfyui.sh
```
Stops the running ComfyUI stack using the same container engine that `run_comfy.sh` detected (or the engine specified through `CONTAINER_ENGINE`).

---

## Repository Structure

- `docker-compose.yml` – Base container configuration (GPU access, ports, volumes)
- `docker-compose.podman.yml` – Podman-specific extensions (CDI GPU device & SELinux labels)
- `dockerfile` – Base image and runtime setup
- `entrypoint.sh` – Container entrypoint (symlinks, code checkout, Python virtual environment, launch ComfyUI)
- Helper scripts:
  - `run_comfy.sh` – builds the image, starts the container stack, follows logs (auto-detects Docker vs Podman)
  - `kill-comfyui.sh` – stops and removes the running stack (auto-detects Docker vs Podman)
  - `clear_podman_cache.sh` – removes Podman cache data

---

## Learning Aspects

1. **Containerization with Podman & Docker** – building images and running containers
2. **Shell scripting** – automating build, start, and cleanup tasks  
3. **Python virtual environments** – creating and managing isolated environments  
4. **GPU configuration** – NVIDIA drivers and container runtime support  
5. **Reverse Proxy & HTTPS** – basic authentication and TLS management  
6. **ComfyUI basics** – directory layout and start parameters (`--listen`, `--lowvram`, etc.)
