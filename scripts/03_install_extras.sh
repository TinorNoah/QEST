#!/bin/bash
set -euo pipefail

execute_git() {
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY RUN] git $*"
    else
        git "$@"
    fi
}

# Only prompt for Homebrew on Debian/Fedora based systems
if [[ "$OS" != "arch" && "$OS" != "manjaro" && "$OS_LIKE" != *"arch"* ]]; then
    echo "This script can install the remaining 30+ modern CLI tools via Homebrew."
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY RUN] Would prompt to install Homebrew and 30+ modern tools"
    else
        read -p "Would you like to install the remaining CLI tools using Homebrew? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            if ! command -v brew &> /dev/null; then
                echo "Installing Homebrew..."
                NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                # Set up brew environment for the current script session
                if [ -d "/home/linuxbrew/.linuxbrew" ]; then
                    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
                fi
            fi

            # Load brew manifest into an array
            mapfile -t BREW_PACKAGES_ARRAY < "$SCRIPT_DIR/manifests/brew_core.txt"

            echo "Installing ${#BREW_PACKAGES_ARRAY[@]} packages via Homebrew..."
            for pkg in "${BREW_PACKAGES_ARRAY[@]}"; do
                qest_spin "Brewing $pkg..." brew install "$pkg" || qest_error "Failed to install $pkg via Homebrew. Continuing..."
            done
            qest_success "Homebrew modern tools setup complete."
        else
            echo "Skipping modern CLI tools installation via Homebrew."
        fi
    fi
fi

# We only run starship script if we aren't using brew/arch for it
if ! command -v starship &> /dev/null; then
    echo "Installing Starship via curl..."
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY RUN] Would download and run starship install script from starship.rs"
    else
        qest_spin "Installing Starship theme engine..." sh -c 'curl -sS https://starship.rs/install.sh | sh -s -- -y' || qest_error "Starship install requires sudo or failed. Continuing..."
    fi
else
    echo "Starship is already installed."
fi

echo "Installing fzf-tab..."
if [ ! -d "$HOME/.zsh/fzf-tab" ]; then
    qest_spin "Cloning fzf-tab..." execute_git clone --depth 1 -- https://github.com/Aloxaf/fzf-tab.git "$HOME/.zsh/fzf-tab"
else
    echo "fzf-tab is already installed."
fi

echo "Installing fast-syntax-highlighting..."
if [ ! -d "$HOME/.zsh/fast-syntax-highlighting" ]; then
    qest_spin "Cloning fast-syntax-highlighting..." execute_git clone --depth 1 -- https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$HOME/.zsh/fast-syntax-highlighting"
else
    echo "fast-syntax-highlighting is already installed."
fi
