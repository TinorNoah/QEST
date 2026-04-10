#!/bin/bash
set -euo pipefail

ZSH_PATH=$(command -v zsh || true)
if [[ -z "$ZSH_PATH" ]]; then
    ZSH_PATH="/bin/zsh"
fi

if [ "$SHELL" != "$ZSH_PATH" ]; then
    qest_info "zsh is not your default shell."
    
    if [[ "$DRY_RUN" == "1" ]]; then
        qest_info "[DRY RUN] Would prompt and run 'chsh -s $ZSH_PATH'."
    else
        if qest_confirm "Would you like to make Zsh your default shell?" 1; then
            qest_info "Changing default shell to zsh."
            chsh -s "$ZSH_PATH" || qest_warn "Unable to change shell automatically. Run 'chsh -s $ZSH_PATH' manually, then log out and back in."
        else
            qest_info "Skipping default shell change."
        fi
    fi
fi
