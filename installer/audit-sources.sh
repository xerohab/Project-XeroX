#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${1:-/var/www/Project-XeroX/manifest/solace-source-audit.txt}"

declare -A REPOS=(
    [nitro]="/var/www/Nitro-V3"
    [renderer]="/var/www/Nitro_Render_V3"
    [emulator]="/var/www/emulator"
    [cms]="/var/www/atomcms"
)

: > "$OUTPUT"

audit_repo()
{
    local name="$1"
    local path="$2"

    {
        echo
        echo "================================================================"
        echo "PROJECT: $name"
        echo "PATH: $path"
        echo "================================================================"

        if [ ! -d "$path/.git" ]; then
            echo "ERROR: not a Git repository"
            return
        fi

        cd "$path"

        echo
        echo "BRANCH:"
        git branch --show-current

        echo
        echo "HEAD:"
        git rev-parse HEAD

        echo
        echo "HEAD SHORT:"
        git rev-parse --short HEAD

        echo
        echo "REMOTES:"
        git remote -v

        echo
        echo "STATUS:"
        git status --short --branch

        echo
        echo "LATEST COMMIT:"
        git log -1 --format='%H%n%ad%n%s' --date=iso-strict

        echo
        echo "TRACKING BRANCH:"
        git rev-parse \
            --abbrev-ref \
            --symbolic-full-name '@{u}' \
            2>/dev/null || echo "NONE"

        echo
        echo "UPSTREAM REMOTE:"
        git remote get-url upstream 2>/dev/null || echo "NONE"

        echo
        echo "ORIGIN REMOTE:"
        git remote get-url origin 2>/dev/null || echo "NONE"

        if git remote get-url upstream >/dev/null 2>&1; then
            echo
            echo "FETCH UPSTREAM:"
            git fetch upstream --prune

            DEFAULT_UPSTREAM=""

            if git show-ref --verify --quiet refs/remotes/upstream/main; then
                DEFAULT_UPSTREAM="upstream/main"
            elif git show-ref --verify --quiet refs/remotes/upstream/master; then
                DEFAULT_UPSTREAM="upstream/master"
            elif git show-ref --verify --quiet refs/remotes/upstream/Dev; then
                DEFAULT_UPSTREAM="upstream/Dev"
            fi

            echo
            echo "UPSTREAM BASE:"
            echo "${DEFAULT_UPSTREAM:-UNKNOWN}"

            if [ -n "$DEFAULT_UPSTREAM" ]; then

                echo
                echo "AHEAD / BEHIND:"
                git rev-list \
                    --left-right \
                    --count \
                    "$DEFAULT_UPSTREAM...HEAD"

                echo
                echo "MERGE BASE:"
                git merge-base "$DEFAULT_UPSTREAM" HEAD

                echo
                echo "FILES DIFFERENT FROM UPSTREAM:"
                git diff \
                    --name-status \
                    "$DEFAULT_UPSTREAM...HEAD"

                echo
                echo "DIFF STAT:"
                git diff \
                    --stat \
                    "$DEFAULT_UPSTREAM...HEAD"

                echo
                echo "COMMITS NOT IN UPSTREAM:"
                git log \
                    --oneline \
                    --decorate \
                    "$DEFAULT_UPSTREAM..HEAD"
            fi
        fi

        echo
        echo "END PROJECT: $name"
    } >> "$OUTPUT" 2>&1
}

audit_repo nitro "/var/www/Nitro-V3"
audit_repo renderer "/var/www/Nitro_Render_V3"
audit_repo emulator "/var/www/emulator"
audit_repo cms "/var/www/atomcms"

echo
echo "Audit written to:"
echo "$OUTPUT"
