#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Preserve an explicit caller override before master.conf supplies defaults.
CALLER_BACKUP_ROOT="${BACKUP_ROOT:-}"

source "$ROOT/manifest/master.conf"
source "$ROOT/installer/lib/deployment-safety.sh"
source "$ROOT/manifest/database-policy.conf"
source "$ROOT/installer/lib/database-safety.sh"

if [ -n "$CALLER_BACKUP_ROOT" ]; then
    BACKUP_ROOT="$CALLER_BACKUP_ROOT"
fi

NITRO="${NITRO_ROOT:-/var/www/Nitro-V3}"
RENDERER="${RENDERER_ROOT:-/var/www/Nitro_Render_V3}"
EMULATOR="${EMULATOR_ROOT:-/var/www/emulator}"
CMS="${CMS_ROOT:-/var/www/atomcms}"

STAMP="${XEROX_BACKUP_STAMP:-$(date +%Y%m%d-%H%M%S)}"
BACKUP="${XEROX_BACKUP_PATH:-$BACKUP_ROOT/deployment-$STAMP}"

mkdir -p "$BACKUP_ROOT"

if [ -e "$BACKUP" ]; then
    xerox_die "Backup path already exists: $BACKUP"
    exit 1
fi

mkdir -p "$BACKUP/components"

backup_component()
{
    local name="$1"
    local source="$2"

    if [ ! -d "$source" ]; then
        xerox_die "Cannot backup missing component: $source"
        return 1
    fi

    echo "BACKUP: $name"

    tar \
        --xattrs \
        --acls \
        --numeric-owner \
        -C "$(dirname "$source")" \
        -cpf "$BACKUP/components/$name.tar" \
        "$(basename "$source")"

    sha256sum "$BACKUP/components/$name.tar" \
        > "$BACKUP/components/$name.tar.sha256"
}

backup_component nitro "$NITRO"
backup_component renderer "$RENDERER"
backup_component emulator "$EMULATOR"
backup_component cms "$CMS"

# Destination database rollback snapshot.
#
# This contains only this destination hotel's own database and exists
# solely so the same destination can be returned to its pre-update state.
# It is never a Project XeroX release payload.
DATABASE_NAME="${XEROX_DATABASE_NAME:-habbo}"
DATABASE_BACKUP_PATH="$BACKUP/database"

echo
echo "===== DATABASE ROLLBACK SNAPSHOT ====="

"$ROOT/installer/verify-database-policy.sh"

xerox_db_backup \
    "$DATABASE_NAME" \
    "$DATABASE_BACKUP_PATH"

xerox_db_verify_backup \
    "$DATABASE_BACKUP_PATH"

DATABASE_DUMP_SHA256="$(
    awk '{print $1}' \
        "$DATABASE_BACKUP_PATH/database.sql.sha256"
)"

[ -n "$DATABASE_DUMP_SHA256" ] || {
    xerox_die "database backup checksum unavailable"
    exit 1
}

echo "PASS: destination database included in deployment snapshot"

cat > "$BACKUP/backup.env" <<META
BACKUP_FORMAT=2
CREATED_AT=$(date -Iseconds)
NITRO_ROOT=$NITRO
RENDERER_ROOT=$RENDERER
EMULATOR_ROOT=$EMULATOR
CMS_ROOT=$CMS
DATABASE_INCLUDED=1
DATABASE_NAME=$DATABASE_NAME
DATABASE_BACKUP_PATH=$DATABASE_BACKUP_PATH
DATABASE_DUMP_SHA256=$DATABASE_DUMP_SHA256
DATABASE_ROLLBACK_ONLY=1
CROSS_HOTEL_DATABASE_IMPORT=0
META

(
    cd "$BACKUP/components"
    sha256sum -c ./*.sha256
)

echo "$BACKUP" > "$BACKUP_ROOT/latest-deployment-backup"

echo "BACKUP_PATH=$BACKUP"
echo "PASS: deployment backup created and verified"
