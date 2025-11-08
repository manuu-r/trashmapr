"""
CRUD operations for worker service.
Handles database operations for points and users.
"""

import logging
from typing import Optional, Tuple

from app.db.models import Point, User
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)


async def create_point_with_user_update(
    db: AsyncSession,
    user_id: int,
    image_url: str,
    latitude: float,
    longitude: float,
    weight: float,
    category: int,
) -> Tuple[Point, Optional[User]]:
    """
    Create a new point and update user statistics in a single transaction.

    Args:
        db: Database session
        user_id: User ID
        image_url: URL of uploaded image in GCS
        latitude: GPS latitude
        longitude: GPS longitude
        weight: Category weight (0.25 to 1.0)
        category: Density category (1-4)

    Returns:
        Tuple of (created_point, updated_user)
        User may be None if user_id doesn't exist

    Raises:
        Exception: If database operations fail
    """
    try:
        # Create point with PostGIS POINT format (longitude, latitude)
        new_point = Point(
            user_id=user_id,
            image_url=image_url,
            location=f"POINT({longitude} {latitude})",
            weight=weight,
            category=category,
            is_trash=False,
        )

        db.add(new_point)

        # Update user points and upload count
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()

        if user:
            user.total_points = (user.total_points or 0) + 250
            user.total_uploads = (user.total_uploads or 0) + 1
            logger.info(
                f"Updated user {user.email}: {user.total_points} points, "
                f"{user.total_uploads} uploads"
            )
        else:
            logger.warning(f"User {user_id} not found in database")

        # Commit transaction
        await db.commit()

        # Refresh to get auto-generated fields
        await db.refresh(new_point)

        return new_point, user

    except Exception as e:
        logger.error(f"Failed to create point: {e}", exc_info=True)
        await db.rollback()
        raise


async def get_user_by_id(db: AsyncSession, user_id: int) -> Optional[User]:
    """
    Get user by ID.

    Args:
        db: Database session
        user_id: User ID

    Returns:
        User object or None if not found
    """
    try:
        result = await db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()
    except Exception as e:
        logger.error(f"Failed to get user {user_id}: {e}", exc_info=True)
        raise


async def increment_user_stats(
    db: AsyncSession, user_id: int, points: int = 250, uploads: int = 1
) -> Optional[User]:
    """
    Increment user points and upload count.

    Args:
        db: Database session
        user_id: User ID
        points: Points to add (default: 250)
        uploads: Upload count to add (default: 1)

    Returns:
        Updated user object or None if not found
    """
    try:
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()

        if user:
            user.total_points = (user.total_points or 0) + points
            user.total_uploads = (user.total_uploads or 0) + uploads
            await db.commit()
            await db.refresh(user)
            logger.info(
                f"Incremented user {user.email} stats: +{points} points, +{uploads} uploads"
            )
            return user
        else:
            logger.warning(f"User {user_id} not found")
            return None

    except Exception as e:
        logger.error(f"Failed to increment user stats: {e}", exc_info=True)
        await db.rollback()
        raise
