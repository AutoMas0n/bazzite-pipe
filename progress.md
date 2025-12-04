# work in progress

## Current Task: ERSC Launcher Network Blocking (2025-12-01)

**Goal**: Block network connections that prevent ERSC (Elden Ring Seamless Co-op) launcher from starting due to broken update check.

**Status**: ✅ COMPLETE - Lutris one-click integration working (2025-12-03)

**What We Found**:
- Game path: `/home/jesse/Games/elden-ring/drive_c/Program Files (x86)/ELDEN RING/Game/ersc_launcher.exe`
- Problem: Launcher checks for updates on GitHub and fails, preventing game launch
- Analyzed packet capture: `/tmp/ersc-capture-20251201-181909.pcap`
- **Identified update servers**: GitHub CDN and API servers
  - `185.199.108.133` (cdn-185-199-108-133.github.com)
  - `140.82.113.4` (lb-140-82-113-4-iad.github.com)
  - Also blocks: github.com, api.github.com, raw.githubusercontent.com

**Solution Created**:
- **Lutris Integration** (one-click, no user action needed):
  - `ersc-prelaunch.sh` - Lutris prelaunch script
  - `ersc-hosts-helper.sh` - Passwordless sudo helper
  - Sudoers rule at `/etc/sudoers.d/ersc-launcher`
- **Manual Script**: `block-ersc-github.sh` - enable/disable/status/launch commands

**How It Works** (automatic via Lutris):
1. User clicks Play in Lutris
2. Prelaunch script blocks GitHub (passwordless sudo)
3. ERSC launcher starts, skips broken update check
4. Script detects `eldenring.exe` (~4 seconds)
5. GitHub unblocked automatically
6. Log at `/tmp/ersc-prelaunch.log`

**Manual Commands** (if needed):
```bash
# Check status
~/GitHub/bazzite-pipe/scripts/gaming/block-ersc-github.sh status

# Manual block/unblock
sudo ~/GitHub/bazzite-pipe/scripts/gaming/ersc-hosts-helper.sh block
sudo ~/GitHub/bazzite-pipe/scripts/gaming/ersc-hosts-helper.sh unblock
```

**Useful Scripts** (in `scripts/gaming/`):
- `block-ersc-github.sh` - Quick enable/disable GitHub blocking for ERSC
- `capture-external-traffic.sh` - Captures external network traffic only
- `block-ersc-updates.sh` - Generic host/IP blocking tool