# REAL STUDENT DATA INPUT GUIDE
**Production Student Data Collection, Security Policy & Ingestion Specification**

---

## 1. Overview

This document specifies the data requirements, schema standards, security constraints, and backend compatibility for collecting real student enrollment rosters from the college administration for **II Year CSE Cyber Security — Class 1** and **III Year CSE Cyber Security — Class 2**.

---

## 2. Information Required from the College

For each student enrolled in II/III Year CSE Cyber Security, the college administration must provide the following attributes:

| Field Name | Type | Required | Description & Validation Rules | Example |
| :--- | :--- | :---: | :--- | :--- |
| **`roll_number`** | String(50) | **Yes** | Official institutional roll/register number. Must be unique across all students. Used as `User.username` and `User.login_identifier` for mobile sign-in. | `23CY001` |
| **`full_name`** | String(100) | **Yes** | Official student full name as recorded in college records. | `Jane Doe` |
| **`email`** | String(100) | Optional | Official college institutional email address. If omitted, importer defaults to `{roll_number.lower()}@student.college.edu`. | `23cy001@student.college.edu` |
| **`class_name`** | String(100) | **Yes** | Assigned class section. Must exactly match one of the active class sections: <br>• `II Year CSE Cyber Security - Class 1`<br>• `III Year CSE Cyber Security - Class 2` | `II Year CSE Cyber Security - Class 1` |
| **`department`** | String(100) | Optional | Academic department name. Defaults to `"Cyber Security"`. | `Cyber Security` |
| **`semester`** | String(20) | Optional | Academic semester identifier. Defaults to `"Semester 4"` or `"Semester 6"`. | `Semester 4` |
| **`is_active`** | Boolean | **Yes** | Enrollment status. `true` for active students, `false` for discontinued/suspended students. | `true` |

---

## 3. Credential & Security Policy

> [!CAUTION]
> **ZERO-CREDENTIAL REPOSITORY POLICY**
> - Student passwords must **NEVER** be committed to Git or pushed to remote repositories.
> - The production template file [`college_seed/students_production_template.json`](file:///C:/Users/Abishek/Desktop/am-oss/college_seed/students_production_template.json) omits plaintext passwords to prevent accidental credential leakage.
> - Existing demo passwords (`student123`) in development fixtures are strictly **DEVELOPMENT ONLY**.

### Security Rules for Real Student Onboarding
1. **Zero Biometrics in Seed Dataset**:
   - **No biometric vectors, face embeddings, or student photos** belong in this dataset.
   - Face enrollment is conducted exclusively through the authorized physical kiosk / enrollment workflow in a subsequent operational milestone.
2. **Initial Temporary Credential Provisioning**:
   - During private deployment outside Git, initial temporary passwords are generated or default to the administrative baseline.
   - All passwords are encrypted with `bcrypt` hashes (`app.core.security.get_password_hash()`) upon import.
3. **Mandatory First-Time Password Reset**:
   - Newly provisioned student accounts are flagged with `force_password_change = true`.
   - Upon first mobile sign-in, the student is immediately prompted to configure a permanent, confidential password via the `ChangePasswordDialog`.

---

## 4. Production Schema Template

The schema template is defined in [`college_seed/students_production_template.json`](file:///C:/Users/Abishek/Desktop/am-oss/college_seed/students_production_template.json):

```json
[
  {
    "roll_number": "2026_CYBER_C1_001",
    "full_name": "STUDENT_PLACEHOLDER_C1_001",
    "email": "student_c1_001@college.edu",
    "class_name": "II Year CSE Cyber Security - Class 1",
    "semester": "Semester 4",
    "department": "Cyber Security",
    "is_active": true
  },
  {
    "roll_number": "2026_CYBER_C2_001",
    "full_name": "STUDENT_PLACEHOLDER_C2_001",
    "email": "student_c2_001@college.edu",
    "class_name": "III Year CSE Cyber Security - Class 2",
    "semester": "Semester 6",
    "department": "Cyber Security",
    "is_active": true
  }
]
```

---

## 5. Backend Importer & API Compatibility Audit

### Cross-Check against `app/services/college_importer.py` (`import_students`)

| JSON Field | Target Model & DB Column | Importer Behavior & Validation | Compatibility Status |
| :--- | :--- | :--- | :---: |
| `roll_number` | `Student.roll_number` & `User.username` & `User.login_identifier` | Verified non-empty. Checked for batch duplicates and database uniqueness collisions. | **Compatible** |
| `full_name` | `Student.full_name` | Verified non-empty. Trimmed. | **Compatible** |
| `email` | `Student.email` & `User.email` | Checked for uniqueness in `users` table. Defaults to `{roll_number.lower()}@student.college.edu` if omitted. | **Compatible** |
| `class_name` | `Student.class_id` (FK to `class_sections.id`) | Looked up in `ClassSection` table by exact name string. Raises error if class section does not exist. | **Compatible** |
| `is_active` | `Student.is_active` & `User.is_active` | Controls account authentication and active roster inclusion. | **Compatible** |
| `semester` | `Student.semester` | Academic profile field. | **Compatible** |
| `department` | `Student.department` | Academic profile field. | **Compatible** |

### API Endpoint Compatibility
- The JSON payload format above is directly consumable by:
  - **Bulk Admin API**: `POST /api/v1/admin/import/students` in [`app/api/admin.py`](file:///C:/Users/Abishek/Desktop/am-oss/app/api/admin.py).
  - **Bundle Seeder**: `import_college_seed_bundle()` via `python seed_college.py`.

---

## 6. Supported Class Sections

The student dataset supports the two active sections defined in [`college_seed/class_sections.json`](file:///C:/Users/Abishek/Desktop/am-oss/college_seed/class_sections.json):

1. **`II Year CSE Cyber Security - Class 1`** (Academic Year `2026-2027`)
2. **`III Year CSE Cyber Security - Class 2`** (Academic Year `2026-2027`)

---

## 7. Information Checklist Still Required from the College

Before importing real student records into the system:

- [ ] Official student roster for **II Year CSE Cyber Security — Class 1** (Roll number + Full name + Institutional email).
- [ ] Official student roster for **III Year CSE Cyber Security — Class 2** (Roll number + Full name + Institutional email).
- [ ] Confirmation of active enrollment status for all listed students.
- [ ] Confirmation that all students belong to appropriate academic semester (`Semester 4` or `Semester 6`).
