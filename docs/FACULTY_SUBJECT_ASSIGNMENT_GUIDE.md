# FACULTY ↔ SUBJECT ASSIGNMENT GUIDE
**Production Faculty-to-Subject Mapping Specification & Validation Checklist**

---

## 1. Overview

This document specifies the faculty-to-subject assignment matrix for **II Year CSE Cyber Security — Class 1** and **III Year CSE Cyber Security — Class 2**. 

In the Attendance Marker architecture, a `FacultyAssignment` links a specific `ClassSection`, a `Subject`, and a `Faculty` member. This assignment is the critical relational bridge that authorizes faculty to initiate attendance sessions and enables the generation of student/faculty timetables.

---

## 2. Subject Assignment Matrix

The curriculum consists of **14 distinct courses/modules** per class section:
- **Theory Courses**: FDS, DMC, DPCO, OOPS, DS, ACE-I, UHV, TWM
- **Laboratory Courses**: FDS LAB, DS LAB, JAVA LAB
- **Institutional / Department Modules**: IIC, LIB, ASSOC

### Class 1: II Year CSE Cyber Security — Class 1
| # | Subject Code | Subject Name | Type | Faculty Username | Employee ID Ref | Assignment Status |
| :-: | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `FDS` | Foundations of Data Science | Theory | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 2 | `DMC` | Discrete Mathematics & Cryptography | Theory | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 3 | `FDS LAB` | Foundations of Data Science Laboratory | Lab | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 4 | `DPCO` | Digital Principles & Computer Organization | Theory | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 5 | `OOPS` | Object Oriented Programming Systems | Theory | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 6 | `DS` | Data Structures | Theory | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 7 | `ACE-I` | Aptitude & Communication Enhancement I | Practical | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 8 | `UHV` | Universal Human Values | Theory | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 9 | `DS LAB` | Data Structures Laboratory | Lab | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 10 | `IIC` | Innovation & Incubation Cell | Activity | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 11 | `JAVA LAB` | Java Programming Laboratory | Lab | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 12 | `TWM` | Technical Writing & Mentoring | Seminar | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 13 | `LIB` | Library Hour | Self-Study | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 14 | `ASSOC` | Department Association Hour | Co-Curricular | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |

### Class 2: III Year CSE Cyber Security — Class 2
| # | Subject Code | Subject Name | Type | Faculty Username | Employee ID Ref | Assignment Status |
| :-: | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `FDS` | Foundations of Data Science | Theory | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 2 | `DMC` | Discrete Mathematics & Cryptography | Theory | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 3 | `FDS LAB` | Foundations of Data Science Laboratory | Lab | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 4 | `DPCO` | Digital Principles & Computer Organization | Theory | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 5 | `OOPS` | Object Oriented Programming Systems | Theory | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 6 | `DS` | Data Structures | Theory | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 7 | `ACE-I` | Aptitude & Communication Enhancement I | Practical | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 8 | `UHV` | Universal Human Values | Theory | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 9 | `DS LAB` | Data Structures Laboratory | Lab | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 10 | `IIC` | Innovation & Incubation Cell | Activity | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 11 | `JAVA LAB` | Java Programming Laboratory | Lab | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 12 | `TWM` | Technical Writing & Mentoring | Seminar | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 13 | `LIB` | Library Hour | Self-Study | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |
| 14 | `ASSOC` | Department Association Hour | Co-Curricular | `FACULTY_TO_BE_CONFIRMED` | `PENDING` | `PENDING_COLLEGE_CONFIRMATION` |

---

## 3. Assignment Status Definitions

- **`CONFIRMED`**: Faculty member is verified and successfully linked to the class-subject pair.
- **`PENDING_FACULTY`**: Subject is configured, but faculty onboarding details (username/employee ID) are awaited.
- **`PENDING_COLLEGE_CONFIRMATION`**: Subject mapping template prepared with placeholder tokens; awaiting official teacher allocation from department head.

---

## 4. Ingestion Validation Checklist

The backend ingestion engine [`app/services/college_importer.py`](file:///C:/Users/Abishek/Desktop/am-oss/app/services/college_importer.py) strictly enforces the following validation invariants during `import_faculty_assignments()`:

1. **Unique Class-Subject Assignment**: Each `(class_id, subject_id)` tuple must have exactly one active assignment record. Attempting to assign multiple faculty to the same subject in the same class will raise an error.
2. **Prior Existence of Dependencies**:
   - `ClassSection` must already exist in the database (resolved by `class_name`).
   - `Subject` must already exist in the database (resolved by `subject_code`).
   - `Faculty` must already exist in the database with an active user account (resolved by `faculty_username`).
3. **No NULL Foreign Keys**: The database model `FacultyAssignment` requires `faculty_id NOT NULL`. If `faculty_username` is `null` or a placeholder, the importer safely records the row as `skipped_unassigned` without inserting a broken foreign key.
4. **Timetable Prerequisite Guard**: Timetable entries in `timetable_class1.json` have a mandatory foreign key `assignment_id`. Timetable entries cannot be created for any subject whose faculty assignment is unassigned or pending.

---

## 5. Backend Importer & API Compatibility Audit

### Cross-Check against `app/services/college_importer.py` (`import_faculty_assignments`)

| Input JSON Key | Database Model / Column | Importer Behavior | Status |
| :--- | :--- | :--- | :---: |
| `class_name` | `FacultyAssignment.class_id` $\rightarrow$ `ClassSection.id` | Resolves class by name (`db.query(ClassSection).filter(name == class_name)`). | **Compatible** |
| `subject_code` | `FacultyAssignment.subject_id` $\rightarrow$ `Subject.id` | Resolves subject by code (`db.query(Subject).filter(code == subject_code)`). | **Compatible** |
| `faculty_username` | `FacultyAssignment.faculty_id` $\rightarrow$ `Faculty.id` | Resolves faculty user (`db.query(User).filter(username == faculty_username)`). Gracefully skips if unassigned/placeholder. | **Compatible** |

### API Endpoint Compatibility
- The JSON array in [`college_seed/faculty_assignments_production_template.json`](file:///C:/Users/Abishek/Desktop/am-oss/college_seed/faculty_assignments_production_template.json) is directly consumable by:
  - **Admin REST API**: `POST /api/v1/admin/assignments` in [`app/api/admin.py`](file:///C:/Users/Abishek/Desktop/am-oss/app/api/admin.py).
  - **Bundle Seeder**: `import_college_seed_bundle()` via `python seed_college.py`.

---

## 6. Information Checklist Still Required from the College

To finalize the faculty-to-subject assignment matrix:

- [ ] Official teacher allocation for all 14 subjects in **II Year CSE Cyber Security — Class 1**.
- [ ] Official teacher allocation for all 14 subjects in **III Year CSE Cyber Security — Class 2**.
- [ ] Confirmation whether lab sessions (`FDS LAB`, `DS LAB`, `JAVA LAB`) share the primary theory professor or are assigned to dedicated laboratory instructors.
- [ ] Confirmation of faculty coordinators assigned to non-classroom modules (`IIC`, `TWM`, `LIB`, `ASSOC`).
