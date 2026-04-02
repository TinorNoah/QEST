#!/bin/bash
# =============================================================================
# QEST — Post-Install Verification Script
# Checks that all tools, configs, and plugins were correctly set up.
# =============================================================================
# This script must NOT use set -e so individual checks can fail without
# aborting the entire test run.
set -uo pipefail

# ── Counters ──────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BOLD="\e[1m"
RESET="\e[0m"

# ── Helpers ───────────────────────────────────────────────────────────────────
header() {
    echo -e "\n${BOLD}── $1 ──${RESET}"
}

pass() {
    echo -e "  ${GREEN}✔${RESET}  $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "  ${RED}✘${RESET}  $1"
    FAIL=$((FAIL + 1))
}

skip() {
    echo -e "  ${YELLOW}⊘${RESET}  $1"
    SKIP=$((SKIP + 1))
}

# has_cmd: checks PATH and the common Linuxbrew prefix
has_cmd() {
    command -v "$1" &>/dev/null || \
        [ -x "/home/linuxbrew/.linuxbrew/bin/$1" ]
}

# check_cmd <label> <binary> [<binary> ...]
# Passes if ANY of the provided binary names is found.
check_cmd() {
    local label="$1"; shift
    for bin in "$@"; do
        if has_cmd "$bin"; then
            pass "$label  [$bin]"
            return 0
        fi
    done
    fail "$label  [tried: $*]"
}

# check_file <label> <path>
check_file() {
    local label="$1"
    local path="$2"
    if [ -f "$path" ]; then
        pass "$label  [$path]"
    else
        fail "$label  [$path not found]"
    fi
}

# check_dir <label> <path>
check_dir() {
    local label="$1"
    local path="$2"
    if [ -d "$path" ]; then
        pass "$label  [$path]"
    else
        fail "$label  [$path not found]"
    fi
}

# ── OS Detection ──────────────────────────────────────────────────────────────
if [ ! -f /etc/os-release ]; then
    echo -e "${RED}Cannot read /etc/os-release — OS unknown. Aborting.${RESET}"
    exit 1
fi

# shellcheck source=/dev/null
. /etc/os-release
OS="${ID:-unknown}"
OS_LIKE="${ID_LIKE:-}"

is_arch()   { [[ "$OS" == "arch" || "$OS" == "manjaro" ]] || echo "$OS_LIKE" | grep -q "arch";   }
is_debian() { [[ "$OS" == "ubuntu" || "$OS" == "debian" ]] || echo "$OS_LIKE" | grep -q "ubuntu\|debian"; }
is_fedora() { [[ "$OS" == "fedora" ]] || echo "$OS_LIKE" | grep -q "fedora"; }
has_brew()  { has_cmd brew; }

echo -e "\n${BOLD}════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  QEST Post-Install Verification${RESET}"
echo -e "${BOLD}  OS: ${OS}  /  LIKE: ${OS_LIKE:-none}${RESET}"
echo -e "${BOLD}════════════════════════════════════════════════${RESET}"

# ── 1. Core Native Tools (all distros) ───────────────────────────────────────
# These come from the native package manager on every supported distribution.
header "Core Native Tools"
check_cmd "zsh"       zsh
check_cmd "curl"      curl
check_cmd "git"       git
check_cmd "fzf"       fzf
check_cmd "jq"        jq
check_cmd "zoxide"    zoxide
# bat is 'batcat' on Debian/Ubuntu, 'bat' everywhere else
check_cmd "bat"       bat batcat
# ripgrep binary is always 'rg'
check_cmd "ripgrep"   rg
# fd is 'fdfind' on Debian/Ubuntu, 'fd' everywhere else
check_cmd "fd"        fd fdfind

# ── 2. Zsh Plugins (cloned by 03_install_extras.sh) ──────────────────────────
header "Zsh Plugins"
check_dir "fzf-tab"                   "$HOME/.zsh/fzf-tab"
check_dir "fast-syntax-highlighting"  "$HOME/.zsh/fast-syntax-highlighting"

# ── 3. Config Files (placed by 04_config_setup.sh) ───────────────────────────
header "Config Files"
check_file ".zshrc"          "$HOME/.zshrc"
check_file "starship.toml"   "$HOME/.config/starship.toml"

# ── 4. Extended / Modern Tools ───────────────────────────────────────────────
# Present on Arch (arch_core.txt) and on Debian/Fedora after the Homebrew step
# (brew_core.txt). We check unconditionally so missing tools are always surfaced.

header "Shell & Environment"
check_cmd "Starship"   starship
check_cmd "Atuin"      atuin
check_cmd "Direnv"     direnv
check_cmd "Chezmoi"    chezmoi
check_cmd "Age"        age
# nushell binary is 'nu'
check_cmd "Nushell"    nu

header "Editors & Multiplexers"
# helix binary is 'hx'
check_cmd "Helix"    hx
check_cmd "Zellij"   zellij

header "Git & Workflow"
check_cmd "Lazygit"    lazygit
check_cmd "Just"       just
check_cmd "Moulti"     moulti
check_cmd "Gitleaks"   gitleaks
# git-delta binary is 'delta'
check_cmd "git-delta"  delta

header "System Monitors"
check_cmd "Btop"    btop
# bottom binary is 'btm'
check_cmd "Bottom"  btm
check_cmd "Viddy"   viddy

header "Files & Navigation"
check_cmd "Yazi"     yazi
check_cmd "Eza"      eza
# broot installs both 'broot' and the 'br' shell function launcher
check_cmd "Broot"    broot br
check_cmd "Rclone"   rclone
check_cmd "s5cmd"    s5cmd

header "Text & Data Processing"
check_cmd "Lnav"       lnav
check_cmd "Yq"         yq
check_cmd "Sd"         sd
check_cmd "Jless"      jless
check_cmd "Dasel"      dasel
# choose-rust (brew) / choose (arch) — binary is always 'choose'
check_cmd "Choose"     choose
# visidata binary is 'vd'
check_cmd "Visidata"   vd
check_cmd "Logdy"      logdy

header "Disk Operations"
check_cmd "Duf"      duf
check_cmd "Procs"    procs
# czkawka-cli (arch) → czkawka_cli  |  czkawka (brew) → czkawka
check_cmd "Czkawka"  czkawka_cli czkawka
check_cmd "Dust"     dust
# gdu is installed as 'gdu-go' on Homebrew (Linux) to avoid conflict with coreutils
check_cmd "Gdu"      gdu-go gdu
# erdtree binary is 'erd' as of v3.x, 'et' in v0.8-v2.x, 'erdtree' in older versions
check_cmd "Erdtree"  erd et erdtree

header "Networking & Security"
check_cmd "Gping"       gping
check_cmd "Doggo"       doggo
check_cmd "Xh"          xh
check_cmd "Bandwhich"   bandwhich
check_cmd "Termshark"   termshark
check_cmd "Atac"        atac

header "Utilities"
check_cmd "Lazydocker"  lazydocker
check_cmd "Asciinema"   asciinema
# tealdeer binary is 'tldr'
check_cmd "Tealdeer"    tldr
check_cmd "Navi"        navi
check_cmd "Grex"        grex

# ── 5. Arch-only Tools ───────────────────────────────────────────────────────
# 'sysz' is in arch_core.txt but not in brew_core.txt
if is_arch; then
    header "Arch-only Tools"
    check_cmd "Sysz"  sysz
else
    header "Arch-only Tools"
    skip "sysz (not applicable on $OS)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}════════════════════════════════════════════════${RESET}"
printf "  ${GREEN}${BOLD}%-8s${RESET}" "${PASS} passed"
printf "  ${RED}${BOLD}%-8s${RESET}" "${FAIL} failed"
printf "  ${YELLOW}${BOLD}%-8s${RESET}\n" "${SKIP} skipped"
echo -e "${BOLD}════════════════════════════════════════════════${RESET}"

if [ "$FAIL" -gt 0 ]; then
    echo -e "  ${RED}${BOLD}✘  Verification FAILED — $FAIL check(s) did not pass.${RESET}\n"
    exit 1
else
    echo -e "  ${GREEN}${BOLD}✔  Verification PASSED — all checks OK.${RESET}\n"
    exit 0
fi
