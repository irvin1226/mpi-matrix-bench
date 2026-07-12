#!/bin/bash

# start SSH service so MPI can communicate between nodes
service ssh start

# generate hostfile based on profile
if [ "$MPI_PROFILE" = "gpu-cuda" ]; then
    cat > /app/hostfile << EOF
master slots=1
node1 slots=1
EOF
else
    cat > /app/hostfile << EOF
master slots=1
node1 slots=1
node2 slots=1
node3 slots=1
EOF
fi

# master node runs MPI, workers just wait for instructions
if [ "$MPI_ROLE" = "master" ]; then
    # delay for nodes to wake up
    sleep 5

    # run the MPI job across all nodes
    mpirun --hostfile /app/hostfile \
           --allow-run-as-root \
           -np $MPI_PROCESSES \
           /app/src/matrix_mult
else
    # worker node, just keep container alive and wait for master
    echo "Worker node ready, waiting for master..."
    tail -f /dev/null
fi