---
trigger: always_on
---

# AGENTS.md - AI Agent Instructions for bazzite-pipe

## Project Overview

**bazzite-pipe** is an idempotent script management system for Bazzite OS installations. This repository provides a web-accessible, single-command solution for managing and maintaining Bazzite Linux installations for less tech-savvy users.

### Core Concept
Users can execute a single piped bash command that fetches and runs the latest scripts from this repository's main branch. This allows centralized management and updates without requiring users to manually download or update scripts.

Example usage pattern:
```bash
curl -fsSL https://raw.githubusercontent.com/AutoMas0n/bazzite-pipe/main/install.sh | bash
```

### Target Audience
- Primary: Less tech-savvy friends who need help managing their Bazzite OS installations
- Secondary: Anyone wanting a simple, centralized way to manage Bazzite configurations

## Repository Structure

```
bazzite-pipe/
├── AGENTS.md              # This file - AI agent instructions
├── README.md              # User-facing documentation
├── progress.md            # Task tracking and development progress
├── install.sh             # Main entry point script
├── scripts/               # Individual feature scripts
│   ├── zerotier/         # ZeroTier management scripts
│   │   ├── install.sh    # ZeroTier installation
│   │   ├── manager.sh    # Connection management
│   │   └── test.sh       # Network testing utilities
│   └── common/           # Shared utilities
│       ├── utils.sh      # Common functions
│       └── config.sh     # Configuration management
├── specs/                # Feature specifications
│   └── zerotier.md       # ZeroTier feature specification
└── tests/                # Test scripts
    └── integration/      # Integration tests
```

## Development Guidelines

### Code Style & Conventions

#### Bash Scripts
- **Idempotency**: All scripts MUST be idempotent - safe to run multiple times without side effects
- **Error Handling**: Use `set -euo pipefail` at the start of all scripts
- **Functions**: Prefix internal functions with underscore (e.g., `_internal_function`)
- **Variables**: Use UPPERCASE for constants, lowercase for local variables
- **Logging**: Use consistent logging functions (info, warn, error)
- **Exit Codes**: 0 for success, non-zero for failures with meaningful codes

#### Script Template
```bash
#!/usr/bin/env bash
set -euo pipefail

# Script: [name]
# Purpose: [description]
# Usage: [usage pattern]

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Source common utilities
source "${SCRIPT_DIR}/../common/utils.sh"

# Main function
main() {
    log_info "Starting ${SCRIPT_NAME}"
    # Implementation
    log_info "Completed ${SCRIPT_NAME}"
}

main "$@"
```

### Testing Requirements

1. **Manual Testing**: All scripts must be tested on a Bazzite installation before merging
2. **Idempotency Testing**: Run each script at least twice to verify idempotency
3. **Error Scenarios**: Test failure modes and ensure graceful error handling
4. **Documentation**: Update relevant specs and README when adding features

### Git Workflow

- **Main Branch**: Production-ready code only
- **Feature Branches**: Use descriptive names (e.g., `feature/zerotier-manager`)
- **Commit Messages**: Clear, descriptive messages explaining the "why"
- **Pull Requests**: Required for all changes to main branch

## Current Features

### 1. ZeroTier Network Manager (In Development)
**Status**: Specification phase
**Location**: `scripts/zerotier/`, `specs/zerotier.md`

**Purpose**: Automated ZeroTier CLI management to keep users connected to the main node and enable LAN gaming over the internet.

**Key Requirements**:
- Automatic installation of zerotier-cli if not present
- Connection management to specified network
- Connection testing between users on the same network
- Automatic reconnection on network issues
- Status reporting and diagnostics

**Specification File**: See `specs/zerotier.md` for detailed requirements

## How to Work with This Repository

### For AI Agents

1. **Read First**: Always start by reading `progress.md` to understand current state
2. **Update Progress**: Update `progress.md` after completing tasks or discovering issues
3. **Follow Specs**: Refer to files in `specs/` for feature requirements
4. **Test Everything**: Verify idempotency and error handling for all scripts
5. **Maintain Structure**: Keep the directory structure organized and logical

### Adding New Features

1. Create a specification file in `specs/[feature-name].md`
2. Define clear requirements, use cases, and testing criteria
3. Implement in appropriate subdirectory under `scripts/`
4. Update `install.sh` to include new feature if needed
5. Document in `README.md` for end users
6. Update `progress.md` with completion status

### Modifying Existing Features

1. Check `specs/` for the feature specification
2. Ensure changes maintain backward compatibility
3. Update specification if requirements change
4. Test thoroughly on Bazzite OS
5. Update documentation as needed

## Common Utilities

Location: `scripts/common/utils.sh`

Expected functions (to be implemented):
- `log_info()`: Info-level logging
- `log_warn()`: Warning-level logging
- `log_error()`: Error-level logging
- `check_command()`: Verify command availability
- `is_bazzite()`: Verify running on Bazzite OS
- `require_root()`: Ensure script runs with appropriate privileges
- `backup_file()`: Create backup before modifying files

## Security Considerations

- **No Hardcoded Secrets**: Never commit API keys, passwords, or tokens
- **User Confirmation**: Prompt for confirmation on destructive operations
- **Privilege Escalation**: Only request sudo when absolutely necessary
- **Input Validation**: Validate all user inputs and external data
- **Safe Defaults**: Use secure defaults for all configurations

## Maintenance

### Regular Tasks
- Keep dependencies updated
- Test on latest Bazzite releases
- Review and update documentation
- Monitor for security issues

### Deprecation Process
1. Mark feature as deprecated in documentation
2. Add deprecation warnings to scripts
3. Maintain for at least one major version
4. Remove and update all references

## Progress Tracking

**Primary File**: `progress.md`

This file serves as the single source of truth for:
- Current development status
- Completed tasks
- Pending tasks
- Known issues
- Future enhancements

AI agents should:
- Read `progress.md` at the start of each session
- Update it after completing work
- Add new tasks as they're identified
- Mark tasks complete with timestamps

## Questions or Issues?

When encountering ambiguity:
1. Check existing specifications in `specs/`
2. Review `progress.md` for context
3. Look for similar patterns in existing code
4. If still unclear, document the question in `progress.md` for human review

## Key Principles

1. **Simplicity**: Keep scripts simple and focused
2. **Reliability**: Prioritize stability over features
3. **User-Friendly**: Design for non-technical users
4. **Maintainability**: Write code that's easy to understand and modify
5. **Documentation**: Keep docs in sync with code

---

**Last Updated**: 2025-11-16
**Repository**: https://github.com/AutoMas0n/bazzite-pipe
**Maintainer**: AutoMas0n
