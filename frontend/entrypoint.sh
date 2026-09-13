#!/bin/sh
# Generates /usr/share/nginx/html/config.js from the container's real
# environment at startup, so VITE_BACKEND_URL can be changed per-deployment
# (docker-compose, Kubernetes ConfigMap, etc.) without rebuilding the image.
set -e

# Deliberately using "=" rather than ":=" - an explicitly empty string is a
# valid, intentional value (same-origin API calls via a reverse proxy) and
# must not be overwritten just because it's empty; only a genuinely unset
# variable should fall back to the default.
: "${VITE_BACKEND_URL=http://localhost:8000}"

cat > /usr/share/nginx/html/config.js <<EOF
window.__ENV__ = {
  VITE_BACKEND_URL: "${VITE_BACKEND_URL}"
};
EOF

echo "[entrypoint] Generated runtime config: VITE_BACKEND_URL=${VITE_BACKEND_URL}"

exec nginx -g "daemon off;"
