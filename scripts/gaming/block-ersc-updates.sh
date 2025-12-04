#!/usr/bin/env bash
set -euo pipefail

# Script: block-ersc-updates.sh
# Purpose: Block network connections to ERSC update servers
# Usage: ./block-ersc-updates.sh [add|remove|list] [host:port]

readonly HOSTS_FILE="/etc/hosts"
readonly HOSTS_BACKUP="/etc/hosts.bak.ersc"

show_usage() {
    cat << EOF
Usage: $0 <command> [arguments]

Commands:
    add <host>      Add host to block list (redirects to 127.0.0.1)
    remove <host>   Remove host from block list
    list            Show currently blocked hosts
    firewall <ip:port>  Block specific IP:port using firewall

Examples:
    $0 add seamlesscoopupdates.example.com
    $0 firewall 192.168.1.100:443
    $0 list
    $0 remove seamlesscoopupdates.example.com

Note: Requires sudo for hosts file and firewall modifications
EOF
}

add_host_block() {
    local host="$1"
    
    # Backup hosts file if not already backed up
    if [ ! -f "${HOSTS_BACKUP}" ]; then
        sudo cp "${HOSTS_FILE}" "${HOSTS_BACKUP}"
        echo "Created backup: ${HOSTS_BACKUP}"
    fi
    
    # Check if already blocked
    if grep -q "^127.0.0.1[[:space:]].*${host}" "${HOSTS_FILE}"; then
        echo "Host ${host} is already blocked"
        return 0
    fi
    
    # Add block entry
    echo "127.0.0.1 ${host} # ERSC update block" | sudo tee -a "${HOSTS_FILE}" > /dev/null
    echo "✓ Blocked: ${host} -> 127.0.0.1"
}

remove_host_block() {
    local host="$1"
    
    if ! grep -q "${host}" "${HOSTS_FILE}"; then
        echo "Host ${host} is not in block list"
        return 0
    fi
    
    sudo sed -i "/${host}.*ERSC update block/d" "${HOSTS_FILE}"
    echo "✓ Removed block: ${host}"
}

list_blocks() {
    echo "Currently blocked ERSC update hosts:"
    echo "===================================="
    grep "ERSC update block" "${HOSTS_FILE}" 2>/dev/null || echo "No hosts currently blocked"
    echo ""
    echo "Firewall rules:"
    echo "==============="
    sudo iptables -L OUTPUT -n -v 2>/dev/null | grep "ERSC" || echo "No firewall rules set"
}

add_firewall_block() {
    local target="$1"
    local ip="${target%:*}"
    local port="${target#*:}"
    
    if [ "$ip" = "$port" ]; then
        echo "Error: Please specify IP:PORT format (e.g., 192.168.1.100:443)"
        return 1
    fi
    
    # Check if rule already exists
    if sudo iptables -C OUTPUT -d "${ip}" -p tcp --dport "${port}" -j REJECT -m comment --comment "ERSC update block" 2>/dev/null; then
        echo "Firewall rule already exists for ${ip}:${port}"
        return 0
    fi
    
    # Add firewall rule
    sudo iptables -A OUTPUT -d "${ip}" -p tcp --dport "${port}" -j REJECT -m comment --comment "ERSC update block"
    echo "✓ Blocked via firewall: ${ip}:${port}"
    echo ""
    echo "Note: This rule will be lost on reboot unless you save it:"
    echo "  sudo iptables-save > /etc/iptables/rules.v4"
}

# Main logic
case "${1:-}" in
    add)
        if [ -z "${2:-}" ]; then
            echo "Error: Please specify a host to block"
            show_usage
            exit 1
        fi
        add_host_block "$2"
        ;;
    remove)
        if [ -z "${2:-}" ]; then
            echo "Error: Please specify a host to unblock"
            show_usage
            exit 1
        fi
        remove_host_block "$2"
        ;;
    list)
        list_blocks
        ;;
    firewall)
        if [ -z "${2:-}" ]; then
            echo "Error: Please specify IP:PORT to block"
            show_usage
            exit 1
        fi
        add_firewall_block "$2"
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
