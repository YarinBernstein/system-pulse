"""
Redis connectivity layer.

Isolated in its own module so the "database boundary" is explicit and easy
for a network-tracing tool to correlate: every Redis attempt is logged
with the target host:port before the call is made, and every outcome
(success, timeout, connection error) is logged immediately after.
"""
import logging

import redis

from app.config import settings

logger = logging.getLogger("system_pulse.redis")

_client: redis.Redis | None = None


def get_client() -> redis.Redis:
    """Returns a lazily-created, module-level Redis client instance.

    A single client is reused across requests; the underlying redis-py
    connection pool handles opening/closing sockets as needed.
    """
    global _client
    if _client is None:
        logger.info(
            "Creating Redis client",
            extra={"redis_host": settings.REDIS_HOST, "redis_port": settings.REDIS_PORT},
        )
        _client = redis.Redis(
            host=settings.REDIS_HOST,
            port=settings.REDIS_PORT,
            db=settings.REDIS_DB,
            socket_connect_timeout=settings.REDIS_CONNECT_TIMEOUT,
            socket_timeout=settings.REDIS_SOCKET_TIMEOUT,
            decode_responses=True,
        )
    return _client


def ping() -> bool:
    """Pings Redis, logging the attempt and outcome. Returns True/False."""
    target = f"{settings.REDIS_HOST}:{settings.REDIS_PORT}"
    logger.info("Pinging Redis", extra={"redis_target": target})
    try:
        client = get_client()
        client.ping()
        logger.info("Redis ping succeeded", extra={"redis_target": target})
        return True
    except redis.exceptions.TimeoutError as exc:
        logger.error(
            "Redis ping timed out", extra={"redis_target": target, "error": str(exc)}
        )
        return False
    except redis.exceptions.ConnectionError as exc:
        logger.error(
            "Redis connection failed", extra={"redis_target": target, "error": str(exc)}
        )
        return False
    except Exception as exc:  # noqa: BLE001 - log anything unexpected, cleanly
        logger.error(
            "Unexpected Redis error during ping",
            extra={"redis_target": target, "error": str(exc)},
        )
        return False


def increment_pulse_count() -> int:
    """Increments the `pulse_count` key in Redis and returns the new value.

    Raises redis.exceptions.RedisError (or a subclass) on failure so the
    API layer can translate it into a clean HTTP 500 response.
    """
    target = f"{settings.REDIS_HOST}:{settings.REDIS_PORT}"
    logger.info("Incrementing pulse_count in Redis", extra={"redis_target": target})
    try:
        client = get_client()
        new_value = client.incr("pulse_count")
        logger.info(
            "pulse_count incremented",
            extra={"redis_target": target, "pulse_count": new_value},
        )
        return new_value
    except redis.exceptions.TimeoutError as exc:
        logger.error(
            "Redis INCR timed out", extra={"redis_target": target, "error": str(exc)}
        )
        raise
    except redis.exceptions.ConnectionError as exc:
        logger.error(
            "Redis connection failed during INCR",
            extra={"redis_target": target, "error": str(exc)},
        )
        raise
