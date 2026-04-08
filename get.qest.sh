#!/bin/bash
set -euo pipefail

TMP_DIR="$(mktemp -d /tmp/qest-bootstrap-XXXXXX)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

detect_os() {
  if [[ "$(uname)" == "Darwin" ]]; then
    return 0
  fi
  if [[ ! -f /etc/os-release ]]; then
    echo "Unsupported system: /etc/os-release not found."
    exit 1
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  local os_id="${ID:-}"
  local os_like="${ID_LIKE:-}"
  if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" || "$os_id" == "fedora" || "$os_id" == "arch" || "$os_id" == "manjaro" ]]; then
    return 0
  fi
  if [[ "$os_like" == *"ubuntu"* || "$os_like" == *"debian"* || "$os_like" == *"fedora"* || "$os_like" == *"arch"* ]]; then
    return 0
  fi
  echo "Unsupported Linux distro: $os_id ($os_like)."
  exit 1
}

require_command() {
  if ! command -v "$1" &>/dev/null; then
    echo "Required command missing: $1"
    exit 1
  fi
}

main() {
  require_command bash
  require_command curl
  require_command tar
  detect_os

  local repo_url="${QEST_REPO_URL:-https://github.com/TinorNoah/QEST/archive/refs/heads/main.tar.gz}"
  echo "Downloading QEST..."
  curl -fsSL "$repo_url" -o "$TMP_DIR/qest.tar.gz"
  tar -xzf "$TMP_DIR/qest.tar.gz" -C "$TMP_DIR"

  local extracted_dir
  extracted_dir="$(echo "$TMP_DIR"/QEST-*)"
  if [[ -z "$extracted_dir" ]]; then
    echo "Unable to locate qest.sh after extraction."
    exit 1
  fi

  cd "$extracted_dir"
  chmod +x ./qest.sh
  ./qest.sh "$@"
}

main "$@"
