# Requirements Document

## Introduction

This feature adds support for Red Hat Enterprise Linux CoreOS (RHCOS) and Fedora CoreOS to the packer-maas project. CoreOS is a container-optimized operating system that uses Ignition for configuration instead of traditional kickstart files. This addition will provide users with immutable, container-focused OS options for MAAS deployments.

## Requirements

### Requirement 1

**User Story:** As a MAAS administrator, I want to build CoreOS images using packer-maas, so that I can deploy container-optimized operating systems through MAAS.

#### Acceptance Criteria

1. WHEN a user runs the CoreOS packer template THEN the system SHALL create a MAAS-compatible CoreOS image
2. WHEN the build process completes THEN the system SHALL output a compressed tar file suitable for MAAS upload
3. IF the user specifies a CoreOS stream (stable/testing/next) THEN the system SHALL use that specific stream version
4. WHEN building the image THEN the system SHALL support both AMD64 and ARM64 architectures

### Requirement 2

**User Story:** As a system administrator, I want CoreOS images to work with MAAS networking and storage configuration, so that deployed systems integrate properly with my infrastructure.

#### Acceptance Criteria

1. WHEN a CoreOS system deploys through MAAS THEN the system SHALL support MAAS-managed networking configuration
2. WHEN a CoreOS system deploys through MAAS THEN the system SHALL support MAAS storage configuration via curtin
3. WHEN the CoreOS system boots THEN the system SHALL enable cloud-init compatibility for MAAS integration
4. IF MAAS provides network configuration THEN CoreOS SHALL apply the configuration correctly

### Requirement 3

**User Story:** As a developer, I want to configure CoreOS systems using Ignition files, so that I can customize the OS for my specific use case while maintaining the immutable OS benefits.

#### Acceptance Criteria

1. WHEN building a CoreOS image THEN the system SHALL accept custom Ignition configuration files
2. WHEN the Ignition configuration is provided THEN the system SHALL validate the configuration syntax
3. IF no custom Ignition config is provided THEN the system SHALL use a default MAAS-compatible configuration
4. WHEN the CoreOS system first boots THEN Ignition SHALL apply the configuration successfully

### Requirement 4

**User Story:** As a MAAS user, I want to authenticate to deployed CoreOS systems securely, so that I can manage the systems without default passwords.

#### Acceptance Criteria

1. WHEN a CoreOS system deploys THEN the system SHALL support SSH key-based authentication for the core user
2. WHEN no SSH keys are configured THEN the system SHALL not allow password-based root access
3. IF SSH keys are provided through MAAS cloud-init THEN the system SHALL configure them for the core user
4. WHEN the system is deployed THEN it SHALL disable any default authentication credentials

### Requirement 5

**User Story:** As a platform engineer, I want CoreOS images to follow the same patterns as other packer-maas templates, so that the build process is consistent and maintainable.

#### Acceptance Criteria

1. WHEN examining the CoreOS template directory THEN it SHALL follow the same structure as other OS templates
2. WHEN building CoreOS images THEN the process SHALL use the same Makefile patterns as other templates
3. WHEN documenting CoreOS support THEN it SHALL include README.md with build instructions and requirements
4. IF the user runs validation commands THEN the CoreOS template SHALL pass packer validation checks

### Requirement 6

**User Story:** As a DevOps engineer, I want to install additional packages on CoreOS images when needed, so that I can customize systems for specific workloads while respecting the immutable filesystem.

#### Acceptance Criteria

1. WHEN custom packages are required THEN the system SHALL support layered image creation or systemd unit installation
2. IF traditional package installation is requested THEN the system SHALL provide guidance on CoreOS-appropriate alternatives
3. WHEN container-based services are needed THEN the system SHALL support systemd unit configuration for containers
4. WHEN the image builds THEN it SHALL maintain CoreOS update capabilities and immutable filesystem benefits