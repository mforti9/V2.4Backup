#!/usr/bin/env bash
# git_backup.sh — Commit the current Klipper config and push it to GitHub.
#
# Pushes to the CURRENTLY checked-out branch (normally main, or dev when staging).
# Does NOT restart Klipper — a backup never changes the running config.
#
# Usage:
#   git_backup.sh                 — commit with an auto timestamp message
#   git_backup.sh "fixed PA"      — commit with a custom message (timestamp appended)
#
# Lives at ~/printer_data/scripts/git_backup.sh, invoked by the BACKUP_CONFIG macro.

set -euo pipefail

PRINTER_DATA_DIR="$HOME/printer_data"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log()        { echo "[git_backup] $*"; }
error_exit() { echo "[git_backup] ERROR: $*" >&2; exit 1; }

cd "$PRINTER_DATA_DIR" || error_exit "Cannot cd to $PRINTER_DATA_DIR"

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || error_exit "Not a git repo"

# Build commit message: custom text (with timestamp appended) or a plain timestamp
CUSTOM="${1:-}"
if [[ -n "$CUSTOM" ]]; then
    MESSAGE="$CUSTOM ($TIMESTAMP)"
else
    MESSAGE="Mainsail backup $TIMESTAMP"
fi

git add -A

if git diff --cached --quiet; then
    log "No changes to back up — working tree already clean on '$BRANCH'"
    exit 0
fi

log "Committing changes on '$BRANCH'..."
git commit -q -m "$MESSAGE"

log "Pushing to origin/$BRANCH..."
git push origin "$BRANCH" \
    || error_exit "push failed — check SSH key auth (ssh -T git@github.com) and network"

log "Backup complete: $(git log -1 --format='%h  %s')"
exit 0
