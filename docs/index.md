<p align="center">
  <img src="icon.svg" width="100" alt="unleash logo">
  <br>
  <strong>unleash</strong>
  <br>
  <em>Single-script MDM bypass for macOS</em>
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#quick-start">Quick Start</a> ·
  <a href="#commands">Commands</a> ·
  <a href="guide">Architecture Guide</a> ·
  <a href="faq">FAQ</a> ·
  <a href="#troubleshooting">Troubleshooting</a>
</p>

---

unleash replaces the original five bypass-mdm scripts with a single file that handles every layer of Apple's MDM enrollment: DEP markers, network blocking, daemon overrides, user-level artifacts, and kernel-level firewall. Works from Recovery mode on Apple Silicon and Intel.

**What makes unleash different from other bypass tools:**

- **Covers all 5 layers** — not just DEP markers or hosts file. Kills every path MDM uses to re-enroll.
- **User-level artifact cleanup** — Migration Assistant copies MDM caches per user. Unleash cleans every home directory.
- **Kernel-level pf firewall** — `/etc/hosts` is bypassed by DNS-over-HTTPS. pf is not.
- **Auto-heal daemon** — survives macOS updates. `persist` + `heal` catches whatever the update resets.
- **39 commands** — bypass, suppress, monitor, harden, audit, backup, predict, remediate, and more.
- **macOS 12–27** — tested on Intel T2, M1, M2, M3, M4, M5.

---

## Install

**Homebrew (easiest)**
```bash
brew install mateussiqueira/unleash/unleash
```

**Direct download**
```bash
curl -L https://raw.githubusercontent.com/mateussiqueira/unleash/main/unleash-standalone.sh -o unleash
chmod +x unleash
```

**From a USB drive (for Recovery mode)**
1. Format a USB/SSD as FAT32, APFS, or exFAT
2. Copy the `unleash` folder (or just `unleash-standalone.sh`) to the drive
3. Boot to Recovery and run from `/Volumes/YourDrive/unleash`

---

## Quick Start

### Recovery mode (standard bypass)

1. Boot to Recovery:
   - **Apple Silicon**: hold power button → Options → Continue
   - **Intel**: Cmd+R on startup

2. Open Terminal (Utilities → Terminal)

3. Run:
   ```bash
   "/Volumes/YourDrive/unleash" bypass
   ```

4. Follow the prompts to create a temporary admin user

5. Reboot. MDM enrollment will be suppressed.

### Booted system (already set up)

If you already have a Mac that was previously bypassed and MDM came back after an update:

```bash
sudo ./unleash heal
```

Or to check your current status:

```bash
sudo ./unleash status -d
```

### One-command setup (new Mac)

```bash
sudo ./unleash init
```

Interactive wizard that runs the full setup: firewall, monitor, persist, backup, and audit.

---

## Commands

### Bypass & suppress

| Command | Description | Recovery | Booted |
|---------|-------------|----------|--------|
| `bypass` | Full bypass: create admin user + suppress MDM | ✓ | ✗ |
| `suppress` | Suppress enrollment without creating a user | ✓ | ✓ |
| `heal` | Re-apply suppression after macOS updates | ✓ | ✓ |
| `persist` | Install LaunchDaemon for auto-heal on every boot | ✓ | ✓ |
| `unpersist` | Remove the auto-heal LaunchDaemon | ✗ | ✓ |

### Firewall & hardening

| Command | Description |
|---------|-------------|
| `firewall` | Block Apple MDM IP ranges via pf (DoH-proof, kernel-level) |
| `firewall-off` | Remove pf firewall MDM block |
| `whitelist` | Block MDM domains only, keep iCloud/App Store working |
| `harden` | Kill MDM processes, remove profiles, flush DNS — from the booted system |

### Diagnostics

| Command | Description |
|---------|-------------|
| `audit` | Deep MDM scan — profiles, certificates, launch agents, risk score |
| `check` | Pre-format / pre-upgrade assessment — will this Mac lock after wipe? |
| `history` | Show event log from monitor/heal runs |
| `history-clear` | Clear the event log |
| `doctor` | Pre-flight diagnostics — root, Recovery, libs, disk, dependencies |
| `status` | MDM enrollment status (use `-d` for deep mode) |
| `report` | Full system report in human-readable or JSON format |

### Monitoring

| Command | Description |
|---------|-------------|
| `monitor` | Watch MDM state every 5 minutes, auto-heal if needed |
| `monitor-stop` | Stop the background monitor |
| `monitor-status` | Check if the monitor is running |
| `monitor-install` | Install monitor as a LaunchDaemon |

### VPN kill-switch

| Command | Description |
|---------|-------------|
| `vpn-kill` | Install pf kill-switch — blocks MDM outside the VPN tunnel |
| `vpn-kill-remove` | Remove the VPN kill-switch |
| `vpn-kill-status` | Check VPN kill-switch state |

### Utilities

| Command | Description |
|---------|-------------|
| `update` | Self-update from the latest GitHub release (GPG-verified) |
| `uninstall` | Complete removal with safety prompts |
| `reinstall` | Uninstall + install (atomic update) |
| `config` | View or edit persistent settings in `~/.unleash.conf` |
| `backup` | Save current state for later restore |
| `restore` | Restore from a previous backup |
| `demo` | Simulated bypass flow — no real changes |
| `test` | Dry-run simulation of any command |
| `dualboot` | Target an external or dual-boot volume |

### Smart commands (v2.0)

| Command | Description |
|---------|-------------|
| `init` | Interactive setup wizard — firewall, monitor, persist, backup |
| `suggest` | Risk-based system analysis and recommendations |
| `remediate` | Per-org MDM cleanup (JAMF, Mosyle, Addigy, Kandji, VMware) |
| `predict` | Serial number lookup — predict which org enrolled this Mac |
| `telemetry` | Manage anonymous usage stats (opt-in) |
| `discord-bot` | Start Discord DM alert bot |
| `discord-bot-stop` | Stop the Discord bot |
| `discord-bot-status` | Check if the Discord bot is running |

### Aliases

Every command has a short alias:

```
by  = bypass       fw  = firewall      fw-off = firewall-off
sv  = suppress     mn  = monitor       doc   = doctor
st  = status       up  = update        uni   = uninstall
rei = reinstall    vk  = vpn-kill      vkr   = vpn-kill-remove
vks = vpn-kill-status                  wl    = whitelist
it  = init         su  = suggest       rm   = remediate
pr  = predict      tel = telemetry     db   = discord-bot
dbs = discord-bot-stop                 dbs2 = discord-bot-status
```

### Global options

| Option | Effect |
|--------|--------|
| `--verbose` | Show debug messages |
| `--log-file <path>` | Write log output to a file |

---

## Scenarios

### Before buying a used Mac

```bash
./unleash predict ABC12345678    # check serial against known org prefixes
./unleash check                  # is this Mac safe to wipe?
```

`predict` looks up the device serial against known MDM org prefixes. If it matches JAMF, Mosyle, or another org, you know what you're dealing with before you buy.

### Recovery after Migration Assistant

1. Fresh install macOS on a new Mac
2. Migration Assistant copies your old data
3. MDM appears within minutes of login

**Fix**: Boot to Recovery and run `unleash suppress` (or `bypass` if you need a new admin user). This removes the DEP markers, user-level artifacts, and MDM preferences that MA transferred over.

### macOS update brought MDM back

1. System update restores enrollment daemons automatically
2. MDM block in `/etc/hosts` is often preserved

**Fix**: `sudo ./unleash heal` — re-disables daemons and re-checks all layers. If you ran `persist` before the update, this happens automatically on the next boot.

### Buying a former office Mac

1. The serial might still be in the company's ABM
2. Even after a clean wipe, connecting to Wi-Fi at Setup Assistant triggers enrollment

**Strategy**:
- Boot to Recovery without connecting to Wi-Fi
- Run `unleash bypass` before the device ever phones home
- Run `unleash persist` and `unleash whitelist` so it stays clean
- The serial stays in ABM forever — but as long as the device never connects with full protections removed, it will not re-enroll

### Used Mac that already has a user logged in

```bash
sudo ./unleash audit     # check current state
sudo ./unleash harden    # kill MDM processes immediately
sudo ./unleash whitelist # block MDM while keeping iCloud
sudo ./unleash persist   # survive future updates
```

### Setting up a new Mac before first boot

1. Boot to Recovery without Wi-Fi
2. Run `unleash init` — interactive wizard
3. It will: suppress MDM, install persist, install whitelist, run audit
4. Reboot, set up normally, MDM never bothers you

---

## How It Works

MDM (Mobile Device Management) operates in five layers on macOS. Unleash blocks every layer:

**Layer 1: DEP enrollment markers** → `/etc/hosts` block → **Layer 2: Network blocking**

**Layer 3: Daemon overrides** → launchd disabled → **Layer 4: User-level artifacts**

**Layer 5: pf firewall** → kernel-level, DoH-proof

### Layer 1: DEP enrollment markers

In `/var/db/ConfigurationProfiles/Settings/`, Apple stores `.cloudConfig*` files that flag the Mac as DEP-enrolled. Removing these is the standard bypass approach, but macOS can recreate them from cached data.

**What unleash does**: Removes all `.cloudConfig*` markers, creates decoy files that tell macOS the device was never enrolled, and prevents re-creation by also blocking the network layer.

### Layer 2: Network blocking

The MDM enrollment process phones home to Apple's servers. Blocking these domains prevents the device from checking in.

**What unleash does**:
- **`/etc/hosts`** (basic): Blocks 13+ Apple MDM domains including `deviceenrollment.apple.com`, `mdmenrollment.apple.com`, `iprofiles.apple.com`. Both IPv4 (0.0.0.0) and IPv6 (::) entries.
- **pf firewall** (advanced): Kernel-level packet filtering that blocks MDM IP ranges even when DoH is used.

Blocked domains:

| Domain | Service |
|--------|---------|
| `iprofiles.apple.com` | Profile delivery |
| `deviceenrollment.apple.com` | DEP service |
| `mdmenrollment.apple.com` | MDM enrollment |
| `acmdm.apple.com` | Apple Configurator 2 MDM |
| `axm-adm-mdm.apple.com` | ACM enrollment |
| `albert.apple.com` | ABM device assignment |
| `gdmf.apple.com` | MDM framework |
| `configuration.apple.com` | Configuration service |
| `xp.apple.com` | Device management |
| `gs.apple.com` | GSM enrollment |
| `tb.apple.com` | Device trust |
| `vpp.itunes.apple.com` | Volume purchase program |

Plus your org's specific MDM host, extracted from the DEP record.

### Layer 3: Daemon overrides

macOS ships with enrollment daemons that trigger enrollment on boot:

| Daemon | Purpose |
|--------|---------|
| `com.apple.ManagedClient.enroll` | Main enrollment |
| `com.apple.ManagedClient.cloudConfiguration` | Cloud configuration |
| `com.apple.mdmclient.daemon.runatboot` | MDM client |
| `com.apple.activationd` | Device activation |

**What unleash does**: Creates launchd disabled overrides for all four, preventing them from starting. Also disables Spotlight shortcut for Remote Management.

### Layer 4: User-level artifacts

Migration Assistant and login caches leave MDM enrollment data in home directories:

```
~/Library/Preferences/com.apple.mdm.*
~/Library/Preferences/com.apple.ManagedClient.*
~/Library/Application Support/com.apple.ManagedClient*/
~/Library/LaunchAgents/com.apple.mdm.*
```

**What unleash does**: Scans every user's Library directory and removes all MDM-related preferences, caches, and launch agents. This is the step most other tools miss.

### Layer 5: pf firewall (optional, advanced)

`/etc/hosts` can be bypassed by DNS-over-HTTPS (DoH). The pf packet filter operates at the kernel level — DoH cannot bypass it.

**`firewall` command**: Blocks Apple's entire IP range (`17.0.0.0/8` + `17.128.0.0/10`). 100% effective but breaks iCloud, App Store, and system updates.

**`whitelist` command**: Resolves only the essential MDM domains to IPs and blocks those specifically. Keeps iCloud and App Store working.

---

## Intel vs Apple Silicon

| | Intel T2 | Apple Silicon |
|---|---|---|
| Recovery | Cmd+R at boot | Hold power button |
| System volume | Writable with SIP disabled | Read-only (SSV) |
| FileVault unlock | `diskutil apfs unlockVolume` | Same, needs user password or recovery key |
| Enrollment daemons | Fewer | `activationd` + `cloudConfiguration` |
| NVRAM flags | Some | More firmware-level flags |
| Migration Assistant | Less risky | **Carries MDM state** — always clean after |

On Apple Silicon, all writes target the Data volume. The system volume is never modified. SIP does not need to be disabled.

---

## macOS Version Support

| Version | Codename | Status |
|---------|----------|--------|
| 12.x | Monterey | ✓ Tested |
| 13.x | Ventura | ✓ Tested |
| 14.x | Sonoma | ✓ Tested |
| 15.x | Sequoia | ✓ Tested |
| 26.x | Tahoe | ✓ Tested |
| 27.x | (current) | ✓ Tested |

Should work on any version that uses the same MDM enrollment mechanism — which has been unchanged since Monterey. If a future macOS changes `ManagedClient.enroll`, activationd, or the DEP markers, open an issue.

---

## Troubleshooting

### MDM comes back after reboot

The most likely cause is user-level artifacts. Run from Recovery:
```bash
sudo ./unleash suppress
```
Or from a booted system:
```bash
sudo ./unleash harden
```

### "Not a known DirStatus" error

The script auto-detects volume names, but if you have a non-standard setup:
1. Run `diskutil list` to find your Data volume
2. Mount it: `diskutil mount /dev/diskXsY`
3. Re-run unleash

### Profiles still shows enrollment

This is cosmetic. macOS stores profile state on the read-only SSV (System Sealed Volume). Check the actual DEP markers instead:
```bash
sudo ./unleash status -d
```

### FileVault is enabled

Unleash will detect FileVault and prompt for the recovery key or volume password. If automatic unlock fails, unlock the volume manually in Disk Utility first.

### macOS update re-enabled MDM

Run `sudo ./unleash heal` after any macOS update. If you used `persist` before the update, it does this automatically on next boot.

### Can I use iCloud after bypass?

Yes, but:
- The basic `/etc/hosts` block also blocks `albert.apple.com` (iCloud activation) and `gdmf.apple.com`
- Use the `whitelist` command instead of `firewall` to block only MDM domains and leave iCloud/App Store working
- Or manually remove those two lines from `/etc/hosts`

### DFU / IPSW restore (hard lock)

If MDM is unbreakable even from Recovery, the device may need a full firmware restore. This applies to Apple Silicon only.

You need a second Mac with Apple Configurator 2 (free), a USB-C cable, and the IPSW file for your Mac model.

1. Open Apple Configurator 2 on the helper Mac
2. Connect the locked Mac via USB-C while holding power
3. In Configurator: right-click the DFU device → Advanced → Restore
4. Pick the IPSW file, wait 10–30 minutes
5. After restore, boot to Recovery without Wi-Fi and run `unleash bypass`

**This erases all data.** IPSW files at [ipsw.me](https://ipsw.me).

---

## Logging

All commands log with timestamps and levels:

```
[INF] Data volume: /Volumes/Macintosh HD - Data
[ OK] Admin 'apple' created (UID 501)
[WRN] DEP activation record present
[ERR] Firewall needs sudo: sudo ./unleash firewall
[STP] Locating Data volume by APFS role...
[DBG] Checking pfctl availability
```

Use `--verbose` for debug messages and `--log-file <path>` to write everything to a file.

---

## Safety

- **No SSV writes** — all changes target the Data volume
- **Reversible** — `backup` saves state, `restore` reverts
- **No data erasure** — never runs `profiles renew` or erase commands
- **Idempotent** — running multiple times is harmless
- **Prompts for confirmation** before destructive actions

---

## Links

- [GitHub Repository](https://github.com/mateussiqueira/unleash)
- [Full README](https://github.com/mateussiqueira/unleash/blob/main/README.md)
- [Architecture Guide](guide)
- [FAQ](faq)
- [Quick Reference (QUICKSTART.md)](https://github.com/mateussiqueira/unleash/blob/main/QUICKSTART.md)
- [Changelog](https://github.com/mateussiqueira/unleash/blob/main/CHANGELOG.md)
- [Contributing](https://github.com/mateussiqueira/unleash/blob/main/CONTRIBUTING.md)
- [Code of Conduct](https://github.com/mateussiqueira/unleash/blob/main/CODE_OF_CONDUCT.md)
- [Security Policy](https://github.com/mateussiqueira/unleash/blob/main/SECURITY.md)
- [Discussions](https://github.com/mateussiqueira/unleash/discussions)
- [Report a Bug](https://github.com/mateussiqueira/unleash/issues/new?template=bug_report.md)
