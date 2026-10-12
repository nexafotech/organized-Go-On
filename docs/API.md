# Attendance Marker — API Specification

## 1. Overview & Base Configuration
- **Base URL**: `http://<host>:8000/api/v1`
- **Content Type**: `application/json` (unless specifying `multipart/form-data` for face recognition uploads)
- **Response Protocol**: Standard JSON objects containing domain payload or detailed error schemas (`{"detail": "..."}`)

---

## 2. Authentication Standard
Endpoints protected by security dependencies require a Bearer token in the `Authorization` HTTP header:
```http
Authorization: Bearer <access_token>
```

---

## 3. Global HTTP Status Codes

| Status Code | Meaning | Description |
| :--- | :--- | :--- |
| `200 OK` | Request Succeeded | Returned on successful queries, updates, and actions. |
| `400 Bad Request` | Validation Error | Returned on invalid input payload, duplicate entity conflict, or invalid state. |
| `401 Unauthorized` | Invalid/Missing Token | Returned when authentication token is missing, expired, or invalid. |
| `403 Forbidden` | Access Denied | Returned when account is disabled or user lacks required role (`ADMIN`, `FACULTY`, `STUDENT`). |
| `404 Not Found` | Resource Missing | Target entity (student, session, timetable entry) does not exist. |
| `413 Payload Too Large` | Image Size Exceeded | File upload exceeds maximum allowable size (10MB). |

---

## 4. Module API Navigation

- [Authentication API Specs (`docs/AUTH.md`)](file:///home/kali/Downloads/Attendance_Marker/docs/AUTH.md)
- [Attendance & Session API Specs (`docs/ATTENDANCE.md`)](file:///home/kali/Downloads/Attendance_Marker/docs/ATTENDANCE.md)
- [Admin Management Specs (`docs/ADMIN.md`)](file:///home/kali/Downloads/Attendance_Marker/docs/ADMIN.md)
- [Biometric Recognition Specs (`docs/RECOGNITION.md`)](file:///home/kali/Downloads/Attendance_Marker/docs/RECOGNITION.md)
- [Mobile App API Integration Contract (`docs/MOBILE_INTEGRATION.md`)](file:///home/kali/Downloads/Attendance_Marker/docs/MOBILE_INTEGRATION.md)
