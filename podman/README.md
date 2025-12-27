# Kickstart.nvim Containerized

## Table of Contents
- [Introduction](#introduction)
- [Why Debian Instead of Alpine](#why-debian-instead-of-alpine)
- [X11 (i3/Xorg Session)](#x11-i3xorg-session)
  - [One-Time Host Setup](#one-time-host-setup)
- [Run with Python](#run-with-python)
-    [Usage](#usage)
- [Installation and usage](#Installation-and-usage)
- [Caveats](#Caveats)

---

## Introduction
This project wraps Kickstarter.nvim in a Podman container and aims to have NVIM work offline as well.
Following things has deviated from the original init.lua:

- Disabled auto formatting on save, you have to press 'space + f' to format code.
- (Python related) Added a custom remote logic for Pylsp to communicate over TCP in a venv.

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

## Run with Python
_Python LSP (pylsp) needs to analyze your exact project's Python interpreter and packages to provide accurate completions,
diagnostics, and refactoring. A global/system pylsp can't accurately see your project's dependencies._

To bypass this, this is intended to work with pylsp that is set in a 'venv'.
Giving the developer the flexibility of changing versions and interpreters as well.
### Usage:
```
# In another shell in your project, create a virtual environment:
python<version> -m venv .venv

# Activate venv:
source .venv/bin/activate

# Install pylsp:
pip install "python-lsp-server[all]"

# Run LSP
./.venv/bin/pylsp --tcp --host 127.0.0.1 --port 2087
```
⚠️ For PYLSP to work, you need to open NVIM where the '.venv' directory is located.

## Installation and usage
Fork the repository or make a branch in this project.
Then clone it to the respective path:
```
git clone https://github.com/Hustlenut/kickstart.nvim.git $HOME/.config/nvim-podman
```
Open init.lua and declare your needs (LSPs, treesitter settings... etc).
⚠️ Then open the ```$HOME/.config/nvim-podman/Dockerfile``` and navigate to the 'TODO' comment.
    Specify your branch or repository that has your changes to the init.lua file.

Symlink to /usr/bin/ or add the nvim-podman script to your .bashrc:
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
### Build the Dockerfile manually
Build the Python image for reusage:
```
podman build -f Dockerfile.python -t python-builder
```
Then build the nvim image:
```
podman build -f Dockerfile -t nvim-podman
```
(Optional) When the container is built, run this command to setup nvim-treesitter for offline build.
```
:TSInstall bash c cpp diff html lua luadoc markdown markdown_inline query vim vimdoc python go perl typescript yaml json toml dockerfile fish css
```

## Caveats
- Do not close NVIM or its container when you copy/paste. (Clipboard actions requires a running container)
