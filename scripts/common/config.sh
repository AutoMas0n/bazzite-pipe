#!/usr/bin/env bash
# Script: config.sh
# Purpose: Configuration management for bazzite-pipe
# Usage: Source this file to access configuration variables

# Configuration directory
readonly CONFIG_DIR="${HOME}/.config/bazzite-pipe"
readonly CONFIG_FILE="${CONFIG_DIR}/config"

# Default configuration values
readonly DEFAULT_LOG_LEVEL="INFO"
readonly DEFAULT_AUTO_UPDATE="false"
readonly DEFAULT_BACKUP_ENABLED="true"

# Initialize configuration directory
init_config() {
    if [[ ! -d "${CONFIG_DIR}" ]]; then
        mkdir -p "${CONFIG_DIR}"
        chmod 700 "${CONFIG_DIR}"
    fi
    
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        create_default_config
    fi
}

# Create default configuration file
create_default_config() {
    cat > "${CONFIG_FILE}" <<EOF
# bazzite-pipe Configuration File
# Generated: $(date)

# Logging level (DEBUG, INFO, WARN, ERROR)
LOG_LEVEL=${DEFAULT_LOG_LEVEL}

# Automatically check for updates
AUTO_UPDATE=${DEFAULT_AUTO_UPDATE}

# Create backups before modifying files
BACKUP_ENABLED=${DEFAULT_BACKUP_ENABLED}

# ZeroTier Configuration
ZEROTIER_NETWORK_ID=
ZEROTIER_AUTO_JOIN=false
ZEROTIER_AUTO_START=true
EOF
    chmod 600 "${CONFIG_FILE}"
}

# Read configuration value
get_config() {
    local key="$1"
    local default="$2"
    
    init_config
    
    if [[ -f "${CONFIG_FILE}" ]]; then
        local value
        value=$(grep "^${key}=" "${CONFIG_FILE}" | cut -d'=' -f2-)
        if [[ -n "${value}" ]]; then
            echo "${value}"
            return 0
        fi
    fi
    
    echo "${default}"
}

# Set configuration value
set_config() {
    local key="$1"
    local value="$2"
    
    init_config
    
    # Check if key exists
    if grep -q "^${key}=" "${CONFIG_FILE}"; then
        # Update existing key
        sed -i "s|^${key}=.*|${key}=${value}|" "${CONFIG_FILE}"
    else
        # Add new key
        echo "${key}=${value}" >> "${CONFIG_FILE}"
    fi
}

# Remove configuration value
unset_config() {
    local key="$1"
    
    if [[ -f "${CONFIG_FILE}" ]]; then
        sed -i "/^${key}=/d" "${CONFIG_FILE}"
    fi
}

# Display all configuration
show_config() {
    init_config
    
    if [[ -f "${CONFIG_FILE}" ]]; then
        cat "${CONFIG_FILE}"
    else
        echo "No configuration file found"
        return 1
    fi
}

# Reset configuration to defaults
reset_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        rm -f "${CONFIG_FILE}"
    fi
    create_default_config
}

# Export configuration as environment variables
export_config() {
    init_config
    
    if [[ -f "${CONFIG_FILE}" ]]; then
        # Read and export non-comment lines
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "${key}" =~ ^#.*$ ]] && continue
            [[ -z "${key}" ]] && continue
            
            # Export variable
            export "${key}=${value}"
        done < "${CONFIG_FILE}"
    fi
}
