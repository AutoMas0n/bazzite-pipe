# Remote Access System - Feature Specification

## Overview

The Remote Access System provides full administrative access to friends' Bazzite OS machines via SSH and Cockpit web console, enabling remote management for non-tech-savvy users who need assistance.

**Status**: Implementation Phase  
**Priority**: High  
**Target Version**: v0.2.0

---

## Purpose

Enable trusted administrators to:
1. Gain full sudo access to friends' machines via SSH
2. Manage systems through web-based Cockpit interface
3. Perform any administrative task remotely
4. Maintain persistent access across reboots
5. Provide support without requiring user technical knowledge

---

## User Stories

### As a System Administrator
- I want to SSH into my friends' machines with my key
- I want full sudo access to perform any administrative task
- I want a web interface for easier system management
- I want access to persist across reboots automatically
- I want secure access only via ZeroTier private network

### As a Non-Technical User
- I want to run one command and have everything set up
- I want my trusted friend to be able to fix issues remotely
- I don't want to deal with passwords or technical configuration
- I want the system to work automatically after initial setup

---

## Requirements

### Functional Requirements

#### FR-1: SSH Server Setup
- **FR-1.1**: Install and enable SSH server (sshd)
- **FR-1.2**: Configure SSH to start on boot
- **FR-1.3**: Harden SSH configuration (disable password auth, root login)
- **FR-1.4**: Configure SSH to listen only on ZeroTier interface (optional)
- **FR-1.5**: Verify SSH service is running

#### FR-2: SSH Key Management
- **FR-2.1**: Accept admin's public SSH key as parameter or from URL
- **FR-2.2**: Add admin key to user's authorized_keys
- **FR-2.3**: Set proper permissions on .ssh directory and files
- **FR-2.4**: Support multiple admin keys if needed
- **FR-2.5**: Verify key was added successfully

#### FR-3: Sudo Access Configuration
- **FR-3.1**: Grant passwordless sudo to user account
- **FR-3.2**: Configure sudoers safely (use visudo or drop-in files)
- **FR-3.3**: Verify sudo access works correctly
- **FR-3.4**: Maintain existing sudo configuration if present

#### FR-4: Cockpit Installation
- **FR-4.1**: Install cockpit package and dependencies
- **FR-4.2**: Enable and start cockpit.socket
- **FR-4.3**: Configure Cockpit to be accessible via ZeroTier
- **FR-4.4**: Set up SSL/TLS certificates (self-signed if needed)
- **FR-4.5**: Verify Cockpit is accessible

#### FR-5: Firewall Configuration
- **FR-5.1**: Allow SSH (port 22) on ZeroTier interface
- **FR-5.2**: Allow Cockpit (port 9090) on ZeroTier interface
- **FR-5.3**: Ensure services are not exposed to public internet
- **FR-5.4**: Verify firewall rules are correct

#### FR-6: Connection Verification
- **FR-6.1**: Test SSH connection from admin machine
- **FR-6.2**: Test sudo access via SSH
- **FR-6.3**: Test Cockpit web interface accessibility
- **FR-6.4**: Provide connection details to admin

### Non-Functional Requirements

#### NFR-1: Security
- **Key-based authentication only** - No password authentication
- **ZeroTier-only access** - Not exposed to public internet
- **Minimal attack surface** - Only necessary services enabled
- **Secure defaults** - Hardened SSH and Cockpit configurations
- **Audit logging** - Track all administrative actions

#### NFR-2: Idempotency
- Safe to run setup multiple times
- Preserve existing SSH keys and configurations
- Don't break existing SSH access
- Handle already-configured systems gracefully

#### NFR-3: User Experience
- **One-command setup** - User runs single curl command
- **Zero user interaction** - No prompts or questions
- **Clear completion message** - Show connection details at end
- **Automatic persistence** - Survives reboots without intervention

#### NFR-4: Reliability
- Services auto-start on boot
- Automatic reconnection after network changes
- Resilient to system updates
- Clear error messages if setup fails

#### NFR-5: Performance
- Setup completes in under 5 minutes
- SSH connection establishes in under 5 seconds
- Cockpit interface loads in under 10 seconds
- Minimal resource overhead

---

## Technical Design

### Script Structure

```
scripts/
├── remote-access/
│   ├── ssh-setup.sh       # SSH server and key configuration
│   ├── cockpit-setup.sh   # Cockpit installation and config
│   ├── firewall-setup.sh  # Firewall rules for remote access
│   └── verify.sh          # Connection verification
└── common/
    ├── utils.sh           # Shared utilities (existing)
    └── config.sh          # Configuration management (existing)
```

### Dependencies

- **openssh-server**: SSH daemon
- **cockpit**: Web-based admin interface
- **cockpit-storaged**: Storage management module
- **cockpit-podman**: Container management (optional)
- **firewalld**: Firewall management
- **zerotier-one**: Private network (existing)

### Configuration Files

#### SSH Configuration
**Location**: `/etc/ssh/sshd_config.d/99-bazzite-pipe.conf`

```
# Bazzite-pipe SSH hardening
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
X11Forwarding no
AllowUsers <username>
```

#### Sudo Configuration
**Location**: `/etc/sudoers.d/99-bazzite-pipe-admin`

```
# Bazzite-pipe admin access
<username> ALL=(ALL) NOPASSWD: ALL
```

#### Firewall Rules
```bash
# Allow SSH on ZeroTier interface
firewall-cmd --permanent --zone=trusted --add-interface=zt+
firewall-cmd --permanent --zone=trusted --add-service=ssh
firewall-cmd --permanent --zone=trusted --add-service=cockpit
```

### State Management

- SSH keys stored in `~/.ssh/authorized_keys`
- Configuration tracked in `~/.config/bazzite-pipe/remote-access.conf`
- Service status tracked via systemd
- Logs in `~/.local/share/bazzite-pipe/logs/remote-access.log`

---

## Implementation Details

### ssh-setup.sh

**Purpose**: Configure SSH server and add admin keys

**Flow**:
1. Check if SSH server is installed
2. Install openssh-server if needed
3. Backup existing SSH configuration
4. Apply hardened SSH configuration
5. Create .ssh directory with proper permissions
6. Add admin public key to authorized_keys
7. Enable and start sshd service
8. Verify SSH is running and accessible

**Parameters**:
- `--public-key <key>`: Admin's SSH public key
- `--key-url <url>`: URL to fetch public key from
- `--user <username>`: Target user (default: current user)

**Exit Codes**:
- 0: Success
- 1: Installation failed
- 2: Configuration failed
- 3: Service start failed
- 4: Verification failed

### cockpit-setup.sh

**Purpose**: Install and configure Cockpit web console

**Flow**:
1. Check if Cockpit is installed
2. Install cockpit and modules
3. Configure Cockpit for ZeroTier access
4. Enable and start cockpit.socket
5. Configure firewall rules
6. Generate self-signed certificate if needed
7. Verify Cockpit is accessible
8. Display access URL

**Parameters**:
- `--no-firewall`: Skip firewall configuration
- `--modules <list>`: Additional Cockpit modules to install

**Exit Codes**:
- 0: Success
- 1: Installation failed
- 2: Service start failed
- 3: Firewall configuration failed
- 4: Verification failed

### firewall-setup.sh

**Purpose**: Configure firewall for remote access

**Flow**:
1. Check if firewalld is installed and running
2. Add ZeroTier interface to trusted zone
3. Allow SSH service
4. Allow Cockpit service
5. Reload firewall rules
6. Verify rules are active

**Exit Codes**:
- 0: Success
- 1: Firewall not available
- 2: Rule configuration failed
- 3: Reload failed

### verify.sh

**Purpose**: Verify remote access is working

**Flow**:
1. Check SSH service status
2. Check Cockpit service status
3. Get ZeroTier IP address
4. Test SSH port is listening
5. Test Cockpit port is listening
6. Display connection instructions
7. Optionally test connection from admin machine

**Output**:
```
✅ Remote Access Setup Complete!

SSH Access:
  ssh <username>@<zerotier-ip>

Cockpit Web Interface:
  https://<zerotier-ip>:9090

Status:
  ✅ SSH server running
  ✅ Cockpit running
  ✅ Firewall configured
  ✅ ZeroTier connected
```

---

## Integration with Existing System

### Updated quick-setup.sh

```bash
#!/usr/bin/env bash
# One-liner remote admin setup

# 1. Install ZeroTier and join network
# 2. Configure SSH with admin key
# 3. Install and configure Cockpit
# 4. Set up firewall rules
# 5. Display connection information
```

### Updated install.sh Menu

```
Bazzite Pipe - System Management
=================================

1. Full Remote Admin Setup (ZeroTier + SSH + Cockpit)
2. ZeroTier Network Only
3. SSH Remote Access Only
4. Cockpit Web Console Only
5. System Information
6. Exit
```

---

## Security Considerations

### Threat Model

**Protected Against**:
- Unauthorized SSH access (key-based auth only)
- Public internet exposure (ZeroTier-only access)
- Privilege escalation (hardened sudo configuration)
- Brute force attacks (no password authentication)

**Assumptions**:
- Admin's SSH key is kept secure
- ZeroTier network is properly secured
- User trusts admin with full system access
- Physical access to machine is trusted

### Best Practices

1. **Key Management**: Admin should use SSH agent, not store unencrypted keys
2. **Network Security**: ZeroTier network should have authorization enabled
3. **Audit Logging**: Enable SSH and sudo logging for accountability
4. **Regular Updates**: Keep SSH and Cockpit updated
5. **Key Rotation**: Periodically rotate SSH keys

---

## Usage Examples

### One-Liner Setup (For Friends)

```bash
# Full remote admin setup with your public key
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | \
  bash -s -- --admin-key "ssh-ed25519 AAAAC3Nz... admin@host"
```

### Individual Component Setup

```bash
# SSH only
./scripts/remote-access/ssh-setup.sh --public-key "ssh-ed25519 AAAAC3Nz..."

# Cockpit only
./scripts/remote-access/cockpit-setup.sh

# Verify setup
./scripts/remote-access/verify.sh
```

### Admin Usage

```bash
# SSH into friend's machine
ssh username@10.147.20.123

# Use Cockpit web interface
firefox https://10.147.20.123:9090
```

---

## Testing Strategy

### Unit Testing
- Test SSH configuration generation
- Test key addition to authorized_keys
- Test firewall rule creation
- Test service enablement

### Integration Testing
- Test on clean Bazzite installation
- Test with existing SSH configuration
- Test with existing authorized_keys
- Test connection from admin machine
- Test sudo access via SSH
- Test Cockpit accessibility

### Security Testing
- Verify password auth is disabled
- Verify services not exposed to internet
- Verify sudo access works correctly
- Test with invalid SSH keys
- Test firewall rules block public access

### Idempotency Testing
- Run setup script multiple times
- Verify existing keys are preserved
- Verify configuration doesn't break
- Confirm services remain functional

---

## Error Scenarios

### SSH Setup Failures
- **Package installation fails**: Provide manual installation instructions
- **Service won't start**: Check logs and suggest troubleshooting
- **Key addition fails**: Verify permissions and file format
- **Connection test fails**: Check firewall and ZeroTier status

### Cockpit Setup Failures
- **Package not available**: Provide alternative access methods
- **Port already in use**: Detect and suggest resolution
- **Certificate generation fails**: Fall back to HTTP or provide manual steps
- **Firewall blocks access**: Verify and fix firewall rules

### Network Issues
- **ZeroTier not connected**: Run ZeroTier setup first
- **Firewall blocks ZeroTier**: Add ZeroTier interface to trusted zone
- **No route to host**: Verify network connectivity

---

## Success Criteria

1. ✅ User can run single command to set up remote access
2. ✅ Admin can SSH into machine with their key
3. ✅ Admin has full sudo access via SSH
4. ✅ Cockpit web interface is accessible
5. ✅ Access persists across reboots
6. ✅ Services only accessible via ZeroTier
7. ✅ Setup completes in under 5 minutes
8. ✅ Clear connection instructions provided
9. ✅ Scripts are idempotent and safe to re-run
10. ✅ Works on fresh Bazzite installation

---

## Future Enhancements

### Phase 2
- Multi-admin support with different permission levels
- Automatic SSH key rotation
- Integration with SSH certificate authority
- Two-factor authentication for Cockpit
- Automated backup before making changes

### Phase 3
- Web-based admin dashboard (custom)
- Remote desktop access (VNC/RDP)
- File transfer interface
- Automated system health monitoring
- Alert system for issues

---

## References

- [OpenSSH Documentation](https://www.openssh.com/manual.html)
- [Cockpit Project](https://cockpit-project.org/)
- [SSH Hardening Guide](https://www.ssh.com/academy/ssh/sshd_config)
- [Firewalld Documentation](https://firewalld.org/documentation/)
- [ZeroTier Documentation](https://docs.zerotier.com/)

---

**Last Updated**: 2025-11-17  
**Author**: AutoMas0n  
**Status**: Ready for Implementation
