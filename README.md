# comfyui-podman-compose

## Introduction

This repository provides a Podman Compose setup for running the **ComfyUI** image-generation interface in a containerized environment with GPU acceleration.

### Prerequisites
- A Linux host with **Podman** and **Podman Compose** installed.
- An NVIDIA GPU with driver support.
- The **NVIDIA Container Toolkit** (`nvidia-container-toolkit`), which supplies the `nvidia-ctk` utility. After installation, generate a CDI (Container Device Interface) specification so Podman can discover your GPU:
  ```bash
  sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
  ```
  This creates the `nvidia.com/gpu` device used by the compose file.

### Directory Layout
Create these directories in the repository root before starting:
- `custom_nodes/`
- `models/`
- `output/`
- `venv/`

### Starting the Service
1. Clone the repository and move into it.
2. Create the required directories listed above.
3. Build and launch the container (the helper script performs both steps and tails the logs):
   ```bash
   ./run_comfy.sh
   ```
   This script rebuilds the image if needed and brings the service up on port **8188**.
4. Open `http://localhost:8188` in your browser to access ComfyUI.

### Stopping the Service
```bash
./kill-cofyui.sh
```
This removes all running ComfyUI containers in one step.

## Beginner's Overview

This repository targets users who want to run **ComfyUI** in a **Podman Compose** environment. It consists mainly of shell scripts and a `podman-compose.yml` file that automate building and starting the container.

### Repository Structure
- `podman-compose.yml`: Container configuration (GPU access, ports, volumes).
- `dockerfile`: Base image and runtime setup.
- `entrypoint.sh`: Script executed in the container (creates symlinks, checks out code, prepares the Python virtual environment, launches ComfyUI).
- Helper scripts:
  - `run_comfy.sh`: builds the image, starts the container, and follows logs.
  - `kill-cofyui.sh`: stops running containers.
  - `clear_podman_cache.sh`: removes Podman caches.

### Key Learning Areas
1. **Containerization with Podman/Docker** – building a `Dockerfile` and using `podman-compose.yml`.
2. **Shell scripting** – automating build, start, and cleanup tasks.
3. **Python environments** – creating and maintaining a virtual environment.
4. **ComfyUI specifics** – directory layout and start parameters (`--listen`, `--lowvram`, etc.).

### Tips for Beginners
- **Understand Podman/Docker basics**: how images are built and containers started.
- **Practice shell scripting**: reading and adapting Bash scripts is essential here.
- **Learn about volumes & symlinks**: they enable mounting host data into containers.
- **Pay attention to GPU configuration**: GPU usage requires proper drivers and runtime support.
- **Experiment with ComfyUI**: start the environment and explore the UI to grasp the workflow.
