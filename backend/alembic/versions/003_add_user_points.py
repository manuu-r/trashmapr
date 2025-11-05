"""add user points and uploads tracking

Revision ID: 003_add_user_points
Revises: 002_add_user_table
Create Date: 2025-11-06

"""

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision = "003_add_user_points"
down_revision = "002_add_user_table"
branch_labels = None
depends_on = None


def upgrade():
    """Add total_points and total_uploads columns to users table."""
    # Add total_points column (250 points per upload)
    op.add_column(
        "users",
        sa.Column("total_points", sa.Integer(), nullable=False, server_default="0"),
    )

    # Add total_uploads column
    op.add_column(
        "users",
        sa.Column("total_uploads", sa.Integer(), nullable=False, server_default="0"),
    )

    # Calculate existing points for users who already have uploads
    # Each upload = 250 points
    op.execute("""
        UPDATE users
        SET total_uploads = (SELECT COUNT(*) FROM points WHERE points.user_id = users.id),
            total_points = (SELECT COUNT(*) * 250 FROM points WHERE points.user_id = users.id)
    """)


def downgrade():
    """Remove total_points and total_uploads columns from users table."""
    op.drop_column("users", "total_uploads")
    op.drop_column("users", "total_points")
