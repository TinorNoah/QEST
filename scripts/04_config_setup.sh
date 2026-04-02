#!/bin/bash
set -euo pipefail

echo "Placing config files..."

# SCRIPT_DIR is exported by setup.sh

if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY RUN] Would create $HOME/.config/zsh/ (for HISTFILE)"
    echo "[DRY RUN] Would copy .zshrc to $HOME/.zshrc"
    echo "[DRY RUN] Would copy starship.toml to $HOME/.config/starship.toml"
else
    # Create the zsh config directory so HISTFILE can be written on first login.
    mkdir -p "$HOME/.config/zsh"
    echo "Ensured $HOME/.config/zsh exists (required for HISTFILE)"

    if [ -f "$SCRIPT_DIR/.zshrc" ]; then
        # Automated Rollback specific to user request
        if [ -f "$HOME/.zshrc" ]; then
            TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
            BACKUP_FILE="$HOME/.zshrc.qest.bak.$TIMESTAMP"
            mv "$HOME/.zshrc" "$BACKUP_FILE"
            echo "Backed up existing .zshrc to $BACKUP_FILE"
        fi

        cp "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
        echo "Copied .zshrc to $HOME/.zshrc"
    else
        echo "Error: .zshrc not found in $SCRIPT_DIR."
    fi

    if [ -f "$SCRIPT_DIR/starship.toml" ]; then
        mkdir -p "$HOME/.config"
        cp "$SCRIPT_DIR/starship.toml" "$HOME/.config/starship.toml"
        echo "Copied starship.toml to $HOME/.config/starship.toml"
    else
        echo "Error: starship.toml not found in $SCRIPT_DIR."
    fi
fi
