#!/bin/bash
set -euo pipefail

# UI Helper functions. Uses `gum` if available, falls back to standard echoing gracefully.

# Attempt to quickly install gum natively if missing
if ! command -v gum &> /dev/null; then
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY RUN] Would attempt to install 'gum'"
    else
        echo "Installing Charmbracelet Gum for a better UI experience..."
        if [[ "$OS" == "arch" || "$OS" == "manjaro" ]] || contains "$OS_LIKE" "arch"; then
            execute_sudo pacman -S --noconfirm gum || true
        elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]] || contains "$OS_LIKE" "ubuntu" || contains "$OS_LIKE" "debian"; then
            execute_sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://repo.charm.sh/apt/gpg.key | execute_sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg || true
            echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | execute_sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
            execute_sudo apt-get update -y || true
            execute_sudo apt-get install -y gum || true
        elif [[ "$OS" == "fedora" ]] || contains "$OS_LIKE" "fedora"; then
            echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | execute_sudo tee /etc/yum.repos.d/charm.repo > /dev/null
            execute_sudo dnf install -y gum || true
        fi
    fi
fi

# Fallback UI Functions

qest_success() {
    if command -v gum &> /dev/null && [[ "$DRY_RUN" != "1" ]]; then
        gum format "# ✨ $1"
    else
        echo -e "\e[32m✨ $1\e[0m"
    fi
}

qest_error() {
    if command -v gum &> /dev/null && [[ "$DRY_RUN" != "1" ]]; then
        gum format "# ❌ **ERROR:** $1"
    else
        echo -e "\e[31m❌ ERROR: $1\e[0m"
    fi
}

qest_spin() {
    local title="$1"
    shift
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY RUN] Would spin on: $title -> COMMAND: $*"
    elif command -v gum &> /dev/null && [ -t 1 ]; then
        gum spin --spinner dot --title "$title" -- "$@" >> /tmp/qest-install.log 2>&1
    else
        echo "$title"
        "$@" >> /tmp/qest-install.log 2>&1
    fi
}

export -f qest_success qest_error qest_spin
