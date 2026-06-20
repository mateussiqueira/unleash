# unleash

Single-script MDM bypass for macOS. Works from Recovery mode. Apple Silicon and Intel.

## Quick start

1. Copy the unleash folder to an external SSD (FAT32/APFS/exFAT)
2. Boot to Recovery (hold Power on AS, Cmd+R on Intel)
3. Open Terminal from Utilities, then:

```bash
chmod +x "/Volumes/YourSSD/unleash/unleash"
"/Volumes/YourSSD/unleash/unleash" bypass
```

No internet needed if running from an SSD. No SIP to disable.

## Commands

| Command | What it does |
|---------|-------------|
| `bypass` | Full bypass — creates admin user + suppresses MDM |
| `suppress` | Silence enrollment, no user created |
| `heal` | Check + re-apply suppression after updates |
| `persist` | Install LaunchDaemon so heal runs on every boot |
| `unpersist` | Remove the boot-time LaunchDaemon |
| `firewall` | Block Apple MDM IPs at kernel level via pf (blocks iCloud too) |
| `firewall-off` | Remove the pf block |
| `whitelist` | Block only MDM endpoints, keep iCloud/App Store |
| `harden` | Kill MDM processes, remove profiles, flush DNS |
| `audit` | Deep system scan + risk assessment |
| `backup` | Save current hosts, profiles, launchd state |
| `restore` | Revert from backup |
| `dualboot` | Target an external macOS install |
| `check` | Pre-format report: will this Mac lock after a wipe? |
| `monitor` | Background daemon that watches MDM state and auto-heals |
| `monitor-stop` | Stop the background monitor |
| `monitor-status` | Check if monitor is running |

Just `./unleash` with no argument shows an interactive menu.

### Monitor

```bash
sudo ./unleash monitor
```

Runs in the background and checks MDM state every 5 minutes. If MDM tries to re-enroll, it auto-heals and sends a macOS notification. Survives reboots only if combined with `unleash persist` (which can run the monitor instead of heal). Logs to `/var/log/unleash-monitor.log`.

### Check

```bash
sudo ./unleash check
```

Answers one question: **"If I wipe this Mac, will it lock?"** Checks DEP records, profiles, enrollment state, firewall, and persistence. Also checks if a macOS upgrade is safe.

## How it works

MDM enrollment sits on four layers. Unleash hits all of them:

1. **DEP markers** — `/private/var/db/ConfigurationProfiles/Settings/.cloudConfig*` files. Remove them, set decoy files.
2. **Network** — `/etc/hosts` blocks 13+ Apple MDM domains plus the org MDM host.
3. **Launchd daemons** — disable `ManagedClient.enroll`, `ManagedClient.cloudConfiguration`, `mdmclient.daemon.runatboot`, `activationd`.
4. **User artifacts** — clean per-user MDM prefs, caches, LaunchAgents from `/Users/*/Library`.

The pf firewall layer (commands `firewall`/`whitelist`) catches what `/etc/hosts` misses — especially DNS-over-HTTPS bypass.

## Why not bypass-mdm?

The original project grew into 5 scripts (v2, v3, express, dualboot.sh, verify.sh) with inconsistent CLI. Unleash replaces all of them in one script.

## Intel vs Apple Silicon

Recovery entry differs (Cmd+R vs hold Power). On Apple Silicon the system volume is cryptographically signed (SSV) — all writes target the Data volume. Everything else is the same.

## Migration Assistant failure

If you migrate from Intel to AS, MDM will come back after reboot because Migration Assistant copies user-level artifacts. The old suppress scripts miss these. Unleash cleans `/Users/*/Library` explicitly. If it still returns after that, run `harden` from the booted system.

## Troubleshooting

**MDM comes back after reboot** — run `unleash suppress` from Recovery again. If it's persistent, you probably have Migration Assistant artifacts. Run `unleash harden` after login.

**profiles shows enrollment** — cosmetic. The SSV stores profile state read-only. Check DEP markers instead with `unleash status`.

**FileVault unlock fails** — you need a user password or the recovery key.

**macOS update resets everything** — run `unleash heal`. If you ran `persist` before the update, it does this automatically.

## Limitations

- Your serial stays in Apple Business Manager. Only the organization can remove it.
- A full wipe (erase install) clears the Data volume — you need to re-run from Recovery.
- The hosts block can be bypassed by cached DNS or DoH. pf firewall fixes this.
- If your org uses hardware-based enrollment (DEP + ABM + device lock), you might need a DFU restore. See DFU/IPSW guide in the repo.

## Legal

This suppresses MDM locally on devices you own. It doesn't touch ABM records. The permanent fix is the organization releasing the device.
