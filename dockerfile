# ---------- Stage: base ----------
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    VENV_PATH=/opt/venv \
    WORKDIR=/workspace \
    PATH="/opt/venv/bin:$PATH"

RUN apt-get update && apt-get install -y --no-install-recommends \
      git python3 python3-venv python3-pip libglib2.0-0 libgl1 ffmpeg tini \
    && rm -rf /var/lib/apt/lists/*

ARG UID=1000
ARG GID=1000
ARG COMFYUI_REF=master
RUN groupadd -g $GID comfy && useradd -u $UID -g comfy -m -d $WORKDIR comfy
ENV COMFYUI_REF=$COMFYUI_REF
USER comfy
WORKDIR $WORKDIR

COPY --chown=comfy:comfy entrypoint.sh /entrypoint.sh
COPY --chown=comfy:comfy patch-requirements.txt /patch-requirements.txt
ENTRYPOINT ["/usr/bin/tini","--","/entrypoint.sh"]
EXPOSE 8188

