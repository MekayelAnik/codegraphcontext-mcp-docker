#!/bin/bash
set -e

DEPENDENCIES=(
    "neo4j>=5.15.0"
    "watchdog>=3.0.0"
    "stdlibs>=2023.11.18"
    "typer[all]>=0.9.0"
    "rich>=13.7.0"
    "inquirerpy>=0.3.4"
    "python-dotenv>=1.0.0"
    "pyyaml"
    "pytest"
    "nbformat"
    "nbconvert>=7.16.6"
    "pathspec>=0.12.1"
    "tree-sitter>=0.25.2"
    "tree-sitter-language-pack>=0.13.0"
)
ARCH=$(uname -m)
echo "Detected build architecture: $ARCH"
if [[ "$ARCH" == "x86_64" ]]; then
    echo "Adding falkordblite for x86_64..." &&
    DEPENDENCIES+=("falkordblite")
else
    echo "Skipping falkordblite for ARM64..."
fi

# Upgrade pip and install dependency array
/opt/venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel
/opt/venv/bin/pip install --no-cache-dir ${DEPENDENCIES[*]}
# Install specific cgc_version of the app

if [ -f /usr/local/bin/build_data/cgc_version ]; then
    CGC_VERSION=$(cat /usr/local/bin/build_data/cgc_version)
else
    echo "ERROR: /usr/local/bin/build_data/cgc_version not found!" >&2
    exit 1
fi

/opt/venv/bin/pip install --no-cache-dir --no-deps "codegraphcontext==${CGC_VERSION}"

find /opt/venv -type d -name "__pycache__" -exec rm -rf {} +
find /opt/venv -name "*.pyc" -delete


/opt/venv/bin/python -c "import codegraphcontext; print('✅ CodeGraphContext imported successfully')"
cgc --help || echo "Note: cgc help command might not show full output"