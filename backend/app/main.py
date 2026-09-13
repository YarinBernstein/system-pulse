"""
System Pulse - Backend API

A deliberately simple FastAPI service acting as the middle tier of a
3-tier demo app. Its sole purposes are:
  1. Report its own health.
  2. Report the health of its downstream dependency (Redis).
  3. Increment a counter in Redis ("send a pulse").

Every request and every Redis interaction is logged verbosely to stdout
(see logging_config.py) so an external network-tracing tool has a clean,
structured signal to correlate against actual packets on the wire.
"""
import logging
import time
import uuid

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings
from app.logging_config import configure_logging
from app.redis_client import increment_pulse_count, ping

configure_logging()
logger = logging.getLogger("system_pulse.api")

app = FastAPI(title="System Pulse Backend", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Logs every incoming request and its outcome with a correlation id.

    A request_id is generated per-request (or reused from an inbound
    X-Request-ID header, so it can be threaded through by an upstream
    proxy/tracer) and echoed back in the response headers.
    """
    request_id = request.headers.get("x-request-id", str(uuid.uuid4()))
    start = time.perf_counter()

    logger.info(
        "Incoming request",
        extra={
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "client": request.client.host if request.client else None,
        },
    )

    try:
        response = await call_next(request)
    except Exception:
        duration_ms = round((time.perf_counter() - start) * 1000, 2)
        logger.exception(
            "Request failed with an unhandled exception",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "duration_ms": duration_ms,
            },
        )
        raise

    duration_ms = round((time.perf_counter() - start) * 1000, 2)
    logger.info(
        "Request completed",
        extra={
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "duration_ms": duration_ms,
        },
    )
    response.headers["X-Request-ID"] = request_id
    return response


@app.get("/api/health")
async def health():
    """Liveness endpoint for the backend tier itself. Always 200 if the process is up."""
    return {"status": "ok", "service": settings.SERVICE_NAME}


@app.get("/api/db-status")
async def db_status():
    """Reports Redis reachability. 200 if reachable, 500 otherwise."""
    healthy = ping()
    if healthy:
        return {"status": "ok", "database": "redis", "reachable": True}
    return JSONResponse(
        status_code=500,
        content={"status": "error", "database": "redis", "reachable": False},
    )


@app.post("/api/pulse")
async def pulse():
    """Increments the pulse_count key in Redis and returns the new value."""
    try:
        new_count = increment_pulse_count()
        return {"status": "ok", "pulse_count": new_count}
    except Exception as exc:  # noqa: BLE001 - translate any Redis failure into a clean 500
        logger.error("Failed to record pulse", extra={"error": str(exc)})
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": "Could not reach the database"},
        )


@app.on_event("startup")
async def on_startup():
    logger.info(
        "System Pulse backend starting up",
        extra={
            "redis_host": settings.REDIS_HOST,
            "redis_port": settings.REDIS_PORT,
            "cors_origins": settings.CORS_ORIGINS,
        },
    )
