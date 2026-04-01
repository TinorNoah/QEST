FROM --platform=linux/amd64 archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm sudo curl git base-devel

# Create a non-root test user with passwordless sudo
RUN useradd -m -s /bin/bash qestuser && \
    echo "qestuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER qestuser
WORKDIR /home/qestuser/quest

# Copy the entire directory into the container
COPY --chown=qestuser:qestuser . .

# Emulate fresh install automatically bypassing interactive prompts, then verify system state
CMD ["/bin/bash", "-c", "yes '' | ./qest.sh && ./tests/verify.sh"]
