import random
import string
from datetime import datetime, timedelta

from google.auth import default
from google.auth.transport import requests as auth_requests
from google.cloud import storage

from app.core.config import settings


class StorageService:
    """Service for handling Google Cloud Storage operations."""

    def __init__(self):
        self.client = storage.Client()
        self.bucket = self.client.bucket(settings.gcs_bucket_name)

        # Get default credentials for IAM signing on Cloud Run
        self.credentials, _ = default()
        self.auth_request = auth_requests.Request()

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

    def generate_filename(self, user_email: str) -> str:
        """
        Generate unique filename for upload.
        Format: uploads/{user_email}/{YYYYMMDD_HHMMSS}_{random}.jpg

        Args:
            user_email: User's email address

        Returns:
            Generated filename path
        """
        safe_email = user_email.replace("@", "_").replace(".", "_")
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        random_id = "".join(random.choices(string.ascii_lowercase + string.digits, k=8))
        return f"uploads/{safe_email}/{timestamp}_{random_id}.jpg"

    def generate_signed_upload_url(
        self,
        file_name: str,
        content_type: str,
        user_id: int,
        latitude: float,
        longitude: float,
    ) -> tuple[str, dict[str, str]]:
        """
        Generate signed URL for client-side upload with custom metadata.

        Custom metadata keys:
        - x-goog-meta-user_id: int
        - x-goog-meta-latitude: float
        - x-goog-meta-longitude: float
        - x-goog-meta-uploaded_at: ISO timestamp

        Args:
            file_name: Destination filename in GCS
            content_type: MIME type of the image
            user_id: User's database ID
            latitude: GPS latitude
            longitude: GPS longitude

        Returns:
            Tuple of (signed_url, required_headers)
        """
        blob = self.bucket.blob(file_name)

        # Custom metadata that will be attached to the blob
        metadata = {
            "user_id": str(user_id),
            "latitude": str(latitude),
            "longitude": str(longitude),
            "uploaded_at": datetime.utcnow().isoformat(),
        }

        # Headers that must be sent with the upload
        required_headers = {
            f"x-goog-meta-{key}": value for key, value in metadata.items()
        }

        # For Cloud Run: Use IAM-based signing since compute engine credentials don't have private keys
        # Refresh credentials to get a valid access token
        if not self.credentials.valid:
            self.credentials.refresh(self.auth_request)

        # Generate signed URL for PUT operation using IAM signing
        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=15),
            method="PUT",
            content_type=content_type,
            headers=required_headers,
            service_account_email=self.credentials.service_account_email,
            access_token=self.credentials.token,
        )

        return signed_url, required_headers

    def download_image(self, file_name: str) -> bytes:
        """
        Download an image from GCS by filename.

        Args:
            file_name: GCS blob name (e.g., "uploads/user_email/file.jpg")

        Returns:
            Image bytes

        Raises:
            Exception: If download fails
        """
        try:
            blob = self.bucket.blob(file_name)
            if not blob.exists():
                raise Exception(f"File not found: {file_name}")
            return blob.download_as_bytes()
        except Exception as e:
            print(f"GCS download error: {e}")
            raise Exception(f"Failed to download image: {str(e)}")


# Singleton instance
storage_service = StorageService()
