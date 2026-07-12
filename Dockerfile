FROM ubuntu:22.04

# install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    openmpi-bin \
    openmpi-common \
    libopenmpi-dev \
    openssh-server \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# set up SSH for MPI communication between nodes
RUN mkdir /var/run/sshd
RUN ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ""
RUN cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys

# disables strict host key checking so nodes can connect freely
RUN echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config

WORKDIR /app

COPY src/ ./src/
COPY scripts/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]