#!/usr/bin/env bash
# Script: ersc-prelaunch.sh
# Purpose: Lutris prelaunch script - blocks GitHub, waits for game, unblocks
# Usage: Set as prelaunch_command in Lutris with prelaunch_wait: false

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HELPER="${SCRIPT_DIR}/ersc-hosts-helper.sh"
readonly GAME_PROCESS="eldenring.exe"
readonly POLL_INTERVAL=1
readonly MAX_WAIT=60
readonly LOG="/tmp/ersc-prelaunch.log"

exec > "${LOG}" 2>&1

echo "[$(date)] ERSC prelaunch starting..."

# Cleanup on exit
cleanup() {
    echo "[$(date)] Cleanup: unblocking GitHub..."
    sudo "${HELPER}" unblock 2>/dev/null || true
    echo "[$(date)] GitHub unblocked."
}
trap cleanup EXIT INT TERM

# Block GitHub
echo "[$(date)] Blocking GitHub..."
sudo "${HELPER}" block
echo "[$(date)] GitHub blocked."

# Wait for game process
echo "[$(date)] Waiting for ${GAME_PROCESS}..."
waited=0
while [ $waited -lt $MAX_WAIT ]; do
    if pgrep -fi "${GAME_PROCESS}" > /dev/null 2>&1; then
        echo "[$(date)] ${GAME_PROCESS} detected!"
        sleep 2  # Brief delay to ensure game is initialized
        exit 0   # Cleanup trap will unblock
    fi
    sleep $POLL_INTERVAL
    waited=$((waited + POLL_INTERVAL))
done

echo "[$(date)] Timeout - game not detected within ${MAX_WAIT}s"
exit 0  # Cleanup trap will unblock
