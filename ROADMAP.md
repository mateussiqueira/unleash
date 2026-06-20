# Roadmap 2026-07 — 2026-12

## Q3 2026 (Jul–Sep) — Foundation

### July — v1.7.0 "Solidify"
- [ ] **Resolve GitHub Actions billing** — re-enable CI/CD
- [ ] **Fix CI pipeline** — all checks passing on every PR
- [ ] **Homebrew audit** — `brew audit --strict` passes on `mateussiqueira/unleash/unleash`
- [ ] **Improve bats test coverage** — mock-based tests for firewall, monitor, vpn modules
- [ ] **Add `--help` flag** per command (currently only global `-h`)

### August — v1.8.0 "Reliability"
- [ ] **macOS 27 final compatibility** — test and confirm on GM release
- [ ] **Migration Assistant deep scan** — detect leftover MA artifacts even after bypass
- [ ] **Auto-detect Configurator/Apple School Manager** enrollment
- [ ] **Graceful pf cleanup** — backup pf anchors before modification
- [ ] **Disk utilization check** before backup/restore

### September — v2.0.0 "Foundation"
- [ ] **Homebrew core** — submit PR to official Homebrew/homebrew-core
- [ ] **`docs/` site with Jekyll** — proper multi-page site, not just a single markdown file
- [ ] **`unleash init` wizard** — interactive setup: asks questions, runs doctor, suggests commands
- [ ] **Release signing** — GPG-signed releases + checksums file
- [ ] **Self-update with GPG verification**

---

## Q4 2026 (Oct–Dec) — Growth

### October — v2.1.0 "Ecosystem"
- [ ] **Nix/NixOS** — package for nixpkgs
- [ ] **Docker image** — recovery-mode container for testing (QEMU + macOS base image)
- [ ] **Website** — dedicated domain with full docs, search, dark mode (Catppuccin)
- [ ] **Telemetry opt-in** — anonymous usage stats to prioritize features (off by default)

### November — v2.2.0 "Intelligence"
- [ ] **Predictive check** — given a serial number, predict which org the Mac is enrolled in
- [ ] **Risk-based suggestions** — `unleash suggest` reads system state and recommends commands
- [ ] **Remediation scripts** — per-org MDM quirks (some orgs use custom domains or certs)
- [ ] **Discord bot** — monitor MDM status via Discord DM

### December — v2.3.0 "Community"
- [ ] **20+ GitHub stars** — organic growth
- [ ] **3+ external contributors** — PRs from non-author
- [ ] **Bug bounty** — $50 for reproducible MDM re-enrollment edge cases
- [ ] **Year-in-review** — retrospective blog post with usage data

---

## Stretch goals (if time/budget allows)

- **Windows dual-boot MDM detection** — detect if a Windows partition carries MDM payloads
- **Linux live USB** — standalone Linux environment with unleash pre-loaded for Recovery
- **GUI wrapper** — simple SwiftUI app that calls the CLI
- **Localization** — Spanish, French, German command output
- **CI/CD with `act`** — documented local CI workflow for offline development

---

## How to contribute

Pick any unchecked item, open an issue or discussion, and submit a PR. See [CONTRIBUTING.md](https://github.com/mateussiqueira/unleash/blob/main/CONTRIBUTING.md) for guidelines.
