# Testing Guide - bazzite-pipe

This guide provides instructions for testing the bazzite-pipe scripts on a Bazzite OS installation.

---

## Prerequisites

- **Bazzite OS** installation (fresh or existing)
- **Terminal access** with sudo privileges
- **Internet connection** for package installation
- **ZeroTier network ID** (for network testing)

---

## Quick Start Testing

### 1. Clone the Repository

```bash
cd ~/
git clone https://github.com/AutoMas0n/bazzite-pipe.git
cd bazzite-pipe
```

### 2. Verify Scripts Are Executable

```bash
ls -la install.sh scripts/common/*.sh scripts/zerotier/*.sh
```

All scripts should have execute permissions (`-rwxr-xr-x`).

---

## Test Scenarios

### Test 1: Main Entry Point

**Purpose**: Verify the main menu system works correctly.

```bash
./install.sh
```

**Expected Results**:
- Menu displays correctly with color coding
- Can navigate between options
- System information displays correctly
- Can access ZeroTier submenu
- Can exit cleanly

**What to Check**:
- [ ] Menu displays without errors
- [ ] Colors render correctly
- [ ] System info shows Bazzite OS details
- [ ] Navigation works smoothly

---

### Test 2: ZeroTier Installation (Fresh Install)

**Purpose**: Test installation on system without ZeroTier.

```bash
sudo ./scripts/zerotier/install.sh
```

**Expected Results**:
- Detects Bazzite OS
- Installs zerotier-one package via rpm-ostree
- Enables and starts service
- Prompts for network ID (optional)
- Displays post-installation information

**What to Check**:
- [ ] Installation completes without errors
- [ ] Service starts successfully
- [ ] ZeroTier CLI is available: `zerotier-cli info`
- [ ] Service is enabled: `systemctl is-enabled zerotier-one`
- [ ] Service is active: `systemctl is-active zerotier-one`

**Note**: If rpm-ostree requires a reboot, test will pause here. Reboot and continue.

---

### Test 3: ZeroTier Installation (Idempotency)

**Purpose**: Verify script is safe to run multiple times.

```bash
sudo ./scripts/zerotier/install.sh
```

**Expected Results**:
- Detects existing installation
- Does not reinstall package
- Verifies service is running
- No errors or duplicate entries

**What to Check**:
- [ ] Script recognizes existing installation
- [ ] No duplicate packages installed
- [ ] Service remains running
- [ ] Exit code is 0 (success)

---

### Test 4: Network Joining

**Purpose**: Test joining a ZeroTier network.

**Prerequisites**: Have a ZeroTier network ID ready (create one at https://my.zerotier.com/)

```bash
sudo ./scripts/zerotier/install.sh --network-id YOUR_NETWORK_ID
```

**Expected Results**:
- Joins the specified network
- Provides authorization instructions
- Saves network ID to config
- Shows network status

**What to Check**:
- [ ] Network join succeeds
- [ ] Network appears in: `zerotier-cli listnetworks`
- [ ] Config saved: `cat ~/.config/bazzite-pipe/config`
- [ ] Authorization instructions are clear

**Manual Step**: Authorize the device in ZeroTier Central, then verify connection:
```bash
zerotier-cli listnetworks
```
Status should show "OK" after authorization.

---

### Test 5: Connection Manager

**Purpose**: Test the interactive management interface.

```bash
./scripts/zerotier/manager.sh
```

**Expected Results**:
- Menu displays correctly
- Status shows current connection
- All menu options work
- Can navigate and exit

**What to Check**:
- [ ] Status displays correctly
- [ ] Network list shows joined networks
- [ ] Diagnostics run without errors
- [ ] Menu navigation works

**Test Each Menu Option**:
1. Show Status - Should display service and network info
2. Join Network - Should prompt for network ID (requires sudo)
3. Leave Network - Should show networks and allow leaving (requires sudo)
4. Reconnect - Should reconnect to saved network (requires sudo)
5. List Networks - Should show all joined networks
6. Run Diagnostics - Should show comprehensive system info

---

### Test 6: Network Testing

**Purpose**: Test connectivity testing functionality.

**Prerequisites**: Be connected to a ZeroTier network with at least one other peer.

```bash
./scripts/zerotier/test.sh
```

**Expected Results**:
- Verifies ZeroTier is running
- Shows network status
- Displays our IP address
- Checks internet connectivity
- Shows peer count

**What to Check**:
- [ ] Test runs without errors
- [ ] Network status is accurate
- [ ] IP address is displayed
- [ ] Internet check works

**Test Specific Peer**:
```bash
./scripts/zerotier/test.sh --target PEER_IP_ADDRESS
```

**Expected Results**:
- Pings the specified peer
- Shows latency measurements
- Assesses connection quality
- Provides troubleshooting if fails

**What to Check**:
- [ ] Ping test executes
- [ ] Latency is measured
- [ ] Results are clearly displayed
- [ ] Troubleshooting suggestions appear on failure

---

### Test 7: CLI Mode Operations

**Purpose**: Test non-interactive command-line usage.

```bash
# Show status
./scripts/zerotier/manager.sh status

# Join network (requires sudo)
sudo ./scripts/zerotier/manager.sh join YOUR_NETWORK_ID

# List networks
./scripts/zerotier/manager.sh list

# Run diagnostics
./scripts/zerotier/manager.sh diagnostics

# Leave network (requires sudo)
sudo ./scripts/zerotier/manager.sh leave YOUR_NETWORK_ID
```

**What to Check**:
- [ ] All commands execute without errors
- [ ] Output is clear and informative
- [ ] Exit codes are correct (0 for success)
- [ ] Operations complete as expected

---

### Test 8: Error Scenarios

**Purpose**: Verify error handling works correctly.

#### Test 8a: Run Without Sudo (When Required)
```bash
./scripts/zerotier/install.sh
```
**Expected**: Clear error message about needing sudo

#### Test 8b: Invalid Network ID
```bash
sudo ./scripts/zerotier/manager.sh join invalid123
```
**Expected**: Error about invalid network ID format

#### Test 8c: Test Without ZeroTier Running
```bash
sudo systemctl stop zerotier-one
./scripts/zerotier/test.sh
```
**Expected**: Error about service not running, with instructions to start it

#### Test 8d: Leave Non-Joined Network
```bash
sudo ./scripts/zerotier/manager.sh leave 0000000000000000
```
**Expected**: Error about not being joined to that network

**What to Check**:
- [ ] All errors are caught gracefully
- [ ] Error messages are clear and helpful
- [ ] Suggestions for fixing are provided
- [ ] Scripts don't crash or hang

---

### Test 9: Configuration Persistence

**Purpose**: Verify configuration is saved and loaded correctly.

```bash
# Join a network
sudo ./scripts/zerotier/install.sh --network-id YOUR_NETWORK_ID

# Check config file
cat ~/.config/bazzite-pipe/config

# Reconnect using saved config
sudo ./scripts/zerotier/manager.sh reconnect
```

**What to Check**:
- [ ] Config file is created
- [ ] Network ID is saved
- [ ] Reconnect uses saved ID
- [ ] Config persists across sessions

---

### Test 10: Remote Execution

**Purpose**: Test the web-based deployment method.

**Note**: This requires the scripts to be pushed to GitHub first.

```bash
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/install.sh | bash
```

**Expected Results**:
- Script downloads and runs
- Menu displays correctly
- Can access all features
- Works same as local execution

**What to Check**:
- [ ] Download succeeds
- [ ] Script executes
- [ ] All features accessible
- [ ] No permission issues

---

## Checklist: Complete Test Suite

### Installation
- [ ] Fresh installation works
- [ ] Idempotent (safe to re-run)
- [ ] Package installs correctly
- [ ] Service starts and enables
- [ ] Handles reboot requirement

### Network Management
- [ ] Can join network
- [ ] Can leave network
- [ ] Can reconnect to saved network
- [ ] Authorization guidance is clear
- [ ] Multiple networks supported

### Testing & Diagnostics
- [ ] Network test runs
- [ ] Ping tests work
- [ ] Latency measured correctly
- [ ] Diagnostics comprehensive
- [ ] Troubleshooting helpful

### User Experience
- [ ] Menus are intuitive
- [ ] Colors render correctly
- [ ] Help text is clear
- [ ] Prompts are understandable
- [ ] Error messages are helpful

### Error Handling
- [ ] Missing sudo detected
- [ ] Invalid inputs rejected
- [ ] Service issues caught
- [ ] Network errors handled
- [ ] Graceful degradation

### Configuration
- [ ] Config file created
- [ ] Settings persist
- [ ] Can be modified
- [ ] Defaults are sensible

---

## Performance Benchmarks

Track these metrics during testing:

- **Installation Time**: _____ minutes (target: < 5 minutes)
- **Network Join Time**: _____ seconds (target: < 30 seconds)
- **Status Check Time**: _____ seconds (target: < 1 second)
- **Network Test Time**: _____ seconds (target: < 10 seconds)

---

## Bug Reporting

If you find issues during testing, document:

1. **What you were doing**: Exact command or menu option
2. **What you expected**: Expected behavior
3. **What happened**: Actual behavior
4. **Error messages**: Full error output
5. **System info**: Bazzite version, kernel version
6. **Logs**: Relevant logs from `journalctl -u zerotier-one`

---

## Success Criteria

Testing is complete when:

- [ ] All test scenarios pass
- [ ] No critical bugs found
- [ ] Performance meets targets
- [ ] User experience is smooth
- [ ] Documentation is accurate
- [ ] Error handling is robust

---

## Post-Testing

After successful testing:

1. Update `progress.md` with test results
2. Mark testing tasks as complete
3. Document any issues found and fixed
4. Update README with real-world examples
5. Add screenshots if helpful
6. Tag a release version

---

**Happy Testing!** 🚀

For questions or issues, refer to:
- `AGENTS.md` - Project guidelines
- `progress.md` - Current status
- `specs/zerotier.md` - Feature specification
- GitHub Issues - Bug reports and feature requests
