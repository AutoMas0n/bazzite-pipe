#!/usr/bin/env bash
set -euo pipefail

# Script: test.sh
# Purpose: Test ZeroTier network connectivity and performance
# Usage: ./test.sh [--target IP] [--network NETWORK_ID]

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
readonly PING_COUNT=5
readonly PING_TIMEOUT=5

# Variables
TARGET_IP=""
NETWORK_ID=""
TEST_ALL=false

# Display usage
usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Test ZeroTier network connectivity and performance.

OPTIONS:
    -t, --target IP         Test connectivity to specific IP address
    -n, --network ID        Test peers on specific network
    -a, --all               Test all peers on all networks
    -h, --help              Display this help message

EXAMPLES:
    # Test all peers on saved network
    ${SCRIPT_NAME}

    # Test specific IP
    ${SCRIPT_NAME} --target 192.168.192.10

    # Test all peers on specific network
    ${SCRIPT_NAME} --network abc123def456 --all

EXIT CODES:
    0   All tests passed
    1   Some tests failed
    2   ZeroTier not running or not connected

EOF
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--target)
                TARGET_IP="$2"
                shift 2
                ;;
            -n|--network)
                NETWORK_ID="$2"
                shift 2
                ;;
            -a|--all)
                TEST_ALL=true
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

# Check ZeroTier is running
check_zerotier() {
    if ! check_command "${ZEROTIER_CLI}"; then
        log_error "ZeroTier CLI is not installed"
        log_info "Please run the installation script first"
        return 1
    fi
    
    if ! service_is_active "${ZEROTIER_SERVICE}"; then
        log_error "ZeroTier service is not running"
        log_info "Start it with: sudo systemctl start ${ZEROTIER_SERVICE}.service"
        return 1
    fi
    
    return 0
}

# Get network ID
get_network_id() {
    if [[ -n "${NETWORK_ID}" ]]; then
        return 0
    fi
    
    # Try to get from config
    NETWORK_ID=$(get_config "${CONFIG_KEY_NETWORK_ID}" "")
    
    if [[ -z "${NETWORK_ID}" ]]; then
        # Try to get first joined network
        NETWORK_ID=$(zerotier-cli listnetworks 2>/dev/null | grep -v "^200" | awk 'NR==1 {print $1}')
    fi
    
    if [[ -z "${NETWORK_ID}" ]]; then
        log_error "No network ID found"
        log_info "Join a network first or specify with --network"
        return 1
    fi
    
    return 0
}

# Get peers on network
get_network_peers() {
    local network_id="$1"
    local peers=()
    
    # Get list of peers from zerotier-cli
    local peer_list
    peer_list=$(zerotier-cli listpeers 2>/dev/null || echo "")
    
    if [[ -z "${peer_list}" ]]; then
        return 1
    fi
    
    # Parse peer list and extract IPs
    # This is a simplified approach - in reality, we'd need to correlate
    # peers with network members via the ZeroTier API
    
    # For now, we'll get the managed IPs from the network info
    local network_info
    network_info=$(zerotier-cli get "${network_id}" 2>/dev/null || echo "")
    
    # Extract assigned addresses
    local assigned_ips
    assigned_ips=$(zerotier-cli get "${network_id}" assignedAddresses 2>/dev/null || echo "")
    
    if [[ -n "${assigned_ips}" ]]; then
        # Parse JSON-like output (simplified)
        while IFS= read -r line; do
            if [[ "${line}" =~ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
                local ip="${BASH_REMATCH[1]}"
                # Don't include our own IP
                if ! ip addr show | grep -q "${ip}"; then
                    peers+=("${ip}")
                fi
            fi
        done <<< "${assigned_ips}"
    fi
    
    # Return peers as space-separated string
    echo "${peers[@]}"
}

# Ping test
ping_test() {
    local target="$1"
    local count="${2:-${PING_COUNT}}"
    
    log_info "Testing connectivity to ${target}..."
    
    # Run ping
    local ping_output
    if ping_output=$(ping -c "${count}" -W "${PING_TIMEOUT}" "${target}" 2>&1); then
        # Parse results
        local packet_loss
        packet_loss=$(echo "${ping_output}" | grep -oP '\d+(?=% packet loss)' || echo "100")
        
        local avg_latency
        avg_latency=$(echo "${ping_output}" | grep -oP 'avg = \K[\d.]+' || echo "N/A")
        
        if [[ "${packet_loss}" == "0" ]]; then
            log_success "✓ ${target} - Reachable (avg latency: ${avg_latency}ms)"
            return 0
        elif [[ "${packet_loss}" -lt "50" ]]; then
            log_warn "⚠ ${target} - Unstable (${packet_loss}% packet loss, avg: ${avg_latency}ms)"
            return 1
        else
            log_error "✗ ${target} - Poor connection (${packet_loss}% packet loss)"
            return 1
        fi
    else
        log_error "✗ ${target} - Unreachable"
        return 1
    fi
}

# Connection quality assessment
assess_connection_quality() {
    local latency="$1"
    
    if [[ "${latency}" == "N/A" ]]; then
        echo "Unknown"
        return
    fi
    
    # Convert to integer for comparison
    local latency_int
    latency_int=$(echo "${latency}" | cut -d'.' -f1)
    
    if [[ ${latency_int} -lt 50 ]]; then
        echo "Excellent"
    elif [[ ${latency_int} -lt 100 ]]; then
        echo "Good"
    elif [[ ${latency_int} -lt 150 ]]; then
        echo "Fair"
    else
        echo "Poor"
    fi
}

# Test single target
test_target() {
    local target="$1"
    
    print_header "Testing Target: ${target}"
    
    # Validate IP
    if ! is_valid_ip "${target}"; then
        log_error "Invalid IP address: ${target}"
        return 1
    fi
    
    # Run ping test
    if ping_test "${target}" "${PING_COUNT}"; then
        echo ""
        log_success "Connection test passed"
        return 0
    else
        echo ""
        log_error "Connection test failed"
        provide_troubleshooting
        return 1
    fi
}

# Test all peers
test_all_peers() {
    local network_id="$1"
    
    print_header "Testing All Peers on Network: ${network_id}"
    
    # Check network is joined and authorized
    if ! zerotier-cli listnetworks 2>/dev/null | grep "${network_id}" | grep -q "OK"; then
        log_error "Network ${network_id} is not connected or authorized"
        return 1
    fi
    
    log_info "Getting list of peers..."
    
    # Get our IP on this network
    local our_ip
    our_ip=$(zerotier-cli get "${network_id}" assignedAddresses 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1 || echo "")
    
    if [[ -z "${our_ip}" ]]; then
        log_error "Could not determine our IP on network ${network_id}"
        return 1
    fi
    
    log_info "Our IP: ${our_ip}"
    echo ""
    
    # Get network range
    local network_range
    network_range=$(zerotier-cli get "${network_id}" routes 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+/\d+' | head -1 || echo "")
    
    if [[ -z "${network_range}" ]]; then
        log_warn "Could not determine network range"
        log_info "Please specify target IPs manually"
        return 1
    fi
    
    log_info "Network range: ${network_range}"
    log_info "Note: Automatic peer discovery is limited. You may need to specify IPs manually."
    echo ""
    
    # For now, suggest manual testing
    log_info "To test specific peers, use:"
    log_info "  ${SCRIPT_NAME} --target <peer-ip>"
    
    return 0
}

# Provide troubleshooting suggestions
provide_troubleshooting() {
    echo ""
    print_separator "-"
    log_info "Troubleshooting Suggestions:"
    echo ""
    echo "1. Verify both devices are on the same ZeroTier network"
    echo "2. Check that both devices are authorized in ZeroTier Central"
    echo "3. Ensure ZeroTier service is running on both devices"
    echo "4. Check firewall settings on both devices"
    echo "5. Verify internet connectivity on both devices"
    echo "6. Try restarting the ZeroTier service:"
    echo "   sudo systemctl restart ${ZEROTIER_SERVICE}.service"
    echo ""
    echo "For more help, run diagnostics:"
    echo "  ${SCRIPT_DIR}/manager.sh diagnostics"
    print_separator "-"
}

# Run comprehensive network test
run_comprehensive_test() {
    print_header "ZeroTier Network Test"
    
    # Check ZeroTier status
    log_info "Checking ZeroTier status..."
    if ! check_zerotier; then
        exit 2
    fi
    log_success "ZeroTier is running"
    echo ""
    
    # Get network ID
    if ! get_network_id; then
        exit 2
    fi
    log_info "Testing network: ${NETWORK_ID}"
    echo ""
    
    # Check network status
    log_info "Checking network connection..."
    if zerotier-cli listnetworks 2>/dev/null | grep "${NETWORK_ID}" | grep -q "OK"; then
        log_success "Connected to network ${NETWORK_ID}"
    else
        log_error "Not connected to network ${NETWORK_ID}"
        log_info "Network may not be authorized. Check ZeroTier Central."
        exit 2
    fi
    echo ""
    
    # Get our IP
    local our_ip
    our_ip=$(zerotier-cli get "${NETWORK_ID}" assignedAddresses 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1 || echo "")
    
    if [[ -n "${our_ip}" ]]; then
        log_info "Our IP on network: ${our_ip}"
    else
        log_warn "Could not determine our IP address"
    fi
    echo ""
    
    # Test internet connectivity
    log_info "Testing internet connectivity..."
    if check_network; then
        log_success "Internet connection is working"
    else
        log_error "No internet connection detected"
        log_warn "ZeroTier requires internet connectivity to function"
    fi
    echo ""
    
    # Check peers
    log_info "Checking for peers..."
    local peer_count
    peer_count=$(zerotier-cli listpeers 2>/dev/null | grep -c "^200" || echo "0")
    
    if [[ ${peer_count} -gt 0 ]]; then
        log_info "Connected to ${peer_count} ZeroTier peers"
    else
        log_warn "No peers found"
    fi
    echo ""
    
    print_separator "="
    log_success "Network test complete"
    echo ""
    log_info "To test connectivity to a specific peer:"
    log_info "  ${SCRIPT_NAME} --target <peer-ip>"
}

# Main function
main() {
    # Parse arguments
    parse_args "$@"
    
    # Check ZeroTier is installed and running
    if ! check_zerotier; then
        exit 2
    fi
    
    # Determine what to test
    if [[ -n "${TARGET_IP}" ]]; then
        # Test specific target
        if test_target "${TARGET_IP}"; then
            exit 0
        else
            exit 1
        fi
    elif [[ "${TEST_ALL}" == "true" ]]; then
        # Test all peers
        if ! get_network_id; then
            exit 2
        fi
        
        if test_all_peers "${NETWORK_ID}"; then
            exit 0
        else
            exit 1
        fi
    else
        # Run comprehensive test
        run_comprehensive_test
        exit 0
    fi
}

# Run main function
main "$@"
