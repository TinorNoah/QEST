#!/bin/bash
set -euo pipefail

echo "Updating packages and installing base dependencies (Arch/Manjaro)..."

# shellcheck disable=SC2086
execute_sudo pacman -Sy --noconfirm $PACKAGES

# Check for yay (AUR helper)
if ! command -v yay &> /dev/null; then
    echo "AUR helper 'yay' is not installed."
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY RUN] Would prompt to install yay and clone/build from AUR"
    else
        read -p "Would you like to install 'yay' to access the Arch User Repository (AUR)? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo -e "\e[31mWARNING: The AUR (Arch User Repository) contains user-produced content. Any use of the provided files is at your own risk.\e[0m"
            echo "Building yay from source..."
            execute_sudo pacman -S --needed --noconfirm base-devel git
            git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
            cd /tmp/yay-bin
            makepkg -si --noconfirm
            cd "$SCRIPT_DIR"
            rm -rf /tmp/yay-bin
        else
            echo "Skipping yay installation. Many packages will fail to install."
        fi
    fi
fi

echo "Installing all requested tools via yay..."
if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY RUN] Would attempt to install from manifests/arch_core.txt"
else
    # Load manifest into an array
    mapfile -t ARCH_PACKAGES_ARRAY < "$SCRIPT_DIR/manifests/arch_core.txt"
    # shellcheck disable=SC2145
    ARCH_PACKAGES="${ARCH_PACKAGES_ARRAY[@]}"

    if command -v yay &> /dev/null; then
        qest_spin "Installing 40+ modern tools via yay..." yay -S --noconfirm "${ARCH_PACKAGES_ARRAY[@]}" || qest_error "Some packages failed."
    else
        qest_spin "Installing 40+ modern tools via pacman..." execute_sudo pacman -S --noconfirm "${ARCH_PACKAGES_ARRAY[@]}" || qest_error "Some packages failed."
    fi
    qest_success "Arch package provisioning complete."
fi
