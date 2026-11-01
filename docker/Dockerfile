ARG BASE=debian:bookworm-slim
FROM ${BASE} AS base

USER root
COPY docker/install-deps.sh /tmp/install-deps.sh
ARG IDM_UID=1000
ARG IDM_GID=1000
RUN bash /tmp/install-deps.sh \
    && rm -f /tmp/install-deps.sh \
    && groupadd --gid "${IDM_GID}" idmgr \
    && useradd --uid "${IDM_UID}" --gid "${IDM_GID}" --create-home --shell /bin/bash idmgr

ENV EDITOR=vim
ENV PATH="/opt/idmgr/bin:${PATH}"
USER idmgr

FROM base AS test
USER root
COPY mise.toml /tmp/mise.toml
RUN set -eu \
    && version=$(sed -n 's/^bats = "\(.*\)"/\1/p' /tmp/mise.toml) \
    && test -n "$version" \
    && curl -fsSL "https://github.com/bats-core/bats-core/archive/refs/tags/v${version}.tar.gz" -o /tmp/bats.tar.gz \
    && tar -xzf /tmp/bats.tar.gz -C /tmp \
    && "/tmp/bats-core-${version}/install.sh" /usr/local \
    && rm -rf /tmp/bats.tar.gz "/tmp/bats-core-${version}" /tmp/mise.toml
USER idmgr
WORKDIR /tmp/idmgr-home
