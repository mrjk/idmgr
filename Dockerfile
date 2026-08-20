FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        bats \
        bsdmainutils \
        ca-certificates \
        coreutils \
        findutils \
        gettext-base \
        git \
        gnupg2 \
        nano \
        vim \
        openssh-client \
        pass \
        procps \
        tar \
    && rm -rf /var/lib/apt/lists/* \
    && command -v gpg2 >/dev/null || ln -s "$(command -v gpg)" /usr/local/bin/gpg2

ENV EDITOR=vim
ENV PATH="/opt/idmgr/bin:${PATH}"

WORKDIR /root/

