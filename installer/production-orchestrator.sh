#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MODE="${1:-}"
PROFILE="${2:-}"

usage()
{
    echo "Usage:"
    echo "  $0 --simulate /path/to/destination.conf"
    echo
    echo "Real production execution is intentionally unavailable."
}

if [ "$MODE" != "--simulate" ]; then
    echo "PRODUCTION ORCHESTRATOR IS LOCKED"
    usage
    exit 2
fi

if [ -z "$PROFILE" ] || [ ! -f "$PROFILE" ]; then
    usage
    exit 2
fi

source "$ROOT/manifest/master.conf"
source "$ROOT/installer/lib/deployment-safety.sh"
source "$ROOT/installer/lib/database-safety.sh"
source "$ROOT/installer/lib/service-safety.sh"
source "$ROOT/installer/lib/build-safety.sh"
source "$PROFILE"

: "${NITRO_ROOT:?}"
: "${RENDERER_ROOT:?}"
: "${EMULATOR_ROOT:?}"
: "${CMS_ROOT:?}"
: "${DATABASE_NAME:?}"

[ "${BACKUP_REQUIRED:-0}" = "1" ] || {
    xerox_die "Production backup requirement disabled"
    exit 1
}

[ "${ROLLBACK_ON_FAILURE:-0}" = "1" ] || {
    xerox_die "Rollback-on-failure requirement disabled"
    exit 1
}

[ "${DATABASE_MIGRATIONS_ONLY:-0}" = "1" ] || {
    xerox_die "Database must remain migrations-only"
    exit 1
}

[ "${PRESERVE_DESTINATION_DATABASE_DATA:-0}" = "1" ] || {
    xerox_die "Destination database preservation disabled"
    exit 1
}

[ "${DATABASE_BACKUP_REQUIRED_BEFORE_MIGRATION:-0}" = "1" ] || {
    xerox_die "Database rollback snapshot requirement disabled"
    exit 1
}

[ "${CROSS_HOTEL_DATABASE_IMPORT:-1}" = "0" ] || {
    xerox_die "Cross-hotel database import must remain prohibited"
    exit 1
}

[ "${DATABASE_RELEASE_DUMPS_ALLOWED:-1}" = "0" ] || {
    xerox_die "Database release dumps must remain prohibited"
    exit 1
}

[ "${MANAGE_GAMEDATA:-1}" = "0" ] || {
    xerox_die "Gamedata must remain excluded"
    exit 1
}

xerox_service_validate

"$ROOT/installer/verify-database-policy.sh" >/dev/null

for F in \
    "$ROOT/installer/backup.sh" \
    "$ROOT/installer/rollback.sh" \
    "$ROOT/installer/deployment-engine.sh" \
    "$ROOT/installer/stage-releases.sh" \
    "$ROOT/installer/verify-staging.sh"
do
    [ -x "$F" ] || {
        xerox_die "Required executable missing: $F"
        exit 1
    }
done

echo "============================================================"
echo "PROJECT XEROX — PRODUCTION ORCHESTRATOR SIMULATION"
echo "============================================================"
echo
echo "This simulation validates production ordering only."
echo "It performs no application mutation."
echo

step()
{
    printf 'ORDER=%02d ACTION=%s\n' "$1" "$2"
}

step 1  "PRODUCTION_PREFLIGHT"
step 2  "STAGE_EXACT_APPROVED_RELEASES"
step 3  "VERIFY_STAGING_AND_IMMUTABLE_MIGRATIONS"
step 4  "PREPARE_TRANSACTION"
step 5  "CREATE_UNIFIED_FILESYSTEM_AND_DATABASE_BACKUP"
step 6  "VERIFY_BACKUP"
step 7  "STOP_CONFIGURED_SERVICE"
step 8  "CAPTURE_DESTINATION_NITRO_RUNTIME_CONFIG"
step 9  "APPLY_PREPARED_SOURCE_TRANSACTION"
step 10 "BUILD_RENDERER"
step 11 "TYPECHECK_NITRO"
step 12 "BUILD_NITRO"
step 13 "RESTORE_DESTINATION_RUNTIME_CONFIG_TO_NITRO_DIST"
step 14 "BUILD_EMULATOR"
step 15 "RUN_APPROVED_POLARIS_MIGRATIONS"
step 16 "VERIFY_RUNTIME_CONFIG_AND_IMMUTABLE_MIGRATIONS"
step 17 "START_CONFIGURED_SERVICE"
step 18 "VERIFY_SERVICE_HEALTH"
step 19 "VERIFY_HTTP_RUNTIME_CONFIGURATION"
step 20 "MARK_DEPLOYMENT_SUCCESS"

echo
echo "FAILURE POLICY:"
echo "  Before mutation: abort without rollback."
echo "  After mutation: stop deployment and preserve failure evidence."
echo "  Filesystem rollback: verified deployment backup."
echo "  Database rollback: NEVER automatic."
echo "  Database rollback requires explicit restore-database.sh confirmation."
echo
echo "BACKUP_REQUIRED=1"
echo "DATABASE_BACKUP_REQUIRED=1"
echo "DATABASE_MODE=MIGRATIONS_ONLY"
echo "AUTOMATIC_DATABASE_RESTORE=DISABLED"
echo "GAMEDATA=EXCLUDED"
echo "SERVICE_MODE=$SERVICE_MODE"
echo "SERVICE_NAME=${SERVICE_NAME:-NONE}"
echo "PRODUCTION_ORCHESTRATOR_SIMULATION=PASS"
echo "REAL_INSTALL=LOCKED"
