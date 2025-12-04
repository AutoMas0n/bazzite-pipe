# ERSC Launcher Network Blocking Guide

## Problem
The ERSC (Elden Ring Seamless Co-op) launcher has a broken update check that prevents the game from launching.

## Solution
Block the network connections that the launcher uses for update checks.

## Step-by-Step Process

### Step 1: Monitor Network Connections

**IMPORTANT**: The first monitoring script showed local connections only. Use these updated scripts:

**Method 1 - Real-time external monitoring (Recommended):**
```bash
sudo ~/GitHub/bazzite-pipe/scripts/gaming/monitor-external-connections.sh
```

This filters out localhost and LAN traffic, showing ONLY external internet connections.

**Method 2 - Full packet capture (Most thorough):**
```bash
sudo ~/GitHub/bazzite-pipe/scripts/gaming/capture-external-traffic.sh
```

This captures all external traffic and analyzes it after you stop the capture.

Then launch Elden Ring through Lutris. The scripts will show external connections that the launcher makes.

### Step 2: Identify Update Endpoints

Look for connections that happen right when the launcher starts. Common patterns:
- Connections to update servers (may contain "update", "patch", "version" in hostname)
- HTTPS connections (port 443) to unknown servers
- Connections that happen before the game actually launches

The script will log all connections to a file for review.

### Step 3: Block the Connections

Once you identify the problematic host/IP, block it using:

**To block by hostname:**
```bash
sudo ~/GitHub/bazzite-pipe/scripts/gaming/block-ersc-updates.sh add seamlesscoopupdates.example.com
```

**To block by IP and port:**
```bash
sudo ~/GitHub/bazzite-pipe/scripts/gaming/block-ersc-updates.sh firewall 192.168.1.100:443
```

**To list current blocks:**
```bash
~/GitHub/bazzite-pipe/scripts/gaming/block-ersc-updates.sh list
```

**To remove a block:**
```bash
sudo ~/GitHub/bazzite-pipe/scripts/gaming/block-ersc-updates.sh remove seamlesscoopupdates.example.com
```

### Step 4: Test

Launch the game again and verify it works without the update check blocking it.

## Quick Commands

```bash
# Make scripts executable (run once)
chmod +x ~/GitHub/bazzite-pipe/scripts/gaming/*.sh

# Start monitoring
sudo ~/GitHub/bazzite-pipe/scripts/gaming/monitor-wine-connections.sh

# Block a host
sudo ~/GitHub/bazzite-pipe/scripts/gaming/block-ersc-updates.sh add <hostname>

# Block an IP:port
sudo ~/GitHub/bazzite-pipe/scripts/gaming/block-ersc-updates.sh firewall <ip:port>
```

## Notes

- The monitoring script requires sudo to see all network connections
- Firewall rules are temporary and will be lost on reboot unless saved
- Hosts file blocks are permanent until removed
- You can use both methods together for maximum blocking
