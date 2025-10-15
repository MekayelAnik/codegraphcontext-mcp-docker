#!/bin/bash
set -ex
# Set variables first
REPO_NAME='codegraphcontext-mcp'
BASE_IMAGE=$(cat ./build_data/base-image 2>/dev/null || echo "node:alpine")
CGC_VERSION=$(cat ./build_data/version 2>/dev/null || exit 1)
CGC_PKG="codegraphcontext==${CGC_VERSION}"
SUPERGATEWAY_PKG='supergateway@latest'
DOCKERFILE_NAME="Dockerfile.$REPO_NAME"

# Create a temporary file safely
TEMP_FILE=$(mktemp "${DOCKERFILE_NAME}.XXXXXX") || {
    echo "Error creating temporary file" >&2
    exit 1
}

# Check if this is a publication build
if [ -e ./build_data/publication ]; then
    # For publication builds, create a minimal Dockerfile that just tags the existing image
    {
        echo "ARG BASE_IMAGE=$BASE_IMAGE"
        echo "ARG CGC_VERSION=$CGC_VERSION"
        echo "FROM $BASE_IMAGE"
    } > "$TEMP_FILE"
else
    # Write the Dockerfile content to the temporary file
    cat > "$TEMP_FILE" << EOF
ARG BASE_IMAGE=$BASE_IMAGE
ARG CGC_VERSION=$CGC_VERSION
FROM \$BASE_IMAGE AS build

# Author info:
LABEL org.opencontainers.image.authors="MOHAMMAD MEKAYEL ANIK <mekayel.anik@gmail.com>"
LABEL org.opencontainers.image.description="CodeGraphContext MCP Server with Supergateway"
LABEL org.opencontainers.image.project="https://github.com/Shashankss1205/CodeGraphContext"
LABEL org.opencontainers.image.source="https://github.com/MekayelAnik/codegraphcontext-mcp-docker"

# Copy the entrypoint script into the container and make it executable
COPY ./resources/ /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/banner.sh \\
    && chmod +r /usr/local/bin/build-timestamp.txt

# Install system dependencies for Python and CodeGraphContext
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/main" > /etc/apk/repositories && \\
    echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \\
    apk --update-cache --no-cache add \\
        py3-pip \\
        py3-wheel \\
        python3 \\
        bash \\
        shadow \\
        su-exec \\
        tzdata \\
        py3-setuptools && \\
    rm -rf /var/cache/apk/*

# Create a virtual environment for Python packages
RUN python3 -m venv /opt/venv

# Set PATH to include virtual environment (must be before verification)
ENV PATH="/opt/venv/bin:\$PATH"

# Upgrade pip, setuptools, and wheel in virtual environment
# Upgrade pip and install Python packages using a multi-stage approach for cleanliness.
# Build dependencies are installed and removed in the same layer to keep the image small.
RUN apk add --no-cache --virtual .build-deps \\
        gcc \\
        g++ \\
        make \\
        musl-dev \\
        python3-dev \\
        libffi-dev \\
        openssl-dev \\
        cargo \\
        rust && \\
    pip install --no-cache-dir --upgrade pip setuptools wheel && \\
    echo "Installing CodeGraphContext version: $CGC_PKG" && \\
    pip install --no-cache-dir \\
        "$CGC_PKG" \\
        neo4j>=5.15.0 \\
        watchdog>=3.0.0 \\
        requests>=2.31.0 \\
        stdlibs>=2023.11.18 \\
        typer>=0.9.0 \\
        rich>=13.7.0 \\
        inquirerpy>=0.3.4 \\
        python-dotenv>=1.0.0 \\
        tree-sitter==0.20.4 \\
        tree-sitter-languages==1.10.2 && \\
    cgc --help || { echo "ERROR: cgc command not found after installation!" >&2; exit 1; } && \\
    apk del .build-deps && \\
    rm -rf /tmp/* /root/.cache

# Install Node.js packages (Supergateway)
RUN npm install -g $SUPERGATEWAY_PKG --loglevel verbose && \\
    npm cache clean --force

# Use an ARG for the default port
ARG PORT=8045

# Neo4j connection arguments
ARG NEO4J_URI="bolt://localhost:7687"
ARG NEO4J_USERNAME="neo4j"
ARG NEO4J_PASSWORD=""

# Optional API key for gateway authentication
ARG API_KEY=""

# Set ENV variables from ARGs for runtime
ENV PORT=\${PORT}
ENV NEO4J_URI=\${NEO4J_URI}
ENV NEO4J_USERNAME=\${NEO4J_USERNAME}
ENV NEO4J_PASSWORD=\${NEO4J_PASSWORD}
ENV API_KEY=\${API_KEY}
ENV PATH="/opt/venv/bin:\$PATH"

# Health check using nc (netcat) to check if the port is open
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \\
    CMD nc -z localhost \${PORT:-8045} || exit 1

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

EOF
fi

# Atomically replace the target file with the temporary file
if mv -f "$TEMP_FILE" "$DOCKERFILE_NAME"; then
    echo "Dockerfile for $REPO_NAME created successfully."
else
    echo "Error: Failed to create Dockerfile for $REPO_NAME" >&2
    rm -f "$TEMP_FILE"
    exit 1
fi