from fastapi import FastAPI, UploadFile, File, Depends, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
import uvicorn

from config import settings
from database import get_db, init_db
from schemas import PointResponse, UploadResponse, BoundsQuery, UserResponse
from crud import create_point, get_points_in_bounds, get_user_points
from auth import get_current_user
from gemini_service import gemini_service
from storage_service import storage_service
from schemas import PointCreate
from models import User

# Initialize FastAPI app with settings from config
app = FastAPI(
    title=settings.app_name,
    description="Geo-tagged photo app with AI-powered trash classification",
    version=settings.app_version,
    debug=settings.debug,
)

# CORS middleware configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event():
    """Initialize database connection on startup."""
    await init_db()
    print("Application startup complete")


@app.get("/")
async def root():
    """Root endpoint - API health check."""
    return {
        "message": settings.app_name,
        "status": "online",
        "version": settings.app_version,
        "environment": "production" if settings.is_production else "development",
    }


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy"}


@app.get("/points", response_model=List[PointResponse])
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


@app.post("/upload", response_model=UploadResponse)
async def upload_image(
    file: UploadFile = File(...),
    lat: float = Query(..., ge=-90, le=90, description="Latitude"),
    lng: float = Query(..., ge=-180, le=180, description="Longitude"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Upload an image with GPS location (protected endpoint).

    Workflow:
    1. Upload image to GCS
    2. Analyze with Gemini API
    3. If trash, reject and return error
    4. If valid, save to database with category and weight

    Args:
        file: Image file
        lat: Latitude coordinate
        lng: Longitude coordinate
        current_user: Authenticated user object

    Returns:
        Upload response with point details
    """
    # Validate file type
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400, detail="Invalid file type. Only images are allowed."
        )

    try:
        # Read image bytes
        image_bytes = await file.read()

        # Validate and categorize with Gemini
        is_valid, category, weight = await gemini_service.validate_and_categorize(
            image_bytes
        )

        if not is_valid:
            raise HTTPException(
                status_code=400,
                detail="Image rejected: This appears to be a trash image (selfie, meme, or non-scene image). Please upload outdoor scene photos only.",
            )

        # Upload to GCS (use email for folder organization)
        image_url = await storage_service.upload_image(
            image_bytes, current_user.email, file.content_type
        )

        # Create point in database
        point_data = PointCreate(
            user_id=current_user.id,
            image_url=image_url,
            lat=lat,
            lng=lng,
            weight=weight,
            category=category,
            is_trash=False,
        )

        new_point = await create_point(db, point_data)

        return UploadResponse(
            success=True,
            message="Image uploaded successfully",
            point_id=new_point.id,
            category=category,
            weight=weight,
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Upload error: {e}")
        raise HTTPException(
            status_code=500, detail=f"Failed to process upload: {str(e)}"
        )


@app.get("/my-uploads", response_model=List[PointResponse])
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


@app.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """
    Get current user information (protected endpoint).

    Args:
        current_user: Authenticated user object

    Returns:
        User information
    """
    return UserResponse.model_validate(current_user)


if __name__ == "__main__":
    # For local development
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=settings.debug)
