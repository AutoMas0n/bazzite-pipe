#!/usr/bin/env bash
# Script: ersc-hosts-helper.sh
# Purpose: Minimal helper for hosts file modifications (for sudoers)
# Usage: ersc-hosts-helper.sh [block|unblock]
# 
# Add to sudoers with:
#   %wheel ALL=(ALL) NOPASSWD: /home/jesse/GitHub/bazzite-pipe/scripts/gaming/ersc-hosts-helper.sh

set -euo pipefail

readonly HOSTS_FILE="/etc/hosts"
readonly GITHUB_DOMAINS=(
    "github.com"
    "api.github.com"
    "raw.githubusercontent.com"
    "cdn-185-199-108-133.github.com"
    "lb-140-82-113-4-iad.github.com"
)

case "${1:-}" in
    block)
        for domain in "${GITHUB_DOMAINS[@]}"; do
            if ! grep -q "${domain}.*ERSC" "${HOSTS_FILE}" 2>/dev/null; then
                echo "127.0.0.1 ${domain} # ERSC" >> "${HOSTS_FILE}"
            fi
        done
        ;;
    unblock)
        for domain in "${GITHUB_DOMAINS[@]}"; do
            sed -i "/${domain}.*ERSC/d" "${HOSTS_FILE}" 2>/dev/null || true
        done
        ;;
    *)
        echo "Usage: $0 [block|unblock]"
        exit 1
        ;;
esac
