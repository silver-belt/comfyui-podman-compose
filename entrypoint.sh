#!/usr/bin/env bash
set -e

# ---------- 1) sync with github comfyUI code ----------
if [ -n "${COMFYUI_REF:-}" ]; then
  echo "[+] Syncing ComfyUI to ref: $COMFYUI_REF"
  git -C ComfyUI fetch --depth=1 origin "$COMFYUI_REF"
  git -C ComfyUI reset --hard FETCH_HEAD
else
  git -C ComfyUI pull --ff-only
fi

# ---------- 1b) ensure ComfyUI-Manager is available ----------
COMFY_CUSTOM_NODES_DIR="ComfyUI/custom_nodes"
COMFY_MANAGER_DIR="$COMFY_CUSTOM_NODES_DIR/ComfyUI-Manager"
if [ ! -d "$COMFY_MANAGER_DIR" ]; then
  echo "[+] Installing ComfyUI-Manager into $COMFY_MANAGER_DIR"
  mkdir -p "$COMFY_CUSTOM_NODES_DIR"
  if git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager "$COMFY_MANAGER_DIR"; then
    echo "[+] ComfyUI-Manager clone completed"
  else
    echo "[!] Failed to clone ComfyUI-Manager" >&2
  fi
else
  echo "[+] ComfyUI-Manager already present in $COMFY_MANAGER_DIR"
fi

if [ -d "$COMFY_MANAGER_DIR" ]; then
  if compgen -G "$COMFY_MANAGER_DIR/requirements*.txt" > /dev/null; then
    for requirement_file in "$COMFY_MANAGER_DIR"/requirements*.txt; do
      echo "[+] Installing ComfyUI-Manager Python dependencies from ${requirement_file##*/}"
      "$VENV_PATH/bin/pip" install -r "$requirement_file"
    done
  fi
fi

CUSTOM_NODES_FLAG_FILE="$WORKDIR/.custom-nodes-bootstrapped"
if [ ! -f "$CUSTOM_NODES_FLAG_FILE" ]; then
  echo "[+] First container start detected – installing custom node requirements"
  if [ -d "$COMFY_CUSTOM_NODES_DIR" ]; then
    requirement_files=()
    while IFS= read -r -d '' requirement_file; do
      requirement_files+=("$requirement_file")
    done < <(find "$COMFY_CUSTOM_NODES_DIR" -mindepth 1 -maxdepth 3 -type f -name 'requirements*.txt' -print0)
    if [ ${#requirement_files[@]} -gt 0 ]; then
      for requirement_file in "${requirement_files[@]}"; do
        relative_path="${requirement_file#$COMFY_CUSTOM_NODES_DIR/}"
        echo "[+] Installing custom node Python dependencies from ${relative_path:-${requirement_file##*/}}"
        "$VENV_PATH/bin/pip" install -r "$requirement_file"
      done
    else
      echo "[+] No custom node requirement files found"
    fi
  else
    echo "[!] Custom nodes directory $COMFY_CUSTOM_NODES_DIR not found"
  fi
  touch "$CUSTOM_NODES_FLAG_FILE"
else
  echo "[+] Custom node requirements previously installed – skipping"
fi
  
# if there are patches these have to be installed
$VENV_PATH/bin/pip install -r $WORKDIR/ComfyUI/patch-requirements.txt

$VENV_PATH/bin/pip check || true   # true doesn't break the start on problems in check

# ---------- 2) CUDA-Check ----------
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
     "$@"

