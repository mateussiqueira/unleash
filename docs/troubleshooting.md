---
layout: default
title: Troubleshooting — unleash
---

# Troubleshooting

## Common Errors

### "Not a known DirStatus"
Volume auto-detection failed.
```
[ERR] Not a known DirStatus
```

**Fix:**
1. Run `diskutil list` to find your Data volume
2. Mount it: `diskutil mount /dev/diskXsY`
3. Re-run unleash

---

### "Full bypass must run from Recovery mode"
```
[ERR] Full bypass must run from Recovery mode.
```

**Cause:** `bypass` creates admin users via dscl, which only works in Recovery.
**Fix:** Boot to Recovery and try again. Or use `suppress` instead from a booted system.

---

### "Needs sudo" errors

Various commands require root:
```
[ERR] Firewall needs sudo: sudo ./unleash firewall
[ERR] Heal needs sudo: sudo ./unleash heal
[ERR] Hardening needs sudo: sudo ./unleash harden
[ERR] Audit needs sudo: sudo ./unleash audit
[ERR] Check needs sudo: sudo ./unleash check
```

**Fix:** Prepend `sudo` to the command.

---

### MDM comes back after reboot

The most common cause is **user-level artifacts** carried over by Migration Assistant.

**Fix from Recovery:**
```bash
sudo ./unleash suppress
```

**Fix from booted system:**
```bash
sudo ./unleash harden
```

If it keeps returning:
```bash
sudo ./unleash persist   # auto-heal on every boot
sudo ./unleash monitor   # watch for re-enrollment
```

---

### macOS update re-enabled MDM

System updates restore enrollment daemons automatically.

**Fix:**
```bash
sudo ./unleash heal
```

If you ran `persist` before the update, this runs automatically on next boot.

---

### "Profiles status" still shows enrollment

This is **cosmetic**. macOS stores profile state on the read-only SSV (System Sealed Volume).

**Don't trust** `profiles status -v`.
**Trust** `unleash status -d` instead.

---

### FileVault is enabled

Unleash detects FileVault and prompts for the recovery key or volume password.

**Fix:** If automatic unlock fails, unlock the volume manually in Disk Utility first:
1. Go to Disk Utility in Recovery
2. Select the Data volume
3. File → Unlock → Enter password
4. Re-run unleash

---

### iCloud stops working after bypass

The basic `/etc/hosts` block includes `albert.apple.com` (iCloud activation) and `gdmf.apple.com`.

**Fix:** Use `whitelist` instead of the basic block:
```bash
sudo ./unleash whitelist
```

Or manually remove these two lines from `/etc/hosts`:
```
0.0.0.0 albert.apple.com
0.0.0.0 gdmf.apple.com
```

---

### "Not a macOS Data volume"

```
[ERR] Not a macOS Data volume
```

**Cause:** The mounted volume doesn't have the expected structure.

**Fix:** Run `diskutil list` to find the correct Data volume (look for "Data" in the name or the `69414d41-...` role). Mount the right one and retry.

---

### Monitor won't start

**Check:**
1. Is it already running? `sudo ./unleash monitor-status`
2. Permissions: needs root
3. Check logs: `/var/log/unleash-monitor.log`

**Fix:**
```bash
sudo ./unleash monitor-stop
sudo ./unleash monitor
```

---

### Can't download files in Recovery

Recovery mode has no internet by default.

**Fix:**
1. Use a USB drive with unleash copied to it
2. Or connect to Wi-Fi in Recovery (top-right menu → Wi-Fi icon)

---

### "Library not found" error on startup

```
ERROR: Library not found: /path/to/lib/colors.sh
```

**Cause:** Running the source `unleash` script from outside the repo directory.

**Fix:**
- Use the standalone version (`unleash-standalone.sh`) instead
- Or run from the repo root where the `lib/` directory exists
- Or install via Homebrew

---

### Firewall rules not applying

pf might have existing rules that conflict.

**Fix:**
```bash
sudo ./unleash firewall-off   # clear existing rules
sudo ./unleash firewall       # re-apply
```

---

### "Device still locks after DFU restore"

A full DFU/IPSW restore doesn't remove ABM assignment — the serial stays in Apple Business Manager.

**Strategy:**
1. After restore, **do not connect to Wi-Fi**
2. Boot to Recovery
3. Run `unleash bypass` before the device ever phones home
4. Run `unleash persist` and `unleash whitelist`
5. Only then connect to the internet

The serial stays in ABM forever — but if the device never connects without protections, it won't re-enroll.

---

### GPG signature verification fails on update

```
[ERR] GPG signature verification failed
```

**Fix:**
1. Make sure you have `gpg` installed
2. Import the signing key: `gpg --keyserver keys.openpgp.org --recv-key <KEY_ID>`
3. Try `sudo ./unleash update` again
4. Or download manually from [GitHub Releases](https://github.com/mateussiqueira/unleash/releases)

---

### Homebrew installation fails

```
Error: ... homebrew-core ...
```

**Fix:** Make sure the tap is up to date:
```bash
brew untap mateussiqueira/unleash
brew tap mateussiqueira/unleash
brew install unleash
```

---

## Logging

All commands produce structured logs:

```
[INF] Data volume: /Volumes/Macintosh HD - Data
[ OK] Admin 'apple' created (UID 501)
[WRN] DEP activation record present
[ERR] Firewall needs sudo: sudo ./unleash firewall
[STP] Locating Data volume by APFS role...
[DBG] Checking pfctl availability
```

**Log format:**

| Prefix | Level |
|--------|-------|
| `[INF]` | Info — normal operation |
| `[ OK]` | Success — operation completed |
| `[WRN]` | Warning — non-critical issue |
| `[ERR]` | Error — operation failed |
| `[STP]` | Step — current action |
| `[DBG]` | Debug — verbose only |

Use `--verbose` for debug messages and `--log-file <path>` to save to a file:
```bash
sudo ./unleash heal --verbose --log-file /tmp/unleash.log
```

---

## Diagnostic Commands

Run these to gather information before seeking help:

```bash
# Quick health check
sudo ./unleash doctor

# Full system audit
sudo ./unleash audit

# Generate report
sudo ./unleash report

# Dry-run a bypass
sudo ./unleash demo
```

---

## Getting Help

- [GitHub Issues](https://github.com/mateussiqueira/unleash/issues)
- [Discussions](https://github.com/mateussiqueira/unleash/discussions)
- [Security Policy](https://github.com/mateussiqueira/unleash/blob/main/SECURITY.md)
