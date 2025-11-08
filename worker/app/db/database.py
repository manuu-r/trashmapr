from contextlib import asynccontextmanager
from typing import AsyncGenerator

from app.core.config import settings
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

# Create async engine using centralized configuration
engine = create_async_engine(
    settings.database_url,
    echo=settings.db_echo,  # SQL query logging
    future=True,
    pool_pre_ping=True,  # Verify connections before using them
    pool_size=settings.db_pool_size,
    max_overflow=settings.db_max_overflow,
)

# Create async session factory
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


@asynccontextmanager
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Context manager for database sessions.
    Use with async context manager: async with get_db() as db:
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()


async def init_db():
    """
    Initialize database connection.
    Run this on application startup to verify connection.
    """
    try:
        async with engine.begin() as conn:
            # Test connection
            await conn.execute(text("SELECT 1"))
        print("Database connection successful")
    except Exception as e:
        print(f"Database connection failed: {e}")
        raise
