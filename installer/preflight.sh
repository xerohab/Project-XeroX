#!/usr/bin/env bash

set -euo pipefail

NITRO="${1:-/var/www/Nitro-V3}"

echo "============================================================"
echo "PROJECT XEROX — PREFLIGHT"
echo "============================================================"
echo
echo "Nitro path: $NITRO"
echo

FAIL=0

require_file()
{
    if [ ! -f "$NITRO/$1" ]; then
        echo "MISSING FILE: $1"
        FAIL=1
    else
        echo "OK FILE: $1"
    fi
}

require_dir()
{
    if [ ! -d "$NITRO/$1" ]; then
        echo "MISSING DIR:  $1"
        FAIL=1
    else
        echo "OK DIR:  $1"
    fi
}

echo "===== CORE NITRO ====="

require_file "package.json"
require_file "src/App.tsx"
require_file "src/index.tsx"
require_file "src/components/MainView.tsx"

echo
echo "===== UI INTEGRATION TARGETS ====="

require_file "src/components/friends/FriendsView.tsx"
require_file "src/components/radio/RadioView.tsx"
require_file "src/components/room/widgets/chat-input/ChatInputView.tsx"
require_file "src/components/avatar-editor/index.ts"

echo
echo "===== HOST DEPENDENCIES ====="

require_dir "src/api"
require_dir "src/common"
require_dir "src/hooks"

if [ -f "$NITRO/src/components/youtube/YoutubeReactPlayer.ts" ] || \
   [ -f "$NITRO/src/components/youtube/YoutubeReactPlayer.tsx" ]; then
    echo "OK FILE: src/components/youtube/YoutubeReactPlayer.(ts|tsx)"
else
    echo "MISSING FILE: src/components/youtube/YoutubeReactPlayer.(ts|tsx)"
    FAIL=1
fi

require_file "src/components/avatar-editor/AvatarEditorIcon.tsx"
require_file "src/components/avatar-editor/AvatarEditorFigurePreviewView.tsx"
require_file "src/components/avatar-editor/AvatarEditorPetView.tsx"
require_file "src/components/avatar-editor/AvatarEditorWardrobeView.tsx"

echo
echo "===== REQUIRED ASSETS ====="

require_file "src/assets/images/avatareditor/air/main-generic.png"
require_file "src/assets/images/avatareditor/air/main-head.png"
require_file "src/assets/images/avatareditor/air/main-legs.png"
require_file "src/assets/images/avatareditor/air/main-misc.png"
require_file "src/assets/images/avatareditor/air/main-torso.png"

require_file "src/assets/images/wardrobe/pets.png"

require_file "src/assets/images/hc-center/hc_logo.gif"
require_file "src/assets/images/purse/air/credits.png"
require_file "src/assets/images/purse/air/diamond.png"
require_file "src/assets/images/purse/air/duckets.png"

echo
echo "============================================================"

if [ "$FAIL" -ne 0 ]; then
    echo "PREFLIGHT FAILED"
    echo
    echo "Project XeroX has NOT modified anything."
    echo "The destination Nitro is missing one or more required dependencies."
    exit 1
fi

echo "PREFLIGHT PASSED"
echo
echo "Destination appears compatible with Project XeroX."
echo "Nothing was modified."
echo "============================================================"
