#!/bin/bash
# Runtime packages for the idmgr test image. Bats is installed by the test stage.
set -euo pipefail

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends \
    bash \
    bsdextrautils \
    ca-certificates \
    coreutils \
    curl \
    findutils \
    gettext-base \
    git \
    gnupg \
    openssh-client \
    pass \
    procps \
    tar \
    vim-tiny
  rm -rf /var/lib/apt/lists/*
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y epel-release
  # Stream images already ship coreutils-single and curl-minimal. The full
  # packages conflict with those, and the minimal builds provide the tools.
  dnf install -y \
    bash \
    ca-certificates \
    findutils \
    gettext \
    git \
    gnupg2 \
    openssh-clients \
    pass \
    procps-ng \
    tar \
    util-linux \
    vim-minimal
  dnf clean all
elif command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm \
    bash \
    ca-certificates \
    coreutils \
    curl \
    findutils \
    gettext \
    git \
    gnupg \
    openssh \
    pass \
    procps-ng \
    tar \
    util-linux \
    vim
else
  echo "unsupported package manager" >&2
  exit 1
fi

if ! command -v gpg2 >/dev/null 2>&1; then
  ln -sf "$(command -v gpg)" /usr/local/bin/gpg2
fi

if ! command -v vim >/dev/null 2>&1; then
  if command -v vim.tiny >/dev/null 2>&1; then
    ln -sf "$(command -v vim.tiny)" /usr/local/bin/vim
  elif command -v vi >/dev/null 2>&1; then
    ln -sf "$(command -v vi)" /usr/local/bin/vim
  fi
fi
