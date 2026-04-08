#!/bin/bash
set -euo pipefail

# UI helper functions. Uses `gum` when available and safe.

is_interactive_shell() {
    [[ -t 0 && -t 1 ]]
}

should_use_gum() {
    command -v gum &> /dev/null && is_interactive_shell
}

install_gum_if_possible() {
    if [[ "${QEST_NO_GUM:-0}" == "1" ]]; then
        return 0
    fi
    if ! is_interactive_shell; then
        return 0
    fi
    if command -v gum &> /dev/null; then
        return 0
    fi
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY RUN] Would attempt to install 'gum'"
        return 0
    fi

    echo "Attempting optional Gum install for improved TUI..."
    if [[ "$OS" == "arch" || "$OS" == "manjaro" ]] || contains "$OS_LIKE" "arch"; then
        execute_sudo pacman -S --noconfirm gum || true
        return 0
    fi
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]] || contains "$OS_LIKE" "ubuntu" || contains "$OS_LIKE" "debian"; then
        execute_sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://repo.charm.sh/apt/gpg.key | execute_sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg || true
        echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | execute_sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
        execute_sudo apt-get update -y || true
        execute_sudo apt-get install -y gum || true
        return 0
    fi
    if [[ "$OS" == "fedora" ]] || contains "$OS_LIKE" "fedora"; then
        echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | execute_sudo tee /etc/yum.repos.d/charm.repo > /dev/null
        execute_sudo dnf install -y gum || true
    fi
}

install_gum_if_possible

# Fallback UI Functions

qest_success() {
    if should_use_gum && [[ "$DRY_RUN" != "1" ]]; then
        gum format "# ✨ $1"
    else
        echo -e "\e[32m✨ $1\e[0m"
    fi
}

qest_error() {
    if should_use_gum && [[ "$DRY_RUN" != "1" ]]; then
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
    elif should_use_gum; then
        gum spin --spinner dot --title "$title" -- "$@" >> /tmp/qest-install.log 2>&1
    else
        echo "$title"
        "$@" >> /tmp/qest-install.log 2>&1
    fi
}

qest_confirm() {
    local prompt="$1"
    local default_yes="${2:-1}"
    if [[ "${AUTO_YES:-0}" == "1" ]]; then
        return 0
    fi
    if ! is_interactive_shell; then
        [[ "$default_yes" == "1" ]]
        return $?
    fi
    if should_use_gum; then
        if [[ "$default_yes" == "1" ]]; then
            gum confirm "$prompt"
            return $?
        fi
        gum confirm --default=false "$prompt"
        return $?
    fi

    local suffix="[Y/n]"
    if [[ "$default_yes" != "1" ]]; then
        suffix="[y/N]"
    fi
    read -r -p "$prompt $suffix " REPLY
    if [[ -z "${REPLY:-}" ]]; then
        [[ "$default_yes" == "1" ]]
        return $?
    fi
    [[ "$REPLY" =~ ^[Yy]$ ]]
}

qest_pick_one() {
    local prompt="$1"
    shift
    local options=("$@")
    if ! is_interactive_shell; then
        echo "${options[0]}"
        return 0
    fi
    if should_use_gum; then
        gum choose --header "$prompt" "${options[@]}"
        return 0
    fi
    echo "$prompt"
    local idx=1
    for option in "${options[@]}"; do
        echo "  $idx) $option"
        idx=$((idx + 1))
    done
    read -r -p "Select an option [1-${#options[@]}]: " selected_idx
    if [[ "$selected_idx" =~ ^[0-9]+$ ]] && (( selected_idx >= 1 && selected_idx <= ${#options[@]} )); then
        echo "${options[$((selected_idx - 1))]}"
        return 0
    fi
    echo "${options[0]}"
}

qest_pick_many() {
    local prompt="$1"
    shift
    local options=("$@")
    if ! is_interactive_shell; then
        if [[ "${AUTO_YES:-0}" == "1" ]]; then
            printf '%s\n' "${options[@]}"
        fi
        return 0
    fi
    if should_use_gum; then
        gum choose --no-limit --header "$prompt" "${options[@]}"
        return 0
    fi
    echo "$prompt"
    local picked=()
    for option in "${options[@]}"; do
        if qest_confirm "Include '$option'?" 0; then
            picked+=("$option")
        fi
    done
    printf '%s\n' "${picked[@]}"
}

export -f qest_success qest_error qest_spin qest_confirm qest_pick_one qest_pick_many should_use_gum
