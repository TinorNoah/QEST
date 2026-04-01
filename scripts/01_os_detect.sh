#!/bin/bash
set -euo pipefail

echo "Starting OS detection..."

# Detect macOS explicitly
if [[ "$(uname)" == "Darwin" ]]; then
    echo "Error: macOS is currently unsupported by this script."
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_LIKE=${ID_LIKE:-""}
else
    echo "Cannot determine OS from /etc/os-release. Exiting."
    exit 1
fi

echo "Detected OS: $OS / $OS_LIKE"

# Function to check if a string contains another
contains() {
    echo "$1" | grep -q "$2"
}
export -f contains

PACKAGES="curl git"

# Check if Zsh is installed
if ! command -v zsh &> /dev/null; then
    echo "Zsh is not found on your system."
    # Wait, in dry-run we might bypass prompting, but typically prompts are fine
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY RUN] Would prompt to install Zsh"
        PACKAGES="curl git zsh"
    else
        read -p "Would you like to install Zsh? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo "Zsh is required for this configuration. Exiting."
            exit 1
        fi
        echo "Will install Zsh..."
        PACKAGES="curl git zsh"
    fi
fi

export OS
export OS_LIKE
export PACKAGES
