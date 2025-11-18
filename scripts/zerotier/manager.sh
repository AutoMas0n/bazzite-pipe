#!/usr/bin/env bash
set -euo pipefail

# Script: manager.sh
# Purpose: Interactive ZeroTier connection management
# Usage: ./manager.sh [command] [args]

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Source common utilities
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../common/utils.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../common/config.sh"

# Constants
readonly ZEROTIER_SERVICE="zerotier-one"
readonly ZEROTIER_CLI="zerotier-cli"
readonly CONFIG_KEY_NETWORK_ID="ZEROTIER_NETWORK_ID"

# Check if ZeroTier is installed
check_zerotier_installed() {
    if ! check_command "${ZEROTIER_CLI}"; then
        log_error "ZeroTier CLI is not installed"
        log_info "Please run the installation script first:"
        log_info "  ${SCRIPT_DIR}/install.sh"
        return 1
    fi
    
    if ! service_is_active "${ZEROTIER_SERVICE}"; then
        log_error "ZeroTier service is not running"
        
        if is_root; then
            if confirm "Start the service now?"; then
                systemctl start "${ZEROTIER_SERVICE}.service"
                sleep 2
                return 0
            fi
        else
            log_info "Start the service with: sudo systemctl start ${ZEROTIER_SERVICE}.service"
        fi
        return 1
    fi
    
    return 0
}

# Display current status
show_status() {
    print_header "ZeroTier Status"
    
    # Service status
    echo "Service Status:"
    if service_is_active "${ZEROTIER_SERVICE}"; then
        log_success "ZeroTier service is running"
    else
        log_error "ZeroTier service is not running"
    fi
    
    if service_is_enabled "${ZEROTIER_SERVICE}"; then
        log_info "Service is enabled (starts on boot)"
    else
        log_warn "Service is not enabled (won't start on boot)"
    fi
    
    echo ""
    
    # ZeroTier info
    echo "ZeroTier Info:"
    if zerotier-cli info 2>/dev/null; then
        echo ""
    else
        log_error "Failed to get ZeroTier info"
        return 1
    fi
    
    # Network list
    echo "Joined Networks:"
    local networks
    networks=$(zerotier-cli listnetworks 2>/dev/null || echo "")
    
    if [[ -z "${networks}" ]]; then
        log_info "No networks joined"
    else
        echo "${networks}"
        echo ""
        
        # Parse and show detailed status for each network
        while IFS= read -r line; do
            # Skip header line
            if [[ "${line}" =~ ^200\ listnetworks ]]; then
                continue
            fi
            
            # Extract network ID (first field)
            local net_id
            net_id=$(echo "${line}" | awk '{print $1}')
            
            if [[ -n "${net_id}" ]] && [[ "${net_id}" =~ ^[0-9a-fA-F]{16}$ ]]; then
                # Check if network is OK
                if echo "${line}" | grep -q "OK"; then
                    log_success "Network ${net_id} is connected"
                else
                    log_warn "Network ${net_id} is not authorized or has issues"
                fi
            fi
        done <<< "${networks}"
    fi
    
    echo ""
}

# Join a network
join_network() {
    local network_id="$1"
    
    if [[ -z "${network_id}" ]]; then
        read -r -p "Enter ZeroTier Network ID (16 characters): " network_id
    fi
    
    # Validate network ID
    if [[ ! "${network_id}" =~ ^[0-9a-fA-F]{16}$ ]]; then
        log_error "Invalid network ID format. Should be 16 hexadecimal characters."
        return 1
    fi
    
    log_info "Joining network: ${network_id}"
    
    # Check if already joined
    if zerotier-cli listnetworks 2>/dev/null | grep -q "${network_id}"; then
        log_warn "Already joined network ${network_id}"
        
        # Check authorization status
        if zerotier-cli listnetworks | grep "${network_id}" | grep -q "OK"; then
            log_success "Network is authorized and connected"
        else
            log_warn "Network is not yet authorized"
            log_info "Please authorize this device in ZeroTier Central:"
            log_info "https://my.zerotier.com/network/${network_id}"
        fi
        
        return 0
    fi
    
    # Join the network
    if zerotier-cli join "${network_id}" 2>/dev/null; then
        log_success "Successfully joined network ${network_id}"
        
        # Save to config
        set_config "${CONFIG_KEY_NETWORK_ID}" "${network_id}"
        
        # Wait and check status
        sleep 2
        
        if zerotier-cli listnetworks | grep "${network_id}" | grep -q "OK"; then
            log_success "Network is authorized and connected"
        else
            log_warn "Network joined but not yet authorized"
            log_info "Please authorize this device in ZeroTier Central:"
            log_info "https://my.zerotier.com/network/${network_id}"
        fi
        
        return 0
    else
        log_error "Failed to join network ${network_id}"
        return 1
    fi
}

# Leave a network
leave_network() {
    local network_id="$1"
    
    # If no network ID provided, show list and prompt
    if [[ -z "${network_id}" ]]; then
        echo "Currently joined networks:"
        zerotier-cli listnetworks 2>/dev/null || log_error "Failed to list networks"
        echo ""
        read -r -p "Enter Network ID to leave: " network_id
    fi
    
    # Validate network ID
    if [[ ! "${network_id}" =~ ^[0-9a-fA-F]{16}$ ]]; then
        log_error "Invalid network ID format"
        return 1
    fi
    
    # Check if joined
    if ! zerotier-cli listnetworks 2>/dev/null | grep -q "${network_id}"; then
        log_error "Not currently joined to network ${network_id}"
        return 1
    fi
    
    # Confirm
    if ! confirm "Leave network ${network_id}?"; then
        log_info "Cancelled"
        return 0
    fi
    
    # Leave the network
    if zerotier-cli leave "${network_id}" 2>/dev/null; then
        log_success "Successfully left network ${network_id}"
        
        # Remove from config if it matches
        local saved_id
        saved_id=$(get_config "${CONFIG_KEY_NETWORK_ID}" "")
        if [[ "${saved_id}" == "${network_id}" ]]; then
            unset_config "${CONFIG_KEY_NETWORK_ID}"
        fi
        
        return 0
    else
        log_error "Failed to leave network ${network_id}"
        return 1
    fi
}

# Reconnect to saved network
reconnect() {
    local network_id
    network_id=$(get_config "${CONFIG_KEY_NETWORK_ID}" "")
    
    if [[ -z "${network_id}" ]]; then
        log_error "No saved network ID found"
        log_info "Join a network first, or specify a network ID"
        return 1
    fi
    
    log_info "Reconnecting to network: ${network_id}"
    
    # Check if already connected
    if zerotier-cli listnetworks 2>/dev/null | grep "${network_id}" | grep -q "OK"; then
        log_success "Already connected to network ${network_id}"
        return 0
    fi
    
    # Try to rejoin
    join_network "${network_id}"
}

# List all networks
list_networks() {
    print_header "ZeroTier Networks"
    
    local networks
    networks=$(zerotier-cli listnetworks 2>/dev/null || echo "")
    
    if [[ -z "${networks}" ]]; then
        log_info "No networks joined"
        return 0
    fi
    
    echo "${networks}"
    echo ""
    
    # Show saved network from config
    local saved_id
    saved_id=$(get_config "${CONFIG_KEY_NETWORK_ID}" "")
    if [[ -n "${saved_id}" ]]; then
        log_info "Saved network ID: ${saved_id}"
    fi
}

# Run diagnostics
run_diagnostics() {
    print_header "ZeroTier Diagnostics"
    
    # Check service
    echo "1. Service Status:"
    systemctl status "${ZEROTIER_SERVICE}.service" --no-pager || true
    echo ""
    
    # Check ZeroTier info
    echo "2. ZeroTier Info:"
    zerotier-cli info 2>/dev/null || log_error "Failed to get info"
    echo ""
    
    # Check networks
    echo "3. Network Status:"
    zerotier-cli listnetworks 2>/dev/null || log_error "Failed to list networks"
    echo ""
    
    # Check peers
    echo "4. Connected Peers:"
    zerotier-cli listpeers 2>/dev/null || log_error "Failed to list peers"
    echo ""
    
    # Check internet connectivity
    echo "5. Internet Connectivity:"
    if check_network; then
        log_success "Internet connection is working"
    else
        log_error "No internet connection detected"
    fi
    echo ""
    
    # Check firewall (if firewalld is available)
    if check_command firewall-cmd; then
        echo "6. Firewall Status:"
        if firewall-cmd --state 2>/dev/null | grep -q "running"; then
            log_info "Firewall is running"
            
            # Check if zerotier service is allowed
            if firewall-cmd --list-services 2>/dev/null | grep -q "zerotier"; then
                log_success "ZeroTier service is allowed in firewall"
            else
                log_warn "ZeroTier service may not be allowed in firewall"
            fi
        else
            log_info "Firewall is not running"
        fi
        echo ""
    fi
    
    # Recent logs
    echo "7. Recent Logs (last 20 lines):"
    journalctl -u "${ZEROTIER_SERVICE}.service" -n 20 --no-pager || log_error "Failed to get logs"
    echo ""
}

# Display interactive menu
show_menu() {
    print_header "ZeroTier Network Manager"
    
    echo "1. Show Status"
    echo "2. Join Network"
    echo "3. Leave Network"
    echo "4. Reconnect to Saved Network"
    echo "5. List Networks"
    echo "6. Run Diagnostics"
    echo "7. Test Network (run test.sh)"
    echo "8. Exit"
    echo ""
}

# Interactive menu loop
interactive_mode() {
    while true; do
        show_menu
        read -r -p "Select an option (1-8): " choice
        echo ""
        
        case "${choice}" in
            1)
                show_status
                ;;
            2)
                if ! is_root; then
                    log_error "Root privileges required to join networks"
                    log_info "Please run with sudo: sudo ${SCRIPT_NAME}"
                else
                    join_network ""
                fi
                ;;
            3)
                if ! is_root; then
                    log_error "Root privileges required to leave networks"
                    log_info "Please run with sudo: sudo ${SCRIPT_NAME}"
                else
                    leave_network ""
                fi
                ;;
            4)
                if ! is_root; then
                    log_error "Root privileges required to reconnect"
                    log_info "Please run with sudo: sudo ${SCRIPT_NAME}"
                else
                    reconnect
                fi
                ;;
            5)
                list_networks
                ;;
            6)
                run_diagnostics
                ;;
            7)
                if [[ -x "${SCRIPT_DIR}/test.sh" ]]; then
                    "${SCRIPT_DIR}/test.sh"
                else
                    log_error "Test script not found or not executable"
                fi
                ;;
            8)
                log_info "Goodbye!"
                exit 0
                ;;
            *)
                log_error "Invalid option: ${choice}"
                ;;
        esac
        
        echo ""
        read -r -p "Press Enter to continue..."
        clear
    done
}

# Display usage
usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [COMMAND] [ARGS]

Interactive ZeroTier network management for Bazzite OS.

COMMANDS:
    status              Show current ZeroTier status
    join <network-id>   Join a ZeroTier network
    leave <network-id>  Leave a ZeroTier network
    reconnect           Reconnect to saved network
    list                List all joined networks
    diagnostics         Run connection diagnostics
    interactive         Start interactive menu (default)
    help                Show this help message

EXAMPLES:
    # Interactive mode
    ${SCRIPT_NAME}

    # Show status
    ${SCRIPT_NAME} status

    # Join a network
    sudo ${SCRIPT_NAME} join abc123def456

    # Leave a network
    sudo ${SCRIPT_NAME} leave abc123def456

    # Reconnect to saved network
    sudo ${SCRIPT_NAME} reconnect

EOF
}

# Main function
main() {
    # Check if ZeroTier is installed
    if ! check_zerotier_installed; then
        exit 1
    fi
    
    # Parse command
    local command="${1:-interactive}"
    
    case "${command}" in
        status)
            show_status
            ;;
        join)
            if ! is_root; then
                log_error "Root privileges required to join networks"
                log_info "Please run with sudo: sudo ${SCRIPT_NAME} join <network-id>"
                exit 1
            fi
            join_network "${2:-}"
            ;;
        leave)
            if ! is_root; then
                log_error "Root privileges required to leave networks"
                log_info "Please run with sudo: sudo ${SCRIPT_NAME} leave <network-id>"
                exit 1
            fi
            leave_network "${2:-}"
            ;;
        reconnect)
            if ! is_root; then
                log_error "Root privileges required to reconnect"
                log_info "Please run with sudo: sudo ${SCRIPT_NAME} reconnect"
                exit 1
            fi
            reconnect
            ;;
        list)
            list_networks
            ;;
        diagnostics|diag)
            run_diagnostics
            ;;
        interactive|menu)
            interactive_mode
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: ${command}"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
