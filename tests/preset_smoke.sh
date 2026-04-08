#!/bin/bash
set -euo pipefail

profiles=("full" "shell" "essentials" "custom")

for profile in "${profiles[@]}"; do
  echo "Smoke-testing profile: $profile"
  ./qest.sh --dry-run --yes --profile "$profile" --no-gum
done

echo "Preset smoke tests passed."
