#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT/manifest/sources.conf"
source "$ROOT/manifest/releases.conf"

STAGING_ROOT="${STAGING_ROOT:-}"

if [ -z "$STAGING_ROOT" ]; then
    echo "ERROR: STAGING_ROOT must be explicitly supplied."
    echo "Persistent Project XeroX staging is no longer permitted."
    exit 1
fi

case "$STAGING_ROOT" in
    "$ROOT"|"$ROOT/"*|/var/www/*|/var/backups/*)
        echo "ERROR: unsafe staging location:"
        echo "$STAGING_ROOT"
        echo "Use an isolated temporary run directory."
        exit 1
        ;;
esac

mkdir -p "$STAGING_ROOT"

if [ -n "$(find "$STAGING_ROOT" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    echo "ERROR: staging root is not empty:"
    echo "$STAGING_ROOT"
    exit 1
fi

stage_component()
{
    local NAME="$1"
    local REPO="$2"
    local BRANCH="$3"
    local COMMIT="$4"

    local KEY
    KEY="$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]')"

    local DEST="$STAGING_ROOT/$KEY"

    echo
    echo "============================================================"
    echo "STAGING: $NAME"
    echo "============================================================"
    echo "Repository: $REPO"
    echo "Branch:     $BRANCH"
    echo "Commit:     $COMMIT"
    echo "Destination:$DEST"

    git clone \
        --filter=blob:none \
        --no-checkout \
        --single-branch \
        --branch "$BRANCH" \
        "$REPO" \
        "$DEST"

    git -C "$DEST" fetch \
        --depth 1 \
        origin \
        "$COMMIT"

    git -C "$DEST" checkout \
        --detach \
        "$COMMIT"

    local ACTUAL
    ACTUAL="$(git -C "$DEST" rev-parse HEAD)"

    if [ "$ACTUAL" != "$COMMIT" ]; then
        echo "ERROR: staged $NAME commit mismatch"
        echo "EXPECTED=$COMMIT"
        echo "ACTUAL=$ACTUAL"
        exit 1
    fi

    if [ -n "$(git -C "$DEST" status --porcelain)" ]; then
        echo "ERROR: staged $NAME repository dirty"
        git -C "$DEST" status --short
        exit 1
    fi

    echo "PASS: $NAME exact approved commit"
}

stage_component \
    NITRO \
    "$NITRO_REPO" \
    "$NITRO_BRANCH" \
    "$NITRO_COMMIT"

stage_component \
    RENDERER \
    "$RENDERER_REPO" \
    "$RENDERER_BRANCH" \
    "$RENDERER_COMMIT"

stage_component \
    EMULATOR \
    "$EMULATOR_REPO" \
    "$EMULATOR_BRANCH" \
    "$EMULATOR_COMMIT"

stage_component \
    CMS \
    "$CMS_REPO" \
    "$CMS_BRANCH" \
    "$CMS_COMMIT"

echo
echo "============================================================"
echo "ALL APPROVED RELEASES STAGED"
echo "STAGING_ROOT=$STAGING_ROOT"
echo "============================================================"
