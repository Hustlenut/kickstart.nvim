# ---------- STAGE 1: fetch toolchains & language servers ----------
FROM debian:bookworm-slim AS bootstrap

ARG DEBIAN_FRONTEND=noninteractive

# Version pins (update these in one place)
ARG NVIM_VERSION=0.11.5
ARG NODE_VERSION=24.11.0
ARG GO_VERSION=1.23.11
ARG RIPGREP_VERSION=15.1.0

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl xz-utils tar unzip git bash perl gcc make \
 && update-ca-certificates

WORKDIR /opt/bootstrap

# --- Neovim (official linux tarball) ---
RUN set -eux; \
  for f in nvim-linux64.tar.gz nvim-linux-x86_64.tar.gz; do \
    url="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/$f"; \
    if curl -fsSLI "$url" >/dev/null; then curl -fsSL -o /tmp/nvim.tgz "$url"; break; fi; \
  done; \
  mkdir -p /opt/nvim; \
  tar -xzf /tmp/nvim.tgz -C /opt/nvim --strip-components=1; \
  rm -f /tmp/nvim.tgz; \
  /opt/nvim/bin/nvim --version

# --- Node.js (official linux tarball) ---
RUN curl -fsSL -o node.tar.xz \
      https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz \
 && tar -xJf node.tar.xz \
 && mv node-v${NODE_VERSION}-linux-x64 /opt/node \
 && rm -f node.tar.xz
ENV PATH=/opt/node/bin:$PATH

# --- Go (official linux tarball) ---
RUN curl -fsSL -o go.tar.gz \
      https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz \
 && tar -C /opt -xzf go.tar.gz \
 && mv /opt/go /opt/go-${GO_VERSION} \
 && ln -s /opt/go-${GO_VERSION} /opt/go \
 && rm -f go.tar.gz
ENV PATH=/opt/go/bin:$PATH

# --- ripgrep (prebuilt) ---
RUN set -eux; \
  curl -fsSL -o /tmp/rg.deb \
    "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep_${RIPGREP_VERSION}-1_amd64.deb"; \
  dpkg -x /tmp/rg.deb /tmp/rg; \
  install -Dm755 /tmp/rg/usr/bin/rg /opt/rg; \
  rm -rf /tmp/rg.deb /tmp/rg

# ---------- STAGE 2: minimal runtime image ----------
FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=dev
ARG UID=1000
ARG GID=1000

# Only the bare runtime libs; no compilers.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git bash perl python3 python3-pip \
      xz-utils tar unzip wget\
      build-essential cmake pkg-config \
      wl-clipboard xclip \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Copy in the pinned toolchains and LSP binaries from the bootstrap stage.
COPY --from=bootstrap /opt/nvim /opt/nvim
COPY --from=bootstrap /opt/node /opt/node
COPY --from=bootstrap /opt/go /opt/go
COPY --from=bootstrap /opt/rg /usr/local/bin/rg

# Paths
ENV PATH=/opt/nvim/bin:/opt/node/bin:/opt/go/bin:/usr/local/bin:$PATH
ENV GOPATH=/home/${USERNAME}/go

# User
RUN groupadd -g ${GID} ${USERNAME} \
 && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME}

ENV XDG_CACHE_HOME=/home/${USERNAME}/.cache
ENV GOCACHE=/home/${USERNAME}/.cache/go-build
RUN mkdir -p /home/${USERNAME}/.cache/go-build && chown -R ${UID}:${GID} /home/${USERNAME}/.cache

USER ${USERNAME}
ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}
WORKDIR /work
VOLUME ["/work"]

# Default entrypoint
ENTRYPOINT ["nvim"]
