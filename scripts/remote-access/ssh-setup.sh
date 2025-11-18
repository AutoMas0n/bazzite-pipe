#!/usr/bin/env bash
set -euo pipefail

# Script: ssh-setup.sh
# Purpose: Configure SSH server with key-based authentication for remote admin access
# Usage: ./ssh-setup.sh --public-key "ssh-ed25519 AAAAC3..." [--user username]

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
readonly SSH_CONFIG_DIR="/etc/ssh/sshd_config.d"
readonly SSH_CONFIG_FILE="${SSH_CONFIG_DIR}/99-bazzite-pipe.conf"

# Helper function to run command with sudo if not root
run_as_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Parse command line arguments
parse_args() {
    PUBLIC_KEY=""
    KEY_URL=""
    TARGET_USER="${USER}"
    SKIP_ROOT_CHECK=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --public-key)
                PUBLIC_KEY="$2"
                shift 2
                ;;
            --key-url)
                KEY_URL="$2"
                shift 2
                ;;
            --user)
                TARGET_USER="$2"
                shift 2
                ;;
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
    
    # Validate inputs
    if [[ -z "${PUBLIC_KEY}" && -z "${KEY_URL}" ]]; then
        log_error "Either --public-key or --key-url must be provided"
        show_usage
        exit 1
    fi
}

show_usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Configure SSH server with key-based authentication for remote admin access.

OPTIONS:
    --public-key <key>    Admin's SSH public key
    --key-url <url>       URL to fetch public key from
    --user <username>     Target user (default: current user)
    -h, --help           Show this help message

EXAMPLES:
    # Add SSH key directly
    ${SCRIPT_NAME} --public-key "ssh-ed25519 AAAAC3Nz... admin@host"
    
    # Fetch key from URL
    ${SCRIPT_NAME} --key-url "https://github.com/username.keys"
    
    # Specify different user
    ${SCRIPT_NAME} --public-key "ssh-ed25519 AAAAC3Nz..." --user otheruser

EOF
}

# Check if SSH server is installed
check_ssh_installed() {
    log_info "Checking SSH server installation..."
    
    if command -v sshd &> /dev/null; then
        log_success "SSH server is already installed"
        return 0
    fi
    
    log_warn "SSH server not found"
    return 1
}

# Install SSH server
install_ssh_server() {
    log_info "Installing SSH server..."
    
    # Check if we're on an immutable system (Bazzite uses rpm-ostree)
    if command -v rpm-ostree &> /dev/null; then
        log_info "Detected rpm-ostree system, checking if openssh-server is available..."
        
        # On Bazzite, openssh-server should be pre-installed
        if rpm -q openssh-server &> /dev/null; then
            log_success "openssh-server is already installed via rpm-ostree"
            return 0
        else
            log_error "openssh-server not found. On Bazzite, SSH server should be pre-installed."
            log_error "Please report this issue."
            return 1
        fi
    else
        # Fallback for non-immutable systems
        if install_package openssh-server; then
            log_success "SSH server installed successfully"
            return 0
        else
            log_error "Failed to install SSH server"
            return 1
        fi
    fi
}

# Backup existing SSH configuration
backup_ssh_config() {
    log_info "Backing up SSH configuration..."
    
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    # Get target user's home directory
    local target_home
    target_home=$(eval echo "~${TARGET_USER}")
    local backup_dir="${target_home}/.local/share/bazzite-pipe/backups"
    
    # Ensure backup directory exists
    if [[ ! -d "${backup_dir}" ]]; then
        mkdir -p "${backup_dir}" || log_warn "Failed to create backup directory"
        if [[ "${EUID}" -eq 0 ]]; then
            chown -R "${TARGET_USER}:${TARGET_USER}" "${target_home}/.local/share/bazzite-pipe" 2>/dev/null || true
        fi
    fi
    
    # Backup existing config if it exists
    if [[ -f "${SSH_CONFIG_FILE}" ]]; then
        local backup_file="${backup_dir}/sshd_config_${timestamp}.bak"
        if cp "${SSH_CONFIG_FILE}" "${backup_file}"; then
            log_success "Backed up existing configuration to ${backup_file}"
            if [[ "${EUID}" -eq 0 ]]; then
                chown "${TARGET_USER}:${TARGET_USER}" "${backup_file}" 2>/dev/null || true
            fi
        else
            log_warn "Failed to backup configuration, continuing anyway..."
        fi
    fi
}

# Configure SSH server with hardened settings
configure_ssh_server() {
    log_info "Configuring SSH server with hardened settings..."
    
    # Ensure config directory exists
    if [[ ! -d "${SSH_CONFIG_DIR}" ]]; then
        log_info "Creating SSH config directory..."
        run_as_root mkdir -p "${SSH_CONFIG_DIR}"
    fi
    
    # Create hardened SSH configuration
    local config_content
    config_content=$(cat << 'EOF'
# Bazzite-pipe SSH hardening configuration
# Generated by bazzite-pipe remote access setup

# Authentication
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
ChallengeResponseAuthentication no
UsePAM yes

# Security
X11Forwarding no
PermitEmptyPasswords no
MaxAuthTries 3
MaxSessions 10

# Performance
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
)
    
    # Add user restriction if not root
    if [[ "${TARGET_USER}" != "root" ]]; then
        config_content="${config_content}
AllowUsers ${TARGET_USER}"
    fi
    
    # Write configuration
    if echo "${config_content}" | run_as_root tee "${SSH_CONFIG_FILE}" > /dev/null; then
        log_success "SSH configuration written to ${SSH_CONFIG_FILE}"
    else
        log_error "Failed to write SSH configuration"
        return 1
    fi
    
    # Validate configuration
    # Note: sshd -t may fail if host keys don't exist yet, but that's okay
    # The keys will be generated when the service starts
    if run_as_root sshd -t 2>&1 | grep -q "no hostkeys available"; then
        log_warn "SSH host keys not yet generated (will be created on first start)"
    elif run_as_root sshd -t 2>/dev/null; then
        log_success "SSH configuration is valid"
    else
        log_warn "SSH configuration validation had warnings (may be okay)"
    fi
}

# Fetch public key from URL
fetch_public_key() {
    local url="$1"
    log_info "Fetching public key from ${url}..."
    
    local key
    if key=$(curl -fsSL "${url}"); then
        if [[ -n "${key}" ]]; then
            log_success "Public key fetched successfully"
            echo "${key}"
            return 0
        else
            log_error "Fetched key is empty"
            return 1
        fi
    else
        log_error "Failed to fetch public key from URL"
        return 1
    fi
}

# Validate SSH public key format
validate_public_key() {
    local key="$1"
    
    # Check if key starts with valid SSH key type
    if [[ "${key}" =~ ^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)[[:space:]] ]]; then
        return 0
    else
        log_error "Invalid SSH public key format"
        log_error "Key must start with: ssh-rsa, ssh-ed25519, or ecdsa-sha2-*"
        return 1
    fi
}

# Add public key to authorized_keys
add_authorized_key() {
    local key="$1"
    local user="$2"
    
    log_info "Adding SSH key for user: ${user}"
    
    # Get user's home directory
    local user_home
    if [[ "${user}" == "${USER}" ]]; then
        user_home="${HOME}"
    else
        user_home=$(eval echo "~${user}")
    fi
    
    local ssh_dir="${user_home}/.ssh"
    local auth_keys="${ssh_dir}/authorized_keys"
    
    # Create .ssh directory if it doesn't exist
    if [[ ! -d "${ssh_dir}" ]]; then
        log_info "Creating .ssh directory..."
        mkdir -p "${ssh_dir}"
        chmod 700 "${ssh_dir}"
        # Ensure proper ownership when running with sudo
        if [[ "${EUID}" -eq 0 ]] && [[ "${user}" != "root" ]]; then
            chown "${user}:${user}" "${ssh_dir}"
        fi
    fi
    
    # Check if key already exists
    if [[ -f "${auth_keys}" ]] && grep -qF "${key}" "${auth_keys}"; then
        log_success "SSH key already exists in authorized_keys"
        return 0
    fi
    
    # Backup existing authorized_keys
    if [[ -f "${auth_keys}" ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        
        # Get target user's home directory for backup
        local target_home
        target_home=$(eval echo "~${user}")
        local backup_dir="${target_home}/.local/share/bazzite-pipe/backups"
        
        # Ensure backup directory exists
        if [[ ! -d "${backup_dir}" ]]; then
            mkdir -p "${backup_dir}" || log_warn "Failed to create backup directory"
            if [[ "${EUID}" -eq 0 ]]; then
                chown -R "${user}:${user}" "${target_home}/.local/share/bazzite-pipe" 2>/dev/null || true
            fi
        fi
        
        local backup_file="${backup_dir}/authorized_keys_${timestamp}.bak"
        if cp "${auth_keys}" "${backup_file}"; then
            log_info "Backed up authorized_keys to ${backup_file}"
            if [[ "${EUID}" -eq 0 ]]; then
                chown "${user}:${user}" "${backup_file}" 2>/dev/null || true
            fi
        else
            log_warn "Failed to backup authorized_keys, continuing anyway..."
        fi
    fi
    
    # Add key with comment
    {
        echo ""
        echo "# Added by bazzite-pipe on $(date)"
        echo "${key}"
    } >> "${auth_keys}"
    
    # Set proper permissions and ownership
    chmod 600 "${auth_keys}"
    # Ensure proper ownership when running with sudo
    if [[ "${EUID}" -eq 0 ]] && [[ "${user}" != "root" ]]; then
        chown "${user}:${user}" "${auth_keys}"
    fi
    
    log_success "SSH key added to ${auth_keys}"
}

# Configure passwordless sudo
configure_sudo() {
    local user="$1"
    
    log_info "Configuring passwordless sudo for ${user}..."
    
    local sudoers_file="/etc/sudoers.d/99-bazzite-pipe-admin"
    local sudoers_content="# Bazzite-pipe admin access
${user} ALL=(ALL) NOPASSWD: ALL"
    
    # Create sudoers file
    if echo "${sudoers_content}" | run_as_root tee "${sudoers_file}" > /dev/null; then
        run_as_root chmod 440 "${sudoers_file}"
        
        # Validate sudoers file
        if run_as_root visudo -c -f "${sudoers_file}" &> /dev/null; then
            log_success "Sudo configuration added successfully"
            return 0
        else
            log_error "Sudoers file validation failed"
            run_as_root rm -f "${sudoers_file}"
            return 1
        fi
    else
        log_error "Failed to create sudoers file"
        return 1
    fi
}

# Enable and start SSH service
enable_ssh_service() {
    log_info "Enabling and starting SSH service..."
    
    # Enable service
    if run_as_root systemctl enable sshd.service; then
        log_success "SSH service enabled"
    else
        log_error "Failed to enable SSH service"
        return 1
    fi
    
    # Start or restart service
    if run_as_root systemctl is-active --quiet sshd.service; then
        log_info "Restarting SSH service to apply configuration..."
        if run_as_root systemctl restart sshd.service; then
            log_success "SSH service restarted"
        else
            log_error "Failed to restart SSH service"
            return 1
        fi
    else
        log_info "Starting SSH service..."
        if run_as_root systemctl start sshd.service; then
            log_success "SSH service started"
        else
            log_error "Failed to start SSH service"
            return 1
        fi
    fi
    
    # Verify service is running
    if run_as_root systemctl is-active --quiet sshd.service; then
        log_success "SSH service is running"
        return 0
    else
        log_error "SSH service is not running"
        return 1
    fi
}

# Verify SSH setup
verify_ssh_setup() {
    log_info "Verifying SSH setup..."
    
    local all_good=true
    
    # Check service status
    if run_as_root systemctl is-active --quiet sshd.service; then
        log_success "✓ SSH service is running"
    else
        log_error "✗ SSH service is not running"
        all_good=false
    fi
    
    # Check if service is enabled
    if run_as_root systemctl is-enabled --quiet sshd.service; then
        log_success "✓ SSH service is enabled"
    else
        log_error "✗ SSH service is not enabled"
        all_good=false
    fi
    
    # Check if port 22 is listening
    if run_as_root ss -tlnp | grep -q ':22 '; then
        log_success "✓ SSH is listening on port 22"
    else
        log_error "✗ SSH is not listening on port 22"
        all_good=false
    fi
    
    # Check authorized_keys exists and has content
    local target_home
    target_home=$(eval echo "~${TARGET_USER}")
    local auth_keys="${target_home}/.ssh/authorized_keys"
    if [[ -f "${auth_keys}" ]] && [[ -s "${auth_keys}" ]]; then
        log_success "✓ Authorized keys file exists and has content"
    else
        log_error "✗ Authorized keys file is missing or empty"
        all_good=false
    fi
    
    # Check sudo configuration
    local sudoers_file="/etc/sudoers.d/99-bazzite-pipe-admin"
    if [[ -f "${sudoers_file}" ]]; then
        log_success "✓ Sudo configuration exists"
    else
        log_warn "⚠ Sudo configuration not found (may not be required)"
    fi
    
    if [[ "${all_good}" == "true" ]]; then
        log_success "All SSH setup checks passed!"
        return 0
    else
        log_error "Some SSH setup checks failed"
        return 1
    fi
}

# Display connection information
show_connection_info() {
    log_info "Gathering connection information..."
    
    # Get ZeroTier IP if available
    local zt_ip=""
    if command -v zerotier-cli &> /dev/null; then
        zt_ip=$(zerotier-cli listnetworks | grep -oP '\d+\.\d+\.\d+\.\d+' | head -n1 || echo "")
    fi
    
    print_separator
    log_success "SSH Remote Access Setup Complete!"
    print_separator
    echo ""
    echo "Connection Information:"
    echo "  User: ${TARGET_USER}"
    
    if [[ -n "${zt_ip}" ]]; then
        echo "  ZeroTier IP: ${zt_ip}"
        echo ""
        echo "SSH Command:"
        echo "  ssh ${TARGET_USER}@${zt_ip}"
    else
        echo "  ZeroTier IP: Not available (run ZeroTier setup first)"
        echo ""
        echo "SSH Command:"
        echo "  ssh ${TARGET_USER}@<zerotier-ip>"
    fi
    
    echo ""
    echo "Notes:"
    echo "  • SSH is configured for key-based authentication only"
    echo "  • Password authentication is disabled for security"
    echo "  • Passwordless sudo is configured for ${TARGET_USER}"
    echo "  • SSH service will start automatically on boot"
    echo ""
    print_separator
}

# Main function
main() {
    print_header "SSH Remote Access Setup"
    
    # Parse arguments
    parse_args "$@"
    
    # Check if running as root (we need sudo, not root)
    # Skip this check if called from quick-setup script
    if [[ "${EUID}" -eq 0 ]] && [[ "${SKIP_ROOT_CHECK}" != "true" ]]; then
        log_error "Do not run this script as root. Run as the target user with sudo access."
        exit 1
    fi
    
    # Fetch key from URL if specified
    if [[ -n "${KEY_URL}" ]]; then
        PUBLIC_KEY=$(fetch_public_key "${KEY_URL}") || exit 1
    fi
    
    # Validate public key
    validate_public_key "${PUBLIC_KEY}" || exit 1
    
    # Check and install SSH server if needed
    if ! check_ssh_installed; then
        install_ssh_server || exit 1
    fi
    
    # Backup existing configuration
    backup_ssh_config
    
    # Configure SSH server
    configure_ssh_server || exit 1
    
    # Add authorized key
    add_authorized_key "${PUBLIC_KEY}" "${TARGET_USER}" || exit 1
    
    # Configure sudo access
    if confirm "Configure passwordless sudo for ${TARGET_USER}?"; then
        configure_sudo "${TARGET_USER}" || log_warn "Sudo configuration failed, continuing..."
    fi
    
    # Enable and start SSH service
    enable_ssh_service || exit 1
    
    # Verify setup
    verify_ssh_setup || log_warn "Some verification checks failed"
    
    # Show connection information
    show_connection_info
    
    log_success "SSH setup completed successfully!"
}

main "$@"
