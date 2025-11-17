#!/usr/bin/env bash
set -euo pipefail

# Script: install.sh
# Purpose: Main entry point for bazzite-pipe script management system
# Usage: curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/install.sh | bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly REPO_URL="https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main"

# Color codes for output
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'

# Logging functions (inline for standalone operation)
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1"
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $1" >&2
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1" >&2
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $1"
}

print_separator() {
    local char="${1:--}"
    local width="${2:-80}"
    printf '%*s\n' "${width}" '' | tr ' ' "${char}"
}

print_header() {
    echo ""
    print_separator "="
    echo -e "${COLOR_CYAN}$1${COLOR_RESET}"
    print_separator "="
    echo ""
}

# Check if running on Bazzite
is_bazzite() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        if [[ "${ID}" == "bazzite" ]] || [[ "${NAME}" == *"Bazzite"* ]]; then
            return 0
        fi
    fi
    
    if [[ -f /usr/share/ublue-os/bazzite-release ]] || [[ -f /etc/bazzite-release ]]; then
        return 0
    fi
    
    return 1
}

# Check if command exists
check_command() {
    command -v "$1" &> /dev/null
}

# Confirm action
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    
    if [[ "${default}" == "y" ]]; then
        prompt="${prompt} [Y/n]: "
    else
        prompt="${prompt} [y/N]: "
    fi
    
    read -r -p "${prompt}" response
    response="${response:-${default}}"
    
    case "${response}" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Download and run a script from the repository
run_remote_script() {
    local script_path="$1"
    shift
    local args=("$@")
    
    local url="${REPO_URL}/${script_path}"
    
    log_info "Downloading ${script_path}..."
    
    if check_command curl; then
        if curl -fsSL "${url}" | bash -s -- "${args[@]}"; then
            return 0
        else
            log_error "Failed to run remote script"
            return 1
        fi
    else
        log_error "curl is not installed"
        log_info "Please install curl: sudo rpm-ostree install curl"
        return 1
    fi
}

# Run local script
run_local_script() {
    local script_path="$1"
    shift
    local args=("$@")
    
    local full_path="${SCRIPT_DIR}/${script_path}"
    
    if [[ ! -f "${full_path}" ]]; then
        log_error "Script not found: ${full_path}"
        return 1
    fi
    
    if [[ ! -x "${full_path}" ]]; then
        chmod +x "${full_path}"
    fi
    
    "${full_path}" "${args[@]}"
}

# Display main menu
show_main_menu() {
    print_header "bazzite-pipe - Bazzite OS Script Manager"
    
    echo "Available Features:"
    echo ""
    echo "1. ZeroTier Network Manager"
    echo "   - Install and configure ZeroTier CLI"
    echo "   - Manage network connections"
    echo "   - Test connectivity"
    echo ""
    echo "2. System Information"
    echo "   - Display system details"
    echo ""
    echo "3. Exit"
    echo ""
}

# ZeroTier submenu
zerotier_menu() {
    while true; do
        print_header "ZeroTier Network Manager"
        
        echo "1. Install ZeroTier"
        echo "2. Manage Connections (requires ZeroTier installed)"
        echo "3. Test Network (requires ZeroTier installed)"
        echo "4. Back to Main Menu"
        echo ""
        
        read -r -p "Select an option (1-4): " choice
        echo ""
        
        case "${choice}" in
            1)
                log_info "Starting ZeroTier installation..."
                if [[ -f "${SCRIPT_DIR}/scripts/zerotier/install.sh" ]]; then
                    run_local_script "scripts/zerotier/install.sh"
                else
                    run_remote_script "scripts/zerotier/install.sh"
                fi
                ;;
            2)
                if [[ -f "${SCRIPT_DIR}/scripts/zerotier/manager.sh" ]]; then
                    run_local_script "scripts/zerotier/manager.sh"
                else
                    run_remote_script "scripts/zerotier/manager.sh"
                fi
                ;;
            3)
                if [[ -f "${SCRIPT_DIR}/scripts/zerotier/test.sh" ]]; then
                    run_local_script "scripts/zerotier/test.sh"
                else
                    run_remote_script "scripts/zerotier/test.sh"
                fi
                ;;
            4)
                return 0
                ;;
            *)
                log_error "Invalid option: ${choice}"
                ;;
        esac
        
        echo ""
        read -r -p "Press Enter to continue..."
    done
}

# Show system information
show_system_info() {
    print_header "System Information"
    
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        echo "OS: ${NAME} ${VERSION}"
    fi
    
    echo "Architecture: $(uname -m)"
    echo "Uptime: $(uptime -p)"
    
    if check_command rpm-ostree; then
        echo ""
        echo "rpm-ostree Status:"
        rpm-ostree status --booted
    fi
    
    echo ""
}

# Display usage
usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS] [COMMAND]

Main entry point for bazzite-pipe script management system.

OPTIONS:
    -h, --help              Display this help message
    -v, --version           Display version information

COMMANDS:
    menu                    Show interactive menu (default)
    zerotier                ZeroTier management submenu
    info                    Display system information

EXAMPLES:
    # Interactive menu
    ${SCRIPT_NAME}

    # Run from web (recommended)
    curl -fsSL ${REPO_URL}/install.sh | bash

    # ZeroTier submenu
    ${SCRIPT_NAME} zerotier

    # System info
    ${SCRIPT_NAME} info

PROJECT:
    Repository: https://github.com/AutoMas0n/bazzite-pipe
    Documentation: https://github.com/AutoMas0n/bazzite-pipe/blob/main/README.md

EOF
}

# Display version
show_version() {
    echo "bazzite-pipe v0.1.0-dev"
    echo "Copyright (c) 2025 AutoMas0n"
    echo "License: MIT"
}

# Verify environment
verify_environment() {
    log_info "Verifying environment..."
    
    # Check if on Bazzite
    if ! is_bazzite; then
        log_warn "This script is designed for Bazzite OS"
        log_warn "It may work on other rpm-ostree systems, but is not tested"
        echo ""
        
        if ! confirm "Continue anyway?"; then
            log_info "Exiting"
            exit 0
        fi
    else
        log_success "Running on Bazzite OS"
    fi
    
    # Check for required commands
    local missing_commands=()
    
    if ! check_command curl; then
        missing_commands+=("curl")
    fi
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_warn "Missing recommended commands: ${missing_commands[*]}"
        log_info "Some features may not work without these commands"
        echo ""
    fi
}

# Main interactive loop
interactive_mode() {
    verify_environment
    
    while true; do
        show_main_menu
        read -r -p "Select an option (1-3): " choice
        echo ""
        
        case "${choice}" in
            1)
                zerotier_menu
                ;;
            2)
                show_system_info
                read -r -p "Press Enter to continue..."
                ;;
            3)
                log_info "Goodbye!"
                exit 0
                ;;
            *)
                log_error "Invalid option: ${choice}"
                sleep 1
                ;;
        esac
        
        clear
    done
}

# Main function
main() {
    # Parse arguments
    case "${1:-menu}" in
        menu|interactive)
            interactive_mode
            ;;
        zerotier|zt)
            verify_environment
            zerotier_menu
            ;;
        info|sysinfo)
            show_system_info
            ;;
        -v|--version|version)
            show_version
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            log_error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
