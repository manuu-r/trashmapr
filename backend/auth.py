from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from google.oauth2 import id_token
from google.auth.transport import requests
from typing import Optional, Tuple
from models import User
from database import get_db
from config import settings

# HTTP Bearer token scheme
security = HTTPBearer()


class AuthService:
    """Service for handling Google OAuth authentication."""

    def __init__(self):
        self.google_client_id = settings.google_oauth_client_id

    async def verify_token(self, token: str) -> dict:
        """
        Verify a Google OAuth ID token.

        Args:
            token: Google OAuth ID token

        Returns:
            Token payload containing user information

        Raises:
            HTTPException: If token is invalid
        """
        try:
            # Verify the token
            idinfo = id_token.verify_oauth2_token(
                token, requests.Request(), self.google_client_id
            )

            # Verify issuer
            if idinfo["iss"] not in [
                "accounts.google.com",
                "https://accounts.google.com",
            ]:
                raise ValueError("Wrong issuer.")

            return idinfo

        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid authentication token: {str(e)}",
                headers={"WWW-Authenticate": "Bearer"},
            )
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )

    async def get_user_info_from_token(
        self, token: str
    ) -> Tuple[str, Optional[str], Optional[str]]:
        """
        Extract user information from token.

        Args:
            token: Google OAuth ID token

        Returns:
            Tuple of (email, name, picture)
        """
        idinfo = await self.verify_token(token)
        email = idinfo["email"]
        name = idinfo.get("name")
        picture = idinfo.get("picture")
        return email, name, picture


# Singleton instance
auth_service = AuthService()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    Dependency to get current authenticated user.
    Creates user in database if not exists.

    Args:
        credentials: HTTP Bearer credentials from request
        db: Database session

    Returns:
        User object

    Raises:
        HTTPException: If authentication fails
    """
    from crud import get_or_create_user

    token = credentials.credentials
    email, name, picture = await auth_service.get_user_info_from_token(token)

    # Get or create user in database
    user = await get_or_create_user(db, email, name, picture)

    return user


async def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(
        HTTPBearer(auto_error=False)
    ),
    db: AsyncSession = Depends(get_db),
) -> Optional[User]:
    """
    Optional dependency to get current user if authenticated.
    Does not raise error if no credentials provided.

    Args:
        credentials: Optional HTTP Bearer credentials
        db: Database session

    Returns:
        User object or None
    """
    from crud import get_or_create_user

    if credentials is None:
        return None

    try:
        token = credentials.credentials
        email, name, picture = await auth_service.get_user_info_from_token(token)
        user = await get_or_create_user(db, email, name, picture)
        return user
    except HTTPException:
        return None
