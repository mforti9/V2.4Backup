#!/usr/bin/env bash
# git_deploy.sh — Pull latest Klipper config from GitHub and restart Klipper
#
# Usage:
#   git_deploy.sh              — pull current branch, then firmware_restart
#   git_deploy.sh dev          — switch to dev branch, pull, then firmware_restart
#   git_deploy.sh main         — switch to main branch, pull, then firmware_restart
#   git_deploy.sh --status     — print branch + last commit, no pull, no restart
#
# Requirements:
#   - git remote 'origin' configured as SSH: git@github.com:mforti9/V2.4Backup.git
#   - SSH key at ~/.ssh/id_ed25519_voron_deploy added to mforti9 GitHub account
#   - Moonraker running on localhost:7125
#   - Script lives at ~/printer_data/scripts/git_deploy.sh

set -euo pipefail

PRINTER_DATA_DIR="$HOME/printer_data"
MOONRAKER_URL="http://localhost:7125"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log()        { echo "[git_deploy] $*"; }
error_exit() { echo "[git_deploy] ERROR: $*" >&2; exit 1; }

cd "$PRINTER_DATA_DIR" || error_exit "Cannot cd to $PRINTER_DATA_DIR"

# ── Status-only mode (no pull, no restart) ─────────────────────────────────────
if [[ "${1:-}" == "--status" ]]; then
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    COMMIT=$(git log -1 --format="%h  %s  (%ci)" 2>/dev/null || echo "no commits")
    log "Branch : $BRANCH"
    log "Commit : $COMMIT"
    exit 0
fi

# ── Determine target branch ────────────────────────────────────────────────────
TARGET_BRANCH="${1:-}"
if [[ -z "$TARGET_BRANCH" ]]; then
    TARGET_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) \
        || error_exit "Could not determine current branch"
    log "No branch specified — using current: $TARGET_BRANCH"
else
    log "Target branch: $TARGET_BRANCH"
fi

# ── Stash any local changes (e.g. edits made via Mainsail config editor) ───────
# --include-untracked captures new files created by Mainsail before git knows them
STASH_OUT=$(git stash push --include-untracked -m "auto-stash before deploy at $TIMESTAMP" 2>&1)
if echo "$STASH_OUT" | grep -q "No local changes"; then
    log "Working tree clean — no stash needed"
else
    log "Local changes stashed: auto-stash before deploy at $TIMESTAMP"
fi

# ── Fetch latest from remote ───────────────────────────────────────────────────
log "Fetching from origin..."
git fetch origin \
    || error_exit "git fetch failed — check SSH key auth (run: ssh -T git@github.com) and network"

# ── Switch branch if needed ────────────────────────────────────────────────────
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]]; then
    log "Switching $CURRENT_BRANCH → $TARGET_BRANCH..."
    git checkout "$TARGET_BRANCH" \
        || error_exit "git checkout $TARGET_BRANCH failed — does the branch exist on origin?"
fi

# ── Pull latest ────────────────────────────────────────────────────────────────
log "Pulling origin/$TARGET_BRANCH..."
git pull origin "$TARGET_BRANCH" \
    || error_exit "git pull failed"

# ── Report result ──────────────────────────────────────────────────────────────
FINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
FINAL_COMMIT=$(git log -1 --format="%h  %s  (%ci)")
log "Deploy complete"
log "Branch : $FINAL_BRANCH"
log "Commit : $FINAL_COMMIT"

# ── Trigger firmware restart via Moonraker API ─────────────────────────────────
# Only reached if all git operations above succeeded (set -e enforced)
log "Triggering FIRMWARE_RESTART via Moonraker..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$MOONRAKER_URL/printer/firmware_restart")

if [[ "$HTTP_STATUS" == "200" ]]; then
    log "Firmware restart triggered (HTTP $HTTP_STATUS)"
elif [[ "$HTTP_STATUS" == "000" ]]; then
    # Connection closed while Klipper was already restarting — this is normal
    log "Connection closed during restart — this is expected, restart succeeded"
else
    log "WARNING: Moonraker returned HTTP $HTTP_STATUS"
    log "You may need to restart Klipper manually from Mainsail"
fi

exit 0
