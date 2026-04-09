#!/bin/bash
set -uo pipefail

PASS=0
FAIL=0
SKIP=0

pass() { echo "  ✔ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✘ $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  ⊘ $1"; SKIP=$((SKIP + 1)); }

has_cmd() { command -v "$1" >/dev/null 2>&1 || [ -x "/home/linuxbrew/.linuxbrew/bin/$1" ]; }

check_cmd() {
  local label="$1"; shift
  for bin in "$@"; do
    if has_cmd "$bin"; then
      pass "$label [$bin]"
      return 0
    fi
  done
  fail "$label [tried: $*]"
}

check_file() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then
    pass "$label [$path]"
  else
    fail "$label [$path]"
  fi
}

check_dir() {
  local label="$1" path="$2"
  if [ -d "$path" ]; then
    pass "$label [$path]"
  else
    fail "$label [$path]"
  fi
}

has_pkg() {
  local pkg="$1"
  if command -v dpkg >/dev/null 2>&1; then
    dpkg -s "$pkg" >/dev/null 2>&1
    return $?
  fi
  if command -v rpm >/dev/null 2>&1; then
    rpm -q "$pkg" >/dev/null 2>&1
    return $?
  fi
  if command -v pacman >/dev/null 2>&1; then
    pacman -Q "$pkg" >/dev/null 2>&1
    return $?
  fi
  return 1
}

check_pkg() {
  local label="$1"; shift
  for pkg in "$@"; do
    if has_pkg "$pkg"; then
      pass "$label [$pkg]"
      return 0
    fi
  done
  fail "$label [tried: $*]"
}

if [ ! -f /etc/os-release ]; then
  echo "Cannot read /etc/os-release"
  exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
OS="${ID:-unknown}"
OS_LIKE="${ID_LIKE:-}"

echo "QEST v0.1 verification"
echo "OS: $OS / ${OS_LIKE:-none}"

echo ""
echo "Core shell and essentials"
check_cmd "zsh" zsh
check_cmd "starship" starship
check_pkg "zsh-autosuggestions package" zsh-autosuggestions
check_cmd "zoxide" zoxide
check_cmd "fzf" fzf
check_cmd "bat" bat batcat
check_cmd "ripgrep" rg
check_cmd "fd" fd fdfind
check_cmd "jq" jq
check_cmd "btop" btop
check_cmd "eza" eza
check_cmd "git-delta" delta
check_cmd "helix" hx helix
check_cmd "zellij" zellij
check_cmd "lazygit" lazygit

echo ""
echo "Config and plugins"
check_file ".zshrc" "$HOME/.zshrc"
check_file "starship.toml" "$HOME/.config/starship.toml"
check_dir "fzf-tab" "$HOME/.zsh/fzf-tab"
check_dir "fast-syntax-highlighting" "$HOME/.zsh/fast-syntax-highlighting"

echo ""
echo "Summary"
echo "  $PASS passed  $FAIL failed  $SKIP skipped"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
