#!/usr/bin/env bash
set -euo pipefail

# Script: ersc-launcher.sh
# Purpose: One-click ERSC launcher with automatic GitHub blocking
# Usage: Set this as the executable in Lutris instead of ersc_launcher.exe

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HELPER="${SCRIPT_DIR}/ersc-hosts-helper.sh"
readonly GAME_PROCESS="eldenring.exe"
readonly POLL_INTERVAL=1
readonly MAX_WAIT=60

# Ensure cleanup on any exit
cleanup() {
    echo "[ERSC] Restoring GitHub access..."
    sudo "${HELPER}" unblock 2>/dev/null || true
    echo "[ERSC] GitHub access restored."
}
trap cleanup EXIT INT TERM

enable_blocking() {
    echo "[ERSC] Blocking GitHub for launcher..."
    sudo "${HELPER}" block
    echo "[ERSC] GitHub blocked."
}

wait_for_game() {
    local waited=0
    echo "[ERSC] Waiting for ${GAME_PROCESS}..."
    
    while [ $waited -lt $MAX_WAIT ]; do
        if pgrep -fi "${GAME_PROCESS}" > /dev/null 2>&1; then
            echo "[ERSC] Game detected!"
            return 0
        fi
        sleep $POLL_INTERVAL
        waited=$((waited + POLL_INTERVAL))
    done
    
    echo "[ERSC] Timeout waiting for game."
    return 1
}

main() {
    echo "[ERSC] === ERSC Launcher Wrapper ==="
    
    # Step 1: Block GitHub
    enable_blocking
    
    # Step 2: Launch the actual ERSC launcher
    # Pass through all arguments (Lutris passes Wine/Proton args)
    echo "[ERSC] Starting ERSC launcher..."
    "$@" &
    local launcher_pid=$!
    
    # Step 3: Wait for the actual game to start
    if wait_for_game; then
        echo "[ERSC] Game running. Unblocking GitHub..."
        # Cleanup will run via trap
    else
        echo "[ERSC] Game didn't start, but continuing anyway..."
    fi
    
    # Wait for launcher to finish (it exits after game starts)
    wait $launcher_pid 2>/dev/null || true
    
    echo "[ERSC] Launcher wrapper complete."
}

main "$@"
