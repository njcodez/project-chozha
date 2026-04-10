"""
tasks.py — Project Chozha
Celery task that wraps the SAM2 processor.
"""

from __future__ import annotations

import logging
import os
import sys
sys.path.append("/app")
from celery import Celery

REDIS_URL = os.environ.get("REDIS_URL", "redis://redis:6379/0")

celery_app = Celery(
    "chozha",
    broker=REDIS_URL,
    backend=REDIS_URL,
)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    task_track_started=True,
    worker_prefetch_multiplier=1,  # one job at a time per worker (GPU constraint)
    task_acks_late=True,           # ack only after successful completion
)

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, name="chozha.process_image")
def process_image_task(self, job_id: str, input_path: str):
    """
    Celery task:
      1. Marks job as 'processing' in the DB
      2. Runs the SAM2 pipeline
      3. Marks job as 'done' (with output path) or 'failed' (with error)
    """
    # Import inside task to avoid loading heavy deps in the API process
    from models import get_engine, get_session
    from crud import mark_processing, mark_done, mark_failed
    from processor import process_image

    engine = get_engine()
    db = get_session(engine)

    try:
        logger.info("[%s] Starting processing", job_id)
        mark_processing(db, job_id)

        output_path = process_image(input_path)
        mark_done(db, job_id, output_path)
        logger.info("[%s] Done → %s", job_id, output_path)

    except Exception as exc:
        error_msg = f"{type(exc).__name__}: {exc}"
        logger.exception("[%s] Failed: %s", job_id, error_msg)
        mark_failed(db, job_id, error_msg)
        # Re-raise so Celery marks the task as FAILURE
        raise

    finally:
        db.close()
