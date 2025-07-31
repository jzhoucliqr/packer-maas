packer {
  required_version = ">= 1.11.0"
  required_plugins {
    qemu = {
      version = ">= 1.1.0, < 1.1.2"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "filename" {
  type        = string
  default     = "fcos.tar.gz"
  description = "The filename of the tarball to produce"
}

variable "fcos_stream" {
  type        = string
  default     = "stable"
  description = "CoreOS stream: stable, testing, or next"
}

variable "timeout" {
  type        = string
  default     = "1h"
  description = "Timeout for building the image"
}

variable "architecture" {
  type        = string
  default     = "amd64"
  description = "The architecture to build the image for (amd64 only)"
}

variable "ovmf_suffix" {
  type        = string
  default     = ""
  description = "Suffix for OVMF CODE and VARS files. Newer systems such as Noble use _4M."
}

variable "ovmf_base" {
  type        = string
  default     = "/usr/share/OVMF"
  description = "Base path for OVMF files. Fedora uses /usr/share/edk2/ovmf, Ubuntu/Debian use /usr/share/OVMF."
}

variable "ssh_key" {
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0g+ZTxC7weoIJLUafOgrm+h...example@maas"
  description = "SSH public key for core user authentication"
}

locals {
  qemu_arch = {
    "amd64"   = "x86_64"
    "x86_64"  = "x86_64"
  }
  uefi_imp = {
    "amd64"   = "OVMF"
    "x86_64"  = "OVMF"
  }
  uefi_sfx = {
    "amd64"   = "${var.ovmf_suffix}"
    "x86_64"  = "${var.ovmf_suffix}"
  }
}

source "qemu" "fcos" {
  boot_command     = ["<wait10s>c<wait5s>linux /ostree/fedora-coreos-*/vmlinuz console=ttyS0 ignition.config.url=http://{{.HTTPIP}}:{{.HTTPPort}}/config.ign<enter><wait5s>initrd /ostree/fedora-coreos-*/initramfs.img<enter><wait5s>boot<enter>"]
  boot_wait        = "10s"
  communicator     = "none"
  disk_size        = "8G"
  headless         = true
  iso_checksum     = "none"
  iso_url          = "fedora-coreos-current.qcow2"
  memory           = 2048
  cores            = 2
  qemu_binary      = "qemu-system-x86_64"
  qemuargs = [
    ["-serial", "stdio"],
    ["-boot", "strict=off"],
    ["-device", "qemu-xhci"],
    ["-device", "usb-kbd"],
    ["-device", "virtio-net-pci,netdev=net0"],
    ["-netdev", "user,id=net0"],
    ["-device", "virtio-blk-pci,drive=drive0,bootindex=0"],
    ["-machine", "accel=kvm:tcg"],
    ["-cpu", "max"],
    ["-device", "virtio-gpu-pci"],
    ["-global", "driver=cfi.pflash01,property=secure,value=off"],
    ["-drive", "if=pflash,format=raw,unit=0,id=ovmf_code,readonly=on,file=${var.ovmf_base}/OVMF_CODE${var.ovmf_suffix}.fd"],
    ["-drive", "if=pflash,format=raw,unit=1,id=ovmf_vars,file=x86_64_VARS.fd"],
    ["-drive", "file=fedora-coreos-current.qcow2,if=none,id=drive0,cache=writeback,discard=ignore,format=qcow2"],
    ["-fw_cfg", "name=opt/com.coreos/config,file=config.ign"]
  ]
  shutdown_timeout = var.timeout
  http_content = {
    "/config.ign" = templatefile("${path.root}/http/config.ign.pkrtpl.hcl",
      {
        SSH_KEY = var.ssh_key
      }
    )
  }
}

build {
  sources = ["source.qemu.fcos"]

  provisioner "shell-local" {
    inline = [
      "# Generate the Ignition config file",
      "sed 's/\\$\\{SSH_KEY\\}/${var.ssh_key}/' http/config.ign.pkrtpl.hcl > config.ign"
    ]
  }

  post-processor "shell-local" {
    inline = [
      "SOURCE=${source.name}",
      "OUTPUT=${var.filename}",
      "CURTIN_HOOKS=curtin",
      "source ../scripts/fuse-nbd",
      "source ../scripts/fuse-tar-root",
      "rm -rf output-${source.name}",
      "rm -f config.ign"
    ]
    inline_shebang = "/bin/bash -e"
  }
}