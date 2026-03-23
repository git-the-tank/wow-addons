#!/usr/bin/env bash
# sync.sh — Copy all addon directories to the WoW AddOns folder.
# Usage: ./sync.sh [AddonName]   (omit addon name to sync all)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
WOW_ADDONS="/mnt/h/World of Warcraft/_retail_/Interface/addons"

if [[ ! -d "$WOW_ADDONS" ]]; then
    echo "ERROR: WoW AddOns directory not found at: $WOW_ADDONS"
    echo "Is the H: drive mounted?"
    exit 1
fi

sync_addon() {
    local addon="$1"
    if [[ ! -d "$REPO_DIR/$addon" ]]; then
        echo "ERROR: Addon directory not found: $addon"
        return 1
    fi
    echo "Syncing $addon ..."
    rsync -rv --delete --checksum \
        --no-perms --no-group --no-owner --no-times --inplace \
        "$REPO_DIR/$addon/" \
        "$WOW_ADDONS/$addon/"
    echo "  ✓ $addon synced"
}

if [[ $# -gt 0 ]]; then
    # Sync specific addon(s)
    for addon in "$@"; do
        sync_addon "$addon"
    done
else
    # Sync all addon directories (skip dotfiles, scripts, and non-directories)
    for dir in "$REPO_DIR"/*/; do
        addon="$(basename "$dir")"
        sync_addon "$addon"
    done
fi

echo "Done."
