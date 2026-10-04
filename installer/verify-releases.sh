#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/manifest/releases.conf"

verify_local()
{
    local NAME="$1"
    local PATHNAME="$2"
    local EXPECTED="$3"

    echo
    echo "===== $NAME ====="

    if [ ! -d "$PATHNAME/.git" ]; then
        echo "ERROR: Git repository missing: $PATHNAME"
        return 1
    fi

    local ACTUAL
    ACTUAL="$(git -C "$PATHNAME" rev-parse HEAD)"

    echo "PATH=$PATHNAME"
    echo "EXPECTED=$EXPECTED"
    echo "ACTUAL=$ACTUAL"

    if [ "$ACTUAL" != "$EXPECTED" ]; then
        echo "ERROR: $NAME does not match approved release."
        return 1
    fi

    echo "PASS: $NAME matches approved release."
}

verify_local \
    "NITRO" \
    "/var/www/Nitro-V3" \
    "$NITRO_COMMIT"

verify_local \
    "RENDERER" \
    "/var/www/Nitro_Render_V3" \
    "$RENDERER_COMMIT"

verify_local \
    "EMULATOR" \
    "/var/www/emulator" \
    "$EMULATOR_COMMIT"

verify_local \
    "CMS" \
    "/var/www/atomcms" \
    "$CMS_COMMIT"

echo
echo "============================================================"
echo "ALL APPROVED RELEASES VERIFIED"
echo "============================================================"
