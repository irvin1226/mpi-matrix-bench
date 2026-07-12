#!/bin/bash

#CLUSTER -N 2
#CLUSTER --ntasks=2
#CLUSTER --profile=gpu-cuda
#CLUSTER --matrix-size=1024
#CLUSTER --memory=256MB
#CLUSTER -t 0:02:00

# bring up the cluster
docker compose -f docker-compose.gpu-cuda.yml up -d

# wait for all nodes to be ready
echo "Waiting for nodes to come online..."


until docker compose -f docker-compose.gpu-cuda.yml exec node1 ssh master exit 2>/dev/null; do
    sleep 1
done
echo "Node node1 connected."


echo "All nodes connected. Starting job..."

# stream master output to terminal in real time
docker compose -f docker-compose.gpu-cuda.yml logs -f master

# save results to timestamped file
docker compose -f docker-compose.gpu-cuda.yml logs master > results/gpu-cuda-$(date +%Y%m%d-%H%M%S).out
echo "Results saved to results/"

# tear down the cluster
docker compose -f docker-compose.gpu-cuda.yml down
echo "Cluster shut down."