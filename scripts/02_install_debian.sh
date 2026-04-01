#!/bin/bash
set -euo pipefail

echo "Updating packages and installing base dependencies (Debian/Ubuntu)..."

qest_spin "Updating apt repositories..." execute_sudo apt-get update

# PACKAGES variable is exported from 01_os_detect.sh
# shellcheck disable=SC2086
qest_spin "Installing base essentials..." execute_sudo apt-get install -y $PACKAGES

echo "Installing native core tools..."
mapfile -t DEBIAN_PACKAGES_ARRAY < "$SCRIPT_DIR/manifests/debian_core.txt"

qest_spin "Installing ${#DEBIAN_PACKAGES_ARRAY[@]} core native tools..." execute_sudo apt-get install -y "${DEBIAN_PACKAGES_ARRAY[@]}"
qest_success "Debian core package provisioning complete."
