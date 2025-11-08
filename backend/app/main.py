import os
from pathlib import Path

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.v1.router import api_router
from app.core.config import settings
from app.db.database import init_db
from app.services.fcm_service import initialize_firebase

# Initialize FastAPI app with settings from config
app = FastAPI(
    title=settings.app_name,
    description="Geo-tagged photo app with AI-powered trash classification",
    version=settings.app_version,
    debug=settings.debug,
)

# CORS middleware configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event():
    """Initialize database connection and Firebase on startup."""
    await init_db()
    initialize_firebase()
    print("Application startup complete")


# Health check endpoint (not versioned)
@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy"}


# Mount API v1 routes under /api/v1
app.include_router(api_router, prefix="/api/v1")

# Determine the path to the React build directory
# In Docker, React build is at /dist; for local dev, fallback to react/dist
react_build_path = (
    Path("/dist")
    if Path("/dist").exists()
    else Path(__file__).parent.parent.parent / "react" / "dist"
)

# Mount static files and serve React app at root
if react_build_path.exists():
    # Serve static assets (JS, CSS, images, etc.)
    app.mount(
        "/assets",
        StaticFiles(directory=react_build_path / "assets"),
        name="static-assets",
    )

    # Serve other static files from root
    app.mount(
        "/",
        StaticFiles(directory=react_build_path, html=True),
        name="react-app",
    )
    print(f"Serving React frontend from: {react_build_path}")
else:
    print(f"Warning: React build directory not found at {react_build_path}")
    print("Run 'npm run build' in the react directory to build the frontend")

    # Fallback root endpoint when React build is not available
    @app.get("/")
    async def root():
        """Root endpoint - API information."""
        return {
            "message": settings.app_name,
            "status": "online",
            "version": settings.app_version,
            "environment": "production" if settings.is_production else "development",
            "api_docs": "/docs",
            "api_base": "/api/v1",
            "note": "React frontend not built. Run 'npm run build' in react directory.",
        }


if __name__ == "__main__":
    # For local development
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=settings.debug)
