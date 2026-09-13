# System Pulse

A minimal 3-tier demo application built as a "dummy/victim" microservices
environment for exercising a network tracing and debugging tool. It has no
business logic to speak of — its entire purpose is to expose clean,
observable network boundaries and verbose, structured logs.

```
Browser  ──HTTP──►  Frontend (Nginx)   ── static assets only ──► (browser renders UI)
Browser  ──HTTP──►  Backend (FastAPI)  ──TCP──►  Redis
```

The browser talks to the backend **directly** (not proxied through Nginx),
so there are exactly two network hops to trace: `browser → backend` and
`backend → redis`.

## Architecture

| Tier | Tech | Role |
|------|------|------|
| Frontend | React + Vite + TypeScript + Tailwind CSS | Dashboard UI. Polls backend health, triggers "pulses". |
| Backend | Python + FastAPI + Uvicorn | Stateless API. Talks to Redis. Logs every request as JSON to stdout. |
| Database | Redis 7 | Single counter (`pulse_count`) plus the backend's health target. |

All three run as separate containers on a custom Docker bridge network
(`system-pulse-net`) and communicate via Docker's embedded DNS using their
service names (`backend`, `redis`) — the same mental model as Kubernetes
Service DNS, so this compose file translates directly to k8s Deployments +
Services later.

### Endpoints (backend)

| Method | Path | Behavior |
|--------|------|----------|
| GET | `/api/health` | Always returns `200 {"status": "ok"}` if the process is alive. |
| GET | `/api/db-status` | Pings Redis. `200` if reachable, `500` if not. |
| POST | `/api/pulse` | `INCR`s `pulse_count` in Redis, returns the new value. `500` on Redis failure. |

### Logging

Every backend log line is a single-line JSON object on stdout, e.g.:

```json
{"timestamp":"2026-09-13T10:22:31+0000","level":"INFO","service":"system-pulse-backend","logger":"system_pulse.api","message":"Incoming request","request_id":"a1b2c3d4-...","method":"POST","path":"/api/pulse"}
{"timestamp":"2026-09-13T10:22:31+0000","level":"INFO","service":"system_pulse.redis","message":"Incrementing pulse_count in Redis","redis_target":"redis:6379"}
{"timestamp":"2026-09-13T10:22:31+0000","level":"ERROR","service":"system_pulse.redis","message":"Redis connection failed during INCR","redis_target":"redis:6379","error":"Error 111 connecting to redis:6379. Connection refused."}
```

Every request carries a `request_id` (generated, or forwarded from an
inbound `X-Request-ID` header) so a tracing tool can correlate a captured
packet flow with the exact log lines it produced.

## Running locally with docker-compose

1. Copy the environment template:

   ```bash
   cp .env.example .env
   ```

2. Adjust `.env` if needed. The important one is `VITE_BACKEND_URL` — since
   the **browser** (not a container) calls the backend directly, this must
   be an address reachable from your host machine, e.g. `http://localhost:8000`.

3. Build and start all three services:

   ```bash
   docker compose up --build
   ```

4. Open the dashboard at [http://localhost:5173](http://localhost:5173)
   (or whatever `FRONTEND_PORT` you configured).

5. Watch the backend's structured logs:

   ```bash
   docker compose logs -f backend
   ```

6. Tear down:

   ```bash
   docker compose down
   ```

## Configuring environment variables

Every network-relevant value is configurable — nothing is hardcoded.

### Frontend

| Variable | Where it's read | Default | Notes |
|----------|------------------|---------|-------|
| `VITE_BACKEND_URL` | Container **runtime** (not build time) | `http://localhost:8000` | Injected into `window.__ENV__` by `entrypoint.sh` when the Nginx container starts, via a generated `/config.js`. This means you can point the same built image at a different backend just by changing an env var on the container/Pod — no rebuild needed. Falls back to Vite's build-time `import.meta.env.VITE_BACKEND_URL` for local `npm run dev`. |
| `FRONTEND_PORT` | docker-compose host port mapping | `5173` | Host port the dashboard is served on. |

### Backend

| Variable | Default | Notes |
|----------|---------|-------|
| `SERVICE_NAME` | `system-pulse-backend` | Included in every log line. |
| `BACKEND_HOST` / `BACKEND_PORT` | `0.0.0.0` / `8000` | Uvicorn bind address. |
| `REDIS_HOST` / `REDIS_PORT` | `redis` / `6379` | Resolved via Docker/K8s DNS. |
| `REDIS_DB` | `0` | Redis logical database index. |
| `REDIS_CONNECT_TIMEOUT` / `REDIS_SOCKET_TIMEOUT` | `2` (seconds) | Kept short so failures surface quickly and predictably in logs. |
| `CORS_ORIGINS` | `*` | Comma-separated allow-list, or `*`. |
| `LOG_LEVEL` | `INFO` | `DEBUG` \| `INFO` \| `WARNING` \| `ERROR`. |

See [`backend/.env.example`](backend/.env.example) and
[`frontend/.env.example`](frontend/.env.example) for per-service templates
(useful if you run either service outside Docker, e.g. `npm run dev` /
`uvicorn app.main:app --reload`).

## Running without Docker (local dev)

**Backend:**

```bash
cd backend
python -m venv .venv && . .venv/Scripts/activate   # or source .venv/bin/activate on macOS/Linux
pip install -r requirements.txt
# Requires a Redis instance reachable at REDIS_HOST:REDIS_PORT, e.g.:
#   docker run -p 6379:6379 redis:7-alpine
uvicorn app.main:app --reload --port 8000
```

**Frontend:**

```bash
cd frontend
cp .env.example .env   # sets VITE_BACKEND_URL for the Vite dev server
npm install
npm run dev
```

## Notes for Kubernetes migration

- Each service is a single stateless (frontend/backend) or single-replica
  (Redis, for this demo) container — straightforward to lift into a
  Deployment + Service per tier.
- The custom bridge network's DNS-by-service-name behavior is the same
  mental model as Kubernetes Service DNS (`redis`, `backend` would become
  `redis.<namespace>.svc.cluster.local`-style names, or just `redis` /
  `backend` within the same namespace).
- The frontend's runtime-config pattern (`entrypoint.sh` generating
  `config.js` from env vars at container start) maps directly onto a
  Kubernetes ConfigMap/Secret injected as Pod environment variables —
  no image rebuild needed to repoint it at a different backend Service.
- Both Dockerfiles run as a non-root user and define a `HEALTHCHECK`,
  which map to Kubernetes `securityContext.runAsNonRoot` and
  liveness/readiness probes respectively (`/api/health` for the backend,
  `/healthz` for the frontend's Nginx).
