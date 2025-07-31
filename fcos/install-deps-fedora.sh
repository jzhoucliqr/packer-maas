#!/bin/bash -e
#
# install-deps-fedora.sh - Install dependencies for FCOS Packer build on Fedora
#
# Author: Canonical Ltd.
#
# Copyright (C) 2024 Canonical
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

set -euo pipefail

echo "🚀 Installing Fedora CoreOS Packer build dependencies..."

# Check if running as root or with sudo access
if [[ $EUID -eq 0 ]]; then
    SUDO=""
elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
    echo "ℹ️  Will use sudo for package installation"
else
    echo "❌ Error: Need root access or sudo to install packages"
    exit 1
fi

# Update package cache
echo "📦 Updating package cache..."
$SUDO dnf update -y --refresh

# Install core virtualization and build tools
echo "🔧 Installing core virtualization packages..."
$SUDO dnf install -y \
    qemu-system-x86 \
    qemu-img \
    qemu-kvm \
    edk2-ovmf

# Install development and file system tools
echo "🛠️  Installing development tools..."
$SUDO dnf install -y \
    make \
    git \
    curl \
    wget \
    jq \
    tar \
    gzip \
    fuse-sshfs \
    fuse3 \
    fuse3-devel

# Install NBD and related tools
echo "💾 Installing NBD and storage tools..."
$SUDO dnf install -y \
    libnbd \
    libnbd-devel \
    nbdkit \
    nbdkit-basic-plugins \
    nbdkit-server \
    parted

# Install coreos-installer
echo "🔥 Installing CoreOS installer..."
if ! command -v coreos-installer >/dev/null 2>&1; then
    $SUDO dnf install -y coreos-installer
    echo "✅ CoreOS installer installed"
else
    echo "✅ CoreOS installer already available"
fi

# Install Packer if not available
echo "📦 Checking Packer installation..."
if ! command -v packer >/dev/null 2>&1; then
    echo "🚀 Installing Packer..."
    
    # Add HashiCorp repository
    $SUDO dnf install -y dnf-plugins-core
    $SUDO dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
    $SUDO dnf install -y packer
    
    echo "✅ Packer installed"
else
    PACKER_VERSION=$(packer version 2>/dev/null | head -1 || echo "unknown")
    echo "✅ Packer already available: $PACKER_VERSION"
fi

# Install Ignition validation tools (optional but recommended)
echo "🔍 Installing Ignition validation tools..."
if ! command -v ignition-validate >/dev/null 2>&1; then
    # ignition-validate might not be in standard repos, try alternatives
    if $SUDO dnf search ignition-validate 2>/dev/null | grep -q ignition-validate; then
        $SUDO dnf install -y ignition-validate
        echo "✅ ignition-validate installed"
    else
        echo "⚠️  ignition-validate not available in repos - will use jq for validation"
        $SUDO dnf install -y jq
    fi
else
    echo "✅ ignition-validate already available"
fi

# Check if virtualization is enabled
echo "🔍 Checking virtualization support..."
if [[ -e /dev/kvm ]]; then
    echo "✅ KVM device available at /dev/kvm"
    
    # Check if user can access KVM
    if [[ -r /dev/kvm && -w /dev/kvm ]]; then
        echo "✅ Current user has KVM access"
    else
        echo "⚠️  Current user may need to be added to 'kvm' group:"
        echo "   sudo usermod -a -G kvm $USER"
        echo "   (then logout and login again)"
    fi
else
    echo "⚠️  KVM device not found - will use software emulation (slower)"
    echo "   This is normal in containers or VMs without nested virtualization"
fi

# Create necessary directories
echo "📁 Creating working directories..."
mkdir -p ~/.cache/packer
mkdir -p ~/.config/packer

# Verify OVMF installation
echo "🔍 Verifying OVMF firmware installation..."
if [[ -d /usr/share/edk2 ]]; then
    echo "✅ OVMF firmware found in /usr/share/edk2/"
    ls -la /usr/share/edk2/ | grep -E "OVMF|AAVMF" | head -5
elif [[ -d /usr/share/OVMF ]]; then
    echo "✅ OVMF firmware found in /usr/share/OVMF/"
    ls -la /usr/share/OVMF/ | head -5
else
    echo "❌ OVMF firmware not found in expected locations"
    echo "   Try: sudo dnf install edk2-ovmf edk2-aarch64"
fi

echo ""
echo "🎉 Dependency installation complete!"
echo ""
echo "📋 Next steps:"
echo "1. Download CoreOS image: make download-image"
echo "2. Build FCOS image: make"
echo ""
echo "🔧 If you encounter KVM access issues:"
echo "   sudo usermod -a -G kvm $USER"
echo "   # Then logout and login again"
echo ""
echo "💡 For troubleshooting, run with debug: PACKER_LOG=1 make" 