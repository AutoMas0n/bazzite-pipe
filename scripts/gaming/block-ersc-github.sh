#!/usr/bin/env bash
set -euo pipefail

# Script: block-ersc-github.sh
# Purpose: Block ERSC launcher from checking GitHub for updates
# Usage: ./block-ersc-github.sh [enable|disable|status|launch]

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HOSTS_FILE="/etc/hosts"
readonly HOSTS_BACKUP="/etc/hosts.bak.ersc"
readonly GAME_PROCESS="eldenring.exe"
readonly POLL_INTERVAL=1
readonly MAX_WAIT=30

# Track if we're in launch mode for cleanup
LAUNCH_MODE_ACTIVE=false

cleanup() {
    if [ "$LAUNCH_MODE_ACTIVE" = true ]; then
        echo ""
        echo "Interrupted! Restoring GitHub access..."
        disable_blocking
    fi
}

trap cleanup EXIT INT TERM

# GitHub IPs/domains identified from packet capture
readonly GITHUB_DOMAINS=(
    "github.com"
    "api.github.com"
    "raw.githubusercontent.com"
    "cdn-185-199-108-133.github.com"
    "lb-140-82-113-4-iad.github.com"
)

readonly GITHUB_IPS=(
    "185.199.108.133"
    "140.82.113.4"
)

show_usage() {
    cat << EOF
ERSC GitHub Update Blocker
==========================

This script blocks ERSC launcher from checking GitHub for updates
by redirecting GitHub domains to localhost.

Usage: $0 <command>

Commands:
    enable      Block GitHub update checks
    disable     Remove GitHub blocks
    status      Show current blocking status
    launch      Block, wait for eldenring.exe to start, then unblock

Examples:
    $0 enable   # Block updates
    $0 disable  # Allow updates
    $0 status   # Check status
    $0 launch   # Auto-block during launcher, unblock when game starts

Note: Requires sudo for hosts file modifications
EOF
}

backup_hosts() {
    if [ ! -f "${HOSTS_BACKUP}" ]; then
        sudo cp "${HOSTS_FILE}" "${HOSTS_BACKUP}"
        echo "✓ Created backup: ${HOSTS_BACKUP}"
    fi
}

enable_blocking() {
    echo "Enabling ERSC GitHub update blocking..."
    echo ""
    
    backup_hosts
    
    local blocked=0
    for domain in "${GITHUB_DOMAINS[@]}"; do
        if grep -q "^127.0.0.1[[:space:]].*${domain}.*ERSC" "${HOSTS_FILE}" 2>/dev/null; then
            echo "  Already blocked: ${domain}"
        else
            echo "127.0.0.1 ${domain} # ERSC update block" | sudo tee -a "${HOSTS_FILE}" > /dev/null
            echo "  ✓ Blocked: ${domain}"
            blocked=$((blocked + 1))
        fi
    done
    
    echo ""
    if [ $blocked -gt 0 ]; then
        echo "✓ Blocked ${blocked} new domain(s)"
        echo ""
        echo "GitHub update checks are now blocked for ERSC launcher"
        echo "You can now launch the game without update check failures"
    else
        echo "All domains already blocked"
    fi
    
    echo ""
    echo "To restore GitHub access, run: $0 disable"
}

disable_blocking() {
    echo "Disabling ERSC GitHub update blocking..."
    echo ""
    
    local removed=0
    for domain in "${GITHUB_DOMAINS[@]}"; do
        if grep -q "${domain}.*ERSC" "${HOSTS_FILE}" 2>/dev/null; then
            sudo sed -i "/${domain}.*ERSC update block/d" "${HOSTS_FILE}"
            echo "  ✓ Unblocked: ${domain}"
            removed=$((removed + 1))
        fi
    done
    
    echo ""
    if [ $removed -gt 0 ]; then
        echo "✓ Removed ${removed} block(s)"
        echo ""
        echo "GitHub update checks are now enabled"
    else
        echo "No blocks were active"
    fi
}

show_status() {
    echo "ERSC GitHub Update Blocking Status"
    echo "==================================="
    echo ""
    
    local blocked=0
    local total=${#GITHUB_DOMAINS[@]}
    
    for domain in "${GITHUB_DOMAINS[@]}"; do
        if grep -q "${domain}.*ERSC" "${HOSTS_FILE}" 2>/dev/null; then
            echo "  ✓ BLOCKED: ${domain}"
            blocked=$((blocked + 1))
        else
            echo "  ✗ ALLOWED: ${domain}"
        fi
    done
    
    echo ""
    echo "Status: ${blocked}/${total} domains blocked"
    
    if [ $blocked -gt 0 ]; then
        echo ""
        echo "GitHub updates are BLOCKED"
        echo "Game should launch without update check failures"
        echo ""
        echo "To allow updates: $0 disable"
    else
        echo ""
        echo "GitHub updates are ALLOWED"
        echo "Launcher will check for updates (may fail)"
        echo ""
        echo "To block updates: $0 enable"
    fi
    
    if [ -f "${HOSTS_BACKUP}" ]; then
        echo ""
        echo "Backup available: ${HOSTS_BACKUP}"
    fi
}

wait_for_game() {
    local waited=0
    echo "Waiting for ${GAME_PROCESS} to start (max ${MAX_WAIT}s)..."
    
    while [ $waited -lt $MAX_WAIT ]; do
        # Check if game process is running (by name only, portable)
        if pgrep -fi "${GAME_PROCESS}" > /dev/null 2>&1; then
            echo "✓ ${GAME_PROCESS} detected!"
            return 0
        fi
        sleep $POLL_INTERVAL
        waited=$((waited + POLL_INTERVAL))
        # Progress indicator every 5 seconds
        if [ $((waited % 5)) -eq 0 ]; then
            echo "  Still waiting... (${waited}s)"
        fi
    done
    
    echo "✗ Timeout: ${GAME_PROCESS} did not start within ${MAX_WAIT}s"
    return 1
}

launch_mode() {
    LAUNCH_MODE_ACTIVE=true
    
    echo "ERSC Launch Mode"
    echo "================"
    echo ""
    echo "This will:"
    echo "  1. Block GitHub traffic"
    echo "  2. Wait for ${GAME_PROCESS} to start"
    echo "  3. Unblock GitHub immediately after"
    echo ""
    echo "Press Ctrl+C to abort and restore GitHub access."
    echo ""
    
    # Step 1: Enable blocking
    enable_blocking
    echo ""
    
    # Step 2: Wait for game
    echo "---"
    if wait_for_game; then
        echo ""
        echo "---"
        # Step 3: Disable blocking
        disable_blocking
        LAUNCH_MODE_ACTIVE=false
        echo ""
        echo "✓ Launch sequence complete! GitHub access restored."
    else
        # Timeout - cleanup trap will handle restore
        echo ""
        echo "---"
        echo "Timeout reached. Restoring GitHub access..."
        # Let trap handle cleanup
    fi
}

# Main logic
case "${1:-}" in
    enable)
        enable_blocking
        ;;
    disable)
        disable_blocking
        ;;
    status)
        show_status
        ;;
    launch)
        launch_mode
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
