"""add fcm_token for push notifications

Revision ID: 004_add_fcm_token
Revises: 003_add_user_points
Create Date: 2025-11-08

"""

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision = "004_add_fcm_token"
down_revision = "003_add_user_points"
branch_labels = None
depends_on = None


def upgrade():
    """Add fcm_token column to users table for Firebase Cloud Messaging."""
    op.add_column(
        "users",
        sa.Column("fcm_token", sa.Text(), nullable=True),
    )


def downgrade():
    """Remove fcm_token column from users table."""
    op.drop_column("users", "fcm_token")
