"""Initial migration: create points table with PostGIS support

Revision ID: 001
Revises:
Create Date: 2025-01-01 00:00:00.000000

"""

import sqlalchemy as sa
from alembic import op
from geoalchemy2 import Geography

# revision identifiers, used by Alembic.
revision = "001_initial_migration"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Enable PostGIS extension
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")

    # Create points table
    op.create_table(
        "points",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Text(), nullable=False),
        sa.Column("image_url", sa.Text(), nullable=False),
        sa.Column(
            "location",
            Geography(geometry_type="POINT", srid=4326, spatial_index=False),
            nullable=False,
        ),
        sa.Column("weight", sa.Float(), nullable=False),
        sa.Column("category", sa.Integer(), nullable=False),
        sa.Column("is_trash", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column(
            "timestamp",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    # Create index on user_id
    op.create_index("ix_points_user_id", "points", ["user_id"])

    # Create GIST spatial index on location
    op.execute("CREATE INDEX idx_points_location ON points USING GIST (location)")


def downgrade() -> None:
    # Drop indexes
    op.execute("DROP INDEX IF EXISTS idx_points_location")
    op.drop_index("ix_points_user_id", table_name="points")

    # Drop table
    op.drop_table("points")

    # Note: We don't drop PostGIS extension as it might be used by other tables
