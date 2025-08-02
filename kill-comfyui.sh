#!/bin/bash
# kill-comfyui.sh
set -e
echo ">>> Killing all ComfyUI containers"
podman ps --filter name=comfyui_ -q | while read cid; do
    echo "Removing container $cid"
    podman rm -f --depend $cid || true
done

