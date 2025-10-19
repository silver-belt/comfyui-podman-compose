# ---------- Stage: base ----------
FROM nvidia/cuda:12.8.1-runtime-ubuntu24.04

# Configure environment variables and paths
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    VENV_PATH=/opt/venv \
    WORKDIR=/workspace \
    PATH="/opt/venv/bin:$PATH"
# make ~/.local/bin available on the PATH so scripts like tqdm, torchrun, etc. are found
ENV PATH=/home/appuser/.local/bin:$PATH

# Install system dependencies required for ComfyUI
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git python3 python3-venv python3-pip ffmpeg tini \
        # Install Mesa/GL and GLib so OpenCV can load libGL.so.1 for ComfyUI-VideoHelperSuite
        libglib2.0-0 libgl1 libglx-mesa0 fonts-dejavu-core fontconfig \
        libsm6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# Configure application user
ARG UID=1000
ARG GID=1000
ARG COMFYUI_REF=master
RUN set -eux; \
    groupadd --gid "${GID}" comfy; \
    useradd --uid "${UID}" --gid "${GID}" \
        --create-home --home-dir "$WORKDIR" \
        --shell /bin/bash --no-log-init comfy
ENV COMFYUI_REF=$COMFYUI_REF
# --- Built-in virtual environment (fast, reproducible) ---
WORKDIR $WORKDIR
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}" \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=0 \
    XDG_CACHE_HOME=/workspace/.cache \
    HF_HOME=/workspace/.cache/huggingface \
    TORCH_HOME=/workspace/.cache/torch \
    PIP_CACHE_DIR=/workspace/.cache/pip \
    # CUDA JIT cache in RAM (tmpfs)
    CUDA_CACHE_PATH=/tmp/ComputeCache \
    # Single temp location pointing to /tmp (tmpfs) – Compose can override
    TMPDIR=/tmp

# Prepare shared cache and temporary directories
RUN mkdir -p /workspace/.cache /tmp && \
    # One temp path, two entrances: /workspace/temp -> /tmp (same tmpfs)
    ln -sfn /tmp /workspace/temp

# Install Torch/cu128 & xformers during the build (not in the entrypoint)
RUN pip install --upgrade pip wheel setuptools && \
    pip install \
      torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 \
      --index-url https://download.pytorch.org/whl/cu128 && \
    pip install xformers==0.0.27.post2 sageattention

RUN chown -R "${UID}:${GID}" /opt/venv "$WORKDIR"

USER comfy
WORKDIR $WORKDIR

# Copy application entrypoint and dependency patches
COPY --chown=comfy:comfy entrypoint.sh /entrypoint.sh
COPY --chown=comfy:comfy patch-requirements.txt /patch-requirements.txt
ENTRYPOINT ["/usr/bin/tini","--","/entrypoint.sh"]
EXPOSE 8188

