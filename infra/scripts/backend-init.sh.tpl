#!/bin/bash
# Runs once when the backend server boots. Installs Docker, downloads and
# builds this project's backend image straight from GitHub, then runs it
# wired up to Redis and to CloudWatch Logs (so its structured logs are
# viewable in the AWS Console).
set -euxo pipefail

# Wait for the NAT instance to be routing traffic before trying to reach
# the internet (avoids a boot-order race with the NAT instance).
until curl -s -m 3 -o /dev/null https://github.com; do
  echo "Waiting for internet access via the NAT instance..."
  sleep 5
done

dnf install -y docker git
systemctl enable --now docker

git clone ${github_repo_url} /opt/system-pulse
cd /opt/system-pulse/backend
docker build -t system-pulse-backend .

docker run -d --name backend --restart unless-stopped \
  -p 8000:8000 \
  -e REDIS_HOST=${redis_private_ip} \
  -e REDIS_PORT=6379 \
  -e CORS_ORIGINS="*" \
  -e LOG_LEVEL=INFO \
  --log-driver=awslogs \
  --log-opt awslogs-region=${aws_region} \
  --log-opt awslogs-group=/system-pulse/backend \
  --log-opt awslogs-create-group=true \
  --log-opt awslogs-stream=backend \
  system-pulse-backend
