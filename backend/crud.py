"""
crud.py — Project Chozha
All database operations.  Functions accept a SQLAlchemy Session and return
ORM objects or raise ValueError / KeyError for domain errors.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session

from models import Job, JobStatus


# ---------------------------------------------------------------------------
# Create
# ---------------------------------------------------------------------------

def create_job(
    db: Session,
    *,
    username: str,
    input_image_path: str,
    title: Optional[str] = None,
    description: Optional[str] = None,
    is_public: bool = True,
) -> Job:
    job = Job(
        id=str(uuid.uuid4()),
        username=username,
        title=title,
        description=description,
        input_image_path=input_image_path,
        status=JobStatus.queued,
        is_public=is_public,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    db.add(job)
    db.commit()
    db.refresh(job)
    return job


# ---------------------------------------------------------------------------
# Read
# ---------------------------------------------------------------------------

def get_job(db: Session, job_id: str) -> Optional[Job]:
    return db.query(Job).filter(Job.id == job_id).first()


def get_public_jobs(
    db: Session,
    *,
    page: int = 1,
    limit: int = 20,
    username: Optional[str] = None,
):
    limit = min(limit, 100)  # cap
    query = db.query(Job).filter(Job.is_public == True)  # noqa: E712
    if username:
        query = query.filter(Job.username == username)
    query = query.order_by(Job.created_at.desc())
    total = query.count()
    items = query.offset((page - 1) * limit).limit(limit).all()
    return items, total


def username_exists(db: Session, username: str) -> bool:
    return db.query(Job.id).filter(Job.username == username).first() is not None


# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------

def mark_processing(db: Session, job_id: str) -> Optional[Job]:
    job = get_job(db, job_id)
    if job is None:
        return None
    job.status = JobStatus.processing
    job.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(job)
    return job


def mark_done(db: Session, job_id: str, output_image_path: str) -> Optional[Job]:
    job = get_job(db, job_id)
    if job is None:
        return None
    job.status = JobStatus.done
    job.output_image_path = output_image_path
    job.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(job)
    return job


def mark_failed(db: Session, job_id: str, error_message: str) -> Optional[Job]:
    job = get_job(db, job_id)
    if job is None:
        return None
    job.status = JobStatus.failed
    job.error_message = error_message
    job.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(job)
    return job


def update_job_metadata(
    db: Session,
    job_id: str,
    *,
    title: Optional[str] = None,
    description: Optional[str] = None,
    is_public: Optional[bool] = None,
) -> Optional[Job]:
    job = get_job(db, job_id)
    if job is None:
        return None
    if title is not None:
        job.title = title
    if description is not None:
        job.description = description
    if is_public is not None:
        job.is_public = is_public
    job.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(job)
    return job


# ---------------------------------------------------------------------------
# Delete
# ---------------------------------------------------------------------------

def delete_job(db: Session, job_id: str) -> bool:
    """Returns True if deleted, False if not found."""
    job = get_job(db, job_id)
    if job is None:
        return False
    db.delete(job)
    db.commit()
    return True
