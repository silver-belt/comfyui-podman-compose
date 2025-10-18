#!/usr/bin/env bash
set -e

# ---------- 0) prepare temp dirs & link external dirs ----------
mkdir -p ComfyUI

ensure_temp_mount() {
  local dir="$1"
  mkdir -p "$dir" || return 1

  # Try to make the directory world-writable (sticky when possible) so multiple
  # users/processes can share it safely. On Windows-backed volumes chmod/chown
  # may be limited, therefore ignore errors.
  chmod 1777 "$dir" 2>/dev/null || chmod 0777 "$dir" 2>/dev/null || true
  chown $(id -u):$(id -g) "$dir" 2>/dev/null || true

  local probe="$dir/.write-test-$$"
  if ! (touch "$probe" 2>/dev/null && rm -f "$probe" 2>/dev/null); then
    return 1
  fi
}

TEMP_TARGET="/tmp"
if ! ensure_temp_mount "$TEMP_TARGET"; then
  echo "[!] /tmp is not writable in this environment – falling back to /workspace/temp" >&2
  TEMP_TARGET="/workspace/temp"
  if ! ensure_temp_mount "$TEMP_TARGET"; then
    echo "[!] Could not prepare a writable temp directory. Check your mounted volumes." >&2
    exit 1
  fi
fi

export TMPDIR="$TEMP_TARGET"
export TEMP="$TEMP_TARGET"
export TMP="$TEMP_TARGET"

ln -snf /workspace/custom_nodes ComfyUI/custom_nodes 2>/dev/null || true
ln -snf /workspace/models       ComfyUI/models       2>/dev/null || true
ln -snf /workspace/output       ComfyUI/output       2>/dev/null || true
ln -snf /workspace/input        ComfyUI/input        2>/dev/null || true
ln -snf "$TEMP_TARGET"         ComfyUI/temp         2>/dev/null || true

# ---------- 1) sync with github comfyUI code ----------
if [ -d ComfyUI/.git ]; then
  if [ -n "${COMFYUI_REF:-}" ]; then
    echo "[+] Syncing ComfyUI to ref: $COMFYUI_REF"
    git -C ComfyUI fetch --depth=1 origin "$COMFYUI_REF"
    git -C ComfyUI reset --hard FETCH_HEAD
  else
    git -C ComfyUI pull --ff-only
  fi
else
  echo "[!] Stale ComfyUI dir – räume Code auf"
  mkdir -p ComfyUI
  find ComfyUI -mindepth 1 -maxdepth 1 \
       ! -name custom_nodes ! -name models ! -name output \
       ! -name input ! -name temp \
       -exec rm -rf {} +
  if [ -n "${COMFYUI_REF:-}" ]; then
    git clone --depth 1 --branch "$COMFYUI_REF" \
      https://github.com/comfyanonymous/ComfyUI.git ComfyUI_tmp
  else
    git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git ComfyUI_tmp
  fi
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

