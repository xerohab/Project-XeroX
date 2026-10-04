#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT/manifest/master.conf"
source "$ROOT/manifest/releases.conf"

NITRO="${NITRO_ROOT:-/var/www/Nitro-V3}"
RENDERER="${RENDERER_ROOT:-/var/www/Nitro_Render_V3}"
EMULATOR="${EMULATOR_ROOT:-/var/www/emulator}"
CMS="${CMS_ROOT:-/var/www/atomcms}"

RUNTIME="$ROOT/manifest/nitro-runtime-config.txt"

errors=0
warnings=0

error()
{
    echo "ERROR: $*"
    errors=$((errors + 1))
}

warn()
{
    echo "WARN: $*"
    warnings=$((warnings + 1))
}

pass()
{
    echo "PASS: $*"
}

repo_head()
{
    local path="$1"

    if [ -d "$path/.git" ]; then
        git -C "$path" rev-parse HEAD 2>/dev/null || true
    fi
}

repo_dirty()
{
    local path="$1"

    if [ -d "$path/.git" ]; then
        [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]
    else
        return 1
    fi
}

component()
{
    local name="$1"
    local path="$2"
    local mode="$3"
    local approved="$4"

    echo
    echo "------------------------------------------------------------"
    echo "$name"
    echo "------------------------------------------------------------"
    echo "MODE=$mode"
    echo "DESTINATION=$path"
    echo "APPROVED_RELEASE=$approved"

    if [ ! -d "$path" ]; then
        error "$name destination missing"
        return
    fi

    pass "$name destination exists"

    local head
    head="$(repo_head "$path")"

    if [ -n "$head" ]; then
        echo "DESTINATION_HEAD=$head"

        if [ "$head" = "$approved" ]; then
            echo "RELEASE_STATE=approved-baseline"
        else
            echo "RELEASE_STATE=integration-required"
        fi

        if repo_dirty "$path"; then
            echo "DESTINATION_WORKTREE=modified"
            warn "$name contains destination modifications; updater must preserve/merge according to policy"
        else
            echo "DESTINATION_WORKTREE=clean"
        fi
    else
        echo "DESTINATION_HEAD=not-a-git-checkout"
        echo "RELEASE_STATE=integration-required"
        warn "$name has no detectable Git baseline"
    fi
}

echo "============================================================"
echo "PROJECT XEROX — DEPLOYMENT PLAN"
echo "READ ONLY"
echo "============================================================"

echo
echo "===== COMPONENT POLICY ====="

component \
    "NITRO" \
    "$NITRO" \
    "managed" \
    "$NITRO_COMMIT"

component \
    "RENDERER" \
    "$RENDERER" \
    "managed" \
    "$RENDERER_COMMIT"

component \
    "EMULATOR" \
    "$EMULATOR" \
    "managed" \
    "$EMULATOR_COMMIT"

component \
    "CMS" \
    "$CMS" \
    "selective" \
    "$CMS_COMMIT"

echo
echo "===== GAMEDATA POLICY ====="

if [ "${MANAGE_GAMEDATA:-0}" = "0" ]; then
    pass "gamedata excluded from Project XeroX master deployment"
else
    error "gamedata unexpectedly enabled"
fi

echo
echo "===== NITRO DESTINATION-OWNED RUNTIME CONFIG ====="

if [ ! -s "$RUNTIME" ]; then
    error "runtime config manifest missing"
else
    while IFS= read -r file
    do
        case "$file" in
            ""|\#*) continue ;;
        esac

        src="$NITRO/public/configuration/$file"

        if [ ! -s "$src" ]; then
            error "Nitro protected runtime config missing: $file"
            continue
        fi

        if python3 -m json.tool "$src" >/dev/null 2>&1; then
            pass "capture and preserve $file"
        else
            error "Nitro protected runtime config invalid JSON: $file"
        fi
    done < "$RUNTIME"
fi

echo
echo "===== PROTECTED DESTINATION STATE ====="

cat <<'PLAN'
PRESERVE:
  hotel branding / identity
  loading / landing / login artwork
  environment files and credentials
  destination URLs and ports
  database contents
  Nitro runtime configuration
  hotel-specific emulator configuration
  destination mobile customisations unless explicitly managed
  unrelated CMS custom pages
  gamedata

MANAGED:
  Nitro approved portable application changes
  Renderer approved portable application changes
  Emulator approved portable application changes

SELECTIVE:
  CMS only through explicitly approved files/integrations

NEVER:
  wholesale CMS replacement
  wholesale gamedata replacement
  overwrite destination runtime config with Solace config
  rewrite existing Flyway migrations
PLAN

echo
echo "===== PLANNED EXECUTION ORDER ====="

cat <<'PLAN'
01 preflight
02 fetch exact approved releases into isolated staging
03 verify staged commit pins
04 reject staging junk/backups
05 audit destination
06 compare staged releases against destination
07 verify immutable Flyway migration history
08 capture destination-owned Nitro runtime config
09 create verified rollback backup
10 integrate approved Nitro changes
11 integrate approved Renderer changes
12 integrate approved Emulator changes
13 apply selective CMS integration
14 typecheck/build applicable components
15 restore destination Nitro runtime config into built dist
16 validate JSON and runtime API contract
17 validate protected destination state
18 controlled service restart
19 HTTP/runtime smoke tests
20 automatic rollback on deployment failure
PLAN

echo
echo "===== RELEASE PINS ====="

printf 'NITRO=%s\n' "$NITRO_COMMIT"
printf 'RENDERER=%s\n' "$RENDERER_COMMIT"
printf 'EMULATOR=%s\n' "$EMULATOR_COMMIT"
printf 'CMS=%s\n' "$CMS_COMMIT"

echo
echo "===== RESULT ====="
echo "ERRORS=$errors"
echo "WARNINGS=$warnings"

if [ "$errors" -ne 0 ]; then
    echo "PLAN_STATUS=BLOCKED"
    exit 1
fi

echo "PLAN_STATUS=READY_FOR_STAGING_DRY_RUN"
echo
echo "NO FILES CHANGED"
echo "NO BACKUP CREATED"
echo "NO BUILD"
echo "NO SERVICE RESTART"
echo "NO DEPLOYMENT"
