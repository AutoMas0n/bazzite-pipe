# Contributing to bazzite-pipe

Thank you for your interest in contributing to bazzite-pipe! This document provides guidelines for contributing to the project.

## Getting Started

1. **Read the Documentation**
   - Review [AGENTS.md](AGENTS.md) for comprehensive project guidelines
   - Check [progress.md](progress.md) for current development status
   - Read feature specifications in [specs/](specs/)

2. **Set Up Your Environment**
   - Fork the repository
   - Clone your fork locally
   - Ensure you have a Bazzite OS installation for testing

## Development Guidelines

### Code Style

All bash scripts must follow these conventions:

- **Idempotency**: Scripts must be safe to run multiple times
- **Error Handling**: Use `set -euo pipefail` at the start of all scripts
- **Functions**: Prefix internal functions with underscore (e.g., `_internal_function`)
- **Variables**: Use UPPERCASE for constants, lowercase for local variables
- **Logging**: Use consistent logging functions (info, warn, error)
- **Exit Codes**: 0 for success, non-zero for failures

### Script Template

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

## Testing Requirements

Before submitting a pull request:

1. **Manual Testing**
   - Test on a clean Bazzite installation
   - Test with feature already installed (idempotency)
   - Test error scenarios

2. **Idempotency Testing**
   - Run your script at least twice
   - Verify no errors or duplicate entries
   - Confirm state remains consistent

3. **Documentation**
   - Update relevant specifications
   - Update README.md if adding user-facing features
   - Update progress.md with your changes

## Submitting Changes

### Pull Request Process

1. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Your Changes**
   - Follow the code style guidelines
   - Write clear, descriptive commit messages
   - Keep commits focused and atomic

3. **Test Thoroughly**
   - Run all relevant tests
   - Verify idempotency
   - Test error handling

4. **Update Documentation**
   - Update AGENTS.md if changing project structure
   - Update progress.md with completed tasks
   - Update README.md for user-facing changes
   - Update or create specifications in specs/

5. **Submit Pull Request**
   - Provide clear description of changes
   - Reference any related issues
   - Include testing notes

### Commit Message Guidelines

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- First line should be 50 characters or less
- Reference issues and pull requests when relevant

Example:
```
Add ZeroTier installation script

- Implements automatic zerotier-cli installation
- Adds service management and verification
- Includes idempotency checks
- Updates progress.md

Closes #123
```

## Adding New Features

1. **Create a Specification**
   - Create a new file in `specs/[feature-name].md`
   - Define requirements, use cases, and testing criteria
   - Get feedback before implementation

2. **Implement the Feature**
   - Create appropriate directory structure
   - Follow the script template
   - Use common utilities where possible

3. **Update Documentation**
   - Add feature to README.md
   - Update AGENTS.md if needed
   - Update progress.md

4. **Test Thoroughly**
   - Test on Bazzite OS
   - Verify idempotency
   - Test error scenarios

## Code Review Process

All submissions require review. We use GitHub pull requests for this purpose.

Reviewers will check for:
- Code quality and style compliance
- Idempotency and error handling
- Documentation completeness
- Test coverage
- Security considerations

## Security

- Never commit secrets, API keys, or passwords
- Validate all user inputs
- Request minimal privileges
- Prompt for confirmation on destructive operations

## Questions?

- Open an issue for bugs or feature requests
- Start a discussion for questions or ideas
- Check existing issues and discussions first

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to bazzite-pipe! 🎉
