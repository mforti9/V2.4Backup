#!/usr/bin/env bash
# version_badge.sh — Sync active git branch + short commit hash to Mainsail's top-left
# header title (general.printername), accent color (uiSettings.primary), and M117 status.
#
# Modes:
#   version_badge.sh                  — Sync badge from current working tree HEAD
#   version_badge.sh --deploy [br]    — Fetch origin, pre-update badge to target branch, then run git_deploy.sh
#   version_badge.sh --diag           — Print read-only Pi system/kernel health diagnostics (dmesg, journalctl, wlan0, disk)
{
set -euo pipefail

PRINTER_DATA_DIR="$HOME/printer_data"
MOONRAKER_URL="http://localhost:7125"
BASE_NAME="V2.4"
COLOR_DEV="#FB8C00"   # Amber/orange accent when running on 'dev'
COLOR_MAIN="#2196F3"  # Default Mainsail blue accent when running on 'main'

cd "$PRINTER_DATA_DIR" || { echo "[version_badge] ERROR: cannot cd to $PRINTER_DATA_DIR" >&2; exit 1; }

post_db_item() {
    local key="$1"
    local val="$2"
    curl -sS --max-time 5 -X POST "$MOONRAKER_URL/server/database/item" \
        -H "Content-Type: application/json" \
        -d "{\"namespace\":\"mainsail\",\"key\":\"$key\",\"value\":\"$val\"}" >/dev/null || true
}

apply_badge() {
    local branch="$1"
    local sha="$2"
    local dirty_mark="${3:-}"
    local branch_upper
    branch_upper=$(echo "$branch" | tr '[:lower:]' '[:upper:]')

    local title="${BASE_NAME} [${branch_upper} • ${sha}${dirty_mark}]"
    local color="$COLOR_MAIN"
    if [[ "$branch" != "main" ]]; then
        color="$COLOR_DEV"
    fi

    post_db_item "general.printername" "$title"
    post_db_item "uiSettings.primary" "$color"
    echo "[version_badge] Mainsail header set to: $title"
}

if [[ "${1:-}" == "--diag" ]]; then
    echo "=== DISK & MEMORY ==="
    df -h / /boot/firmware 2>/dev/null || df -h /
    free -m
    swapon --show || true
    echo "=== WIFI POWER SAVE & SIGNAL ==="
    /sbin/iw dev wlan0 get power_save 2>/dev/null || true
    /sbin/iw dev wlan0 link 2>/dev/null || true
    echo "=== DMESG ERRORS (MMC/SD/EXT4/OOM/WIFI/USB) ==="
    dmesg -T 2>/dev/null | grep -iE "mmc|ext4|i/o error|corrupt|readonly|read-only|oom|out of memory|killed process|brcmfmac|under-voltage|throttl" | tail -n 35 || true
    echo "=== PREVIOUS BOOT CRITICAL LOGS ==="
    journalctl -b -1 -p err --no-pager -n 30 2>/dev/null || true
    echo "=== CURRENT BOOT CRITICAL LOGS ==="
    journalctl -b 0 -p err --no-pager -n 30 2>/dev/null || true
    exit 0
fi

if [[ "${1:-}" == "--deploy" ]]; then
    TARGET_BRANCH="${2:-}"
    if [[ -z "$TARGET_BRANCH" ]]; then
        TARGET_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    fi
    # Fetch first so we only pre-update the badge if origin is reachable; pre-updating
    # before FIRMWARE_RESTART ensures Mainsail loads the new badge immediately on reconnect
    # (even when rolling back to an older 'main' commit without version_badge.cfg).
    if git fetch origin --quiet 2>/dev/null; then
        TARGET_SHA=$(git rev-parse --short "origin/$TARGET_BRANCH" 2>/dev/null || echo "unknown")
        apply_badge "$TARGET_BRANCH" "$TARGET_SHA" ""
    fi
    exec bash "$PRINTER_DATA_DIR/scripts/git_deploy.sh" ${2:+"$2"}
fi

# Default mode: inspect current checked-out HEAD + dirty working tree state
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DIRTY=""
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    DIRTY="*"
fi

apply_badge "$BRANCH" "$SHA" "$DIRTY"

exit 0
}
