## Introduction
This repo is built on top of kickstart.nvim, and aims to slap it into a Docker container.

## Prerequisites
- Docker

## Supported on
- Hyprland and Arch Linux

### Reasoning behind using Debian image instead of Alpine
Most prebuilt Python wheels on PyPI are compiled against glibc,
the GNU C standard library used by Debian/Ubuntu/Red Hat, etc.
Alpine Linux uses musl instead of glibc, so glibc-targeted wheels won’t load on Alpine

### Clipboard setup with X11 (i3/Xorg session)

You need the X11 Unix socket and permission:
```
# One-time on the host (allow your user from local sockets):
xhost +si:localuser:$(id -un)

docker run --rm -it \
  --network=host \
  -e PYLSP_HOST=127.0.0.1 -e PYLSP_PORT=2087 \
  -e DISPLAY="$DISPLAY" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "${XAUTHORITY:-$HOME/.Xauthority}:/home/$(id -un)/.Xauthority:ro" \
  <your-image> nvim
```
