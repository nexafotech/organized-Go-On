# Authentication & Identity API Documentation

## 1. Student Login
Authenticate student accounts via Register Number or Email.

- **Endpoint**: `POST /api/v1/auth/student/login`
- **Method**: `POST`
- **Authentication**: None (Public)
- **Role Access**: Public

### Request Body
```json
{
  "identifier": "23CY001",
  "password": "student123"
}
```

### Success Response (`200 OK`)
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI...",
  "token_type": "bearer",
  "student_id": 1,
  "roll_number": "23CY001",
  "full_name": "Demo Student 001",
  "class_name": "II Year CSE Cyber Security - Class 1",
  "force_password_change": false
}
```

### Error Responses
- `401 Unauthorized`: Invalid credentials or password mismatch.
- `403 Forbidden`: Account is disabled (`is_active = false`) or account locked due to excessive failed attempts.

---

## 2. Faculty & Admin Login
Authenticate Faculty or Admin accounts via Username, Employee ID, or Email.

- **Endpoint**: `POST /api/v1/auth/login`
- **Method**: `POST`
- **Authentication**: None (Public)
- **Role Access**: Public

### Request Body
```json
{
  "username_or_email": "faculty",
  "password": "faculty123"
}
```

### Success Response (`200 OK`)
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI...",
  "token_type": "bearer",
  "user_id": 2,
  "role": "FACULTY",
  "force_password_change": false
}
```

---

## 3. Profile & Session Verification (`/me`)
Retrieves authoritative account details, current active role, and profile state.

- **Endpoint**: `GET /api/v1/auth/me`
- **Method**: `GET`
- **Authentication**: Bearer Token
- **Role Access**: `STUDENT`, `FACULTY`, `ADMIN`

### Success Response (`200 OK`)
```json
{
  "id": 1,
  "username": "23CY001",
  "email": "demo001@college.edu",
  "role": "STUDENT",
  "is_active": true,
  "full_name": "Demo Student 001",
  "faculty_profile_id": null
}
```

---

## 4. Account Logout
Invalidates local session / clears server token cache.

- **Endpoint**: `POST /api/v1/auth/logout` (or `/api/v1/auth/student/logout`)
- **Method**: `POST`
- **Authentication**: Bearer Token
- **Response**: `{"message": "Logged out successfully"}`
