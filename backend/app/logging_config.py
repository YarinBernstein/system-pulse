"""
Structured stdout logging setup.

System Pulse is meant to be traced by an external network-debugging tool,
so every log line is emitted as a single-line JSON object to stdout. That
makes it trivially parseable by log shippers, `docker logs | jq`, etc.,
without needing any special log-format configuration.
"""
import json
import logging
import sys
import time
from typing import Any

from app.config import settings


class JsonFormatter(logging.Formatter):
    """Formats every log record as a single-line JSON object."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(record.created)),
            "level": record.levelname,
            "service": settings.SERVICE_NAME,
            "logger": record.name,
            "message": record.getMessage(),
        }

        # Merge any structured extras passed via `logger.info(msg, extra={...})`
        reserved = set(logging.LogRecord("", 0, "", 0, "", (), None).__dict__.keys())
        for key, value in record.__dict__.items():
            if key not in reserved and key not in payload:
                payload[key] = value

        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)

        return json.dumps(payload, default=str)


def configure_logging() -> None:
    """Configures the root logger to emit JSON lines to stdout exactly once."""
    root = logging.getLogger()
    root.setLevel(settings.LOG_LEVEL)

    # Avoid duplicate handlers if this is called more than once (e.g. reload).
    root.handlers.clear()

    handler = logging.StreamHandler(stream=sys.stdout)
    handler.setFormatter(JsonFormatter())
    root.addHandler(handler)

    # Quiet down noisy third-party loggers but keep uvicorn's access log,
    # since request-level visibility is exactly what the tracing tool wants.
    logging.getLogger("uvicorn.error").setLevel(settings.LOG_LEVEL)
    logging.getLogger("uvicorn.access").setLevel(settings.LOG_LEVEL)
