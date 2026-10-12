# Admin Operations & Management API Documentation

## 1. Faculty Management APIs

- `GET /api/v1/admin/faculty`: List all faculty accounts.
- `POST /api/v1/admin/faculty`: Create new faculty account.
- `PUT /api/v1/admin/faculty/{id}`: Update faculty details & status (`is_active`).
- `POST /api/v1/admin/faculty/{id}/reset-password`: Reset faculty password.

---

## 2. Student Management APIs

- `GET /api/v1/admin/students`: List all student profiles.
- `POST /api/v1/admin/students`: Create new student account.
- `PUT /api/v1/admin/students/{id}`: Update student details & status (`is_active`). Synchronizes linked `User.is_active`.
- `POST /api/v1/admin/students/{id}/reset-password`: Reset student password.

---

## 3. Academic Structure APIs

- `GET/POST /api/v1/admin/classes`: Class sections CRUD.
- `GET/POST /api/v1/admin/subjects`: Subjects CRUD.
- `GET/POST /api/v1/admin/periods`: Configurable period timings CRUD.
- `GET/POST /api/v1/admin/faculty-assignments`: Faculty-Subject-Class mappings.
- `GET/POST /api/v1/admin/timetable`: Master timetable entries.

---

## 4. Bulk Data Import APIs

Admin import endpoints enforce strict pre-validation. Duplicate items return `400 Bad Request` with detailed failure messages instead of overwriting existing DB records.

### Import Endpoints

- `POST /api/v1/admin/import/students`: Import array of student objects.
- `POST /api/v1/admin/import/faculty`: Import array of faculty objects.
- `POST /api/v1/admin/import/subjects`: Import array of subject objects.
- `POST /api/v1/admin/import/classes`: Import array of class section objects.
- `POST /api/v1/admin/import/timetable`: Import array of timetable entry objects.
- `POST /api/v1/admin/import/college-seed`: Imports official `college_seed/` directory files into DB.

### Validation Failure Format (`400 Bad Request`)
```json
{
  "detail": {
    "message": "Student import failed validation",
    "errors": [
      "Row 2: Student roll_number '23CY001' already exists",
      "Row 5: Class section 'NonExistentClass' not found"
    ]
  }
}
```
