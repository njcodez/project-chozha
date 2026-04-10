# Project Chozha — Backend

Python FastAPI backend for Tamil inscription binarization. Handles job processing, image management, and API serving for web and mobile clients.

## ✨ Features

- ⚡ **FastAPI** — High-performance async API framework
- 📦 **Asynchronous Processing** — SAM2 model for image binarization
- 💾 **PostgreSQL** — Job and metadata storage
- 🌐 **REST API** — RESTful endpoints for clients
- 🔑 **Username System** — Track jobs by username (implicit registration)
- 👁️ **Public/Private Jobs** — Control job visibility
- 🖼️ **Image URLs** — Direct serving of input/output images
- 🚇 **Cloudflare Tunnel** — Public API exposure for remote clients
- 🐳 **Docker Support** — containerized deployment

## 🛠️ Tech Stack

- **Framework**: FastAPI
- **Language**: Python 3.11+
- **Database**: PostgreSQL
- **ORM**: SQLAlchemy (CRUD operations)
- **ML Model**: SAM2 (Segment Anything Model 2)
- **Image Processing**: OpenCV, PIL
- **Task Queue**: Celery (optional, for async jobs)
- **Deployment**: Docker + Docker Compose
- **Networking**: Cloudflare Tunnel

## 🚀 Quick Start

### Prerequisites

- **Docker** and **Docker Compose**
- **Git**
- **Python 3.11+** (for local development)
## 🔧 Backend Setup (SAM2 Model + Repository)

This project requires the **SAM2 model weights** and the **SAM2 repository** to be set up manually due to their large size.

### 📥 1. Download Model Weights

Download the pretrained model file:

👉 https://huggingface.co/facebook/sam2-hiera-large

* Download the file: `sam2.1_hiera_large.pt`
* Place it inside the `backend/` directory

Final structure:

```
backend/
├── sam2.1_hiera_large.pt
```

---

### 📦 2. Clone SAM2 Repository

Clone the official SAM2 repository:

```bash
cd backend
git clone https://github.com/facebookresearch/sam2.git
```

---

### ✏️ 3. Rename the Folder

Rename the cloned repository from `sam2` to `sam`:

```bash
mv sam2 sam
```

---

### 📁 Final Backend Structure

Your backend folder should look like this:

```
backend/
├── sam/
├── sam2.1_hiera_large.pt
├── main.py
├── models.py
├── processor.py
├── ...
```

---

### ⚠️ Notes

* The `.pt` file is intentionally not included in the repository due to size constraints.
* Ensure the file name remains exactly:

  ```
  sam2.1_hiera_large.pt
  ```
* Do not modify the internal structure of the `sam/` folder after cloning.

---

### ✅ Quick Setup Summary

```bash
cd backend

# Clone SAM2 repo
git clone https://github.com/facebookresearch/sam2.git

# Rename it
mv sam2 sam

# Manually download the model file and place it here
```

---

If you encounter issues, ensure:

* Python dependencies are installed (`requirements.txt`)
* The model file path is correctly referenced in the code

### Start All Services

```bash
# Clone backend repository
git clone https://github.com/your-org/chozha-backend.git
cd chozha-backend

# Start services (API + DB + Cloudflare tunnel)
docker compose up cloudflared api

# Expected output:
# api           | INFO:     Uvicorn running on http://0.0.0.0:8000
# cloudflared   | 2024-01-15 10:30:45 URL: https://abc123def456.trycloudflare.com

# Copy the Cloudflare tunnel URL
```

Backend is now running on:
- **Local**: `http://localhost:8000`
- **Public**: `https://your-tunnel.trycloudflare.com` (via Cloudflare)

## 📄 API Endpoints

### Health Check
```
GET /health
→ { "status": "ok" }
```

### Username Management
```
GET /usernames/check?username={name}
→ { "taken": boolean }

# Returns true if any job exists with that username
# Returns false if username is available
```

### Job Management
```
GET /jobs
→ { "total": int, "items": [JobListItem, ...] }
# All public jobs

GET /jobs?username={username}
→ { "total": int, "items": [JobListItem, ...] }
# Jobs by specific username

GET /jobs/{job_id}
→ Job
# Job details with full metadata

POST /jobs
# Form Data: image (file), username (string), is_public (boolean)
# Returns: { "job_id": "uuid" }
# Creates job, triggers processing

PATCH /jobs/{job_id}
# JSON: { "title": "...", "description": "...", "is_public": boolean }
# Updates job metadata

DELETE /jobs/{job_id}
# JSON: { "master_password": "..." }
# Deletes job (requires correct master password)
```

## 📦 Data Models

### Job Table Structure
```sql
CREATE TABLE jobs (
  job_id UUID PRIMARY KEY,
  username VARCHAR(255) NOT NULL,
  title VARCHAR(500),
  description TEXT,
  status VARCHAR(50),  -- queued, processing, done, failed
  error_message TEXT,
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  input_image_url VARCHAR(500),
  output_image_url VARCHAR(500),
  INDEX (username),
  INDEX (status),
  INDEX (is_public)
);
```

### Response Models
```python
class JobStatus(str, Enum):
    queued = "queued"
    processing = "processing"
    done = "done"
    failed = "failed"

class Job(BaseModel):
    job_id: str
    username: str
    title: Optional[str]
    description: Optional[str]
    status: JobStatus
    error_message: Optional[str]
    is_public: bool
    created_at: str  # ISO 8601
    updated_at: str  # ISO 8601
    input_image_url: str
    output_image_url: Optional[str]

class JobListItem(BaseModel):
    job_id: str
    username: str
    title: Optional[str]
    status: JobStatus
    created_at: str
    input_image_url: str
```

## 🔄 Job Processing Flow

1. **Client Uploads**:
   - POST `/jobs` with image file + username
   - Backend saves image, creates job record (status: "queued")
   - Returns job_id

2. **Processing Starts**:
   - Job status changes to "processing"
   - SAM2 model processes image asynchronously
   - Progress tracked in database

3. **Processing Complete**:
   - Output image saved
   - Job status: "done"
   - output_image_url populated
   - OR status: "failed" with error_message if error occurs

4. **Client Polls**:
   - Client polls `GET /jobs/{job_id}` every 3 seconds
   - Displays status updates to user
   - Shows before/after when done

## 🔐 Environment Variables

Create `.env` file in backend root:

```env
# Database
DATABASE_URL=postgresql://user:password@postgres:5432/chozha

# API Config
API_HOST=0.0.0.0
API_PORT=8000
API_WORKERS=4

# Secrets
MASTER_PASSWORD=your_secure_password

# CORS
CORS_ORIGINS=http://localhost:3000,http://localhost:*,https://*.vercel.app

# Image Storage (local or cloud)
IMAGE_STORAGE_PATH=/app/images
IMAGE_SERVE_URL=http://localhost:8000/images

# Cloudflare Tunnel (auto-generated in docker-compose)
TUNNEL_TOKEN=...
```

## 🛠️ Local Development

### Prerequisites
- Python 3.11+
- PostgreSQL 14+
- pip/virtualenv

### Setup

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables
cp .env.example .env
# Edit .env with your config

# Run migrations
alembic upgrade head

# Start server
uvicorn app.main:app --reload

# API available at http://localhost:8000
# Docs at http://localhost:8000/docs (Swagger UI)
```

### Database Migrations

```bash
# Create new migration
alembic revision --autogenerate -m "Add new column"

# Apply migrations
alembic upgrade head

# Rollback
alembic downgrade -1
```

## 🐳 Docker Deployment

### Docker Compose Services

```yaml
# Start all services
docker compose up

# Services:
# - postgres: Database on port 5432
# - api: FastAPI on port 8000
# - cloudflared: Tunnel for public access
# - redis (optional): Cache layer
```

### Build Custom Image

```bash
docker build -t chozha-api:latest .
docker run -p 8000:8000 --env-file .env chozha-api:latest
```

## 🔌 CORS Configuration

Backend should have CORS enabled for:
- `http://localhost:3000` (web dev)
- `http://192.168.1.x:3000` (local network)
- `https://*.vercel.app` (web production)
- Mobile app origins (if applicable)

Update `CORS_ORIGINS` in `.env`:
```env
CORS_ORIGINS=http://localhost:3000,https://your-domain.vercel.app
```

## 📊 Database Schema

### Jobs Table
```
job_id (UUID, PK)
username (VARCHAR, indexed)
title (VARCHAR, nullable)
description (TEXT, nullable)
status (VARCHAR, indexed) - queued|processing|done|failed
error_message (TEXT, nullable)
is_public (BOOLEAN, indexed)
created_at (TIMESTAMP)
updated_at (TIMESTAMP)
input_image_url (VARCHAR)
output_image_url (VARCHAR, nullable)
```

### Indexing Strategy
- `(username)` — Quick user job lookups
- `(status)` — Fast processing queue queries
- `(is_public)` — Public feed filtering
- `(created_at)` — Recent jobs sorting

## 🚀 Production Deployment

### Cloud Platforms

**AWS EC2**:
```bash
# Launch instance, SSH in
git clone https://github.com/your-org/chozha-backend.git
cd chozha-backend
docker compose -f docker-compose.prod.yml up -d
```

**DigitalOcean App Platform**:
- Connect GitHub repo
- Set environment variables
- Deploy (auto-deploys on push)

**Google Cloud Run**:
```bash
gcloud run deploy chozha-api \
  --source . \
  --set-env-vars DATABASE_URL=... \
  --memory 2Gi
```

### Database
- Use **managed PostgreSQL** (AWS RDS, Google Cloud SQL, etc.)
- Enable automated backups
- Set up read replicas for scalability

### Image Storage
- **Local**: Simple but requires persistent storage
- **AWS S3**: Scalable, CDN-friendly
- **Google Cloud Storage**: Similar to S3
- **Cloudflare Images**: Optimized image delivery

### Monitoring
- Set up logging (CloudWatch, Stackdriver)
- Monitor job processing queue
- Alert on failures

## 🔐 Security Considerations

1. **Master Password**: Change `MASTER_PASSWORD` in production
2. **Database**: Use strong credentials, SSL connections
3. **CORS**: Restrict to known origins only
4. **Rate Limiting**: Implement on API endpoints
5. **Input Validation**: Validate all file uploads
6. **Error Messages**: Don't expose internal errors to clients

## 🐛 Troubleshooting

### Database Connection Issues
```bash
# Check container logs
docker compose logs postgres

# Verify connection string format
postgresql://username:password@hostname:5432/database

# Reset database
docker compose down -v
docker compose up postgres
```

### API Not Responding
```bash
# Check container is running
docker compose ps

# View API logs
docker compose logs api

# Test endpoint manually
curl http://localhost:8000/health
```

### Image Processing Failures
- Check SAM2 model is downloaded
- Verify image format is supported (JPG, PNG, WEBP)
- Check disk space for processing
- Review error_message in database

### Cloudflare Tunnel Issues
```bash
# Check tunnel status
docker compose logs cloudflared

# Verify tunnel URL
curl https://your-tunnel.trycloudflare.com/health
```

## 📈 Performance Tips

1. **Database**: Use connection pooling, optimize queries
2. **Images**: Compress on upload, serve from CDN
3. **Processing**: Queue jobs, use worker threads
4. **Caching**: Cache public feed results
5. **Pagination**: Limit results per request

## 📚 API Documentation

Once running, view interactive docs:
- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

---

**For project overview**: See [Common README](./README.md)  
**For web frontend**: See [Web README](../chozha-frontend/README.md)  
**For mobile app**: See [Flutter README](../chozha-flutter/README.md)