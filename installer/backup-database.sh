#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT/manifest/master.conf"
source "$ROOT/manifest/database-policy.conf"
source "$ROOT/installer/lib/deployment-safety.sh"
source "$ROOT/installer/lib/database-safety.sh"

"$ROOT/installer/verify-database-policy.sh"

DB_NAME="${XEROX_DATABASE_NAME:-habbo}"
STAMP="${XEROX_BACKUP_STAMP:-$(date +%Y%m%d-%H%M%S)}"

BACKUP="${XEROX_DATABASE_BACKUP_PATH:-$BACKUP_ROOT/database-rollback-$STAMP}"

xerox_db_backup "$DB_NAME" "$BACKUP"
xerox_db_verify_backup "$BACKUP"

echo "DATABASE_BACKUP_PATH=$BACKUP"
