from typing import Optional, Tuple

from google import genai
from google.genai import types

from app.core.config import settings


class GeminiService:
    """Service for analyzing images using Google Gemini API (New SDK)."""

    def __init__(self):
        # Initialize the new Google Gen AI client
        self.client = genai.Client(api_key=settings.gemini_api_key)
        self.model_name = "gemini-2.5-flash"

    async def analyze_image(self, image_bytes: bytes) -> Tuple[bool, Optional[int]]:
        """
        Analyze an image to determine if it's trash or a valid scene with density category.

        Args:
            image_bytes: Raw image bytes

        Returns:
            Tuple of (is_trash: bool, category: Optional[int])
            - If is_trash=True, category will be None
            - If is_trash=False, category will be 1-4

        Raises:
            ValueError: If the API response is invalid
            Exception: If the API call fails
        """
        try:
            # Prompt for Gemini
            prompt = """Analyze this image carefully:

1. First, determine if this is a TRASH image (invalid upload). TRASH includes:
   - Selfies or portraits of people
   - Memes, screenshots, or text-heavy images
   - Close-up photos of objects (not outdoor scenes)
   - Garbage or inappropriate content
   - Indoor scenes (we only want outdoor scenes)

2. If it's NOT trash, rate the density/crowding level of the scene from 1-4:
   - 1 = Low/Sparse: Very few objects or people, open space, minimal activity
   - 2 = Medium: Moderate number of objects/people, some activity
   - 3 = High: Many objects/people, busy scene, significant activity
   - 4 = Very High: Extremely crowded, dense with objects/people, very busy

OUTPUT ONLY ONE OF THESE:
- 'TRASH' if the image is invalid
- '1' if valid scene with low density
- '2' if valid scene with medium density
- '3' if valid scene with high density
- '4' if valid scene with very high density

Output only the single word or number, nothing else."""

            # Call Gemini API with new SDK
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=[
                    prompt,
                    types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
                ],
            )

            # Parse response
            result = response.text.strip().upper()

            if result == "TRASH":
                return (True, None)
            elif result in ["1", "2", "3", "4"]:
                category = int(result)
                return (False, category)
            else:
                # If response is unexpected, log it and treat as trash
                print(f"Unexpected Gemini response: {result}")
                # Try to extract a number
                for char in result:
                    if char in "1234":
                        return (False, int(char))
                # If no valid number found, treat as trash
                return (True, None)

        except Exception as e:
            print(f"Gemini API error: {e}")
            raise Exception(f"Failed to analyze image: {str(e)}")

    async def validate_and_categorize(
        self, image_bytes: bytes
    ) -> Tuple[bool, Optional[int], Optional[float]]:
        """
        Validate image and get category with weight.

        Args:
            image_bytes: Raw image bytes

        Returns:
            Tuple of (is_valid: bool, category: Optional[int], weight: Optional[float])
            - If is_valid=False, category and weight will be None
            - If is_valid=True, category will be 1-4 and weight will be category/4.0
        """
        is_trash, category = await self.analyze_image(image_bytes)

        if is_trash:
            return (False, None, None)

        weight = category / 4.0
        return (True, category, weight)


# Singleton instance
gemini_service = GeminiService()
