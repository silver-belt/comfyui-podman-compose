# ---------- Stage: base ----------
FROM nvidia/cuda:12.8.1-runtime-ubuntu24.04

# Configure environment variables and paths
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    VENV_PATH=/opt/venv \
    WORKDIR=/workspace \
    PATH="/opt/venv/bin:$PATH"

# Install system dependencies required for ComfyUI
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git python3 python3-venv python3-pip ffmpeg tini \
        # Install Mesa/GL and GLib so OpenCV can load libGL.so.1 for ComfyUI-VideoHelperSuite
        libglib2.0-0 libgl1 libglx-mesa0 fonts-dejavu-core fontconfig \
        libsm6 libxext6 libxrender1 \
        # only if custom nodes need ability to compile: build-essential python3-dev pkg-config \
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
    TMPDIR=/tmp \
    CUDA_CACHE_PATH=/tmp/ComputeCache \
    CUDA_CACHE_MAXSIZE=536870912

# Prepare shared cache and temporary directories
RUN mkdir -p /workspace/.cache /tmp && \
    # One temp path, two entrances: /workspace/temp -> /tmp (same tmpfs)
    ln -sfn /tmp /workspace/temp

# Install Torch/cu128 & xformers
RUN pip install --upgrade pip wheel setuptools && \
    pip install \
      torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 \
      --index-url https://download.pytorch.org/whl/cu128 && \
    pip install xformers==0.0.27.post2 sageattention

RUN chown -R "${UID}:${GID}" /opt/venv "$WORKDIR"

USER comfy
WORKDIR $WORKDIR

RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git ComfyUI
RUN grep -vE '^(torch|torchvision|torchaudio|xformers)($|=)' ComfyUI/requirements.txt > /tmp/req.txt \
    && pip install -r /tmp/req.txt

# Copy application entrypoint and dependency patches
COPY --chown=comfy:comfy entrypoint.sh /entrypoint.sh
COPY --chown=comfy:comfy patch-requirements.txt /patch-requirements.txt
ENTRYPOINT ["/usr/bin/tini","--","/entrypoint.sh"]
EXPOSE 8188

