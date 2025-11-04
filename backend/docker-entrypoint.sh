#!/bin/bash
set -e

echo "==================================="
echo "TrashMapr API - Starting..."
echo "==================================="

# Wait for AlloyDB/Cloud SQL to be ready
echo "Checking database connection..."
max_retries=30
retry_count=0

while [ $retry_count -lt $max_retries ]; do
    if python -c "
import asyncio
import sys
from database import engine

async def check():
    try:
        async with engine.connect() as conn:
            result = await conn.execute('SELECT 1')
            return True
    except Exception as e:
        print(f'Database not ready: {e}', file=sys.stderr)
        return False

result = asyncio.run(check())
sys.exit(0 if result else 1)
" 2>/dev/null; then
        echo "✓ Database connection successful!"
        break
    fi

    retry_count=$((retry_count + 1))
    echo "⏳ Waiting for database... ($retry_count/$max_retries)"
    sleep 3
done

if [ $retry_count -eq $max_retries ]; then
    echo "❌ ERROR: Database connection timeout"
    echo "Please check:"
    echo "  - ALLOYDB_CONNECTION_URI is correct in .env"
    echo "  - AlloyDB instance is running and accessible"
    echo "  - Network connectivity to AlloyDB"
    echo "  - Cloud SQL Proxy is running (if using)"
    exit 1
fi

# Run database migrations
echo "Running database migrations..."
alembic upgrade head

if [ $? -eq 0 ]; then
    echo "✓ Migrations completed successfully!"
else
    echo "❌ ERROR: Migration failed"
    exit 1
fi

echo "==================================="
echo "✓ All checks passed!"
echo "Starting application server..."
echo "==================================="

# Execute the CMD from Dockerfile
exec "$@"
