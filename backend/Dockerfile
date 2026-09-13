# --- System Pulse Backend: minimal, production-ready image ---
FROM python:3.11-slim

# Prevents Python from buffering stdout, which would delay/batch the
# structured logs this app relies on for external tracing.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install dependencies first to maximize Docker layer caching.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Run as a non-root user (good practice, and a prerequisite for most
# Kubernetes PodSecurity policies).
RUN useradd --create-home --uid 1000 appuser
COPY app ./app
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Simple liveness check for docker-compose / local orchestration.
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/health')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
