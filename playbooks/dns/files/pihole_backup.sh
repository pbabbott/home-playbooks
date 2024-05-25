#!/bin/bash

# Get the container ID or name
CONTAINER_ID=$(docker ps -aqf "name=pihole")

# Execute the commands inside the container
docker exec -it "$CONTAINER_ID" /bin/bash -c "cd /backups && pihole -a -t"

echo "Job complete at $(date)"
