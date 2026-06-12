# unleash — Unified MDM Bypass for macOS

A single tool to bypass, suppress, backup, restore, and check MDM enrollment on macOS.

## Why unleash?

The original project (bypass-mdm) grew into 5 separate scripts. This one unifies everything:

| Feature | bypass-mdm | unleash |
|---------|-----------|---------|
| Full bypass (admin + suppress) | v2/v3/express | `unleash bypass` |
| Suppress only (no user) | v3 only | `unleash suppress` |
| Backup + Restore | express only | `unleash backup / restore` |
| Dual-boot | dualboot.sh | `unleash dualboot` |
| Status check | v3 verify | `unleash status` |
| Auto-detect Recovery | partial | Always |
| FileVault unlock | v3 | Yes |
| Org MDM host blocking | v3 | Yes |
| Daemon disable (durable) | v3 | Yes |
| Interactive menu | all | Yes |
| CLI flags | none | Yes |

## Quick Start

### From an external SSD (recommended)

1. Copy the `unleash` folder to your SSD
2. Boot into Recovery mode (hold Power on Apple Silicon)
3. Open Terminal → `chmod +x "/Volumes/YourSSD/unleash/unleash"`
4. Run: `"/Volumes/YourSSD/unleash/unleash"`

### One-liner (download)

```bash
curl -L https://raw.githubusercontent.com/mateussiqueira/unleash/main/unleash -o unleash
chmod +x unleash && ./unleash bypass
```

### Commands

| Command | Description |
|---------|-------------|
| `./unleash` | Interactive menu (auto-detects mode) |
| `./unleash bypass` | Full bypass — create admin + suppress MDM |
| `./unleash suppress` | Suppress enrollment only (no user) |
| `./unleash backup` | Backup current state |
| `./unleash restore` | Restore from backup |
| `./unleash dualboot` | Target a dual-boot volume (needs sudo) |
| `./unleash status` | Check MDM status |
| `./unleash version` | Show version |

## Safety

- All writes target the **Data volume** (SSV-safe on Apple Silicon)
- Backups can restore original state
- Never runs `profiles renew`
- Never touches Apple Business Manager records

## Architecture

```
unleash/
├── unleash          # Single entry point (CLI + interactive)
├── lib/
│   ├── colors.sh    # UI colors and helpers
│   ├── detect.sh    # Volume detection, Recovery/dualboot mode
│   ├── validate.sh  # Username/password validation
│   ├── dscl.sh      # Directory Services operations
│   ├── suppress.sh  # Core MDM suppression logic
│   ├── backup.sh    # Backup and restore
│   └── status.sh    # Verify and status check
├── examples/
├── README.md
└── LICENSE
```

## Legal

This only suppresses MDM locally. Your serial stays in the org's Apple Business Manager. The permanent fix is them releasing it.

Use on devices you own. I'm not responsible for what you do with this.
