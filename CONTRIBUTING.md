# Contributing to unleash

Thank you for considering contributing to unleash! This document outlines the guidelines for contributions.

## Code of Conduct

This project follows a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

## How to Contribute

### Reporting Issues

- **Bug reports**: Open an issue with the `bug` label. Include macOS version, hardware (Intel/Apple Silicon), and steps to reproduce.
- **Feature requests**: Open an issue with the `enhancement` label. Describe the problem and the proposed solution.
- **Compatibility reports**: Open an issue with the `compatibility` label if you've tested on a new macOS version or hardware.

### Pull Requests

1. Fork the repository
2. Create a feature branch from `main`
3. Follow the existing code style (ShellCheck compliant)
4. Test your changes:
   - Syntax check: `bash -n lib/*.sh unleash`
   - ShellCheck: `shellcheck lib/*.sh unleash` (install via `brew install shellcheck`)
5. Update documentation (README.md) if adding features
6. Open a PR against `main`

### Code Style

- **Shell**: Bash 3.2+ compatible (macOS default)
- **Naming**: Functions → `snake_case`, Constants → `UPPER_CASE`
- **Error handling**: Use `set -euo pipefail` in the main script
- **Library functions**: Return 0 on success, call `error_exit` on failure
- **Portability**: Avoid GNU-specific flags; prefer macOS-compatible options

### Testing

- Manual testing is required for now
- Preferred environments: macOS Recovery mode (Intel and Apple Silicon)
- Test both `bypass` (from Recovery) and `suppress`/`heal` (from booted system)

## Areas Needing Help

- **New macOS version compatibility**: Test on latest macOS releases
- **Additional MDM domains**: Research and add new Apple MDM endpoints
- **Firewall improvements**: Better pf rules for selective blocking
- **Documentation**: Translations, better troubleshooting guides
- **CI/CD**: GitHub Actions for automated ShellCheck and syntax validation

## Questions?

Open a discussion or issue. We aim to respond within 48 hours.
