#!/usr/bin/env bash
# backup-wtf.sh — Git commit & push the WoW WTF folder (saved variables, config, etc.)
# Usage: ./backup-wtf.sh [message]
# This is a separate repo from the addons monorepo — purely a convenience backup.

set -euo pipefail

WTF_DIR="/mnt/h/World of Warcraft/_retail_/WTF"

if [[ ! -d "$WTF_DIR/.git" ]]; then
    echo "ERROR: No git repo found at: $WTF_DIR"
    exit 1
fi

cd "$WTF_DIR"

# Check if there are any changes
if git diff --quiet HEAD 2>/dev/null && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
    echo "No changes to back up."
    exit 0
fi

# Stage everything
git add -A

# Build commit message
if [[ $# -gt 0 ]]; then
    msg="$*"
else
    msg="Backup on $(date)"
fi

# Show summary
echo "=== WTF Backup ==="
echo ""
git diff --cached --stat
echo ""

# Commit and push
git commit -m "$msg"

if git remote get-url origin &>/dev/null; then
    echo ""
    echo "Pushing to origin..."
    git push
fi

echo ""
echo "Done. WTF backed up."
