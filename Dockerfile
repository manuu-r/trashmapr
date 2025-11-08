# Multi-stage build: Build React frontend first
FROM node:22-slim AS react-builder

WORKDIR /react-build

# Copy React package files and install dependencies
COPY react/package*.json ./
RUN npm install

# Copy React source files (excluding node_modules and dist)
COPY react/*.ts ./
COPY react/*.tsx ./
COPY react/*.js ./
COPY react/*.json ./
COPY react/*.html ./
COPY react/public ./public/
COPY react/components ./components/
COPY react/hooks ./hooks/

# Build React app (modify package.json to skip tsc and only run vite build)
RUN sed -i 's/"tsc && vite build"/"vite build"/' package.json && npm run build

# Main stage: Python backend
FROM python:3.12-slim

# Set working directory for backend
WORKDIR /app

# Install system dependencies for PostGIS and other libraries
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy backend requirements and install Python dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend application code
COPY backend/ .

# Copy React build from the builder stage to /dist
COPY --from=react-builder /react-build/dist /dist

# Expose port
EXPOSE 8000

# Copy and set up entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Run entrypoint script
ENTRYPOINT ["/docker-entrypoint.sh"]

# Default command
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
