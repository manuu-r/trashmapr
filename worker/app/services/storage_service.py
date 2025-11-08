from app.core.config import settings
from google.cloud import storage


class StorageService:
    """Service for handling Google Cloud Storage operations in worker."""

    def __init__(self):
        self.client = storage.Client()
        self.bucket = self.client.bucket(settings.gcs_bucket_name)

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

    async def delete_image_by_name(self, file_name: str) -> bool:
        """
        Delete an image from GCS by filename.

        Args:
            file_name: GCS blob name (e.g., "uploads/user_email/file.jpg")

        Returns:
            True if deleted successfully, False otherwise
        """
        try:
            blob = self.bucket.blob(file_name)
            if blob.exists():
                blob.delete()
                return True
            return False
        except Exception as e:
            print(f"GCS delete error: {e}")
            return False


# Singleton instance
storage_service = StorageService()
