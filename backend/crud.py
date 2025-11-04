from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, text
from sqlalchemy.orm import selectinload
from typing import List, Optional
from models import Point, User
from schemas import PointCreate, PointResponse, LocationSchema, UserCreate, UserResponse
from geoalchemy2.functions import (
    ST_MakePoint,
    ST_Intersects,
    ST_MakeEnvelope,
    ST_X,
    ST_Y,
)
from geoalchemy2.elements import WKBElement


# ==================== USER OPERATIONS ====================


async def create_user(db: AsyncSession, user_data: UserCreate) -> User:
    """
    Create a new user in the database.

    Args:
        db: Database session
        user_data: User creation data

    Returns:
        Created User object
    """
    new_user = User(
        email=user_data.email,
        name=user_data.name,
        picture=user_data.picture,
    )

    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)

    return new_user


async def get_user_by_email(db: AsyncSession, email: str) -> Optional[User]:
    """
    Get a user by their email address.

    Args:
        db: Database session
        email: User email

    Returns:
        User object or None
    """
    query = select(User).where(User.email == email)
    result = await db.execute(query)
    return result.scalar_one_or_none()


async def get_user_by_id(db: AsyncSession, user_id: int) -> Optional[User]:
    """
    Get a user by their ID.

    Args:
        db: Database session
        user_id: User ID

    Returns:
        User object or None
    """
    query = select(User).where(User.id == user_id)
    result = await db.execute(query)
    return result.scalar_one_or_none()


async def get_or_create_user(
    db: AsyncSession,
    email: str,
    name: Optional[str] = None,
    picture: Optional[str] = None,
) -> User:
    """
    Get an existing user or create a new one.

    Args:
        db: Database session
        email: User email
        name: User name (optional)
        picture: User picture URL (optional)

    Returns:
        User object
    """
    user = await get_user_by_email(db, email)

    if user:
        # Update user info if provided
        if name and user.name != name:
            user.name = name
        if picture and user.picture != picture:
            user.picture = picture
        if name or picture:
            await db.commit()
            await db.refresh(user)
        return user

    # Create new user
    user_data = UserCreate(email=email, name=name, picture=picture)
    return await create_user(db, user_data)


async def update_user(
    db: AsyncSession,
    user_id: int,
    name: Optional[str] = None,
    picture: Optional[str] = None,
) -> Optional[User]:
    """
    Update user information.

    Args:
        db: Database session
        user_id: User ID
        name: Updated name (optional)
        picture: Updated picture URL (optional)

    Returns:
        Updated User object or None
    """
    user = await get_user_by_id(db, user_id)

    if not user:
        return None

    if name is not None:
        user.name = name
    if picture is not None:
        user.picture = picture

    await db.commit()
    await db.refresh(user)

    return user


# ==================== POINT OPERATIONS ====================


async def create_point(db: AsyncSession, point_data: PointCreate) -> Point:
    """
    Create a new point in the database.

    Args:
        db: Database session
        point_data: Point creation data

    Returns:
        Created Point object
    """
    # Create point using PostGIS function
    point_geom = ST_MakePoint(point_data.lng, point_data.lat)

    new_point = Point(
        user_id=point_data.user_id,
        image_url=point_data.image_url,
        location=point_geom,
        weight=point_data.weight,
        category=point_data.category,
        is_trash=point_data.is_trash,
    )

    db.add(new_point)
    await db.commit()
    await db.refresh(new_point)

    return new_point


async def get_points_in_bounds(
    db: AsyncSession,
    lat1: float,
    lng1: float,
    lat2: float,
    lng2: float,
) -> List[PointResponse]:
    """
    Get all points within a bounding box.
    Excludes trash images (is_trash=False).

    Args:
        db: Database session
        lat1: Southwest latitude
        lng1: Southwest longitude
        lat2: Northeast latitude
        lng2: Northeast longitude

    Returns:
        List of PointResponse objects
    """
    # Create bounding box envelope (lng1, lat1, lng2, lat2)
    bbox = ST_MakeEnvelope(lng1, lat1, lng2, lat2, 4326)

    # Query points that intersect with bounding box
    query = (
        select(Point)
        .where(
            ST_Intersects(Point.location, bbox),
            Point.is_trash == False,  # Exclude trash images
        )
        .order_by(Point.timestamp.desc())
    )

    result = await db.execute(query)
    points = result.scalars().all()

    # Convert to response format
    response_points = []
    for point in points:
        # Extract lat/lng from geography point
        lat_query = select(ST_Y(Point.location)).where(Point.id == point.id)
        lng_query = select(ST_X(Point.location)).where(Point.id == point.id)

        lat_result = await db.execute(lat_query)
        lng_result = await db.execute(lng_query)

        lat = lat_result.scalar()
        lng = lng_result.scalar()

        response_points.append(
            PointResponse(
                id=point.id,
                image_url=point.image_url,
                location=LocationSchema(lat=lat, lng=lng),
                weight=point.weight,
                category=point.category,
                timestamp=point.timestamp,
                user_id=point.user_id,
            )
        )

    return response_points


async def get_user_points(db: AsyncSession, user_id: int) -> List[PointResponse]:
    """
    Get all points uploaded by a specific user.
    Includes both valid and trash-flagged images.

    Args:
        db: Database session
        user_id: User ID

    Returns:
        List of PointResponse objects
    """
    query = (
        select(Point).where(Point.user_id == user_id).order_by(Point.timestamp.desc())
    )

    result = await db.execute(query)
    points = result.scalars().all()

    # Convert to response format
    response_points = []
    for point in points:
        # Extract lat/lng from geography point
        lat_query = select(ST_Y(Point.location)).where(Point.id == point.id)
        lng_query = select(ST_X(Point.location)).where(Point.id == point.id)

        lat_result = await db.execute(lat_query)
        lng_result = await db.execute(lng_query)

        lat = lat_result.scalar()
        lng = lng_result.scalar()

        response_points.append(
            PointResponse(
                id=point.id,
                image_url=point.image_url,
                location=LocationSchema(lat=lat, lng=lng),
                weight=point.weight,
                category=point.category,
                timestamp=point.timestamp,
                user_id=point.user_id,
            )
        )

    return response_points


async def get_point_by_id(db: AsyncSession, point_id: int) -> Optional[Point]:
    """
    Get a point by its ID.

    Args:
        db: Database session
        point_id: Point ID

    Returns:
        Point object or None
    """
    query = select(Point).where(Point.id == point_id)
    result = await db.execute(query)
    return result.scalar_one_or_none()
