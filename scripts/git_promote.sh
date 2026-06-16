#!/usr/bin/env bash
# git_promote.sh — Promote the dev branch to main ("mark current dev as stable").
#
# Fast-forwards origin/main up to origin/dev on the remote. Does NOT touch the
# working tree or restart Klipper — it only advances the stable branch pointer.
# Run this after you've tested a change on dev (CONFIG_SWITCH_DEV + BACKUP_CONFIG),
# then use CONFIG_SWITCH_MAIN to bring the printer back onto the now-updated main.
#
# Lives at ~/printer_data/scripts/git_promote.sh, invoked by the PROMOTE_CONFIG macro.

set -euo pipefail

cd "$HOME/printer_data" || { echo "[git_promote] ERROR: cannot cd to ~/printer_data" >&2; exit 1; }

log()        { echo "[git_promote] $*"; }
error_exit() { echo "[git_promote] ERROR: $*" >&2; exit 1; }

log "Fetching latest refs..."
git fetch origin --quiet || error_exit "git fetch failed — check SSH auth/network"

DEV=$(git rev-parse --short origin/dev)
MAIN=$(git rev-parse --short origin/main)

if [[ "$DEV" == "$MAIN" ]]; then
    log "Nothing to promote — main and dev are already identical ($MAIN)"
    exit 0
fi

# Only allow a clean fast-forward: main must be an ancestor of dev
if git merge-base --is-ancestor origin/main origin/dev; then
    log "Promoting origin/dev ($DEV) -> origin/main ($MAIN)..."
    git push origin "origin/dev:refs/heads/main" \
        || error_exit "push to main failed"
    log "Promoted. main is now at $DEV"
else
    error_exit "main and dev have diverged — main is not an ancestor of dev. Resolve manually before promoting."
fi
exit 0
