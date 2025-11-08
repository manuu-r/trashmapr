"""
Notifications API endpoints for FCM token management.
"""

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.crud import update_user_fcm_token
from app.db.database import get_db
from app.db.models import User
from app.db.schemas import FCMTokenRequest, FCMTokenResponse
from app.services.auth import get_current_user

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/register-token", response_model=FCMTokenResponse)
async def register_fcm_token(
    request: FCMTokenRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Register or update FCM token for the authenticated user.

    Args:
        request: FCM token registration request
        current_user: Authenticated user object
        db: Database session

    Returns:
        Success response
    """
    try:
        # Update user's FCM token
        updated_user = await update_user_fcm_token(
            db=db,
            user_id=current_user.id,
            fcm_token=request.fcm_token,
        )

        if not updated_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        logger.info(
            f"FCM token registered for user {current_user.id} ({current_user.email})"
        )

        return FCMTokenResponse(
            success=True,
            message="FCM token registered successfully",
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to register FCM token: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to register FCM token",
        )


@router.delete("/unregister-token", response_model=FCMTokenResponse)
async def unregister_fcm_token(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Remove FCM token for the authenticated user (on logout).

    Args:
        current_user: Authenticated user object
        db: Database session

    Returns:
        Success response
    """
    try:
        # Remove user's FCM token (set to None)
        updated_user = await update_user_fcm_token(
            db=db,
            user_id=current_user.id,
            fcm_token=None,
        )

        if not updated_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        logger.info(
            f"FCM token unregistered for user {current_user.id} ({current_user.email})"
        )

        return FCMTokenResponse(
            success=True,
            message="FCM token unregistered successfully",
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to unregister FCM token: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to unregister FCM token",
        )
