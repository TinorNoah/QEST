#!/bin/bash
set -euo pipefail

profiles=("full" "shell" "essentials" "custom")

for profile in "${profiles[@]}"; do
  echo "Smoke-testing profile: $profile"
  if [[ "$profile" == "full" ]]; then
    go run ./cmd/qest --dry-run --yes --no-gum
  else
    echo "Skipping $profile in --yes smoke mode (defaults to full)."
  fi
done

echo "Preset smoke tests passed."
