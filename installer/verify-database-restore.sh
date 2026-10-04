#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT/manifest/master.conf"
source "$ROOT/installer/lib/deployment-safety.sh"
source "$ROOT/installer/lib/database-safety.sh"

BACKUP="${1:-}"

[ -n "$BACKUP" ] || {
    xerox_die "database backup path required"
    exit 1
}

xerox_db_require_local_access
xerox_db_verify_backup "$BACKUP"

# shellcheck disable=SC1090
source "$BACKUP/database.env"

xerox_db_validate_name "$DATABASE_NAME"

TEST_DB="xerox_restore_test_$$"
REWRITTEN_DUMP="$(mktemp /tmp/project-xerox-db-restore.XXXXXX.sql)"

cleanup()
{
    local rc=$?

    trap - EXIT INT TERM

    rm -f -- "$REWRITTEN_DUMP"

    mariadb \
        --protocol=socket \
        -e "DROP DATABASE IF EXISTS \`$TEST_DB\`;" \
        >/dev/null 2>&1 || true

    return "$rc"
}

trap cleanup EXIT

echo "TEST_DATABASE=$TEST_DB"

mariadb \
    --protocol=socket \
    -e "
        DROP DATABASE IF EXISTS \`$TEST_DB\`;
        CREATE DATABASE \`$TEST_DB\`
            CHARACTER SET utf8mb4
            COLLATE utf8mb4_unicode_ci;
    "

#
# Rewrite ONLY CREATE DATABASE / USE statements.
#
# The backup data itself is unchanged. This prevents the verification
# restore from selecting or recreating the live destination database.
#
python3 - "$BACKUP/database.sql" "$TEST_DB" "$REWRITTEN_DUMP" <<'PY'
import re
import sys

source, test_db, destination = sys.argv[1:4]

create_re = re.compile(
    r"^\s*CREATE\s+DATABASE\b.*?`[^`]+`.*;\s*$",
    re.IGNORECASE,
)

use_re = re.compile(
    r"^\s*USE\s+`[^`]+`;\s*$",
    re.IGNORECASE,
)

with open(
    source,
    "r",
    encoding="utf-8",
    errors="surrogateescape",
) as src, open(
    destination,
    "w",
    encoding="utf-8",
    errors="surrogateescape",
) as dst:
    for line in src:
        stripped = line.rstrip("\r\n")

        if create_re.match(stripped):
            continue

        if use_re.match(stripped):
            dst.write(f"USE `{test_db}`;\n")
            continue

        dst.write(line)
PY

[ -s "$REWRITTEN_DUMP" ] || {
    xerox_die "rewritten verification dump is empty"
    exit 1
}

echo "PASS: disposable restore stream prepared"

#
# Safety assertion:
# the rewritten dump must not contain a USE statement selecting
# the original destination database.
#
if grep -Eiq \
    "^[[:space:]]*USE[[:space:]]+\`$DATABASE_NAME\`;" \
    "$REWRITTEN_DUMP"
then
    xerox_die "verification dump still selects live database"
    exit 1
fi

echo "PASS: live database selection absent from verification dump"

mariadb \
    --protocol=socket \
    "$TEST_DB" \
    < "$REWRITTEN_DUMP"

echo "PASS: disposable database import completed"

RESTORED_TABLES="$(
    mariadb \
        --protocol=socket \
        --batch \
        --skip-column-names \
        -e "
            SELECT COUNT(*)
            FROM information_schema.TABLES
            WHERE TABLE_SCHEMA='$TEST_DB';
        "
)"

RESTORED_FLYWAY_ROWS="$(
    mariadb \
        --protocol=socket \
        --batch \
        --skip-column-names \
        -e "
            SELECT COUNT(*)
            FROM \`$TEST_DB\`.flyway_schema_history;
        "
)"

RESTORED_FLYWAY_RANK="$(
    mariadb \
        --protocol=socket \
        --batch \
        --skip-column-names \
        -e "
            SELECT COALESCE(MAX(installed_rank),0)
            FROM \`$TEST_DB\`.flyway_schema_history;
        "
)"

RESTORED_FLYWAY_VERSION="$(
    mariadb \
        --protocol=socket \
        --batch \
        --skip-column-names \
        -e "
            SELECT COALESCE(MAX(version),'')
            FROM \`$TEST_DB\`.flyway_schema_history;
        "
)"

echo "EXPECTED_TABLES=$TABLE_COUNT"
echo "RESTORED_TABLES=$RESTORED_TABLES"

echo "EXPECTED_FLYWAY_ROWS=$FLYWAY_ROWS"
echo "RESTORED_FLYWAY_ROWS=$RESTORED_FLYWAY_ROWS"

echo "EXPECTED_FLYWAY_RANK=$FLYWAY_MAX_RANK"
echo "RESTORED_FLYWAY_RANK=$RESTORED_FLYWAY_RANK"

echo "EXPECTED_FLYWAY_VERSION=$FLYWAY_MAX_VERSION"
echo "RESTORED_FLYWAY_VERSION=$RESTORED_FLYWAY_VERSION"

[ "$RESTORED_TABLES" = "$TABLE_COUNT" ] || {
    xerox_die "restored table count mismatch"
    exit 1
}

[ "$RESTORED_FLYWAY_ROWS" = "$FLYWAY_ROWS" ] || {
    xerox_die "restored Flyway row count mismatch"
    exit 1
}

[ "$RESTORED_FLYWAY_RANK" = "$FLYWAY_MAX_RANK" ] || {
    xerox_die "restored Flyway rank mismatch"
    exit 1
}

[ "$RESTORED_FLYWAY_VERSION" = "$FLYWAY_MAX_VERSION" ] || {
    xerox_die "restored Flyway version mismatch"
    exit 1
}

echo "PASS: database backup restored successfully into disposable database"
echo "PASS: live destination database was not restored or replaced"
