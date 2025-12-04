# work in progress

## Current Task: ERSC Launcher Network Blocking (2025-12-01)

**Goal**: Block network connections that prevent ERSC (Elden Ring Seamless Co-op) launcher from starting due to broken update check.

**Status**: Ready for Testing - Blocking script created

**What We Found**:
- Game path: `/home/jesse/Games/elden-ring/drive_c/Program Files (x86)/ELDEN RING/Game/ersc_launcher.exe`
- Problem: Launcher checks for updates on GitHub and fails, preventing game launch
- Analyzed packet capture: `/tmp/ersc-capture-20251201-181909.pcap`
- **Identified update servers**: GitHub CDN and API servers
  - `185.199.108.133` (cdn-185-199-108-133.github.com)
  - `140.82.113.4` (lb-140-82-113-4-iad.github.com)
  - Also blocks: github.com, api.github.com, raw.githubusercontent.com

**Solution Created**:
- Script: `scripts/gaming/block-ersc-github.sh`
- Blocks GitHub domains via `/etc/hosts` file
- Easy enable/disable/status commands

**Next Steps**:
1. Enable blocking: `~/GitHub/bazzite-pipe/scripts/gaming/block-ersc-github.sh enable`
2. Test game launch in Lutris
3. If successful, document solution
4. If unsuccessful, capture new traffic and analyze

**Quick Commands**:
```bash
# Check current status
~/GitHub/bazzite-pipe/scripts/gaming/block-ersc-github.sh status

# Enable blocking (prevents update checks)
~/GitHub/bazzite-pipe/scripts/gaming/block-ersc-github.sh enable

# Disable blocking (allows update checks)
~/GitHub/bazzite-pipe/scripts/gaming/block-ersc-github.sh disable
```

**Useful Scripts** (in `scripts/gaming/`):
- `block-ersc-github.sh` - Quick enable/disable GitHub blocking for ERSC
- `capture-external-traffic.sh` - Captures external network traffic only
- `block-ersc-updates.sh` - Generic host/IP blocking tool