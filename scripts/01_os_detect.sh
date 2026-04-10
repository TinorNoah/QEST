#!/bin/bash
set -euo pipefail

qest_bootstrap_log() {
    local level="$1"
    local message="$2"
    echo "[${level}] ${message}"
}

qest_bootstrap_log "INFO" "Starting OS detection."

# Function to check if a string contains another
contains() {
    echo "$1" | grep -q "$2"
}
export -f contains

# Detect macOS explicitly
if [[ "$(uname)" == "Darwin" ]]; then
    OS="macos"
    OS_LIKE="darwin"
    PACKAGES="curl git"

    # zsh is bundled on macOS, but keep the guard for custom/minimal setups.
    if ! command -v zsh &> /dev/null; then
        PACKAGES="curl git zsh"
    fi

    qest_bootstrap_log "INFO" "Detected OS: $OS / $OS_LIKE"
    export OS
    export OS_LIKE
    export PACKAGES
    return 0
fi

# Detect OS
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS=$ID
    OS_LIKE=${ID_LIKE:-""}
else
    qest_bootstrap_log "ERROR" "Cannot determine OS from /etc/os-release. Exiting."
    exit 1
fi

qest_bootstrap_log "INFO" "Detected OS: $OS / $OS_LIKE"

PACKAGES="curl git"

# Check if Zsh is installed
if ! command -v zsh &> /dev/null; then
    qest_bootstrap_log "WARN" "zsh is not found on your system."
    # Wait, in dry-run we might bypass prompting, but typically prompts are fine
    if [[ "$DRY_RUN" == "1" || "${AUTO_YES:-0}" == "1" ]]; then
        qest_bootstrap_log "INFO" "[DRY RUN] Would prompt to install zsh."
        PACKAGES="curl git zsh"
    else
        read -p "Would you like to install Zsh? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            qest_bootstrap_log "ERROR" "zsh is required for this configuration. Install zsh and re-run qest."
            exit 1
        fi
        qest_bootstrap_log "INFO" "Will install zsh."
        PACKAGES="curl git zsh"
    fi
fi

export OS
export OS_LIKE
export PACKAGES
