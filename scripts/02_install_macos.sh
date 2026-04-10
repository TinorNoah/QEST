#!/bin/bash
set -euo pipefail

qest_info "Preparing package installation for macOS."

if ! command -v brew &> /dev/null; then
    qest_warn "Homebrew is required on macOS."
    if [[ "$DRY_RUN" == "1" ]]; then
        qest_info "[DRY RUN] Would install Homebrew from brew.sh."
    else
        if ! qest_confirm "Install Homebrew now?" 1; then
            qest_error "Homebrew is required to continue on macOS. Install Homebrew and re-run qest."
            exit 1
        fi
        installer_file="/tmp/qest-brew-install.sh"
        run_with_retry curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer_file"
        NONINTERACTIVE=1 run_with_retry /bin/bash "$installer_file"
    fi
fi

if command -v brew &> /dev/null; then
    eval "$("$(command -v brew)" shellenv)"
fi

manifest_path=""
if [[ "${INSTALL_EXTRAS:-0}" == "1" ]]; then
    manifest_path="$SCRIPT_DIR/manifests/brew_core.txt"
elif [[ "${INSTALL_ESSENTIALS:-0}" == "1" ]]; then
    manifest_path="$SCRIPT_DIR/manifests/profiles/macos/essentials.txt"
elif [[ "${INSTALL_SHELL_STACK:-0}" == "1" ]]; then
    manifest_path="$SCRIPT_DIR/manifests/profiles/macos/shell.txt"
fi

if [[ -z "$manifest_path" ]]; then
    qest_success "No macOS package bundle selected for this profile."
    return 0
fi

if [[ "$DRY_RUN" == "1" ]]; then
    qest_info "[DRY RUN] Would install packages from $manifest_path"
    return 0
fi

MACOS_PACKAGES_ARRAY=()
while IFS= read -r pkg; do
    [[ -n "$pkg" ]] && MACOS_PACKAGES_ARRAY+=("$pkg")
done < "$manifest_path"
if [[ "${#MACOS_PACKAGES_ARRAY[@]}" -eq 0 ]]; then
    qest_success "No packages listed for selected macOS profile."
    return 0
fi

qest_spin "Installing ${#MACOS_PACKAGES_ARRAY[@]} packages via Homebrew..." run_with_retry brew install "${MACOS_PACKAGES_ARRAY[@]}" || qest_warn "Some macOS packages failed to install. Review /tmp/qest-install.log and retry missing packages."
qest_success "macOS package provisioning complete."
