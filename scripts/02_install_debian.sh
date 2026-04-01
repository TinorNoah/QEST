#!/bin/bash
set -euo pipefail

echo "Updating packages and installing base dependencies (Debian/Ubuntu)..."

execute_sudo apt-get update
# PACKAGES variable is not quoted because we want it to split into separate words (e.g. "curl git zsh")
# shellcheck disable=SC2086
execute_sudo apt-get install -y $PACKAGES

echo "Installing native core tools..."
execute_sudo apt-get install -y zoxide zsh-autosuggestions bat fzf ripgrep fd-find jq
