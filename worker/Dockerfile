# Multi-stage build for TrashMapr Worker
FROM python:3.12-slim as base

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ app/

# Create non-root user for security
RUN useradd -m -u 1000 worker && chown -R worker:worker /app
USER worker

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8080}/health || exit 1

# Expose port (Cloud Run uses PORT env var)
EXPOSE 8080

# Run the application
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080} --workers 1
