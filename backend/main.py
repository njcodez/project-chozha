"""
main.py — Project Chozha
FastAPI application — all HTTP endpoints.
"""

from __future__ import annotations

import os
import shutil
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

from fastapi import (
    Body,
    Depends,
    FastAPI,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
    status,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session

import crud
from models import Job, JobStatus, get_engine, get_session, init_db

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
STORAGE_ROOT = os.environ.get("STORAGE_ROOT", "/storage")
INPUT_DIR = os.path.join(STORAGE_ROOT, "input")
OUTPUT_DIR = os.path.join(STORAGE_ROOT, "output")
MASTER_PASSWORD = os.environ.get("MASTER_PASSWORD", "changeme")
BASE_URL = os.environ.get("BASE_URL", "http://localhost:8000")

# ---------------------------------------------------------------------------
# Application lifecycle
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Ensure storage dirs exist and DB is initialised
    Path(INPUT_DIR).mkdir(parents=True, exist_ok=True)
    Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)
    Path(os.path.join(STORAGE_ROOT, "db")).mkdir(parents=True, exist_ok=True)
    engine = get_engine()
    #init_db(engine)
    yield


app = FastAPI(
    title="Project Chozha",
    description="Public Tamil inscription binarisation tool powered by SAM2.",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS — open to all origins (will be tightened post-grant)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# DB dependency
# ---------------------------------------------------------------------------

def get_db():
    db = get_session()
    try:
        yield db
    finally:
        db.close()

# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------

def _job_to_dict(job: Job, *, include_urls: bool = True) -> dict:
    d = {
        "job_id": job.id,
        "username": job.username,
        "title": job.title,
        "description": job.description,
        "status": job.status.value if isinstance(job.status, JobStatus) else job.status,
        "error_message": job.error_message,
        "is_public": job.is_public,
        "created_at": job.created_at.isoformat() if job.created_at else None,
        "updated_at": job.updated_at.isoformat() if job.updated_at else None,
        "input_image_path": job.input_image_path,
        "output_image_path": job.output_image_path,
    }
    if include_urls:
        d["input_image_url"] = f"{BASE_URL}/jobs/{job.id}/input"
        if job.output_image_path:
            d["output_image_url"] = f"{BASE_URL}/jobs/{job.id}/output"
        else:
            d["output_image_url"] = None
    return d


class PatchJobBody(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    is_public: Optional[bool] = None


class DeleteJobBody(BaseModel):
    master_password: str

# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/usernames/check")
def check_username(username: str = Query(...), db: Session = Depends(get_db)):
    taken = crud.username_exists(db, username)
    return {"taken": taken}


# ── POST /jobs ──────────────────────────────────────────────────────────────

@app.post("/jobs", status_code=status.HTTP_201_CREATED)
async def create_job(
    image: UploadFile = File(...),
    username: str = Form(...),
    title: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    is_public: bool = Form(True),
    db: Session = Depends(get_db),
):
    # Validate content type loosely
    if image.content_type and not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Uploaded file must be an image.")

    # Create a placeholder job to get the job_id
    import uuid
    job_id = str(uuid.uuid4())

    input_dir = os.path.join(INPUT_DIR, job_id)
    Path(input_dir).mkdir(parents=True, exist_ok=True)
    input_path = os.path.join(input_dir, "original.jpg")

    # Save upload
    try:
        with open(input_path, "wb") as f:
            shutil.copyfileobj(image.file, f)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to save image: {exc}")

    # Persist to DB
    job = crud.create_job(
        db,
        username=username,
        input_image_path=input_path,
        title=title,
        description=description,
        is_public=is_public,
    )
    # Override the auto-generated id with our pre-allocated one so storage
    # paths match.  Simpler: let crud generate id and rename folder.
    # We'll do the rename approach to keep crud clean.
    real_id = job.id
    if real_id != job_id:
        new_input_dir = os.path.join(INPUT_DIR, real_id)
        os.rename(input_dir, new_input_dir)
        new_input_path = os.path.join(new_input_dir, "original.jpg")
        job.input_image_path = new_input_path
        db.commit()
        db.refresh(job)

    # Enqueue Celery task
    from tasks import process_image_task
    process_image_task.delay(job.id, job.input_image_path)

    return {"job_id": job.id, "status": job.status}


# ── GET /jobs ───────────────────────────────────────────────────────────────

@app.get("/jobs")
def list_jobs(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    username: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    items, total = crud.get_public_jobs(db, page=page, limit=limit, username=username)
    return {
        "total": total,
        "page": page,
        "limit": limit,
        "items": [
            {
                "job_id": j.id,
                "username": j.username,
                "title": j.title,
                "description": j.description,
                "status": j.status.value if isinstance(j.status, JobStatus) else j.status,
                "created_at": j.created_at.isoformat() if j.created_at else None,
                "input_image_url": f"{BASE_URL}/jobs/{j.id}/input",
            }
            for j in items
        ],
    }


# ── GET /jobs/{job_id} ──────────────────────────────────────────────────────

@app.get("/jobs/{job_id}")
def get_job(job_id: str, db: Session = Depends(get_db)):
    job = crud.get_job(db, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")
    return _job_to_dict(job)


# ── GET /jobs/{job_id}/input ────────────────────────────────────────────────

@app.get("/jobs/{job_id}/input")
def get_input_image(job_id: str, db: Session = Depends(get_db)):
    job = crud.get_job(db, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")
    if not os.path.exists(job.input_image_path):
        raise HTTPException(status_code=404, detail="Input image file not found.")
    return FileResponse(job.input_image_path, media_type="image/jpeg")


# ── GET /jobs/{job_id}/output ───────────────────────────────────────────────

@app.get("/jobs/{job_id}/output")
def get_output_image(job_id: str, db: Session = Depends(get_db)):
    job = crud.get_job(db, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")
    if not job.output_image_path or not os.path.exists(job.output_image_path):
        raise HTTPException(status_code=404, detail="Output not ready yet.")
    return FileResponse(job.output_image_path, media_type="image/png")


# ── PATCH /jobs/{job_id} ────────────────────────────────────────────────────

@app.patch("/jobs/{job_id}")
def patch_job(job_id: str, body: PatchJobBody, db: Session = Depends(get_db)):
    job = crud.get_job(db, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")
    updated = crud.update_job_metadata(
        db,
        job_id,
        title=body.title,
        description=body.description,
        is_public=body.is_public,
    )
    return _job_to_dict(updated)


# ── DELETE /jobs/{job_id} ───────────────────────────────────────────────────

@app.delete("/jobs/{job_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_job(job_id: str, body: DeleteJobBody, db: Session = Depends(get_db)):
    if body.master_password != MASTER_PASSWORD:
        raise HTTPException(status_code=403, detail="Invalid master password.")

    job = crud.get_job(db, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")

    # Remove image files
    for path in [job.input_image_path, job.output_image_path]:
        if path:
            try:
                parent = os.path.dirname(path)
                if os.path.isdir(parent):
                    shutil.rmtree(parent, ignore_errors=True)
            except Exception:
                pass  # best-effort

    crud.delete_job(db, job_id)
    return

@app.get("/users/{username}/jobs")
def get_user_jobs(username: str, db: Session = Depends(get_db)):
    jobs = db.query(Job).filter(Job.username == username).order_by(Job.created_at.desc()).all()

    return [
        {
            "job_id": j.id,
            "status": j.status.value,
            "created_at": j.created_at.isoformat(),
            "input_image_url": f"{BASE_URL}/jobs/{j.id}/input",
            "output_image_url": f"{BASE_URL}/jobs/{j.id}/output" if j.output_image_path else None,
        }
        for j in jobs
    ]