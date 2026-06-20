---
layout: default
title: FAQ — unleash
---

# FAQ

## General

### What macOS versions are supported?

12.x (Monterey) through 15.x (Sequoia), 26.x (Tahoe), and 27.x. Tested on Intel T2, M1, M2, M3, M4, M5.

### Is this the same as bypass-mdm?

No. The original bypass-mdm scripts (v2, v3, express) only handle DEP markers and `/etc/hosts`. Unleash covers all five layers:

- DEP markers (same as original)
- Network blocking via `/etc/hosts` (same)
- Daemon overrides (original has a basic version)
- **User-level artifact cleanup** (original does not do this)
- **Kernel-level pf firewall** (original does not do this)
- **Auto-heal daemon**, **background monitor**, **audit**, **predict**, **remediate**, and 30+ more commands

Plus a single-file distribution, Homebrew tap, DONT.md discussions, and GPG-signed releases.

### Do I need to disable SIP?

No. All writes target the Data volume. The system volume is never modified.

### Do I need internet?

`bypass` and `suppress` do not need internet. `persist`, `firewall`, and `update` do (they download resources or contact GitHub).

### Will this survive an OS reinstall?

No. Clean install wipes the Data volume. Re-run `bypass` from Recovery after reinstalling.

### Will this survive a macOS update?

Usually yes, with `persist`. The LaunchDaemon runs `heal` automatically on the next boot after an update. Without `persist`, run `sudo ./unleash heal` manually.

### Can the organization track this?

The device serial stays in Apple Business Manager forever. Only the organization can remove it. If the device ever connects to the internet with full protections removed, it will re-enroll.

### Can I use iCloud after bypass?

Yes. Use `whitelist` instead of `firewall` or the basic `suppress`. It resolves only the essential MDM domains to IPs and blocks those, leaving iCloud, App Store, and system updates untouched.

### Why does MDM come back after Migration Assistant?

Migration Assistant copies user-level caches, preferences, and launch agents from the old Mac. These contain MDM enrollment artifacts that re-trigger the enrollment process. Most tools only clean system-level DEP markers — Unleash also cleans every user's Library directory.

### Is there a GUI?

Not yet. The CLI is the primary interface. A SwiftUI wrapper is on the [roadmap](https://github.com/mateussiqueira/unleash/blob/main/ROADMAP.md).

### How is unleash licensed?

MIT. Free to use, modify, and distribute.

## Technical

### How do I know if my Mac is enrolled in MDM?

```bash
sudo ./unleash check
```

Returns SAFE TO FORMAT (no MDM) or MDM DETECTED (will lock after wipe).

### How do I check if the bypass is still working?

```bash
sudo ./unleash status -d
```

Checks DEP markers, hosts file, daemon overrides, and profile enrollment state.

### `profiles status -v` still shows an MDM profile — why?

Cosmetic. macOS stores the profile enrollment state on the read-only System Sealed Volume. The actual enrollment daemons are disabled and the DEP markers are gone. Trust `unleash status` over `profiles status`.

### What's the difference between `monitor` and `persist`?

`monitor` is a daemon that checks every 5 minutes and sends a macOS notification if MDM tries to re-enroll. `persist` is a LaunchDaemon that runs `heal` on every boot. Use both for full protection.

### What's the difference between `firewall` and `whitelist`?

`firewall` blocks Apple's entire IP range (breaks iCloud/App Store). `whitelist` resolves only MDM domains to IPs and blocks those (keeps iCloud/App Store working).

### Which orgs does `remediate` support?

JAMF, Mosyle, Addigy, Kandji, VMware Workspace ONE. It auto-detects the org from your device's DEP record and applies targeted cleanup.

### How does `predict` work?

It reads the serial number prefix and checks it against known MDM org prefixes (from community research). If a match is found, it predicts which organization enrolled the device.

## Troubleshooting

### MDM comes back after reboot

Run from Recovery:
```bash
sudo ./unleash suppress
```

Or from a booted system:
```bash
sudo ./unleash harden
```

### "Not a known DirStatus" error

Volume auto-detection failed. Find your Data volume:
```bash
diskutil list
diskutil mount /dev/diskXsY
./unleash bypass
```

### FileVault unlock fails in Recovery

You need a user password or the FileVault recovery key. If neither is available, the Data volume cannot be mounted from Recovery. Unlock it manually in Disk Utility first.

### "Not a macOS Data volume"

Unleash checks for `/private/var/db/dslocal/nodes/Default` on the mounted volume. If it's missing, you mounted the wrong disk. Run `diskutil list` to find the correct Data volume.

### Monitor won't start

1. Check if it's already running: `sudo ./unleash monitor-status`
2. Check permissions: needs root
3. Check logs: `/var/log/unleash-monitor.log`

---

[Back to home](/) · [Architecture Guide](guide)

{% include lang-toggle.html %}
