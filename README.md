# unleash — Unified MDM Bypass for macOS

**unleash** is a single-tool solution to bypass, suppress, backup, restore, and audit MDM (Mobile Device Management) enrollment on macOS. It unifies the functionality of the original `bypass-mdm` project into one script with CLI flags and an interactive menu.

> **Legal**: This tool suppresses MDM locally on devices you own. It does not touch Apple Business Manager (ABM) records. The permanent fix is the organization releasing the device. Use at your own risk.

---

## Table of Contents

- [Why unleash?](#why-unleash)
- [Quick Start](#quick-start)
- [Commands](#commands)
- [How It Works](#how-it-works)
- [Intel vs Apple Silicon](#intel-vs-apple-silicon)
- [Migration Assistant — Known Failure Mode](#migration-assistant--known-failure-mode)
- [Troubleshooting](#troubleshooting)
- [Architecture](#architecture)
- [Safety & Limitations](#safety--limitations)
- [FAQ](#faq)

---

## Why unleash?

The original `bypass-mdm` project grew into 5 separate scripts (v2, v3, express, dualboot.sh, verify.sh). Each handled a different use case with inconsistent options. **unleash** replaces all of them:

| Feature | bypass-mdm | unleash |
|---------|-----------|---------|
| Full bypass (admin + suppress) | v2 / v3 / express | `unleash bypass` |
| Suppress only (no user) | v3 only | `unleash suppress` |
| Backup + Restore | express only | `unleash backup / restore` |
| Dual-boot target | `dualboot.sh` | `unleash dualboot` |
| Status & health check | `v3 --verify` | `unleash status` |
| Auto-detect Recovery | partial | always |
| FileVault unlock | v3 only | always |
| Org MDM host blocking | v3 | always |
| Launchd daemon disable | v3 | always |
| User-level cleanup | — | yes |
| Interactive menu | brew-based | native |
| CLI flags | none | yes |

---

## Quick Start

### From an External SSD (recommended)

1. Copy the `unleash` folder to an external SSD (FAT32, APFS, or exFAT)
2. Boot into Recovery mode:
   - **Apple Silicon**: hold the Power button → Options → Continue
   - **Intel**: `Cmd+R` at startup
3. Open **Terminal** from the Utilities menu
4. Make the script executable and run it:
   ```bash
   chmod +x "/Volumes/YourSSD/unleash/unleash"
   "/Volumes/YourSSD/unleash/unleash"
   ```

### One-Liner (Download)

If you have internet access in Recovery:

```bash
curl -L https://raw.githubusercontent.com/mateussiqueira/unleash/main/unleash -o /tmp/unleash
chmod +x /tmp/unleash && /tmp/unleash bypass
```

### Standalone (No Dependencies)

```bash
cp /Volumes/YourSSD/unleash/unleash-standalone.sh /tmp/unleash
chmod +x /tmp/unleash && /tmp/unleash bypass
```

---

## Commands

### `unleash bypass` — Full Bypass

Creates a temporary admin account and suppresses MDM enrollment.

```bash
./unleash bypass
```

**What it does:**
1. Locates and mounts the macOS Data volume
2. Unlocks FileVault if needed (prompts for password)
3. Creates a local admin user (default: `Apple / 1234`)
4. Removes DEP (Device Enrollment Program) activation records
5. Blocks Apple and organization MDM domains via `/etc/hosts`
6. Disables enrollment launch daemons
7. Sets `.AppleSetupDone` so Setup Assistant is skipped

> **Must run from Recovery mode.**

### `unleash heal` — Auto-Heal

Checks if MDM suppression is still active and re-applies it if any component has been reset (e.g., after a macOS update). Safe to run from a booted system:

```bash
sudo ./unleash heal     # from booted system
./unleash heal          # from Recovery mode
```

**What it checks:**
1. DEP marker files — are they still cleared?
2. Hosts file — are MDM domains still blocked?
3. Launchd disabled.plist — are enrollment daemons still disabled?
4. If any check fails, re-runs `suppress_enrollment` to restore suppression

### `unleash persist` — Boot-Time Persistence

Installs a LaunchDaemon that runs `unleash heal` automatically on every boot and every 24 hours:

```bash
sudo ./unleash persist     # from booted system
./unleash persist          # from Recovery mode
```

Creates `/Library/LaunchDaemons/com.unleash.heal.plist`. Logs are written to `/var/log/unleash-heal.log` and `/var/log/unleash-heal.err`.

### `unleash unpersist` — Remove Persistence

Removes the LaunchDaemon installed by `unleash persist`:

```bash
sudo ./unleash unpersist   # from booted system
./unleash unpersist        # from Recovery mode
```

### `unleash suppress` — Suppress Only

Suppresses MDM enrollment without creating a user. Ideal after a clean bypass breaks (e.g., after macOS update).

```bash
./unleash suppress
```

Can also run from a normal booted system (sudo not required — targets the currently-mounted Data volume).

### `unleash status` — Health Check

Audits the current MDM state and reports what artifacts are present or missing:

```bash
./unleash status
```

Checks:
- DEP marker files (present/absent)
- Blocked domains in hosts
- Launchd daemon overrides
- Profiles enrollment status
- Backup existence

### `unleash backup` — Backup State

Saves the current hosts, Configuration Profiles, and launchd override:

```bash
./unleash backup
```

Backup location: `.unleash-backup/` inside the unleash folder.

### `unleash restore` — Restore State

Restores the original hosts, profiles, and launchd state from backup:

```bash
./unleash restore
```

### `unleash dualboot` — Target External/Dual-Boot Volume

Creates an admin account and blocks MDM on a target volume (e.g., an external macOS installation):

```bash
sudo ./unleash dualboot
```

Prompts for system volume name and data volume name.

### `unleash version` — Version Info

```bash
./unleash version
```

---

## How It Works

MDM enrollment on macOS is a multi-layer system. Unleash addresses each layer:

### Layer 1: DEP Activation Record

When an organization assigns a device in Apple Business Manager, macOS creates a DEP marker file at:

```
/private/var/db/ConfigurationProfiles/Settings/
├── .cloudConfigRecordFound        ← "this serial belongs to ABM"
├── .cloudConfigHasActivationRecord ← "enrollment has been triggered"
└── .cloudConfigTimerCheck         ← "check again periodically"
```

**Unleash removes** these and creates decoy files (`.cloudConfigRecordNotFound`, `.cloudConfigProfileInstalled`) to signal "no enrollment needed."

### Layer 2: Network-Level Blocking

The enrollment client contacts Apple and organization servers. Without network access, it cannot download the MDM profile.

**Unleash blocks** via `/etc/hosts`:

| Domain | Purpose |
|--------|---------|
| `iprofiles.apple.com` | Configuration profile delivery |
| `deviceenrollment.apple.com` | DEP enrollment service |
| `mdmenrollment.apple.com` | MDM enrollment service |
| `acmdm.apple.com` | Apple Configurator MDM |
| `axm-adm-mdm.apple.com` | Apple Configuration Manager enrollment |
| `albert.apple.com` | ABM app/device assignment |
| `gdmf.apple.com` | Mobile device management framework |
| `configuration.apple.com` | Configuration service |
| `xp.apple.com` | Device management |
| `gs.apple.com` | Device enrollment |
| `tb.apple.com` | Device trust |
| `vpp.itunes.apple.com` | Volume purchase program |
| `<org-mdm-host>` | Organization-specific MDM server (extracted from DEP record) |

### Layer 3: Launchd Daemon Override

macOS registers enrollment daemons that run at boot and login:

| Daemon | Purpose |
|--------|---------|
| `com.apple.ManagedClient.enroll` | Main enrollment daemon |
| `com.apple.ManagedClient.cloudConfiguration` | Cloud configuration fetcher |
| `com.apple.mdmclient.daemon.runatboot` | MDM client at boot |
| `com.apple.activationd` | Device activation |

**Unleash disables** these via the launchd `disabled.plist` override at:

```
/private/var/db/com.apple.xpc.launchd/disabled.plist
```

### Layer 4: User-Level Cleanup

User home directories can carry MDM artifacts that trigger re-enrollment after login:

```
~/Library/Preferences/com.apple.mdm.*
~/Library/Application Support/com.apple.ManagedClient/
~/Library/LaunchAgents/com.apple.mdm.*
```

**Unleash removes** these from all user directories on the Data volume.

---

## Intel vs Apple Silicon

Apple Silicon (M1/M2/M3/M4) has architectural differences that make MDM bypass harder:

| Aspect | Intel | Apple Silicon |
|--------|-------|---------------|
| System Volume | Writable with SIP disabled | Cryptographically signed (SSV) — read-only |
| Recovery Mode | `Cmd+R` at boot | Hold Power button |
| FileVault unlock | Via `diskutil apfs unlockVolume` | Same, but requires user password or recovery key |
| Enrollment daemons | Fewer | `activationd` + additional cloud config daemons |
| NVRAM persistence | NVRAM has some MDM flags | More flags stored in firmware |
| Migration Assistant | Safe to migrate | **Carries MDM state** — see below |

> On Apple Silicon, always use the **full bypass** (`unleash bypass`) from Recovery. The `suppress` command alone may not be sufficient after Migration Assistant.

---

## Migration Assistant — Known Failure Mode

Using Migration Assistant from an Intel Mac to an Apple Silicon Mac **will copy the full MDM enrollment state**, including:

- DEP activation records
- Enrolled configuration profiles
- User-level MDM preferences and caches
- Launch agents that re-trigger enrollment
- Keychain identity certificates

### Symptoms

- Remote Management screen appears **after the first reboot**
- Running `unleash suppress` or the old v3 script makes it go away temporarily
- MDM profile **returns within ~1 minute** of login

### Why the Current Scripts Fail

The original `suppress.sh` only handles system-level artifacts (DEP markers, hosts block, launchd override). After Migration Assistant, there are **user-level artifacts** in `~/Library/Preferences/` and `~/Library/Application Support/` that re-establish enrollment on every login. The hosts file block is also insufficient — the enrollment client may use cached DNS or direct IP connections.

### Solution: Three-Phase Approach

**Phase 1 — Recovery (full cleanup):**

```bash
# Boot from Recovery, mount Data volume
DISK=$(diskutil apfs list | awk '/\(Data\)/ && match($0, /disk[0-9]+s[0-9]+/) {print substr($0, RSTART, RLENGTH)}')
diskutil mount "$DISK"
DV="/Volumes/$(diskutil info "$DISK" | awk -F': *' '/Volume Name/{print $2}' | xargs)"
cd "$DV"

# Remove DEP records
rm -f private/var/db/ConfigurationProfiles/Settings/.cloudConfig*

# Clean ALL user directories of MDM artifacts
for home in Users/*; do
  [ -d "$home/Library" ] || continue
  rm -rf "$home/Library/Preferences/com.apple.mdm"*
  rm -rf "$home/Library/Application Support/com.apple.ManagedClient"*
  rm -rf "$home/Library/LaunchAgents/com.apple.mdm"*
done

# Expand domain blocking
cat >> private/etc/hosts << 'EOF'

0.0.0.0 iprofiles.apple.com
0.0.0.0 deviceenrollment.apple.com
0.0.0.0 mdmenrollment.apple.com
0.0.0.0 acmdm.apple.com
0.0.0.0 albert.apple.com
0.0.0.0 gdmf.apple.com
0.0.0.0 configuration.apple.com
0.0.0.0 xp.apple.com
0.0.0.0 gs.apple.com
::     (same list with IPv6)
EOF

# Disable all enrollment daemons
PB=/usr/libexec/PlistBuddy
LDP=private/var/db/com.apple.xpc.launchd/disabled.plist
for label in com.apple.ManagedClient.enroll com.apple.ManagedClient.cloudConfiguration \
             com.apple.mdmclient.daemon.runatboot com.apple.activationd; do
  $PB -c "Add :$label bool true" "$LDP" 2>/dev/null || $PB -c "Set :$label true" "$LDP"
done
```

**Phase 2 — Boot and Act Fast:**

1. Boot normally. If the MDM screen appears, **do not interact** — force reboot (hold Power).
2. On login, immediately run:
   ```bash
   sudo profiles -D
   sudo pkill -f ManagedClient
   sudo pkill -f mdmclient
   ```

**Phase 3 — Network-Level Firewall:**

The hosts file is weak. For durability, use a firewall:
- **Little Snitch** — commercial, per-app rules
- **LuLu** — free, open-source
- **pf firewall** — built-in, blocks Apple IP ranges

---

## Troubleshooting

### MDM screen reappears after reboot

Run `unleash suppress` from Recovery again. If it still returns, you likely have **user-level artifacts** from Migration Assistant. Follow the [Solution section](#solution-three-phase-approach) above.

### Hard-locked Mac: DFU / IPSW Restore

If the MDM screen is unbreakable — even from Recovery — the device may need a full firmware restore. This applies to Apple Silicon Macs only.

**What you need:**
- A second Mac with Apple Configurator 2 installed (from App Store)
- A USB-C cable (preferably Thunderbolt 4)
- The correct IPSW file for your Mac model

**Steps:**
1. On the second Mac, open Apple Configurator 2
2. Connect the locked Mac via USB-C while holding the Power button (DFU mode)
   - M1/M2: hold Power for 10s, keep holding while connecting USB-C
   - M3/M4: hold Power + Volume Down for 10s while connecting
3. In Apple Configurator 2, the Mac appears as a DFU device
4. Right-click → Advanced → Restore (choose the IPSW file)
5. Wait for restore to complete (10-30 minutes)
6. Mac reboots to Setup Assistant — **do NOT connect to Wi-Fi**
7. Immediately boot to Recovery (hold Power) and run `unleash bypass`

> ⚠️ This **erases all data** on the Mac. Only use if the normal bypass fails completely.

**Where to get IPSW files:**
- [ipsw.me](https://ipsw.me) — official Apple IPSW downloads
- [MrMacintosh blog](https://mrmacintosh.com) — links to latest IPSW

### Intel T2 Macs

Unleash works on Intel Macs with the T2 chip as well. The behavior differs slightly:

| Aspect | Intel T2 | Apple Silicon |
|--------|----------|---------------|
| Recovery | Cmd+R at boot | Hold Power button |
| System volume | Writable with SIP disabled | SSV (read-only always) |
| Volume naming | "Macintosh HD" + "Macintosh HD - Data" | Same convention |
| FileVault | Supported | Supported |
| DEP mechanism | Same | Same |

On T2 Macs you can alternatively disable SIP (`csrutil disable`) in Recovery and run the script. This is not needed on AS Macs since all writes target the Data volume.

### "profiles" command still shows enrollment

The `profiles` command reads from the system volume (SSV) which is read-only on Apple Silicon. This is cosmetic — if DEP markers are removed and daemons are disabled, enrollment won't activate. Run `unleash status` to check the actual Data volume state.

### FileVault unlock fails

Ensure you have:
- The password of any user on the Mac, OR
- The FileVault recovery key (shown during FileVault setup)

If neither is available, the Data volume cannot be mounted from Recovery.

### "Not a macOS Data volume" error

The script checks for the presence of:

```
/private/var/db/dslocal/nodes/Default
```

If this directory is missing, you may have selected the wrong disk. Run `diskutil list` to identify the correct Data volume.

### Dual-boot volume not found

The default names are `Macintosh HD` (system) and `Macintosh HD - Data` (data). If your volumes have different names (e.g., external disk name), provide them when prompted.

---

## Architecture

```
unleash/
├── unleash                   # Single entry point (CLI + interactive)
├── unleash-standalone.sh     # Self-contained variant (no lib/ dependency)
├── lib/
│   ├── colors.sh             # Color codes, logging, user prompts
│   ├── detect.sh             # Recovery mode detection, Data volume resolution
│   ├── validate.sh           # Username/password validation
│   ├── dscl.sh               # Directory Services user CRUD
│   ├── suppress.sh           # DEP removal, hosts blocking, launchd disable
│   ├── backup.sh             # State backup and restore
│   └── status.sh             # Health check and audit
├── examples/
│   ├── build-standalone.sh   # Builds the standalone variant
│   └── quickstart.sh         # Example automation script
├── README.md
└── LICENSE (MIT)
```

### Design Principles

1. **SSV-safe**: All writes target the Data volume. The system volume (SSV) is never modified.
2. **Idempotent**: Running multiple times is safe. Already-blocked domains and disabled daemons are detected and skipped.
3. **Reversible**: `unleash backup` saves the original state; `unleash restore` reverts it.
4. **Recovery-first**: The full bypass requires Recovery mode, ensuring the Data volume is unmounted from the running OS.

---

## Safety & Limitations

### What Unleash Does NOT Do

- ❌ Remove your device from Apple Business Manager — only the organization can do that
- ❌ Modify the signed system volume (SSV)
- ❌ Run `profiles renew` (which would re-enroll the device)
- ❌ Wipe data or erase content

### Known Limitations

| Limitation | Workaround |
|------------|------------|
| After macOS update, daemons may re-enable | Run `unleash suppress` again |
| Hosts file can be bypassed by cached DNS | Use `dscacheutil -flushcache` |
| IPv6 may not be blocked if only IPv4 entries added | Unleash adds both (:: and 0.0.0.0) |
| Migration Assistant carries MDM state | Use the three-phase solution above |
| `profiles status` shows enrollment | This is the SSV's view; daemon disable takes precedence |

---

## FAQ

**Q: What macOS versions are supported?**  
A: macOS 12.x (Monterey) through 15.x (Sequoia) and 26.x (Tahoe). Tested on Intel T2, M1, M2, M3, and M4 hardware.

**Q: Do I need to disable SIP?**  
A: No. All operations target the Data volume, which does not require SIP to be disabled.

**Q: Will this survive an OS reinstall?**  
A: No. A fresh install clears the Data volume. You must re-run Unleash after reinstalling macOS.

**Q: Can the organization still track this device?**  
A: The serial number remains in ABM. If the device connects to the internet and the MDM daemon re-enables, it will re-enroll. This is why the daemon disable and hosts block are both needed.

**Q: What if I need iCloud or App Store?**  
A: The hosts block is broad. Use a per-app firewall (Little Snitch, LuLu) for selective blocking instead.

**Q: Why does MDM come back after Migration Assistant?**  
A: Because MA copies user-level MDM caches, preferences, and launch agents. See [Migration Assistant section](#migration-assistant--known-failure-mode).

---

## Development

```bash
# Build standalone (bundles all lib/ into one file)
bash examples/build-standalone.sh

# Test the suppress logic
sudo ./unleash suppress --dry-run
```

### Pull Requests

Contributions welcome, especially for:
- Additional MDM domains to block
- New launch daemon labels discovered on newer macOS versions
- Migration Assistant detection logic
- iCloud/MDM domain whitelist for selective blocking

---

## License

MIT. See [LICENSE](LICENSE).
