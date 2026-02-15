#!/bin/bash
set -e

if [ -f /usr/local/bin/build_data/nvm_version ]; then
    NVM_VERSION=$(cat /usr/local/bin/build_data/nvm_version)
else
    echo "ERROR: /usr/local/bin/build_data/nvm_version not found!" >&2
    exit 1
fi

# Download and install nvm:
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_VERSION/install.sh" | bash

# Source nvm BEFORE using it
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Now nvm command is available
nvm version

# Download and install Node.js:
nvm install node
nvm alias default node

# Verify the Node.js version:
node -v
# Verify npm version:
npm -v

npm install -g npm@latest supergateway@latest && npm cache clean --force