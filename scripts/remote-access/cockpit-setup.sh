#!/usr/bin/env bash
set -euo pipefail

# Script: cockpit-setup.sh
# Purpose: Install and configure Cockpit web console for remote administration
# Usage: ./cockpit-setup.sh [--no-firewall] [--modules module1,module2]

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Source common utilities
if [[ -n "${BAZZITE_PIPE_COMMON_DIR:-}" ]]; then
    # Running from quick-setup.sh or similar - use provided path
    source "${BAZZITE_PIPE_COMMON_DIR}/utils.sh"
else
    # Running from repo - use relative path
    source "${SCRIPT_DIR}/../common/utils.sh"
fi

# Configuration
readonly COCKPIT_PORT=9090
CONFIGURE_FIREWALL=true
ADDITIONAL_MODULES=""
SKIP_ROOT_CHECK=false

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-firewall)
                CONFIGURE_FIREWALL=false
                shift
                ;;
            --modules)
                ADDITIONAL_MODULES="$2"
                shift 2
                ;;
            --skip-root-check)
                SKIP_ROOT_CHECK=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

show_usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Install and configure Cockpit web console for remote administration.

OPTIONS:
    --no-firewall        Skip firewall configuration
    --modules <list>     Additional Cockpit modules to install (comma-separated)
    -h, --help          Show this help message

EXAMPLES:
    # Basic installation
    ${SCRIPT_NAME}
    
    # Install with additional modules
    ${SCRIPT_NAME} --modules cockpit-podman,cockpit-machines
    
    # Install without configuring firewall
    ${SCRIPT_NAME} --no-firewall

AVAILABLE MODULES:
    cockpit-storaged     Storage management
    cockpit-podman       Container management
    cockpit-machines     Virtual machine management
    cockpit-networkmanager  Network configuration
    cockpit-packagekit   Package management

EOF
}

# Check if Cockpit is installed
check_cockpit_installed() {
    log_info "Checking Cockpit installation..."
    
    if rpm -q cockpit &> /dev/null; then
        log_success "Cockpit is already installed"
        return 0
    fi
    
    log_warn "Cockpit not found"
    return 1
}

# Install Cockpit and modules
install_cockpit() {
    log_info "Installing Cockpit web console..."
    
    # Base packages to install
    local packages="cockpit cockpit-storaged cockpit-networkmanager"
    
    # Add additional modules if specified
    if [[ -n "${ADDITIONAL_MODULES}" ]]; then
        # Replace commas with spaces
        local extra_modules="${ADDITIONAL_MODULES//,/ }"
        packages="${packages} ${extra_modules}"
    fi
    
    # Check if we're on an immutable system (Bazzite uses rpm-ostree)
    if command -v rpm-ostree &> /dev/null; then
        log_info "Detected rpm-ostree system"
        
        # Check which packages need to be installed
        local packages_to_install=""
        for pkg in ${packages}; do
            if ! rpm -q "${pkg}" &> /dev/null; then
                packages_to_install="${packages_to_install} ${pkg}"
            fi
        done
        
        if [[ -z "${packages_to_install}" ]]; then
            log_success "All Cockpit packages already installed"
            return 0
        fi
        
        log_info "Installing packages:${packages_to_install}"
        log_warn "This will require a system reboot to complete..."
        
        if sudo rpm-ostree install ${packages_to_install}; then
            log_success "Cockpit packages layered successfully"
            log_warn "IMPORTANT: You must reboot for changes to take effect"
            log_warn "After reboot, run this script again to complete setup"
            
            if confirm "Reboot now?"; then
                sudo systemctl reboot
                exit 0
            else
                log_info "Please reboot manually and run this script again"
                exit 0
            fi
        else
            log_error "Failed to layer Cockpit packages"
            return 1
        fi
    else
        # Fallback for non-immutable systems
        log_info "Installing packages: ${packages}"
        if sudo dnf install -y ${packages}; then
            log_success "Cockpit installed successfully"
            return 0
        else
            log_error "Failed to install Cockpit"
            return 1
        fi
    fi
}

# Configure Cockpit
configure_cockpit() {
    log_info "Configuring Cockpit..."
    
    # Cockpit configuration directory
    local config_dir="/etc/cockpit"
    local config_file="${config_dir}/cockpit.conf"
    
    # Ensure config directory exists
    if [[ ! -d "${config_dir}" ]]; then
        sudo mkdir -p "${config_dir}"
    fi
    
    # Create or update configuration
    local config_content
    config_content=$(cat << 'EOF'
[WebService]
# Allow connections from all interfaces
# (will be restricted by firewall to ZeroTier only)
Origins = https://0.0.0.0:9090 wss://0.0.0.0:9090
ProtocolHeader = X-Forwarded-Proto
AllowUnencrypted = false

[Session]
# Session timeout (30 minutes)
IdleTimeout = 30
EOF
)
    
    if echo "${config_content}" | sudo tee "${config_file}" > /dev/null; then
        log_success "Cockpit configuration written"
    else
        log_error "Failed to write Cockpit configuration"
        return 1
    fi
}

# Enable and start Cockpit service
enable_cockpit_service() {
    log_info "Enabling and starting Cockpit service..."
    
    # Enable socket (Cockpit uses socket activation)
    if sudo systemctl enable cockpit.socket; then
        log_success "Cockpit socket enabled"
    else
        log_error "Failed to enable Cockpit socket"
        return 1
    fi
    
    # Start socket
    if sudo systemctl is-active --quiet cockpit.socket; then
        log_info "Restarting Cockpit socket..."
        if sudo systemctl restart cockpit.socket; then
            log_success "Cockpit socket restarted"
        else
            log_error "Failed to restart Cockpit socket"
            return 1
        fi
    else
        log_info "Starting Cockpit socket..."
        if sudo systemctl start cockpit.socket; then
            log_success "Cockpit socket started"
        else
            log_error "Failed to start Cockpit socket"
            return 1
        fi
    fi
    
    # Verify socket is active
    if sudo systemctl is-active --quiet cockpit.socket; then
        log_success "Cockpit socket is active"
        return 0
    else
        log_error "Cockpit socket is not active"
        return 1
    fi
}

# Configure firewall for Cockpit
configure_firewall() {
    if [[ "${CONFIGURE_FIREWALL}" == "false" ]]; then
        log_info "Skipping firewall configuration (--no-firewall specified)"
        return 0
    fi
    
    log_info "Configuring firewall for Cockpit..."
    
    # Check if firewalld is available
    if ! command -v firewall-cmd &> /dev/null; then
        log_warn "firewalld not found, skipping firewall configuration"
        return 0
    fi
    
    # Check if firewalld is running
    if ! sudo systemctl is-active --quiet firewalld; then
        log_warn "firewalld is not running, skipping firewall configuration"
        return 0
    fi
    
    # Add Cockpit service to trusted zone (for ZeroTier)
    if sudo firewall-cmd --permanent --zone=trusted --add-service=cockpit; then
        log_success "Added Cockpit to trusted zone"
    else
        log_warn "Failed to add Cockpit to trusted zone"
    fi
    
    # Reload firewall
    if sudo firewall-cmd --reload; then
        log_success "Firewall rules reloaded"
    else
        log_warn "Failed to reload firewall"
    fi
}

# Verify Cockpit setup
verify_cockpit_setup() {
    log_info "Verifying Cockpit setup..."
    
    local all_good=true
    
    # Check if Cockpit is installed
    if rpm -q cockpit &> /dev/null; then
        log_success "✓ Cockpit is installed"
    else
        log_error "✗ Cockpit is not installed"
        all_good=false
    fi
    
    # Check socket status
    if sudo systemctl is-active --quiet cockpit.socket; then
        log_success "✓ Cockpit socket is active"
    else
        log_error "✗ Cockpit socket is not active"
        all_good=false
    fi
    
    # Check if socket is enabled
    if sudo systemctl is-enabled --quiet cockpit.socket; then
        log_success "✓ Cockpit socket is enabled"
    else
        log_error "✗ Cockpit socket is not enabled"
        all_good=false
    fi
    
    # Check if port is listening
    if sudo ss -tlnp | grep -q ":${COCKPIT_PORT} "; then
        log_success "✓ Cockpit is listening on port ${COCKPIT_PORT}"
    else
        log_error "✗ Cockpit is not listening on port ${COCKPIT_PORT}"
        all_good=false
    fi
    
    # Check firewall (if configured)
    if [[ "${CONFIGURE_FIREWALL}" == "true" ]] && command -v firewall-cmd &> /dev/null; then
        if sudo firewall-cmd --zone=trusted --query-service=cockpit &> /dev/null; then
            log_success "✓ Firewall allows Cockpit on trusted zone"
        else
            log_warn "⚠ Cockpit not found in trusted zone firewall rules"
        fi
    fi
    
    if [[ "${all_good}" == "true" ]]; then
        log_success "All Cockpit setup checks passed!"
        return 0
    else
        log_error "Some Cockpit setup checks failed"
        return 1
    fi
}

# Display connection information
show_connection_info() {
    log_info "Gathering connection information..."
    
    # Get ZeroTier IP if available
    local zt_ip=""
    if command -v zerotier-cli &> /dev/null; then
        zt_ip=$(zerotier-cli listnetworks | grep -oP '\d+\.\d+\.\d+\.\d+' | head -n1 || echo "")
    fi
    
    # Get all IP addresses
    local all_ips
    all_ips=$(hostname -I 2>/dev/null || echo "")
    
    print_separator
    log_success "Cockpit Web Console Setup Complete!"
    print_separator
    echo ""
    echo "Access Cockpit:"
    
    if [[ -n "${zt_ip}" ]]; then
        echo "  ZeroTier: https://${zt_ip}:${COCKPIT_PORT}"
    else
        echo "  ZeroTier: https://<zerotier-ip>:${COCKPIT_PORT}"
        echo "            (Run ZeroTier setup first to get IP)"
    fi
    
    if [[ -n "${all_ips}" ]]; then
        echo ""
        echo "Other interfaces:"
        for ip in ${all_ips}; do
            echo "  https://${ip}:${COCKPIT_PORT}"
        done
    fi
    
    echo ""
    echo "Login Credentials:"
    echo "  Username: ${USER} (or any system user)"
    echo "  Password: Your system password"
    echo ""
    echo "Notes:"
    echo "  • Accept the self-signed certificate warning in your browser"
    echo "  • Cockpit provides full system administration capabilities"
    echo "  • Terminal access is available through the web interface"
    echo "  • Service will start automatically on boot"
    echo ""
    print_separator
}

# Main function
main() {
    print_header "Cockpit Web Console Setup"
    
    # Parse arguments
    parse_args "$@"
    
    # Check if running as root
    if [[ "${EUID}" -eq 0 ]] && [[ "${SKIP_ROOT_CHECK}" != "true" ]]; then
        log_error "Do not run this script as root. Run as a regular user with sudo access."
        exit 1
    fi
    
    # Check and install Cockpit if needed
    if ! check_cockpit_installed; then
        install_cockpit || exit 1
        
        # If we're on rpm-ostree and just installed, script will exit for reboot
        # This check is here for clarity
        if command -v rpm-ostree &> /dev/null; then
            log_info "Waiting for reboot to complete installation..."
            exit 0
        fi
    fi
    
    # Configure Cockpit
    configure_cockpit || exit 1
    
    # Enable and start service
    enable_cockpit_service || exit 1
    
    # Configure firewall
    configure_firewall || log_warn "Firewall configuration had issues"
    
    # Verify setup
    verify_cockpit_setup || log_warn "Some verification checks failed"
    
    # Show connection information
    show_connection_info
    
    log_success "Cockpit setup completed successfully!"
}

main "$@"
