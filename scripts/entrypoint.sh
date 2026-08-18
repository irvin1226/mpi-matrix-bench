#!/bin/bash

# start SSH service so MPI can communicate between nodes
service ssh start

# generate hostfile dynamically based on how many nodes this job actually requested
echo "master slots=1" > /app/hostfile
for (( i=1; i<=MPI_NODE_COUNT; i++ )); do
    echo "node$i slots=1" >> /app/hostfile
done

# master node runs MPI, workers just wait for instructions
if [ "$MPI_ROLE" = "master" ]; then
    # delay for nodes to wake up
    sleep 5

    # run the MPI job across all nodes
    if [ "$MPI_PROFILE" = "gpu-cuda" ]; then
    mpirun --hostfile /app/hostfile \
       --allow-run-as-root \
       -x MATRIX_SIZE \
       -x NVIDIA_VISIBLE_DEVICES \
       -x NVIDIA_DRIVER_CAPABILITIES \
       -x PATH \
       -x LD_LIBRARY_PATH \
       -np $MPI_PROCESSES \
       /app/src/matrix_mult
    else
        mpirun --hostfile /app/hostfile \
        --allow-run-as-root \
        -x MATRIX_SIZE \
        -np $MPI_PROCESSES \
        /app/src/matrix_mult
    fi
else
    # worker node, just keep container alive and wait for master
    echo "Worker node ready, waiting for master..."
    tail -f /dev/null
fi