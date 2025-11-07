from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.crud import get_points_in_bounds, get_user_points
from app.db.database import get_db
from app.db.models import User
from app.db.schemas import PointResponse
from app.services.auth import get_current_user

router = APIRouter()


@router.get("", response_model=List[PointResponse])
async def get_points(
    lat1: float = Query(..., ge=-90, le=90, description="Southwest latitude"),
    lng1: float = Query(..., ge=-180, le=180, description="Southwest longitude"),
    lat2: float = Query(..., ge=-90, le=90, description="Northeast latitude"),
    lng2: float = Query(..., ge=-180, le=180, description="Northeast longitude"),
    db: AsyncSession = Depends(get_db),
):
    """
    Get all points within a bounding box (public endpoint).
    Excludes trash-flagged images.

    Args:
        lat1: Southwest latitude
        lng1: Southwest longitude
        lat2: Northeast latitude
        lng2: Northeast longitude

    Returns:
        List of points within the bounding box
    """
    # Validate bounds
    if lat2 <= lat1:
        raise HTTPException(status_code=400, detail="lat2 must be greater than lat1")
    if lng2 <= lng1:
        raise HTTPException(status_code=400, detail="lng2 must be greater than lng1")

    points = await get_points_in_bounds(db, lat1, lng1, lat2, lng2)
    return points


@router.get("/my-uploads", response_model=List[PointResponse])
async def get_my_uploads(
    current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    """
    Get all uploads for the authenticated user (protected endpoint).

    Args:
        current_user: Authenticated user object

    Returns:
        List of user's uploaded points
    """
    points = await get_user_points(db, current_user.id)
    return points
