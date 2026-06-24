---
layout: default
title: Installation — unleash
---

# Installation

## Homebrew (easiest)

```bash
brew tap mateussiqueira/unleash
brew install unleash
```

Or in one step:
```bash
brew install mateussiqueira/unleash/unleash
```

## Direct download

```bash
curl -L https://raw.githubusercontent.com/mateussiqueira/unleash/main/unleash-standalone.sh -o unleash
chmod +x unleash
sudo ./unleash init
```

## From a USB drive (for Recovery mode)

1. Format a USB/SSD as **FAT32**, **APFS**, or **exFAT**
2. Copy the `unleash` folder (or just `unleash-standalone.sh`) to the drive
3. Boot to Recovery and run from `/Volumes/YourDrive/unleash`

## Via curl in Recovery (needs internet)

```bash
curl -L https://raw.githubusercontent.com/mateussiqueira/unleash/main/unleash -o /tmp/unleash
chmod +x /tmp/unleash && /tmp/unleash bypass
```

## Building from source

```bash
git clone https://github.com/mateussiqueira/unleash.git
cd unleash
bash examples/build-standalone.sh
# Output: unleash-standalone.sh (~3200 lines)
```

## Verifying the installation

```bash
./unleash version
# → unleash v2.0.0

./unleash doctor
# Runs pre-flight diagnostics
```
