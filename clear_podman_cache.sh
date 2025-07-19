#!/bin/bash
podman container prune -f
podman image prune -a -f
podman volume prune -f
podman network prune -f
podman system prune -f
podman rmi --all
