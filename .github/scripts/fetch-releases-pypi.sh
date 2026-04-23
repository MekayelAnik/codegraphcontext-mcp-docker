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
# Accepts comma-separated list (1.4.5,1.5.3), inclusive range (1.0.0-1.5.3),
# or any mix (1.0.0,1.2.0-1.4.0,1.5.3). Ranges are expanded against the live
# PyPI release list, filtered to stable versions, and inclusive on both ends.
if [[ -n "$MANUAL_VERSIONS_RAW" && "$REQUESTED_ACTION" == "build" ]]; then
    IFS=',' read -ra MANUAL_ARRAY <<< "$MANUAL_VERSIONS_RAW"

    PYPI_ALL_STABLE=""
    fetch_pypi_stable() {
        if [[ -z "$PYPI_ALL_STABLE" ]]; then
            local url="${PYPI_REGISTRY}/pypi/${PYPI_PACKAGE}/json"
            PYPI_ALL_STABLE="$(curl -fsSL "$url" \
                | jq -r '.releases | keys[]' \
                | grep -Evi '(a|b|rc|dev|alpha|beta|pre|post)' \
                | sort -V)"
            if [[ -z "$PYPI_ALL_STABLE" ]]; then
                echo "Failed to fetch PyPI release list for range expansion" >&2
                exit 1
            fi
        fi
    }

    VERSIONS_OLDEST=""
    for v in "${MANUAL_ARRAY[@]}"; do
        clean="$(echo "$v" | xargs)"
        [[ -z "$clean" ]] && continue

        if [[ "$clean" =~ ^([0-9]+(\.[0-9]+)*)-([0-9]+(\.[0-9]+)*)$ ]]; then
            range_lo="${BASH_REMATCH[1]}"
            range_hi="${BASH_REMATCH[3]}"
            if [[ "$(printf '%s\n%s\n' "$range_lo" "$range_hi" | sort -V | head -n1)" != "$range_lo" ]]; then
                echo "Invalid range '$clean': lower bound must be <= upper bound" >&2
                exit 1
            fi
            fetch_pypi_stable
            expanded="$(echo "$PYPI_ALL_STABLE" | awk -v lo="$range_lo" -v hi="$range_hi" '
                function vlte(a, b,   na, nb, i, ai, bi) {
                    na = split(a, ai, ".")
                    nb = split(b, bi, ".")
                    for (i = 1; i <= (na > nb ? na : nb); i++) {
                        x = (i <= na) ? ai[i] + 0 : 0
                        y = (i <= nb) ? bi[i] + 0 : 0
                        if (x < y) return 1
                        if (x > y) return 0
                    }
                    return 1
                }
                { if (vlte(lo, $0) && vlte($0, hi)) print }
            ')"
            if [[ -z "$expanded" ]]; then
                echo "Range '$clean' matched no stable PyPI versions" >&2
                exit 1
            fi
            while IFS= read -r ev; do
                [[ -n "$ev" ]] && VERSIONS_OLDEST="${VERSIONS_OLDEST:+$VERSIONS_OLDEST
}$ev"
            done <<< "$expanded"
        else
            VERSIONS_OLDEST="${VERSIONS_OLDEST:+$VERSIONS_OLDEST
}$clean"
        fi
    done

    # Dedupe while preserving newest-first ordering downstream
    VERSIONS_OLDEST="$(echo "$VERSIONS_OLDEST" | awk 'NF && !seen[$0]++')"

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
