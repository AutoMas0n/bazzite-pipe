#!/usr/bin/env bash
set -euo pipefail

# Script: quick-setup.sh
# Purpose: One-liner setup script for joining ZeroTier network from config
# Usage: curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | sudo bash -s -- <config-url>

readonly REPO_URL="https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main"
readonly DEFAULT_CONFIG_URL="${REPO_URL}/zerotier-config.json"

# Color codes
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
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

# Check if running as root
if [[ "${EUID}" -ne 0 ]]; then
    log_error "This script must be run with sudo or as root"
    echo ""
    echo "Usage:"
    echo "  curl -fsSL ${REPO_URL}/quick-setup.sh | sudo bash"
    echo ""
    echo "Or with custom config:"
    echo "  curl -fsSL ${REPO_URL}/quick-setup.sh | sudo bash -s -- <config-url>"
    exit 1
fi

# Get config URL from argument or use default
CONFIG_URL="${1:-${DEFAULT_CONFIG_URL}}"

log_info "bazzite-pipe Quick Setup"
log_info "========================"
echo ""
log_info "This script will:"
log_info "1. Download the config-loader script"
log_info "2. Join the ZeroTier network specified in: ${CONFIG_URL}"
echo ""

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

# Download config-loader script
log_info "Downloading config-loader script..."
if ! curl -fsSL -o "${TEMP_DIR}/config-loader.sh" "${REPO_URL}/scripts/zerotier/config-loader.sh"; then
    log_error "Failed to download config-loader script"
    exit 1
fi

# Download common utilities
log_info "Downloading utilities..."
mkdir -p "${TEMP_DIR}/common"
if ! curl -fsSL -o "${TEMP_DIR}/common/utils.sh" "${REPO_URL}/scripts/common/utils.sh"; then
    log_error "Failed to download utilities"
    exit 1
fi

# Download manager script (needed by config-loader)
log_info "Downloading manager script..."
mkdir -p "${TEMP_DIR}/zerotier"
if ! curl -fsSL -o "${TEMP_DIR}/zerotier/manager.sh" "${REPO_URL}/scripts/zerotier/manager.sh"; then
    log_error "Failed to download manager script"
    exit 1
fi

# Make scripts executable
chmod +x "${TEMP_DIR}/config-loader.sh"
chmod +x "${TEMP_DIR}/zerotier/manager.sh"

# Adjust paths in config-loader to use temp directory
sed -i "s|SCRIPT_DIR=\".*\"|SCRIPT_DIR=\"${TEMP_DIR}\"|g" "${TEMP_DIR}/config-loader.sh"

# Run config-loader
log_info "Running configuration loader..."
echo ""

cd "${TEMP_DIR}"
bash "${TEMP_DIR}/config-loader.sh" "${CONFIG_URL}"

log_success "Quick setup complete!"
echo ""
log_info "For full management features, clone the repository:"
log_info "  git clone https://github.com/AutoMas0n/bazzite-pipe.git"
log_info "  cd bazzite-pipe"
log_info "  ./install.sh"
