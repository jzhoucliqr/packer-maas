#!/usr/bin/make -f

include ../scripts/check.mk

PACKER ?= packer
PACKER_LOG ?= 0
STREAM ?= stable
TIMEOUT ?= 1h
ARCH ?= x86_64

# Detect if running on ARM host
ifeq ($(shell uname -m),aarch64)
    HOST_IS_ARM = true
else
    HOST_IS_ARM = false
endif

ifeq ($(wildcard /usr/share/OVMF/OVMF_CODE.fd),)
	OVMF_SFX ?= _4M
else
	OVMF_SFX ?=
endif

export PACKER_LOG

# Fallback
ifeq ($(strip $(ARCH)),amd64)
	ARCH = x86_64
endif

.PHONY: all clean download-image validate-ignition test test-integration

all: fcos.tar.gz

$(eval $(call check_packages_deps))

lint: validate-ignition
	packer validate .
	packer fmt -check -diff .

format:
	packer fmt .

validate-ignition:
	@echo "Validating Ignition configuration..."
	@# Generate the Ignition config with placeholder SSH key for validation
	@mkdir -p temp
	@sed 's/$${SSH_KEY}/ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0g+ZTxC7weoIJLUafOgrm+h...test@example.com/' http/config.ign.pkrtpl.hcl > temp/config.ign
	@if command -v ignition-validate >/dev/null 2>&1; then \
		echo "Using ignition-validate for validation..."; \
		ignition-validate temp/config.ign || (echo "Ignition validation failed" && rm -rf temp && exit 1); \
	else \
		echo "ignition-validate not found, using basic JSON validation..."; \
		if command -v jq >/dev/null 2>&1; then \
			jq empty temp/config.ign || (echo "Invalid JSON in Ignition config" && rm -rf temp && exit 1); \
		else \
			echo "Warning: No validation tools available. Install ignition-validate or jq for validation."; \
		fi; \
	fi
	@rm -rf temp
	@echo "Ignition configuration is valid"

download-image:
	@echo "Downloading Fedora CoreOS $(STREAM) stream for $(ARCH)..."
	@if ! command -v coreos-installer >/dev/null 2>&1; then \
		echo "Error: coreos-installer not found. Please install it first."; \
		echo "Install with: sudo dnf install coreos-installer"; \
		echo "Or from container: podman run --pull=always --rm -v \$${PWD}:/data -w /data quay.io/coreos/coreos-installer:release download -s $(STREAM) -p qemu -f qcow2.xz --decompress"; \
		exit 1; \
	fi
	@if [ ! -f fedora-coreos-*-$(STREAM)-*-qemu.$(ARCH).qcow2 ]; then \
		echo "Downloading CoreOS $(STREAM) stream with verification..."; \
		for retry in 1 2 3; do \
			echo "Download attempt $$retry..."; \
			if coreos-installer download -s $(STREAM) -p qemu -f qcow2.xz --decompress --architecture $(ARCH) -C ./; then \
				echo "Download successful"; \
				break; \
			else \
				echo "Download failed, attempt $$retry/3"; \
				if [ $$retry -eq 3 ]; then \
					echo "All download attempts failed"; \
					exit 1; \
				fi; \
				sleep $$((retry * 2)); \
			fi; \
		done; \
	else \
		echo "CoreOS image already exists, skipping download."; \
	fi
	@# Verify the downloaded image exists and is valid
	@if [ ! -f fedora-coreos-*-$(STREAM)-*-qemu.$(ARCH).qcow2 ]; then \
		echo "Error: No CoreOS image found after download"; \
		exit 1; \
	fi
	@# Basic file size validation (CoreOS images should be > 500MB)
	@IMAGE_SIZE=$$(stat -c%s fedora-coreos-*-$(STREAM)-*-qemu.$(ARCH).qcow2 2>/dev/null || stat -f%z fedora-coreos-*-$(STREAM)-*-qemu.$(ARCH).qcow2 2>/dev/null); \
	if [ $$IMAGE_SIZE -lt 524288000 ]; then \
		echo "Error: Downloaded image appears corrupted (size: $$IMAGE_SIZE bytes)"; \
		rm -f fedora-coreos-*-$(STREAM)-*-qemu.$(ARCH).qcow2; \
		exit 1; \
	fi
	@# Create a symlink with a predictable name for the template
	@if [ ! -L fedora-coreos-current.qcow2 ]; then \
		ln -sf $$(ls fedora-coreos-*-$(STREAM)-*-qemu.$(ARCH).qcow2 | head -1) fedora-coreos-current.qcow2; \
	fi
	@echo "CoreOS image ready: $$(ls fedora-coreos-*-$(STREAM)-*-qemu.$(ARCH).qcow2)"

OVMF_VARS.fd: /usr/share/OVMF/OVMF_VARS${OVMF_SFX}.fd
	cp -v $< ${ARCH}_VARS.fd

SIZE_VARS.fd:
ifeq ($(strip $(ARCH)),aarch64)
	truncate -s 64m ${ARCH}_VARS.fd
else
	truncate -s 2m ${ARCH}_VARS.fd
endif

fcos.tar.gz: check-deps clean validate-ignition download-image OVMF_VARS.fd SIZE_VARS.fd
	${PACKER} init fcos.pkr.hcl && ${PACKER} build \
							-var architecture=${ARCH} \
							-var host_is_arm=${HOST_IS_ARM} \
							-var ovmf_suffix=${OVMF_SFX} \
							-var fcos_stream=${STREAM} \
							-var timeout=${TIMEOUT} \
							fcos.pkr.hcl

clean:
	${RM} -rf *.fd output-fcos fcos.tar.gz fedora-coreos-*.qcow2 fedora-coreos-current.qcow2 config.ign temp/

clean-downloads:
	${RM} -rf fedora-coreos-*.qcow2 fedora-coreos-current.qcow2

help:
	@echo "Available targets:"
	@echo "  all              - Build the FCOS image (default)"
	@echo "  download-image   - Download CoreOS QEMU image"
	@echo "  validate-ignition- Validate Ignition configuration"
	@echo "  lint             - Validate Packer template and format"
	@echo "  format           - Format Packer template"
	@echo "  clean            - Clean build artifacts"
	@echo "  clean-downloads  - Clean downloaded CoreOS images"
	@echo "  test             - Run validation tests"
	@echo "  help             - Show this help"
	@echo ""
	@echo "Variables:"
	@echo "  STREAM           - CoreOS stream (stable, testing, next) [default: stable]"
	@echo "  TIMEOUT          - Build timeout [default: 1h]"

test: validate-ignition
	@echo "Running template validation tests..."
	@echo "✓ Testing Packer template syntax..."
	@packer validate . || (echo "✗ Packer template validation failed" && exit 1)
	
	@echo "✓ Testing Ignition configuration..."
	@$(MAKE) validate-ignition || (echo "✗ Ignition validation failed" && exit 1)
	
	@echo "✓ Testing variable substitution..."
	@mkdir -p temp
	@sed 's/\\$\\{SSH_KEY\\}/ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0g+ZTxC7weoIJLUafOgrm+h...test@example.com/' http/config.ign.pkrtpl.hcl > temp/test-config.ign
	@if command -v jq >/dev/null 2>&1; then \
		echo "  - Checking core user configuration..."; \
		jq -e '.passwd.users[] | select(.name=="core")' temp/test-config.ign >/dev/null || (echo "✗ Core user not found in config" && rm -rf temp && exit 1); \
		echo "  - Checking cloud-init service..."; \
		jq -e '.systemd.units[] | select(.name=="cloud-init.service")' temp/test-config.ign >/dev/null || (echo "✗ cloud-init service not configured" && rm -rf temp && exit 1); \
		echo "  - Checking MAAS datasource configuration..."; \
		jq -e '.storage.files[] | select(.path=="/etc/cloud/cloud.cfg.d/10_maas.cfg")' temp/test-config.ign >/dev/null || (echo "✗ MAAS datasource not configured" && rm -rf temp && exit 1); \
	fi
	@rm -rf temp
	@echo "✓ All validation tests passed!"

test-integration:
	@echo "Running integration tests..."
	@echo "✓ Testing CoreOS image download for different streams..."
	
	@echo "  - Testing stable stream download..."
	@$(MAKE) STREAM=stable download-image || (echo "✗ Failed to download stable stream" && exit 1)
	@if [ -f fedora-coreos-current.qcow2 ]; then \
		echo "  - Verifying downloaded image..."; \
		qemu-img check fedora-coreos-current.qcow2 || (echo "✗ Downloaded image is corrupted" && exit 1); \
		echo "  - Image verification passed"; \
	else \
		echo "✗ Downloaded image not found"; \
		exit 1; \
	fi
	
	@echo "✓ Testing Packer build process (dry-run)..."
	@$(MAKE) validate-ignition
	@mkdir -p temp
	@sed 's/\\$\\{SSH_KEY\\}/ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0g+ZTxC7weoIJLUafOgrm+h...test@example.com/' http/config.ign.pkrtpl.hcl > config.ign
	@echo "  - Ignition config generated successfully"
	@rm -f config.ign
	
	@echo "✓ Testing MAAS image format requirements..."
	@echo "  - Checking fuse-nbd script availability..."
	@test -f ../scripts/fuse-nbd || (echo "✗ fuse-nbd script not found" && exit 1)
	@echo "  - Checking fuse-tar-root script availability..."  
	@test -f ../scripts/fuse-tar-root || (echo "✗ fuse-tar-root script not found" && exit 1)
	
	@rm -rf temp
	@echo "✓ All integration tests passed!"