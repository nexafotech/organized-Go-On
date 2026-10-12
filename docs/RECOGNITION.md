# Biometric Face Recognition API Documentation

## 1. Process Group Photo
Processes single or multi-face photographs uploaded by Faculty for an `ACTIVE` ClassSession. Matches faces against enrolled student embeddings for the class section.

- **Endpoint**: `POST /api/v1/faculty/sessions/{session_id}/recognize-image`
- **Method**: `POST`
- **Content-Type**: `multipart/form-data`
- **Authentication**: Bearer Token
- **Role Access**: `FACULTY` (Must own the active session)

### Form Parameters
- `file`: Image file (`image/jpeg`, `image/png`, `image/webp`). Max size: **10MB**.

### Success Response (`200 OK`)
```json
{
  "session_id": 10,
  "faces_detected": 3,
  "high_confidence_matches": [
    {
      "student_id": 1,
      "roll_number": "23CY001",
      "full_name": "Demo Student 001",
      "distance": 0.32,
      "confidence": 92.5
    }
  ],
  "uncertain_matches": [
    {
      "face_index": 1,
      "candidates": [
        {
          "student_id": 2,
          "roll_number": "23CY002",
          "full_name": "Demo Student 002",
          "distance": 0.48,
          "confidence": 62.0
        }
      ]
    }
  ],
  "unknown_faces": [
    {
      "face_index": 2
    }
  ]
}
```

### Error Responses
- `400 Bad Request`: Unsupported image format or session not `ACTIVE`.
- `403 Forbidden`: Access denied / user does not own class session.
- `404 Not Found`: Session ID does not exist.
- `413 Payload Too Large`: Image file size exceeds 10MB limit.

---

## 2. Confirm Recognition
Submits faculty-confirmed student candidates to the Attendance Engine.

- **Endpoint**: `POST /api/v1/faculty/sessions/{session_id}/confirm-recognition`
- **Method**: `POST`
- **Authentication**: Bearer Token
- **Role Access**: `FACULTY`

### Request Body
```json
{
  "confirmed_candidates": [
    {
      "student_id": 1,
      "status": "PRESENT",
      "recognized_via": "GROUP_PHOTO"
    },
    {
      "student_id": 2,
      "status": "PRESENT",
      "recognized_via": "GROUP_PHOTO"
    }
  ]
}
```

### Success Response (`200 OK`)
```json
{
  "message": "Successfully recorded attendance for 2 confirmed students",
  "session_id": 10,
  "records": [
    {
      "record_id": 101,
      "student_id": 1,
      "status": "PRESENT",
      "recognized_via": "GROUP_PHOTO"
    }
  ]
}
```
