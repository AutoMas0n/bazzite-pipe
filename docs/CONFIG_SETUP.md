# Configuration-Based ZeroTier Setup

This guide explains how to use the configuration-based setup system for easy ZeroTier network management.

## Overview

The configuration system allows you to:
- Store network settings in a JSON file hosted on GitHub
- Share a single URL with users for easy setup
- Update network settings centrally without users needing to update scripts
- Provide a one-command setup experience for non-technical users

## Quick Start for Users

### Option 1: One-Line Setup (Easiest)

Use this command to automatically join the default network:

```bash
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | sudo bash
```

### Option 2: Custom Config URL

If you have a custom configuration file:

```bash
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | sudo bash -s -- YOUR_CONFIG_URL
```

### Option 3: Local Repository

If you've cloned the repository:

```bash
cd ~/GitHub/bazzite-pipe
sudo ./scripts/zerotier/config-loader.sh https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/zerotier-config.json
```

Or use a local config file:

```bash
sudo ./scripts/zerotier/config-loader.sh ./zerotier-config.json
```

## Configuration File Format

Create a JSON file with the following structure:

```json
{
  "network_id": "76fc96e4988eaf33",
  "network_name": "sewage-pipe",
  "description": "Main ZeroTier network for bazzite-pipe users"
}
```

### Required Fields

- **network_id**: 16-character hexadecimal ZeroTier network ID (required)

### Optional Fields

- **network_name**: Human-readable name for the network
- **description**: Description of the network's purpose

## Hosting Your Configuration

### GitHub (Recommended)

1. Create a JSON config file in your repository
2. Commit and push to GitHub
3. Get the raw URL:
   - Navigate to the file on GitHub
   - Click "Raw" button
   - Copy the URL (format: `https://raw.githubusercontent.com/USER/REPO/BRANCH/file.json`)

Example URL:
```
https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/zerotier-config.json
```

### Other Hosting Options

Any publicly accessible URL that returns the JSON file will work:
- GitHub Gists
- GitLab snippets
- Your own web server
- Cloud storage with public links

## For Network Administrators

### Setting Up a Network Config

1. **Create your ZeroTier network** at https://my.zerotier.com
2. **Note the Network ID** (16 hex characters)
3. **Create config file**:
   ```json
   {
     "network_id": "YOUR_NETWORK_ID",
     "network_name": "your-network-name",
     "description": "Description for your users"
   }
   ```
4. **Host the file** on GitHub or another public location
5. **Share the setup command** with your users:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | sudo bash -s -- YOUR_CONFIG_URL
   ```

### Updating the Configuration

To update network settings:
1. Edit the JSON file in your repository
2. Commit and push changes
3. Users can re-run the setup command to apply updates

**Note**: The network_id should not change. If you need to change networks, create a new config file.

## Security Considerations

### For Users

- Only use configuration URLs from trusted sources
- Verify the URL before running the setup command
- The script will show you the network details before joining

### For Administrators

- Use HTTPS URLs only
- Keep your network_id private until ready to share
- Use ZeroTier Central's authorization to control who can join
- Consider using private repositories for sensitive networks

## Troubleshooting

### "Failed to download configuration"

- Check your internet connection
- Verify the URL is correct and publicly accessible
- Ensure the URL points to the raw file, not the GitHub page

### "Invalid network ID format"

- Network ID must be exactly 16 hexadecimal characters
- Check for typos in your config file
- Verify the network exists in ZeroTier Central

### "Failed to join network"

- Ensure ZeroTier is installed (the script will try to install it)
- Check if the ZeroTier service is running
- Verify you have root/sudo privileges

### "Network joined but not authorized"

This is normal! After joining:
1. Go to https://my.zerotier.com/network/YOUR_NETWORK_ID
2. Find your device in the members list
3. Check the "Auth" checkbox to authorize it

## Advanced Usage

### Using with the Interactive Menu

1. Run the main script:
   ```bash
   ./install.sh
   ```
2. Select "ZeroTier Network Manager"
3. Choose "Join Network from Config URL"
4. Enter your config URL

### Scripting and Automation

The config-loader can be used in scripts:

```bash
#!/bin/bash
CONFIG_URL="https://example.com/zerotier-config.json"
sudo /path/to/scripts/zerotier/config-loader.sh "${CONFIG_URL}"
```

### Multiple Networks

To join multiple networks, create separate config files and run the loader multiple times:

```bash
sudo ./scripts/zerotier/config-loader.sh network1-config.json
sudo ./scripts/zerotier/config-loader.sh network2-config.json
```

## Example Workflow

### For the Network Admin (You)

1. Create network on ZeroTier Central
2. Create `zerotier-config.json` in your repo:
   ```json
   {
     "network_id": "76fc96e4988eaf33",
     "network_name": "sewage-pipe",
     "description": "Gaming network for friends"
   }
   ```
3. Commit and push to GitHub
4. Share this command with friends:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | sudo bash
   ```

### For Your Friends (Users)

1. Open terminal on their Bazzite machine
2. Paste and run the command you shared
3. Wait for authorization (you'll see them in ZeroTier Central)
4. You authorize them by checking the box
5. They're connected!

## Benefits of This Approach

✅ **Simple**: One command for users to run
✅ **Centralized**: Update config file, users get new settings
✅ **Flexible**: Works with any ZeroTier network
✅ **Safe**: Users see what they're joining before confirming
✅ **Maintainable**: No need to update scripts, just the config

## Next Steps

After joining a network:
- Check status: `./scripts/zerotier/manager.sh status`
- Test connectivity: `./scripts/zerotier/test.sh`
- Manage networks: `./scripts/zerotier/manager.sh`

## Support

For issues or questions:
- Check the main README.md
- Review TESTING_GUIDE.md
- Open an issue on GitHub
