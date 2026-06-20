# unleash

Single-script MDM bypass for macOS. Apple Silicon + Intel. Recovery mode.

## Quick install

```bash
# Homebrew (easiest)
brew install mateussiqueira/unleash/unleash

# Or download directly
curl -L https://raw.githubusercontent.com/mateussiqueira/unleash/main/unleash-standalone.sh -o unleash
chmod +x unleash && sudo ./unleash
```

## Commands

| Command | What it does |
|---------|-------------|
| `bypass` | Full MDM bypass from Recovery |
| `suppress` | Silence enrollment, no user |
| `heal` | Fix after macOS updates |
| `persist` | Auto-heal on every boot |
| `firewall` | Block MDM at kernel level (pf) |
| `whitelist` | Block MDM only, keep iCloud |
| `harden` | Kill MDM + remove profiles |
| `audit` | Deep scan + risk score |
| `check` | Pre-format safety report |
| `monitor` | Watch MDM every 5min |
| `doctor` | Pre-flight diagnostics |
| `report` | Full system status |
| `demo` | Simulated bypass (no real changes) |
| `vpn-kill` | Block MDM outside VPN |
| `update` | Self-update from GitHub |
| `uninstall` | Remove all traces |
| `test` | Dry-run simulation |

## Documentation

- [Full README](https://github.com/mateussiqueira/unleash)
- [Quick Reference](https://github.com/mateussiqueira/unleash/blob/main/QUICKSTART.md)
- [Contributing](https://github.com/mateussiqueira/unleash/blob/main/CONTRIBUTING.md)
- [Changelog](https://github.com/mateussiqueira/unleash/blob/main/CHANGELOG.md)
