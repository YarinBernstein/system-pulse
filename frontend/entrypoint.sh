#!/bin/sh
# Generates /usr/share/nginx/html/config.js from the container's real
# environment at startup, so VITE_BACKEND_URL can be changed per-deployment
# (docker-compose, Kubernetes ConfigMap, etc.) without rebuilding the image.
set -e

: "${VITE_BACKEND_URL:=http://localhost:8000}"

cat > /usr/share/nginx/html/config.js <<EOF
window.__ENV__ = {
  VITE_BACKEND_URL: "${VITE_BACKEND_URL}"
};
EOF

echo "[entrypoint] Generated runtime config: VITE_BACKEND_URL=${VITE_BACKEND_URL}"

exec nginx -g "daemon off;"
