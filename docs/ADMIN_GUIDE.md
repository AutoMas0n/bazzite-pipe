# Admin Guide - Remote Access to Friends' Machines

This guide is for **you** (the admin) who needs full remote access to manage your friends' Bazzite OS machines.

## Quick Start

### One-Liner Setup (For Your Friends)

First, **you** (the admin) need to generate an SSH key if you don't have one:

```bash
ssh-keygen -t ed25519 -C "sewer-master" -f ~/.ssh/id_ed25519 -N ""
```

Then send this command to your friends. They copy-paste and run it with **sudo**:

```bash
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | sudo bash -s -- \
  --admin-key "YOUR_SSH_PUBLIC_KEY_HERE"
```

**Example** (replace with your actual public key):
```bash
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | sudo bash -s -- \
  --admin-key "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAbCdEfGhIjKlMnOpQrStUvWxYz sewer-master"
```

**Important Notes**:
- The command **must be run with sudo** (requires root privileges for ZeroTier and SSH setup)
- Replace `YOUR_SSH_PUBLIC_KEY_HERE` with the contents of your `~/.ssh/id_ed25519.pub` file
- Your friend will need to enter their sudo password when prompted

---

## What Gets Set Up

When your friend runs the command, it automatically:

1. **Installs ZeroTier** - Creates a private network connection
2. **Joins your ZeroTier network** - Connects to the network specified in config
3. **Configures SSH** - Sets up secure key-based authentication
4. **Installs Cockpit** - Web-based admin interface (optional)
5. **Configures firewall** - Ensures access only via ZeroTier

---

## Accessing Their Machine

### Via SSH (Command Line)

Once setup is complete, the script will display their ZeroTier IP address. Connect with:

```bash
ssh username@<zerotier-ip>
```

Example:
```bash
ssh jesse@10.147.20.123
```

**Note**: Use their actual system username (the one they used to run the setup command). You'll have full sudo access without needing a password.

### Via Cockpit (Web Interface)

Open your browser and go to:

```
https://<zerotier-ip>:9090
```

Example:
```
https://10.147.20.123:9090
```

**Note**: You'll see a certificate warning - this is normal for self-signed certificates. Click "Advanced" and proceed.

Login with their system username and password.

---

## Common Tasks

### Installing Software

```bash
# SSH into their machine
ssh username@<zerotier-ip>

# Install packages (Bazzite uses rpm-ostree)
sudo rpm-ostree install package-name

# Reboot to apply
sudo systemctl reboot
```

### Checking System Status

```bash
# System info
hostnamectl

# OS version
rpm-ostree status

# Service status
systemctl status service-name

# Disk usage
df -h

# Memory usage
free -h
```

### Viewing Logs

```bash
# Recent system logs
sudo journalctl -n 100

# Specific service logs
sudo journalctl -u sshd -n 50

# Follow logs in real-time
sudo journalctl -f
```

### Managing Services

```bash
# Start a service
sudo systemctl start service-name

# Stop a service
sudo systemctl stop service-name

# Restart a service
sudo systemctl restart service-name

# Enable on boot
sudo systemctl enable service-name

# Check status
sudo systemctl status service-name
```

---

## ZeroTier Network Management

### Authorizing New Machines

1. Go to [ZeroTier Central](https://my.zerotier.com/)
2. Log in to your account
3. Select your network
4. Find the new machine in "Members"
5. Check the "Auth" checkbox to authorize it

### Getting Network Information

```bash
# On their machine
zerotier-cli listnetworks

# Shows:
# - Network ID
# - Network name
# - IP address assigned
# - Connection status
```

### Troubleshooting Connection Issues

```bash
# Check ZeroTier service
sudo systemctl status zerotier-one

# Restart ZeroTier
sudo systemctl restart zerotier-one

# Leave and rejoin network
sudo zerotier-cli leave <network-id>
sudo zerotier-cli join <network-id>
```

---

## Security Best Practices

### SSH Key Management

- **Keep your private key secure** - Never share it
- **Use SSH agent** - Don't store unencrypted keys
- **Rotate keys periodically** - Update every 6-12 months
- **Use strong passphrases** - Protect your private key

### Access Control

- **Limit who has access** - Only add trusted admins
- **Use ZeroTier authorization** - Don't auto-authorize devices
- **Monitor access logs** - Check `/var/log/auth.log` periodically
- **Revoke access when needed** - Remove SSH keys or ZeroTier authorization

### Network Security

- **Keep ZeroTier network private** - Don't share network ID publicly
- **Use strong passwords** - For Cockpit and system accounts
- **Enable 2FA where possible** - For ZeroTier Central account
- **Regular updates** - Keep systems patched

---

## Troubleshooting

### Can't Connect via SSH

1. **Check ZeroTier connection**:
   ```bash
   ping <zerotier-ip>
   ```

2. **Verify SSH is running** (on their machine):
   ```bash
   sudo systemctl status sshd
   ```

3. **Check firewall** (on their machine):
   ```bash
   sudo firewall-cmd --list-all --zone=trusted
   ```

4. **Test SSH port**:
   ```bash
   telnet <zerotier-ip> 22
   ```

### Can't Access Cockpit

1. **Check Cockpit is running** (on their machine):
   ```bash
   sudo systemctl status cockpit.socket
   ```

2. **Verify firewall allows Cockpit**:
   ```bash
   sudo firewall-cmd --zone=trusted --query-service=cockpit
   ```

3. **Try different browser** - Some browsers are strict about certificates

### ZeroTier Not Connecting

1. **Check service status**:
   ```bash
   sudo systemctl status zerotier-one
   ```

2. **Verify network authorization** - Check ZeroTier Central

3. **Check internet connection**:
   ```bash
   ping 8.8.8.8
   ```

4. **Restart ZeroTier**:
   ```bash
   sudo systemctl restart zerotier-one
   ```

---

## Advanced Configuration

### Adding Multiple Admin Keys

To add another admin's SSH key:

```bash
# SSH into their machine
ssh username@<zerotier-ip>

# Add the new key to the user's authorized_keys
echo "ssh-ed25519 AAAAC3Nz... other-admin@host" >> ~/.ssh/authorized_keys

# Set proper permissions
chmod 600 ~/.ssh/authorized_keys
```

Or run the SSH setup script again with the new key:

```bash
# On their machine
sudo bash <(curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/scripts/remote-access/ssh-setup.sh) \
  --public-key "ssh-ed25519 AAAAC3Nz... other-admin@host" \
  --user username \
  --skip-root-check
```

### Customizing Cockpit

Cockpit modules can be installed for additional functionality:

```bash
# Container management
sudo rpm-ostree install cockpit-podman

# Virtual machines
sudo rpm-ostree install cockpit-machines

# Network configuration
sudo rpm-ostree install cockpit-networkmanager

# Reboot to apply
sudo systemctl reboot
```

### Restricting SSH Access

To limit SSH to specific IP addresses, edit `/etc/ssh/sshd_config.d/99-bazzite-pipe.conf`:

```
# Only allow from specific ZeroTier subnet
AllowUsers username@10.147.20.*
```

Then restart SSH:
```bash
sudo systemctl restart sshd
```

---

## Maintenance Tasks

### Regular Checks

**Weekly**:
- Verify ZeroTier connection is active
- Check for system updates
- Review SSH access logs

**Monthly**:
- Update installed packages
- Review firewall rules
- Check disk space usage

**Quarterly**:
- Rotate SSH keys (if policy requires)
- Review and remove unused accounts
- Update ZeroTier network configuration

### Updating the System

```bash
# Check for updates
rpm-ostree upgrade --check

# Apply updates
sudo rpm-ostree upgrade

# Reboot to apply
sudo systemctl reboot

# Check new version
rpm-ostree status
```

### Backing Up Configuration

Important files to backup:
- `/etc/ssh/sshd_config.d/99-bazzite-pipe.conf`
- `/etc/sudoers.d/99-bazzite-pipe-admin`
- `~/.ssh/authorized_keys`
- ZeroTier network ID (from `zerotier-cli listnetworks`)

---

## Removing Access

If you need to revoke access:

### Remove SSH Access

```bash
# SSH into their machine
ssh username@<zerotier-ip>

# Remove your key from authorized_keys
nano ~/.ssh/authorized_keys
# Delete the line with your key

# Or remove the entire file
rm ~/.ssh/authorized_keys
```

### Leave ZeroTier Network

```bash
# Get network ID
zerotier-cli listnetworks

# Leave network
sudo zerotier-cli leave <network-id>
```

### Uninstall Everything

```bash
# Run the uninstall script (if available)
# Or manually:

# Remove ZeroTier
sudo rpm-ostree uninstall zerotier-one

# Remove Cockpit
sudo rpm-ostree uninstall cockpit cockpit-storaged

# Remove SSH config
sudo rm /etc/ssh/sshd_config.d/99-bazzite-pipe.conf
sudo systemctl restart sshd

# Remove sudo config
sudo rm /etc/sudoers.d/99-bazzite-pipe-admin

# Reboot
sudo systemctl reboot
```

---

## Getting Help

### Check Logs

```bash
# SSH logs
sudo journalctl -u sshd -n 100

# ZeroTier logs
sudo journalctl -u zerotier-one -n 100

# Cockpit logs
sudo journalctl -u cockpit -n 100

# System logs
sudo journalctl -n 100
```

### Verify Setup

Run the verification script:

```bash
# If you have the repo cloned
./scripts/remote-access/verify.sh

# Or download and run
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/scripts/remote-access/verify.sh | bash
```

### Community Support

- **GitHub Issues**: https://github.com/AutoMas0n/bazzite-pipe/issues
- **Bazzite Discord**: https://discord.gg/bazzite
- **ZeroTier Forums**: https://discuss.zerotier.com/

---

## Reference

### Default Ports

- **SSH**: 22
- **Cockpit**: 9090
- **ZeroTier**: 9993 (UDP)

### Default Locations

- **SSH config**: `/etc/ssh/sshd_config.d/99-bazzite-pipe.conf`
- **Sudo config**: `/etc/sudoers.d/99-bazzite-pipe-admin`
- **Authorized keys**: `~/.ssh/authorized_keys`
- **ZeroTier config**: `/var/lib/zerotier-one/`

### Useful Commands

```bash
# Get ZeroTier IP
zerotier-cli listnetworks | grep -oP '\d+\.\d+\.\d+\.\d+'

# Get system info
hostnamectl

# Check SSH connections
sudo ss -tnp | grep :22

# Check Cockpit connections
sudo ss -tnp | grep :9090

# List all services
systemctl list-units --type=service

# Check firewall status
sudo firewall-cmd --list-all-zones
```

---

### Quick Setup Options

The quick-setup script supports several options:

```bash
# Skip Cockpit installation
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | sudo bash -s -- \
  --admin-key "YOUR_KEY" \
  --no-cockpit

# Skip firewall configuration
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | sudo bash -s -- \
  --admin-key "YOUR_KEY" \
  --no-firewall

# Use custom ZeroTier config
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | sudo bash -s -- \
  --admin-key "YOUR_KEY" \
  --config-url "https://example.com/custom-config.json"

# Minimal setup (ZeroTier + SSH only)
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | sudo bash -s -- \
  --admin-key "YOUR_KEY" \
  --no-cockpit \
  --no-firewall
```

---

**Last Updated**: 2025-11-17  
**Repository**: https://github.com/AutoMas0n/bazzite-pipe  
**Maintainer**: AutoMas0n
