#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT/installer/lib/database-safety.sh"

usage()
{
    cat <<'TXT'
Usage:
  restore-database.sh --verify BACKUP_DIR

  restore-database.sh --restore BACKUP_DIR \
      --database DATABASE \
      --service SERVICE \
      --confirm RESTORE-DATABASE

Important:
  --verify never modifies a database.

  --restore is destructive and must only be used to restore a private
  rollback snapshot to the SAME destination database from which it came.

  Automatic database restore is intentionally unsupported.
TXT
}

MODE=""
BACKUP_DIR=""
DATABASE=""
SERVICE=""
CONFIRM=""

while [ "$#" -gt 0 ]
do
    case "$1" in
        --verify)
            [ "$#" -ge 2 ] || {
                usage
                exit 2
            }

            MODE="verify"
            BACKUP_DIR="$2"
            shift 2
            ;;

        --restore)
            [ "$#" -ge 2 ] || {
                usage
                exit 2
            }

            MODE="restore"
            BACKUP_DIR="$2"
            shift 2
            ;;

        --database)
            [ "$#" -ge 2 ] || {
                usage
                exit 2
            }

            DATABASE="$2"
            shift 2
            ;;

        --service)
            [ "$#" -ge 2 ] || {
                usage
                exit 2
            }

            SERVICE="$2"
            shift 2
            ;;

        --confirm)
            [ "$#" -ge 2 ] || {
                usage
                exit 2
            }

            CONFIRM="$2"
            shift 2
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            echo "ERROR: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[ -n "$MODE" ] || {
    usage
    exit 2
}

[ -n "$BACKUP_DIR" ] || {
    echo "ERROR: backup directory required" >&2
    exit 1
}

BACKUP_DIR="$(readlink -f "$BACKUP_DIR")"

[ -d "$BACKUP_DIR" ] || {
    echo "ERROR: backup directory not found: $BACKUP_DIR" >&2
    exit 1
}

META="$BACKUP_DIR/database.env"
DUMP="$BACKUP_DIR/database.sql"
SHA="$BACKUP_DIR/database.sql.sha256"

[ -f "$META" ] || {
    echo "ERROR: database metadata missing" >&2
    exit 1
}

[ -s "$DUMP" ] || {
    echo "ERROR: database dump missing/empty" >&2
    exit 1
}

[ -s "$SHA" ] || {
    echo "ERROR: database checksum missing" >&2
    exit 1
}

# shellcheck disable=SC1090
source "$META"

BACKUP_DATABASE="${DATABASE_NAME:-${DB_NAME:-}}"

[ -n "$BACKUP_DATABASE" ] || {
    echo "ERROR: backup database identity missing" >&2
    exit 1
}

case "$BACKUP_DATABASE" in
    *[!A-Za-z0-9_]*|"")
        echo "ERROR: unsafe backup database name" >&2
        exit 1
        ;;
esac

(
    cd "$BACKUP_DIR"
    sha256sum -c "$(basename "$SHA")"
)

xerox_db_verify_backup "$BACKUP_DIR"

echo "BACKUP_DATABASE=$BACKUP_DATABASE"
echo "BACKUP_VERIFICATION=PASS"

if [ "$MODE" = "verify" ]; then
    echo "DATABASE_RESTORE=NOT_PERFORMED"
    exit 0
fi

[ "$CONFIRM" = "RESTORE-DATABASE" ] || {
    echo "ERROR: destructive confirmation missing" >&2
    exit 1
}

[ -n "$DATABASE" ] || {
    echo "ERROR: --database required" >&2
    exit 1
}

case "$DATABASE" in
    *[!A-Za-z0-9_]*|"")
        echo "ERROR: unsafe destination database name" >&2
        exit 1
        ;;
esac

[ "$DATABASE" = "$BACKUP_DATABASE" ] || {
    echo "ERROR: cross-database restore prohibited" >&2
    echo "BACKUP_DATABASE=$BACKUP_DATABASE" >&2
    echo "REQUESTED_DATABASE=$DATABASE" >&2
    exit 1
}

[ -n "$SERVICE" ] || {
    echo "ERROR: --service required" >&2
    exit 1
}

systemctl cat "$SERVICE" >/dev/null 2>&1 || {
    echo "ERROR: configured service does not exist: $SERVICE" >&2
    exit 1
}

echo
echo "WARNING: DESTRUCTIVE DATABASE RESTORE AUTHORIZED"
echo "DATABASE=$DATABASE"
echo "SERVICE=$SERVICE"
echo "BACKUP=$BACKUP_DIR"

WAS_ACTIVE=0

if systemctl is-active --quiet "$SERVICE"; then
    WAS_ACTIVE=1
    systemctl stop "$SERVICE"
fi

restore_service()
{
    if [ "$WAS_ACTIVE" -eq 1 ]; then
        systemctl start "$SERVICE" || true
    fi
}

trap restore_service EXIT

if systemctl is-active --quiet "$SERVICE"; then
    echo "ERROR: service did not stop" >&2
    exit 1
fi

# The dump was created with --databases, so it owns CREATE/USE for its
# original database. Identity was checked above before execution.
mariadb --protocol=socket < "$DUMP"

if [ "$WAS_ACTIVE" -eq 1 ]; then
    systemctl start "$SERVICE"
    WAS_ACTIVE=0

    systemctl is-active --quiet "$SERVICE" || {
        echo "ERROR: service failed after database restore" >&2
        exit 1
    }
fi

trap - EXIT

echo "DATABASE_RESTORE=PASS"
echo "DATABASE=$DATABASE"
echo "AUTOMATIC_RESTORE=DISABLED"
