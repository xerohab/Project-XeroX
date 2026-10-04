#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/manifest/releases.conf"

STAGING="$ROOT/staging"

stage_component()
{
    local NAME="$1"
    local REPO="$2"
    local BRANCH="$3"
    local COMMIT="$4"

    local KEY
    KEY="$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]')"

    local DEST="$STAGING/$KEY"

    echo
    echo "============================================================"
    echo "STAGING: $NAME"
    echo "============================================================"
    echo "Repository: $REPO"
    echo "Branch:     $BRANCH"
    echo "Commit:     $COMMIT"

    rm -rf "$DEST"

    git clone \
        --filter=blob:none \
        --no-checkout \
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
        echo "ERROR: staged $NAME commit mismatch."
        echo "Expected: $COMMIT"
        echo "Actual:   $ACTUAL"
        exit 1
    fi

    if [ -n "$(git -C "$DEST" status --porcelain)" ]; then
        echo "ERROR: staged $NAME repository is dirty."
        git -C "$DEST" status --short
        exit 1
    fi

    echo "PASS: $NAME staged at exact approved commit."
}

mkdir -p "$STAGING"

stage_component \
    "NITRO" \
    "$NITRO_REPO" \
    "$NITRO_BRANCH" \
    "$NITRO_COMMIT"

stage_component \
    "RENDERER" \
    "$RENDERER_REPO" \
    "$RENDERER_BRANCH" \
    "$RENDERER_COMMIT"

stage_component \
    "EMULATOR" \
    "$EMULATOR_REPO" \
    "$EMULATOR_BRANCH" \
    "$EMULATOR_COMMIT"

stage_component \
    "CMS" \
    "$CMS_REPO" \
    "$CMS_BRANCH" \
    "$CMS_COMMIT"

echo
echo "============================================================"
echo "ALL APPROVED RELEASES STAGED"
echo "============================================================"
