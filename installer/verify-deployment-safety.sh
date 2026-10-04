#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT/installer/lib/deployment-safety.sh"

RUNTIME="$ROOT/manifest/nitro-runtime-config.txt"

echo "============================================================"
echo "PROJECT XEROX — DEPLOYMENT SAFETY VERIFICATION"
echo "READ-ONLY AGAINST LIVE COMPONENTS"
echo "============================================================"

echo
echo "===== MANIFEST ====="

test -s "$RUNTIME"

grep -q '^client-mode.json$' "$RUNTIME"
grep -q '^renderer-config.json$' "$RUNTIME"
grep -q '^ui-config.json$' "$RUNTIME"

echo "PASS: runtime configuration contract"

echo
echo "===== STAGING JUNK ====="

# Report this separately for now. Existing historical staging may contain junk;
# verification must expose it without deleting anything.
if xerox_reject_staging_junk "$ROOT/staging"
then
    echo "PASS: staging cleanliness"
else
    echo "WARN: staging currently contains historical junk"
    echo "      Nothing has been deleted."
fi

echo
echo "===== NITRO CONFIG ====="

if [ -d /var/www/Nitro-V3/public/configuration ] &&
   [ -d /var/www/Nitro-V3/dist/configuration ]
then
    xerox_verify_nitro_runtime_config \
        /var/www/Nitro-V3 \
        "$RUNTIME"
else
    echo "SKIP: live Nitro dist/public contract unavailable on this server"
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
echo "SAFETY LAYER CREATED"
echo "NO HOTEL FILES CHANGED"
echo "NO BUILD PERFORMED"
echo "NO SERVICE RESTARTED"
echo "============================================================"
