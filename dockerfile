# ---------- Stage: base ----------
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

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
USER comfy
WORKDIR $WORKDIR

# Copy application entrypoint and dependency patches
COPY --chown=comfy:comfy entrypoint.sh /entrypoint.sh
COPY --chown=comfy:comfy patch-requirements.txt /patch-requirements.txt
ENTRYPOINT ["/usr/bin/tini","--","/entrypoint.sh"]
EXPOSE 8188

