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
  description = "The architecture to build the image for (amd64, aarch64)"
}

variable "host_is_arm" {
  type        = bool
  default     = false
  description = "The host architecture is aarch64"
}

variable "ovmf_suffix" {
  type        = string
  default     = ""
  description = "Suffix for OVMF CODE and VARS files. Newer systems such as Noble use _4M."
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
    "aarch64" = "aarch64"
  }
  uefi_imp = {
    "amd64"   = "OVMF"
    "x86_64"  = "OVMF"
    "aarch64" = "AAVMF"
  }
  uefi_sfx = {
    "amd64"   = "${var.ovmf_suffix}"
    "x86_64"  = "${var.ovmf_suffix}"
    "aarch64" = ""
  }
  qemu_machine = {
    "amd64"   = "accel=kvm"
    "x86_64"  = "accel=kvm"
    "aarch64" = var.host_is_arm ? "virt,accel=kvm" : "virt"
  }
  qemu_cpu = {
    "amd64"   = "host"
    "x86_64"  = "host"
    "aarch64" = var.host_is_arm ? "host" : "max"
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
  qemu_binary      = "qemu-system-${lookup(local.qemu_arch, var.architecture, "")}"
  qemuargs = [
    ["-serial", "stdio"],
    ["-boot", "strict=off"],
    ["-device", "qemu-xhci"],
    ["-device", "usb-kbd"],
    ["-device", "virtio-net-pci,netdev=net0"],
    ["-netdev", "user,id=net0"],
    ["-device", "virtio-blk-pci,drive=drive0,bootindex=0"],
    ["-machine", "${lookup(local.qemu_machine, var.architecture, "")}"],
    ["-cpu", "${lookup(local.qemu_cpu, var.architecture, "")}"],
    ["-device", "virtio-gpu-pci"],
    ["-global", "driver=cfi.pflash01,property=secure,value=off"],
    ["-drive", "if=pflash,format=raw,unit=0,id=ovmf_code,readonly=on,file=/usr/share/${lookup(local.uefi_imp, var.architecture, "")}/${lookup(local.uefi_imp, var.architecture, "")}_CODE${lookup(local.uefi_sfx, var.architecture, "")}.fd"],
    ["-drive", "if=pflash,format=raw,unit=1,id=ovmf_vars,file=${var.architecture}_VARS.fd"],
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