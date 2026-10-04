#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage()
{
    echo "Usage:"
    echo "  verify-release-engine-files.sh COMMIT"
}

[ "$#" -eq 1 ] || {
    usage >&2
    exit 2
}

COMMIT="$1"

git cat-file -e "$COMMIT^{commit}" 2>/dev/null || {
    echo "ERROR: invalid commit: $COMMIT" >&2
    exit 1
}

EXPECTED="$(mktemp)"
ACTUAL="$(mktemp)"

cleanup()
{
    rm -f "$EXPECTED" "$ACTUAL"
}
trap cleanup EXIT

cat > "$EXPECTED" <<'LIST'
docs/PRODUCTION-TRANSACTION.md
installer/apply-transaction.py
installer/build-transaction.py
installer/deployment-engine.sh
installer/lib/build-safety.sh
installer/lib/deployment-safety.sh
installer/lib/service-safety.sh
installer/production-preflight.sh
installer/production-update.sh
installer/restore-database.sh
manifest/cms-portable-files.txt
manifest/destination-profile.example.conf
manifest/destinations/README.md
manifest/renderer-preserve.txt
LIST

sort -o "$EXPECTED" "$EXPECTED"

git diff-tree \
    --no-commit-id \
    --name-only \
    -r "$COMMIT" |
    sort > "$ACTUAL"

if ! diff -u "$EXPECTED" "$ACTUAL"; then
    echo "ERROR: release-engine commit path set differs from approved allowlist" >&2
    exit 1
fi

while IFS= read -r file
do
    case "$file" in
        database.sql|*/database.sql|\
        *.sql.gz|*.sql.zst|\
        *.dump|*.dump.gz|\
        *.bak|*.old|*.orig|*~|\
        *.pyc|*/__pycache__/*)
            echo "ERROR: forbidden release payload: $file" >&2
            exit 1
            ;;
    esac

    git cat-file -e "$COMMIT:$file" || {
        echo "ERROR: committed file missing: $file" >&2
        exit 1
    }
done < "$ACTUAL"

echo "RELEASE_ENGINE_FILE_AUDIT=PASS"
echo "COMMIT=$COMMIT"
echo "APPROVED_PATH_COUNT=$(wc -l < "$ACTUAL")"
