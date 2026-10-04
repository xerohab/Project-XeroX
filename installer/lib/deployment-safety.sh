#!/usr/bin/env bash

xerox_die()
{
    echo "PROJECT XEROX ERROR: $*" >&2
    return 1
}

xerox_validate_json()
{
    local file="$1"

    if [ ! -s "$file" ]; then
        xerox_die "Missing/empty JSON: $file"
        return 1
    fi

    if ! python3 -m json.tool "$file" >/dev/null 2>&1; then
        xerox_die "Invalid JSON: $file"
        return 1
    fi
}

xerox_capture_nitro_runtime_config()
{
    local nitro="$1"
    local save="$2"
    local manifest="$3"
    local src="$nitro/public/configuration"

    if [ ! -d "$src" ]; then
        xerox_die "Destination Nitro configuration missing: $src"
        return 1
    fi

    mkdir -p "$save" || return 1

    while IFS= read -r file
    do
        case "$file" in
            ""|\#*) continue ;;
        esac

        if [ ! -s "$src/$file" ]; then
            xerox_die "Required destination runtime config missing: $src/$file"
            return 1
        fi

        xerox_validate_json "$src/$file" || return 1

        install -m 0644 "$src/$file" "$save/$file" || return 1

        if ! cmp -s "$src/$file" "$save/$file"; then
            xerox_die "Runtime config capture mismatch: $file"
            return 1
        fi

        echo "CAPTURED: $file"
    done < "$manifest"
}

xerox_json_semantically_equal()
{
    local left="$1"
    local right="$2"

    xerox_validate_json "$left" || return 1
    xerox_validate_json "$right" || return 1

    python3 - "$left" "$right" <<'PYJSON'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    left = json.load(f)

with open(sys.argv[2], "r", encoding="utf-8") as f:
    right = json.load(f)

raise SystemExit(0 if left == right else 1)
PYJSON
}

xerox_restore_nitro_runtime_config()
{
    local save="$1"
    local nitro="$2"
    local manifest="$3"
    local dst="$nitro/dist/configuration"

    if [ ! -d "$dst" ]; then
        xerox_die "Built Nitro configuration directory missing: $dst"
        return 1
    fi

    while IFS= read -r file
    do
        case "$file" in
            ""|\#*) continue ;;
        esac

        if [ ! -s "$save/$file" ]; then
            xerox_die "Captured runtime config missing: $file"
            return 1
        fi

        xerox_validate_json "$save/$file" || return 1

        install -m 0644 "$save/$file" "$dst/$file" || return 1

        if ! cmp -s "$save/$file" "$dst/$file"; then
            xerox_die "Runtime config restore mismatch: $file"
            return 1
        fi

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

        if [ ! -s "$src" ]; then
            xerox_die "Public runtime config missing after deploy: $file"
            return 1
        fi

        if [ ! -s "$dst" ]; then
            xerox_die "Dist runtime config missing after deploy: $file"
            return 1
        fi

        xerox_validate_json "$src" || return 1
        xerox_validate_json "$dst" || return 1

        if ! xerox_json_semantically_equal "$src" "$dst"; then
            xerox_die "Destination runtime config semantics changed: $file"
            return 1
        fi

        echo "CONFIG SEMANTIC MATCH: $file"
    done < "$manifest"
}

xerox_validate_nitro_api_contract()
{
    local nitro="$1"

    local client="$nitro/dist/configuration/client-mode.json"
    local renderer="$nitro/dist/configuration/renderer-config.json"

    xerox_validate_json "$client" || return 1
    xerox_validate_json "$renderer" || return 1

    python3 - "$client" "$renderer" <<'PY'
import json
import sys
from urllib.parse import urlparse

client_path, renderer_path = sys.argv[1], sys.argv[2]

with open(client_path, encoding="utf-8") as f:
    client = json.load(f)

with open(renderer_path, encoding="utf-8") as f:
    renderer = json.load(f)

def find_key(obj, wanted):
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key == wanted:
                return value
            found = find_key(value, wanted)
            if found is not None:
                return found
    elif isinstance(obj, list):
        for value in obj:
            found = find_key(value, wanted)
            if found is not None:
                return found
    return None

api_base = find_key(client, "apiBaseUrl")
api_url = find_key(renderer, "api.url")

if api_url is None:
    api_section = find_key(renderer, "api")
    if isinstance(api_section, dict):
        api_url = api_section.get("url")

def valid_endpoint(value):
    if not isinstance(value, str) or not value.strip():
        return False

    value = value.strip()

    if "${" in value:
        return False

    parsed = urlparse(value)

    if parsed.scheme in ("http", "https"):
        return bool(parsed.netloc)

    # Relative API roots such as /api are acceptable.
    return value.startswith("/")

if api_base is not None and not valid_endpoint(api_base):
    print(
        f"PROJECT XEROX ERROR: invalid client apiBaseUrl: {api_base!r}",
        file=sys.stderr,
    )
    sys.exit(1)

if not valid_endpoint(api_url):
    print(
        f"PROJECT XEROX ERROR: missing/invalid renderer api.url: {api_url!r}",
        file=sys.stderr,
    )
    sys.exit(1)

print(f"PASS: renderer api.url={api_url}")

if api_base is None:
    print("INFO: client-mode.json does not define apiBaseUrl")
else:
    print(f"PASS: client apiBaseUrl={api_base}")
PY
}

xerox_verify_http_config()
{
    local domain="$1"
    local manifest="$2"
    local scheme="${3:-https}"
    local address="${4:-127.0.0.1}"
    local base_path="${5:-/client/configuration}"

    local tmp
    tmp="$(mktemp)" || return 1

    while IFS= read -r file
    do
        case "$file" in
            ""|\#*) continue ;;
        esac

        local code

        if ! code="$(
            curl -ksS \
                --connect-timeout 10 \
                --max-time 30 \
                -o "$tmp" \
                -w '%{http_code}' \
                -H "Host: $domain" \
                "$scheme://$address$base_path/$file"
        )"; then
            rm -f "$tmp"
            xerox_die "HTTP request failed for $file"
            return 1
        fi

        if [ "$code" != "200" ]; then
            rm -f "$tmp"
            xerox_die "$file returned HTTP $code"
            return 1
        fi

        if ! python3 -m json.tool "$tmp" >/dev/null 2>&1; then
            rm -f "$tmp"
            xerox_die "$file did not return valid JSON"
            return 1
        fi

        echo "HTTP 200 JSON: $file"
    done < "$manifest"

    rm -f "$tmp"
}

xerox_verify_immutable_migrations()
{
    local staged="$1"
    local destination="$2"

    local rel="Emulator/src/main/resources/db/migration"
    local src="$staged/$rel"
    local dst="$destination/$rel"

    if [ ! -d "$src" ]; then
        xerox_die "Staged migration directory missing: $src"
        return 1
    fi

    if [ ! -d "$dst" ]; then
        xerox_die "Destination migration directory missing: $dst"
        return 1
    fi

    local failures=0

    while IFS= read -r -d '' file
    do
        local name
        name="$(basename "$file")"

        if [ -f "$dst/$name" ] && ! cmp -s "$file" "$dst/$name"; then
            echo "IMMUTABILITY FAILURE: $name" >&2
            failures=$((failures + 1))
        fi
    done < <(find "$src" -maxdepth 1 -type f -name 'V*.sql' -print0)

    if [ "$failures" -ne 0 ]; then
        xerox_die "$failures historical migration(s) differ from destination"
        return 1
    fi

    echo "PASS: existing Flyway migration history is immutable"
}

xerox_reject_staging_junk()
{
    local stage="$1"

    if [ ! -d "$stage" ]; then
        xerox_die "Staging directory missing: $stage"
        return 1
    fi

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

    if [ "$failures" -ne 0 ]; then
        xerox_die "$failures backup/junk file(s) detected in staging"
        return 1
    fi

    echo "PASS: no recognised backup/junk files in staging"
}
