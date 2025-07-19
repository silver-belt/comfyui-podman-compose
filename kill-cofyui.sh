#!/bin/bash
# kill_comfy.sh
set -e
echo ">>> Killing all ComfyUI containers"
podman ps --filter name=comfyui_ -q | xargs -r podman rm -f

