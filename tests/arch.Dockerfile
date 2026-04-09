FROM --platform=linux/amd64 archlinux:latest

# Arch is rolling; keep latest intentionally for package ecosystem parity.

# Disable pacman's seccomp sandbox — required in Docker environments that
# restrict certain syscalls (e.g. Docker Desktop on macOS / Apple Silicon).
# Without this, pacman fails with "error restricting syscalls via seccomp: 22".
RUN sed -i 's/^\[options\]/[options]\nDisableSandbox/' /etc/pacman.conf

RUN pacman -Syu --noconfirm && pacman -S --noconfirm sudo curl git go base-devel

# Create a non-root test user with passwordless sudo
RUN useradd -m -s /bin/bash qestuser && \
    echo "qestuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER qestuser
WORKDIR /home/qestuser/quest

# Copy the entire directory into the container
COPY --chown=qestuser:qestuser . .

# Emulate fresh install using Go installer, then verify system state
CMD ["/bin/bash", "-c", "go run ./cmd/qest --yes --no-gum && bash ./tests/verify.sh"]
