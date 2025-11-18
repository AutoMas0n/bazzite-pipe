#!/usr/bin/env bash
set -euo pipefail

# Script: quick-setup.sh
# Purpose: One-liner setup script for full remote admin access (ZeroTier + SSH + Cockpit)
# Usage: curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | bash -s -- --admin-key "ssh-ed25519 AAAA..."

readonly REPO_URL="https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main"
readonly DEFAULT_CONFIG_URL="${REPO_URL}/zerotier-config.json"

# Default options
ADMIN_KEY=""
CONFIG_URL="${DEFAULT_CONFIG_URL}"
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
Usage: quick-setup.sh [OPTIONS]

One-liner setup for full remote admin access to Bazzite OS.

OPTIONS:
    --admin-key <key>     Admin's SSH public key (required)
    --config-url <url>    ZeroTier config URL (default: repo config)
    --no-cockpit          Skip Cockpit installation
    --no-firewall         Skip firewall configuration
    -h, --help           Show this help message

EXAMPLES:
    # Full setup with your SSH key
    curl -fsSL ${REPO_URL}/quick-setup.sh | bash -s -- \\
      --admin-key "ssh-ed25519 AAAAC3Nz... admin@host"
    
    # With custom ZeroTier config
    curl -fsSL ${REPO_URL}/quick-setup.sh | bash -s -- \\
      --admin-key "ssh-ed25519 AAAAC3Nz..." \\
      --config-url "https://example.com/config.json"
    
    # ZeroTier and SSH only (no Cockpit)
    curl -fsSL ${REPO_URL}/quick-setup.sh | bash -s -- \\
      --admin-key "ssh-ed25519 AAAAC3Nz..." \\
      --no-cockpit

WHAT THIS DOES:
    1. Installs and configures ZeroTier
    2. Joins your ZeroTier network
    3. Sets up SSH with key-based authentication
    4. Installs Cockpit web console (optional)
    5. Configures firewall for secure access
    6. Displays connection information

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

log_info "bazzite-pipe Quick Setup - Full Remote Admin Access"
log_info "===================================================="
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

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

# Download required scripts
log_info "Downloading scripts..."
mkdir -p "${TEMP_DIR}/common" "${TEMP_DIR}/zerotier" "${TEMP_DIR}/remote-access"

# Common utilities
if ! curl -fsSL -o "${TEMP_DIR}/common/utils.sh" "${REPO_URL}/scripts/common/utils.sh"; then
    log_error "Failed to download utilities"
    exit 1
fi

if ! curl -fsSL -o "${TEMP_DIR}/common/config.sh" "${REPO_URL}/scripts/common/config.sh"; then
    log_error "Failed to download config utilities"
    exit 1
fi

# ZeroTier scripts
if ! curl -fsSL -o "${TEMP_DIR}/zerotier/config-loader.sh" "${REPO_URL}/scripts/zerotier/config-loader.sh"; then
    log_error "Failed to download config-loader"
    exit 1
fi

if ! curl -fsSL -o "${TEMP_DIR}/zerotier/manager.sh" "${REPO_URL}/scripts/zerotier/manager.sh"; then
    log_error "Failed to download manager"
    exit 1
fi

# Remote access scripts
if ! curl -fsSL -o "${TEMP_DIR}/remote-access/ssh-setup.sh" "${REPO_URL}/scripts/remote-access/ssh-setup.sh"; then
    log_error "Failed to download SSH setup script"
    exit 1
fi

if [[ "${INSTALL_COCKPIT}" == "true" ]]; then
    if ! curl -fsSL -o "${TEMP_DIR}/remote-access/cockpit-setup.sh" "${REPO_URL}/scripts/remote-access/cockpit-setup.sh"; then
        log_error "Failed to download Cockpit setup script"
        exit 1
    fi
fi

if [[ "${SETUP_FIREWALL}" == "true" ]]; then
    if ! curl -fsSL -o "${TEMP_DIR}/remote-access/firewall-setup.sh" "${REPO_URL}/scripts/remote-access/firewall-setup.sh"; then
        log_error "Failed to download firewall setup script"
        exit 1
    fi
fi

if ! curl -fsSL -o "${TEMP_DIR}/remote-access/verify.sh" "${REPO_URL}/scripts/remote-access/verify.sh"; then
    log_error "Failed to download verification script"
    exit 1
fi

# Make scripts executable and ensure temp dir is accessible
chmod +x "${TEMP_DIR}"/zerotier/*.sh
chmod +x "${TEMP_DIR}"/remote-access/*.sh
chmod +x "${TEMP_DIR}"/common/*.sh

# Ensure temp directory is accessible to the original user
if [[ "${EUID}" -eq 0 ]] && [[ -n "${ORIGINAL_USER}" ]] && [[ "${ORIGINAL_USER}" != "root" ]]; then
    chmod -R 755 "${TEMP_DIR}"
fi

# Export the temp directory so scripts can find common utilities
# This allows scripts to source utils.sh even when run from temp directory
export BAZZITE_PIPE_COMMON_DIR="${TEMP_DIR}/common"

# Step 1: ZeroTier setup
log_info "Step 1: Setting up ZeroTier..."
echo ""
if ! bash "${TEMP_DIR}/zerotier/config-loader.sh" "${CONFIG_URL}"; then
    log_error "ZeroTier setup failed"
    exit 1
fi
echo ""

# Step 2: SSH setup
log_info "Step 2: Configuring SSH remote access..."
echo ""
# Run SSH setup - when run via sudo, the script can use sudo without password
# because we're in the same sudo session
if ! bash "${TEMP_DIR}/remote-access/ssh-setup.sh" --public-key "${ADMIN_KEY}" --user "${ORIGINAL_USER}" --skip-root-check; then
    log_error "SSH setup failed"
    exit 1
fi
echo ""

# Step 3: Cockpit setup (optional)
if [[ "${INSTALL_COCKPIT}" == "true" ]]; then
    log_info "Step 3: Installing Cockpit web console..."
    echo ""
    if bash "${TEMP_DIR}/remote-access/cockpit-setup.sh" --no-firewall; then
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
    if bash "${TEMP_DIR}/remote-access/firewall-setup.sh"; then
        log_success "Firewall configured successfully"
    else
        log_warn "Firewall configuration had issues (continuing anyway)"
    fi
    echo ""
fi

# Step 5: Verify setup
log_info "Verifying setup..."
echo ""
bash "${TEMP_DIR}/remote-access/verify.sh"

log_success "Quick setup complete!"
echo ""
log_info "Your machine is now accessible remotely via ZeroTier!"
log_info ""
log_info "For full management features, clone the repository:"
log_info "  git clone https://github.com/AutoMas0n/bazzite-pipe.git"
log_info "  cd bazzite-pipe"
log_info "  ./install.sh"
