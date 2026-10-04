#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XEROX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

NITRO="/var/www/Nitro-V3"
DRY_RUN=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --nitro-root)
            NITRO="${2:?Missing path after --nitro-root}"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            exit 2
            ;;
    esac
done

NITRO="$(realpath "$NITRO")"

echo "============================================================"
echo "PROJECT XEROX INSTALLER"
echo "============================================================"
echo
echo "Nitro root: $NITRO"

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Mode: DRY RUN"
else
    echo "Mode: INSTALL"
fi

echo
echo "===== PREFLIGHT ====="

"$SCRIPT_DIR/preflight.sh" "$NITRO"

echo
echo "===== PATCH COMPATIBILITY ====="

PATCH_ARGS=(
    --nitro-root "$NITRO"
    --package-root "$XEROX_ROOT/package/nitro"
)

if [ "$DRY_RUN" -eq 1 ]; then
    PATCH_ARGS+=(--dry-run)
fi

python3 "$SCRIPT_DIR/patch_nitro.py" "${PATCH_ARGS[@]}"

if [ "$DRY_RUN" -eq 1 ]; then
    echo
    echo "===== OWNED FILES ====="
    echo
    echo "The following Project XeroX files WOULD be installed:"
    echo

    (
        cd "$XEROX_ROOT/package/nitro"

        find src -type f | sort
    )

    echo
    echo "============================================================"
    echo "DRY RUN PASSED"
    echo "Nothing was modified."
    echo "No backup was required."
    echo "No typecheck/build was run."
    echo "============================================================"

    exit 0
fi


STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/var/backups/Project-XeroX/$STAMP"

echo
echo "===== CREATE BACKUP ====="
echo "Backup: $BACKUP"

mkdir -p "$BACKUP"

CREATED_MANIFEST="$BACKUP/.xerox-created-files"
: > "$CREATED_MANIFEST"

backup_file()
{
    local rel="$1"

    if [ -e "$NITRO/$rel" ]; then
        mkdir -p "$BACKUP/$(dirname "$rel")"
        cp -a "$NITRO/$rel" "$BACKUP/$rel"
    fi
}

while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    [[ "$rel" = \#* ]] && continue

    if [[ "$rel" == */ ]]; then
        continue
    fi

    backup_file "$rel"
done < "$XEROX_ROOT/manifest/patched-files.txt"

# Back up Xerox-owned destinations if they already exist.
while IFS= read -r source; do
    rel="${source#"$XEROX_ROOT/package/nitro/"}"

    case "$rel" in
        patches/*)
            continue
            ;;
    esac

    if [ -e "$NITRO/$rel" ]; then
        backup_file "$rel"
    else
        echo "$rel" >> "$CREATED_MANIFEST"
    fi
done < <(find "$XEROX_ROOT/package/nitro/src" -type f)


rollback()
{
    code=$?

    if [ "$code" -eq 0 ]; then
        return
    fi

    echo
    echo "============================================================"
    echo "INSTALL FAILED — ROLLING BACK"
    echo "============================================================"

    if [ -f "$CREATED_MANIFEST" ]; then
        while IFS= read -r rel; do
            [ -z "$rel" ] && continue

            case "$rel" in
                src/*)
                    rm -f -- "$NITRO/$rel"
                    ;;
                *)
                    echo "ROLLBACK SAFETY: refusing unexpected path: $rel"
                    ;;
            esac
        done < "$CREATED_MANIFEST"
    fi

    if [ -d "$BACKUP" ]; then
        while IFS= read -r backup_file_path; do
            rel="${backup_file_path#"$BACKUP/"}"

            case "$rel" in
                .xerox-created-files)
                    continue
                    ;;
            esac

            mkdir -p "$NITRO/$(dirname "$rel")"
            cp -a "$backup_file_path" "$NITRO/$rel"
        done < <(find "$BACKUP" -type f)
    fi

    echo
    echo "Existing files restored."
    echo "New Xerox-created files removed."
    echo "Backup retained at:"
    echo "$BACKUP"
    echo
    echo "No build was performed."
    echo "============================================================"

    exit "$code"
}

trap rollback ERR


echo
echo "===== APPLY INTEGRATION PATCHES ====="

python3 "$SCRIPT_DIR/patch_nitro.py" \
    --nitro-root "$NITRO" \
    --package-root "$XEROX_ROOT/package/nitro"


echo
echo "===== INSTALL XEROX-OWNED FILES ====="

(
    cd "$XEROX_ROOT/package/nitro"

    while IFS= read -r source; do
        rel="${source#./}"

        mkdir -p "$NITRO/$(dirname "$rel")"
        cp -a "$source" "$NITRO/$rel"

        echo "INSTALLED: $rel"
    done < <(find ./src -type f | sort)
)


echo
echo "===== CSS BRACE CHECK ====="

python3 - "$NITRO/src/css/ui2/UI2.css" "$NITRO/src/css/radio/RadioView.css" <<'PY'
from pathlib import Path
import sys

for filename in sys.argv[1:]:
    p = Path(filename)
    text = p.read_text(encoding="utf-8")

    opens = text.count("{")
    closes = text.count("}")

    print(f"{p}: {{={opens} }}={closes}")

    if opens != closes:
        raise SystemExit(f"CSS BRACE CHECK FAILED: {p}")

print("CSS BRACE CHECK PASSED")
PY


echo
echo "===== TYPECHECK ====="

cd "$NITRO"

if command -v yarn >/dev/null 2>&1; then
    yarn typecheck
else
    echo "ERROR: yarn is not installed or not in PATH."
    exit 1
fi


trap - ERR

echo
echo "============================================================"
echo "PROJECT XEROX INSTALLATION VALIDATED"
echo "============================================================"
echo
echo "Backup:"
echo "$BACKUP"
echo
echo "Typecheck passed."
echo
echo "DO NOT BUILD YET."
echo "Review the typecheck/install output first."
echo "============================================================"
