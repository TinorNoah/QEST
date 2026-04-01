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

# We list all native + modern packages that yay can install. 
# yay will fallback to pacman for official packages, and AUR for others.
ARCH_PACKAGES="zoxide zsh-autosuggestions bat fzf nushell starship direnv atuin chezmoi age helix zellij lazygit just python-moulti btop bottom viddy sysz yazi eza fd git-delta rclone broot s5cmd lnav jq yq ripgrep sd jless dasel choose visidata logdy-bin duf procs czkawka-cli dust gdu erdtree lazydocker gping doggo xh curl wget bandwhich termshark atac gitleaks asciinema tealdeer navi grex"

echo "Installing all requested tools via yay..."
if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY RUN] Would attempt to install: $ARCH_PACKAGES"
else
    if command -v yay &> /dev/null; then
        # shellcheck disable=SC2086
        yay -S --noconfirm $ARCH_PACKAGES || echo "Some packages failed to install. Continuing..."
    else
        # Fallback to pacman if yay is not available
        # shellcheck disable=SC2086
        execute_sudo pacman -S --noconfirm $ARCH_PACKAGES || echo "Some packages failed to install via pacman. Continuing..."
    fi
fi
