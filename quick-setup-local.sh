#!/usr/bin/env bash
set -euo pipefail

# Script: quick-setup-local.sh
# Purpose: LOCAL TESTING VERSION - One-liner setup script for full remote admin access
# Usage: sudo bash quick-setup-local.sh --admin-key "ssh-ed25519 AAAA..."

readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default options
ADMIN_KEY=""
CONFIG_URL="${REPO_DIR}/zerotier-config.json"
INSTALL_COCKPIT=true
SETUP_FIREWALL=true

# Color codes
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_BLUE='\033[0;34m'

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1" >&2
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $1"
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $1" >&2
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --admin-key)
                ADMIN_KEY="$2"
                shift 2
                ;;
            --config-url)
                CONFIG_URL="$2"
                shift 2
                ;;
            --no-cockpit)
                INSTALL_COCKPIT=false
                shift
                ;;
            --no-firewall)
                SETUP_FIREWALL=false
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
Usage: quick-setup-local.sh [OPTIONS]

LOCAL TESTING VERSION - One-liner setup for full remote admin access to Bazzite OS.

OPTIONS:
    --admin-key <key>     Admin's SSH public key (required)
    --config-url <url>    ZeroTier config URL (default: local config)
    --no-cockpit          Skip Cockpit installation
    --no-firewall         Skip firewall configuration
    -h, --help           Show this help message

EXAMPLES:
    # Full setup with your SSH key
    sudo bash quick-setup-local.sh --admin-key "ssh-ed25519 AAAAC3Nz... admin@host"

EOF
}

# Parse arguments
parse_args "$@"

# Validate required arguments
if [[ -z "${ADMIN_KEY}" ]]; then
    log_error "Admin SSH key is required"
    echo ""
    show_usage
    exit 1
fi

# Detect the original user if running with sudo
if [[ -n "${SUDO_USER:-}" ]]; then
    ORIGINAL_USER="${SUDO_USER}"
else
    ORIGINAL_USER="${USER}"
fi

log_info "bazzite-pipe Quick Setup - Full Remote Admin Access (LOCAL TEST)"
log_info "=================================================================="
echo ""
log_info "This script will set up complete remote admin access:"
log_info "  1. Install and configure ZeroTier"
log_info "  2. Join ZeroTier network from: ${CONFIG_URL}"
log_info "  3. Configure SSH with key-based authentication"
if [[ "${INSTALL_COCKPIT}" == "true" ]]; then
    log_info "  4. Install Cockpit web console"
fi
if [[ "${SETUP_FIREWALL}" == "true" ]]; then
    log_info "  5. Configure firewall for secure access"
fi
echo ""

# Export the repo directory so scripts can find common utilities
export BAZZITE_PIPE_COMMON_DIR="${REPO_DIR}/scripts/common"

# Step 1: ZeroTier setup
log_info "Step 1: Setting up ZeroTier..."
echo ""
if ! bash "${REPO_DIR}/scripts/zerotier/config-loader.sh" "${CONFIG_URL}"; then
    log_error "ZeroTier setup failed"
    exit 1
fi
echo ""

# Step 2: SSH setup
log_info "Step 2: Configuring SSH remote access..."
echo ""
if ! bash "${REPO_DIR}/scripts/remote-access/ssh-setup.sh" --public-key "${ADMIN_KEY}" --user "${ORIGINAL_USER}" --skip-root-check; then
    log_error "SSH setup failed"
    exit 1
fi
echo ""

# Step 3: Cockpit setup (optional)
if [[ "${INSTALL_COCKPIT}" == "true" ]]; then
    log_info "Step 3: Installing Cockpit web console..."
    echo ""
    if bash "${REPO_DIR}/scripts/remote-access/cockpit-setup.sh" --no-firewall --skip-root-check; then
        log_success "Cockpit installed successfully"
    else
        log_warn "Cockpit installation had issues (continuing anyway)"
    fi
    echo ""
fi

# Step 4: Firewall setup (optional)
if [[ "${SETUP_FIREWALL}" == "true" ]]; then
    log_info "Step 4: Configuring firewall..."
    echo ""
    if bash "${REPO_DIR}/scripts/remote-access/firewall-setup.sh" --skip-root-check; then
        log_success "Firewall configured successfully"
    else
        log_warn "Firewall configuration had issues (continuing anyway)"
    fi
    echo ""
fi

# Step 5: Verify setup
log_info "Verifying setup..."
echo ""
bash "${REPO_DIR}/scripts/remote-access/verify.sh"

log_success "Quick setup complete!"
echo ""
log_info "Your machine is now accessible remotely via ZeroTier!"
