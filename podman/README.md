# Project README

## Table of Contents
- [Introduction](#introduction)
- [Why Debian Instead of Alpine](#why-debian-instead-of-alpine)
- [X11 (i3/Xorg Session)](#x11-i3xorg-session)
  - [One-Time Host Setup](#one-time-host-setup)
- [Usage](#usage)

---

## Introduction

This project runs Python applications in a containerized environment optimized for compatibility and GUI support. This README covers the rationale behind the base image choice and the necessary host setup to enable X11 graphical forwarding.

## Why Debian Instead of Alpine

Most prebuilt Python wheels on PyPI are compiled against **glibc**,  
the GNU C standard library used by Debian, Ubuntu, Red Hat, and similar distros.

Alpine Linux uses **musl libc** instead of glibc, causing many Python wheels to fail or require complex recompilation.

Choosing Debian as a base image ensures better compatibility and reduces build complexity for Python packages with native dependencies.

## X11 (i3/Xorg Session)

To allow GUI applications inside the container to display on the host’s X11 server, the container must access the X11 Unix socket with proper permissions.

### One-Time Host Setup

Run the following on your host machine to allow your user permission to access the X11 sockets:
```
xhost +si:localuser:$(id -un)
```

This grants access to local socket connections for your current user.


## Installation and usage
Install it on your machine:
```
git clone https://github.com/Hustlenut/kickstart.nvim.git $HOME/.config/nvim-podman
```
Add the nvim-podman script to you .bashrc:
```
nvim() {
    local script="$HOME/.config/nvim-podman/podman/nvim-podman"
    "$script" "$@"
}
```
Then run it on a file:
```
nvim <file>
```
