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
  default     = ""
  description = "SSH public key for core user authentication. If empty, will read from ~/.ssh/id_rsa.pub"
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
  
  # Use provided SSH key or read from default location
  ssh_key = var.ssh_key != "" ? var.ssh_key : trimspace(file("~/.ssh/id_rsa.pub"))
}

source "qemu" "fcos" {
  boot_command     = []
  boot_wait        = "3s"
  communicator     = "none"
  pause_before_connecting = "2m"
  disk_image       = true
  disk_interface   = "virtio"
  disk_size        = "8G"
  format           = "qcow2"
  headless         = true
  iso_checksum     = "none"
  iso_url          = "fedora-coreos-current.qcow2"
  use_backing_file = true
  memory           = 2048
  cores            = 2
  qemu_binary      = "qemu-system-x86_64"
  qemuargs = [
    ["-nographic"],
    ["-serial", "stdio"],
    ["-machine", "accel=kvm:tcg"],
    ["-cpu", "max"],
    ["-global", "driver=cfi.pflash01,property=secure,value=off"],
    ["-drive", "if=pflash,format=raw,unit=0,id=ovmf_code,readonly=on,file=${var.ovmf_base}/OVMF_CODE${var.ovmf_suffix}.fd"],
    ["-drive", "if=pflash,format=raw,unit=1,id=ovmf_vars,file=x86_64_VARS.fd"],
    ["-fw_cfg", "name=opt/com.coreos/config,file=config.ign"]
  ]
  shutdown_timeout = var.timeout
}

build {
  sources = ["source.qemu.fcos"]



  post-processor "shell-local" {
    inline = [
      "SOURCE=${source.name}",
      "OUTPUT=${var.filename}",
      "CURTIN_HOOKS=curtin",
      "ROOT_PARTITION=3",
      "source ../scripts/fuse-nbd",
      "source ../scripts/fuse-tar-root",
      "rm -rf output-${source.name}",
      "rm -f config.ign"
    ]
    inline_shebang = "/bin/bash -e"
  }
}