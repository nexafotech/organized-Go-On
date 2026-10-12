# Attendance Management & Policy Engine API Documentation

## 1. Student Portal APIs

### Student Summary & Statistics
Retrieves overall percentage, calculation mode (`IMPACT_BASED` vs `RECORD_BASED`), minimum required percentage, status (`OK`, `WARNING`, `CRITICAL`), and class recovery estimates.

- **Endpoint**: `GET /api/v1/student/me`
- **Method**: `GET`
- **Authentication**: Bearer Token
- **Role Access**: `STUDENT`

#### Response (`200 OK`)
```json
{
  "student_id": 1,
  "full_name": "Demo Student 001",
  "register_number": "23CY001",
  "is_active": true,
  "total": 20,
  "present": 16,
  "absent": 4,
  "od": 0,
  "percentage": 80.0,
  "calculation_mode": "IMPACT_BASED",
  "attendance_status": "OK",
  "minimum_required": 75.0,
  "below_minimum": false,
  "required_future_classes": 0,
  "missable_future_classes": 4,
  "estimated_working_days": 0
}
```

### Subject Breakdown
- **Endpoint**: `GET /api/v1/student/attendance/subjects`
- **Method**: `GET`
- **Role Access**: `STUDENT`
- **Response**: List of subjects with `total`, `present`, `absent`, `od`, and `percentage`.

### Student Timetable
- **Endpoint**: `GET /api/v1/student/timetable`
- **Method**: `GET`
- **Role Access**: `STUDENT`

---

## 2. Faculty Attendance Session APIs

### Active Class Lookup
Checks current server time against the faculty's timetable to find current active/upcoming class slot.

- **Endpoint**: `GET /api/v1/faculty/active-class`
- **Method**: `GET`
- **Role Access**: `FACULTY`

#### Response (`200 OK`)
```json
{
  "has_active_class": true,
  "active_class": {
    "timetable_entry_id": 1,
    "class_name": "II Year CSE Cyber Security - Class 1",
    "subject_code": "FDS",
    "subject_name": "Foundations of Data Science",
    "period_number": 1,
    "period_name": "Period 1",
    "start_time": "09:10",
    "end_time": "10:00"
  }
}
```

### Start Session
Starts a new `ACTIVE` ClassSession for the current active timetable entry.

- **Endpoint**: `POST /api/v1/faculty/sessions/start`
- **Method**: `POST`
- **Role Access**: `FACULTY`
- **Response**: `{"session_id": 10, "status": "ACTIVE"}`

### Active Session Roster
Retrieves active session details and student roster.

- **Endpoint**: `GET /api/v1/faculty/sessions/active`
- **Method**: `GET`
- **Role Access**: `FACULTY`

### Manual Attendance Marking
Marks individual student attendance (`PRESENT`, `ABSENT`, or `OD`).

- **Endpoint**: `POST /api/v1/faculty/sessions/{session_id}/attendance`
- **Method**: `POST`
- **Role Access**: `FACULTY`
- **Request Body**:
```json
{
  "student_id": 1,
  "status": "OD",
  "od_reason": "Sports Event Approved"
}
```

### Complete Session
Transitions session status to `COMPLETED`.

- **Endpoint**: `POST /api/v1/faculty/sessions/{session_id}/complete`
- **Method**: `POST`
- **Role Access**: `FACULTY`
- **Response**: `{"message": "Session completed successfully", "session_id": 10}`
