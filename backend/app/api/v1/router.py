from fastapi import APIRouter

from app.api.v1 import notifications, points, upload, users

api_router = APIRouter()

# Include all v1 routers
api_router.include_router(points.router, prefix="/points", tags=["points"])
api_router.include_router(upload.router, prefix="/upload", tags=["upload"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(
    notifications.router, prefix="/notifications", tags=["notifications"]
)
