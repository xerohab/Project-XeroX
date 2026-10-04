#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT/manifest/master.conf"
source "$ROOT/installer/lib/deployment-safety.sh"

MODE="${1:-}"

if [ "$MODE" != "--prepare" ] && [ "$MODE" != "--apply-prepared" ]; then
    echo "Usage:"
    echo "  $0 --prepare"
    echo "  $0 --apply-prepared"
    exit 2
fi

STAGING_ROOT="${STAGING_ROOT:?STAGING_ROOT required}"
TRANSACTION_ROOT="${TRANSACTION_ROOT:?TRANSACTION_ROOT required}"

NITRO="${NITRO_ROOT:-/var/www/Nitro-V3}"
RENDERER="${RENDERER_ROOT:-/var/www/Nitro_Render_V3}"
EMULATOR="${EMULATOR_ROOT:-/var/www/emulator}"
CMS="${CMS_ROOT:-/var/www/atomcms}"

mkdir -p "$TRANSACTION_ROOT"

assert_safe_destination()
{
    local path="$1"

    [ -d "$path" ] || {
        xerox_die "destination missing: $path"
        return 1
    }

    [ "$path" != "/" ] || {
        xerox_die "refusing root destination"
        return 1
    }
}

assert_safe_destination "$NITRO"
assert_safe_destination "$RENDERER"
assert_safe_destination "$EMULATOR"
assert_safe_destination "$CMS"

xerox_verify_immutable_migrations \
    "$STAGING_ROOT/emulator" \
    "$EMULATOR"

prepare()
{
    python3 "$ROOT/installer/build-transaction.py" \
        --component NITRO \
        --source "$STAGING_ROOT/nitro" \
        --destination "$NITRO" \
        --protection "$ROOT/manifest/protection/nitro.txt" \
        --mode managed \
        --output "$TRANSACTION_ROOT/nitro.json"

    python3 "$ROOT/installer/build-transaction.py" \
        --component RENDERER \
        --source "$STAGING_ROOT/renderer" \
        --destination "$RENDERER" \
        --protection "$ROOT/manifest/protection/renderer.txt" \
        --preserve "$ROOT/manifest/renderer-preserve.txt" \
        --mode managed \
        --output "$TRANSACTION_ROOT/renderer.json"

    python3 "$ROOT/installer/build-transaction.py" \
        --component EMULATOR \
        --source "$STAGING_ROOT/emulator" \
        --destination "$EMULATOR" \
        --protection "$ROOT/manifest/protection/emulator.txt" \
        --mode managed \
        --output "$TRANSACTION_ROOT/emulator.json"

    python3 "$ROOT/installer/build-transaction.py" \
        --component CMS \
        --source "$STAGING_ROOT/cms" \
        --destination "$CMS" \
        --protection "$ROOT/manifest/protection/cms.txt" \
        --allowlist "$ROOT/manifest/cms-portable-files.txt" \
        --mode selective \
        --output "$TRANSACTION_ROOT/cms.json"

    python3 - "$TRANSACTION_ROOT" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])

summary = {
    "format": 1,
    "deployment": "Project XeroX",
    "components": {},
}

for name in ("nitro", "renderer", "emulator", "cms"):
    data = json.loads((root / f"{name}.json").read_text())

    counts = {
        "create": 0,
        "update": 0,
        "preserve": 0,
        "destination_only_keep": len(data["destination_only"]),
    }

    for op in data["operations"]:
        counts[op["operation"]] += 1

    summary["components"][name] = counts

(root / "transaction.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n"
)

print(json.dumps(summary, indent=2, sort_keys=True))
PY

    echo "TRANSACTION_STATUS=PREPARED"
}

apply_prepared()
{
    for f in \
        "$TRANSACTION_ROOT/nitro.json" \
        "$TRANSACTION_ROOT/renderer.json" \
        "$TRANSACTION_ROOT/emulator.json" \
        "$TRANSACTION_ROOT/cms.json" \
        "$TRANSACTION_ROOT/transaction.json"
    do
        [ -s "$f" ] || {
            xerox_die "prepared transaction missing: $f"
            return 1
        }
    done

    RUNTIME_SAVE="$TRANSACTION_ROOT/nitro-runtime"

    # Transaction workspace is disposable. Remove any previous capture
    # before taking the authoritative destination runtime snapshot.
    rm -rf -- "$RUNTIME_SAVE"

    xerox_capture_nitro_runtime_config \
        "$NITRO" \
        "$RUNTIME_SAVE" \
        "$ROOT/manifest/nitro-runtime-config.txt"

    python3 "$ROOT/installer/apply-transaction.py" \
        --transaction "$TRANSACTION_ROOT/renderer.json"

    python3 "$ROOT/installer/apply-transaction.py" \
        --transaction "$TRANSACTION_ROOT/emulator.json"

    python3 "$ROOT/installer/apply-transaction.py" \
        --transaction "$TRANSACTION_ROOT/nitro.json"

    python3 "$ROOT/installer/apply-transaction.py" \
        --transaction "$TRANSACTION_ROOT/cms.json"

    #
    # In production the Nitro build occurs after source deployment.
    # The five destination-owned runtime JSON files are then overlaid
    # into dist/configuration.
    #
    # During disposable certification we create the dist directory
    # ourselves to exercise the exact preservation contract without
    # running a real application build.
    #
    mkdir -p "$NITRO/dist/configuration"

    xerox_restore_nitro_runtime_config \
        "$RUNTIME_SAVE" \
        "$NITRO" \
        "$ROOT/manifest/nitro-runtime-config.txt"

    xerox_verify_nitro_runtime_config \
        "$NITRO" \
        "$ROOT/manifest/nitro-runtime-config.txt"

    xerox_validate_nitro_api_contract "$NITRO"

    xerox_verify_immutable_migrations \
        "$STAGING_ROOT/emulator" \
        "$EMULATOR"

    echo "TRANSACTION_STATUS=APPLIED_AND_VERIFIED"
}

if [ "$MODE" = "--prepare" ]; then
    prepare
else
    apply_prepared
fi
