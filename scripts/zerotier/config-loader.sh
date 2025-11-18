#!/usr/bin/env bash
set -euo pipefail

# Script: config-loader.sh
# Purpose: Load ZeroTier configuration from a URL or local file and join network
# Usage: ./config-loader.sh <config-url-or-path>

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Source common utilities
# shellcheck disable=SC1091
if [[ -n "${BAZZITE_PIPE_COMMON_DIR:-}" ]]; then
    # Running from quick-setup.sh or similar - use provided path
    source "${BAZZITE_PIPE_COMMON_DIR}/utils.sh"
else
    # Running from repo - use relative path
    source "${SCRIPT_DIR}/../common/utils.sh"
fi

# Constants
readonly TEMP_CONFIG="/tmp/zerotier-config-$$.json"
readonly ZEROTIER_CLI="zerotier-cli"

# Cleanup temp files on exit
cleanup_temp() {
    if [[ -f "${TEMP_CONFIG}" ]]; then
        rm -f "${TEMP_CONFIG}"
    fi
}
trap cleanup_temp EXIT

# Check if jq is available for JSON parsing
check_json_parser() {
    if ! check_command jq; then
        log_warn "jq not found, using basic parsing (less reliable)"
        return 1
    fi
    return 0
}

# Download configuration from URL
download_config() {
    local url="$1"
    local output="$2"
    
    log_info "Downloading configuration from: ${url}"
    
    if check_command curl; then
        if curl -fsSL -o "${output}" "${url}"; then
            log_success "Configuration downloaded successfully"
            return 0
        else
            log_error "Failed to download configuration with curl"
            return 1
        fi
    elif check_command wget; then
        if wget -q -O "${output}" "${url}"; then
            log_success "Configuration downloaded successfully"
            return 0
        else
            log_error "Failed to download configuration with wget"
            return 1
        fi
    else
        log_error "Neither curl nor wget is available"
        return 1
    fi
}

# Parse JSON configuration with jq
parse_config_jq() {
    local config_file="$1"
    
    if ! check_command jq; then
        return 1
    fi
    
    # Extract network ID
    NETWORK_ID=$(jq -r '.network_id // empty' "${config_file}" 2>/dev/null || echo "")
    NETWORK_NAME=$(jq -r '.network_name // empty' "${config_file}" 2>/dev/null || echo "")
    DESCRIPTION=$(jq -r '.description // empty' "${config_file}" 2>/dev/null || echo "")
    
    if [[ -z "${NETWORK_ID}" ]]; then
        log_error "Failed to parse network_id from configuration"
        return 1
    fi
    
    return 0
}

# Parse JSON configuration without jq (basic fallback)
parse_config_basic() {
    local config_file="$1"
    
    # Extract network_id using grep and sed
    NETWORK_ID=$(grep -o '"network_id"[[:space:]]*:[[:space:]]*"[^"]*"' "${config_file}" | sed 's/.*"network_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    NETWORK_NAME=$(grep -o '"network_name"[[:space:]]*:[[:space:]]*"[^"]*"' "${config_file}" | sed 's/.*"network_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    DESCRIPTION=$(grep -o '"description"[[:space:]]*:[[:space:]]*"[^"]*"' "${config_file}" | sed 's/.*"description"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    
    if [[ -z "${NETWORK_ID}" ]]; then
        log_error "Failed to parse network_id from configuration"
        return 1
    fi
    
    return 0
}

# Validate network ID format
validate_network_id() {
    local network_id="$1"
    
    if [[ ! "${network_id}" =~ ^[0-9a-fA-F]{16}$ ]]; then
        log_error "Invalid network ID format: ${network_id}"
        log_error "Network ID must be 16 hexadecimal characters"
        return 1
    fi
    
    return 0
}

# Join network using the manager script
join_network() {
    local network_id="$1"
    
    if [[ ! -x "${SCRIPT_DIR}/manager.sh" ]]; then
        log_error "Manager script not found or not executable: ${SCRIPT_DIR}/manager.sh"
        return 1
    fi
    
    log_info "Joining network: ${network_id}"
    if [[ -n "${NETWORK_NAME}" ]]; then
        log_info "Network name: ${NETWORK_NAME}"
    fi
    if [[ -n "${DESCRIPTION}" ]]; then
        log_info "Description: ${DESCRIPTION}"
    fi
    
    # Use the manager script to join
    if "${SCRIPT_DIR}/manager.sh" join "${network_id}"; then
        log_success "Successfully joined network"
        return 0
    else
        log_error "Failed to join network"
        return 1
    fi
}

# Display configuration info
show_config_info() {
    local config_file="$1"
    
    print_header "Configuration Information"
    
    echo "Network ID: ${NETWORK_ID}"
    
    if [[ -n "${NETWORK_NAME}" ]]; then
        echo "Network Name: ${NETWORK_NAME}"
    fi
    
    if [[ -n "${DESCRIPTION}" ]]; then
        echo "Description: ${DESCRIPTION}"
    fi
    
    echo ""
}

# Main function
main() {
    local config_source="${1:-}"
    
    # Check if config source is provided
    if [[ -z "${config_source}" ]]; then
        log_error "No configuration source provided"
        cat <<EOF

Usage: ${SCRIPT_NAME} <config-url-or-path>

Examples:
    # Load from GitHub raw URL
    sudo ${SCRIPT_NAME} https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/zerotier-config.json
    
    # Load from local file
    sudo ${SCRIPT_NAME} /path/to/config.json

Configuration file format (JSON):
{
  "network_id": "16-character-hex-id",
  "network_name": "optional-name",
  "description": "optional-description"
}

EOF
        exit 1
    fi
    
    # Check if running as root
    if ! is_root; then
        log_error "This script must be run with sudo or as root"
        log_info "Try: sudo ${SCRIPT_NAME} ${config_source}"
        exit 1
    fi
    
    # Check if ZeroTier is installed
    if ! check_command "${ZEROTIER_CLI}"; then
        log_error "ZeroTier is not installed"
        log_info "Please run the installation script first:"
        log_info "  ${SCRIPT_DIR}/install.sh"
        exit 1
    fi
    
    # Determine if source is URL or local file
    if [[ "${config_source}" =~ ^https?:// ]]; then
        # Download from URL
        if ! download_config "${config_source}" "${TEMP_CONFIG}"; then
            exit 1
        fi
        CONFIG_FILE="${TEMP_CONFIG}"
    elif [[ -f "${config_source}" ]]; then
        # Use local file
        log_info "Using local configuration file: ${config_source}"
        CONFIG_FILE="${config_source}"
    else
        log_error "Configuration source not found: ${config_source}"
        exit 1
    fi
    
    # Parse configuration
    log_info "Parsing configuration..."
    
    if check_json_parser; then
        if ! parse_config_jq "${CONFIG_FILE}"; then
            log_warn "jq parsing failed, trying basic parser"
            if ! parse_config_basic "${CONFIG_FILE}"; then
                exit 1
            fi
        fi
    else
        if ! parse_config_basic "${CONFIG_FILE}"; then
            exit 1
        fi
    fi
    
    # Validate network ID
    if ! validate_network_id "${NETWORK_ID}"; then
        exit 1
    fi
    
    # Show configuration info
    show_config_info "${CONFIG_FILE}"
    
    # Confirm before joining
    if ! confirm "Join this ZeroTier network?" "y"; then
        log_info "Cancelled by user"
        exit 0
    fi
    
    # Join the network
    if join_network "${NETWORK_ID}"; then
        log_success "Configuration applied successfully!"
        echo ""
        log_info "Next steps:"
        log_info "1. Authorize this device in ZeroTier Central:"
        log_info "   https://my.zerotier.com/network/${NETWORK_ID}"
        log_info "2. Check status with: ${SCRIPT_DIR}/manager.sh status"
        log_info "3. Test connectivity with: ${SCRIPT_DIR}/test.sh"
    else
        log_error "Failed to apply configuration"
        exit 1
    fi
}

# Run main function
main "$@"
