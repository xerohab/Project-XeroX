#!/usr/bin/env bash

xerox_die()
{
    echo "PROJECT XEROX ERROR: $*" >&2
    return 1
}

xerox_validate_json()
{
    local file="$1"

    [ -s "$file" ] ||
        xerox_die "Missing/empty JSON: $file"

    python3 -m json.tool "$file" >/dev/null ||
        xerox_die "Invalid JSON: $file"
}

xerox_capture_nitro_runtime_config()
{
    local nitro="$1"
    local save="$2"
    local manifest="$3"

    local src="$nitro/public/configuration"

    [ -d "$src" ] ||
        xerox_die "Destination Nitro configuration missing: $src"

    mkdir -p "$save"

    while IFS= read -r file
    do
        case "$file" in
            ""|\#*) continue ;;
        esac

        [ -s "$src/$file" ] ||
            xerox_die "Required destination runtime config missing: $src/$file"

        xerox_validate_json "$src/$file"

        install -m 0644 "$src/$file" "$save/$file"

        cmp -s "$src/$file" "$save/$file" ||
            xerox_die "Runtime config capture mismatch: $file"

        echo "CAPTURED: $file"

    done < "$manifest"
}

xerox_restore_nitro_runtime_config()
{
    local save="$1"
    local nitro="$2"
    local manifest="$3"

    local dst="$nitro/dist/configuration"

    [ -d "$dst" ] ||
        xerox_die "Built Nitro configuration directory missing: $dst"

    while IFS= read -r file
    do
        case "$file" in
            ""|\#*) continue ;;
        esac

        [ -s "$save/$file" ] ||
            xerox_die "Captured runtime config missing: $file"

        xerox_validate_json "$save/$file"

        install -m 0644 "$save/$file" "$dst/$file"

        cmp -s "$save/$file" "$dst/$file" ||
            xerox_die "Runtime config restore mismatch: $file"

        echo "RESTORED: $file"

    done < "$manifest"
}

xerox_verify_nitro_runtime_config()
{
    local nitro="$1"
    local manifest="$2"

    while IFS= read -r file
    do
        case "$file" in
            ""|\#*) continue ;;
        esac

        local src="$nitro/public/configuration/$file"
        local dst="$nitro/dist/configuration/$file"

        [ -s "$src" ] ||
            xerox_die "Public runtime config missing after deploy: $file"

        [ -s "$dst" ] ||
            xerox_die "Dist runtime config missing after deploy: $file"

        xerox_validate_json "$dst"

        cmp -s "$src" "$dst" ||
            xerox_die "Destination runtime config was not preserved: $file"

        echo "CONFIG MATCH: $file"

    done < "$manifest"
}

xerox_verify_http_config()
{
    local domain="$1"
    local manifest="$2"
    local tmp
    tmp="$(mktemp)"

    while IFS= read -r file
    do
        case "$file" in
            ""|\#*) continue ;;
        esac

        local code

        code="$(
            curl -ksS \
                -o "$tmp" \
                -w '%{http_code}' \
                -H "Host: $domain" \
                "https://127.0.0.1/client/configuration/$file"
        )"

        [ "$code" = "200" ] ||
        {
            rm -f "$tmp"
            xerox_die "$file returned HTTP $code"
            return 1
        }

        python3 -m json.tool "$tmp" >/dev/null ||
        {
            rm -f "$tmp"
            xerox_die "$file did not return valid JSON"
            return 1
        }

        echo "HTTP 200 JSON: $file"

    done < "$manifest"

    rm -f "$tmp"
}

xerox_check_unresolved_runtime_placeholders()
{
    local nitro="$1"

    if grep -RIl \
        --include='*.json' \
        -E '\$\{(api\.url|apiBaseUrl)\}' \
        "$nitro/dist/configuration" \
        2>/dev/null
    then
        xerox_die "Unresolved API placeholder found in deployed runtime JSON"
    fi

    echo "PASS: no unresolved API placeholders in runtime JSON"
}

xerox_verify_immutable_migrations()
{
    local staged="$1"
    local destination="$2"

    local rel="Emulator/src/main/resources/db/migration"
    local src="$staged/$rel"
    local dst="$destination/$rel"

    [ -d "$src" ] ||
        xerox_die "Staged migration directory missing: $src"

    [ -d "$dst" ] ||
        xerox_die "Destination migration directory missing: $dst"

    local failures=0

    while IFS= read -r -d '' file
    do
        local name
        name="$(basename "$file")"

        if [ -f "$dst/$name" ] && ! cmp -s "$file" "$dst/$name"
        then
            echo "IMMUTABILITY FAILURE: $name" >&2
            failures=$((failures + 1))
        fi

    done < <(find "$src" -maxdepth 1 -type f -name 'V*.sql' -print0)

    [ "$failures" -eq 0 ] ||
        xerox_die "$failures historical migration(s) differ from destination"

    echo "PASS: existing Flyway migration history is immutable"
}

xerox_reject_staging_junk()
{
    local stage="$1"
    local failures=0

    while IFS= read -r -d '' file
    do
        local base
        base="$(basename "$file")"

        case "$base" in
            *.backup-*|*.bak|*.orig|*.rej|*~)
                echo "STAGING JUNK: $file" >&2
                failures=$((failures + 1))
                ;;
        esac

    done < <(find "$stage" -type f -print0)

    [ "$failures" -eq 0 ] ||
        xerox_die "$failures backup/junk file(s) detected in staging"

    echo "PASS: no recognised backup/junk files in staging"
}
