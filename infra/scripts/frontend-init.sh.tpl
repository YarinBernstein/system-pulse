#!/bin/bash
# Runs once when the frontend server boots. Installs Docker, downloads and
# builds this project's frontend image straight from GitHub, then runs it
# with a custom Nginx config that forwards API calls to the private backend.
set -euxo pipefail

dnf install -y docker git
systemctl enable --now docker

git clone ${github_repo_url} /opt/system-pulse
cd /opt/system-pulse/frontend
docker build -t system-pulse-frontend .

mkdir -p /opt/system-pulse-config
cat > /opt/system-pulse-config/default.conf <<'NGINXEOF'
${nginx_conf}
NGINXEOF

docker run -d --name frontend --restart unless-stopped \
  -p 80:80 \
  -e VITE_BACKEND_URL="" \
  -v /opt/system-pulse-config/default.conf:/etc/nginx/conf.d/default.conf:ro \
  system-pulse-frontend
