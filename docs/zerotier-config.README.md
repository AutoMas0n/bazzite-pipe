# ZeroTier Network Configuration

This file contains the network configuration for the bazzite-pipe ZeroTier network.

## Current Network

- **Network ID**: `76fc96e4988eaf33`
- **Network Name**: `sewage-pipe`
- **Description**: Main ZeroTier network for bazzite-pipe users

## Usage

### For Users (Quick Setup)

Run this command to join the network:

```bash
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | sudo bash
```

### For Administrators

To use this config file directly:

```bash
# From URL
sudo ./scripts/zerotier/config-loader.sh https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/zerotier-config.json

# From local file
sudo ./scripts/zerotier/config-loader.sh ./zerotier-config.json
```

## Configuration Format

```json
{
  "network_id": "16-character-hex-network-id",
  "network_name": "optional-network-name",
  "description": "optional-description"
}
```

## Modifying This Config

1. Edit the `zerotier-config.json` file
2. Commit and push to GitHub
3. Users can re-run the setup command to apply updates

**Note**: Do not change the `network_id` unless you're switching to a different network.

## Authorization

After joining, users must be authorized by the network administrator:

1. Go to https://my.zerotier.com/network/76fc96e4988eaf33
2. Find the new member in the list
3. Check the "Auth" checkbox

## More Information

- **Full Documentation**: See [CONFIG_SETUP.md](CONFIG_SETUP.md)
- **Quick Reference**: See [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- **Main README**: See [README.md](README.md)
