#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RUN_ROOT="$(mktemp -d /tmp/project-xerox-plan.XXXXXX)"
STAGING_ROOT="$RUN_ROOT/releases"
REPORT_DIR="$RUN_ROOT/reports"

mkdir -p "$STAGING_ROOT" "$REPORT_DIR"

KEEP_PLAN_WORKSPACE="${KEEP_PLAN_WORKSPACE:-0}"

cleanup()
{
    local RC=$?

    trap - EXIT INT TERM

    if [ "$KEEP_PLAN_WORKSPACE" = "1" ]; then
        echo
        echo "PLAN_WORKSPACE_RETAINED=$RUN_ROOT"
    else
        rm -rf -- "$RUN_ROOT"
        echo
        echo "PLAN_WORKSPACE_CLEANED=YES"
    fi

    return "$RC"
}

trap cleanup EXIT

echo "============================================================"
echo "PROJECT XEROX — ISOLATED DEPLOYMENT PLAN"
echo "============================================================"
echo "RUN_ROOT=$RUN_ROOT"
echo "STAGING_ROOT=$STAGING_ROOT"
echo "REPORT_DIR=$REPORT_DIR"
echo "READ_ONLY=YES"

echo
echo "===== STAGE APPROVED RELEASES ====="

STAGING_ROOT="$STAGING_ROOT" \
    "$ROOT/installer/stage-releases.sh"

echo
echo "===== VERIFY APPROVED RELEASES ====="

STAGING_ROOT="$STAGING_ROOT" \
    "$ROOT/installer/verify-staging.sh"

echo
echo "===== COMPARE APPROVED RELEASES TO DESTINATION ====="

STAGING_ROOT="$STAGING_ROOT" \
REPORT_DIR="$REPORT_DIR" \
    "$ROOT/installer/compare-destination.sh"

echo
echo "===== DESTINATION SAFETY PLAN ====="

"$ROOT/installer/plan-deployment.sh"

echo
echo "===== COMPARISON SUMMARY ====="

for FILE in "$REPORT_DIR"/*-comparison.txt
do
    [ -f "$FILE" ] || continue

    echo
    echo "--- $(basename "$FILE") ---"

    sed -n \
        '/===== SUMMARY =====/,/===== DEPLOY CANDIDATES =====/p' \
        "$FILE"
done

echo
echo "============================================================"
echo "ISOLATED_PLAN_STATUS=READY"
echo "NO BUILD"
echo "NO BACKUP"
echo "NO RESTART"
echo "NO DEPLOYMENT"
echo "============================================================"
