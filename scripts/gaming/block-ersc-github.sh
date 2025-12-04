#!/usr/bin/env bash
set -euo pipefail

# Script: block-ersc-github.sh
# Purpose: Block ERSC launcher from checking GitHub for updates
# Usage: ./block-ersc-github.sh [enable|disable|status]

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HOSTS_FILE="/etc/hosts"
readonly HOSTS_BACKUP="/etc/hosts.bak.ersc"

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

Examples:
    $0 enable   # Block updates
    $0 disable  # Allow updates
    $0 status   # Check status

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
    *)
        show_usage
        exit 1
        ;;
esac
