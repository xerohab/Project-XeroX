#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PROFILE="${1:-}"

if [ -z "$PROFILE" ] || [ ! -f "$PROFILE" ]; then
    echo "Usage: $0 /path/to/destination.conf"
    exit 2
fi

source "$ROOT/manifest/master.conf"
source "$ROOT/installer/lib/deployment-safety.sh"
source "$ROOT/installer/lib/database-safety.sh"
source "$ROOT/installer/lib/service-safety.sh"
source "$PROFILE"

: "${NITRO_ROOT:?}"
: "${RENDERER_ROOT:?}"
: "${EMULATOR_ROOT:?}"
: "${CMS_ROOT:?}"
: "${DATABASE_NAME:?}"

[ "${MANAGE_GAMEDATA:-0}" = "0" ] || {
    xerox_die "Gamedata must remain excluded"
    exit 1
}

for D in \
    "$NITRO_ROOT" \
    "$RENDERER_ROOT" \
    "$EMULATOR_ROOT" \
    "$CMS_ROOT"
do
    [ -d "$D" ] || {
        xerox_die "Destination missing: $D"
        exit 1
    }
done

xerox_service_validate

xerox_validate_nitro_api_contract "$NITRO_ROOT"

xerox_verify_immutable_migrations \
    "$EMULATOR_ROOT" \
    "$EMULATOR_ROOT"

"$ROOT/installer/verify-database-policy.sh"

mariadb \
    --protocol=socket \
    --batch \
    --skip-column-names \
    "$DATABASE_NAME" \
    -e "SELECT 1;" \
    >/dev/null

echo "PRODUCTION_PREFLIGHT=PASS"
echo "GAMEDATA=EXCLUDED"
echo "SERVICE_MODE=$SERVICE_MODE"
