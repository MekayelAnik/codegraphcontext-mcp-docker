#!/usr/bin/env bash
set -euo pipefail

REQUESTED_ACTION="${REQUESTED_ACTION:-auto-check}"
MANUAL_VERSIONS_RAW="${MANUAL_VERSIONS_RAW:-}"
PYPI_PACKAGE="${PYPI_PACKAGE:-codegraphcontext}"
PYPI_REGISTRY="${PYPI_REGISTRY:-https://pypi.org}"
MAX_VERSIONS="${MAX_VERSIONS:-10}"

if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
    echo "GITHUB_OUTPUT is required" >&2
    exit 1
fi

DATE_TAG="$(date +%d%m%Y)"
echo "date_tag=$DATE_TAG" >> "$GITHUB_OUTPUT"

# Handle manual version input
if [[ -n "$MANUAL_VERSIONS_RAW" && "$REQUESTED_ACTION" == "build" ]]; then
    IFS=',' read -ra MANUAL_ARRAY <<< "$MANUAL_VERSIONS_RAW"
    VERSIONS_OLDEST=""
    for v in "${MANUAL_ARRAY[@]}"; do
        clean="$(echo "$v" | xargs)"
        [[ -n "$clean" ]] && VERSIONS_OLDEST="${VERSIONS_OLDEST:+$VERSIONS_OLDEST
}$clean"
    done

    if [[ -z "$VERSIONS_OLDEST" ]]; then
        echo "versions_json=[]" >> "$GITHUB_OUTPUT"
        echo "latest_version=" >> "$GITHUB_OUTPUT"
        echo "should_build=false" >> "$GITHUB_OUTPUT"
        exit 0
    fi

    VERSIONS_NEWEST="$(echo "$VERSIONS_OLDEST" | sort -Vr)"
    LATEST_VERSION="$(echo "$VERSIONS_NEWEST" | head -n1)"
else
    # Fetch from PyPI JSON API
    PYPI_URL="${PYPI_REGISTRY}/pypi/${PYPI_PACKAGE}/json"
    curl -fsSL "$PYPI_URL" -o pypi-package.json

    # Extract versions, filter out pre-releases (alpha, beta, rc, dev)
    VERSIONS_NEWEST="$({
        jq -r '.releases | keys[]' pypi-package.json \
            | grep -Evi '(a|b|rc|dev|alpha|beta|pre|post)' \
            | sort -Vr \
            | head -n "$MAX_VERSIONS"
    } || true)"

    if [[ -z "$VERSIONS_NEWEST" ]]; then
        echo "versions_json=[]" >> "$GITHUB_OUTPUT"
        echo "latest_version=" >> "$GITHUB_OUTPUT"
        echo "should_build=false" >> "$GITHUB_OUTPUT"
        exit 0
    fi

    # PyPI latest is in info.version
    DIST_TAG_LATEST="$(jq -r '.info.version // ""' pypi-package.json)"
    if [[ -n "$DIST_TAG_LATEST" ]] && echo "$VERSIONS_NEWEST" | grep -qx "$DIST_TAG_LATEST"; then
        LATEST_VERSION="$DIST_TAG_LATEST"
    else
        LATEST_VERSION="$(echo "$VERSIONS_NEWEST" | head -n1)"
    fi
fi

VERSIONS_OLDEST="$(echo "$VERSIONS_NEWEST" | sort -V)"
VERSIONS_JSON="$(echo "$VERSIONS_OLDEST" | jq -Rnc --arg date "$DATE_TAG" --arg latest "$LATEST_VERSION" '
    [inputs | select(length > 0)] | map({
      version: .,
      image_tag: (. + "-" + $date),
      promote_latest: (. == $latest)
    })
')"

echo "versions_json=$VERSIONS_JSON" >> "$GITHUB_OUTPUT"
echo "latest_version=$LATEST_VERSION" >> "$GITHUB_OUTPUT"
echo "should_build=true" >> "$GITHUB_OUTPUT"

echo "Stable versions selected for build (oldest first):"
echo "$VERSIONS_OLDEST"
echo "Latest stable: $LATEST_VERSION"
