#!/bin/bash
set -euo pipefail

qest_info "Updating package indexes and installing base dependencies (Fedora)."

qest_spin "Updating dnf repositories..." run_with_retry execute_sudo dnf update -y
# PACKAGES variable is exported from 01_os_detect.sh
# shellcheck disable=SC2086
qest_spin "Installing base essentials..." run_with_retry execute_sudo dnf install -y $PACKAGES

manifest_path=""
if [[ "${INSTALL_EXTRAS:-0}" == "1" ]]; then
    manifest_path="$SCRIPT_DIR/manifests/fedora_core.txt"
elif [[ "${INSTALL_ESSENTIALS:-0}" == "1" ]]; then
    manifest_path="$SCRIPT_DIR/manifests/profiles/fedora/essentials.txt"
elif [[ "${INSTALL_SHELL_STACK:-0}" == "1" ]]; then
    manifest_path="$SCRIPT_DIR/manifests/profiles/fedora/shell.txt"
fi

if [[ -n "$manifest_path" ]]; then
    qest_info "Installing native tools from manifest: $manifest_path"
    FEDORA_PACKAGES_ARRAY=()
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && FEDORA_PACKAGES_ARRAY+=("$pkg")
    done < "$manifest_path"
    if [[ "${#FEDORA_PACKAGES_ARRAY[@]}" -gt 0 ]]; then
        qest_spin "Installing ${#FEDORA_PACKAGES_ARRAY[@]} native tools..." run_with_retry execute_sudo dnf install -y "${FEDORA_PACKAGES_ARRAY[@]}"
    fi
fi

qest_success "Fedora package provisioning complete."
