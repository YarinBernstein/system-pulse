#!/bin/bash
# Runs once when the redis server boots. Installs Docker and runs the
# official Redis image, unmodified - no custom build needed.
set -euxo pipefail

# Wait for the NAT instance to be routing traffic before trying to reach
# the internet (avoids a boot-order race with the NAT instance).
until curl -s -m 3 -o /dev/null https://hub.docker.com; do
  echo "Waiting for internet access via the NAT instance..."
  sleep 5
done

dnf install -y docker
systemctl enable --now docker

docker run -d --name redis --restart unless-stopped \
  -p 6379:6379 \
  redis:7-alpine
