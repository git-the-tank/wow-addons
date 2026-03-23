#!/usr/bin/env bash
# watch.sh — Watch for file changes and auto-sync to WoW AddOns folder.
# Usage: ./watch.sh [AddonName]   (omit addon name to watch all)
# Requires: inotify-tools (apt install inotify-tools)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
WOW_ADDONS="/mnt/h/World of Warcraft/_retail_/Interface/addons"
SYNC_SCRIPT="$REPO_DIR/sync.sh"

if [[ ! -d "$WOW_ADDONS" ]]; then
    echo "ERROR: WoW AddOns directory not found at: $WOW_ADDONS"
    exit 1
fi

if ! command -v inotifywait &>/dev/null; then
    echo "ERROR: inotifywait not found. Install with: sudo apt install inotify-tools"
    exit 1
fi

# Build list of directories to watch
WATCH_DIRS=()
if [[ $# -gt 0 ]]; then
    for addon in "$@"; do
        if [[ -d "$REPO_DIR/$addon" ]]; then
            WATCH_DIRS+=("$REPO_DIR/$addon")
        else
            echo "WARNING: Addon directory not found: $addon"
        fi
    done
else
    for dir in "$REPO_DIR"/*/; do
        WATCH_DIRS+=("$dir")
    done
fi

if [[ ${#WATCH_DIRS[@]} -eq 0 ]]; then
    echo "ERROR: No addon directories to watch."
    exit 1
fi

# Initial sync
echo "Running initial sync..."
"$SYNC_SCRIPT" "$@"

echo ""
echo "Watching for changes in: ${WATCH_DIRS[*]}"
echo "Press Ctrl+C to stop."
echo ""

# Debounce: wait 0.5s after last change before syncing
while true; do
    # Wait for any file change
    changed_file=$(inotifywait -r -q \
        --exclude '\.(git|swp|swo)' \
        -e modify,create,delete,move \
        --format '%w%f' \
        "${WATCH_DIRS[@]}")

    # Figure out which addon changed
    addon_dir="${changed_file#"$REPO_DIR/"}"
    addon_name="${addon_dir%%/*}"

    echo "[$(date +%H:%M:%S)] Change detected in $addon_name: $(basename "$changed_file")"

    # Brief pause to batch rapid changes
    sleep 0.3

    "$SYNC_SCRIPT" "$addon_name"
    echo ""
done
