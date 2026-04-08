#!/bin/bash
set -euo pipefail

qest_apply_profile() {
    case "$PROFILE" in
        full)
            INSTALL_SHELL_STACK=1
            INSTALL_ESSENTIALS=1
            INSTALL_EXTRAS=1
            INSTALL_CONFIG=1
            INSTALL_DEFAULT_SHELL=1
            ;;
        shell)
            INSTALL_SHELL_STACK=1
            INSTALL_ESSENTIALS=0
            INSTALL_EXTRAS=0
            INSTALL_CONFIG=1
            INSTALL_DEFAULT_SHELL=1
            ;;
        essentials)
            INSTALL_SHELL_STACK=1
            INSTALL_ESSENTIALS=1
            INSTALL_EXTRAS=0
            INSTALL_CONFIG=1
            INSTALL_DEFAULT_SHELL=1
            ;;
        custom)
            local selections=()
            while IFS= read -r selected_line; do
                [[ -n "$selected_line" ]] && selections+=("$selected_line")
            done < <(qest_pick_many \
                "Pick what to install" \
                "Shell stack (zsh + starship + plugins)" \
                "Essentials CLI bundle (bat, rg, fd, eza, btop, etc.)" \
                "Extended extras bundle (full modern toolkit)" \
                "Apply dotfiles (.zshrc + starship.toml)" \
                "Set default shell to zsh")

            INSTALL_SHELL_STACK=0
            INSTALL_ESSENTIALS=0
            INSTALL_EXTRAS=0
            INSTALL_CONFIG=0
            INSTALL_DEFAULT_SHELL=0

            for selected in "${selections[@]}"; do
                case "$selected" in
                    "Shell stack (zsh + starship + plugins)")
                        INSTALL_SHELL_STACK=1
                        ;;
                    "Essentials CLI bundle (bat, rg, fd, eza, btop, etc.)")
                        INSTALL_ESSENTIALS=1
                        ;;
                    "Extended extras bundle (full modern toolkit)")
                        INSTALL_EXTRAS=1
                        ;;
                    "Apply dotfiles (.zshrc + starship.toml)")
                        INSTALL_CONFIG=1
                        ;;
                    "Set default shell to zsh")
                        INSTALL_DEFAULT_SHELL=1
                        ;;
                esac
            done
            ;;
        *)
            qest_error "Unknown profile '$PROFILE'. Falling back to 'full'."
            PROFILE="full"
            qest_apply_profile
            return
            ;;
    esac

    export INSTALL_SHELL_STACK INSTALL_ESSENTIALS INSTALL_EXTRAS INSTALL_CONFIG INSTALL_DEFAULT_SHELL PROFILE
}

qest_choose_profile_if_needed() {
    if [[ -n "${PROFILE:-}" ]]; then
        qest_apply_profile
        return 0
    fi

    local picked
    picked="$(qest_pick_one \
        "Choose a setup profile" \
        "full" \
        "shell" \
        "essentials" \
        "custom")"

    PROFILE="$picked"
    qest_apply_profile
}

export -f qest_apply_profile qest_choose_profile_if_needed
