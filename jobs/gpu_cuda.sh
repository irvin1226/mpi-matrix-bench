#!/bin/bash

#CLUSTER -N 2
#CLUSTER --ntasks=2
#CLUSTER --profile=gpu-cuda
#CLUSTER --matrix-size=1024
#CLUSTER --memory=128MB
#CLUSTER -t 0:02:00

# parse this script's own #CLUSTER directives into real variables
SCRIPT_PATH="${BASH_SOURCE[0]}"

WORKER_NODES=$(grep "^#CLUSTER -N" "$SCRIPT_PATH" | awk '{print $3}')
MPI_PROCESSES=$(grep "^#CLUSTER --ntasks" "$SCRIPT_PATH" | cut -d= -f2)
MPI_PROFILE=$(grep "^#CLUSTER --profile" "$SCRIPT_PATH" | cut -d= -f2)
MEM_LIMIT_RAW=$(grep "^#CLUSTER --memory" "$SCRIPT_PATH" | cut -d= -f2)
MEM_LIMIT=$(echo "$MEM_LIMIT_RAW" | tr '[:upper:]' '[:lower:]')
MATRIX_SIZE=$(grep "^#CLUSTER --matrix-size" "$SCRIPT_PATH" | cut -d= -f2)

# worker node count is total nodes minus master
export MPI_NODE_COUNT=$((WORKER_NODES - 1))
export MPI_PROCESSES
export MPI_PROFILE
export MEM_LIMIT
export MATRIX_SIZE

# single timestamped filename used for the whole run
RESULTS_FILE="results/gpu-cuda-$(date +%Y%m%d-%H%M%S).out"

{
    echo "=== Job Configuration ==="
    echo "Profile: $MPI_PROFILE"
    echo "Nodes: $MPI_NODE_COUNT workers + 1 master"
    echo "Processes: $MPI_PROCESSES"
    echo "Matrix size: $MATRIX_SIZE"
    echo "Memory limit: $MEM_LIMIT"
    echo "=========================="
} | tee "$RESULTS_FILE"

# bring up the GPU cluster using its dedicated compose file
docker compose -f docker-compose.gpu.yml up -d --build

# wait for the worker node to be ready
echo "Waiting for nodes to come online..."

until docker compose -f docker-compose.gpu.yml exec node1 ssh master exit 2>/dev/null; do
    sleep 1
done
echo "Node node1 connected."

echo "All nodes connected. Starting job..."

# stream master output to terminal in real time
docker compose -f docker-compose.gpu.yml logs -f master

# append container logs to the same results file
docker compose -f docker-compose.gpu.yml logs master >> "$RESULTS_FILE"
echo "Results saved to $RESULTS_FILE"

# tear down the GPU cluster
docker compose -f docker-compose.gpu.yml down
echo "Cluster shut down."