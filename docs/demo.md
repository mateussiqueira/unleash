## unleash v2.0.0 — Terminal Demo

```
$ sudo ./unleash --version
unleash v1.6.0

$ sudo ./unleash check
[DRY-RUN] System Assessment
  ✓ Recovery mode: yes
  ✓ Data volume: /Volumes/Data (123.4 GB free)
  ✓ /etc/hosts: writable
  ⚠ FileVault: enabled (key required)
  ⚠ Previous bypass: detected
VP>: SAFE TO FORMAT (no active MDM record)

$ sudo ./unleash audit
[AUDIT] Deep MDM Scan
  Active profiles: 0
  DEP enrollment: clean
  MDM domains blocked: 13/13
  Daemon overrides: 4/4 active
  Risk score: 0 (LOW)

$ sudo ./unleash status -d
[ OK] System: clean
[ OK] Profiles: 0
[INF] MDM: no enrollment found
[INF] User artifacts: none
[ OK] Last check: 30s ago

$ sudo ./unleash report --json
{
  "version": "1.6.0",
  "platform": "darwin",
  "arch": "arm64",
  "recovery": true,
  "mdm_enrolled": false,
  "risk_score": 0
}
```
