# Dockerfile — Project Chozha (OFFLINE STABLE BUILD)

FROM pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime

# ── System deps ─────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        curl \
        libglib2.0-0 \
        libgl1 \
        libsm6 \
        libxext6 \
        libxrender1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ── Python deps ─────────────────────────────────────────────
COPY requirements.txt .

# Minimal required deps (NO torch reinstall)
RUN pip install \
    hydra-core \
    iopath \
    omegaconf \
    tqdm \
    pillow \
    pyyaml \
    packaging

RUN pip install --no-cache-dir -r requirements.txt

# ── Install SAM2 from LOCAL repo ────────────────────────────
COPY backend/sam2 /app/sam2
RUN pip install --no-deps --no-build-isolation /app/sam2

# ── Copy model (offline usage) ──────────────────────────────

COPY backend/sam2.1_hiera_large.pt /app/sam2.1_hiera_large.pt

# ── Application code ────────────────────────────────────────
COPY backend/*.py ./

# ── Storage dirs ────────────────────────────────────────────
RUN mkdir -p /storage/input /storage/output /storage/db

# (HF cache no longer required, but harmless to keep)
ENV HF_HOME=/hf_cache
RUN mkdir -p /hf_cache

# ── Default command ─────────────────────────────────────────
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]