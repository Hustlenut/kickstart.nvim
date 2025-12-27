# ---------- STAGE 1: fetch toolchains ----------
FROM debian:bookworm-slim AS bootstrap

ARG DEBIAN_FRONTEND=noninteractive

ARG NVIM_VERSION=0.11.5
ARG NODE_VERSION=24.11.0
ARG GO_VERSION=1.23.11
ARG RIPGREP_VERSION=15.1.0
ARG TREESITTER_CLI_VERSION=0.26.3

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
	ca-certificates curl xz-utils tar unzip git bash perl gcc make build-essential clang libclang-dev \
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

# --- Rust + Cargo + tree-sitter ---
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y \
	&& . /root/.cargo/env \
	&& rustup component add rust-analyzer rustfmt clippy \
	&& rustup default stable \
	&& cargo install tree-sitter-cli@${TREESITTER_CLI_VERSION} \
	&& tree-sitter --version || (echo "❌ tree-sitter install FAILED!" && exit 1) \
	&& find /root/.rustup /root/.cargo -name "*.crate" -delete 2>/dev/null || true \
	&& rm -rf /root/.rustup/toolchains/*/share/doc

# Verify ALL binaries exist
RUN ls -la /root/.cargo/bin/tree-sitter* && echo "✅ tree-sitter OK"
ENV PATH=/root/.cargo/bin:$PATH

# --- ripgrep (prebuilt) ---
RUN set -eux; \
	curl -fsSL -o /tmp/rg.deb \
	"https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep_${RIPGREP_VERSION}-1_amd64.deb"; \
	dpkg -x /tmp/rg.deb /tmp/rg; \
	install -Dm755 /tmp/rg/usr/bin/rg /opt/rg; \
	rm -rf /tmp/rg.deb /tmp/rg

# ---------- STAGE 2: runtime image (ROOT USER) ----------
FROM debian:bookworm-slim AS runtime

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
	ca-certificates curl git bash perl \
	xz-utils tar unzip wget \
	build-essential cmake pkg-config \
	wl-clipboard xclip \
	binutils libunwind8 libstdc++6 \
	&& update-ca-certificates \
	&& rm -rf /var/lib/apt/lists/* \
	&& ldconfig

# PS! Take from the python image
COPY --from=localhost/python-builder:0.0.2 /usr/bin/python* /usr/bin/
COPY --from=localhost/python-builder:0.0.2 /usr/lib/python3.9  /usr/lib/python3.9
COPY --from=localhost/python-builder:0.0.2 /usr/lib/python3.10 /usr/lib/python3.10
COPY --from=localhost/python-builder:0.0.2 /usr/lib/python3.11 /usr/lib/python3.11
COPY --from=localhost/python-builder:0.0.2 /usr/lib/python3.12 /usr/lib/python3.12
COPY --from=localhost/python-builder:0.0.2 /usr/lib/python3.13 /usr/lib/python3.13
COPY --from=localhost/python-builder:0.0.2 /usr/lib/python3.14 /usr/lib/python3.14


# Create symlinks for Python versions
RUN set -eux; \
	for ver in 3.9.25 3.10.19 3.11.14 3.12.12 3.13.9 3.14.0; do \
	major=$(echo $ver | cut -d. -f1-2); \
	ln -sf "/usr/bin/python${ver}" "/usr/local/bin/python${ver}"; \
	ln -sf "/usr/bin/python${ver}" "/usr/local/bin/python${major}"; \
	mkdir -p /usr/lib64; \
	ln -sf "/usr/lib/python${ver}" "/usr/lib64/python${ver}"; \
	ln -sf "/usr/lib/python${major}" "/usr/lib64/python${major}"; \
	done && ldconfig

# COPY from stage 1
COPY --from=bootstrap /opt/nvim /opt/nvim
COPY --from=bootstrap /opt/node /opt/node
COPY --from=bootstrap /opt/go /opt/go
COPY --from=bootstrap /opt/rg /usr/local/bin/rg

COPY --from=bootstrap /root/.cargo/bin/* /usr/local/bin

ENV PATH=/opt/nvim/bin:/opt/node/bin:/opt/go/bin:/usr/local/bin:$PATH

# Following is intended to be shared with host user
ENV GOPATH=/work/go
ENV XDG_CACHE_HOME=/work/.cache
ENV XDG_CONFIG_HOME=/work/.config
ENV XDG_DATA_HOME=/work/.local/share
ENV XDG_STATE_HOME=/work/.local/state
ENV GOCACHE=/work/.cache/go-build

RUN mkdir -p /work/go /work/.cache/go-build \
	/work/.config/nvim \
	/work/.local/share/nvim/{lazy,mason} \
	/work/.cache/nvim/undo \
	/work/.local/state/nvim/{swap,backup}

RUN git clone -b podman-with-lsp --single-branch https://github.com/Hustlenut/kickstart.nvim.git "/work/.config/nvim"

# create SONAME symlink and update ld cache (only if target exists)
RUN if [ -f /usr/lib/x86_64-linux-gnu/libbfd-2.40-system.so ] && [ ! -f /usr/lib/x86_64-linux-gnu/libbfd-2.38-system.so ]; then \
	ln -s /usr/lib/x86_64-linux-gnu/libbfd-2.40-system.so /usr/lib/x86_64-linux-gnu/libbfd-2.38-system.so && ldconfig; \
	fi

RUN chmod -R 777 /work \
	&& chmod -R 755 /opt/nvim /opt/node /opt/go

# Lazy sync
RUN nvim --headless \
	-c 'Lazy sync' \
	-c 'qa'

WORKDIR /work

ENTRYPOINT ["nvim"]
