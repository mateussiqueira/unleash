---
layout: default
title: Architecture Guide — unleash
---

# Architecture Guide

## The Five Layers of MDM

Apple's MDM enrollment works through five independent mechanisms. Blocking just one or two is why bypass tools fail over time. Unleash addresses all five.

```
Layer 1: DEP markers  ───  /var/db/ConfigurationProfiles/Settings/.cloudConfig*
Layer 2: Hosts block  ───  /etc/hosts → 0.0.0.0 deviceenrollment.apple.com
Layer 3: Daemons      ───  launchd disabled → ManagedClient.enroll, activationd
Layer 4: User data    ───  ~/Library/Preferences/com.apple.mdm.*
Layer 5: pf firewall  ───  pf anchor com.unleash/mdm → kernel-level drop
```

### Layer 1: DEP Enrollment Markers

When an organization assigns a device in Apple Business Manager (ABM), macOS creates marker files:

```
/private/var/db/ConfigurationProfiles/Settings/
  .cloudConfigHasActivationRecord   ← "this serial is in ABM"
  .cloudConfigRecordFound           ← "we checked and enrollment was triggered"
  .cloudConfigTimerCheck            ← "check again later"
```

**Attack**: Remove all `.cloudConfig*` markers. Create decoy files (`.cloudConfigRecordNotFound`, `.cloudConfigProfileInstalled`) that tell macOS "no enrollment needed."

**Weakness**: macOS can recreate these from cached data if the network layer is not also blocked.

### Layer 2: Network Blocking

The enrollment client contacts Apple servers to download the MDM profile. Without network access, it cannot complete.

**Attack**: Add 13+ Apple MDM domains to `/etc/hosts` pointing to `0.0.0.0` and `::`:

```
0.0.0.0 deviceenrollment.apple.com
0.0.0.0 mdmenrollment.apple.com
0.0.0.0 iprofiles.apple.com
...
```

Also blocks your org's specific MDM host (extracted from the DEP record during bypass).

**Weakness**: DNS-over-HTTPS bypasses `/etc/hosts` entirely. Chrome, Firefox, and some system services use DoH by default.

### Layer 3: Daemon Overrides

macOS registers four enrollment daemons that run at boot:

| Daemon | System path | Effect when disabled |
|--------|-------------|---------------------|
| `com.apple.ManagedClient.enroll` | `/System/Library/LaunchDaemons/` | Never runs enrollment |
| `com.apple.ManagedClient.cloudConfiguration` | `/System/Library/LaunchDaemons/` | No cloud config fetch |
| `com.apple.mdmclient.daemon.runatboot` | `/System/Library/LaunchDaemons/` | MDM client stays dead |
| `com.apple.activationd` | `/System/Library/LaunchDaemons/` | Activation never starts |

**Attack**: Create launchd disabled overrides in `/private/var/db/com.apple.xpc.launchd/disabled.plist`. This is the same mechanism macOS uses internally for `sudo launchctl disable`.

### Layer 4: User-Level Cleanup

Home directories carry MDM artifacts that re-trigger enrollment after login or Migration Assistant:

```
~/Library/Preferences/com.apple.mdm.*
~/Library/Preferences/com.apple.ManagedClient.*
~/Library/Application Support/com.apple.ManagedClient*/
~/Library/Caches/com.apple.mdmclient
~/Library/LaunchAgents/com.apple.mdm.*
```

**Attack**: Scan every home directory on the Data volume. Remove all MDM-related plists, caches, and launch agents. This prevents re-enrollment when the user logs in.

**Why this matters**: Migration Assistant copies ALL of the above. This is the #1 reason MDM returns after a successful bypass — and the step most other tools skip entirely.

### Layer 5: pf Firewall (Kernel Level)

`/etc/hosts` can be bypassed by:
- DNS-over-HTTPS (DoH) in Chrome/Firefox
- Cached DNS responses
- Direct IP connections

pf (packet filter) operates at the kernel networking layer, below DNS resolution. DoH cannot bypass pf.

**`firewall` command**: Blocks Apple's entire IP range:
```
17.0.0.0/8      ← Apple
17.128.0.0/10   ← Apple (extended)
```

**`whitelist` command**: Resolves only MDM domains → IPs and blocks those specifically. iCloud/App Store continue working.

**`vpn-kill` command**: Blocks MDM IPs when the device is NOT connected to your VPN. Useful for org-provided Macs that must enroll but should only communicate while on VPN.

## Script Architecture

```
unleash/
├── unleash                   # Main entry point — loads libs, dispatches commands
├── lib/
│   ├── colors.sh             # Logging, colors, prompts, show_cmd_help()
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
│   ├── monitor.sh            # Background MDM watcher
│   ├── config.sh             # Config file read/write
│   ├── doctor.sh             # Pre-flight diagnostics
│   ├── history.sh            # Event log read/clear
│   ├── selfupdate.sh         # GPG-verified self-update
│   ├── uninstall.sh          # Complete removal
│   ├── report.sh             # Full system report
│   ├── ma_detect.sh          # Migration Assistant detect
│   ├── demo.sh               # Simulated bypass (no changes)
│   ├── vpn.sh                # VPN kill-switch pf rules
│   ├── init.sh               # Setup wizard
│   ├── suggest.sh            # Risk-based recommendations
│   ├── remediate.sh          # Per-org cleanup
│   ├── predict.sh            # Serial number lookup
│   ├── telemetry.sh          # Anonymous usage stats
│   └── discord.sh            # Discord DM alert bot
├── docs/                     # Jekyll site (GitHub Pages)
├── tests/                    # Bats tests (78 tests)
└── examples/                 # build-standalone.sh, auto-bypass-usb.sh, etc.
```

### Dispatch Flow

1. `unleash` loads all `lib/*.sh` modules
2. `load_config()` reads `~/.unleash.conf` (if exists)
3. Command argument is matched against the `case` dispatch in main
4. Handler function is called (e.g., `cmd_bypass`, `cmd_firewall`)
5. Each handler calls lib functions that do the actual work

### Standalone Build

`examples/build-standalone.sh` concatenates all lib modules + main script body into a single file (`unleash-standalone.sh`, ~3200 lines). No external dependencies — runs on any macOS system with bash.

## Build Process

1. **Source**: Individual `lib/*.sh` modules + `unleash` entry point
2. **Test**: 78 Bats tests covering all modules
3. **Build**: `bash examples/build-standalone.sh` → `unleash-standalone.sh`
4. **Sign**: `scripts/sign-release.sh` → GPG detached signature
5. **Release**: GitHub release with standalone + signature + checksums

## Security Design

### No root persistence
Unleash does not install a backdoor, create hidden users, or modify the system volume. All changes are reversible.

### GPG-signed releases
Releases are signed with a GPG key. `selfupdate` verifies the signature before applying updates. Signature verification must pass or the update is rejected.

### Opt-in telemetry
Telemetry is OFF by default. If enabled, it sends only anonymous counts (command run, macOS version, success/failure) — no serial numbers, IPs, or identifiable data.

### No internet dependency
Core commands (`bypass`, `suppress`, `heal`) work entirely offline. Only `update`, `firewall` (DNS resolution), and `discord-bot` need network access.

---

[Back to home](/) · [FAQ](faq)
