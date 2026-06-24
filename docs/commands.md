---
layout: default
title: Commands Reference — unleash
---

# Commands Reference

## Bypass & Suppress

| Command | Description | Recovery | Booted |
|---------|-------------|----------|--------|
| `bypass` | Full bypass: create admin user + suppress MDM | ✓ | ✗ |
| `suppress` | Suppress enrollment without creating a user | ✓ | ✓ |
| `heal` | Re-apply suppression after macOS updates | ✓ | ✓ |
| `persist` | Install LaunchDaemon for auto-heal on every boot | ✓ | ✓ |
| `unpersist` | Remove the auto-heal LaunchDaemon | ✗ | ✓ |

### `bypass`
Creates a temporary admin account and suppresses all 5 layers of MDM.
**Must run from Recovery.**
```bash
./unleash bypass
```

### `suppress`
Silences MDM enrollment without creating a new user.
Works from both Recovery and booted systems.
```bash
sudo ./unleash suppress
```

### `heal`
Re-applies suppression after macOS updates re-enable enrollment daemons.
On booted systems, needs sudo. With `persist`, runs automatically on each boot.
```bash
sudo ./unleash heal
```

### `persist`
Installs a LaunchDaemon that runs `heal` automatically on every boot.
Survives macOS updates.
```bash
sudo ./unleash persist
```

### `unpersist`
Removes the persistence LaunchDaemon.
```bash
sudo ./unleash unpersist
```

---

## Firewall & Network

| Command | Description | Privilege |
|---------|-------------|-----------|
| `firewall` | Block Apple MDM IP ranges via pf | sudo |
| `firewall-off` | Remove pf firewall MDM block | sudo |
| `whitelist` | Block MDM domains only, keep iCloud/App Store | sudo |

### `firewall`
Kernel-level packet filtering. Blocks Apple's entire IP range (`17.0.0.0/8`).
DoH-proof — cannot be bypassed by DNS-over-HTTPS.
**Warning:** Breaks iCloud, App Store, and system updates.
```bash
sudo ./unleash firewall
```

### `firewall-off`
Removes pf firewall rules added by `firewall`.
```bash
sudo ./unleash firewall-off
```

### `whitelist`
Resolves only MDM domains to IPs and blocks those specifically.
Keeps iCloud and App Store working while blocking MDM enrollment.
```bash
sudo ./unleash whitelist
```

---

## Living System

| Command | Description | Privilege |
|---------|-------------|-----------|
| `harden` | Kill MDM processes + remove profiles + flush DNS | sudo |
| `audit` | Deep system scan with risk score | sudo |

### `harden`
Kills running MDM processes, removes configuration profiles, and flushes DNS cache.
Useful when MDM is actively enrolling on a booted system.
```bash
sudo ./unleash harden
```

### `audit`
Performs a deep MDM scan:
- Checks DEP markers
- Scans for configuration profiles
- Checks launch agents and daemons
- Searches for MDM certificates
- Generates a risk score (0–100)
```bash
sudo ./unleash audit
```

---

## Monitoring

| Command | Description |
|---------|-------------|
| `check` | Pre-format / pre-upgrade safety report |
| `monitor` | Start background MDM watcher (5 min interval) |
| `monitor-install` | Install monitor as a LaunchDaemon |
| `monitor-uninstall` | Remove monitor LaunchDaemon |
| `monitor-stop` | Stop the monitor daemon |
| `monitor-status` | Check if the monitor is running |
| `history` | Show event log from monitor/heal runs |
| `history-clear` | Clear the event log |

### `check`
Returns **SAFE TO FORMAT** (no MDM) or **MDM DETECTED** (will lock after wipe).
Also checks upgrade safety for macOS updates.
```bash
sudo ./unleash check
```

### `monitor`
Background daemon that checks MDM state every 5 minutes.
Sends a macOS notification if MDM tries to re-enroll.
Supports optional `--webhook` for Discord alerts.
```bash
sudo ./unleash monitor
sudo ./unleash monitor --webhook https://discord.com/api/webhooks/...
```

### `history`
Shows the event log from previous monitor and heal runs.
```bash
sudo ./unleash history
```

---

## State Management

| Command | Description |
|---------|-------------|
| `backup` | Save current state (hosts, profiles, launchd, settings) |
| `restore` | Restore from a previous backup |
| `dualboot` | Target an external macOS install |

### `backup`
Saves `/etc/hosts`, MDM profile state, launchd disabled overrides, and Unleash config.
```bash
sudo ./unleash backup
```

### `restore`
Reverts the system to a previously saved state.
```bash
sudo ./unleash restore
```

### `dualboot`
Creates an admin account and applies suppression to an external/bootcamp volume.
```bash
sudo ./unleash dualboot
```

---

## Smart Commands (v2.0)

| Command | Description |
|---------|-------------|
| `init` | Interactive setup wizard |
| `suggest` | Risk-based system analysis and recommendations |
| `remediate` | Per-org MDM cleanup |
| `predict` | Serial number lookup — predict which org enrolled this Mac |
| `telemetry` | Manage anonymous usage stats (opt-in) |

### `init`
Interactive wizard that runs the full setup:
firewall → monitor → persist → backup → audit.
```bash
sudo ./unleash init
```

### `suggest`
Analyzes your system and provides risk-based recommendations.
```bash
sudo ./unleash suggest
```

### `remediate`
Per-org MDM cleanup. Supports: JAMF, Mosyle, Addigy, Kandji, VMware.
Auto-detects the org from your DEP record.
```bash
sudo ./unleash remediate
```

### `predict`
Reads the serial number prefix and checks against known MDM org prefixes.
Useful before buying a used Mac.
```bash
./unleash predict ABC12345678
```

### `telemetry`
Manages anonymous usage stats (opt-in, OFF by default).
```bash
./unleash telemetry on
./unleash telemetry off
./unleash telemetry status
```

---

## VPN Kill-Switch

| Command | Description |
|---------|-------------|
| `vpn-kill` | Install pf kill-switch — blocks MDM outside VPN |
| `vpn-kill-remove` | Remove the VPN kill-switch |
| `vpn-kill-status` | Check VPN kill-switch state |

Designed for org-provided Macs that must enroll but should only communicate while on VPN.
Blocks MDM IPs when the device is NOT connected to your VPN tunnel.
```bash
sudo ./unleash vpn-kill
sudo ./unleash vpn-kill-status
sudo ./unleash vpn-kill-remove
```

---

## Management

| Command | Description |
|---------|-------------|
| `update` | Self-update from the latest GitHub release |
| `uninstall` | Complete removal with safety prompts |
| `reinstall` | Uninstall + reinstall (persist + whitelist + monitor) |
| `config` | View or edit persistent settings |
| `report` | Full system report (markdown or JSON) |
| `demo` | Simulated bypass flow (no real changes) |
| `version` | Show version |

### `update`
Downloads the latest release from GitHub. GPG-verifies the signature.
```bash
sudo ./unleash update
```

### `uninstall`
Removes all Unleash traces. Prompts for confirmation.
```bash
sudo ./unleash uninstall
```

### `reinstall`
Uninstalls then re-applies persist + whitelist + monitor.
```bash
sudo ./unleash reinstall
```

### `config`
View or edit persistent settings in `~/.unleash.conf`.
```bash
./unleash config
./unleash config show
./unleash config set key value
```

### `report`
Generates a full status report. Supports `--json` for machine-readable output.
```bash
sudo ./unleash report
sudo ./unleash report --json
```

### `demo`
Runs a simulated bypass flow. No real changes are made.
```bash
./unleash demo
```

---

## Discord Bot

| Command | Description |
|---------|-------------|
| `discord-bot` | Start Discord DM alert bot |
| `discord-bot-stop` | Stop the Discord bot |
| `discord-bot-status` | Check if the Discord bot is running |

Sends Discord DMs when MDM activity is detected.
```bash
sudo ./unleash discord-bot <token> <userId>
sudo ./unleash discord-bot-status
sudo ./unleash discord-bot-stop
```

---

## Diagnostics

| Command | Description |
|---------|-------------|
| `doctor` | Pre-flight diagnostics — root, Recovery, libs, disk, dependencies |
| `status` | MDM enrollment status (Recovery only, use `-d` for deep) |
| `test` | Dry-run simulation of any command |

### `doctor`
Checks: root privileges, Recovery mode detection, bash version,
disk/volume availability required libraries, and internet connectivity.
```bash
./unleash doctor
```

### `status`
Shows DEP marker state, hosts file, daemon overrides.
Only works from Recovery. Use `check` or `audit` on booted systems.
```bash
./unleash status
./unleash status -d
```

### `test`
Dry-run mode. Simulates a command without making real changes.
```bash
./unleash test bypass
./unleash test all
```

---

## Aliases

```
by  = bypass         sv  = suppress        st  = status
ls  = status         fw  = firewall        fw-off = firewall-off
wl  = whitelist      mn  = monitor         mn-install = monitor-install
mn-uninstall = monitor-uninstall           mn-stop = monitor-stop
mn-st = monitor-status                     doc = doctor
up  = update         uni = uninstall       rei = reinstall
vk  = vpn-kill       vkr = vpn-kill-remove vks = vpn-kill-status
```

---

## Global Options

| Option | Effect |
|--------|--------|
| `--verbose` | Show debug messages |
| `--dry-run` | Simulate without making changes |
| `--log-file <path>` | Write logs to file (appended) |
