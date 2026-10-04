#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/installer/lib/deployment-safety.sh"

RUNTIME="$ROOT/manifest/nitro-runtime-config.txt"
NITRO="${NITRO_ROOT:-/var/www/Nitro-V3}"

echo "============================================================"
echo "PROJECT XEROX — DEPLOYMENT SAFETY VERIFICATION"
echo "READ ONLY"
echo "============================================================"

echo
echo "===== RUNTIME CONFIG CONTRACT ====="

test -s "$RUNTIME"

for file in \
    client-mode.json \
    renderer-config.json \
    ui-config.json \
    hotlooks.json \
    infostand_backgrounds.json
do
    grep -qx "$file" "$RUNTIME"
    echo "PASS: $file protected"
done

echo
echo "===== FAILURE PROPAGATION SELF-TEST ====="

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/stage"
touch "$TMP/stage/test.backup-123"

if xerox_reject_staging_junk "$TMP/stage" >/dev/null 2>&1; then
    echo "ERROR: junk rejection incorrectly returned success"
    exit 1
fi

echo "PASS: safety failures propagate correctly"

echo
echo "===== LIVE NITRO OBSERVATION ====="

if [ -d "$NITRO/public/configuration" ] &&
   [ -d "$NITRO/dist/configuration" ]; then

    if xerox_verify_nitro_runtime_config "$NITRO" "$RUNTIME"; then
        echo "PASS: current public/dist runtime config match"

        if xerox_validate_nitro_api_contract "$NITRO"; then
            echo "PASS: current Nitro API contract"
        else
            echo "WARN: current Nitro API contract requires attention"
            echo "      No files were changed."
        fi
    else
        echo "WARN: current public/dist runtime config differ"
        echo "      This verifier is observational before deployment."
        echo "      Deployment must capture public config and restore it into dist."
    fi
else
    echo "SKIP: live Nitro public/dist configuration unavailable"
fi

echo
echo "===== SCRIPT SYNTAX ====="

for SCRIPT in \
    "$ROOT"/installer/*.sh \
    "$ROOT"/installer/lib/*.sh
do
    bash -n "$SCRIPT"
    echo "PASS: ${SCRIPT#$ROOT/}"
done

echo
echo "============================================================"
echo "SAFETY VERIFICATION COMPLETE"
echo "NO HOTEL FILES CHANGED"
echo "NO BUILD"
echo "NO SERVICE RESTART"
echo "============================================================"
