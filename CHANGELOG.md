# Changelog

## [1.2.0] — 2026-06-20

### Added
- **check**: Pre-format / pre-upgrade assessment (will this Mac lock after wipe?)
- **monitor**: Background daemon that watches MDM every 5 minutes and auto-heals
- **monitor-stop**: Stop the background monitor
- **monitor-status**: Check if monitor is running
- GitHub repo About section updated with description and topics

## [1.1.0] — 2026-06-20

### Added
- Project files: CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CHANGELOG.md
- GitHub issue templates (bug, feature, compatibility)
- GitHub Actions CI (ShellCheck, syntax check, markdown lint)
- Badges and professional README layout

### Changed
- Humanized code: removed AI artifacts, file headers, section comments
- README rewritten from scratch (625 → 140 lines)

## [1.0.0] — 2026-06-20

### Added
- Initial release of unleash — Unified MDM Bypass for macOS
- **bypass**: Full MDM bypass with admin user creation (Recovery mode)
- **suppress**: Suppress MDM enrollment without creating a user
- **heal**: Auto-heal — check and re-apply suppression after macOS updates
- **persist**: Install LaunchDaemon for boot-time auto-heal
- **unpersist**: Remove the persistence LaunchDaemon
- **firewall**: Block Apple MDM IP ranges via pf (DoH-proof)
- **firewall-off**: Remove pf firewall MDM block
- **harden**: Live-OS hardening (kill MDM, remove profiles, flush DNS)
- **audit**: Deep MDM audit (profiles, certs, agents, risk scoring)
- **whitelist**: Selective block (block MDM only, keep iCloud/App Store)
- **backup/restore**: Save and revert all changes
- **dualboot**: Target external or dual-boot volumes
- **status**: MDM status check with deep audit mode
- User-level MDM artifact cleanup (Preferences, Caches, LaunchAgents)
- Expanded domain blocking (13 Apple MDM domains + org MDM host)
- 4 enrollment daemon overrides (launchd disabled.plist)
- Intel T2 and Apple Silicon support
- DFU/IPSW restore guide in documentation
- macOS Tahoe 26.x compatibility
