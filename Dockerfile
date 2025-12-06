# ---------- STAGE 1: fetch toolchains ----------
FROM debian:bookworm-slim AS bootstrap

ARG DEBIAN_FRONTEND=noninteractive

ARG NVIM_VERSION=0.11.5
ARG NODE_VERSION=24.11.0
ARG GO_VERSION=1.23.11
ARG RIPGREP_VERSION=15.1.0

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl xz-utils tar unzip git bash perl gcc make build-essential \
 && update-ca-certificates

WORKDIR /opt/bootstrap

# --- Neovim ---
RUN set -eux; \
  for f in nvim-linux64.tar.gz nvim-linux-x86_64.tar.gz; do \
    url="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/$f"; \
    if curl -fsSLI "$url" >/dev/null; then curl -fsSL -o /tmp/nvim.tgz "$url"; break; fi; \
  done; \
  mkdir -p /opt/nvim; \
  tar -xzf /tmp/nvim.tgz -C /opt/nvim --strip-components=1; \
  rm -f /tmp/nvim.tgz; \
  /opt/nvim/bin/nvim --version

# --- Node.js ---
RUN curl -fsSL -o node.tar.xz \
      https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz \
 && tar -xJf node.tar.xz \
 && mv node-v${NODE_VERSION}-linux-x64 /opt/node \
 && rm -f node.tar.xz
ENV PATH=/opt/node/bin:$PATH

# --- Go ---
RUN curl -fsSL -o go.tar.gz \
      https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz \
 && tar -C /opt -xzf go.tar.gz \
 && mv /opt/go /opt/go-${GO_VERSION} \
 && ln -s /opt/go-${GO_VERSION} /opt/go \
 && rm -f go.tar.gz
ENV PATH=/opt/go/bin:$PATH

# --- Rust + Cargo ---
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH=/root/.cargo/bin:$PATH

# --- ripgrep (prebuilt) ---
RUN set -eux; \
  curl -fsSL -o /tmp/rg.deb \
    "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep_${RIPGREP_VERSION}-1_amd64.deb"; \
  dpkg -x /tmp/rg.deb /tmp/rg; \
  install -Dm755 /tmp/rg/usr/bin/rg /opt/rg; \
  rm -rf /tmp/rg.deb /tmp/rg

# ---------- STAGE 2: runtime image (ROOT USER) ----------
FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git bash perl python3 python3-pip \
      xz-utils tar unzip wget \
      build-essential cmake pkg-config \
      wl-clipboard xclip \
      libunwind8 \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY --from=bootstrap /opt/nvim /opt/nvim
COPY --from=bootstrap /opt/node /opt/node
COPY --from=bootstrap /opt/go /opt/go
COPY --from=bootstrap /opt/rg /usr/local/bin/rg

COPY --from=bootstrap /root/.cargo /root/.cargo
ENV PATH=/root/.cargo/bin:/opt/nvim/bin:/opt/node/bin:/opt/go/bin:/usr/local/bin:$PATH

# Following is intended to be shared with host user
ENV GOPATH=/work/go
ENV XDG_CACHE_HOME=/work/.cache
ENV XDG_CONFIG_HOME=/work/.config
ENV XDG_DATA_HOME=/work/.local/share
ENV XDG_STATE_HOME=/work/.local/state
ENV GOCACHE=/work/.cache/go-build

RUN mkdir -p /work/go /work/.cache/go-build \
    /work/.config/nvim /work/.local/share/nvim /work/.local/state/nvim

# TODO: Change to your branch or your own fork
RUN git clone -b <CHANGE ME> --single-branch https://github.com/Hustlenut/kickstart.nvim.git "/work/.config/nvim"

RUN nvim --headless \
    -c 'MasonToolsInstallSync' \
    -c 'qa'

RUN chmod -R 777 /work \
 && chmod -R 755 /opt/nvim /opt/node /opt/go /root/.cargo

WORKDIR /work

ENTRYPOINT ["nvim"]
