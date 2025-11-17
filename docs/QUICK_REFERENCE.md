# Quick Reference Guide

## For You (Network Admin)

### Your Network Details
- **Network ID**: `76fc96e4988eaf33`
- **Network Name**: `sewage-pipe`
- **Config File**: `zerotier-config.json` (in repo root)
- **Your IP**: `10.159.202.203/24`

### Quick Commands

```bash
# Check ZeroTier status
sudo zerotier-cli info
sudo zerotier-cli listnetworks

# Use the manager
./scripts/zerotier/manager.sh status
sudo ./scripts/zerotier/manager.sh

# Test connectivity
./scripts/zerotier/test.sh

# Join from config (local)
sudo ./scripts/zerotier/config-loader.sh ./zerotier-config.json

# Join from config (URL)
sudo ./scripts/zerotier/config-loader.sh https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/zerotier-config.json
```

## For Your Friends (Users)

### One-Line Setup

Share this command with your friends:

```bash
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | sudo bash
```

### What It Does
1. Downloads the necessary scripts
2. Reads the network config from your GitHub repo
3. Joins the sewage-pipe network
4. Shows them what to do next

### After They Run It
1. They'll see a confirmation prompt with network details
2. After confirming, they join the network
3. **You need to authorize them** in ZeroTier Central:
   - Go to https://my.zerotier.com/network/76fc96e4988eaf33
   - Find their device in the members list
   - Check the "Auth" checkbox

## Updating the Network Config

To change network settings:

1. Edit `zerotier-config.json` in your repo
2. Commit and push to GitHub
3. Users can re-run the setup command

**Note**: Don't change the `network_id` unless you're switching to a different network.

## Troubleshooting

### For You

**Check if service is running:**
```bash
systemctl status zerotier-one.service
```

**Restart service:**
```bash
sudo systemctl restart zerotier-one.service
```

**View logs:**
```bash
sudo journalctl -u zerotier-one.service -n 50
```

### For Your Friends

**If they get "permission denied":**
```bash
# Make sure they use sudo
sudo curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | bash
```

**If they can't connect after joining:**
- Check if you authorized them in ZeroTier Central
- Have them check status: `sudo zerotier-cli listnetworks`
- Look for "OK" status in the output

**If ZeroTier isn't installed:**
```bash
# Install ZeroTier first
sudo rpm-ostree install zerotier-one
sudo systemctl reboot
```

## Testing Connectivity

### Between Two Machines

On machine 1:
```bash
sudo zerotier-cli listnetworks
# Note the IP address (e.g., 10.159.202.203)
```

On machine 2:
```bash
# Ping machine 1's ZeroTier IP
ping 10.159.202.203
```

### Using the Test Script

```bash
./scripts/zerotier/test.sh
# Follow the prompts to test connectivity
```

## Common Tasks

### Add a New User
1. Share the one-line setup command
2. Wait for them to run it
3. Authorize them in ZeroTier Central
4. Verify they can connect

### Remove a User
1. Go to ZeroTier Central
2. Find their device
3. Uncheck "Auth" or delete the member

### Check Who's Connected
- Go to https://my.zerotier.com/network/76fc96e4988eaf33
- View the members list
- See online status, IPs, and last seen time

## Gaming Setup

Once everyone is connected:

1. **Host a game** on your machine
2. **Use your ZeroTier IP** instead of public IP
   - Your IP: `10.159.202.203`
3. **Friends connect** using your ZeroTier IP
4. **Enjoy LAN gaming** over the internet!

### Example: Minecraft Server

**On your machine (host):**
```bash
# Start Minecraft server
# It will bind to all interfaces including ZeroTier
```

**Friends connect to:**
```
10.159.202.203:25565
```

### Example: Steam Games

Most Steam games with LAN multiplayer will automatically detect each other on the ZeroTier network!

## Security Notes

- ZeroTier traffic is encrypted end-to-end
- Only authorized members can join
- You control who has access via ZeroTier Central
- Network is private by default

## Next Steps

- [ ] Test the one-line setup with a friend
- [ ] Try hosting a game over ZeroTier
- [ ] Explore the other scripts in the repo
- [ ] Customize the config for your needs

## Support

- **Documentation**: See `CONFIG_SETUP.md` for detailed config info
- **Testing Guide**: See `TESTING_GUIDE.md` for testing procedures
- **Main README**: See `README.md` for project overview
- **Issues**: Open an issue on GitHub if you find bugs
