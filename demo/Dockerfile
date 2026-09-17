FROM python:3.13.7-bookworm@sha256:c900d35aba5fe4c1dc1cd358408baae2902ff2a2926a1d15cc5002c6061ddb2e

ARG TARGETARCH
ARG NODE_VERSION=24.8.0
ARG GO_VERSION=1.25.1
ARG CMAKE_VERSION=4.1.1
ARG UV_VERSION=0.8.17
ARG GIT_A2A_VERSION=2.0.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential ca-certificates curl git jq xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) node_arch=x64; node_sha=2598641d188b41793930917f1a99a81c9615856b4205d408a44ab676c1acbb3d;; \
      arm64) node_arch=arm64; node_sha=323e6bc34bfe82a21f42d9eb94d9a2b6c8082d8c03cb510cf2f95dd1dcaa1531;; \
      *) echo "unsupported architecture: $TARGETARCH" >&2; exit 1;; \
    esac; \
    archive="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz"; \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${archive}"; \
    echo "${node_sha}  ${archive}" | sha256sum -c -; \
    mkdir -p /opt/node; \
    tar -xJf "$archive" -C /opt/node --strip-components=1; \
    rm "$archive"

RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) go_arch=amd64; go_sha=7716a0d940a0f6ae8e1f3b3f4f36299dc53e31b16840dbd171254312c41ca12e;; \
      arm64) go_arch=arm64; go_sha=65a3e34fb2126f55b34e1edfc709121660e1be2dee6bdf405fc399a63a95a87d;; \
    esac; \
    archive="go${GO_VERSION}.linux-${go_arch}.tar.gz"; \
    curl -fsSLO "https://go.dev/dl/${archive}"; \
    echo "${go_sha}  ${archive}" | sha256sum -c -; \
    tar -xzf "$archive" -C /usr/local; \
    rm "$archive"

RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) cmake_arch=x86_64; cmake_sha=5a6c61cb62b38e153148a2c8d4af7b3d387f0c8c32b6dbceb5eb4af113efd65a;; \
      arm64) cmake_arch=aarch64; cmake_sha=a34bc76b1ebe76ca0bbd6067f68d4614b93221912770dc08f466aec1923e9bef;; \
    esac; \
    archive="cmake-${CMAKE_VERSION}-linux-${cmake_arch}.tar.gz"; \
    curl -fsSLO "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/${archive}"; \
    echo "${cmake_sha}  ${archive}" | sha256sum -c -; \
    mkdir -p /opt/cmake; \
    tar -xzf "$archive" -C /opt/cmake --strip-components=1; \
    rm "$archive"

RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) uv_arch=x86_64; uv_sha=920cbcaad514cc185634f6f0dcd71df5e8f4ee4456d440a22e0f8c0f142a8203;; \
      arm64) uv_arch=aarch64; uv_sha=9a20d65b110770bbaa2ee89ed76eb963d8c6a480b9ebef584ea9df2ae85b4f0f;; \
    esac; \
    archive="uv-${uv_arch}-unknown-linux-gnu.tar.gz"; \
    curl -fsSLO "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${archive}"; \
    echo "${uv_sha}  ${archive}" | sha256sum -c -; \
    tar -xzf "$archive" -C /usr/local/bin --strip-components=1 \
      "uv-${uv_arch}-unknown-linux-gnu/uv" \
      "uv-${uv_arch}-unknown-linux-gnu/uvx"; \
    rm "$archive"

# Use the published release archive, not a locally built git-a2a binary.  The
# checksum is taken from the immutable v2.0.0 checksums.txt release asset.
RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) a2a_arch=amd64; a2a_sha=396de4803687a13486eabefa5acde4af557274e705355d9b470c7e2a997dccfd;; \
      arm64) a2a_arch=arm64; a2a_sha=5ff7a58f2cbb0986f813fd50200432cf0a86ffcd40f75e20a4d62a38c22fb4e7;; \
    esac; \
    archive="git-a2a_${GIT_A2A_VERSION}_linux_${a2a_arch}.tar.gz"; \
    curl -fsSLO "https://github.com/neprel/git-a2a/releases/download/v${GIT_A2A_VERSION}/${archive}"; \
    echo "${a2a_sha}  ${archive}" | sha256sum -c -; \
    tar -xzf "$archive" -C /usr/local/bin git-a2a; \
    rm "$archive"; \
    git-a2a --version | grep -Eq "^git-a2a ${GIT_A2A_VERSION} \(752eda1db35315592154e7928e61a8f18454d733, linux/(amd64|arm64), channel=binary\)$"

ENV PATH="/opt/node/bin:/opt/cmake/bin:/usr/local/go/bin:${PATH}" \
    UV_CACHE_DIR=/cache/uv \
    GOMODCACHE=/cache/go/pkg/mod \
    GOPATH=/cache/go \
    NPM_CONFIG_CACHE=/cache/npm \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN uv pip install --system \
      "a2a-sdk[http-server]==1.1.2" \
      "httpx==0.28.1" \
      "uvicorn==0.35.0" \
    && node --version \
    && python --version \
    && go version \
    && cmake --version \
    && uv --version

RUN useradd --create-home --uid 1000 demo \
    && mkdir -p /workspace /cache \
    && chown -R demo:demo /workspace /cache

USER demo
WORKDIR /workspace
