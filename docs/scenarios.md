---
layout: default
title: Scenarios — unleash
---

# Scenarios

## Before buying a used Mac

Check the serial number before you buy:

```bash
./unleash predict ABC12345678    # check serial against known org prefixes
./unleash check                  # is this Mac safe to wipe?
```

`predict` looks up the device serial against known MDM org prefixes.
If it matches JAMF, Mosyle, or another org, you know what you're dealing with before you buy.

---

## Recovery after Migration Assistant

1. Fresh install macOS on a new Mac
2. Migration Assistant copies your old data
3. MDM appears within minutes of login

**Fix:** Boot to Recovery and run:
```bash
./unleash suppress
```

Or `bypass` if you need a new admin user. This removes the DEP markers,
user-level artifacts, and MDM preferences that MA transferred over.
*This is the #1 case most other tools miss — Unleash handles it.*

---

## macOS update brought MDM back

1. System update restores enrollment daemons automatically
2. MDM block in `/etc/hosts` is often preserved

**Fix:**
```bash
sudo ./unleash heal
```

Re-disables daemons and re-checks all layers. If you ran `persist`
before the update, this happens automatically on the next boot.

---

## Buying a former office Mac

1. The serial might still be in the company's ABM
2. Even after a clean wipe, connecting to Wi-Fi at Setup Assistant triggers enrollment

**Strategy:**
1. Boot to Recovery **without connecting to Wi-Fi**
2. Run `unleash bypass` before the device ever phones home
3. Run `unleash persist` and `unleash whitelist` so it stays clean
4. Only then connect to the internet

The serial stays in ABM forever — but as long as the device never
connects with full protections removed, it will not re-enroll.

---

## Used Mac that already has a user logged in

```bash
sudo ./unleash audit       # check current state
sudo ./unleash harden      # kill MDM processes immediately
sudo ./unleash whitelist   # block MDM while keeping iCloud
sudo ./unleash persist     # survive future updates
```

---

## Setting up a new Mac before first boot

1. Boot to Recovery without Wi-Fi
2. Run `unleash init` — interactive wizard
3. It will: suppress MDM, install persist, install whitelist, run audit
4. Reboot, set up normally, MDM never bothers you

---

## Org-provided Mac (must enroll on VPN only)

Some organizations require the Mac to enroll but only when connected to the corporate VPN.

```bash
sudo ./unleash vpn-kill
```

This installs a pf kill-switch that blocks MDM traffic when the device
is NOT connected to the VPN tunnel. MDM can only communicate through
the encrypted VPN connection.

---

## After a full DFU/IPSW restore

A DFU restore erases everything but doesn't remove ABM assignment.

1. Restore via Apple Configurator 2
2. **Do not connect to Wi-Fi**
3. Boot to Recovery
4. Run `unleash bypass`
5. Run `unleash persist && unleash whitelist`
6. Reboot and connect to the internet safely

---

## Automated deployment (IT admins)

For deploying across multiple machines:

```bash
# Scripted bypass
./unleash suppress --log-file /var/log/unleash-deploy.log

# With persist + monitor
sudo ./unleash persist
sudo ./unleash monitor

# Audit report in JSON
sudo ./unleash report --json

# Discord alerts
sudo ./unleash discord-bot <token> <userId>
```
