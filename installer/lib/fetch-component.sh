#!/usr/bin/env bash
set -euo pipefail

NAME="${1:-}"
REPO="${2:-}"
BRANCH="${3:-}"
DEST="${4:-}"

if [ -z "$NAME" ] || [ -z "$REPO" ] || [ -z "$BRANCH" ] || [ -z "$DEST" ]; then
    echo "Usage:"
    echo "  fetch-component.sh NAME REPO BRANCH DEST"
    exit 1
fi

echo "Fetching component: $NAME"
echo "Repository: $REPO"
echo "Branch:     $BRANCH"
echo "Staging:    $DEST"

rm -rf "$DEST"

git clone \
    --depth 1 \
    --branch "$BRANCH" \
    "$REPO" \
    "$DEST"

echo
echo "Fetched:"
git -C "$DEST" rev-parse HEAD
