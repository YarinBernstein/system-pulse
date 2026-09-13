"""
Centralized configuration for the System Pulse backend.

All values are sourced from environment variables so that the same
container image can be reused unmodified across environments
(local docker-compose, staging, Kubernetes, etc). Nothing here should
ever hardcode a hostname or port.
"""
import os


class Settings:
    # --- Service identity (useful for log correlation / tracing tools) ---
    SERVICE_NAME: str = os.getenv("SERVICE_NAME", "system-pulse-backend")

    # --- HTTP server ---
    HOST: str = os.getenv("BACKEND_HOST", "0.0.0.0")
    PORT: int = int(os.getenv("BACKEND_PORT", "8000"))

    # --- CORS ---
    # Comma-separated list of allowed origins. "*" allows everything (fine for a demo app).
    CORS_ORIGINS: list[str] = os.getenv("CORS_ORIGINS", "*").split(",")

    # --- Redis connection ---
    REDIS_HOST: str = os.getenv("REDIS_HOST", "redis")
    REDIS_PORT: int = int(os.getenv("REDIS_PORT", "6379"))
    REDIS_DB: int = int(os.getenv("REDIS_DB", "0"))
    # Timeouts are kept short and explicit so failures surface quickly and
    # predictably in logs, which matters a lot for a network-tracing target app.
    REDIS_CONNECT_TIMEOUT: float = float(os.getenv("REDIS_CONNECT_TIMEOUT", "2"))
    REDIS_SOCKET_TIMEOUT: float = float(os.getenv("REDIS_SOCKET_TIMEOUT", "2"))

    # --- Logging ---
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO").upper()


settings = Settings()
