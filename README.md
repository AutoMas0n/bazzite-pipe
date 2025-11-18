# bazzite-pipe

> Idempotent script management for Bazzite OS installations

A simple, web-accessible solution for managing and maintaining Bazzite Linux installations. Run a single command to keep your system configured and up-to-date.

## 🎯 What is bazzite-pipe?

**bazzite-pipe** provides full remote administrative access to Bazzite OS machines for trusted administrators. Perfect for helping less tech-savvy friends manage their gaming systems remotely.

### Key Features

- **🔐 Full Remote Access**: SSH + Cockpit web console for complete system control
- **🌐 Secure Networking**: ZeroTier private network (not exposed to internet)
- **🔑 Key-Based Auth**: Secure SSH access without passwords
- **🔄 Idempotent Scripts**: Safe to run multiple times without side effects
- **👥 User-Friendly**: One-command setup for non-technical users
- **🔧 Modular**: Easy to extend with new features

## 🚀 Quick Start

### For Non-Technical Users (Your Friends)

Send them this one-liner command (replace with your SSH public key):

```bash
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | bash -s -- \
  --admin-key "ssh-ed25519 AAAAC3Nz... your-email@example.com"
```

**That's it!** They copy-paste and run it. You'll get full remote access.

### For Administrators

See **[docs/ADMIN_GUIDE.md](docs/ADMIN_GUIDE.md)** for:
- How to get your SSH public key
- Connecting to their machines
- Managing systems remotely
- Troubleshooting and maintenance

### Interactive Setup

For more control, use the interactive menu:

```bash
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/install.sh | bash
```

This will:
1. Download the latest scripts from this repository
2. Present you with available features
3. Guide you through setup and configuration

## 📦 Available Features

### 🔐 Remote Access System

Complete remote administrative access via secure private network.

**What Gets Set Up:**
- **ZeroTier Network**: Private network connection (not exposed to internet)
- **SSH Access**: Secure key-based authentication with full sudo access
- **Cockpit Web Console**: Browser-based system management at `https://<ip>:9090`
- **Firewall Configuration**: Ensures services only accessible via ZeroTier

**One-Liner Setup:**
```bash
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/quick-setup.sh | bash -s -- \
  --admin-key "YOUR_SSH_PUBLIC_KEY"
```

**What You Get:**
- SSH into their machine: `ssh user@<zerotier-ip>`
- Web interface: `https://<zerotier-ip>:9090`
- Full sudo access without passwords
- Persistent across reboots

### 🌐 ZeroTier Network Manager

Automated ZeroTier CLI management for LAN gaming over the internet.

**Features:**
- Automatic installation and configuration
- Connection management and testing
- Network diagnostics and troubleshooting
- Configuration-based network joining

**Usage:**
```bash
# Quick setup from config
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/scripts/zerotier/config-loader.sh | bash

# Interactive management
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/scripts/zerotier/manager.sh | bash
```

### More Features Coming Soon!

- System configuration presets
- Gaming optimizations
- Backup and restore utilities
- Automated update management

## 🛠️ How It Works

1. **Centralized Management**: All scripts are hosted in this GitHub repository
2. **Always Up-to-Date**: Running the command fetches the latest version from the main branch
3. **Idempotent Design**: Scripts can be run multiple times safely
4. **Modular Architecture**: Each feature is self-contained and independent

## 📖 Documentation

### For Administrators
- **[docs/ADMIN_GUIDE.md](docs/ADMIN_GUIDE.md)**: Complete guide for remote system management
- **[docs/CONFIG_SETUP.md](docs/CONFIG_SETUP.md)**: ZeroTier configuration guide

### For Developers
- **[AGENTS.md](AGENTS.md)**: Comprehensive guide for AI agents and developers
- **[progress.md](progress.md)**: Current development status and roadmap
- **[specs/](specs/)**: Detailed feature specifications
- **[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)**: Contribution guidelines

## 🤝 Contributing

This project is primarily designed to help manage Bazzite installations for friends and family. However, contributions are welcome!

### Development Guidelines

1. All scripts must be idempotent
2. Follow the bash script template in [AGENTS.md](AGENTS.md)
3. Test thoroughly on Bazzite OS
4. Update documentation and specifications
5. Submit pull requests to the main branch

### Testing

Before submitting changes:
- Test on a clean Bazzite installation
- Run scripts at least twice to verify idempotency
- Test error scenarios and edge cases
- Update relevant documentation

## 🔒 Security

- **No Hardcoded Secrets**: Never commit sensitive information
- **User Confirmation**: Destructive operations require confirmation
- **Minimal Privileges**: Scripts request sudo only when necessary
- **Input Validation**: All user inputs are validated

## 📝 License

This project is open source and available under the MIT License.

## 🙏 Acknowledgments

- Built for the Bazzite OS community
- Inspired by the need for simple, accessible system management
- Thanks to all contributors and testers

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/AutoMas0n/bazzite-pipe/issues)
- **Discussions**: [GitHub Discussions](https://github.com/AutoMas0n/bazzite-pipe/discussions)

## 🗺️ Roadmap

### v0.2.0 - Remote Access System (Current)
- [x] SSH remote access with key-based authentication
- [x] Cockpit web console installation
- [x] Firewall configuration for secure access
- [x] ZeroTier network integration
- [x] One-liner setup for complete remote admin
- [x] Comprehensive admin documentation
- [ ] Real-world testing and refinement

### v0.1.0 - Foundation (Completed)
- [x] Repository setup and documentation
- [x] ZeroTier network manager
- [x] Common utilities library
- [x] Main installation script
- [x] Configuration-based network joining

### Future Plans
- Multi-admin support with permission levels
- System configuration presets
- Gaming optimizations
- Backup and restore utilities
- Automated update management
- Custom web dashboard

---

**Made with ❤️ for the Bazzite community**

**Repository**: https://github.com/AutoMas0n/bazzite-pipe
**Maintainer**: AutoMas0n
