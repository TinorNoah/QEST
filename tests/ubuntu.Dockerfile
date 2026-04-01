FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive

# Pre-install dependencies for QEST scripts
RUN apt-get update && apt-get install -y sudo curl git build-essential

# Create a non-root test user with passwordless sudo
RUN useradd -m -s /bin/bash qestuser && \
    echo "qestuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER qestuser
WORKDIR /home/qestuser/quest

# Copy the entire directory into the container
COPY --chown=qestuser:qestuser . .

# Emulate fresh install
CMD ["/bin/bash", "./qest.sh"]
