#!/usr/bin/env bash
set -e

# ---------- 1) link external dirs ----------
mkdir -p ComfyUI
ln -snf /workspace/custom_nodes ComfyUI/custom_nodes 2>/dev/null || true
ln -snf /workspace/models       ComfyUI/models       2>/dev/null || true
ln -snf /workspace/output       ComfyUI/output       2>/dev/null || true
ln -snf /workspace/input        ComfyUI/input        2>/dev/null || true
ln -snf /workspace/temp         ComfyUI/temp         2>/dev/null || true

# ---------- 2) sync with github comfyUI code ----------
if [ -n "${COMFYUI_REF:-}" ]; then
  echo "[+] Syncing ComfyUI to ref: $COMFYUI_REF"
  git -C ComfyUI fetch --depth=1 origin "$COMFYUI_REF"
  git -C ComfyUI reset --hard FETCH_HEAD
else
  git -C ComfyUI pull --ff-only
fi
  
# if there are patches these have to be installed
$VENV_PATH/bin/pip install -r /patch-requirements.txt

$VENV_PATH/bin/pip check || true   # true doesn't break the start on problems in check

# ---------- 3) CUDA-Check ----------
$VENV_PATH/bin/python - <<'PY'
import torch, platform, textwrap, os, subprocess, shutil
print(textwrap.dedent(f"""
=== ComfyUI Torch-Check ===
Torch   : {torch.__version__}
Python  : {platform.python_version()}
CUDA ok : {torch.cuda.is_available()}
""").strip())
if torch.cuda.is_available():
    print("Device :", torch.cuda.get_device_name(0),
          "| Compute :", *torch.cuda.get_device_capability(0))
if shutil.which("nvidia-smi"):
    print("=== Host driver & runtime ===")
    subprocess.run(["nvidia-smi"])
print("="*30, flush=True)
PY

# ---------- 4) ComfyUI start ----------
cd ComfyUI
exec python3 main.py \
     --listen 0.0.0.0 \
     --use-sage-attention \
     --preview-method auto \
     "$@"

