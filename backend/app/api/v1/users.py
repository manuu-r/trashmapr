from fastapi import APIRouter, Depends

from app.db.models import User
from app.db.schemas import UserResponse
from app.services.auth import get_current_user

router = APIRouter()


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """
    Get current user information (protected endpoint).

    Args:
        current_user: Authenticated user object

    Returns:
        User information
    """
    return UserResponse.model_validate(current_user)
