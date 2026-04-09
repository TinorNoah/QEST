FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Pre-install dependencies for QEST Go installer
RUN apt-get update && apt-get install -y sudo curl git build-essential golang-go

# Create a non-root test user with passwordless sudo
RUN useradd -m -s /bin/bash qestuser && \
    echo "qestuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER qestuser
WORKDIR /home/qestuser/quest

# Copy the entire directory into the container
COPY --chown=qestuser:qestuser . .

# Emulate fresh install using Go installer, then verify system state
CMD ["/bin/bash", "-c", "go run ./cmd/qest --yes --no-gum && ./tests/verify.sh"]
