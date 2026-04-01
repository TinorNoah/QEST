#!/bin/bash
set -eo pipefail

echo "================================================="
echo "  QEST End-to-End Test Orchestrator (Docker) "
echo "================================================="

if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH."
    exit 1
fi

DISTROS=("ubuntu" "fedora" "arch")

if [ "$#" -eq 1 ]; then
    DISTROS=("$1")
fi

for DISTRO in "${DISTROS[@]}"; do
    echo -e "\n\n---> Testing $DISTRO environment <---"
    docker build -t "qest-test-$DISTRO" -f "tests/$DISTRO.Dockerfile" .
    
    echo "Running container (this will execute qest.sh internally)..."
    docker run --rm -it "qest-test-$DISTRO"
    
    echo "✅ $DISTRO passed baseline execution."
done

echo "All tests complete!"
