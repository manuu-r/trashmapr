from pydantic import BaseModel, Field, field_validator, EmailStr
from datetime import datetime
from typing import Optional, List


class LocationSchema(BaseModel):
    """Schema for geographic coordinates."""

    lat: float = Field(..., ge=-90, le=90, description="Latitude")
    lng: float = Field(..., ge=-180, le=180, description="Longitude")


class UserCreate(BaseModel):
    """Schema for creating a new user (internal use)."""

    email: EmailStr
    name: Optional[str] = None
    picture: Optional[str] = None


class UserResponse(BaseModel):
    """Schema for user response in API."""

    id: int
    email: str
    name: Optional[str] = None
    picture: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class UserWithPointsResponse(BaseModel):
    """Schema for user response with their points."""

    id: int
    email: str
    name: Optional[str] = None
    picture: Optional[str] = None
    created_at: datetime
    points: List["PointResponse"] = []

    model_config = {"from_attributes": True}


class PointCreate(BaseModel):
    """Schema for creating a new point (internal use)."""

    user_id: int
    image_url: str
    lat: float = Field(..., ge=-90, le=90)
    lng: float = Field(..., ge=-180, le=180)
    weight: float = Field(..., ge=0.25, le=1.0)
    category: int = Field(..., ge=1, le=4)
    is_trash: bool = False


class PointResponse(BaseModel):
    """Schema for point response in API."""

    id: int
    image_url: str
    location: LocationSchema
    weight: float
    category: int
    timestamp: datetime
    user_id: int

    model_config = {"from_attributes": True}


class PointWithUserResponse(BaseModel):
    """Schema for point response with user information."""

    id: int
    image_url: str
    location: LocationSchema
    weight: float
    category: int
    timestamp: datetime
    user: UserResponse

    model_config = {"from_attributes": True}


class UploadResponse(BaseModel):
    """Schema for upload endpoint response."""

    success: bool
    message: str
    point_id: Optional[int] = None
    category: Optional[int] = None
    weight: Optional[float] = None


class BoundsQuery(BaseModel):
    """Schema for bounding box query parameters."""

    lat1: float = Field(..., ge=-90, le=90, description="Southwest latitude")
    lng1: float = Field(..., ge=-180, le=180, description="Southwest longitude")
    lat2: float = Field(..., ge=-90, le=90, description="Northeast latitude")
    lng2: float = Field(..., ge=-180, le=180, description="Northeast longitude")

    @field_validator("lat2")
    @classmethod
    def validate_lat2(cls, v, info):
        if "lat1" in info.data and v <= info.data["lat1"]:
            raise ValueError("lat2 must be greater than lat1")
        return v

    @field_validator("lng2")
    @classmethod
    def validate_lng2(cls, v, info):
        if "lng1" in info.data and v <= info.data["lng1"]:
            raise ValueError("lng2 must be greater than lng1")
        return v


class UserInfo(BaseModel):
    """Schema for user information from OAuth."""

    email: str
    name: Optional[str] = None
    picture: Optional[str] = None
