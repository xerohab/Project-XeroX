#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT/manifest/master.conf"
source "$ROOT/manifest/database-policy.conf"

fail()
{
    echo "PROJECT XEROX ERROR: $*" >&2
    exit 1
}

[ "${PRESERVE_DATABASE:-0}" = "1" ] ||
    fail "PRESERVE_DATABASE must remain enabled"

[ "${DATABASE_MIGRATIONS_ONLY:-0}" = "1" ] ||
    fail "database deployment must remain migrations-only"

[ "${PRESERVE_DESTINATION_DATABASE_DATA:-0}" = "1" ] ||
    fail "destination database data protection is disabled"

[ "${DATABASE_BACKUP_REQUIRED_BEFORE_MIGRATION:-0}" = "1" ] ||
    fail "database rollback backup is not mandatory"

[ "${CROSS_HOTEL_DATABASE_IMPORT:-1}" = "0" ] ||
    fail "cross-hotel database import must be disabled"

[ "${DATABASE_RELEASE_DUMPS_ALLOWED:-1}" = "0" ] ||
    fail "database dumps must not be release payloads"

[ "${DATABASE_MODE:-}" = "MIGRATIONS_ONLY" ] ||
    fail "database policy is not MIGRATIONS_ONLY"

[ "${ALLOW_APPROVED_SCHEMA_MIGRATIONS:-0}" = "1" ] ||
    fail "approved schema migration policy missing"

[ "${REQUIRE_IMMUTABLE_MIGRATION_HISTORY:-0}" = "1" ] ||
    fail "immutable Flyway history requirement missing"

[ "${REQUIRE_DATABASE_ROLLBACK_BACKUP:-0}" = "1" ] ||
    fail "rollback database backup requirement missing"

[ "${DATABASE_BACKUP_FOR_ROLLBACK_ONLY:-0}" = "1" ] ||
    fail "database backup must be rollback-only"

[ "${ALLOW_DATABASE_DUMP_AS_RELEASE_PAYLOAD:-1}" = "0" ] ||
    fail "release database dumps must be prohibited"

[ "${ALLOW_CROSS_HOTEL_DATA_IMPORT:-1}" = "0" ] ||
    fail "cross-hotel data import must be prohibited"

[ "${ALLOW_DATABASE_REPLACEMENT:-1}" = "0" ] ||
    fail "database replacement must be prohibited"

for FLAG in \
    PRESERVE_USERS \
    PRESERVE_USER_SETTINGS \
    PRESERVE_USER_CURRENCIES \
    PRESERVE_USER_INVENTORIES \
    PRESERVE_USER_ACHIEVEMENTS \
    PRESERVE_USER_RELATIONSHIPS \
    PRESERVE_ROOMS \
    PRESERVE_ROOM_ITEMS \
    PRESERVE_CATALOG_STATE \
    PRESERVE_BANS \
    PRESERVE_MESSAGES \
    PRESERVE_GROUPS \
    PRESERVE_WEBSITE_ACCOUNTS
do
    [ "${!FLAG:-0}" = "1" ] ||
        fail "$FLAG must remain enabled"
done

echo "DATABASE_MODE=$DATABASE_MODE"
echo "DESTINATION_DATA=PRESERVED"
echo "CROSS_HOTEL_IMPORT=PROHIBITED"
echo "DATABASE_REPLACEMENT=PROHIBITED"
echo "RELEASE_DATABASE_DUMPS=PROHIBITED"
echo "APPROVED_MIGRATIONS=ALLOWED"
echo "ROLLBACK_BACKUP=REQUIRED"

echo "PASS: Project XeroX database isolation policy"
