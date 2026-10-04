#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NITRO="${NITRO_ROOT:-/var/www/Nitro-V3}"
RENDERER="${RENDERER_ROOT:-/var/www/Nitro_Render_V3}"
EMULATOR="${EMULATOR_ROOT:-/var/www/emulator}"
CMS="${CMS_ROOT:-/var/www/atomcms}"

STAGING_ROOT="${STAGING_ROOT:-}"

if [ -z "$STAGING_ROOT" ]; then
    echo "ERROR: STAGING_ROOT not supplied"
    exit 1
fi

REPORT_DIR="${REPORT_DIR:-$ROOT/reports}"

mkdir -p "$REPORT_DIR"

compare()
{
    local NAME="$1"
    local SOURCE="$2"
    local DEST="$3"
    local PROTECTION="$4"
    local MODE="${5:-managed}"

    local OUTPUT="$REPORT_DIR/${NAME,,}-comparison.txt"

    echo
    echo "============================================================"
    echo "COMPARE: $NAME"
    echo "============================================================"

    if [ ! -d "$SOURCE" ]; then
        echo "ERROR: staged source missing: $SOURCE"
        exit 1
    fi

    if [ ! -d "$DEST" ]; then
        echo "ERROR: destination missing: $DEST"
        exit 1
    fi

    EXTRA=()

    if [ "$MODE" = "selective" ]; then
        EXTRA+=(--selective)
    fi

    "$ROOT/installer/compare-release.py" \
        --component "$NAME" \
        --source "$SOURCE" \
        --destination "$DEST" \
        --protection "$PROTECTION" \
        --output "$OUTPUT" \
        "${EXTRA[@]}"
}

compare \
    NITRO \
    "$STAGING_ROOT/nitro" \
    "$NITRO" \
    "$ROOT/manifest/protection/nitro.txt"

compare \
    RENDERER \
    "$STAGING_ROOT/renderer" \
    "$RENDERER" \
    "$ROOT/manifest/protection/renderer.txt"

compare \
    EMULATOR \
    "$STAGING_ROOT/emulator" \
    "$EMULATOR" \
    "$ROOT/manifest/protection/emulator.txt"

compare \
    CMS \
    "$STAGING_ROOT/cms" \
    "$CMS" \
    "$ROOT/manifest/protection/cms.txt" \
    selective

echo
echo "============================================================"
echo "COMPARISON COMPLETE"
echo "READ ONLY — NOTHING DEPLOYED"
echo "============================================================"
