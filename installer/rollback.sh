#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/manifest/master.conf"
source "$ROOT/installer/lib/deployment-safety.sh"
source "$ROOT/installer/lib/database-safety.sh"

BACKUP="${1:-}"

if [ -z "$BACKUP" ]; then
    if [ -s "$BACKUP_ROOT/latest-deployment-backup" ]; then
        BACKUP="$(cat "$BACKUP_ROOT/latest-deployment-backup")"
    else
        xerox_die "No rollback backup supplied and no latest backup recorded"
        exit 1
    fi
fi

if [ ! -d "$BACKUP/components" ] || [ ! -s "$BACKUP/backup.env" ]; then
    xerox_die "Invalid Project XeroX backup: $BACKUP"
    exit 1
fi

# shellcheck disable=SC1090
source "$BACKUP/backup.env"

[ "${BACKUP_FORMAT:-0}" = "2" ] || {
    xerox_die "Backup does not contain the required database rollback snapshot"
    exit 1
}

[ "${DATABASE_INCLUDED:-0}" = "1" ] || {
    xerox_die "Database rollback snapshot missing"
    exit 1
}

[ "${DATABASE_ROLLBACK_ONLY:-0}" = "1" ] || {
    xerox_die "Database snapshot is not marked rollback-only"
    exit 1
}

[ "${CROSS_HOTEL_DATABASE_IMPORT:-1}" = "0" ] || {
    xerox_die "Unsafe cross-hotel database policy in backup"
    exit 1
}

[ -n "${DATABASE_NAME:-}" ] || {
    xerox_die "Database name missing from backup metadata"
    exit 1
}

[ -n "${DATABASE_BACKUP_PATH:-}" ] || {
    xerox_die "Database backup path missing from backup metadata"
    exit 1
}

[ -n "${DATABASE_DUMP_SHA256:-}" ] || {
    xerox_die "Database checksum missing from backup metadata"
    exit 1
}

# The database directory must belong to THIS backup transaction.
EXPECTED_DATABASE_PATH="$BACKUP/database"

[ "$DATABASE_BACKUP_PATH" = "$EXPECTED_DATABASE_PATH" ] || {
    xerox_die "Database backup path escapes unified deployment snapshot"
    exit 1
}

xerox_db_verify_backup "$DATABASE_BACKUP_PATH"

ACTUAL_DATABASE_SHA256="$(
    sha256sum "$DATABASE_BACKUP_PATH/database.sql" |
    awk '{print $1}'
)"

[ "$ACTUAL_DATABASE_SHA256" = "$DATABASE_DUMP_SHA256" ] || {
    xerox_die "Unified deployment database checksum mismatch"
    exit 1
}

echo "PASS: deployment database snapshot verified"

for name in nitro renderer emulator cms
do
    [ -s "$BACKUP/components/$name.tar" ] || {
        xerox_die "Backup archive missing: $name"
        exit 1
    }

    [ -s "$BACKUP/components/$name.tar.sha256" ] || {
        xerox_die "Backup checksum missing: $name"
        exit 1
    }
done

(
    cd "$BACKUP/components"
    sha256sum -c ./*.sha256
)

echo
echo "============================================================"
echo "PROJECT XEROX ROLLBACK"
echo "============================================================"
echo "Backup: $BACKUP"
echo
echo "Rollback is intentionally ARMED but not automatically executed"
echo "by this standalone script without explicit --restore."
echo
echo "The database snapshot has been VERIFIED but is NOT automatically"
echo "restored by --restore. Live database restore requires a separate"
echo "explicit controlled database-restore gate."
echo

if [ "${2:-}" != "--restore" ]; then
    echo "Verification passed."
    echo "To actually restore this backup:"
    echo "  $0 '$BACKUP' --restore"
    exit 0
fi

restore_component()
{
    local name="$1"
    local destination="$2"
    local archive="$BACKUP/components/$name.tar"

    local parent
    local base

    parent="$(dirname "$destination")"
    base="$(basename "$destination")"

    [ "$destination" != "/" ] || {
        xerox_die "Refusing to restore over /"
        return 1
    }

    [ -n "$base" ] || {
        xerox_die "Invalid destination: $destination"
        return 1
    }

    mkdir -p "$parent"

    local failed="$destination.failed-$(date +%Y%m%d-%H%M%S)"

    if [ -e "$destination" ]; then
        mv "$destination" "$failed"
    fi

    if ! tar --xattrs --acls --numeric-owner -C "$parent" -xpf "$archive"; then
        rm -rf "$destination"

        if [ -e "$failed" ]; then
            mv "$failed" "$destination"
        fi

        xerox_die "Rollback extraction failed for $name"
        return 1
    fi

    echo "RESTORED: $name -> $destination"
    echo "FAILED_VERSION_SAVED_AS=$failed"
}

restore_component nitro "$NITRO_ROOT"
restore_component renderer "$RENDERER_ROOT"
restore_component emulator "$EMULATOR_ROOT"
restore_component cms "$CMS_ROOT"

echo
echo "PASS: rollback files restored"
echo "NOTE: database was NOT restored"
echo "NOTE: service restart remains a separate controlled operation"
