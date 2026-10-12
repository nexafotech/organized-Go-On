# Class 1 Student Onboarding Guide — Development Onboarding Data

## 1. Overview & Scope
This document specifies the structured student onboarding dataset for **II Year CSE Cyber Security - Class 1** (`college_seed/students_class1_development.json`).

> [!IMPORTANT]
> **DEVELOPMENT ONBOARDING DATA ONLY**
> This dataset is prepared exclusively for developmental testing and onboarding validation. No database mutations, student account creations, password generation, or biometric enrollments have been performed in this milestone.

---

## 2. Roster Summary & Breakdown

| Category | Count | Register Number Range | Notes |
| :--- | :--- | :--- | :--- |
| **Total Students** | **64** | `721025149001`–`721025149063`, `301` | Exact count from official college roster |
| **Regular Students** | **63** | `721025149001`–`721025149063` | 63 continuous university register numbers |
| **Lateral-Entry Students** | **1** | `301` | **Akhil** (Register No: 301, Student ID: Not Assigned) |
| **System Capacity Limit** | **130** | Across Class 1 & Class 2 combined | Class 1 count (64) is within capacity (64 / 130) |

---

## 3. Lateral-Entry Student Specification (Akhil)
- **Full Name**: `Akhil`
- **Register Number (`roll_number`)**: `301` (MUST NOT be numbered as 64)
- **Student ID (`student_id`)**: `null` (Unassigned / Not yet allocated by college administration)
- **Entry Type (`entry_type`)**: `LATERAL_ENTRY`
- **Class**: `II Year CSE Cyber Security - Class 1`
- **Status**: `is_active: true`

---

## 4. Dataset Schema

```json
[
  {
    "roll_number": "721025149001",
    "student_id": null,
    "full_name": "ABINAYA B",
    "class_name": "II Year CSE Cyber Security - Class 1",
    "entry_type": "REGULAR",
    "is_active": true
  },
  ...
  {
    "roll_number": "301",
    "student_id": null,
    "full_name": "Akhil",
    "class_name": "II Year CSE Cyber Security - Class 1",
    "entry_type": "LATERAL_ENTRY",
    "is_active": true
  }
]
```

### Field Definitions:
- `roll_number` (String, Required, Unique): University register number used as the primary academic identifier and student login identifier.
- `student_id` (String/Null, Optional): College internal student identifier if allocated; otherwise `null`.
- `full_name` (String, Required): Official student full name preserving source uppercase/casing.
- `class_name` (String, Required): Must match `"II Year CSE Cyber Security - Class 1"`.
- `entry_type` (String, Required): Either `"REGULAR"` or `"LATERAL_ENTRY"`.
- `is_active` (Boolean, Required): Default `true`.

---

## 5. Validation Rules (`scripts/validate_class1_student_roster.py`)

1. **Total Count**: Exactly 64 records must be present.
2. **Regular Count**: Exactly 63 records with `entry_type: "REGULAR"`.
3. **Lateral Count**: Exactly 1 record with `entry_type: "LATERAL_ENTRY"`.
4. **Register Number Uniqueness**: Every `roll_number` must be unique; duplicate register numbers are rejected.
5. **Lateral Identifier Integrity**: Lateral entry student (Akhil) must have `roll_number == "301"` and `student_id == null`.
6. **Class Matching**: Every student must belong to `"II Year CSE Cyber Security - Class 1"`.
7. **Capacity Constraint**: Dataset size must not exceed system capacity limit of 130 total students.
8. **Duplicate Name Handling**: Same student names are flagged as warnings (`WARN`) for verification, not hard blocking errors (`FAIL`), provided roll numbers are distinct.

### Validation CLI:
```bash
python scripts/validate_class1_student_roster.py
```
- **Exit Code 0**: Full pass.
- **Exit Code 1**: Valid dataset with informational warnings (e.g., unassigned student IDs).
- **Exit Code 2**: Blocking schema or integrity errors.

---

## 6. Production Schema Compatibility Analysis

| Field in JSON Dataset | Supported in DB Student Model (`Student`)? | Schema Notes |
| :--- | :--- | :--- |
| `roll_number` | **YES** (`roll_number`, String(50), Unique) | Matches primary student register number / login identifier |
| `full_name` | **YES** (`full_name`, String(100)) | Matches student full name |
| `class_name` | **YES** (`class_id` foreign key via `ClassSection`) | Resolves to ClassSection table |
| `is_active` | **YES** (`is_active`, Boolean) | Active/disabled account state |
| `student_id` | **METADATA** (Not a separate column) | Roll number serves as unique identifier in current DB model |
| `entry_type` | **METADATA** (Not a separate column) | Managed in onboarding/import pipelines without requiring DB schema changes |

---

## 7. Next Steps: Credential Preparation & Database Ingestion
1. **Milestone 10C.11.2**: Generate secure initial credentials (temporary password generation + bcrypt hashing) following Admin password lifecycle policies.
2. **Database Ingestion**: Import validated student records into `Student` and `User` models via the authoritative Admin import workflow without deleting existing demo students (`DEV_DEMO_23CY001`–`DEV_DEMO_23CY003`).
