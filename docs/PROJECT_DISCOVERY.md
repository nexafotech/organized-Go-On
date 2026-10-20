# PROJECT DISCOVERY AND ENVIRONMENT BASELINE REPORT
**Project**: go-On — AI Face Attendance System  
**Discovery Date**: October 18, 2026  
**Auditor / Engineering Role**: Antigravity Full-Stack & Deployment Agent  
**Environment**: Windows 11 (Physical Host Machine)

---

## 1. Physical Environment & Repository Identification

- **Confirmed Repository Root**: `E:\originalam`
- **Initial Candidate Path (`C:\Users\Abishek\Desktop\am-oss`)**: Not present on this machine (Host user profile: `C:\Users\rethi`). Confirmed active project root is `E:\originalam`.
- **Git Branch**: `main`
- **Current HEAD Commit**: `f6bdf052402b10f8cf0ce6b6e57d88b46ebcb24a` (`feat(mobile): implement adaptive splash screen, deterministic theme persistence, and zero-flicker startup`)
- **Remote URL**: `https://github.com/nexafotech/go-on-app.git` (synchronized with `origin/main`)
- **Working Tree Status**: Clean (0 unstaged changes, 0 uncommitted modifications)
- **Available Disk Space**:
  - `C:\`: 85.39 GB free (213.92 GB used)
  - `E:\`: 60.45 GB free (157.09 GB used)

---

## 2. Tooling and Runtime Baseline

| Component | Detected Version | Status / Notes |
| :--- | :--- | :--- |
| **Python** | `3.14.5` (64-bit) | Active runtime on host PATH |
| **Flutter SDK** | `3.47.7` (Dart `3.13.5`) | Channel `stable`, revision `abaf9c5237` |
| **Node.js** | `v24.16.0` | Active on PATH |
| **npm** | `11.13.0` | Active on PATH |
| **Git** | `2.54.0.windows.1` | Configured user: `nexafotech <support@nexafotech.com>` |
| **Java JDK** | OpenJDK `17.0.20.1` | Microsoft build (LTS) |
| **Android SDK / ADB** | Platform-Tools `37.0.1` (`ADB 1.0.41`) | Target Android SDK 36 |
| **Zoho Catalyst CLI** | `1.28.0` | Installed via npm globally; login pending |

---

## 3. Verified Safe Backups Created

Prior to any migration, cloud deployment, or structural modifications, verified backups were created in an isolated directory:
- **Backup Directory**: `E:\backups\go-on-backup-20261018-phase1`
- **Primary Database Backup**:
  - Source: `E:\originalam\attendance_system.db`
  - Destination: `E:\backups\go-on-backup-20261018-phase1\attendance_system.db`
  - Size: `28,217,344 bytes` (~28.2 MB)
- **Full Git Repository Bundle**:
  - Destination: `E:\backups\go-on-backup-20261018-phase1\repo_backup_20261018.bundle`
  - Size: `166,170,488 bytes` (~166.2 MB)
  - Scope: Complete repository history, all branches, tags, and commit trees.

---

## 4. Backend Application Architecture (FastAPI)

- **Entry Point**: `app.main:app` (FastAPI 2.0.0)
- **Primary Port Configuration**:
  - Backend API: Port `8000` (`http://localhost:8000`)
  - Swagger UI: `http://localhost:8000/docs`
  - Health Endpoint: `http://localhost:8000/health` and `http://localhost:8000/api/v1/health`
- **Lifespan Task**:
  - `next_class_reminder_scheduler_loop()`: Async 60-second background loop processing due scheduled notifications and next-class reminders in `Asia/Kolkata` (IST) timezone.
- **CORS Configuration**: Restricts origins safely with credentials enabled; allows localhost, 127.0.0.1, and Cloudflare tunnel regex.
- **Mounted Web Client**: Mounts `mobile/build/web` to `/` for unified web access.
- **Protected Engine Files**:
  - `app/engines/recognition/local_dlib.py` (Dlib facial recognition integration)
  - `attendance_marker.py` (Attendance orchestration pipeline)
  - `app/engines/attendance_engine.py` (Core attendance verification engine)

---

## 5. Mobile Application Architecture (Flutter)

- **Project Directory**: `E:\originalam\mobile`
- **Application Name**: `attendance_marker_mobile`
- **Android Package / Namespace**: `com.aifaceattendance.mobile_app`
- **Application Version**: `2.0.0` (Version Code `6`)
- **API Client Configuration**: `mobile/lib/core/config/api_config.dart`
  - Supports dynamic backend base URL (`setBaseUrl()`), persistent SharedPreferences caching, and automatic fallback.
- **Firebase Messaging**: Integrated via `firebase_core` (4.15.0) and `firebase_messaging` (16.7.0).
- **Static Analysis Status**: `flutter analyze lib/` passing with 0 errors and 0 warnings.
- **Widget / Unit Test Suite**: 203 passing tests (100% pass rate).

---

## 6. Database Baseline & Record Integrity

- **Database Engine**: SQLite 3 (SQLAlchemy ORM + Alembic migrations)
- **Database File**: `E:\originalam\attendance_system.db` (28.2 MB)
- **Verified Record Baseline**:
  - Total Tables: 21
  - `users`: 721 rows (Faculty, Students, Admins)
  - `students`: 387 rows
  - `faculty`: 142 rows
  - `attendance_records`: 128 rows
  - `attendance_policies`: 1 row
  - `timetable_entries`: 84 rows
  - `face_embeddings`: 195 rows
  - `device_tokens`: 66 rows
  - `notification_logs`: 60,752 rows
  - `scheduled_notifications`: 44 rows
  - `subjects`: 27 rows
  - `faculty_assignments`: 30 rows
  - `assignment_authorized_faculty`: 21 rows
  - `class_sections`: 2 rows
  - `class_sessions`: 2 rows
  - `system_settings`: 24 rows
  - `audit_logs`: 790 rows
  - `alembic_version`: 1 row

---

## 7. Machine Learning & Biometric Models

1. **Face Detector: SCRFD-10G** (`models/face_recognition/det_10g.onnx`):
   - Size: 16.92 MB (16,923,827 bytes)
   - Source: InsightFace buffalo_l release
   - License: Non-Commercial Research & Educational Academic License
   - Preprocessing: BGR float32, normalized `(img - 127.5)/128.0`
2. **Feature Extractor: ArcFace ResNet-50** (`models/face_recognition/w600k_r50.onnx`):
   - Size: 174.38 MB (174,383,860 bytes)
   - Source: InsightFace buffalo_l release
   - License: Non-Commercial Research & Educational Academic License
   - Output: 512-dimensional float32 feature vector (L2-normalized)

---

## 8. Zoho Catalyst Compatibility Analysis

| Architectural Component | Local Behavior | Catalyst Cloud Support | Recommended Cloud Strategy |
| :--- | :--- | :--- | :--- |
| **FastAPI Backend Web Service** | Uvicorn ASGI on port 8000 | Fully supported on **Catalyst AppSail** | Deploy as a Catalyst AppSail standalone Python service. Set listening port via `$X_ZOHO_CATALYST_LISTEN_PORT`. |
| **ArcFace & SCRFD ONNX Models** | 191 MB total model weights loaded in memory | Exceeds Basic Function limits; supported on AppSail with memory tier $\ge$ 1GB/2GB | Bundle models within AppSail or download on cold start into AppSail local disk; ensure memory allocation is $\ge$ 2048 MB. |
| **SQLite Database Persistence** | Stored locally in `attendance_system.db` | Serverless / AppSail containers have **ephemeral filesystems** (lost on restart/redeploy) | For development/staging: SQLite can run locally or on persistent storage; for production durability: Migrate to a managed PostgreSQL database or Catalyst Data Store. |
| **Background Scheduler Loop** | 60-second `asyncio` loop in lifespan | AppSail keeps background loops running during active container lifespans | AppSail preserves the lifespan loop; alternatively, bind to Catalyst Cron triggers for decoupled execution. |
| **Static Web Client** | Served via FastAPI `/` or port 3000 | Supported via **Catalyst Web Client Hosting** (Slate/Client) | Deploy `mobile/build/web` to Catalyst Client Hosting or serve directly through AppSail. |
| **Firebase Cloud Messaging** | Firebase Admin SDK + FCM tokens | Supported (outbound HTTPS to Google FCM endpoints) | Provide Firebase service account key securely via Catalyst environment variables/secrets. |

---

## 9. Proposed Implementation Sequence

1. **Phase 2 — Project Structure & Safety**: Preserve protected engine files, ensure `.gitignore` excludes local DBs and secrets, generate safe `.env.example`.
2. **Phase 3 — Catalyst CLI Configuration**: Guide user through official interactive login (`catalyst login`), inspect available projects, select Development/Staging environment.
3. **Phase 4 & 5 — Deployment Configuration**: Generate `catalyst.json` and AppSail configuration (`app-config.json`) with proper Python runtime, start command, and environment variable bindings.
4. **Phase 6 — Verification**: Run backend test suite (11 pytests), mobile test suite (203 tests), database integrity checks, and capacity validation.
5. **Phase 7 — Development Deployment**: Deploy to Catalyst Development environment; verify HTTPS endpoint, health check, and API routing.
6. **Phase 8 — Notifications**: Verify FCM integration and Asia/Kolkata scheduler handling.
7. **Phase 9 — Mobile App Release**: Configure mobile app with deployed Catalyst HTTPS URL, build release APK, and verify.
8. **Phase 10 — Comprehensive Documentation**: Produce all required documentation in `docs/` and runbooks.
