# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 1.x     | ✅ Currently supported |

## Reporting a Vulnerability

This tool modifies system configuration to suppress MDM enrollment. While designed to be safe (SSV-safe, reversible via backup/restore), please report any security concerns.

To report a vulnerability:

1. **Do NOT** open a public issue
2. Open a [security advisory](https://github.com/mateussiqueira/unleash/security/advisories) privately
3. Or email the maintainer directly

## Safety Guarantees

- **No system volume writes**: All operations target the Data volume only
- **Reversible**: `unleash backup`/`restore` saves and reverts all changes
- **No data loss**: Never runs `profiles renew` or erase commands
- **No ABM modification**: Does not touch Apple Business Manager records

## Known Limitations

- Serial numbers remain in ABM after bypass
- macOS updates may reset suppression (use `unleash heal`)
- Profile enrollment status may still show as active (cosmetic, from SSV)
