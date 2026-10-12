# Attendance Marker — Mobile Integration Contract & API Specification

This document defines the authoritative API integration contract for the Flutter mobile application (targeting Android APK) interacting with the FastAPI backend.

---

## 1. Authentication & Security Architecture

### Token Storage Standard
- **Sensitive Secrets (`flutter_secure_storage`)**:
  - `access_token`
  - `refresh_token` / Session credentials
- **Non-Sensitive Preferences (`shared_preferences`)**:
  - Custom backend URL overrides
  - Selected role tab preference before login (`STUDENT` vs `FACULTY`)
  - Dark mode / UI settings

### Startup & Session Restoration Lifecycle
1. On application boot (`SplashScreen`), read token from `flutter_secure_storage`.
2. If no token exists -> route directly to `LoginScreen`.
3. If token exists -> execute `GET /api/v1/auth/me`.
4. If backend responds with `401 Unauthorized` or `403 Forbidden`:
   - Clear secure storage session.
   - Route to `LoginScreen` with error notification.
5. If backend responds with `200 OK`:
   - Trust the **backend-returned role** (`user.role`). Do NOT rely on client-cached role data.
   - Route to `StudentDashboardScreen` if `role == "STUDENT"`.
   - Route to `FacultyDashboardScreen` if `role == "FACULTY"`.

---

## 2. Student Mobile API Contract

| Mobile Feature | Method | API Endpoint Path | Key Request Parameters | Expected Response Fields |
| :--- | :--- | :--- | :--- | :--- |
| **Student Login** | `POST` | `/api/v1/auth/student/login` | `identifier`, `password` | `access_token`, `student_id`, `full_name`, `class_name` |
| **Verify Identity** | `GET` | `/api/v1/auth/me` | Bearer Token Header | `id`, `username`, `role`, `is_active`, `full_name` |
| **Dashboard Stats** | `GET` | `/api/v1/student/me` | Bearer Token Header | `percentage`, `attendance_status`, `below_minimum`, `required_future_classes`, `missable_future_classes` |
| **Subject Breakdown** | `GET` | `/api/v1/student/attendance/subjects` | Bearer Token Header | List of `{ subject_name, subject_code, total, present, absent, od, percentage }` |
| **Class Timetable** | `GET` | `/api/v1/student/timetable` | Bearer Token Header | `class_name`, `timetable` list |

---

## 3. Faculty Mobile API Contract

| Mobile Feature | Method | API Endpoint Path | Payload / Format | Expected Response Fields |
| :--- | :--- | :--- | :--- | :--- |
| **Faculty Login** | `POST` | `/api/v1/auth/login` | `username_or_email`, `password` | `access_token`, `user_id`, `role` |
| **Personal Schedule** | `GET` | `/api/v1/faculty/timetable` | Bearer Token Header | `faculty_id`, `timetable` list |
| **Active Class Slot** | `GET` | `/api/v1/faculty/active-class` | Bearer Token Header | `has_active_class`, `active_class` details |
| **Start Session** | `POST` | `/api/v1/faculty/sessions/start` | Bearer Token Header | `session_id`, `status: "ACTIVE"` |
| **Active Roster** | `GET` | `/api/v1/faculty/sessions/active` | Bearer Token Header | `has_active_session`, `session`, `roster` list |
| **Manual Attendance** | `POST` | `/api/v1/faculty/sessions/{id}/attendance` | `student_id`, `status` (`PRESENT`/`ABSENT`) | Updated record details |
| **Mark OD** | `POST` | `/api/v1/faculty/sessions/{id}/attendance` | `student_id`, `status: "OD"`, `od_reason` | Updated record details with `od_reason` |
| **Group Photo Upload** | `POST` | `/api/v1/faculty/sessions/{id}/recognize-image` | `multipart/form-data` (`file`) | `faces_detected`, `high_confidence_matches`, `uncertain_matches`, `unknown_faces` |
| **Confirm Recognition**| `POST` | `/api/v1/faculty/sessions/{id}/confirm-recognition` | `confirmed_candidates` list | `message`, `session_id`, `records` list |
| **Complete Session** | `POST` | `/api/v1/faculty/sessions/{id}/complete` | Bearer Token Header | `message`, `session_id` |

---

## 4. Group Photo Recognition & Review Workflow

### Multipart Request Specs
- **Content Type**: `multipart/form-data`
- **Field Name**: `file`
- **Supported Formats**: JPEG (`image/jpeg`), PNG (`image/png`), WebP (`image/webp`)
- **Max File Size**: **10MB** (Returns `413 Payload Too Large` if exceeded)

### Review UI Flow in Flutter
1. Faculty captures group photo via Camera or Gallery.
2. Photo is previewed on `ImagePreviewScreen` with Retake / Process options.
3. On submission, image is sent to `/recognize-image`.
4. Resulting `RecognitionResultModel` opens `RecognitionReviewScreen`:
   - High-confidence matches are checked by default.
   - Uncertain matches display candidate identities with confidence scores. Faculty must explicitly select student or mark unknown.
   - Deduplication algorithm guarantees no student is confirmed twice.
5. "Confirm Attendance" posts selected student IDs to `/confirm-recognition`.

---

## 5. Error Handling & Mobile UX Requirements

- **Target Dimensions**: All interactive buttons & touch targets must be `>= 48px`.
- **Loading Indicators**: Display non-blocking progress bars during API requests.
- **Error Banners**: Display user-friendly snackbars/cards on API errors (`400`, `401`, `403`, `413`, `500`).
- **Network Resilience**: Gracefully handle network timeouts and offline states with Retry options.
