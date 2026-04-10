#!/bin/bash
set -euo pipefail

qest_info "Applying shell configuration files."

# SCRIPT_DIR is exported by setup.sh

resolve_dotfiles_source() {
    local local_zshrc="$SCRIPT_DIR/.zshrc"
    local local_starship="$SCRIPT_DIR/starship.toml"

    DOTFILES_ZSHRC="$local_zshrc"
    DOTFILES_STARSHIP="$local_starship"

    if [[ -z "${QEST_DOTFILES_REPO:-}" ]] && [[ "${AUTO_YES:-0}" != "1" ]]; then
        if qest_confirm "Use a custom GitHub dotfiles repository?" 0; then
            read -r -p "Enter repo URL (example: https://github.com/you/dotfiles.git): " maybe_repo
            if [[ -n "${maybe_repo:-}" ]]; then
                QEST_DOTFILES_REPO="$maybe_repo"
                export QEST_DOTFILES_REPO
            fi
        fi
    fi

    if [[ -z "${QEST_DOTFILES_REPO:-}" ]]; then
        return 0
    fi
    if [[ "$DRY_RUN" == "1" ]]; then
        qest_info "[DRY RUN] Would pull dotfiles from: $QEST_DOTFILES_REPO"
        return 0
    fi

    local cache_dir="$HOME/.cache/qest/dotfiles"
    local repo_dir="$cache_dir/repo"
    mkdir -p "$cache_dir"

    if [[ -d "$repo_dir/.git" ]]; then
        qest_spin "Updating dotfiles repo..." run_with_retry git -C "$repo_dir" pull --ff-only || qest_warn "Failed to update dotfiles repo. Falling back to bundled configs."
    else
        qest_spin "Cloning dotfiles repo..." run_with_retry git clone --depth 1 "$QEST_DOTFILES_REPO" "$repo_dir" || qest_warn "Failed to clone dotfiles repo. Falling back to bundled configs."
    fi

    if [[ -f "$repo_dir/.zshrc" ]]; then
        DOTFILES_ZSHRC="$repo_dir/.zshrc"
    fi
    if [[ -f "$repo_dir/starship.toml" ]]; then
        DOTFILES_STARSHIP="$repo_dir/starship.toml"
    fi
}

backup_and_copy() {
    local src="$1"
    local dest="$2"
    local label="$3"
    local parent_dir
    parent_dir="$(dirname "$dest")"
    mkdir -p "$parent_dir"

    if [[ -f "$dest" ]]; then
        local timestamp backup_file
        timestamp=$(date +"%Y%m%d_%H%M%S")
        backup_file="${dest}.qest.bak.${timestamp}"
        mv "$dest" "$backup_file"
        qest_info "Backed up existing $label to $backup_file"
    fi

    cp "$src" "$dest"
    qest_success "Copied $label to $dest"
}

if [[ "$DRY_RUN" == "1" ]]; then
    qest_info "[DRY RUN] Would create $HOME/.config/zsh/ (for HISTFILE)."
    qest_info "[DRY RUN] Would copy .zshrc to $HOME/.zshrc."
    qest_info "[DRY RUN] Would copy starship.toml to $HOME/.config/starship.toml."
else
    resolve_dotfiles_source

    # Create the zsh config directory so HISTFILE can be written on first login.
    mkdir -p "$HOME/.config/zsh"
    qest_info "Ensured $HOME/.config/zsh exists (required for HISTFILE)."

    if [ -f "$DOTFILES_ZSHRC" ]; then
        backup_and_copy "$DOTFILES_ZSHRC" "$HOME/.zshrc" ".zshrc"
    else
        qest_error ".zshrc not found in configured source. Add .zshrc to your repo or rerun without custom dotfiles."
    fi

    if [ -f "$DOTFILES_STARSHIP" ]; then
        backup_and_copy "$DOTFILES_STARSHIP" "$HOME/.config/starship.toml" "starship.toml"
    else
        qest_error "starship.toml not found in configured source. Add starship.toml to your repo or rerun without custom dotfiles."
    fi
fi
