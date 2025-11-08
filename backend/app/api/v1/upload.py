from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.crud import (
    decrement_user_points,
    delete_point,
    get_point_by_id,
)
from app.db.database import get_db
from app.db.models import User
from app.services.auth import get_current_user
from app.services.storage_service import storage_service

router = APIRouter()


@router.post("/signed-url")
async def generate_signed_url(
    lat: float = Query(..., ge=-90, le=90, description="Latitude"),
    lng: float = Query(..., ge=-180, le=180, description="Longitude"),
    content_type: str = Query(
        "image/jpeg", regex="^image/(jpeg|jpg|png)$", description="Image MIME type"
    ),
    current_user: User = Depends(get_current_user),
):
    """
    Generate a signed URL for direct client upload to GCS (protected endpoint).

    This endpoint allows clients to upload images directly to Google Cloud Storage
    without going through the backend server. The signed URL includes custom metadata
    (user_id, latitude, longitude) that will trigger the processing worker via Pub/Sub.

    Workflow:
    1. Client requests signed URL with GPS coordinates
    2. Backend generates unique filename and signed URL with metadata
    3. Client uploads image directly to GCS using the signed URL
    4. GCS triggers Pub/Sub notification
    5. Worker processes the image asynchronously

    Args:
        lat: Latitude coordinate
        lng: Longitude coordinate
        content_type: MIME type of the image (default: image/jpeg)
        current_user: Authenticated user object

    Returns:
        upload_url: Signed URL for PUT request
        file_name: Generated filename for tracking
        expires_in: Seconds until URL expires (900 = 15 minutes)
    """
    print(
        f"Signed URL request - User: {current_user.email}, Lat: {lat}, Lng: {lng}, Content-Type: {content_type}"
    )

    try:
        # Generate unique filename
        file_name = storage_service.generate_filename(current_user.email)
        print(f"Generated filename: {file_name}")

        # Generate signed URL with custom metadata
        signed_url, required_headers = storage_service.generate_signed_upload_url(
            file_name=file_name,
            content_type=content_type,
            user_id=current_user.id,
            latitude=lat,
            longitude=lng,
        )
        print(f"Generated signed URL (expires in 15 minutes)")

        return {
            "upload_url": signed_url,
            "file_name": file_name,
            "expires_in": 900,
            "required_headers": required_headers,
        }

    except Exception as e:
        import traceback

        print(f"Signed URL generation error: {e}")
        print(traceback.format_exc())
        raise HTTPException(
            status_code=500, detail=f"Failed to generate signed URL: {str(e)}"
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
