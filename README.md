# bazzite-pipe

> Idempotent script management for Bazzite OS installations

A simple, web-accessible solution for managing and maintaining Bazzite Linux installations. Run a single command to keep your system configured and up-to-date.

## 🎯 What is bazzite-pipe?

**bazzite-pipe** provides centralized management scripts for Bazzite OS that can be executed with a single piped bash command. This allows easy maintenance and updates without manually downloading or managing scripts.

### Key Features

- **🔄 Idempotent Scripts**: Safe to run multiple times without side effects
- **🌐 Web-Accessible**: Execute latest scripts directly from GitHub
- **🎮 Gaming Focused**: Tools specifically designed for gaming workloads
- **👥 User-Friendly**: Designed for less tech-savvy users
- **🔧 Modular**: Easy to extend with new features

## 🚀 Quick Start

### Prerequisites

- Bazzite OS installation
- Internet connection
- Terminal access

### Installation

Run the main installation script with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/install.sh | bash
```

This will:
1. Download the latest scripts from this repository
2. Present you with available features
3. Guide you through setup and configuration

## 📦 Available Features

### ZeroTier Network Manager (Coming Soon)

Automated ZeroTier CLI management for seamless LAN gaming over the internet.

**Features:**
- Automatic installation of zerotier-cli
- Connection management to your network
- Network testing between users
- Automatic reconnection on network issues
- Status monitoring and diagnostics

**Usage:**
```bash
# Install and configure ZeroTier
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/scripts/zerotier/install.sh | bash

# Manage connections
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/scripts/zerotier/manager.sh | bash

# Test network connectivity
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/scripts/zerotier/test.sh | bash
```

### More Features Coming Soon!

We're continuously developing new tools to make Bazzite OS management easier. Check back for updates!

## 🛠️ How It Works

1. **Centralized Management**: All scripts are hosted in this GitHub repository
2. **Always Up-to-Date**: Running the command fetches the latest version from the main branch
3. **Idempotent Design**: Scripts can be run multiple times safely
4. **Modular Architecture**: Each feature is self-contained and independent

## 📖 Documentation

- **[AGENTS.md](AGENTS.md)**: Comprehensive guide for AI agents and developers
- **[progress.md](progress.md)**: Current development status and roadmap
- **[specs/](specs/)**: Detailed feature specifications

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

### Current Phase: Initial Development
- [x] Repository setup and documentation
- [ ] ZeroTier network manager
- [ ] Common utilities library
- [ ] Main installation script

### Future Plans
- System configuration manager
- Gaming optimizations
- Backup and restore utilities
- Update manager
- Web dashboard for remote management

---

**Made with ❤️ for the Bazzite community**

**Repository**: https://github.com/AutoMas0n/bazzite-pipe
**Maintainer**: AutoMas0n
