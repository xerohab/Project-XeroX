#!/usr/bin/env bash

xerox_build_nitro()
{
    local root="$1"

    [ -d "$root" ] || {
        xerox_die "Nitro root missing: $root"
        return 1
    }

    command -v yarn >/dev/null 2>&1 || {
        xerox_die "yarn unavailable"
        return 1
    }

    (
        cd "$root"

        echo "NITRO: typecheck"
        yarn typecheck

        echo "NITRO: build"
        yarn build
    )
}

xerox_build_renderer()
{
    local root="$1"

    [ -d "$root" ] || {
        xerox_die "Renderer root missing: $root"
        return 1
    }

    command -v yarn >/dev/null 2>&1 || {
        xerox_die "yarn unavailable"
        return 1
    }

    (
        cd "$root"

        echo "RENDERER: build"
        yarn build
    )
}

xerox_build_emulator()
{
    local root="$1"

    local project="$root/Emulator"

    [ -d "$project" ] || {
        xerox_die "Emulator project missing: $project"
        return 1
    }

    if [ -x "$root/gradlew" ]; then
        (
            cd "$root"
            ./gradlew build
        )
        return
    fi

    if [ -x "$project/gradlew" ]; then
        (
            cd "$project"
            ./gradlew build
        )
        return
    fi

    if [ -f "$project/pom.xml" ] && command -v mvn >/dev/null 2>&1; then
        (
            cd "$project"
            mvn package
        )
        return
    fi

    xerox_die "Unable to identify approved Emulator build command"
    return 1
}
