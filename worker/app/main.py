import base64
import json
import logging
from contextlib import asynccontextmanager

from app.core.config import settings
from app.db.crud import create_point_with_user_update, get_user_by_id
from app.db.database import engine, get_db
from app.services.fcm_service import (
    initialize_firebase,
    send_image_accepted_notification,
    send_image_rejected_notification,
)
from app.services.gemini_service import GeminiService
from app.services.storage_service import StorageService
from fastapi import FastAPI, HTTPException, Request

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Initialize services
gemini_service = GeminiService()
storage_service = StorageService()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup/shutdown events."""
    logger.info("Worker starting up...")
    initialize_firebase()
    yield
    logger.info("Worker shutting down...")
    await engine.dispose()


app = FastAPI(
    title="TrashMapr Worker",
    description="Async image processing worker for TrashMapr",
    version="1.0.0",
    lifespan=lifespan,
)


@app.post("/process-upload")
async def process_upload(request: Request):
    """
    Pub/Sub push endpoint for processing uploaded images.

    Expected message format from GCS via Pub/Sub:
    {
      "message": {
        "data": "<base64-encoded-json>",
        "attributes": {...},
        "messageId": "...",
        "publishTime": "..."
      },
      "subscription": "..."
    }

    The decoded data contains GCS object notification:
    {
      "name": "uploads/user_email/file.jpg",
      "bucket": "garbage-pics",
      "contentType": "image/jpeg",
      "metadata": {
        "user_id": "42",
        "latitude": "12.9716",
        "longitude": "77.5946",
        "uploaded_at": "2025-01-07T14:30:25Z"
      }
    }
    """
    try:
        # Parse Pub/Sub message
        body = await request.json()
        logger.info(
            f"Received Pub/Sub message: {body.get('message', {}).get('messageId', 'unknown')}"
        )

        message = body.get("message", {})
        if not message:
            logger.error("No message in request body")
            raise HTTPException(status_code=400, detail="No message in request")

        # Decode base64 data
        encoded_data = message.get("data")
        if not encoded_data:
            logger.error("No data in message")
            raise HTTPException(status_code=400, detail="No data in message")

        decoded_data = base64.b64decode(encoded_data).decode("utf-8")
        data = json.loads(decoded_data)

        logger.info(f"Decoded GCS notification: {data.get('name', 'unknown')}")

        # Extract file information
        file_name = data.get("name")
        bucket_name = data.get("bucket")
        metadata = data.get("metadata", {})

        if not file_name:
            logger.error("No file name in notification")
            raise HTTPException(status_code=400, detail="No file name in notification")

        # Extract metadata (custom metadata from signed URL)
        try:
            user_id = int(metadata.get("user_id"))
            latitude = float(metadata.get("latitude"))
            longitude = float(metadata.get("longitude"))
        except (ValueError, TypeError, KeyError) as e:
            logger.error(f"Invalid metadata: {metadata}, error: {e}")
            raise HTTPException(status_code=400, detail=f"Invalid metadata: {str(e)}")

        logger.info(
            f"Processing upload - User ID: {user_id}, Location: ({latitude}, {longitude})"
        )

        # Download image from GCS
        logger.info(f"Downloading image from GCS: {file_name}")
        image_bytes = storage_service.download_image(file_name)
        logger.info(f"Downloaded {len(image_bytes)} bytes")

        # Analyze with Gemini
        logger.info("Analyzing image with Gemini API...")
        is_valid, category, weight = await gemini_service.validate_and_categorize(
            image_bytes
        )
        logger.info(
            f"Gemini result - Valid: {is_valid}, Category: {category}, Weight: {weight}"
        )

        if not is_valid:
            # Delete rejected image
            logger.warning(f"Image rejected by Gemini: {file_name}")
            deleted = await storage_service.delete_image_by_name(file_name)
            logger.info(f"Rejected image deleted: {deleted}")

            # Send rejection notification to user
            async with get_db() as db:
                user = await get_user_by_id(db, user_id)
                if user and user.fcm_token:
                    logger.info(f"Sending rejection notification to user {user_id}")
                    await send_image_rejected_notification(
                        token=user.fcm_token,
                        reason="Image doesn't meet quality standards",
                    )
                else:
                    logger.info(
                        f"No FCM token for user {user_id}, skipping notification"
                    )

            return {
                "status": "rejected",
                "file_name": file_name,
                "message": "Image rejected by AI validation",
            }

        # Save to database
        logger.info("Saving point to database...")
        async with get_db() as db:
            image_url = f"https://storage.googleapis.com/{bucket_name}/{file_name}"

            # Create point and update user stats in single transaction
            new_point, user = await create_point_with_user_update(
                db=db,
                user_id=user_id,
                image_url=image_url,
                latitude=latitude,
                longitude=longitude,
                weight=weight,
                category=category,
            )

            logger.info(f"Point created successfully - ID: {new_point.id}")

            # Send acceptance notification to user
            if user and user.fcm_token:
                logger.info(f"Sending acceptance notification to user {user_id}")
                await send_image_accepted_notification(
                    token=user.fcm_token,
                    category=category,
                    weight=weight,
                    points_earned=250,
                )
            else:
                logger.info(f"No FCM token for user {user_id}, skipping notification")

        return {
            "status": "success",
            "point_id": new_point.id,
            "category": category,
            "weight": weight,
            "user_id": user_id,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Worker error: {str(e)}", exc_info=True)
        # Return 500 to trigger Pub/Sub retry
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
async def health_check():
    """Health check endpoint for Cloud Run."""
    return {"status": "healthy", "service": "trashmapr-worker", "version": "1.0.0"}


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "service": "TrashMapr Worker",
        "description": "Async image processing worker",
        "endpoints": {"health": "/health", "process": "/process-upload"},
    }
