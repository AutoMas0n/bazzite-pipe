#!/usr/bin/env bash
set -euo pipefail

# Script: install.sh
# Purpose: Install and configure ZeroTier CLI on Bazzite OS
# Usage: ./install.sh [--network-id NETWORK_ID] [--auto-join]

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Source common utilities
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../common/utils.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../common/config.sh"

# Constants
readonly ZEROTIER_SERVICE="zerotier-one"
readonly ZEROTIER_PACKAGE="zerotier-one"
readonly ZEROTIER_CLI="zerotier-cli"
readonly CONFIG_KEY_NETWORK_ID="ZEROTIER_NETWORK_ID"
readonly CONFIG_KEY_AUTO_START="ZEROTIER_AUTO_START"

# Variables
NETWORK_ID=""
AUTO_JOIN=false
REBOOT_REQUIRED=false

# Display usage information
usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Install and configure ZeroTier CLI on Bazzite OS.

OPTIONS:
    -n, --network-id ID     ZeroTier network ID to join after installation
    -a, --auto-join         Automatically join the network without prompting
    -h, --help              Display this help message

EXAMPLES:
    # Basic installation
    ${SCRIPT_NAME}

    # Install and join a network
    ${SCRIPT_NAME} --network-id abc123def456

    # Install and auto-join without prompting
    ${SCRIPT_NAME} --network-id abc123def456 --auto-join

EXIT CODES:
    0   Success
    1   Installation failed
    2   Service start failed
    3   Verification failed
    4   Network join failed

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--network-id)
                NETWORK_ID="$2"
                shift 2
                ;;
            -a|--auto-join)
                AUTO_JOIN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Check if ZeroTier is already installed
check_existing_installation() {
    log_info "Checking for existing ZeroTier installation..."
    
    if check_command "${ZEROTIER_CLI}"; then
        log_success "ZeroTier CLI is already installed"
        
        # Check version
        local version
        version=$(zerotier-cli -v 2>/dev/null || echo "unknown")
        log_info "Installed version: ${version}"
        
        return 0
    else
        log_info "ZeroTier CLI is not installed"
        return 1
    fi
}

# Verify we're running on Bazzite
verify_bazzite() {
    log_info "Verifying Bazzite OS..."
    
    if ! is_bazzite; then
        log_warn "This script is designed for Bazzite OS"
        log_warn "It may work on other rpm-ostree systems, but is not tested"
        
        if ! confirm "Continue anyway?"; then
            log_info "Installation cancelled"
            exit 0
        fi
    else
        log_success "Running on Bazzite OS"
    fi
}

# Install ZeroTier package
install_zerotier() {
    log_info "Installing ZeroTier..."
    
    if ! is_root; then
        log_error "Root privileges required to install ZeroTier"
        log_info "Please run this script with sudo or as root"
        exit 1
    fi
    
    # Check if already installed via rpm-ostree
    if package_is_installed "${ZEROTIER_PACKAGE}"; then
        log_success "ZeroTier package is already layered"
        return 0
    fi
    
    # Install the package
    log_info "Installing ${ZEROTIER_PACKAGE} via rpm-ostree..."
    log_warn "This may take a few minutes..."
    
    if rpm-ostree install -y "${ZEROTIER_PACKAGE}"; then
        log_success "ZeroTier package installed successfully"
        REBOOT_REQUIRED=true
        return 0
    else
        log_error "Failed to install ZeroTier package"
        return 1
    fi
}

# Enable and start ZeroTier service
start_zerotier_service() {
    log_info "Configuring ZeroTier service..."
    
    if ! is_root; then
        log_error "Root privileges required to manage services"
        exit 2
    fi
    
    # Check if service exists
    if ! service_exists "${ZEROTIER_SERVICE}"; then
        log_error "ZeroTier service not found"
        log_info "Installation may be incomplete. Try rebooting if package was just installed."
        return 1
    fi
    
    # Enable service
    if ! service_is_enabled "${ZEROTIER_SERVICE}"; then
        log_info "Enabling ${ZEROTIER_SERVICE} service..."
        if systemctl enable "${ZEROTIER_SERVICE}.service"; then
            log_success "Service enabled"
        else
            log_error "Failed to enable service"
            return 1
        fi
    else
        log_info "Service is already enabled"
    fi
    
    # Start service
    if ! service_is_active "${ZEROTIER_SERVICE}"; then
        log_info "Starting ${ZEROTIER_SERVICE} service..."
        if systemctl start "${ZEROTIER_SERVICE}.service"; then
            log_success "Service started"
            # Wait a moment for service to initialize
            sleep 2
        else
            log_error "Failed to start service"
            log_info "Check logs with: journalctl -u ${ZEROTIER_SERVICE}.service"
            return 1
        fi
    else
        log_success "Service is already running"
    fi
    
    return 0
}

# Verify ZeroTier installation
verify_installation() {
    log_info "Verifying ZeroTier installation..."
    
    # Check CLI command
    if ! check_command "${ZEROTIER_CLI}"; then
        log_error "ZeroTier CLI command not found"
        return 1
    fi
    
    # Check service status
    if ! service_is_active "${ZEROTIER_SERVICE}"; then
        log_error "ZeroTier service is not running"
        return 1
    fi
    
    # Try to get status
    if zerotier-cli info &> /dev/null; then
        log_success "ZeroTier is installed and running"
        
        # Display info
        local info
        info=$(zerotier-cli info)
        log_info "ZeroTier Info: ${info}"
        
        return 0
    else
        log_error "ZeroTier CLI is not responding"
        return 1
    fi
}

# Join ZeroTier network
join_network() {
    local network_id="$1"
    
    log_info "Joining ZeroTier network: ${network_id}"
    
    # Check if already joined
    if zerotier-cli listnetworks | grep -q "${network_id}"; then
        log_success "Already joined network ${network_id}"
        
        # Check if authorized
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
    if zerotier-cli join "${network_id}"; then
        log_success "Successfully joined network ${network_id}"
        
        # Save network ID to config
        set_config "${CONFIG_KEY_NETWORK_ID}" "${network_id}"
        
        # Wait a moment and check status
        sleep 2
        
        if zerotier-cli listnetworks | grep "${network_id}" | grep -q "OK"; then
            log_success "Network is authorized and connected"
        else
            log_warn "Network joined but not yet authorized"
            log_info "Please authorize this device in ZeroTier Central:"
            log_info "https://my.zerotier.com/network/${network_id}"
            log_info ""
            log_info "After authorization, the connection should establish automatically"
        fi
        
        return 0
    else
        log_error "Failed to join network ${network_id}"
        return 1
    fi
}

# Prompt for network ID
prompt_network_id() {
    if [[ -n "${NETWORK_ID}" ]]; then
        return 0
    fi
    
    echo ""
    log_info "Would you like to join a ZeroTier network now?"
    
    if ! confirm "Join a network?" "n"; then
        log_info "Skipping network join. You can join later using the manager script."
        return 1
    fi
    
    echo ""
    read -r -p "Enter ZeroTier Network ID (16 characters): " NETWORK_ID
    
    # Validate network ID format (should be 16 hex characters)
    if [[ ! "${NETWORK_ID}" =~ ^[0-9a-fA-F]{16}$ ]]; then
        log_error "Invalid network ID format. Should be 16 hexadecimal characters."
        return 1
    fi
    
    return 0
}

# Display post-installation information
show_post_install_info() {
    print_header "ZeroTier Installation Complete"
    
    if [[ "${REBOOT_REQUIRED}" == "true" ]]; then
        log_warn "A system reboot is required to complete the installation"
        log_info "After rebooting, run this script again to join a network"
        echo ""
        log_info "Reboot now with: systemctl reboot"
    else
        log_success "ZeroTier is installed and running"
        
        # Show current status
        echo ""
        log_info "Current Status:"
        zerotier-cli info
        
        echo ""
        log_info "Joined Networks:"
        zerotier-cli listnetworks || log_info "No networks joined yet"
    fi
    
    echo ""
    log_info "Next Steps:"
    echo "  1. Join a network: ${SCRIPT_DIR}/manager.sh join <network-id>"
    echo "  2. Check status: ${SCRIPT_DIR}/manager.sh status"
    echo "  3. Test connectivity: ${SCRIPT_DIR}/test.sh"
    
    echo ""
    log_info "For more information, visit: https://docs.zerotier.com/"
    echo ""
}

# Main installation flow
main() {
    print_header "ZeroTier Installation for Bazzite OS"
    
    # Parse arguments
    parse_args "$@"
    
    # Verify we're on Bazzite
    verify_bazzite
    
    # Check for existing installation
    if check_existing_installation; then
        log_info "ZeroTier is already installed. Verifying configuration..."
        
        # Verify it's working
        if ! verify_installation; then
            log_error "Existing installation has issues"
            
            if confirm "Attempt to fix?"; then
                if is_root; then
                    start_zerotier_service || exit 2
                else
                    log_error "Root privileges required to fix service issues"
                    log_info "Please run with sudo: sudo ${SCRIPT_NAME}"
                    exit 2
                fi
            else
                exit 3
            fi
        fi
    else
        # Fresh installation
        log_info "Starting fresh installation..."
        
        # Check for root privileges
        if ! is_root; then
            log_error "Root privileges required for installation"
            log_info "Please run with sudo: sudo ${SCRIPT_NAME} $*"
            exit 1
        fi
        
        # Install package
        if ! install_zerotier; then
            log_error "Installation failed"
            exit 1
        fi
        
        # If reboot is required, stop here
        if [[ "${REBOOT_REQUIRED}" == "true" ]]; then
            show_post_install_info
            exit 0
        fi
        
        # Start service
        if ! start_zerotier_service; then
            log_error "Failed to start ZeroTier service"
            exit 2
        fi
        
        # Verify installation
        if ! verify_installation; then
            log_error "Installation verification failed"
            exit 3
        fi
    fi
    
    # Handle network joining
    if [[ "${AUTO_JOIN}" == "true" ]] || [[ -n "${NETWORK_ID}" ]]; then
        # Network ID provided via command line
        if [[ -n "${NETWORK_ID}" ]]; then
            if ! is_root; then
                log_error "Root privileges required to join networks"
                log_info "Please run with sudo: sudo ${SCRIPT_NAME} --network-id ${NETWORK_ID}"
                exit 4
            fi
            
            if ! join_network "${NETWORK_ID}"; then
                log_error "Failed to join network"
                exit 4
            fi
        fi
    else
        # Interactive mode - prompt for network
        if prompt_network_id; then
            if ! is_root; then
                log_error "Root privileges required to join networks"
                log_info "Please run with sudo to join a network"
            else
                join_network "${NETWORK_ID}" || log_warn "Network join failed"
            fi
        fi
    fi
    
    # Save auto-start preference
    set_config "${CONFIG_KEY_AUTO_START}" "true"
    
    # Show post-installation info
    show_post_install_info
    
    log_success "Installation complete!"
    exit 0
}

# Run main function
main "$@"
