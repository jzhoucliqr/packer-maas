# Fedora CoreOS Packer Template for MAAS

## Introduction

The Packer template in this directory creates a Fedora CoreOS image for use with MAAS on AMD64 and ARM64 architectures.

## Prerequisites (to create the image)

* A machine running Ubuntu 22.04+ with the ability to run KVM virtual machines.
* qemu-utils, libnbd-bin, nbdkit and fuse2fs
* [Packer](https://www.packer.io/intro/getting-started/install.html), v1.8.0 or newer
* [coreos-installer](https://github.com/coreos/coreos-installer) for downloading CoreOS images

### Installing coreos-installer

On Fedora/RHEL/CentOS:
```shell
sudo dnf install coreos-installer
```

On Ubuntu/Debian:
```shell
# Install from GitHub releases
wget https://github.com/coreos/coreos-installer/releases/latest/download/coreos-installer-x86_64-unknown-linux-gnu
sudo install coreos-installer-x86_64-unknown-linux-gnu /usr/local/bin/coreos-installer
```

Alternatively, use the container version (no installation required):
```shell
alias coreos-installer='podman run --pull=always --rm -v ${PWD}:/data -w /data quay.io/coreos/coreos-installer:release'
```

## Requirements (to deploy the image)

* [MAAS](https://maas.io) 3.3+
* [Curtin](https://launchpad.net/curtin) 22.1+

## Customizing the Image

The deployment image may be customized by modifying http/config.ign.pkrtpl.hcl. See the [Ignition documentation](https://coreos.github.io/ignition/) for more information.

### Understanding Ignition vs Kickstart

Unlike traditional Linux distributions that use Kickstart files, CoreOS uses Ignition for first-boot configuration:

- **Kickstart**: Used during installation to configure the OS while it's being installed
- **Ignition**: Runs on first boot of an already-installed system to configure it

The Ignition configuration includes:
- User account setup (core user with SSH keys)
- Systemd service configuration
- File system modifications
- Network configuration handoff to cloud-init

## Building an image

You can easily build the image using the Makefile:

```shell
make
```

You can specify a different CoreOS stream:

```shell
make STREAM=testing
```

You can build for different architectures:

```shell
make ARCH=aarch64
```

You can combine parameters:

```shell
make STREAM=testing ARCH=aarch64
```

Alternatively you can manually run packer. Your current working directory must
be in packer-maas/fcos, where this file is located. Once in packer-maas/fcos
you can generate an image with:

```shell
packer init
PACKER_LOG=1 packer build .
```

Note: fcos.pkr.hcl is configured to run Packer in headless mode. Only Packer
output will be seen. If you wish to see the installation output connect to the
VNC port given in the Packer output or change the value of headless to false in
fcos.pkr.hcl.

Installation is non-interactive.

### Makefile Parameters

#### STREAM

The CoreOS stream to use. Defaults to stable. Options are:
- stable (default)
- testing  
- next

#### ARCH

The target architecture for the image. Defaults to x86_64. Options are:
- x86_64 (default) 
- aarch64

#### TIMEOUT

The timeout to apply when building the image. The default value is set to 1h.

## Uploading an image to MAAS

For AMD64/x86_64:
```shell
maas $PROFILE boot-resources create \
    name='custom/fcos' title='Fedora CoreOS Custom' \
    architecture='amd64/generic' filetype='tgz' \
    content@=fcos.tar.gz
```

For ARM64/aarch64:
```shell
maas $PROFILE boot-resources create \
    name='custom/fcos-arm64' title='Fedora CoreOS Custom ARM64' \
    architecture='arm64/generic' filetype='tgz' \
    content@=fcos.tar.gz
```

## Default Username

The default username is ```core```

## Troubleshooting

### Common Build Issues

**Error: "coreos-installer not found"**
- Install coreos-installer using the instructions above
- Or use the container version with the provided alias

**Error: "Downloaded image appears corrupted"**
- Clean downloaded images: `make clean-downloads`
- Retry the build: `make`
- Check network connectivity and try a different CoreOS stream

**Error: "Ignition validation failed"**
- Validate your Ignition config: `make validate-ignition`
- Check JSON syntax in http/config.ign.pkrtpl.hcl
- Ensure all required fields are present

**Error: "OVMF files not found"**
- Install OVMF firmware: `sudo apt install ovmf` (Ubuntu) or `sudo dnf install edk2-ovmf` (Fedora)
- The Makefile automatically detects the correct OVMF suffix

### Custom Ignition Configuration Examples

#### Adding additional users:
```json
"passwd": {
  "users": [
    {
      "name": "core",
      "groups": ["sudo", "docker"],
      "sshAuthorizedKeys": ["ssh-rsa AAAAB3..."]
    },
    {
      "name": "admin",
      "groups": ["sudo"],
      "sshAuthorizedKeys": ["ssh-rsa AAAAB3..."]
    }
  ]
}
```

#### Installing additional systemd services:
```json
"systemd": {
  "units": [
    {
      "name": "my-service.service",
      "enabled": true,
      "contents": "[Unit]\nDescription=My Custom Service\n[Service]\nExecStart=/usr/bin/my-app\n[Install]\nWantedBy=multi-user.target"
    }
  ]
}
```

### CoreOS Stream Information

- **stable**: Production-ready releases, updated monthly
- **testing**: Pre-release versions, updated bi-weekly  
- **next**: Development versions with latest features, updated weekly

Choose the appropriate stream based on your stability requirements.