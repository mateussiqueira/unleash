<p align="center">
  <img src="docs/icon.svg" width="120" alt="unleash logo">
</p>

# unleash

Single-script MDM bypass for macOS. Works from Recovery mode on Apple Silicon and Intel.

I started this because the original bypass-mdm project had five different scripts (v2, v3, express, dualboot.sh, verify.sh), each with slightly different options and none of them handling the full problem after Migration Assistant. This replaces all of them in one file.

## Quick start

1. Copy the `unleash` folder to an external SSD (FAT32, APFS, or exFAT)
2. Boot to Recovery:
   - **Apple Silicon**: hold the power button until you see "Loading Startup Options", then click Options → Continue
   - **Intel**: Cmd+R at the startup chime
3. Open Terminal from the Utilities menu
4. Run:

```bash
chmod +x "/Volumes/YourSSD/unleash/unleash"
"/Volumes/YourSSD/unleash/unleash"
```

Pick "Full bypass" from the menu. Or if you know what you want:

```bash
"/Volumes/YourSSD/unleash/unleash" bypass
```

No internet needed. No SIP to disable. No typing long URLs.

If you do have internet in Recovery:

```bash
curl -L https://raw.githubusercontent.com/mateussiqueira/unleash/main/unleash -o /tmp/unleash
chmod +x /tmp/unleash && /tmp/unleash bypass
```

---

## Commands

### bypass — Full MDM bypass (Recovery only)

```bash
./unleash bypass
```

Creates a temporary admin account and suppresses MDM. What it does:

1. Finds and mounts the macOS Data volume
2. Unlocks FileVault if needed (asks for password)
3. Creates an admin user (default Apple / 1234)
4. Removes DEP activation records
5. Blocks 13+ Apple MDM domains plus your org's MDM host
6. Disables 4 enrollment daemons
7. Cleans user-level MDM artifacts from all home directories
8. Sets .AppleSetupDone so Setup Assistant is skipped

### suppress — Silence enrollment, no user

```bash
./unleash suppress
```

Same as bypass minus the user creation. Useful after a clean bypass breaks from a macOS update.

### heal — Check and re-apply

```bash
sudo ./unleash heal       # from booted system
./unleash heal            # from Recovery
```

Checks if suppression is still intact. If any piece (DEP markers, hosts block, daemon disable) has been reset, it re-applies it. Safe to run repeatedly.

### persist — Boot-time auto-heal

```bash
sudo ./unleash persist
```

Installs a LaunchDaemon at `/Library/LaunchDaemons/com.unleash.heal.plist` that runs `unleash heal` on every boot and every 24 hours after that. Logs go to `/var/log/unleash-heal.log`.

Use this before a macOS upgrade. When the update finishes and reboots, heal runs automatically and re-applies anything the update reset.

### unpersist — Remove auto-heal

```bash
sudo ./unleash unpersist
```

Removes the LaunchDaemon and unloads it.

### firewall — Kernel-level MDM block

```bash
sudo ./unleash firewall
```

Creates pf firewall rules that drop traffic to Apple's MDM IP ranges (17.0.0.0/8 and 17.128.0.0/10). pf works below DNS — DNS-over-HTTPS cannot bypass it.

**Warning**: this blocks all Apple services. iCloud, App Store, and system updates will not work while the firewall is active. Use `whitelist` instead if you need those.

### firewall-off — Remove firewall

```bash
sudo ./unleash firewall-off
```

Flushes the Unleash pf anchor and restores pf.conf.

### whitelist — Block only MDM, keep iCloud

```bash
sudo ./unleash whitelist
```

Alternative to `firewall` that resolves only the essential MDM domains (mdmenrollment.apple.com, deviceenrollment.apple.com, iprofiles.apple.com) to IPs and blocks those, leaving everything else untouched. iCloud, App Store, and updates should work normally.

### harden — Live cleanup from booted system

```bash
sudo ./unleash harden
```

Runs from the logged-in desktop after bypass. Does:

1. Kills ManagedClient, mdmclient, activationd
2. Forces profile removal
3. Scans and removes MDM LaunchAgents per user
4. Flushes DNS cache, restarts mDNSResponder
5. Checks keychain for MDM identity certs
6. Looks for JAMF/Intune/Workspace ONE agents
7. Disables iCloud Private Relay (a DoH loophole)

### audit — Deep system scan

```bash
sudo ./unleash audit
```

Comprehensive scan that checks: installed profiles, enrollment state, keychain certificates, user LaunchAgents, system LaunchDaemons, running processes, MDM agent binaries, pf firewall status. Ends with a risk score (LOW / MEDIUM / HIGH / CRITICAL).

### status — MDM health check (Recovery only)

```bash
./unleash status
```

Shows DEP markers, hosts block, daemon overrides, profile enrollment, and backup status. Only works from Recovery because that's where the Data volume is cleanly accessible.

### check — Pre-format / pre-upgrade assessment

```bash
sudo ./unleash check
```

Answers: **"If I wipe this Mac, will it lock?"** Checks DEP records, profiles, enrollment state, firewall, and persistence. Also does an upgrade safety check — tells you if `persist` and `firewall` are installed before you upgrade macOS.

Returns one of two verdicts:

- **SAFE TO FORMAT** — no MDM enrollment detected
- **MDM DETECTED** — this Mac will lock after a wipe. Run bypass from Recovery afterward.

### monitor — Background MDM watcher

```bash
sudo ./unleash monitor
```

Starts a daemon that checks MDM state every 5 minutes. If it detects MDM trying to re-enroll (DEP record appears, hosts block missing, enrollment becomes active), it auto-heals and sends a macOS notification.

```bash
sudo ./unleash monitor-stop      # stop it
sudo ./unleash monitor-status    # check if it's running
```

Logs everything to `/var/log/unleash-monitor.log`. The daemon does not survive a reboot on its own — combine with `persist` for persistence.

### backup / restore — State save

```bash
./unleash backup
./unleash restore
```

Backup saves hosts, config profiles, and launchd override to `.unleash-backup/`. Restore reverts them.

### dualboot — External volume target

```bash
sudo ./unleash dualboot
```

Same as bypass but lets you pick which volume to target (for external macOS installs or dual-boot setups). Prompts for system and data volume names.

### version / help

```bash
./unleash version
./unleash help
```

---

## Aliases

Every command has a shorter alias:

| Alias | Full command |
|-------|-------------|
| `by` | bypass |
| `sv` | suppress |
| `st`, `ls` | status |
| `fw` | firewall |
| `fw-off` | firewall-off |
| `wl` | whitelist |
| `mn` | monitor |
| `mn-stop` | monitor-stop |
| `mn-st` | monitor-status |

---

## Options

Global options that can go before any command:

| Option | Effect |
|--------|--------|
| `--verbose` | Show debug messages |
| `--log-file <path>` | Write log output to file |

Example:
```bash
sudo ./unleash --verbose --log-file /tmp/unleash.log heal
```

---

## How it works

MDM enrollment on macOS sits on four layers. Unleash addresses each one.

### Layer 1: DEP activation record

When an organization assigns a device in Apple Business Manager, macOS creates marker files at:

```
/private/var/db/ConfigurationProfiles/Settings/
  .cloudConfigHasActivationRecord   ← "this serial has DEP"
  .cloudConfigRecordFound           ← "enrollment was triggered"
  .cloudConfigTimerCheck            ← "check again later"
```

Unleash removes these and creates decoy files (`.cloudConfigRecordNotFound`, `.cloudConfigProfileInstalled`) that signal "no enrollment needed."

### Layer 2: Network blocking

The enrollment client contacts Apple servers to download the MDM profile. Without network access, it cannot complete enrollment.

Unleash blocks via `/etc/hosts`:

- `iprofiles.apple.com` — profile delivery
- `deviceenrollment.apple.com` — DEP service
- `mdmenrollment.apple.com` — MDM service
- `acmdm.apple.com` — Apple Configurator MDM
- `axm-adm-mdm.apple.com` — ACM enrollment
- `albert.apple.com` — ABM device assignment
- `gdmf.apple.com` — MDM framework
- `configuration.apple.com` — config service
- `xp.apple.com` — device management
- `gs.apple.com` — device enrollment
- `tb.apple.com` — device trust
- `vpp.itunes.apple.com` — volume purchase
- Your org's MDM host (extracted from the DEP record)

Both IPv4 (0.0.0.0) and IPv6 (::) entries are added.

### Layer 3: Launchd daemon override

macOS registers enrollment daemons that run at boot:

| Daemon | What it does |
|--------|-------------|
| `com.apple.ManagedClient.enroll` | Main enrollment |
| `com.apple.ManagedClient.cloudConfiguration` | Cloud config |
| `com.apple.mdmclient.daemon.runatboot` | MDM client |
| `com.apple.activationd` | Device activation |

Unleash disables them via the launchd override at `/private/var/db/com.apple.xpc.launchd/disabled.plist`.

### Layer 4: User-level cleanup

Home directories carry MDM artifacts that trigger re-enrollment after login:

```
~/Library/Preferences/com.apple.mdm.*
~/Library/Preferences/com.apple.ManagedClient.*
~/Library/Application Support/com.apple.ManagedClient*/
~/Library/LaunchAgents/com.apple.mdm.*
```

Unleash removes these from every home directory on the Data volume. This is the step most scripts miss — and the reason MDM comes back after Migration Assistant.

### Layer 5: pf firewall (optional)

The hosts file can be bypassed by DNS-over-HTTPS or cached DNS. pf (packet filter) operates at the kernel level and is immune to both. Unleash installs pf rules that either:

- **firewall**: blocks Apple's entire IP range (17.0.0.0/8 + 17.128.0.0/10) — aggressive but 100% effective
- **whitelist**: resolves only MDM domains to IPs and blocks those specifically — keeps iCloud working

## Intel vs Apple Silicon

| | Intel T2 | Apple Silicon |
|---|---|---|
| Recovery | Cmd+R at boot | Hold power button |
| System volume | Writable with SIP disabled | Cryptographically signed (SSV) — read-only |
| FileVault unlock | diskutil apfs unlockVolume | Same, but needs user password or recovery key |
| Enrollment daemons | Fewer | activationd + cloudConfig |
| NVRAM flags | Some | More firmware-level flags |
| Migration Assistant | Less risky | **Carries MDM state** — see below |

On Apple Silicon, all writes target the Data volume. The system volume is never modified. SIP does not need to be disabled.

## Migration Assistant failure

This is the most common reason MDM comes back.

When you migrate from an Intel Mac to Apple Silicon (or between AS Macs), Migration Assistant copies:

- DEP activation records
- Enrolled configuration profiles
- User-level MDM preferences and caches
- Launch agents that re-trigger enrollment
- Keychain identity certificates

The old bypass scripts only clean system-level artifacts (DEP markers, hosts, launchd). The user-level stuff gets copied over and re-establishes enrollment on every login.

### Symptoms

- Remote Management screen appears after the first reboot
- Running suppress makes it go away temporarily
- MDM profile returns within about a minute of login

### Solution

**From Recovery**: run `unleash bypass` (or `suppress`). This cleans both system-level and user-level artifacts.

**If MDM still comes back**: boot normally, run `sudo ./unleash harden` immediately after login. This kills active MDM processes and removes profiles before they can re-establish.

**For prevention**: run `sudo ./unleash persist` and `sudo ./unleash whitelist` before Migration Assistant. The LaunchDaemon + pf rules survive the migration and catch anything that slips through.

## Hard lock: DFU / IPSW restore

If MDM is unbreakable — even from Recovery — the device may need a full firmware restore. This applies to Apple Silicon Macs only.

**You need**: a second Mac with Apple Configurator 2 (free from App Store), a USB-C cable, and the correct IPSW file for your Mac model.

**Steps**:
1. On the helper Mac, open Apple Configurator 2
2. Connect the locked Mac via USB-C while holding the power button
   - M1/M2: hold power 10s, keep holding while connecting USB-C
   - M3/M4: hold power + volume down 10s while connecting
3. The locked Mac appears as a DFU device in Configurator
4. Right-click → Advanced → Restore (pick the IPSW file)
5. Wait 10-30 minutes for restore to finish
6. Mac reboots to Setup Assistant — **do not connect to Wi-Fi**
7. Immediately boot to Recovery (hold power) and run `unleash bypass`

**This erases all data.** IPSW files are available at [ipsw.me](https://ipsw.me).

## Logging

All commands now log with timestamps and levels:

```
[INF] Data volume: /Volumes/Macintosh HD - Data
[ OK] Admin 'apple' created (UID 501)
[WRN] DEP activation record present
[ERR] Firewall needs sudo: sudo ./unleash firewall
[STP] Locating Data volume by APFS role...
[DBG] Checking pfctl availability
```

Use `--verbose` to see debug messages and `--log-file <path>` to write everything to a file.

## Files

```
unleash/
├── unleash                   # Main script (entry point)
├── lib/
│   ├── colors.sh             # Logging, colors, prompts
│   ├── detect.sh             # Recovery detection, volume mounting
│   ├── validate.sh           # Username/password validation
│   ├── dscl.sh               # Directory Services (user CRUD)
│   ├── suppress.sh           # DEP removal, hosts, daemon disable
│   ├── backup.sh             # Backup and restore
│   ├── status.sh             # Health check and audit
│   ├── heal.sh               # Auto-heal + LaunchDaemon persist
│   ├── firewall.sh           # pf rules management
│   ├── harden.sh             # Live-OS hardening
│   ├── whitelist.sh          # Selective iCloud-safe block
│   ├── check.sh              # Pre-format assessment
│   └── monitor.sh            # Background MDM watcher
├── README.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── CHANGELOG.md
└── LICENSE (MIT)
```

The standalone variant (`unleash-standalone.sh`) bundles everything into one file. Build it with `bash examples/build-standalone.sh`.

## Limitations

- **Your serial stays in ABM.** Only the organization can remove it. If the device ever connects to the internet with all protections removed, it will re-enroll.
- **A full wipe requires re-running.** Clean installs clear the Data volume. Boot to Recovery and run bypass again afterward.
- **macOS updates can reset daemons.** Always run `persist` before an update so `heal` runs automatically after.
- **`profiles status` may show enrollment.** This is cosmetic — the SSV stores profile state read-only. DEP markers and daemon disable take precedence.
- **The hosts file can be bypassed.** DNS-over-HTTPS and cached DNS bypass `/etc/hosts`. Use `firewall` or `whitelist` for the kernel-level fix.

## Safety

Unleash is designed to be safe:

- **No SSV writes** — all changes target the Data volume
- **Reversible** — `backup` saves state, `restore` reverts
- **No data erasure** — never runs `profiles renew` or erase commands
- **Idempotent** — running multiple times is harmless
- **Prompts for confirmation** before destructive actions

## Troubleshooting

### MDM comes back after reboot
Run `unleash suppress` from Recovery. If it still returns, you have Migration Assistant artifacts. Run `unleash harden` from the booted system.

### profiles shows enrollment
Cosmetic. The SSV stores profile state but the enrollment daemons are disabled. Run `unleash status` to check the actual state on the Data volume.

### FileVault unlock fails
You need a user password or the FileVault recovery key. If neither is available, the Data volume cannot be mounted from Recovery.

### "Not a macOS Data volume"
Unleash checks for `/private/var/db/dslocal/nodes/Default` on the mounted volume. If it's missing, you mounted the wrong disk. Run `diskutil list` to find the correct one.

### macOS 27 (or future version)
Unleash should work on any macOS version that uses the same MDM enrollment mechanism. If a new macOS changes the enrollment daemons or DEP markers, open an issue.

### Monitor won't start
Check if it's already running (`monitor-status`). Check permissions — it needs root. Check logs at `/var/log/unleash-monitor.log`.

## FAQ

**What macOS versions are supported?**
12.x (Monterey) through 15.x (Sequoia), 26.x (Tahoe), and 27.x. Tested on Intel T2, M1, M2, M3, M4, M5.

**Do I need to disable SIP?**
No. All writes target the Data volume.

**Will this survive an OS reinstall?**
No. Clean install wipes the Data volume. Re-run after reinstalling.

**Can the organization track this?**
The serial stays in ABM. If the device connects to the internet with enrollment daemons re-enabled, it will re-enroll.

**What if I need iCloud?**
Use `whitelist` instead of `firewall` or `suppress`. It blocks only MDM endpoints.

**Why does MDM come back after Migration Assistant?**
MA copies user-level caches, preferences, and launch agents. Unleash handles this — run `bypass` or `suppress` from Recovery after migrating.

## Contributing

See CONTRIBUTING.md. PRs welcome, especially for:

- New macOS version compatibility
- Additional MDM domains or daemon labels
- Migration Assistant detection
- iCloud / MDM domain research

## License

MIT.
