#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/manifest/releases.conf"

check()
{
    local NAME="$1"
    local DIR="$2"
    local EXPECTED="$3"

    echo
    echo "===== $NAME ====="

    if [ ! -d "$DIR/.git" ]; then
        echo "ERROR: staging repository missing:"
        echo "$DIR"
        exit 1
    fi

    local ACTUAL
    ACTUAL="$(git -C "$DIR" rev-parse HEAD)"

    echo "EXPECTED=$EXPECTED"
    echo "ACTUAL=$ACTUAL"

    if [ "$ACTUAL" != "$EXPECTED" ]; then
        echo "ERROR: commit mismatch."
        exit 1
    fi

    if [ -n "$(git -C "$DIR" status --porcelain)" ]; then
        echo "ERROR: staging repository dirty."
        exit 1
    fi

    echo "PASS"
}

check NITRO \
    "$ROOT/staging/nitro" \
    "$NITRO_COMMIT"

check RENDERER \
    "$ROOT/staging/renderer" \
    "$RENDERER_COMMIT"

check EMULATOR \
    "$ROOT/staging/emulator" \
    "$EMULATOR_COMMIT"

check CMS \
    "$ROOT/staging/cms" \
    "$CMS_COMMIT"

echo
echo "============================================================"
echo "STAGING VERIFIED"
echo "============================================================"
