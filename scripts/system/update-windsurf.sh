#!/usr/bin/env bash
set -euo pipefail

# Script: update-windsurf.sh
# Purpose: Update Windsurf IDE to the latest version on Bazzite OS
# Usage: ./update-windsurf.sh

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly WINDSURF_URL="https://windsurf-stable.codeiumdata.com/linux-x64/stable/9472213c2b01d64c024e510cd6fe81abd9b16fb7/Windsurf-linux-x64-1.12.36.tar.gz"
readonly DOWNLOAD_DIR="/tmp/windsurf-update"
readonly INSTALL_DIR="$HOME/.local/share/windsurf"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

check_current_version() {
    if command -v windsurf &> /dev/null; then
        local version=$(windsurf --version 2>/dev/null | head -n1 || echo "Unknown")
        log_info "Current Windsurf version: $version"
        return 0
    else
        log_warn "Windsurf not found in PATH"
        return 1
    fi
}

download_latest() {
    log_info "Creating download directory..." >&2
    mkdir -p "$DOWNLOAD_DIR"
    
    log_info "Downloading latest Windsurf..." >&2
    local tarball="$DOWNLOAD_DIR/windsurf-latest.tar.gz"
    
    if curl -fSL "$WINDSURF_URL" -o "$tarball"; then
        log_info "Download complete: $tarball" >&2
        echo "$tarball"
    else
        log_error "Failed to download Windsurf" >&2
        return 1
    fi
}

backup_current() {
    if [ -d "$INSTALL_DIR" ]; then
        local backup_dir="${INSTALL_DIR}.backup.$(date +%Y%m%d-%H%M%S)"
        log_info "Backing up current installation to: $backup_dir"
        mv "$INSTALL_DIR" "$backup_dir"
        log_info "Backup complete"
    else
        log_warn "No existing installation found at $INSTALL_DIR"
    fi
}

install_windsurf() {
    local tarball="$1"
    
    log_info "Extracting Windsurf..."
    mkdir -p "$INSTALL_DIR"
    
    if tar -xzf "$tarball" -C "$INSTALL_DIR" --strip-components=1; then
        log_info "Extraction complete"
    else
        log_error "Failed to extract Windsurf"
        return 1
    fi
}

setup_symlink() {
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    
    local symlink="$bin_dir/windsurf"
    
    if [ -L "$symlink" ]; then
        log_info "Removing old symlink..."
        rm "$symlink"
    fi
    
    log_info "Creating symlink: $symlink -> $INSTALL_DIR/bin/windsurf"
    ln -s "$INSTALL_DIR/bin/windsurf" "$symlink"
    
    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        log_warn "~/.local/bin is not in your PATH"
        log_warn "Add this to your ~/.bashrc or ~/.zshrc:"
        echo ""
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
    fi
}

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$DOWNLOAD_DIR"
}

main() {
    echo "=========================================="
    echo "  Windsurf IDE Updater for Bazzite OS"
    echo "=========================================="
    echo ""
    
    # Check current version
    check_current_version || true
    echo ""
    
    # Confirm with user
    read -p "Update Windsurf to the latest version? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Update cancelled"
        exit 0
    fi
    
    # Download latest version
    local tarball
    if ! tarball=$(download_latest); then
        log_error "Download failed"
        exit 1
    fi
    
    # Backup current installation
    backup_current
    
    # Install new version
    if ! install_windsurf "$tarball"; then
        log_error "Installation failed"
        exit 1
    fi
    
    # Setup symlink
    setup_symlink
    
    # Cleanup
    cleanup
    
    echo ""
    log_info "✓ Windsurf updated successfully!"
    echo ""
    
    # Show new version
    if command -v windsurf &> /dev/null; then
        local new_version=$(windsurf --version 2>/dev/null | head -n1 || echo "Unknown")
        log_info "New version: $new_version"
    fi
    
    echo ""
    log_info "You may need to restart Windsurf for changes to take effect"
}

# Trap to cleanup on exit
trap cleanup EXIT

main "$@"
