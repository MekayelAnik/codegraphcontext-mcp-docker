#!/bin/bash
set -euxo pipefail

# 1. Variables and Version Check
REPO_NAME='codegraphcontext-mcp'
HAPROXY_IMAGE=$(cat ./resources/build_data/haproxy-image 2>/dev/null || echo "haproxy:lts")
BASE_IMAGE=$(cat ./resources/build_data/base-image 2>/dev/null || echo "python:3.14-slim")
# mcp-proxy: stdio<->StreamableHTTP/SSE bridge. Replaces supergateway.
# Stateful by default (one stdio child shared across all sessions, multiplexed
# by JSON-RPC ids) — avoids the spawn-per-request memory leak that affected
# supergateway in stateless mode (supercorp-ai/supergateway#108).
MCP_PROXY_PKG=$(cat ./resources/build_data/mcp_proxy_version 2>/dev/null || echo "mcp-proxy")

# Create Dockerfile directly
if [ -e ./resources/build_data/publication ]; then
    # For publication builds
    echo "FROM ${BASE_IMAGE}" > "Dockerfile.$REPO_NAME"
    echo "# Publication tag" >> "Dockerfile.$REPO_NAME"
else
    if [ -f ./resources/build_data/cgc_version ]; then
        CGC_VERSION=$(cat ./resources/build_data/cgc_version)
        echo "Building Dockerfile for $CGC_VERSION"
    else
        echo "ERROR: build_data/cgc_version not found!" >&2
        exit 1
    fi
# 4. Generate the Dockerfile
cat > "Dockerfile.$REPO_NAME" << EOF
FROM $HAPROXY_IMAGE AS haproxy-src
FROM ${BASE_IMAGE}

# Author info
LABEL org.opencontainers.image.authors="MOHAMMAD MEKAYEL ANIK <mekayel.anik@gmail.com>"
LABEL org.opencontainers.image.description="CodeGraphContext MCP Server with mcp-proxy (stdio<->StreamableHTTP/SSE bridge)"

# Silence debconf and setup runtime tools
ENV DEBIAN_FRONTEND=noninteractive

# Copy scripts from your OLD script's logic
COPY ./resources/ /usr/local/bin/
RUN mkdir -p /etc/haproxy/ && mv -vf /usr/local/bin/haproxy.cfg.template /etc/haproxy/haproxy.cfg.template

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/banner.sh /usr/local/bin/pypi.sh \\
    && chmod +r /usr/local/bin/build-timestamp.txt \\
    && ln -sf /usr/sbin/gosu /usr/local/bin/su-exec

RUN apt-get update && apt-get install -y --no-install-recommends curl wget gosu iproute2 netcat-openbsd libatomic1 haproxy dos2unix openssl git util-linux \\
    && dos2unix /usr/local/bin/*.sh \\
    && apt-get purge dos2unix -y \\
    && ln -sf /usr/sbin/gosu /usr/local/bin/su-exec \\
    && rm -rf /var/lib/apt/lists/*

# HAProxy with native QUIC/H3 support from official image
COPY --from=haproxy-src /usr/local/sbin/haproxy /usr/sbin/haproxy
RUN mkdir -p /usr/local/sbin && ln -sf /usr/sbin/haproxy /usr/local/sbin/haproxy

# 1. Create user and directories
RUN groupadd -g 1000 node && \
    useradd -u 1000 -g node -s /bin/bash -m node && \
    mkdir -p /app /opt/venv && \
    chown -R node:node /app /opt/venv /home/node

# 2. Switch to the non-root user
USER node

# Setup Virtual Environment (mcp-proxy is pure Python — no Node/NVM needed)
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:\$PATH"

RUN --mount=type=cache,target=/home/node/.cache/pip,uid=1000,gid=1000 /usr/local/bin/pypi.sh

# Install mcp-proxy into the same venv (replaces supergateway as the stdio<->HTTP bridge)
RUN --mount=type=cache,target=/home/node/.cache/pip,uid=1000,gid=1000 \\
    /opt/venv/bin/pip install --no-cache-dir ${MCP_PROXY_PKG} && \\
    /opt/venv/bin/mcp-proxy --version || true

USER root

# User Configuration
RUN apt-get purge curl -y \\
    && apt-get autoremove -y \\
    && rm -rf /var/lib/apt/lists/* /usr/share/man/* /usr/share/doc/* /usr/local/bin/pypi.sh /usr/local/bin/build_data

# HAProxy with native QUIC/H3 support from official image
COPY --from=haproxy-src /usr/local/sbin/haproxy /usr/sbin/haproxy
RUN mkdir -p /usr/local/sbin && ln -sf /usr/sbin/haproxy /usr/local/sbin/haproxy

# Final Environment Setup
ENV PYTHONUNBUFFERED=1 \\
    PYTHONFAULTHANDLER=1 \\
    PYTHONDONTWRITEBYTECODE=1 \\
    PATH="/opt/venv/bin:\$PATH" \\
    VIRTUAL_ENV=/opt/venv \\
    PORT=8045 \\
    NEO4J_URI="bolt://localhost:7687" \\
    NEO4J_USERNAME="neo4j"

# L7 health check: auto-detects HTTP/HTTPS via ENABLE_HTTPS env var.
# /healthz is answered by HAProxy locally (mcp-proxy lacks a configurable
# health endpoint) so the check itself returns in well under a second.
# start-period=60s tolerates the cold-start period so orchestrators do not
# flap the container before the backend is ready.
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \\
    CMD sh -c 'wget -q --spider --no-check-certificate \$([ "\$ENABLE_HTTPS" = "true" ] && echo https || echo http)://127.0.0.1:\${PORT:-8045}/healthz'

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
EOF
fi

echo "Successfully generated Dockerfile.$REPO_NAME"