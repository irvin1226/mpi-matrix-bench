#!/bin/bash

#CLUSTER -N 4
#CLUSTER --ntasks=4
#CLUSTER --profile=cpu-optimized
#CLUSTER --matrix-size=1024
#CLUSTER --memory=32MB
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
export PROFILE=optimized

# build the list of services to start: master plus however many nodes this job needs
SERVICES="master"
for (( i=1; i<=MPI_NODE_COUNT; i++ )); do
    SERVICES="$SERVICES node$i"
done

# single timestamped filename used for the whole run
RESULTS_FILE="results/cpu-optimized-$(date +%Y%m%d-%H%M%S).out"

{
    echo "=== Job Configuration ==="
    echo "Profile: $MPI_PROFILE"
    echo "Nodes: $MPI_NODE_COUNT workers + 1 master"
    echo "Processes: $MPI_PROCESSES"
    echo "Matrix size: $MATRIX_SIZE"
    echo "Memory limit: $MEM_LIMIT"
    echo "=========================="
} | tee "$RESULTS_FILE"

# bring up only the nodes this job actually needs
docker compose up -d --build $SERVICES

# wait for all nodes to be ready
echo "Waiting for nodes to come online..."

for (( i=1; i<=MPI_NODE_COUNT; i++ )); do
    until docker compose exec node$i ssh master exit 2>/dev/null; do
        sleep 1
    done
    echo "Node node$i connected."
done

echo "All nodes connected. Starting job..."

# stream master output to terminal in real time
docker compose logs -f master

# append container logs to the same results file
docker compose logs master >> "$RESULTS_FILE"
echo "Results saved to $RESULTS_FILE"

# tear down only the containers this job started
docker compose down $SERVICES
echo "Cluster shut down."