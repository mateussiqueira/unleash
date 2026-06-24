---
layout: default
title: Security — unleash
---

# Security & Safety

## Design Principles

### No root persistence
Unleash does not install backdoors, create hidden users, or modify the
system volume. All changes target the **Data volume** only and are
fully reversible.

### GPG-signed releases
Every release is signed with a GPG key. The `update` command verifies
the signature before applying updates. If verification fails, the
update is **rejected**.

### Opt-in telemetry
Telemetry is **OFF by default**. If enabled, it sends only anonymous
counts:
- Command name executed
- macOS version
- Success/failure status

No serial numbers, IPs, or personally identifiable information.

### No internet dependency
Core commands (`bypass`, `suppress`, `heal`) work entirely offline.
Only `update`, `firewall` (DNS resolution), and `discord-bot` need
network access.

---

## Safety Guarantees

- **No SSV writes** — all changes target the Data volume
- **Reversible** — `backup` saves state, `restore` reverts
- **No data erasure** — never runs `profiles renew` or erase commands
- **Idempotent** — running multiple times is harmless
- **Prompts for confirmation** before destructive actions

---

## Risk Levels

| Level | Description | Commands |
|-------|-------------|----------|
| Safe | Read-only, no changes | `status`, `check`, `doctor`, `audit`, `predict`, `report` |
| Low | Writes hosts file only | `suppress`, `heal` |
| Medium | Creates/modifies system files | `bypass`, `dualboot`, `persist`, `whitelist` |
| High | Kernel-level firewall | `firewall`, `vpn-kill` |
| Destructive | Full removal | `uninstall`, `reinstall` |

---

## Responsible Disclosure

Found a security issue?
See the [Security Policy](https://github.com/mateussiqueira/unleash/blob/main/SECURITY.md).
