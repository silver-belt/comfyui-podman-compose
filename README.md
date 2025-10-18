# comfyui-podman-compose

## Introduction

This repository provides a **Podman Compose** setup for running the **ComfyUI** image‑generation interface in a containerized environment with GPU acceleration.  
Optionally, the service can run behind an `nginx` reverse proxy with **HTTPS** and **Basic Authentication**.

---

## Prerequisites

- A Linux host with **Podman** and **Podman Compose** installed.  
- An **NVIDIA GPU** with driver support.  
- The **NVIDIA Container Toolkit** (`nvidia-container-toolkit`), which provides the `nvidia-ctk` utility:  
  ```bash
  sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
  ```
  This creates the `nvidia.com/gpu` CDI specification used by the compose file.

---

## Directory Layout

Create these directories in the repository root before starting:
- `custom_nodes/`
- `models/`
- `output/`
- `venv/`

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
   - **Standard (no proxy)** (Port 8188):
     → ComfyUI is available at <http://localhost:8188>  
   - **With nginx reverse proxy** (Port 8443, HTTPS & Auth):
     → ComfyUI is available at <https://localhost:8443> (protected by credentials in `nginx/htpasswd`)

---

## Stopping the Services

```bash
./kill-comfyui.sh
```
Stops all running ComfyUI containers.

---

## Repository Structure

- `podman-compose.yml` – Container configuration (GPU access, ports, volumes)
- `Dockerfile` – Base image and runtime setup
- `entrypoint.sh` – Container entrypoint (symlinks, code checkout, Python virtual environment, launch ComfyUI)
- Helper scripts:
  - `run_comfy.sh` – builds image, starts container, follows logs
  - `kill-comfyui.sh` – stops running containers
  - `clear_podman_cache.sh` – removes Podman cache data

---

## Learning Aspects

1. **Containerization with Podman** – building images and running containers  
2. **Shell scripting** – automating build, start, and cleanup tasks  
3. **Python virtual environments** – creating and managing isolated environments  
4. **GPU configuration** – NVIDIA drivers and container runtime support  
5. **Reverse Proxy & HTTPS** – basic authentication and TLS management  
6. **ComfyUI basics** – directory layout and start parameters (`--listen`, `--lowvram`, etc.)
