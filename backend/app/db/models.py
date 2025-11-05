from geoalchemy2 import Geography
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

Base = declarative_base()


class User(Base):
    """
    Model for users authenticated via Google OAuth.
    Email is used as the unique identifier.
    """

    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=True)
    picture = Column(Text, nullable=True)
    total_points = Column(
        Integer, default=0, nullable=False
    )  # Points earned (250 per upload)
    total_uploads = Column(Integer, default=0, nullable=False)  # Total uploads count
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationship to points
    points = relationship("Point", back_populates="user", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<User(id={self.id}, email={self.email})>"


class Point(Base):
    """
    Model for geo-tagged photo points with trash classification.
    Uses PostGIS Geography type for location storage.
    """

    __tablename__ = "points"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    image_url = Column(Text, nullable=False)
    location = Column(Geography(geometry_type="POINT", srid=4326), nullable=False)
    weight = Column(Float, nullable=False)  # 0.25 to 1.0 (category/4.0)
    category = Column(Integer, nullable=False)  # 1-4 (density level)
    is_trash = Column(Boolean, default=False, nullable=False)
    timestamp = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationship to user
    user = relationship("User", back_populates="points")

    # GIST spatial index is created in migration
    __table_args__ = (
        Index("idx_points_location", "location", postgresql_using="gist"),
    )

    def __repr__(self):
        return (
            f"<Point(id={self.id}, user_id={self.user_id}, category={self.category})>"
        )
