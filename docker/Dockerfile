# Neovim + common CLIs for kickstart.nvim (Debian, glibc)
FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=dev
ARG UID=1000
ARG GID=1000

# Base tools (ripgrep for Telescope, Python/Node for LSPs/formatters)
# Install Neovim from backports for a newer version.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl wget git ripgrep unzip bash \
      python3 python3-venv python3-pip \
      nodejs npm build-essential \
 && echo "deb http://deb.debian.org/debian bookworm-backports main" \
      > /etc/apt/sources.list.d/backports.list \
 && apt-get update \
 && apt-get -t bookworm-backports install -y --no-install-recommends neovim \
 && rm -rf /var/lib/apt/lists/*

# Create non-root user (match at runtime with -u/--userns=keep-id)
RUN groupadd -g ${GID} ${USERNAME} \
 && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME}

USER ${USERNAME}
ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}
WORKDIR /work

# Optional volumes (you will bind-mount from the launcher scripts anyway)
VOLUME ["/work"]

# Default entrypoint: run nvim; launcher passes args and mounts
ENTRYPOINT ["nvim"]
