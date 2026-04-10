"""initial jobs table

Revision ID: 0001_initial
Revises: 
Create Date: 2024-01-01 00:00:00.000000
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "jobs",
        sa.Column("id",                  sa.String(36),          primary_key=True),
        sa.Column("username",            sa.String(128),         nullable=False),
        sa.Column("title",               sa.String(255),         nullable=True),
        sa.Column("description",         sa.Text(),              nullable=True),
        sa.Column("input_image_path",    sa.String(512),         nullable=False),
        sa.Column("output_image_path",   sa.String(512),         nullable=True),
        sa.Column(
            "status",
            sa.Enum("queued", "processing", "done", "failed", name="jobstatus"),
            nullable=False,
            server_default="queued",
        ),
        sa.Column("error_message",       sa.Text(),              nullable=True),
        sa.Column("is_public",           sa.Boolean(),           nullable=False, server_default=sa.true()),
        sa.Column("created_at",          sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at",          sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_jobs_username", "jobs", ["username"])
    op.create_index("ix_jobs_status",   "jobs", ["status"])


def downgrade() -> None:
    op.drop_index("ix_jobs_status",   table_name="jobs")
    op.drop_index("ix_jobs_username", table_name="jobs")
    op.drop_table("jobs")
    # Drop the named enum type — no-op on SQLite, required on Postgres
    sa.Enum(name="jobstatus").drop(op.get_bind(), checkfirst=True)