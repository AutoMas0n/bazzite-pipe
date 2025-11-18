#!/usr/bin/env bash
set -euo pipefail

# Script: verify.sh
# Purpose: Verify remote access setup and display connection information
# Usage: ./verify.sh

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Source common utilities
source "${SCRIPT_DIR}/../common/utils.sh"

show_usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Verify remote access setup and display connection information.

OPTIONS:
    -h, --help    Show this help message

DESCRIPTION:
    This script checks:
    - ZeroTier connection status
    - SSH server status
    - Cockpit web console status
    - Firewall configuration
    - Network connectivity

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
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

# Check ZeroTier status
check_zerotier() {
    log_info "Checking ZeroTier status..."
    
    if ! command -v zerotier-cli &> /dev/null; then
        log_warn "✗ ZeroTier not installed"
        return 1
    fi
    
    if ! sudo systemctl is-active --quiet zerotier-one; then
        log_warn "✗ ZeroTier service not running"
        return 1
    fi
    
    # Get network info
    local network_info
    network_info=$(zerotier-cli listnetworks 2>/dev/null || echo "")
    
    if [[ -z "${network_info}" ]] || [[ "${network_info}" == *"200 listnetworks"* ]]; then
        log_warn "✗ Not connected to any ZeroTier networks"
        return 1
    fi
    
    log_success "✓ ZeroTier is running and connected"
    return 0
}

# Get ZeroTier IP address
get_zerotier_ip() {
    if ! command -v zerotier-cli &> /dev/null; then
        echo ""
        return 1
    fi
    
    local zt_ip
    zt_ip=$(zerotier-cli listnetworks 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' | head -n1 || echo "")
    echo "${zt_ip}"
}

# Get ZeroTier network ID
get_zerotier_network() {
    if ! command -v zerotier-cli &> /dev/null; then
        echo ""
        return 1
    fi
    
    local network_id
    network_id=$(zerotier-cli listnetworks 2>/dev/null | grep -oP '[0-9a-f]{16}' | head -n1 || echo "")
    echo "${network_id}"
}

# Check SSH status
check_ssh() {
    log_info "Checking SSH server status..."
    
    if ! sudo systemctl is-active --quiet sshd; then
        log_warn "✗ SSH service not running"
        return 1
    fi
    
    if ! sudo ss -tlnp | grep -q ':22 '; then
        log_warn "✗ SSH not listening on port 22"
        return 1
    fi
    
    # Check if key-based auth is configured
    if [[ -f "${HOME}/.ssh/authorized_keys" ]] && [[ -s "${HOME}/.ssh/authorized_keys" ]]; then
        log_success "✓ SSH is running with authorized keys configured"
    else
        log_warn "✓ SSH is running but no authorized keys found"
    fi
    
    return 0
}

# Check Cockpit status
check_cockpit() {
    log_info "Checking Cockpit status..."
    
    if ! rpm -q cockpit &> /dev/null; then
        log_warn "✗ Cockpit not installed"
        return 1
    fi
    
    if ! sudo systemctl is-active --quiet cockpit.socket; then
        log_warn "✗ Cockpit service not running"
        return 1
    fi
    
    if ! sudo ss -tlnp | grep -q ':9090 '; then
        log_warn "✗ Cockpit not listening on port 9090"
        return 1
    fi
    
    log_success "✓ Cockpit is running"
    return 0
}

# Check firewall status
check_firewall() {
    log_info "Checking firewall configuration..."
    
    if ! command -v firewall-cmd &> /dev/null; then
        log_warn "✗ firewalld not installed"
        return 1
    fi
    
    if ! sudo systemctl is-active --quiet firewalld; then
        log_warn "✗ firewalld not running"
        return 1
    fi
    
    # Check if SSH is in trusted zone
    local ssh_ok=false
    if sudo firewall-cmd --zone=trusted --query-service=ssh &> /dev/null; then
        ssh_ok=true
    fi
    
    # Check if Cockpit is in trusted zone
    local cockpit_ok=false
    if sudo firewall-cmd --zone=trusted --query-service=cockpit &> /dev/null; then
        cockpit_ok=true
    fi
    
    if [[ "${ssh_ok}" == "true" ]] && [[ "${cockpit_ok}" == "true" ]]; then
        log_success "✓ Firewall configured for remote access"
        return 0
    else
        log_warn "⚠ Firewall may not be fully configured"
        return 1
    fi
}

# Check sudo access
check_sudo() {
    log_info "Checking sudo configuration..."
    
    local sudoers_file="/etc/sudoers.d/99-bazzite-pipe-admin"
    
    if [[ -f "${sudoers_file}" ]]; then
        log_success "✓ Passwordless sudo configured"
        return 0
    else
        log_info "ℹ Passwordless sudo not configured (may not be needed)"
        return 0
    fi
}

# Display comprehensive status
show_status() {
    print_separator
    echo "Remote Access Status Report"
    print_separator
    echo ""
    
    # Component status
    echo "Component Status:"
    echo ""
    
    local zerotier_ok=false
    local ssh_ok=false
    local cockpit_ok=false
    local firewall_ok=false
    
    if check_zerotier 2>/dev/null; then
        zerotier_ok=true
    fi
    
    if check_ssh 2>/dev/null; then
        ssh_ok=true
    fi
    
    if check_cockpit 2>/dev/null; then
        cockpit_ok=true
    fi
    
    if check_firewall 2>/dev/null; then
        firewall_ok=true
    fi
    
    check_sudo 2>/dev/null
    
    echo ""
    print_separator
    
    # Connection information
    local zt_ip
    zt_ip=$(get_zerotier_ip)
    
    local zt_network
    zt_network=$(get_zerotier_network)
    
    if [[ -n "${zt_ip}" ]]; then
        echo "Connection Information:"
        echo ""
        echo "ZeroTier Network:"
        echo "  Network ID: ${zt_network:-Unknown}"
        echo "  IP Address: ${zt_ip}"
        echo ""
        
        if [[ "${ssh_ok}" == "true" ]]; then
            echo "SSH Access:"
            echo "  ssh ${USER}@${zt_ip}"
            echo ""
        fi
        
        if [[ "${cockpit_ok}" == "true" ]]; then
            echo "Cockpit Web Console:"
            echo "  https://${zt_ip}:9090"
            echo ""
        fi
    else
        echo "⚠ ZeroTier IP not available"
        echo ""
        echo "Please ensure:"
        echo "  1. ZeroTier is installed and running"
        echo "  2. You are connected to a ZeroTier network"
        echo "  3. The network is authorized in ZeroTier Central"
        echo ""
    fi
    
    print_separator
    
    # Overall status
    echo "Overall Status:"
    echo ""
    
    if [[ "${zerotier_ok}" == "true" ]] && [[ "${ssh_ok}" == "true" ]]; then
        log_success "✓ Remote access is configured and ready!"
        echo ""
        echo "You can now connect from another machine on the same ZeroTier network."
        return 0
    else
        log_warn "⚠ Remote access setup is incomplete"
        echo ""
        echo "Missing components:"
        [[ "${zerotier_ok}" == "false" ]] && echo "  • ZeroTier network connection"
        [[ "${ssh_ok}" == "false" ]] && echo "  • SSH server"
        [[ "${cockpit_ok}" == "false" ]] && echo "  • Cockpit web console (optional)"
        [[ "${firewall_ok}" == "false" ]] && echo "  • Firewall configuration"
        echo ""
        echo "Run the appropriate setup scripts to complete configuration."
        return 1
    fi
}

# Test connectivity from remote machine (if on ZeroTier)
test_connectivity() {
    log_info "Testing network connectivity..."
    
    local zt_ip
    zt_ip=$(get_zerotier_ip)
    
    if [[ -z "${zt_ip}" ]]; then
        log_warn "Cannot test connectivity without ZeroTier IP"
        return 1
    fi
    
    # Test if we can reach ourselves
    if ping -c 1 -W 2 "${zt_ip}" &> /dev/null; then
        log_success "✓ ZeroTier interface is reachable"
    else
        log_warn "✗ Cannot reach ZeroTier interface"
        return 1
    fi
    
    # Test SSH port
    if timeout 2 bash -c "echo > /dev/tcp/${zt_ip}/22" 2>/dev/null; then
        log_success "✓ SSH port (22) is accessible"
    else
        log_warn "✗ SSH port (22) is not accessible"
    fi
    
    # Test Cockpit port
    if timeout 2 bash -c "echo > /dev/tcp/${zt_ip}/9090" 2>/dev/null; then
        log_success "✓ Cockpit port (9090) is accessible"
    else
        log_info "ℹ Cockpit port (9090) is not accessible (may not be installed)"
    fi
}

# Display troubleshooting tips
show_troubleshooting() {
    echo ""
    print_separator
    echo "Troubleshooting Tips:"
    print_separator
    echo ""
    echo "If you cannot connect:"
    echo ""
    echo "1. Verify ZeroTier connection:"
    echo "   zerotier-cli listnetworks"
    echo ""
    echo "2. Check SSH service:"
    echo "   sudo systemctl status sshd"
    echo ""
    echo "3. Check firewall rules:"
    echo "   sudo firewall-cmd --list-all --zone=trusted"
    echo ""
    echo "4. Test from remote machine:"
    echo "   ping <zerotier-ip>"
    echo "   ssh <user>@<zerotier-ip>"
    echo ""
    echo "5. Check logs:"
    echo "   sudo journalctl -u sshd -n 50"
    echo "   sudo journalctl -u zerotier-one -n 50"
    echo ""
}

# Main function
main() {
    print_header "Remote Access Verification"
    
    # Parse arguments
    parse_args "$@"
    
    # Show status
    show_status
    
    echo ""
    
    # Test connectivity
    test_connectivity 2>/dev/null || true
    
    # Show troubleshooting tips
    show_troubleshooting
    
    log_info "Verification complete"
}

main "$@"
