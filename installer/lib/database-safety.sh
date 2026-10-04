#!/usr/bin/env bash

xerox_db_client()
{
    mariadb --protocol=socket "$@"
}

xerox_db_require_local_access()
{
    command -v mariadb >/dev/null 2>&1 || {
        xerox_die "mariadb client unavailable"
        return 1
    }

    command -v mariadb-dump >/dev/null 2>&1 || {
        xerox_die "mariadb-dump unavailable"
        return 1
    }

    mariadb \
        --protocol=socket \
        --batch \
        --skip-column-names \
        -e 'SELECT 1' \
        >/dev/null 2>&1 || {
            xerox_die "local MariaDB socket authentication unavailable"
            return 1
        }
}

xerox_db_validate_name()
{
    local db="$1"

    case "$db" in
        ""|*[!A-Za-z0-9_]*)
            xerox_die "unsafe database name: $db"
            return 1
            ;;
    esac
}

xerox_db_backup()
{
    local db="$1"
    local destination="$2"

    xerox_db_validate_name "$db" || return 1
    xerox_db_require_local_access || return 1

    local exists

    exists="$(
        mariadb \
            --protocol=socket \
            --batch \
            --skip-column-names \
            -e "
                SELECT COUNT(*)
                FROM information_schema.SCHEMATA
                WHERE SCHEMA_NAME='$db';
            "
    )"

    [ "$exists" = "1" ] || {
        xerox_die "database does not exist: $db"
        return 1
    }

    mkdir -p "$destination" || return 1
    chmod 0700 "$destination" || return 1

    local dump="$destination/database.sql"
    local checksum="$destination/database.sql.sha256"
    local metadata="$destination/database.env"

    umask 077

    echo "DATABASE BACKUP: $db"

    if ! mariadb-dump \
        --protocol=socket \
        --databases "$db" \
        --single-transaction \
        --quick \
        --routines \
        --triggers \
        --events \
        --hex-blob \
        --default-character-set=utf8mb4 \
        > "$dump"
    then
        rm -f "$dump"
        xerox_die "database dump failed"
        return 1
    fi

    [ -s "$dump" ] || {
        xerox_die "database dump is empty"
        return 1
    }

    sha256sum "$dump" > "$checksum" || return 1

    (
        cd "$destination"
        sha256sum -c database.sql.sha256
    ) || return 1

    local tables
    local flyway_rows
    local flyway_rank
    local flyway_version

    tables="$(
        mariadb \
            --protocol=socket \
            --batch \
            --skip-column-names \
            -e "
                SELECT COUNT(*)
                FROM information_schema.TABLES
                WHERE TABLE_SCHEMA='$db';
            "
    )"

    flyway_rows="$(
        mariadb \
            --protocol=socket \
            --batch \
            --skip-column-names \
            -e "
                SELECT COUNT(*)
                FROM \`$db\`.flyway_schema_history;
            "
    )"

    flyway_rank="$(
        mariadb \
            --protocol=socket \
            --batch \
            --skip-column-names \
            -e "
                SELECT COALESCE(MAX(installed_rank),0)
                FROM \`$db\`.flyway_schema_history;
            "
    )"

    flyway_version="$(
        mariadb \
            --protocol=socket \
            --batch \
            --skip-column-names \
            -e "
                SELECT COALESCE(MAX(version),'')
                FROM \`$db\`.flyway_schema_history;
            "
    )"

    cat > "$metadata" <<META
DATABASE_BACKUP_FORMAT=1
DATABASE_NAME=$db
CREATED_AT=$(date -Iseconds)
TABLE_COUNT=$tables
FLYWAY_ROWS=$flyway_rows
FLYWAY_MAX_RANK=$flyway_rank
FLYWAY_MAX_VERSION=$flyway_version
ROLLBACK_ONLY=1
CROSS_HOTEL_IMPORT_ALLOWED=0
META

    chmod 0600 \
        "$dump" \
        "$checksum" \
        "$metadata"

    echo "DATABASE_NAME=$db"
    echo "TABLE_COUNT=$tables"
    echo "FLYWAY_ROWS=$flyway_rows"
    echo "FLYWAY_MAX_RANK=$flyway_rank"
    echo "FLYWAY_MAX_VERSION=$flyway_version"
    echo "PASS: database rollback backup created and verified"
}

xerox_db_verify_backup()
{
    local backup="$1"

    [ -d "$backup" ] || {
        xerox_die "database backup directory missing: $backup"
        return 1
    }

    [ -s "$backup/database.sql" ] || {
        xerox_die "database dump missing"
        return 1
    }

    [ -s "$backup/database.sql.sha256" ] || {
        xerox_die "database checksum missing"
        return 1
    }

    [ -s "$backup/database.env" ] || {
        xerox_die "database metadata missing"
        return 1
    }

    (
        cd "$backup"
        sha256sum -c database.sql.sha256
    ) || return 1

    # shellcheck disable=SC1090
    source "$backup/database.env"

    [ "${DATABASE_BACKUP_FORMAT:-}" = "1" ] || {
        xerox_die "unsupported database backup format"
        return 1
    }

    [ "${ROLLBACK_ONLY:-}" = "1" ] || {
        xerox_die "database backup is not marked rollback-only"
        return 1
    }

    [ "${CROSS_HOTEL_IMPORT_ALLOWED:-1}" = "0" ] || {
        xerox_die "unsafe database backup policy"
        return 1
    }

    echo "PASS: database backup checksum and metadata verified"
}
