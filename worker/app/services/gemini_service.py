from typing import Optional, Tuple

from app.core.config import settings
from google import genai
from google.genai import types


class GeminiService:
    """Service for analyzing images using Google Gemini API."""

    def __init__(self):
        self.client = genai.Client(api_key=settings.gemini_api_key)
        self.model_name = "gemini-2.5-flash"

    async def analyze_image(
        self, image_bytes: bytes
    ) -> Tuple[bool, Optional[int], Optional[float]]:
        """
        Analyze an image to determine if it contains trash and its density.

        Args:
            image_bytes: Raw image bytes

        Returns:
            Tuple of (is_valid: bool, category: Optional[int], weight: Optional[float])
            - is_valid=True: Image contains trash, category is 1-4, weight is density (0.25-1.0)
            - is_valid=False: Image is invalid (not trash), category and weight are None

        Raises:
            Exception: If the API call fails
        """
        try:
            prompt = """Analyze this image carefully:

First, decide if this is a valid trash/waste image or NOT.
Mark as NOT TRASH if the image is:
- A selfie or portrait of a person
- A meme, screenshot, or text-heavy image
- An indoor scene
- A random object not related to waste
- Any inappropriate or irrelevant content

If it IS a valid trash image, rate the trash density from 1-4:
1 = Small/Light Trash: A few scattered items, minimal waste
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

            response = self.client.models.generate_content(
                model=self.model_name,
                contents=[
                    prompt,
                    types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
                ],
            )

            result = response.text.strip().upper()

            # Check if it's NOT TRASH (invalid image)
            if "NOT TRASH" in result or result == "NOT" or result == "TRASH":
                return (False, None, None)

            # Try to extract category number
            for char in result:
                if char in "1234":
                    category = int(char)
                    weight = (
                        category / 4.0
                    )  # Convert category to weight (0.25, 0.5, 0.75, 1.0)
                    return (True, category, weight)

            # If no valid response, treat as invalid
            print(f"Unexpected Gemini response: {result}")
            return (False, None, None)

        except Exception as e:
            print(f"Gemini API error: {e}")
            raise Exception(f"Failed to analyze image: {str(e)}")


# Singleton instance
gemini_service = GeminiService()
