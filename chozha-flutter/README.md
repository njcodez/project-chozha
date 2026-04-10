# Project Chozha — Flutter Mobile App

Dark-themed Material 3 mobile application for iOS and Android. Real-time job processing with interactive image comparison.

## ✨ Features

- 🎨 **Material 3 Dark Theme** — Modern, clean UI
- 📸 **Image Capture** — Gallery (prioritized) or camera input
- 🎬 **Live Processing** — Animated status stepper, 3-second polling
- 🎞️ **Image Comparison** — Horizontal drag slider (touch-friendly)
- 🔄 **Pull to Refresh** — Update job feeds manually
- 💾 **Gallery Download** — Save processed images to device
- ⚙️ **Settings Screen** — Backend URL management + username control
- 🌐 **Firebase Sync** — Real-time API URL from Firestore
- 📱 **Fully Responsive** — Phone and tablet optimized

## 🛠️ Tech Stack

- **Framework**: Flutter 3.x (stable)
- **Language**: Dart 3.x
- **UI Design**: Material 3
- **State Management**: Riverpod
- **Navigation**: GoRouter
- **HTTP Client**: Dio
- **Image Handling**: image_picker, cached_network_image
- **Local Storage**: shared_preferences
- **Database**: Firebase Firestore (config)
- **Date/Time**: intl, timeago
- **Fonts**: Google Fonts (Catamaran)

## 🚀 Installation

```bash
# Clone repository
git clone https://github.com/njcodez/chozha-flutter.git
cd chozha-flutter

# Get dependencies
flutter pub get

# Build runner (if needed)
flutter pub run build_runner build

# Platform-specific (optional)
cd ios && pod install && cd ..
```

## 🔐 Environment Setup

API URL is set at **build time** via `--dart-define` flag.

### Development
```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

### Production
```bash
flutter run --dart-define=API_BASE_URL=https://your-tunnel.trycloudflare.com
```

The app reads the Firestore `config/api_link` document and caches the URL in SharedPreferences for subsequent runs.

## 💻 Running Locally

### Prerequisites

1. **Flutter 3.x** installed: `flutter --version`
2. **Backend running**: `docker compose up cloudflared api`
3. **Firebase configured**: Firestore with `config/api_link`
4. **iOS**: Xcode 14+, CocoaPods
5. **Android**: Android SDK, Android Studio (optional)

### Start App

```bash
# iOS
flutter run --dart-define=API_BASE_URL=http://localhost:8000

# Android (with emulator)
flutter run --dart-define=API_BASE_URL=http://localhost:8000

# iOS Simulator
open -a Simulator
flutter run --dart-define=API_BASE_URL=http://localhost:8000

# Physical device
# Connect device, enable USB debugging
flutter devices  # Verify device shows
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

## 📄 Screens

### Splash
- App name "Project Chozha" in Catamaran font
- Dark background, minimal design
- Auto-advances after 2 seconds

### Username Entry
- Text input field
- Submit button
- Calls `GET /usernames/check`
- If taken: Dialog with "Proceed anyway" or "Choose different" options
- Username saved to SharedPreferences

### Home — Two Tabs
**Tab 1: My Work**
- Grid of job cards (your uploads)
- Each card: Thumbnail, timestamp, title, status chip
- Pull-to-refresh support
- Tap card → Result screen

**Tab 2: Public Feed**
- Grid of all public jobs
- Shows username on each card
- Sort toggle: "Newest First" or "Grouped by Username"
- Pull-to-refresh support
- Tap card → Result screen

**FAB Button**
- Floating action button
- Tap → Upload screen

### Upload
- Image picker (gallery first, camera fallback)
- Image preview after selection
- Username display (read-only)
- Process button
  - Calls `POST /jobs` with FormData
  - Navigates to Result screen with job ID

### Result
**While Processing**:
- Input image with pulsing overlay
- Animated status stepper: Queued → Processing → Done
- Polls backend every 3 seconds
- Shows error message if processing fails

**When Done**:
- Before/after comparison slider
- Drag horizontally to reveal before/after
- Input label on left, Output on right
- Touch-friendly handle with arrow icons

**Below Slider**:
- Title text field
- Description textarea
- "Public" toggle switch
- Save button → `PATCH /jobs/{id}`

**Action Buttons**:
- Download: Saves to device gallery
- Delete: Password dialog → `DELETE /jobs/{id}` → Pop to home

### Settings
- **Backend URL Field**: Pre-filled from Firestore, editable
- **Update Button**: Writes to Firestore, updates cache
- **Test Connection**: `GET /health` → Green tick or red cross
- **Username Display**: Current username
- **Change Username Button**: Clears SharedPreferences, navigates to username entry

## 🔌 API Integration

### Endpoints Used

```
GET  /health
GET  /usernames/check?username={name}
GET  /jobs (all public)
GET  /jobs?username={username} (user's jobs)
GET  /jobs/{id}
POST /jobs (FormData: image, username, is_public)
PATCH /jobs/{id} (JSON: title, description, is_public)
DELETE /jobs/{id} (JSON: master_password)
```

### Data Models

```dart
enum JobStatus { queued, processing, done, failed }

class Job {
  final String jobId;
  final String username;
  final String? title;
  final String? description;
  final JobStatus status;
  final String? errorMessage;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String inputImageUrl;
  final String? outputImageUrl;
}

class JobListItem {
  final String jobId;
  final String username;
  final String? title;
  final JobStatus status;
  final DateTime createdAt;
  final String inputImageUrl;
}
```

## 🎨 Design System

### Colors
- **Dark Background**: #121212 (Material 3)
- **Surface**: #1E1E1E
- **Primary**: Blue (#2196F3)
- **Success**: Green (#4CAF50)
- **Warning**: Amber (#FFC107)
- **Error**: Red (#F44336)
- **Text**: White (#FFFFFF) / Gray (#E0E0E0)

### Typography
- **App Name**: Catamaran (Splash)
- **UI Text**: Roboto (Material 3 default)
- **Sizes**: 12sp (caption), 14sp (body), 16sp (subheading), 20sp+ (heading)

## 📦 State Management (Riverpod)

### Providers

**Auth**:
- `usernameProvider` — Current username (SharedPreferences)
- `changeUsernameProvider` — Clear username, navigate to entry

**API**:
- `dioProvider` — HTTP client (Dio instance)
- `apiBaseUrlProvider` — Base URL (Firestore cache)

**Jobs**:
- `jobsProvider` — List of jobs (with pagination, filtering)
- `jobProvider(jobId)` — Single job detail (polling when processing)
- `createJobProvider` — Upload job mutation
- `updateJobProvider` — Update metadata mutation
- `deleteJobProvider` — Delete job mutation

**Settings**:
- `backendUrlProvider` — Current backend URL
- `updateBackendUrlProvider` — Write to Firestore

## 🔄 State Flow

1. **App Start**: Check username in SharedPreferences
   - If exists: Go to home
   - If not: Show username entry screen

2. **Upload**: 
   - Pick image from gallery/camera
   - Show preview
   - POST to `/jobs`
   - Get job_id in response
   - Navigate to result screen with that ID

3. **Processing**:
   - Poll `/jobs/{id}` every 3 seconds
   - Update UI based on status (queued/processing/done/failed)
   - Animate stepper progress
   - Stop polling when done or failed

4. **Results**:
   - Display comparison slider
   - Allow metadata editing + saving
   - Download or delete options

## 📱 Responsive Design

- **Portrait Mode**: Full-width cards, single-column grid
- **Landscape Mode**: Two-column grid, side-by-side forms
- **Tablets**: Optimized spacing, larger cards
- **Safe Areas**: Respects notches, status bars

## 🔐 Security

- **Passwords**: Master password for deletion (sent in request body)
- **Storage**: SharedPreferences for local data (device-specific)
- **HTTPS**: Use only HTTPS URLs in production
- **Firebase**: Firestore security rules restrict writes

## 📤 Building for Release

### Android (APK)
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-tunnel.trycloudflare.com
```

### Android (App Bundle for Play Store)
```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-tunnel.trycloudflare.com
```

### iOS (IPA)
```bash
flutter build ios --release \
  --dart-define=API_BASE_URL=https://your-tunnel.trycloudflare.com
```

Then upload to respective app stores (Google Play, App Store).

## 🐛 Troubleshooting

### App Crashes on Startup
- Check Firebase configuration in `main.dart`
- Verify Firestore is accessible
- Check `config/api_link` document exists

### "Could not reach server"
- Ensure backend is running: `docker compose ps`
- Verify API_BASE_URL is correct
- Test manually: `curl {API_BASE_URL}/health`

### Images Not Loading
- Check backend URL is correct (Settings → Test Connection)
- Verify network connectivity
- Check image URLs in API responses

### Pull-to-Refresh Not Working
- Ensure RefreshIndicator wraps job list
- Check providers are set up correctly

### Status Not Updating
- Verify polling timer is active (every 3 seconds)
- Check job status in Firestore/backend
- Look for API errors in console

## 📊 Performance

- **Image Caching**: `cached_network_image` caches thumbnails
- **Lazy Loading**: Jobs load in batches
- **State Caching**: Riverpod caches provider states
- **Memory Management**: Proper disposal of listeners
- **Image Optimization**: Backend serves optimized sizes

---

**For project overview**: See [Common README](./README.md)  
**For backend details**: See [Backend README](../chozha-backend/README.md)  
**For web frontend**: See [Web README](../chozha-frontend//README.md)