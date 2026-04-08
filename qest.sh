#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR

DRY_RUN=0
AUTO_YES=0
PROFILE="${QEST_PROFILE:-}"
QEST_NO_GUM="${QEST_NO_GUM:-0}"

show_help() {
    cat <<'EOF'
QEST — Quite Effective Setup Tool

Usage:
  ./qest.sh [options]

Options:
  --dry-run              Preview commands without mutating the system
  --yes, -y              Non-interactive mode, assume yes for prompts
  --profile <name>       full | shell | essentials | custom
  --dotfiles-repo <url>  Git repository containing .zshrc and starship.toml
  --no-gum               Disable optional Gum installation and TUI
  --help                 Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --yes|-y)
            AUTO_YES=1
            shift
            ;;
        --profile)
            if [[ $# -lt 2 ]]; then
                echo "--profile requires a value."
                exit 1
            fi
            PROFILE="${2:-}"
            shift 2
            ;;
        --dotfiles-repo)
            if [[ $# -lt 2 ]]; then
                echo "--dotfiles-repo requires a value."
                exit 1
            fi
            export QEST_DOTFILES_REPO="${2:-}"
            shift 2
            ;;
        --no-gum)
            QEST_NO_GUM=1
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

if [[ "$DRY_RUN" == "1" ]]; then
    echo "==== DRY-RUN MODE: System-modifying commands will be mocked ===="
fi

export DRY_RUN
export AUTO_YES
export PROFILE
export QEST_NO_GUM

# Utility function to handle dry-runs seamlessly for sudo
execute_sudo() {
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY RUN] sudo $*"
    else
        sudo "$@"
    fi
}
export -f execute_sudo

run_with_retry() {
    local retries="${QEST_RETRIES:-3}"
    local delay="${QEST_RETRY_DELAY:-2}"
    local attempt=1
    while true; do
        if "$@"; then
            return 0
        fi
        if (( attempt >= retries )); then
            return 1
        fi
        sleep "$delay"
        attempt=$((attempt + 1))
    done
}
export -f run_with_retry

preflight_checks() {
    if ! command -v bash &>/dev/null; then
        echo "bash is required."
        exit 1
    fi
    if ! command -v curl &>/dev/null; then
        echo "curl is required."
        exit 1
    fi
    if [[ "$DRY_RUN" != "1" ]]; then
        mkdir -p "$HOME/.config" "$HOME/.cache/qest" || {
            echo "Unable to write required config/cache directories in $HOME."
            exit 1
        }
        if ! run_with_retry curl -fsS --max-time 10 https://github.com &>/dev/null; then
            echo "Network check failed. Please verify internet connectivity."
            exit 1
        fi
        if [[ "${OS:-}" != "macos" ]]; then
            if ! sudo -n true &>/dev/null; then
                echo "sudo privileges are required. You may be prompted now."
                sudo -v || {
                    echo "Unable to acquire sudo credentials."
                    exit 1
                }
            fi
        fi
    fi
}

# Source OS detection
source "$SCRIPT_DIR/scripts/01_os_detect.sh"

preflight_checks

# Source UI helper functions
source "$SCRIPT_DIR/scripts/00_init_ui.sh"
source "$SCRIPT_DIR/scripts/06_profile_menu.sh"

qest_choose_profile_if_needed

# Clean up any previous log
if [[ "$DRY_RUN" != "1" ]]; then
    rm -f /tmp/qest-install.log
    touch /tmp/qest-install.log
fi

# Install distro specific packages
qest_success "Initiating core package installation..."
if [[ "${INSTALL_SHELL_STACK:-0}" == "1" || "${INSTALL_ESSENTIALS:-0}" == "1" || "${INSTALL_EXTRAS:-0}" == "1" ]]; then
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]] || contains "$OS_LIKE" "ubuntu" || contains "$OS_LIKE" "debian"; then
        source "$SCRIPT_DIR/scripts/02_install_debian.sh"
    elif [[ "$OS" == "fedora" ]] || contains "$OS_LIKE" "fedora"; then
        source "$SCRIPT_DIR/scripts/02_install_fedora.sh"
    elif [[ "$OS" == "arch" || "$OS" == "manjaro" ]] || contains "$OS_LIKE" "arch"; then
        source "$SCRIPT_DIR/scripts/02_install_arch.sh"
    elif [[ "$OS" == "macos" ]]; then
        source "$SCRIPT_DIR/scripts/02_install_macos.sh"
    else
        echo "Unsupported OS: $OS. Exiting."
        exit 1
    fi
else
    echo "Skipping package installation phase for selected profile."
fi

if [[ "${INSTALL_EXTRAS:-0}" == "1" || "${INSTALL_SHELL_STACK:-0}" == "1" ]]; then
    source "$SCRIPT_DIR/scripts/03_install_extras.sh"
else
    echo "Skipping extras and shell-stack plugins installation."
fi

if [[ "${INSTALL_CONFIG:-0}" == "1" ]]; then
    source "$SCRIPT_DIR/scripts/04_config_setup.sh"
else
    echo "Skipping dotfiles configuration."
fi

if [[ "${INSTALL_DEFAULT_SHELL:-0}" == "1" ]]; then
    source "$SCRIPT_DIR/scripts/05_set_default_shell.sh"
else
    echo "Skipping default shell change."
fi

qest_success "Setup is strictly complete!"
if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY RUN] Finished mocked setup."
else
    echo "Please log out and log back in, or run 'zsh'"
    echo "to start using your beautifully empowered environment."
fi
