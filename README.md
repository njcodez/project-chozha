# Project Chozha

A modern platform for Tamil inscription binarization using AI. This project consists of three main components: a **Python FastAPI backend**, a **Next.js web frontend**, and a **Flutter mobile app**.

## 🎯 Overview

**Project Chozha** enables researchers and enthusiasts to upload, process, and share Tamil inscriptions with AI-powered binarization. The platform provides:

- **Backend (Python/FastAPI)**: Job processing, image handling, database management
- **Web Frontend (Next.js)**: Light-themed UI for desktop/tablet users
- **Mobile App (Flutter)**: Dark-themed Material 3 app for iOS/Android
- **Real-time Processing**: Live status updates with polling
- **Community Sharing**: Public feeds with filtering and sorting
- **Centralized Configuration**: Firebase Firestore for dynamic API URL management

---

## 🏗️ Project Architecture

```
Project Chozha
├── Backend (project-chozha-backend)
│   └── FastAPI + PostgreSQL + Image Processing
│
├── Frontend (chozha-frontend)
│   ├── Web (Next.js + Tailwind CSS)
│   └── Flutter (Material 3)
│
└── Cloud Infrastructure
    ├── Firebase Firestore (Configuration)
    ├── Cloudflare Tunnel (API Exposure)
    └── Cloud Storage (Images)
```

---

## 📦 Components Overview

### 1. Backend (`project-chozha-backend`)

**Technology**: Python 3.11+, FastAPI, PostgreSQL, Docker

**Key Features**:
- REST API for job management
- Asynchronous image processing (SAM2 model)
- User job tracking by username
- Public/private job visibility
- Image URL serving

**Quick Start**:
```bash
docker compose up cloudflared api
# Backend: http://localhost:8000
# Cloudflare Tunnel URL: https://xxx.trycloudflare.com
```

**See**: [Backend README](../chozha-backend/README.md)

---

### 2. Web Frontend (`chozha-frontend`)

**Technology**: Next.js 14+, TypeScript, Tailwind CSS, shadcn/ui

**Key Features**:
- Light-themed UI (stone/amber/blue colors)
- Splash screen → Username entry → Dual feed (My Work + Public)
- Upload page with drag-drop + mobile camera
- Result page with image comparison slider
- Admin panel for API URL configuration
- Firebase Firestore integration

**Quick Start**:
```bash
cd chozha-frontend
pnpm install
pnpm dev
# Open http://localhost:3000
```

**See**: [Web Frontend README](./README_WEB.md)

---

### 3. Mobile App (`chozha-flutter`)

**Technology**: Flutter 3.x, Dart, Material 3, Riverpod

**Key Features**:
- Dark-themed Material 3 UI
- Image picker (camera/gallery)
- Live job status with animated stepper
- Before/after image comparison slider
- Settings screen with backend URL management
- Firebase Firestore integration

**Quick Start**:
```bash
cd chozha-flutter
flutter pub get
flutter run
```

**See**: [Flutter README](./README_FLUTTER.md)

---

## 🚀 Getting Started (All Components)

### Prerequisites

- **Docker** & **Docker Compose** (for backend)
- **Node.js 18+** & **pnpm** (for web frontend)
- **Flutter 3.x** & **Dart 3.x** (for mobile)
- **Firebase Project** (all components share one)

### Step 1: Backend Setup

```bash
git clone https://github.com/njcodez/chozha-backend.git
cd chozha-backend
docker compose up cloudflared api

# Copy the Cloudflare tunnel URL from output
# Example: https://abc123def456.trycloudflare.com
```

### Step 2: Firebase Configuration

1. Go to [Firebase Console](https://console.firebase.google.com) → Your project
2. Navigate to **Firestore Database > Collections**
3. Create/verify structure:
   ```
   config/
   └── api_link (document)
       └── url: "https://your-cloudflare-url.trycloudflare.com" (string)
   ```

### Step 3: Web Frontend Setup

```bash
git clone https://github.com/njcodez/chozha-frontend.git
cd chozha-frontend
pnpm install

# Create .env.local with Firebase credentials
# (See Web README for details)

pnpm dev
# http://localhost:3000 → Admin panel at /admin
```

### Step 4: Update API URL (via Admin Panel)

1. Open `http://localhost:3000/admin`
2. Enter admin password
3. Paste Cloudflare tunnel URL
4. Click **Update URL** → Success toast

### Step 5: Mobile App Setup (Optional)

```bash
cd chozha-flutter
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-cloudflare-url.trycloudflare.com
```

---

## 🔐 Shared Configuration (Firebase)

All three components use the same Firebase Firestore for API URL management.

### Firestore Structure

```
project-chozha (Database)
│
└── config (Collection)
    └── api_link (Document)
        ├── url: string (API endpoint)
        └── updated_at: timestamp (auto)
```

### Environment Setup

**Web Frontend** (`.env.local`):
```env
NEXT_PUBLIC_FIREBASE_API_KEY=...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=...
NEXT_PUBLIC_FIREBASE_PROJECT_ID=project-chozha
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=...
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=...
NEXT_PUBLIC_FIREBASE_APP_ID=...
NEXT_PUBLIC_ADMIN_PASSWORD=your_password
```

**Mobile App** (build-time define):
```bash
flutter run --dart-define=API_BASE_URL=https://your-url.trycloudflare.com
```

---

## 🔌 API Endpoints (Backend)

All three components use the same REST API:

```
GET  /health                           # Health check
GET  /usernames/check?username={name}  # Check username availability
GET  /jobs                             # All public jobs
GET  /jobs?username={username}         # User's jobs
GET  /jobs/{id}                        # Job details
POST /jobs                             # Create job (FormData)
PATCH /jobs/{id}                       # Update metadata
DELETE /jobs/{id}                      # Delete job (with password)
```

### Data Models

```typescript
type JobStatus = "queued" | "processing" | "done" | "failed"

interface Job {
  job_id: string
  username: string
  title: string | null
  description: string | null
  status: JobStatus
  error_message: string | null
  is_public: boolean
  created_at: string      // ISO 8601
  updated_at: string      // ISO 8601
  input_image_url: string
  output_image_url: string | null
}

interface JobListItem {
  job_id: string
  username: string
  title: string | null
  status: JobStatus
  created_at: string
  input_image_url: string
}
```

---

## 🌐 Deployment

### Backend
- Deploy on cloud VMs (AWS, GCP, DigitalOcean)
- Use environment variables for secrets
- PostgreSQL on managed database service
- Cloudflare Tunnel for API exposure

### Web Frontend
- Deploy to **Vercel** (recommended)
- Set Firebase env vars in Vercel dashboard
- Auto-deploys on GitHub push

### Mobile App
- **Android**: Build APK/AAB, upload to Google Play Console
- **iOS**: Build IPA, upload to App Store Connect
- Use `--dart-define=API_BASE_URL=...` for production URL

---

## 🔄 Feature Sync Across Platforms

### API URL Updates
1. Admin updates URL via web admin panel (`/admin`)
2. URL written to Firestore `config/api_link`
3. Web frontend: Fetches on next API call
4. Mobile app: Fetches from SharedPreferences cache (updates periodically from Firestore)

### Username Management
1. User enters username on first launch
2. System checks if taken via `GET /usernames/check`
3. Username "taken" if any job exists with that username
4. Saved locally (web: cookie, mobile: SharedPreferences)
5. Auto-registered when first job is uploaded

### Job Processing
- Real-time status polling every 3 seconds
- Status: queued → processing → done/failed
- Both platforms display animated progress stepper
- Results shown with before/after comparison

---

## 🛠️ Technology Stack Summary

| Component | Stack |
|-----------|-------|
| **Backend** | Python 3.11, FastAPI, PostgreSQL, Docker, Cloudflare |
| **Web** | Next.js 14, TypeScript, Tailwind CSS, shadcn/ui, Firebase |
| **Mobile** | Flutter 3.x, Dart 3.x, Material 3, Riverpod, Firebase |
| **Database** | PostgreSQL (jobs), Firebase Firestore (config) |
| **Images** | Direct URL serving from backend |
| **Infrastructure** | Docker Compose, Cloudflare Tunnel, Firebase, Vercel |

---

## 📞 Support & Documentation

- **Backend**: See [Backend README](./backend/README.md)
- **Web Frontend**: See [Web README](./chozha-frontend/README.md)
- **Mobile App**: See [Flutter README](./chozha-flutter/README.md)

For general issues:
1. Check component-specific README
2. Verify Firestore `config/api_link` has correct URL
3. Ensure backend is running: `docker compose ps`
4. Test connection: `curl http://localhost:8000/health`

---

## 📄 License

This project is proprietary software. All rights reserved.

---

**Last Updated**: January 2024  
**Version**: 1.0.0