#!/usr/bin/env bash
set -u

NITRO="${NITRO_ROOT:-/var/www/Nitro-V3}"
RENDERER="${RENDERER_ROOT:-/var/www/Nitro_Render_V3}"
EMULATOR="${EMULATOR_ROOT:-/var/www/emulator}"
CMS="${CMS_ROOT:-/var/www/atomcms}"

OUTPUT="${1:-/tmp/project-xerox-destination-audit.txt}"

: > "$OUTPUT"

say()
{
    echo "$*" | tee -a "$OUTPUT"
}

section()
{
    say ""
    say "============================================================"
    say "$1"
    say "============================================================"
}

git_info()
{
    local NAME="$1"
    local PATHNAME="$2"

    section "$NAME"

    say "PATH=$PATHNAME"

    if [ ! -d "$PATHNAME" ]; then
        say "STATUS=MISSING"
        return
    fi

    say "STATUS=PRESENT"

    if git -C "$PATHNAME" rev-parse --show-toplevel >/dev/null 2>&1; then

        local TOP
        TOP="$(git -C "$PATHNAME" rev-parse --show-toplevel)"

        say "GIT=YES"
        say "GIT_ROOT=$TOP"
        say "BRANCH=$(git -C "$PATHNAME" branch --show-current 2>/dev/null || true)"
        say "HEAD=$(git -C "$PATHNAME" rev-parse HEAD 2>/dev/null || true)"

        say "ORIGIN=$(git -C "$PATHNAME" remote get-url origin 2>/dev/null || echo NONE)"
        say "UPSTREAM=$(git -C "$PATHNAME" remote get-url upstream 2>/dev/null || echo NONE)"

        local DIRTY
        DIRTY="$(git -C "$PATHNAME" status --porcelain 2>/dev/null | wc -l)"

        say "DIRTY_FILES=$DIRTY"

    else
        say "GIT=NO"
    fi
}


section "PROJECT XEROX DESTINATION AUDIT"

say "AUDIT_VERSION=1"
say "HOSTNAME=$(hostname 2>/dev/null || echo UNKNOWN)"
say "DATE=$(date -Iseconds 2>/dev/null || date)"
say "USER=$(id -un)"
say "KERNEL=$(uname -srmo 2>/dev/null || uname -a)"


section "SOFTWARE"

for cmd in git node npm yarn java php composer mysql mariadb
do
    if command -v "$cmd" >/dev/null 2>&1; then
        say "$cmd=$(command -v "$cmd")"

        case "$cmd" in
            node)
                say "node_version=$(node --version 2>/dev/null || true)"
                ;;
            npm)
                say "npm_version=$(npm --version 2>/dev/null || true)"
                ;;
            yarn)
                say "yarn_version=$(yarn --version 2>/dev/null || true)"
                ;;
            java)
                say "java_version=$(java -version 2>&1 | head -1 || true)"
                ;;
            php)
                say "php_version=$(php -r 'echo PHP_VERSION;' 2>/dev/null || true)"
                ;;
            composer)
                say "composer_version=$(composer --version 2>/dev/null | head -1 || true)"
                ;;
        esac
    else
        say "$cmd=MISSING"
    fi
done


git_info "NITRO" "$NITRO"
git_info "RENDERER" "$RENDERER"
git_info "EMULATOR" "$EMULATOR"
git_info "CMS" "$CMS"


section "NITRO STRUCTURE"

check_file()
{
    local FILE="$1"

    if [ -f "$NITRO/$FILE" ]; then
        say "FILE_OK=$FILE"
    else
        say "FILE_MISSING=$FILE"
    fi
}

check_dir()
{
    local DIR="$1"

    if [ -d "$NITRO/$DIR" ]; then
        say "DIR_OK=$DIR"
    else
        say "DIR_MISSING=$DIR"
    fi
}

check_file "package.json"
check_file "src/App.tsx"
check_file "src/index.tsx"
check_file "src/components/MainView.tsx"
check_file "src/components/friends/FriendsView.tsx"
check_file "src/components/radio/RadioView.tsx"
check_file "src/components/room/widgets/chat-input/ChatInputView.tsx"
check_file "src/components/avatar-editor/index.ts"

check_dir "src/api"
check_dir "src/common"
check_dir "src/hooks"
check_dir "src/components/youtube"
check_dir "src/components/avatar-editor"


section "EXISTING XEROX/UI2 DETECTION"

if [ -d "$NITRO/src/components/ui2" ]; then
    say "UI2_COMPONENTS=YES"
    say "UI2_FILE_COUNT=$(find "$NITRO/src/components/ui2" -type f | wc -l)"
else
    say "UI2_COMPONENTS=NO"
fi

if [ -f "$NITRO/src/css/ui2/UI2.css" ]; then
    say "UI2_CSS=YES"
else
    say "UI2_CSS=NO"
fi

if grep -Rq \
    --include='*.ts' \
    --include='*.tsx' \
    --include='*.css' \
    'solace-ui2-enabled' \
    "$NITRO/src" 2>/dev/null
then
    say "XEROX_SELECTOR=YES"
else
    say "XEROX_SELECTOR=NO"
fi


section "ENTRY / BRANDING FILE DISCOVERY"

# Names only. We deliberately do not dump file contents because these
# may contain destination-specific URLs, credentials or configuration.

find "$NITRO" \
    -maxdepth 5 \
    \( -path '*/node_modules' -o -path '*/node_modules/*' -o -path '*/dist' -o -path '*/dist/*' \) -prune -o \
    -type f \
    \( \
        -iname '*loading*' -o \
        -iname '*landing*' -o \
        -iname '*login*' -o \
        -iname '*logo*' -o \
        -iname '*brand*' \
    \) \
    2>/dev/null \
    | sed "s#^$NITRO/##" \
    | sort \
    | head -200 \
    | while IFS= read -r file
do
    say "PROTECTED_CANDIDATE=$file"
done


section "ENVIRONMENT FILE DISCOVERY"

for ROOT in "$NITRO" "$RENDERER" "$EMULATOR" "$CMS"
do
    [ -d "$ROOT" ] || continue

    find "$ROOT" \
        -maxdepth 3 \
        \( -path '*/node_modules' -o -path '*/node_modules/*' -o -path '*/vendor' -o -path '*/vendor/*' -o -path '*/dist' -o -path '*/dist/*' \) -prune -o \
        -type f \
        \( \
            -name '.env' -o \
            -name '.env.*' -o \
            -iname '*config*.json' -o \
            -iname '*configuration*.json' \
        \) \
        2>/dev/null \
        | sed "s#^$ROOT/##" \
        | sort \
        | head -100 \
        | while IFS= read -r file
    do
        say "CONFIG_CANDIDATE=$(basename "$ROOT"):$file"
    done
done


section "EMULATOR STRUCTURE"

if [ -d "$EMULATOR" ]; then

    find "$EMULATOR" \
        -maxdepth 3 \
        -type f \
        \( \
            -name 'pom.xml' -o \
            -name 'build.gradle' -o \
            -name 'gradlew' -o \
            -name 'application.properties' \
        \) \
        2>/dev/null \
        | sed "s#^$EMULATOR/##" \
        | sort \
        | while IFS= read -r file
    do
        say "EMULATOR_BUILD_FILE=$file"
    done

    for dir in \
        Emulator \
        src \
        config \
        data
    do
        if [ -d "$EMULATOR/$dir" ]; then
            say "EMULATOR_DIR=$dir"
        fi
    done
fi


section "CMS STRUCTURE"

if [ -d "$CMS" ]; then

    for file in \
        artisan \
        composer.json \
        package.json
    do
        if [ -f "$CMS/$file" ]; then
            say "CMS_FILE=$file"
        fi
    done

    for dir in \
        app \
        resources \
        routes \
        public \
        storage
    do
        if [ -d "$CMS/$dir" ]; then
            say "CMS_DIR=$dir"
        fi
    done
fi


section "DATABASE SAFETY"

say "DATABASE_CONTENTS=NOT_READ"
say "DATABASE_CHANGES=NONE"
say "GAMEDATA_CONTENTS=NOT_READ"
say "GAMEDATA_CHANGES=NONE"


section "AUDIT RESULT"

say "READ_ONLY=YES"
say "FILES_MODIFIED=0"
say "INSTALL_PERFORMED=NO"
say "BUILD_PERFORMED=NO"

say ""
say "Audit saved to:"
say "$OUTPUT"
