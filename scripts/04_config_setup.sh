#!/bin/bash
set -euo pipefail

echo "Placing config files..."

# SCRIPT_DIR is exported by setup.sh

if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY RUN] Would copy .zshrc to $HOME/.zshrc"
    echo "[DRY RUN] Would copy starship.toml to $HOME/.config/starship.toml"
else
    if [ -f "$SCRIPT_DIR/.zshrc" ]; then
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
