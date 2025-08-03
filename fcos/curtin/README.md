# Curtin Directory for Fedora CoreOS

## Purpose

This directory serves a **dual purpose** for FCOS deployment in MAAS:

### 1. 🎯 **Filesystem Marker**
- **Required by MAAS**: Curtin searches for `['curtin', 'system-data/var/lib/snapd', 'snaps']` to identify the root filesystem
- **Without this directory**: MAAS deployment fails with `ValueError: Did not find any filesystem`
- **Critical for deployment**: MAAS needs this marker to locate the correct partition during deployment

### 2. 🔧 **Minimal Hooks**
- **Simplified approach**: Only `curtin-hooks` is included
- **No complex operations**: Most configuration handled by Ignition during first boot
- **Self-cleaning**: Directory removes itself after deployment

## How FCOS Differs

### Traditional Linux Distributions:
```
ISO Installation → Curtin Hooks → Bootloader Setup → Package Installation → Configuration
```

### Fedora CoreOS:
```
Pre-built qcow2 → Minimal Curtin (filesystem marker) → Ignition Configuration → Ready
```

## What Ignition Handles Instead:
- ✅ User account setup (core user + SSH keys)
- ✅ Cloud-init configuration (MAAS datasource)
- ✅ Systemd service configuration
- ✅ File system modifications
- ✅ Network configuration handoff

## Files in This Directory:
- `curtin-hooks`: Minimal Python script that serves as deployment marker
- `README.md`: This documentation file

The curtin hooks are intentionally minimal because CoreOS uses Ignition for system configuration rather than traditional package management and system setup approaches. 