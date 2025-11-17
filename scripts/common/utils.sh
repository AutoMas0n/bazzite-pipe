#!/usr/bin/env bash
# Script: utils.sh
# Purpose: Common utility functions for bazzite-pipe scripts
# Usage: Source this file in other scripts

# Color codes for output
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_BLUE='\033[0;34m'

# Log levels
readonly LOG_INFO="INFO"
readonly LOG_WARN="WARN"
readonly LOG_ERROR="ERROR"

# Logging functions
log_info() {
    local message="$1"
    echo -e "${COLOR_BLUE}[${LOG_INFO}]${COLOR_RESET} ${message}"
}

log_warn() {
    local message="$1"
    echo -e "${COLOR_YELLOW}[${LOG_WARN}]${COLOR_RESET} ${message}" >&2
}

log_error() {
    local message="$1"
    echo -e "${COLOR_RED}[${LOG_ERROR}]${COLOR_RESET} ${message}" >&2
}

log_success() {
    local message="$1"
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} ${message}"
}

# Check if a command exists
check_command() {
    local cmd="$1"
    if command -v "${cmd}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Verify running on Bazzite OS
is_bazzite() {
    # Check for Bazzite-specific indicators
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        if [[ "${ID}" == "bazzite" ]] || [[ "${NAME}" == *"Bazzite"* ]]; then
            return 0
        fi
    fi
    
    # Check for Universal Blue/Bazzite specific files
    if [[ -f /usr/share/ublue-os/bazzite-release ]] || [[ -f /etc/bazzite-release ]]; then
        return 0
    fi
    
    return 1
}

# Ensure script runs with root privileges
require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check if running with root privileges (without exiting)
is_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Backup a file before modifying it
backup_file() {
    local file="$1"
    local backup_suffix="${2:-.bak}"
    
    if [[ ! -f "${file}" ]]; then
        log_warn "File does not exist, skipping backup: ${file}"
        return 1
    fi
    
    local backup_path="${file}${backup_suffix}"
    local counter=1
    
    # If backup already exists, add a number
    while [[ -f "${backup_path}" ]]; do
        backup_path="${file}${backup_suffix}.${counter}"
        ((counter++))
    done
    
    if cp -p "${file}" "${backup_path}"; then
        log_info "Backed up ${file} to ${backup_path}"
        return 0
    else
        log_error "Failed to backup ${file}"
        return 1
    fi
}

# Prompt user for yes/no confirmation
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

# Check if a systemd service exists
service_exists() {
    local service="$1"
    if systemctl list-unit-files "${service}.service" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Check if a systemd service is active
service_is_active() {
    local service="$1"
    if systemctl is-active --quiet "${service}.service"; then
        return 0
    else
        return 1
    fi
}

# Check if a systemd service is enabled
service_is_enabled() {
    local service="$1"
    if systemctl is-enabled --quiet "${service}.service" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Install a package using rpm-ostree (Bazzite's package manager)
install_package() {
    local package="$1"
    
    log_info "Installing package: ${package}"
    
    if ! is_root; then
        log_error "Root privileges required to install packages"
        return 1
    fi
    
    # Check if package is already layered
    if rpm-ostree status | grep -q "LayeredPackages:" && \
       rpm-ostree status | grep -A 100 "LayeredPackages:" | grep -q "^[[:space:]]*${package}$"; then
        log_info "Package ${package} is already installed"
        return 0
    fi
    
    # Install the package
    if rpm-ostree install -y "${package}"; then
        log_success "Package ${package} installed successfully"
        log_warn "A system reboot may be required to use the new package"
        return 0
    else
        log_error "Failed to install package: ${package}"
        return 1
    fi
}

# Check if a package is installed
package_is_installed() {
    local package="$1"
    
    # Check if package is layered via rpm-ostree
    if rpm-ostree status | grep -q "LayeredPackages:" && \
       rpm-ostree status | grep -A 100 "LayeredPackages:" | grep -q "^[[:space:]]*${package}$"; then
        return 0
    fi
    
    # Check if command from package exists (fallback)
    if check_command "${package}"; then
        return 0
    fi
    
    return 1
}

# Create directory if it doesn't exist
ensure_directory() {
    local dir="$1"
    local mode="${2:-755}"
    
    if [[ ! -d "${dir}" ]]; then
        if mkdir -p "${dir}"; then
            chmod "${mode}" "${dir}"
            log_info "Created directory: ${dir}"
            return 0
        else
            log_error "Failed to create directory: ${dir}"
            return 1
        fi
    fi
    return 0
}

# Write content to a file safely (with backup)
write_file() {
    local file="$1"
    local content="$2"
    local backup="${3:-true}"
    
    # Backup existing file if requested
    if [[ "${backup}" == "true" ]] && [[ -f "${file}" ]]; then
        backup_file "${file}" || return 1
    fi
    
    # Write content
    if echo "${content}" > "${file}"; then
        log_info "Wrote to file: ${file}"
        return 0
    else
        log_error "Failed to write to file: ${file}"
        return 1
    fi
}

# Check network connectivity
check_network() {
    local test_host="${1:-8.8.8.8}"
    
    if ping -c 1 -W 2 "${test_host}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Display a spinner while running a command
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while ps -p "${pid}" > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "${spinstr}"
        local spinstr=${temp}${spinstr%"$temp"}
        sleep ${delay}
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Run a command with a spinner
run_with_spinner() {
    local message="$1"
    shift
    local cmd=("$@")
    
    echo -n "${message}... "
    "${cmd[@]}" &> /dev/null &
    local pid=$!
    spinner ${pid}
    wait ${pid}
    local exit_code=$?
    
    if [[ ${exit_code} -eq 0 ]]; then
        echo "✓"
        return 0
    else
        echo "✗"
        return ${exit_code}
    fi
}

# Print a separator line
print_separator() {
    local char="${1:--}"
    local width="${2:-80}"
    printf '%*s\n' "${width}" '' | tr ' ' "${char}"
}

# Print a header
print_header() {
    local text="$1"
    echo ""
    print_separator "="
    echo "${text}"
    print_separator "="
    echo ""
}

# Validate IP address format
is_valid_ip() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ${ip} =~ ${regex} ]]; then
        # Check each octet is <= 255
        local IFS='.'
        local -a octets=(${ip})
        for octet in "${octets[@]}"; do
            if [[ ${octet} -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Get script directory (useful for sourcing other scripts)
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
}

# Cleanup function to be called on exit
cleanup() {
    local exit_code=$?
    # Add cleanup tasks here if needed
    exit ${exit_code}
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM
