#!/usr/bin/env bash
set -e

# ---------- 0) link external dirs ----------
ln -snf /workspace/custom_nodes ComfyUI/custom_nodes 2>/dev/null || true
ln -snf /workspace/models       ComfyUI/models       2>/dev/null || true
ln -snf /workspace/output       ComfyUI/output       2>/dev/null || true
ln -snf /workspace/input        ComfyUI/input        2>/dev/null || true
ln -snf /workspace/temp         ComfyUI/temp         2>/dev/null || true

# ---------- 1) sync with github comfyUI code ----------
if [ -d ComfyUI/.git ]; then
  git -C ComfyUI pull --ff-only
else
  echo "[!] Stale ComfyUI dir – räume Code auf"
  mkdir -p ComfyUI
  find ComfyUI -mindepth 1 -maxdepth 1 \
       ! -name custom_nodes ! -name models ! -name output \
       ! -name input ! -name temp \
       -exec rm -rf {} +
  git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git ComfyUI_tmp
  cp -rT ComfyUI_tmp ComfyUI && rm -rf ComfyUI_tmp
fi

# ---------- 2) virtual environment ----------
# ensure Ownership (if volume might come root-owned)
if [ ! -w "$VENV_PATH" ]; then
  echo "[+] Fix ownership of venv mount"
  chown -R $(id -u):$(id -g) "$VENV_PATH"
fi

# create venv
if [ ! -x "$VENV_PATH/bin/pip" ]; then
  echo "[+] Creating  virtual Environment"
  python3 -m venv "$VENV_PATH"
fi

$VENV_PATH/bin/pip install --upgrade pip
$VENV_PATH/bin/pip install --no-cache-dir \
  --extra-index-url https://download.pytorch.org/whl/cu124 \
  torch==2.5.1+cu124 torchvision==0.20.1+cu124 \
  torchaudio==2.5.1+cu124 xformers==0.0.28.post3 sageattention

# requirements without torch and xformers, to ensure our specific versions
grep -vE 'torch|torchvision|torchaudio|xformers' \
     ComfyUI/requirements.txt >/tmp/req.txt
$VENV_PATH/bin/pip install -r /tmp/req.txt
$VENV_PATH/bin/pip install -r /patch-requirements.txt

$VENV_PATH/bin/pip check || true   # true doesn't break the start on problems in check

# ---------- 2a) CUDA-Check ----------
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

# ---------- 3) ComfyUI start ----------
cd ComfyUI
exec python3 main.py \
     --listen 0.0.0.0 \
     --use-sage-attention \
     --preview-method auto \
     --lowvram \
     "$@"

