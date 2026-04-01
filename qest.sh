#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR

# Parse arguments
DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    echo "==== DRY-RUN MODE: System-modifying commands will be mocked ===="
fi
export DRY_RUN

# Utility function to handle dry-runs seamlessly for sudo
execute_sudo() {
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY RUN] sudo $*"
    else
        sudo "$@"
    fi
}
export -f execute_sudo

# Source OS detection
source "$SCRIPT_DIR/scripts/01_os_detect.sh"

# Source UI helper functions
source "$SCRIPT_DIR/scripts/00_init_ui.sh"

# Clean up any previous log
if [[ "$DRY_RUN" != "1" ]]; then
    rm -f /tmp/qest-install.log
    touch /tmp/qest-install.log
fi

# Install distro specific packages
qest_success "Initiating core package installation..."
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]] || contains "$OS_LIKE" "ubuntu" || contains "$OS_LIKE" "debian"; then
    source "$SCRIPT_DIR/scripts/02_install_debian.sh"
elif [[ "$OS" == "fedora" ]] || contains "$OS_LIKE" "fedora"; then
    source "$SCRIPT_DIR/scripts/02_install_fedora.sh"
elif [[ "$OS" == "arch" || "$OS" == "manjaro" ]] || contains "$OS_LIKE" "arch"; then
    source "$SCRIPT_DIR/scripts/02_install_arch.sh"
else
    echo "Unsupported Linux OS: $OS. Exiting."
    exit 1
fi

source "$SCRIPT_DIR/scripts/03_install_extras.sh"
source "$SCRIPT_DIR/scripts/04_config_setup.sh"
source "$SCRIPT_DIR/scripts/05_set_default_shell.sh"

qest_success "Setup is strictly complete!"
if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY RUN] Finished mocked setup."
else
    echo "Please log out and log back in, or run 'zsh'"
    echo "to start using your beautifully empowered environment."
fi
