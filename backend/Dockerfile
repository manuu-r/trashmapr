# Use Python 3.12 slim image
FROM python:3.12-slim

# Set working directory
WORKDIR /app

# Install system dependencies for PostGIS and other libraries
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose port (Cloud Run uses PORT env var)
EXPOSE 8080

# Create entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Run entrypoint script
ENTRYPOINT ["/docker-entrypoint.sh"]

# Default command - use PORT env var with fallback to 8080 (Cloud Run requirement)
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}
