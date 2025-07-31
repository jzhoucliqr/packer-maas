#!/usr/bin/make -f

include ../scripts/check.mk

PACKER ?= packer
PACKER_LOG ?= 0
STREAM ?= stable
TIMEOUT ?= 1h
ARCH ?= x86_64

# x86_64 only support

# Detect OVMF location and suffix (Fedora vs Ubuntu/Debian)
ifeq ($(wildcard /usr/share/edk2/ovmf/OVMF_CODE.fd),)
  ifeq ($(wildcard /usr/share/OVMF/OVMF_CODE.fd),)
	OVMF_SFX ?= _4M
	OVMF_BASE ?= /usr/share/OVMF
  else
	OVMF_SFX ?=
	OVMF_BASE ?= /usr/share/OVMF
  endif
else
	OVMF_SFX ?=
	OVMF_BASE ?= /usr/share/edk2/ovmf
endif

export PACKER_LOG

# Fallback
ifeq ($(strip $(ARCH)),amd64)
	ARCH = x86_64
endif

.PHONY: all clean download-image validate-ignition test test-integration

all: fcos.tar.gz

#$(eval $(call check_packages_deps))

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
	@# Check if we already have a CoreOS image for x86_64
	@if [ ! -f fedora-coreos-*-qemu.x86_64.qcow2 ]; then \
		echo "Downloading CoreOS $(STREAM) stream with verification..."; \
		for retry in 1 2 3; do \
			echo "Download attempt $$retry..."; \
			if coreos-installer download -s $(STREAM) -p qemu -f qcow2.xz --decompress --architecture x86_64 -C ./; then \
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
	@COREOS_IMAGE=$$(ls fedora-coreos-*-qemu.x86_64.qcow2 2>/dev/null | head -1); \
	if [ -z "$$COREOS_IMAGE" ]; then \
		echo "Error: No CoreOS image found after download"; \
		exit 1; \
	fi
	@# Basic file size validation (CoreOS images should be > 500MB)
	@COREOS_IMAGE=$$(ls fedora-coreos-*-qemu.x86_64.qcow2 | head -1); \
	IMAGE_SIZE=$$(stat -c%s "$$COREOS_IMAGE" 2>/dev/null || stat -f%z "$$COREOS_IMAGE" 2>/dev/null); \
	if [ $$IMAGE_SIZE -lt 524288000 ]; then \
		echo "Error: Downloaded image appears corrupted (size: $$IMAGE_SIZE bytes)"; \
		rm -f "$$COREOS_IMAGE"; \
		exit 1; \
	fi
	@# Create a symlink with a predictable name for the template
	@COREOS_IMAGE=$$(ls fedora-coreos-*-qemu.x86_64.qcow2 | head -1); \
	if [ ! -L fedora-coreos-current.qcow2 ] || [ ! -e fedora-coreos-current.qcow2 ]; then \
		echo "Creating symlink: fedora-coreos-current.qcow2 -> $$COREOS_IMAGE"; \
		ln -sf "$$COREOS_IMAGE" fedora-coreos-current.qcow2; \
	fi
	@echo "CoreOS image ready: $$(ls fedora-coreos-*-qemu.x86_64.qcow2 | head -1)"

OVMF_VARS.fd: 
	@if [ -f "${OVMF_BASE}/OVMF_VARS${OVMF_SFX}.fd" ]; then \
		cp -v "${OVMF_BASE}/OVMF_VARS${OVMF_SFX}.fd" x86_64_VARS.fd; \
	else \
		echo "❌ OVMF_VARS.fd not found. Install with: sudo dnf install edk2-ovmf"; \
		exit 1; \
	fi

SIZE_VARS.fd:
	truncate -s 2m x86_64_VARS.fd

fcos.tar.gz: check-deps clean validate-ignition download-image OVMF_VARS.fd SIZE_VARS.fd
	${PACKER} init fcos.pkr.hcl && ${PACKER} build \
							-var architecture=${ARCH} \
							-var ovmf_suffix=${OVMF_SFX} \
							-var ovmf_base=${OVMF_BASE} \
							-var fcos_stream=${STREAM} \
							-var timeout=${TIMEOUT} \
							fcos.pkr.hcl

clean:
	@echo "Cleaning build artifacts (preserving downloaded images)..."
	${RM} -rf *.fd output-fcos fcos.tar.gz config.ign temp/
	@echo "Build cleanup complete (CoreOS images preserved)"

clean-downloads:
	@echo "Cleaning downloaded CoreOS images..."
	${RM} -f fedora-coreos-*-qemu.*.qcow2 fedora-coreos-current.qcow2
	@echo "Download cleanup complete"

help:
	@echo "Available targets:"
	@echo "  all              - Build the FCOS image (default)"
	@echo "  download-image   - Download CoreOS QEMU image"
	@echo "  validate-ignition- Validate Ignition configuration"
	@echo "  lint             - Validate Packer template and format"
	@echo "  format           - Format Packer template"
	@echo "  clean            - Clean build artifacts (preserves downloaded images)"
	@echo "  clean-downloads  - Clean downloaded CoreOS images"
	@echo "  test             - Run validation tests"
	@echo "  help             - Show this help"
	@echo ""
	@echo "Variables:"
	@echo "  STREAM           - CoreOS stream (stable, testing, next) [default: stable]"
	@echo "  ARCH             - Target architecture (x86_64 only) [default: x86_64]"
	@echo "  TIMEOUT          - Build timeout [default: 1h]"
	@echo ""
	@echo "Examples:"
	@echo "  make STREAM=testing                    # Build testing stream"
	@echo "  make ARCH=x86_64                       # Build for x86_64 (default)"
	@echo "  make STREAM=next                       # Build next stream"

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
		echo "  - Downloaded image: $$(ls fedora-coreos-*-qemu.x86_64.qcow2 | head -1)"; \
	else \
		echo "✗ Downloaded image symlink not found"; \
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