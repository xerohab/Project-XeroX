#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MODE="${1:-}"
PROFILE="${2:-}"

if [ "$MODE" != "--certify" ]; then
    echo "PRODUCTION INSTALL IS LOCKED"
    echo "Supported mode: --certify"
    exit 2
fi

if [ -z "$PROFILE" ] || [ ! -f "$PROFILE" ]; then
    echo "Usage: $0 --certify /path/to/destination.conf"
    exit 2
fi

source "$ROOT/manifest/master.conf"
source "$ROOT/installer/lib/deployment-safety.sh"
source "$ROOT/installer/lib/database-safety.sh"
source "$ROOT/installer/lib/service-safety.sh"
source "$ROOT/installer/lib/build-safety.sh"
source "$PROFILE"

echo "PROJECT XEROX PRODUCTION CERTIFICATION"
echo "NO FILE DEPLOYMENT"
echo "NO DATABASE MIGRATION"
echo "NO SERVICE STOP/START"
echo

"$ROOT/installer/production-preflight.sh" "$PROFILE"

echo
echo "===== BACKUP CAPABILITY ====="

[ -x "$ROOT/installer/backup.sh" ] || {
    xerox_die "Unified backup engine unavailable"
    exit 1
}

[ -x "$ROOT/installer/rollback.sh" ] || {
    xerox_die "Rollback engine unavailable"
    exit 1
}

echo "PASS: unified backup/rollback engines present"

echo
echo "===== BUILD CAPABILITY ====="

if [ "${BUILD_NITRO:-1}" = "1" ]; then
    command -v yarn >/dev/null 2>&1 || {
        xerox_die "Nitro build dependency yarn unavailable"
        exit 1
    }
fi

if [ "${BUILD_RENDERER:-1}" = "1" ]; then
    command -v yarn >/dev/null 2>&1 || {
        xerox_die "Renderer build dependency yarn unavailable"
        exit 1
    }
fi

if [ "${BUILD_EMULATOR:-1}" = "1" ]; then
    if \
        [ ! -x "$EMULATOR_ROOT/gradlew" ] &&
        [ ! -x "$EMULATOR_ROOT/Emulator/gradlew" ] &&
        ! {
            [ -f "$EMULATOR_ROOT/Emulator/pom.xml" ] &&
            command -v mvn >/dev/null 2>&1
        }
    then
        xerox_die "No supported Emulator build tool found"
        exit 1
    fi
fi

echo "PASS: build prerequisites"

echo
echo "===== DEPLOYMENT ENGINE ====="

for F in \
    "$ROOT/installer/deployment-engine.sh" \
    "$ROOT/installer/build-transaction.py" \
    "$ROOT/installer/apply-transaction.py"
do
    [ -s "$F" ] || {
        xerox_die "Deployment engine component missing: $F"
        exit 1
    }
done

echo "PASS: transaction deployment engine"

echo
echo "===== PRODUCTION ORCHESTRATOR ====="

[ -x "$ROOT/installer/production-orchestrator.sh" ] || {
    xerox_die "Production orchestrator unavailable"
    exit 1
}

"$ROOT/installer/production-orchestrator.sh"     --simulate     "$PROFILE"

echo "PASS: production orchestrator simulation"

echo
echo "===== PRODUCTION RULES ====="

echo "BACKUP BEFORE DEPLOYMENT=REQUIRED"
echo "DATABASE ROLLBACK SNAPSHOT=REQUIRED"
echo "DATABASE MODE=MIGRATIONS_ONLY"
echo "CROSS-HOTEL DATABASE IMPORT=PROHIBITED"
echo "GAMEDATA=EXCLUDED"
echo "SERVICE CONTROL=EXPLICIT"
echo "PROTECTED DESTINATION STATE=PRESERVED"
echo "NITRO RUNTIME CONFIG=PRESERVED"
echo "FLYWAY HISTORY=IMMUTABLE"
echo "CMS=SELECTIVE"
echo "AUTOMATIC LIVE DB RESTORE=DISABLED"
echo
echo "PRODUCTION_GATE_CERTIFICATION=PASS"
echo "REAL_INSTALL=LOCKED"
