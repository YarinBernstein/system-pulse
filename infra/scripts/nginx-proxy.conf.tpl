server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location = /config.js {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
        try_files /config.js =404;
    }

    # Anything the browser asks for under /api/ is quietly forwarded to the
    # backend server's private address. The browser never talks to the
    # backend directly, and the backend is never reachable from the internet.
    location /api/ {
        proxy_pass http://${backend_private_ip}:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    location = /healthz {
        access_log off;
        return 200 "ok\n";
        add_header Content-Type text/plain;
    }
}
