from google.cloud import storage
from typing import Tuple
import uuid
from datetime import datetime
from config import settings


class StorageService:
    """Service for handling Google Cloud Storage operations."""

    def __init__(self):
        self.client = storage.Client()
        self.bucket = self.client.bucket(settings.gcs_bucket_name)

    async def upload_image(
        self, image_bytes: bytes, user_id: str, content_type: str = "image/jpeg"
    ) -> str:
        """
        Upload an image to GCS and return its public URL.

        Args:
            image_bytes: Raw image bytes
            user_id: User ID (email) for organizing uploads
            content_type: MIME type of the image

        Returns:
            Public URL of the uploaded image

        Raises:
            Exception: If upload fails
        """
        try:
            # Generate unique filename
            timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
            unique_id = uuid.uuid4().hex[:8]
            # Sanitize user_id for filename (replace @ and . with _)
            safe_user_id = user_id.replace("@", "_").replace(".", "_")
            filename = f"uploads/{safe_user_id}/{timestamp}_{unique_id}.jpg"

            # Create blob
            blob = self.bucket.blob(filename)

            # Set content type
            blob.content_type = content_type

            # Upload bytes
            blob.upload_from_string(image_bytes, content_type=content_type)

            # Make blob publicly accessible
            blob.make_public()

            # Return public URL
            return blob.public_url

        except Exception as e:
            print(f"GCS upload error: {e}")
            raise Exception(f"Failed to upload image: {str(e)}")

    async def delete_image(self, image_url: str) -> bool:
        """
        Delete an image from GCS by its public URL.

        Args:
            image_url: Public URL of the image

        Returns:
            True if deleted successfully, False otherwise
        """
        try:
            # Extract blob name from URL
            # Format: https://storage.googleapis.com/bucket-name/path/to/file.jpg
            if settings.gcs_bucket_name not in image_url:
                return False

            blob_name = image_url.split(f"{settings.gcs_bucket_name}/")[1]
            blob = self.bucket.blob(blob_name)

            if blob.exists():
                blob.delete()
                return True
            return False

        except Exception as e:
            print(f"GCS delete error: {e}")
            return False


# Singleton instance
storage_service = StorageService()
