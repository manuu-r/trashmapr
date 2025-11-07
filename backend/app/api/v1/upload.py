from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.crud import (
    create_point,
    decrement_user_points,
    delete_point,
    get_point_by_id,
    increment_user_points,
)
from app.db.database import get_db
from app.db.models import User
from app.db.schemas import PointCreate, UploadResponse
from app.services.auth import get_current_user
from app.services.gemini_service import gemini_service
from app.services.storage_service import storage_service

router = APIRouter()


@router.post("", response_model=UploadResponse)
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
    print(
        f"Upload request - User: {current_user.email}, Lat: {lat}, Lng: {lng}, File: {file.filename}, Content-Type: {file.content_type}"
    )

    # Validate file type
    if not file.content_type or not file.content_type.startswith("image/"):
        print(f"Invalid file type: {file.content_type}")
        raise HTTPException(
            status_code=400, detail="Invalid file type. Only images are allowed."
        )

    try:
        # Read image bytes
        print("Reading image bytes...")
        image_bytes = await file.read()
        print(f"Image size: {len(image_bytes)} bytes")

        # Validate and categorize with Gemini
        print("Validating with Gemini...")
        is_valid, category, weight = await gemini_service.validate_and_categorize(
            image_bytes
        )
        print(
            f"Gemini result - Valid: {is_valid}, Category: {category}, Weight: {weight}"
        )

        if not is_valid:
            print("Image rejected by Gemini")
            raise HTTPException(
                status_code=400,
                detail="Image rejected: This appears to be a trash image (selfie, meme, or non-scene image). Please upload outdoor scene photos only.",
            )

        # Upload to GCS (use email for folder organization)
        print(f"Uploading to GCS for user: {current_user.email}")
        image_url = await storage_service.upload_image(
            image_bytes, current_user.email, file.content_type
        )
        print(f"Uploaded to: {image_url}")

        # Create point in database
        print("Creating point in database...")
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
        print(f"Point created with ID: {new_point.id}")

        # Increment user points (250 points per upload)
        await increment_user_points(db, current_user.id, points=250)
        print(f"User {current_user.email} earned 250 points")

        return UploadResponse(
            success=True,
            message="Image uploaded successfully",
            point_id=new_point.id,
            category=category,
            weight=weight,
        )

    except HTTPException as he:
        print(f"HTTPException: {he.status_code} - {he.detail}")
        raise
    except Exception as e:
        import traceback

        print(f"Upload error: {e}")
        print(traceback.format_exc())
        raise HTTPException(
            status_code=500, detail=f"Failed to process upload: {str(e)}"
        )


@router.delete("/{point_id}")
async def delete_upload(
    point_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Delete an uploaded point and its associated image (protected endpoint).
    Users can only delete their own uploads.

    Args:
        point_id: ID of the point to delete
        current_user: Authenticated user object
        db: Database session

    Returns:
        Success message
    """
    print(f"Delete request - User: {current_user.email}, Point ID: {point_id}")

    # Get the point
    point = await get_point_by_id(db, point_id)

    if not point:
        print(f"Point {point_id} not found")
        raise HTTPException(status_code=404, detail="Point not found")

    # Verify ownership
    if point.user_id != current_user.id:
        print(
            f"Unauthorized delete attempt - Point owner: {point.user_id}, Requester: {current_user.id}"
        )
        raise HTTPException(
            status_code=403, detail="You can only delete your own uploads"
        )

    try:
        # Delete image from storage bucket
        print(f"Deleting image from storage: {point.image_url}")
        image_deleted = await storage_service.delete_image(point.image_url)
        if image_deleted:
            print("Image deleted from storage successfully")
        else:
            print("Image not found in storage or already deleted")

        # Delete point from database
        print(f"Deleting point {point_id} from database")
        deleted = await delete_point(db, point_id)

        if not deleted:
            raise HTTPException(status_code=500, detail="Failed to delete point")

        # Decrement user points (subtract 250 points)
        await decrement_user_points(db, current_user.id, points=250)
        print(f"User {current_user.email} lost 250 points for deletion")

        print(f"Point {point_id} deleted successfully")
        return {
            "success": True,
            "message": "Upload deleted successfully",
            "point_id": point_id,
        }

    except HTTPException:
        raise
    except Exception as e:
        import traceback

        print(f"Delete error: {e}")
        print(traceback.format_exc())
        raise HTTPException(
            status_code=500, detail=f"Failed to delete upload: {str(e)}"
        )
