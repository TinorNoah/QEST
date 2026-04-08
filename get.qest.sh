#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="$(mktemp -d /tmp/qest-bootstrap-XXXXXX)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

detect_linux_distro() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    echo "QEST bootstrap currently supports Linux only."
    exit 1
  fi
  if [[ ! -f /etc/os-release ]]; then
    echo "Cannot detect Linux distribution (/etc/os-release missing)."
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

detect_arch() {
  local machine_arch
  machine_arch="$(uname -m)"
  case "$machine_arch" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *)
      echo "Unsupported CPU architecture: $machine_arch"
      exit 1
      ;;
  esac
}

check_internet() {
  if ! curl -fsS --max-time 8 https://github.com >/dev/null 2>&1; then
    echo "Network check failed. Please verify internet connectivity."
    exit 1
  fi
}

check_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo is required but missing."
    exit 1
  fi
}

verify_checksum() {
  local binary_file="$1"
  local checksum_file="$2"

  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$TMP_DIR" && sha256sum -c "$(basename "$checksum_file")")
    return 0
  fi

  if command -v shasum >/dev/null 2>&1; then
    local expected actual
    expected="$(awk '{print $1}' "$checksum_file")"
    actual="$(shasum -a 256 "$binary_file" | awk '{print $1}')"
    if [[ "$expected" != "$actual" ]]; then
      echo "Checksum verification failed for $(basename "$binary_file")."
      exit 1
    fi
    return 0
  fi

  echo "No checksum tool found (sha256sum/shasum)."
  exit 1
}

main() {
  require_command bash
  require_command curl
  check_sudo
  check_internet
  detect_linux_distro

  local arch asset_name base_url bin_path sha_path
  arch="$(detect_arch)"
  asset_name="qest-linux-${arch}"
  base_url="${QEST_RELEASE_BASE_URL:-https://github.com/TinorNoah/QEST/releases/latest/download}"
  bin_path="$TMP_DIR/$asset_name"
  sha_path="$TMP_DIR/${asset_name}.sha256"

  echo "Downloading QEST binary (${asset_name})..."
  curl -fsSL "${base_url}/${asset_name}" -o "$bin_path"
  curl -fsSL "${base_url}/${asset_name}.sha256" -o "$sha_path"

  echo "Verifying checksum..."
  verify_checksum "$bin_path" "$sha_path"

  chmod +x "$bin_path"
  exec "$bin_path" "$@"
}

main "$@"
