#!/bin/bash

#CLUSTER -N 4
#CLUSTER --ntasks=4
#CLUSTER --profile=cpu-naive
#CLUSTER --matrix-size=1024
#CLUSTER --memory=256MB
#CLUSTER -t 0:02:00

# bring up the cluster
docker compose -f docker-compose.cpu-naive.yml up -d

# wait for all nodes to be ready
echo "Waiting for nodes to come online..."

for node in node1 node2 node3; do
    until docker compose -f docker-compose.cpu-naive.yml exec $node ssh master exit 2>/dev/null; do
        sleep 1
    done
    echo "Node $node connected."
done

echo "All nodes connected. Starting job..."

# stream master output to terminal in real time
docker compose -f docker-compose.cpu-naive.yml logs -f master

# save results to timestamped file
docker compose -f docker-compose.cpu-naive.yml logs master > results/cpu-naive-$(date +%Y%m%d-%H%M%S).out
echo "Results saved to results/"

# tear down the cluster
docker compose -f docker-compose.cpu-naive.yml down
echo "Cluster shut down."