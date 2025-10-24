# syntax=docker/dockerfile:1.7-labs
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
        # only if custom nodes need ability to compile:
        # build-essential python3-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Configure application user
ARG UID=1000
ARG GID=1000
ARG COMFYUI_REF=master
RUN set -eux; \
    # 1) ensure group for $GID exists (might already be there under a different name)
    if ! getent group "${GID}" >/dev/null; then \
        groupadd -g "${GID}" comfy; \
    fi; \
    # 2) create user only if UID not taken yet
    if ! id -u "${UID}" >/dev/null 2>&1; then \
        useradd -u "${UID}" -g "${GID}" --create-home --home-dir "${WORKDIR}" \
               --shell /bin/bash --no-log-init comfy; \
    fi
ENV COMFYUI_REF=$COMFYUI_REF
# Prepare writable paths before switching users
RUN install -d -m 0755 -o "${UID}" -g "${GID}" /opt/venv "${WORKDIR}" "${WORKDIR}/.cache" /tmp /tmp/Input \
    "${WORKDIR}/ComfyUI/custom_nodes" "${WORKDIR}/ComfyUI/user/default"

# Continue as numeric user from this point forward
USER ${UID}:${GID}
ENV HOME=${WORKDIR}
WORKDIR ${WORKDIR}

# --- Built-in virtual environment (fast, reproducible) ---
RUN python3 -m venv /opt/venv
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=0 \
    TMPDIR=/tmp \
    PIP_CACHE_DIR=/workspace/.cache/pip \
    CUDA_CACHE_PATH=/tmp/ComputeCache \
    CUDA_CACHE_MAXSIZE=536870912

# --- Torch/X pins as Constraints
RUN printf '%s\n' \
  'torch==2.8.0' \
  'torchvision==0.23.0' \
  'torchaudio==2.8.0' \
  'xformers==0.0.32.post2' \
  > ${WORKDIR}/constraints.txt

# install PyTorch/cu128 & xformers (with BuildKit-Pipcache for Speed)
# Hint: --mount=type=cache needs DOCKER_BUILDKIT=1
RUN --mount=type=cache,target=/workspace/.cache/pip,id=pip-cache \
    python -m pip install "pip==25.2" "setuptools==80.9.0" "wheel==0.45.1" && \
    python -m pip install \
      --index-url https://download.pytorch.org/whl/cu128 \
      -r ${WORKDIR}/constraints.txt && \
    # Other Low-Level Libs (z. B. sageattention)
    python -m pip install --no-deps sageattention

# install ComfyUI and download requirements (excluding already pinned ones above)
RUN git config --global --add safe.directory /workspace/ComfyUI \
 && git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git ComfyUI \
 && ln -sfn /tmp /workspace/ComfyUI/temp \
 && ln -sfn /tmp/Input /workspace/ComfyUI/input

# install ComfyUI requirements (excluding already pinned torch stack)
# Use a broader regex to exclude any torch specifier (==, ~=, >=, etc.)
RUN --mount=type=cache,target=/workspace/.cache/pip,id=pip-cache \
    grep -vE '^(torch(|vision|audio)|xformers)([[:space:]]*([<>=!~]=?).*)?$' \
        ComfyUI/requirements.txt > /tmp/req.txt && \
    # Tripwire: dry-run must not plan a torch uninstall
    python -m pip install --dry-run -r /tmp/req.txt -c ${WORKDIR}/constraints.txt \
      2>&1 | tee /tmp/pip_dry.log && \
    ! grep -q "Uninstalling torch" /tmp/pip_dry.log && \
    # Actual install (respect constraints)
    python -m pip install --upgrade-strategy only-if-needed \
      -r /tmp/req.txt -c ${WORKDIR}/constraints.txt && \
    python -m pip check

# Copy application entrypoint and dependency patches
COPY --chown=${UID}:${GID} entrypoint.sh ${WORKDIR}/entrypoint.sh
RUN sed -i 's/\r$//' ${WORKDIR}/entrypoint.sh && chmod +x ${WORKDIR}/entrypoint.sh
COPY --chown=${UID}:${GID} patch-requirements.txt ${WORKDIR}/ComfyUI/patch-requirements.txt
ENTRYPOINT ["/usr/bin/tini","--","/workspace/entrypoint.sh"]
EXPOSE 8188
