#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROFILE="${1:-}"
CONFIRM="${2:-}"

[ -f "$PROFILE" ] || {
    echo "ERROR: destination profile missing"
    exit 1
}

[ "$CONFIRM" = "PROJECT-XEROX-PRODUCTION-UPDATE" ] || {
    echo "ERROR: production authorization rejected"
    exit 1
}

source "$PROFILE"
source manifest/master.conf
source manifest/database-policy.conf
source installer/lib/deployment-safety.sh
source installer/lib/database-safety.sh
source installer/lib/service-safety.sh
source installer/lib/build-safety.sh

[ "${MANAGE_GAMEDATA:-0}" = "0" ] || {
    echo "ERROR: gamedata must remain excluded"
    exit 1
}

[ "${DATABASE_MODE:-}" = "MIGRATIONS_ONLY" ] || {
    echo "ERROR: database must remain migrations-only"
    exit 1
}

[ "${DATABASE_BACKUP_REQUIRED_BEFORE_MIGRATION:-0}" = "1" ] || {
    echo "ERROR: database backup requirement disabled"
    exit 1
}

echo
echo "===== PRODUCTION PREFLIGHT ====="

installer/production-preflight.sh "$PROFILE"

RUN_ROOT="$(mktemp -d /tmp/project-xerox-production.XXXXXX)"
STAGING_ROOT="$RUN_ROOT/staging"
REPORT_DIR="$RUN_ROOT/reports"
RUNTIME_DIR="$RUN_ROOT/runtime"
TRANSACTION_ROOT="$RUN_ROOT/transaction"

mkdir -p \
 "$STAGING_ROOT" \
 "$REPORT_DIR" \
 "$RUNTIME_DIR" \
 "$TRANSACTION_ROOT"

cleanup()
{
    rm -rf "$RUN_ROOT"
}
trap cleanup EXIT

echo
echo "===== STAGE EXACT APPROVED RELEASES ====="

STAGING_ROOT="$STAGING_ROOT" \
 installer/stage-releases.sh

STAGING_ROOT="$STAGING_ROOT" \
 installer/verify-staging.sh

echo
echo "===== VERIFY IMMUTABLE MIGRATIONS ====="

xerox_verify_immutable_migrations \
 "$EMULATOR_ROOT" \
 "$STAGING_ROOT/emulator"

echo
echo "===== PREPARE TRANSACTION ====="

STAGING_ROOT="$STAGING_ROOT" \
REPORT_DIR="$REPORT_DIR" \
TRANSACTION_ROOT="$TRANSACTION_ROOT" \
 installer/deployment-engine.sh \
 --prepare \
 "$PROFILE"

echo
echo "===== CAPTURE DESTINATION RUNTIME CONFIG ====="

xerox_capture_nitro_runtime_config \
 "$NITRO_ROOT" \
 "$RUNTIME_DIR" \
 manifest/nitro-runtime-config.txt

echo
echo "===== CREATE REQUIRED PRODUCTION BACKUP ====="

BACKUP_CONTAINER="/var/backups/Project-XeroX/production-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_CONTAINER"

NITRO_ROOT="$NITRO_ROOT" \
RENDERER_ROOT="$RENDERER_ROOT" \
EMULATOR_ROOT="$EMULATOR_ROOT" \
CMS_ROOT="$CMS_ROOT" \
XEROX_DATABASE_NAME="$DATABASE_NAME" \
BACKUP_ROOT="$BACKUP_CONTAINER" \
 installer/backup.sh

BACKUP_ROOT="$(
    find "$BACKUP_CONTAINER" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -name 'deployment-*' \
        -print |
    LC_ALL=C sort |
    tail -1
)"

[ -n "$BACKUP_ROOT" ] || {
    echo "ERROR: backup.sh did not create a deployment backup"
    exit 1
}

test -f "$BACKUP_ROOT/backup.env"

installer/rollback.sh "$BACKUP_ROOT"

echo "BACKUP_VERIFICATION=PASS"
echo "BACKUP=$BACKUP_ROOT"

echo
echo "===== STOP CONFIGURED SERVICE ====="

xerox_service_validate
xerox_service_stop

FAILURE_STAGE="PRE_FLYWAY"

failure()
{
    RC=$?

    echo
    echo "============================================================"
    echo "PROJECT XEROX PRODUCTION FAILURE"
    echo "EXIT_CODE=$RC"
    echo "FAILURE_STAGE=$FAILURE_STAGE"
    echo "BACKUP=$BACKUP_ROOT"
    echo "AUTOMATIC_DATABASE_RESTORE=DISABLED"
    echo "============================================================"
    echo
    echo "Verified rollback evidence has been preserved."
    echo "Review database state before any rollback."

    exit "$RC"
}

trap failure ERR

echo
echo "===== APPLY APPROVED SOURCE TRANSACTION ====="

STAGING_ROOT="$STAGING_ROOT" \
REPORT_DIR="$REPORT_DIR" \
TRANSACTION_ROOT="$TRANSACTION_ROOT" \
 installer/deployment-engine.sh \
 --apply-prepared \
 "$PROFILE"

echo
echo "===== BUILD RENDERER ====="

if [ "${BUILD_RENDERER:-1}" = "1" ]; then
    xerox_build_renderer "$RENDERER_ROOT"
fi

echo
echo "===== TYPECHECK NITRO ====="

if [ "${BUILD_NITRO:-1}" = "1" ]; then
    (
        cd "$NITRO_ROOT"
        yarn typecheck
    )
fi

echo
echo "===== BUILD NITRO ====="

if [ "${BUILD_NITRO:-1}" = "1" ]; then
    (
        cd "$NITRO_ROOT"
        yarn build
    )
fi

echo
echo "===== RESTORE NITRO RUNTIME CONFIG ====="

mkdir -p "$NITRO_ROOT/dist/configuration"

xerox_restore_nitro_runtime_config \
 "$RUNTIME_DIR" \
 "$NITRO_ROOT" \
 manifest/nitro-runtime-config.txt

xerox_verify_nitro_runtime_config \
 "$NITRO_ROOT" \
 manifest/nitro-runtime-config.txt

xerox_validate_nitro_api_contract "$NITRO_ROOT"

echo
echo "===== BUILD EMULATOR ====="

if [ "${BUILD_EMULATOR:-1}" = "1" ]; then
    xerox_build_emulator "$EMULATOR_ROOT"
fi

echo
echo "===== FINAL MIGRATION SAFETY ====="

xerox_verify_immutable_migrations \
 "$EMULATOR_ROOT" \
 "$STAGING_ROOT/emulator"

echo
echo "===== START POLARIS ====="
echo "Flyway runs through normal Polaris startup."

FAILURE_STAGE="POST_FLYWAY_BOUNDARY"

xerox_service_start
xerox_service_health

sleep 5

echo
echo "===== VERIFY FLYWAY ====="

FAILED="$(
mariadb --protocol=socket --batch --skip-column-names -e "
SELECT COUNT(*)
FROM \`${DATABASE_NAME}\`.flyway_schema_history
WHERE success=0;
"
)"

test "$FAILED" = 0

DB_AFTER="$(
mariadb --protocol=socket --batch --skip-column-names -e "
SELECT
 (SELECT COUNT(*)
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA='${DATABASE_NAME}'),
 COUNT(*),
 COALESCE(MAX(installed_rank),0),
 COALESCE(MAX(version),''),
 COALESCE(SUM(CASE WHEN success=0 THEN 1 ELSE 0 END),0)
FROM \`${DATABASE_NAME}\`.flyway_schema_history;
"
)"

echo "DATABASE_AFTER=$DB_AFTER"
echo "FAILED_MIGRATIONS=$FAILED"

echo
echo "===== VERIFY FINAL RUNTIME CONFIG ====="

xerox_verify_nitro_runtime_config \
 "$NITRO_ROOT" \
 manifest/nitro-runtime-config.txt

xerox_validate_nitro_api_contract "$NITRO_ROOT"

echo
echo "===== FINAL SERVICE HEALTH ====="

xerox_service_health

trap - ERR

echo
echo "============================================================"
echo "PROJECT XEROX PRODUCTION UPDATE=PASS"
echo "BACKUP=$BACKUP_ROOT"
echo "DATABASE_MODE=MIGRATIONS_ONLY"
echo "AUTOMATIC_DATABASE_RESTORE=DISABLED"
echo "GAMEDATA=EXCLUDED"
echo "SERVICE=HEALTHY"
echo "============================================================"
