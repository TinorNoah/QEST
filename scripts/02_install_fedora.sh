#!/bin/bash
set -euo pipefail

echo "Updating packages and installing base dependencies (Fedora)..."

# shellcheck disable=SC2086
execute_sudo dnf install -y $PACKAGES

echo "Installing native core tools..."
execute_sudo dnf install -y zoxide zsh-autosuggestions bat fzf ripgrep fd-find jq
