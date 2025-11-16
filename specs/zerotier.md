# ZeroTier Network Manager - Feature Specification

## Overview

The ZeroTier Network Manager provides automated management of ZeroTier CLI connections on Bazzite OS, enabling users to easily maintain persistent connections to ZeroTier networks for LAN gaming over the internet.

**Status**: Specification Phase  
**Priority**: High  
**Target Version**: v0.1.0

---

## Purpose

Enable less tech-savvy users to:
1. Install and configure ZeroTier CLI without manual intervention
2. Maintain persistent connections to a ZeroTier network
3. Test connectivity between users on the same network
4. Troubleshoot connection issues with clear diagnostics
5. Play LAN-only games over the internet seamlessly

---

## User Stories

### As a User
- I want to install ZeroTier with a single command
- I want to automatically connect to my gaming network
- I want to verify I can reach other players
- I want the connection to automatically recover if it drops
- I want clear status information about my connection

### As a System Administrator
- I want to deploy ZeroTier to multiple friends' machines easily
- I want to verify all users are connected to the same network
- I want to troubleshoot connectivity issues remotely
- I want scripts that won't break if run multiple times

---

## Requirements

### Functional Requirements

#### FR-1: Installation
- **FR-1.1**: Detect if zerotier-cli is already installed
- **FR-1.2**: Install zerotier-cli using appropriate package manager for Bazzite
- **FR-1.3**: Enable and start zerotier-one service
- **FR-1.4**: Verify installation was successful
- **FR-1.5**: Handle installation failures gracefully

#### FR-2: Network Connection
- **FR-2.1**: Accept network ID as parameter or prompt user
- **FR-2.2**: Join specified ZeroTier network
- **FR-2.3**: Wait for network authorization (with timeout)
- **FR-2.4**: Verify successful connection
- **FR-2.5**: Store network ID for future use
- **FR-2.6**: Handle already-joined networks gracefully

#### FR-3: Connection Management
- **FR-3.1**: Display current connection status
- **FR-3.2**: Show network details (IP, peers, etc.)
- **FR-3.3**: Leave network if requested
- **FR-3.4**: Reconnect to network if connection drops
- **FR-3.5**: List all joined networks

#### FR-4: Network Testing
- **FR-4.1**: Ping other users on the same network
- **FR-4.2**: Display latency information
- **FR-4.3**: Test connectivity to specific IP addresses
- **FR-4.4**: Report connection quality metrics
- **FR-4.5**: Suggest troubleshooting steps for failures

#### FR-5: Diagnostics
- **FR-5.1**: Check ZeroTier service status
- **FR-5.2**: Display network configuration
- **FR-5.3**: Show recent connection logs
- **FR-5.4**: Verify firewall configuration
- **FR-5.5**: Test internet connectivity

### Non-Functional Requirements

#### NFR-1: Idempotency
- All scripts must be safe to run multiple times
- Running installation script on already-installed system should succeed
- Joining an already-joined network should not cause errors

#### NFR-2: Error Handling
- Clear error messages for common failure scenarios
- Graceful degradation when services are unavailable
- Rollback capability for failed installations
- Logging of all operations for troubleshooting

#### NFR-3: User Experience
- Interactive prompts with sensible defaults
- Progress indicators for long-running operations
- Color-coded output (success=green, warning=yellow, error=red)
- Help text and usage examples

#### NFR-4: Security
- No hardcoded network IDs or credentials
- Prompt for confirmation before destructive operations
- Validate all user inputs
- Run with minimal required privileges

#### NFR-5: Performance
- Installation should complete in under 5 minutes
- Network join should complete in under 30 seconds
- Status checks should be near-instantaneous
- Network tests should complete in under 10 seconds

---

## Technical Design

### Script Structure

```
scripts/zerotier/
├── install.sh      # Installation and initial setup
├── manager.sh      # Connection management interface
└── test.sh         # Network testing utilities
```

### Dependencies

- **zerotier-cli**: Main ZeroTier client
- **systemd**: Service management
- **curl**: For downloading scripts
- **ping**: For network testing
- **jq**: For JSON parsing (optional, fallback to grep/awk)

### Configuration

**Location**: `~/.config/bazzite-pipe/zerotier.conf`

```bash
# ZeroTier Configuration
ZEROTIER_NETWORK_ID=""
ZEROTIER_AUTO_CONNECT="true"
ZEROTIER_CHECK_INTERVAL="300"  # seconds
```

### State Management

- Network ID stored in config file
- Service status tracked via systemd
- Connection state queried from zerotier-cli
- Logs stored in `~/.local/share/bazzite-pipe/logs/zerotier.log`

---

## Implementation Details

### install.sh

**Purpose**: Install and configure ZeroTier CLI

**Flow**:
1. Check if already installed (idempotency)
2. Detect package manager (rpm-ostree for Bazzite)
3. Install zerotier-one package
4. Enable and start service
5. Verify installation
6. Optionally join network if ID provided
7. Create configuration file

**Exit Codes**:
- 0: Success
- 1: Installation failed
- 2: Service start failed
- 3: Verification failed

### manager.sh

**Purpose**: Interactive connection management

**Menu Options**:
1. Show status
2. Join network
3. Leave network
4. Reconnect
5. List networks
6. Run diagnostics
7. Exit

**Flow**:
1. Verify ZeroTier is installed
2. Display current status
3. Present menu
4. Execute selected action
5. Show results
6. Return to menu or exit

### test.sh

**Purpose**: Network connectivity testing

**Features**:
- Ping test to specified IP or all peers
- Latency measurements
- Packet loss detection
- Connection quality report
- Troubleshooting suggestions

**Flow**:
1. Verify ZeroTier connection
2. Get list of network peers
3. Test connectivity to each peer
4. Aggregate and display results
5. Provide recommendations

---

## Testing Strategy

### Unit Testing
- Test each function in isolation
- Mock external dependencies
- Verify error handling paths
- Test edge cases and boundary conditions

### Integration Testing
- Test on clean Bazzite installation
- Test with ZeroTier already installed
- Test with network already joined
- Test network disconnection and recovery
- Test with invalid network IDs
- Test with network authorization delays

### Idempotency Testing
- Run installation script twice
- Join same network multiple times
- Verify no duplicate entries or errors
- Confirm state remains consistent

### User Acceptance Testing
- Test with non-technical users
- Verify error messages are clear
- Confirm prompts are understandable
- Validate help text is sufficient

---

## Usage Examples

### Installation
```bash
# Basic installation
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/scripts/zerotier/install.sh | bash

# Installation with network join
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/scripts/zerotier/install.sh | bash -s -- --network-id abc123def456
```

### Connection Management
```bash
# Interactive menu
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/scripts/zerotier/manager.sh | bash

# Direct commands
./manager.sh status
./manager.sh join abc123def456
./manager.sh leave abc123def456
```

### Network Testing
```bash
# Test all peers
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/scripts/zerotier/test.sh | bash

# Test specific IP
./test.sh --target 192.168.192.10
```

---

## Error Scenarios

### Installation Failures
- **Package not found**: Provide manual installation instructions
- **Service won't start**: Check logs and suggest troubleshooting
- **Permission denied**: Request appropriate privileges

### Connection Failures
- **Network not found**: Verify network ID is correct
- **Authorization timeout**: Instruct user to authorize in ZeroTier Central
- **Service not running**: Attempt to start service

### Network Testing Failures
- **No peers found**: Verify network is authorized and active
- **Ping failures**: Check firewall rules and network configuration
- **Timeout**: Suggest checking internet connection

---

## Future Enhancements

### Phase 2
- Automatic network authorization via API
- Web dashboard for status monitoring
- Systemd timer for periodic connection checks
- Notification system for connection issues

### Phase 3
- Multi-network support
- Network performance optimization
- Bandwidth monitoring
- Peer discovery and management

---

## Success Criteria

1. ✅ User can install ZeroTier with single command
2. ✅ User can join network without manual configuration
3. ✅ Connection persists across reboots
4. ✅ User can verify connectivity to other players
5. ✅ Clear error messages guide troubleshooting
6. ✅ Scripts are idempotent and safe to re-run
7. ✅ Installation completes in under 5 minutes
8. ✅ Works on fresh Bazzite installation

---

## References

- [ZeroTier Documentation](https://docs.zerotier.com/)
- [ZeroTier CLI Reference](https://docs.zerotier.com/cli/)
- [Bazzite Documentation](https://bazzite.gg/)
- [rpm-ostree Documentation](https://coreos.github.io/rpm-ostree/)

---

**Last Updated**: 2025-11-16  
**Author**: AutoMas0n  
**Status**: Ready for Implementation
