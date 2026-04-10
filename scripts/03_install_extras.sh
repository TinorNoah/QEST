#!/bin/bash
set -euo pipefail

execute_git() {
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY RUN] git $*"
    else
        run_with_retry git "$@"
    fi
}

# Install extended toolset only when explicitly requested.
if [[ "${INSTALL_EXTRAS:-0}" == "1" ]] && [[ "$OS" != "arch" && "$OS" != "manjaro" && "$OS_LIKE" != *"arch"* && "$OS" != "macos" ]]; then
    qest_info "This profile can install the extended CLI bundle via Homebrew."
    if [[ "$DRY_RUN" == "1" ]]; then
        qest_info "[DRY RUN] Would prompt to install Homebrew and the extended tool bundle."
    else
        if qest_confirm "Install the extended CLI bundle with Homebrew?" 1; then
            if ! command -v brew &> /dev/null; then
                qest_info "Installing Homebrew."
                installer_file="/tmp/qest-brew-install.sh"
                run_with_retry curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer_file"
                NONINTERACTIVE=1 run_with_retry /bin/bash "$installer_file"
                # Set up brew environment for the current script session
                if [ -d "/home/linuxbrew/.linuxbrew" ]; then
                    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
                fi
                if [[ "$OS" == "macos" ]] && command -v brew &> /dev/null; then
                    eval "$("$(command -v brew)" shellenv)"
                fi
            fi

            # Load brew manifest into an array
            BREW_PACKAGES_ARRAY=()
            while IFS= read -r pkg; do
                [[ -n "$pkg" ]] && BREW_PACKAGES_ARRAY+=("$pkg")
            done < "$SCRIPT_DIR/manifests/brew_core.txt"

            qest_info "Installing ${#BREW_PACKAGES_ARRAY[@]} packages via Homebrew."
            qest_spin "Brewing tool bundle..." run_with_retry brew install "${BREW_PACKAGES_ARRAY[@]}" || qest_warn "Some Homebrew packages failed. Review /tmp/qest-install.log and install missing packages manually."
            qest_success "Homebrew modern tools setup completed."
        else
            qest_info "Skipping extended CLI bundle installation."
        fi
    fi
fi

# Install shell stack components when requested by selected profile.
if [[ "${INSTALL_SHELL_STACK:-0}" == "1" ]]; then
    if ! command -v starship &> /dev/null; then
        qest_info "Installing Starship via curl."
        if [[ "$DRY_RUN" == "1" ]]; then
            qest_info "[DRY RUN] Would download and run the Starship install script."
        else
            qest_spin "Installing Starship theme engine..." sh -c 'curl -sS https://starship.rs/install.sh | sh -s -- -y' || qest_warn "Starship install failed. Run the installer manually from https://starship.rs/guide/ and retry."
        fi
    else
        qest_info "Starship is already installed."
    fi

    qest_info "Installing fzf-tab."
    if [ ! -d "$HOME/.zsh/fzf-tab" ]; then
        qest_spin "Cloning fzf-tab..." execute_git clone --depth 1 -- https://github.com/Aloxaf/fzf-tab.git "$HOME/.zsh/fzf-tab"
    else
        qest_info "fzf-tab is already installed."
    fi

    qest_info "Installing fast-syntax-highlighting."
    if [ ! -d "$HOME/.zsh/fast-syntax-highlighting" ]; then
        qest_spin "Cloning fast-syntax-highlighting..." execute_git clone --depth 1 -- https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$HOME/.zsh/fast-syntax-highlighting"
    else
        qest_info "fast-syntax-highlighting is already installed."
    fi
fi
