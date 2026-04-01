#!/bin/bash
set -euo pipefail

echo "Updating packages and installing base dependencies (Fedora)..."

qest_spin "Updating dnf repositories..." execute_sudo dnf update -y
# PACKAGES variable is exported from 01_os_detect.sh
# shellcheck disable=SC2086
qest_spin "Installing base essentials..." execute_sudo dnf install -y $PACKAGES

echo "Installing native core tools..."
mapfile -t FEDORA_PACKAGES_ARRAY < "$SCRIPT_DIR/manifests/fedora_core.txt"

qest_spin "Installing ${#FEDORA_PACKAGES_ARRAY[@]} core native tools..." execute_sudo dnf install -y "${FEDORA_PACKAGES_ARRAY[@]}"
qest_success "Fedora core package provisioning complete."
