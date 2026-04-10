#!/bin/bash
set -euo pipefail

qest_info "Syncing packages and installing base dependencies (Arch/Manjaro)."

# shellcheck disable=SC2086
qest_spin "Syncing pacman repositories..." run_with_retry execute_sudo pacman -Sy --noconfirm $PACKAGES

manifest_path=""
if [[ "${INSTALL_EXTRAS:-0}" == "1" ]]; then
    manifest_path="$SCRIPT_DIR/manifests/arch_core.txt"
elif [[ "${INSTALL_ESSENTIALS:-0}" == "1" ]]; then
    manifest_path="$SCRIPT_DIR/manifests/profiles/arch/essentials.txt"
elif [[ "${INSTALL_SHELL_STACK:-0}" == "1" ]]; then
    manifest_path="$SCRIPT_DIR/manifests/profiles/arch/shell.txt"
fi

# Check for yay (AUR helper)
if [[ "${INSTALL_EXTRAS:-0}" == "1" ]] && ! command -v yay &> /dev/null; then
    qest_warn "AUR helper 'yay' is not installed."
    if [[ "$DRY_RUN" == "1" ]]; then
        qest_info "[DRY RUN] Would prompt to install yay and build it from AUR."
    else
        if qest_confirm "Install 'yay' for Arch User Repository access?" 1; then
            qest_warn "AUR packages are user-maintained content. Review package details before continuing."
            qest_info "Building yay from source."
            execute_sudo pacman -S --needed --noconfirm base-devel git
            run_with_retry git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
            cd /tmp/yay-bin
            makepkg -si --noconfirm
            cd "$SCRIPT_DIR"
            rm -rf /tmp/yay-bin
        else
            qest_warn "Skipping yay installation. Some selected packages may fail to install."
        fi
    fi
fi

if [[ -z "$manifest_path" ]]; then
    qest_success "No Arch package bundle selected for this profile."
    return 0
fi

qest_info "Installing native tools from manifest: $manifest_path"
if [[ "$DRY_RUN" == "1" ]]; then
    qest_info "[DRY RUN] Would attempt to install from $manifest_path"
    return 0
fi

ARCH_PACKAGES_ARRAY=()
while IFS= read -r pkg; do
    [[ -n "$pkg" ]] && ARCH_PACKAGES_ARRAY+=("$pkg")
done < "$manifest_path"

if [[ "${#ARCH_PACKAGES_ARRAY[@]}" -eq 0 ]]; then
    qest_success "No packages to install for selected Arch profile."
    return 0
fi

if [[ "${INSTALL_EXTRAS:-0}" == "1" ]] && command -v yay &> /dev/null; then
    qest_spin "Installing ${#ARCH_PACKAGES_ARRAY[@]} tools via yay..." run_with_retry yay -S --noconfirm "${ARCH_PACKAGES_ARRAY[@]}" || qest_warn "Some packages failed. Review output in /tmp/qest-install.log and retry missing packages manually."
else
    qest_spin "Installing ${#ARCH_PACKAGES_ARRAY[@]} tools via pacman..." run_with_retry execute_sudo pacman -S --noconfirm "${ARCH_PACKAGES_ARRAY[@]}" || qest_warn "Some packages failed. Review output in /tmp/qest-install.log and retry missing packages manually."
fi
qest_success "Arch package provisioning complete."
