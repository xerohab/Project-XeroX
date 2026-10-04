#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/manifest/releases.conf"

STAGING_ROOT="${STAGING_ROOT:-}"

[ -n "$STAGING_ROOT" ] || {
    echo "ERROR: STAGING_ROOT not supplied"
    exit 1
}

reject_junk()
{
    local DIR="$1"

    # Approved releases are immutable Git commits.
    #
    # Historical files with names such as *.backup-* may themselves be
    # tracked by that approved commit. Staging must never silently delete
    # or alter tracked release content.
    #
    # We reject backup/junk filenames only when they are UNTRACKED.
    local FOUND

    FOUND="$(
        git -C "$DIR" ls-files \
            --others \
            --exclude-standard |
        grep -E '(^|/).*(\.backup[^/]*|\.bak|\.old|\.orig|~)$' |
        head -50 ||
        true
    )"

    if [ -n "$FOUND" ]; then
        echo "ERROR: untracked staging junk detected"
        printf '%s\n' "$FOUND"
        return 1
    fi
}

check()
{
    local NAME="$1"
    local DIR="$2"
    local EXPECTED="$3"

    echo
    echo "===== $NAME ====="

    [ -d "$DIR/.git" ] || {
        echo "ERROR: repository missing: $DIR"
        exit 1
    }

    local ACTUAL
    ACTUAL="$(git -C "$DIR" rev-parse HEAD)"

    echo "EXPECTED=$EXPECTED"
    echo "ACTUAL=$ACTUAL"

    [ "$ACTUAL" = "$EXPECTED" ] || {
        echo "ERROR: commit mismatch"
        exit 1
    }

    [ -z "$(git -C "$DIR" status --porcelain)" ] || {
        echo "ERROR: repository dirty"
        git -C "$DIR" status --short
        exit 1
    }

    reject_junk "$DIR"

    echo "PASS"
}

check NITRO \
    "$STAGING_ROOT/nitro" \
    "$NITRO_COMMIT"

check RENDERER \
    "$STAGING_ROOT/renderer" \
    "$RENDERER_COMMIT"

check EMULATOR \
    "$STAGING_ROOT/emulator" \
    "$EMULATOR_COMMIT"

check CMS \
    "$STAGING_ROOT/cms" \
    "$CMS_COMMIT"

echo
echo "============================================================"
echo "STAGING VERIFIED"
echo "STAGING_ROOT=$STAGING_ROOT"
echo "============================================================"
