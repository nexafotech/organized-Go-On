# REAL COLLEGE DATA INPUT GUIDE
**Production Faculty Data Collection, Security Policy & Ingestion Specification**

---

## 1. Overview

This document specifies the exact format, fields, and security constraints required to collect real faculty personnel data from the college administration for the Attendance Marker system.

---

## 2. Information Required from the College

For each faculty member to be onboarded, the college administration must provide the following six attributes:

| Field Name | Type | Required | Description & Validation Rules | Example |
| :--- | :--- | :---: | :--- | :--- |
| **`full_name`** | String(100) | **Yes** | Official full name with title/honorific (e.g., Dr., Prof.). | `Dr. John Doe` |
| **`employee_id`** | String(50) | **Yes** | Unique institutional employee identifier assigned by the college. Used as a secondary login identifier on mobile. Must be unique across all faculty. | `2026_FAC_001` |
| **`username`** | String(50) | **Yes** | Unique handle for authentication. Recommended format: lowercase alphanumeric (e.g., `jdoe` or `fac_cy_01`). Must be unique across all system users. | `fac_jdoe` |
| **`email`** | String(100) | **Yes** | Official college institutional email address. Must be unique across all system users. | `jdoe@college.edu` |
| **`department`** | String(100) | **Yes** | Academic department affiliation (e.g., `Cyber Security`, `Computer Science & Engineering`). | `Cyber Security` |
| **`is_active`** | Boolean | **Yes** | Current employment/teaching status. `true` for active faculty, `false` for inactive/on-leave accounts. | `true` |

---

## 3. Credential & Security Policy

> [!CAUTION]
> **ZERO-CREDENTIAL REPOSITORY POLICY**
> - Production passwords must **NEVER** be committed to Git or pushed to remote version control.
> - Production data files committed to this repository must contain only schema definitions and placeholder tokens.
> - The passwords currently present in template/demo files (`faculty_initial_pass`, `faculty123`, `admin123`, `student123`) are strictly **DEVELOPMENT ONLY** baselines.

### Recommended Credential Workflow
1. **Initial Provisioning**:
   - The college administration issues a cryptographically random, high-entropy temporary password for each faculty member (minimum 8 characters, alphanumeric + symbol).
   - Alternatively, the backend administrator sets temporary initial credentials during a private deployment session outside Git.
2. **Mandatory Password Update on First Login**:
   - When the user account is created, the system sets `force_password_change = true`.
   - Upon first sign-in on the Flutter mobile app or web portal, the user is immediately prompted via the `ChangePasswordDialog` to set a private, permanent password.
3. **At-Rest Storage**:
   - All passwords are encrypted using `bcrypt` hashes (`app.core.security.get_password_hash()`).
   - Plaintext passwords are never persisted to disk or the database.

---

## 4. Production Schema Template

The schema template is defined in [`college_seed/faculty_production_template.json`](file:///C:/Users/Abishek/Desktop/am-oss/college_seed/faculty_production_template.json).

```json
[
  {
    "username": "FACULTY_PLACEHOLDER_001",
    "email": "faculty_placeholder_001@college.edu",
    "employee_id": "EMP_PLACEHOLDER_001",
    "full_name": "Faculty Member Placeholder 001",
    "department": "Cyber Security",
    "password": "SECURE_TEMPORARY_PASSWORD_PLACEHOLDER",
    "is_active": true
  },
  {
    "username": "FACULTY_PLACEHOLDER_002",
    "email": "faculty_placeholder_002@college.edu",
    "employee_id": "EMP_PLACEHOLDER_002",
    "full_name": "Faculty Member Placeholder 002",
    "department": "Computer Science & Engineering",
    "password": "SECURE_TEMPORARY_PASSWORD_PLACEHOLDER",
    "is_active": true
  }
]
```

---

## 5. Backend Importer & API Compatibility Audit

### Cross-Check against `app/services/college_importer.py` (`import_faculty`)

| JSON Field | Target Model & DB Column | Importer Behavior & Validation | Mismatch / Finding |
| :--- | :--- | :--- | :--- |
| `username` | `User.username` (String, Unique) | Checked for non-empty string. Checked for in-batch duplicates and database collisions. | **Compatible** |
| `email` | `User.email` (String, Unique) | Checked for non-empty string. Checked for database collisions. | **Compatible** |
| `employee_id` | `Faculty.employee_id` (String, Unique) & `User.login_identifier` | Checked for non-empty string. Checked for in-batch duplicates and database collisions. | **Compatible** |
| `full_name` | `Faculty.full_name` (String) | Stripped. Defaults to `username` if empty. | **Compatible** |
| `department` | `Faculty.department` (String) | Stripped. Defaults to `"General"` if empty. | **Compatible** |
| `password` | `User.hashed_password` (Bcrypt Hash) | Passed to `get_password_hash()`. Defaults to development baseline if omitted. | **Compatible** |
| `is_active` | `User.is_active` (Boolean) | Controls whether account can authenticate. | **Compatible** |

### API Endpoint Compatibility
- The JSON structure above is directly consumable by:
  - **Bulk API**: `POST /api/v1/admin/import/faculty`
  - **Bundle API**: `POST /api/v1/admin/import/college-seed` (reads `college_seed/faculty.json`)
  - **CLI Seeder**: `python seed_college.py`

---

## 6. Information Checklist Still Required from the College

Before importing real faculty data, the college administration must provide:

- [ ] Complete list of faculty teaching the II/III Year CSE Cyber Security curriculum (14 subjects across Class 1 and Class 2).
- [ ] Official Institutional Employee ID for each faculty member.
- [ ] Preferred unique username handle for each faculty member.
- [ ] Official college email address for each faculty member.
- [ ] Department affiliation for each faculty member.
- [ ] Mapping of which faculty member is assigned to which subject code (`FDS`, `DMC`, `DPCO`, `OOPS`, `DS`, `ACE-I`, `UHV`, `IIC`, `TWM`, `LIB`, `ASSOC`, `FDS LAB`, `DS LAB`, `JAVA LAB`) for Class 1 and Class 2.
