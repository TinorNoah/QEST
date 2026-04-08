#!/bin/bash
set -euo pipefail

if [[ "$(uname)" == "Darwin" ]]; then
  echo "Skipping preset smoke tests on macOS host."
  exit 0
fi

profiles=("full" "shell" "essentials" "custom")

for profile in "${profiles[@]}"; do
  echo "Smoke-testing profile: $profile"
  ./qest.sh --dry-run --yes --profile "$profile" --no-gum
done

echo "Preset smoke tests passed."
