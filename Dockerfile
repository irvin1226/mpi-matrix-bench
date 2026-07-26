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

# which profile's source file to compile, set at build time (naive, optimized, gpu)
ARG PROFILE=naive

# compile only the source file matching this profile
RUN mpic++ -o ./src/matrix_mult ./src/matrix_mult_${PROFILE}.cpp

ENTRYPOINT ["./entrypoint.sh"]