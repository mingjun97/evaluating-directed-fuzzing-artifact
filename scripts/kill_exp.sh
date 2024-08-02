#!/bin/bash

containers=(
  ""
)

$ run the command in all containers
for container in "${containers[@]}"; do
  echo "Executing in container $container"
  docker exec "$container" sh -c 'echo "FINISHED" > /STATUS'
done

echo "All commands executed."

