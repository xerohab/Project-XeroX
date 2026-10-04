#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/manifest/master.conf"
source "$ROOT/installer/lib/deployment-safety.sh"

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
echo "NOTE: service restart remains a separate controlled operation"
