from typing import Optional, Tuple

from app.core.config import settings
from google import genai
from google.genai import types


class GeminiService:
    """Service for analyzing images using Google Gemini API."""

    def __init__(self):
        # Initialize the new Google Gen AI client with API key for AI Studio
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

            First, decide if this is a TRASH image (valid trash photo) or NOT TRASH (invalid upload).
            Mark as NOT TRASH if the image is:

            A selfie or portrait of a person

            A meme, screenshot, or text-heavy image

            An indoor scene

            A random object not related to waste

            Any inappropriate or irrelevant content

            If it IS a valid trash image, rate the trash amount/weight from 1–4:

            1 = Small / Light Trash: A few scattered items, minimal waste

            2 = Moderate Trash: Noticeable pile or bag, moderate amount

            3 = Heavy Trash: Large pile, multiple bags, visibly dense waste

            4 = Massive Trash: Huge dump site, overflowing bins, very large accumulation

            OUTPUT ONLY ONE OF THE FOLLOWING:

            'NOT TRASH' – if the image is invalid or irrelevant

            '1' – small/light trash

            '2' – moderate trash

            '3' – heavy trash

            '4' – massive trash

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
