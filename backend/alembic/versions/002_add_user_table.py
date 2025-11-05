"""Add user table and update points relationship

Revision ID: 002
Revises: 001
Create Date: 2025-01-02 00:00:00.000000

"""

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision = "002_add_user_table"
down_revision = "001_initial_migration"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create users table
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("name", sa.String(255), nullable=True),
        sa.Column("picture", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email"),
    )

    # Create index on email
    op.create_index("ix_users_email", "users", ["email"])

    # Step 1: Add new user_id_new column as nullable integer
    op.add_column("points", sa.Column("user_id_new", sa.Integer(), nullable=True))

    # Step 2: Migrate data - create users from existing email addresses and update references
    # Note: This is a data migration - run this manually or customize for your data
    op.execute("""
        INSERT INTO users (email, name, picture, created_at, updated_at)
        SELECT DISTINCT user_id as email, NULL, NULL, now(), now()
        FROM points
        WHERE user_id IS NOT NULL
        ON CONFLICT (email) DO NOTHING;
    """)

    # Step 3: Update points.user_id_new with the new user IDs
    op.execute("""
        UPDATE points
        SET user_id_new = users.id
        FROM users
        WHERE points.user_id = users.email;
    """)

    # Step 4: Drop old user_id column
    op.drop_index("ix_points_user_id", table_name="points")
    op.drop_column("points", "user_id")

    # Step 5: Rename user_id_new to user_id
    op.alter_column("points", "user_id_new", new_column_name="user_id", nullable=False)

    # Step 6: Create foreign key constraint and index
    op.create_foreign_key(
        "fk_points_user_id", "points", "users", ["user_id"], ["id"], ondelete="CASCADE"
    )
    op.create_index("ix_points_user_id", "points", ["user_id"])


def downgrade() -> None:
    # Drop foreign key and index
    op.drop_constraint("fk_points_user_id", "points", type_="foreignkey")
    op.drop_index("ix_points_user_id", table_name="points")

    # Add old user_id column (text) as nullable
    op.add_column("points", sa.Column("user_id_old", sa.Text(), nullable=True))

    # Migrate data back - populate with email addresses
    op.execute("""
        UPDATE points
        SET user_id_old = users.email
        FROM users
        WHERE points.user_id = users.id;
    """)

    # Drop new user_id column
    op.drop_column("points", "user_id")

    # Rename user_id_old to user_id
    op.alter_column("points", "user_id_old", new_column_name="user_id", nullable=False)

    # Recreate index
    op.create_index("ix_points_user_id", "points", ["user_id"])

    # Drop users table
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")
