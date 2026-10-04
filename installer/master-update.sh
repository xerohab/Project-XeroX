#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT/manifest/master.conf"

MODE="dry-run"

if [ "${1:-}" = "--install" ]; then
    MODE="install"
fi

echo "============================================================"
echo "PROJECT XEROX — MASTER UPDATER"
echo "============================================================"
echo
echo "Mode: $MODE"
echo "Project: $PROJECT_ROOT"
echo "Backups: $BACKUP_ROOT"
echo

echo "Components:"
echo "  1. Renderer"
echo "  2. Emulator"
echo "  3. Nitro"
echo "  4. CMS portable changes"
echo "  5. Project XeroX UI"
echo
echo "Gamedata:"
echo "  Managed separately"
echo

if [ "$MODE" = "install" ]; then
    echo "INSTALL MODE IS NOT ENABLED YET."
    echo
    echo "This protection is intentional."
    echo "The deployment engine must be completed and validated first."
    exit 1
fi

echo "===== SAFETY POLICY ====="

printf '%-30s %s\n' "Backups required:" "$BACKUP_REQUIRED"
printf '%-30s %s\n' "Rollback on failure:" "$ROLLBACK_ON_FAILURE"
printf '%-30s %s\n' "Preserve hotel identity:" "$PRESERVE_HOTEL_IDENTITY"
printf '%-30s %s\n' "Preserve database:" "$PRESERVE_DATABASE"
printf '%-30s %s\n' "Preserve gamedata:" "$PRESERVE_GAMEDATA"
printf '%-30s %s\n' "Preserve landing:" "$PRESERVE_LANDING"
printf '%-30s %s\n' "Preserve loading:" "$PRESERVE_LOADING"
printf '%-30s %s\n' "Preserve login:" "$PRESERVE_LOGIN"
printf '%-30s %s\n' "Preserve secrets:" "$PRESERVE_SECRETS"
printf '%-30s %s\n' "CMS full replacement:" "$CMS_FULL_REPLACE"

echo
echo "===== COMPONENT POLICIES ====="

for file in "$ROOT"/manifest/components/*.conf
do
    echo
    echo "--- $(basename "$file") ---"

    grep -E \
        '^(COMPONENT|MODE|SOURCE_REPO|SOURCE_BRANCH|DEFAULT_DESTINATION)=' \
        "$file"
done

echo
echo "============================================================"
echo "MASTER DRY RUN PASSED"
echo "============================================================"
echo
echo "Nothing was downloaded."
echo "Nothing was installed."
echo "No destination files were changed."
echo "============================================================"
