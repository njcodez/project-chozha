"""
models.py — Project Chozha
SQLAlchemy ORM models.  The DATABASE_URL env var controls the backend;
swap sqlite:// → postgresql:// to migrate to Postgres with zero code changes.
"""

from __future__ import annotations

import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Enum,
    String,
    Text,
    create_engine,
)
from sqlalchemy.orm import DeclarativeBase, Session

import os

DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:////storage/db/chozha.db")


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class JobStatus(str, enum.Enum):
    queued = "queued"
    processing = "processing"
    done = "done"
    failed = "failed"


# ---------------------------------------------------------------------------
# ORM base
# ---------------------------------------------------------------------------

class Base(DeclarativeBase):
    pass


# ---------------------------------------------------------------------------
# Jobs table
# ---------------------------------------------------------------------------

class Job(Base):
    __tablename__ = "jobs"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    username = Column(String(128), nullable=False, index=True)
    title = Column(String(255), nullable=True)
    description = Column(Text, nullable=True)
    input_image_path = Column(String(512), nullable=False)
    output_image_path = Column(String(512), nullable=True)
    status = Column(
        Enum(JobStatus, values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        default=JobStatus.queued,
        index=True,
    )
    error_message = Column(Text, nullable=True)
    is_public = Column(Boolean, nullable=False, default=True)
    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )


# ---------------------------------------------------------------------------
# Engine / session helpers (used by both API and worker)
# ---------------------------------------------------------------------------

def get_engine(url: str = DATABASE_URL):
    connect_args = {}
    if url.startswith("sqlite"):
        connect_args["check_same_thread"] = False
    return create_engine(url, connect_args=connect_args)


def get_session(engine=None) -> Session:
    from sqlalchemy.orm import sessionmaker

    if engine is None:
        engine = get_engine()
    SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    return SessionLocal()


def init_db(engine=None):
    """Create all tables (idempotent).  Used as a fallback when Alembic isn't run."""
    if engine is None:
        engine = get_engine()
    Base.metadata.create_all(bind=engine)
