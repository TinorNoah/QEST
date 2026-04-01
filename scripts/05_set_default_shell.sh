#!/bin/bash
set -euo pipefail

ZSH_PATH=$(command -v zsh || true)
if [[ -z "$ZSH_PATH" ]]; then
    ZSH_PATH="/bin/zsh"
fi

if [ "$SHELL" != "$ZSH_PATH" ]; then
    echo "Zsh is not your default shell."
    
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY RUN] Would prompt and run 'chsh -s $ZSH_PATH'"
    else
        read -p "Would you like to make Zsh your default shell? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "Changing default shell to zsh..."
            chsh -s "$ZSH_PATH" || echo "Please run 'chsh -s $ZSH_PATH' manually to change your shell."
        else
            echo "Skipping default shell change."
        fi
    fi
fi
