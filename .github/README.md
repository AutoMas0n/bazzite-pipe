# Quick Reference for AI Agents

This directory contains GitHub-specific files. For comprehensive project documentation, see the root directory.

## Essential Files (Read These First)

1. **[../AGENTS.md](../AGENTS.md)** - Main AI agent instructions
2. **[../progress.md](../progress.md)** - Current development status
3. **[../specs/zerotier.md](../specs/zerotier.md)** - ZeroTier feature specification

## Workflow

1. Read `progress.md` to understand current status
2. Check `AGENTS.md` for development guidelines
3. Review relevant spec in `specs/` directory
4. Implement following the bash script template
5. Test thoroughly on Bazzite OS
6. Update `progress.md` with changes

## Key Principles

- **Idempotency**: All scripts must be safe to run multiple times
- **Error Handling**: Use `set -euo pipefail`
- **Testing**: Test on Bazzite OS before considering complete
- **Documentation**: Update progress.md after every change

---

For full documentation, see [../AGENTS.md](../AGENTS.md)
