# Changelog

## [1.0.0] — 2026-06-20

### Added
- Initial release of unleashes — Unified MDM Bypass for macOS
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
