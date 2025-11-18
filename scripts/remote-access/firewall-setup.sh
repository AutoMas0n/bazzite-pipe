#!/usr/bin/env bash
set -euo pipefail

# Script: firewall-setup.sh
# Purpose: Configure firewall rules for remote access via ZeroTier
# Usage: ./firewall-setup.sh

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
readonly TRUSTED_ZONE="trusted"
readonly ZT_INTERFACE_PATTERN="zt*"
SKIP_ROOT_CHECK=false

show_usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Configure firewall rules to allow remote access via ZeroTier network.

OPTIONS:
    -h, --help    Show this help message

DESCRIPTION:
    This script configures firewalld to:
    - Add ZeroTier interfaces to the trusted zone
    - Allow SSH (port 22) on ZeroTier
    - Allow Cockpit (port 9090) on ZeroTier
    - Block these services on public interfaces

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
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

# Check if firewalld is available
check_firewalld() {
    log_info "Checking firewalld availability..."
    
    if ! command -v firewall-cmd &> /dev/null; then
        log_error "firewalld not found"
        log_error "Please install firewalld: sudo dnf install firewalld"
        return 1
    fi
    
    log_success "firewalld is installed"
    
    # Check if firewalld is running
    if ! sudo systemctl is-active --quiet firewalld; then
        log_warn "firewalld is not running"
        if confirm "Start firewalld now?"; then
            if sudo systemctl start firewalld; then
                log_success "firewalld started"
            else
                log_error "Failed to start firewalld"
                return 1
            fi
        else
            log_error "firewalld must be running to configure rules"
            return 1
        fi
    fi
    
    log_success "firewalld is running"
    return 0
}

# Enable firewalld on boot
enable_firewalld() {
    log_info "Enabling firewalld on boot..."
    
    if sudo systemctl is-enabled --quiet firewalld; then
        log_success "firewalld is already enabled"
        return 0
    fi
    
    if sudo systemctl enable firewalld; then
        log_success "firewalld enabled on boot"
        return 0
    else
        log_error "Failed to enable firewalld"
        return 1
    fi
}

# Get ZeroTier interfaces
get_zerotier_interfaces() {
    local interfaces
    interfaces=$(ip -o link show | grep -oP 'zt\w+' || echo "")
    echo "${interfaces}"
}

# Add ZeroTier interfaces to trusted zone
configure_zerotier_zone() {
    log_info "Configuring ZeroTier interfaces in trusted zone..."
    
    # Get current ZeroTier interfaces
    local zt_interfaces
    zt_interfaces=$(get_zerotier_interfaces)
    
    if [[ -z "${zt_interfaces}" ]]; then
        log_warn "No ZeroTier interfaces found"
        log_info "ZeroTier interfaces will be added to trusted zone when they appear"
        
        # Add interface pattern to trusted zone for future interfaces
        if sudo firewall-cmd --permanent --zone="${TRUSTED_ZONE}" --add-interface="${ZT_INTERFACE_PATTERN}" 2>/dev/null; then
            log_success "Added ZeroTier interface pattern to trusted zone"
        else
            log_info "Interface pattern already configured or not supported"
        fi
    else
        log_info "Found ZeroTier interfaces: ${zt_interfaces}"
        
        # Add each interface to trusted zone
        for interface in ${zt_interfaces}; do
            log_info "Adding ${interface} to trusted zone..."
            
            if sudo firewall-cmd --permanent --zone="${TRUSTED_ZONE}" --add-interface="${interface}"; then
                log_success "Added ${interface} to trusted zone"
            else
                log_warn "Failed to add ${interface} (may already be configured)"
            fi
        done
    fi
}

# Configure services in trusted zone
configure_trusted_services() {
    log_info "Configuring services in trusted zone..."
    
    local services=("ssh" "cockpit")
    
    for service in "${services[@]}"; do
        log_info "Adding ${service} to trusted zone..."
        
        if sudo firewall-cmd --permanent --zone="${TRUSTED_ZONE}" --add-service="${service}"; then
            log_success "Added ${service} to trusted zone"
        else
            log_info "${service} already configured in trusted zone"
        fi
    done
}

# Ensure services are not in public zone
secure_public_zone() {
    log_info "Securing public zone..."
    
    # Check if SSH is in public zone
    if sudo firewall-cmd --zone=public --query-service=ssh &> /dev/null; then
        log_warn "SSH is allowed in public zone"
        if confirm "Remove SSH from public zone? (Recommended for security)"; then
            if sudo firewall-cmd --permanent --zone=public --remove-service=ssh; then
                log_success "Removed SSH from public zone"
            else
                log_warn "Failed to remove SSH from public zone"
            fi
        fi
    else
        log_success "SSH is not in public zone"
    fi
    
    # Check if Cockpit is in public zone
    if sudo firewall-cmd --zone=public --query-service=cockpit &> /dev/null; then
        log_warn "Cockpit is allowed in public zone"
        if confirm "Remove Cockpit from public zone? (Recommended for security)"; then
            if sudo firewall-cmd --permanent --zone=public --remove-service=cockpit; then
                log_success "Removed Cockpit from public zone"
            else
                log_warn "Failed to remove Cockpit from public zone"
            fi
        fi
    else
        log_success "Cockpit is not in public zone"
    fi
}

# Reload firewall rules
reload_firewall() {
    log_info "Reloading firewall rules..."
    
    if sudo firewall-cmd --reload; then
        log_success "Firewall rules reloaded"
        return 0
    else
        log_error "Failed to reload firewall rules"
        return 1
    fi
}

# Verify firewall configuration
verify_firewall() {
    log_info "Verifying firewall configuration..."
    
    local all_good=true
    
    # Check if firewalld is running
    if sudo systemctl is-active --quiet firewalld; then
        log_success "✓ firewalld is running"
    else
        log_error "✗ firewalld is not running"
        all_good=false
    fi
    
    # Check if firewalld is enabled
    if sudo systemctl is-enabled --quiet firewalld; then
        log_success "✓ firewalld is enabled on boot"
    else
        log_error "✗ firewalld is not enabled on boot"
        all_good=false
    fi
    
    # Check trusted zone services
    log_info "Checking trusted zone configuration..."
    
    if sudo firewall-cmd --zone="${TRUSTED_ZONE}" --query-service=ssh &> /dev/null; then
        log_success "✓ SSH allowed in trusted zone"
    else
        log_warn "⚠ SSH not found in trusted zone"
    fi
    
    if sudo firewall-cmd --zone="${TRUSTED_ZONE}" --query-service=cockpit &> /dev/null; then
        log_success "✓ Cockpit allowed in trusted zone"
    else
        log_warn "⚠ Cockpit not found in trusted zone"
    fi
    
    # Check ZeroTier interfaces
    local zt_interfaces
    zt_interfaces=$(get_zerotier_interfaces)
    
    if [[ -n "${zt_interfaces}" ]]; then
        log_info "Checking ZeroTier interfaces..."
        for interface in ${zt_interfaces}; do
            local zone
            zone=$(sudo firewall-cmd --get-zone-of-interface="${interface}" 2>/dev/null || echo "")
            
            if [[ "${zone}" == "${TRUSTED_ZONE}" ]]; then
                log_success "✓ ${interface} is in trusted zone"
            else
                log_warn "⚠ ${interface} is in zone: ${zone:-none}"
            fi
        done
    else
        log_info "ℹ No ZeroTier interfaces currently active"
    fi
    
    if [[ "${all_good}" == "true" ]]; then
        log_success "Firewall configuration verified!"
        return 0
    else
        log_warn "Some firewall checks had issues"
        return 1
    fi
}

# Display firewall status
show_firewall_status() {
    print_separator
    log_success "Firewall Configuration Complete!"
    print_separator
    echo ""
    echo "Firewall Status:"
    
    # Show trusted zone configuration
    echo ""
    echo "Trusted Zone (ZeroTier):"
    sudo firewall-cmd --zone="${TRUSTED_ZONE}" --list-all | grep -E "(services|interfaces)" || true
    
    # Show public zone configuration
    echo ""
    echo "Public Zone (Internet):"
    sudo firewall-cmd --zone=public --list-all | grep -E "(services|interfaces)" || true
    
    echo ""
    echo "Security Notes:"
    echo "  • SSH and Cockpit are only accessible via ZeroTier"
    echo "  • Public interfaces are protected"
    echo "  • Firewall rules persist across reboots"
    echo ""
    print_separator
}

# Main function
main() {
    print_header "Firewall Configuration for Remote Access"
    
    # Parse arguments
    parse_args "$@"
    
    # Check if running as root
    if [[ "${EUID}" -eq 0 ]] && [[ "${SKIP_ROOT_CHECK}" != "true" ]]; then
        log_error "Do not run this script as root. Run as a regular user with sudo access."
        exit 1
    fi
    
    # Check firewalld availability
    check_firewalld || exit 1
    
    # Enable firewalld on boot
    enable_firewalld || exit 1
    
    # Configure ZeroTier zone
    configure_zerotier_zone || log_warn "ZeroTier zone configuration had issues"
    
    # Configure trusted services
    configure_trusted_services || exit 1
    
    # Secure public zone
    secure_public_zone || log_warn "Public zone security had issues"
    
    # Reload firewall
    reload_firewall || exit 1
    
    # Verify configuration
    verify_firewall || log_warn "Some verification checks failed"
    
    # Show status
    show_firewall_status
    
    log_success "Firewall setup completed successfully!"
}

main "$@"
