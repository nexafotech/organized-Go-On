# MILESTONE 10C — TIMETABLE AUDIT REPORT
**Production Timetable Structure, Grid Validation & Relational Dependency Analysis**

---

## 1. Executive Summary

This document presents the comprehensive audit of the production timetable dataset for **II Year CSE Cyber Security — Class 1** and the availability status for **Class 2**.

The Class 1 timetable ([`college_seed/timetable_class1.json`](file:///C:/Users/Abishek/Desktop/am-oss/college_seed/timetable_class1.json)) contains a complete **42-slot weekly schedule** (Monday through Saturday, 7 periods daily). All 42 slots have been validated with 0 syntax errors, 0 duplicate period collisions, and 100% valid curriculum subject codes.

Class 2 currently has no timetable file in the repository and is designated as **PENDING COLLEGE DATA**.

---

## 2. Class 1 Weekly Timetable Matrix (Human-Readable)

### Period Timing Reference (`college_seed/periods.json`)
- **Period 1 (P1)**: `09:10 - 10:00`
- **Period 2 (P2)**: `10:00 - 10:50`
- **Period 3 (P3)**: `11:10 - 12:00`
- **Period 4 (P4)**: `12:00 - 12:50`
- **Period 5 (P5)**: `13:40 - 14:30`
- **Period 6 (P6)**: `14:30 - 15:20`
- **Period 7 (P7)**: `15:20 - 16:10`

---

### Class 1 Master Grid: II Year CSE Cyber Security — Class 1

| Day | P1 (09:10–10:00) | P2 (10:00–10:50) | P3 (11:10–12:00) | P4 (12:00–12:50) | P5 (13:40–14:30) | P6 (14:30–15:20) | P7 (15:20–16:10) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Monday** | **FDS**<br>Foundations of Data Science | **DMC**<br>Discrete Math & Cryptography | **DPCO**<br>Digital Principles & Comp Org | **OOPS**<br>Object Oriented Programming | **FDS LAB**<br>Data Science Lab | **FDS LAB**<br>Data Science Lab | **FDS LAB**<br>Data Science Lab |
| **Tuesday** | **DS LAB**<br>Data Structures Lab | **DS LAB**<br>Data Structures Lab | **DS LAB**<br>Data Structures Lab | **DS**<br>Data Structures | **ACE-I**<br>Aptitude & Comm Enh I | **UHV**<br>Universal Human Values | **TWM**<br>Technical Writing & Mentoring |
| **Wednesday** | **JAVA LAB**<br>Java Programming Lab | **JAVA LAB**<br>Java Programming Lab | **JAVA LAB**<br>Java Programming Lab | **FDS**<br>Foundations of Data Science | **DMC**<br>Discrete Math & Cryptography | **DPCO**<br>Digital Principles & Comp Org | **OOPS**<br>Object Oriented Programming |
| **Thursday** | **OOPS**<br>Object Oriented Programming | **FDS**<br>Foundations of Data Science | **DMC**<br>Discrete Math & Cryptography | **DPCO**<br>Digital Principles & Comp Org | **DS**<br>Data Structures | **IIC**<br>Innovation & Incubation Cell | **LIB**<br>Library Hour |
| **Friday** | **DPCO**<br>Digital Principles & Comp Org | **DS**<br>Data Structures | **FDS**<br>Foundations of Data Science | **DMC**<br>Discrete Math & Cryptography | **OOPS**<br>Object Oriented Programming | **ACE-I**<br>Aptitude & Comm Enh I | **ASSOC**<br>Dept Association Hour |
| **Saturday** | **DMC**<br>Discrete Math & Cryptography | **OOPS**<br>Object Oriented Programming | **DS**<br>Data Structures | **FDS**<br>Foundations of Data Science | **DPCO**<br>Digital Principles & Comp Org | **UHV**<br>Universal Human Values | **LIB**<br>Library Hour |

---

## 3. Subject Distribution & Weekly Hours (Class 1)

All 14 subjects from [`college_seed/subjects.json`](file:///C:/Users/Abishek/Desktop/am-oss/college_seed/subjects.json) are represented:

| Subject Code | Full Subject Name | Course Type | Weekly Hours (Periods) | Days Scheduled |
| :--- | :--- | :--- | :---: | :--- |
| `FDS` | Foundations of Data Science | Core Theory | **5** | Mon, Wed, Thu, Fri, Sat |
| `DMC` | Discrete Mathematics & Cryptography | Core Theory | **5** | Mon, Wed, Thu, Fri, Sat |
| `DPCO` | Digital Principles & Computer Organization | Core Theory | **5** | Mon, Wed, Thu, Fri, Sat |
| `OOPS` | Object Oriented Programming Systems | Core Theory | **5** | Mon, Wed, Thu, Fri, Sat |
| `DS` | Data Structures | Core Theory | **4** | Tue, Thu, Fri, Sat |
| `FDS LAB` | Foundations of Data Science Laboratory | Core Lab | **3** (Block) | Monday (P5, P6, P7) |
| `DS LAB` | Data Structures Laboratory | Core Lab | **3** (Block) | Tuesday (P1, P2, P3) |
| `JAVA LAB` | Java Programming Laboratory | Core Lab | **3** (Block) | Wednesday (P1, P2, P3) |
| `ACE-I` | Aptitude & Communication Enhancement I | Skill Practical | **2** | Tue (P5), Fri (P6) |
| `UHV` | Universal Human Values | Value Education | **2** | Tue (P6), Sat (P6) |
| `LIB` | Library Hour | Self-Study | **2** | Thu (P7), Sat (P7) |
| `TWM` | Technical Writing & Mentoring | Seminar | **1** | Tue (P7) |
| `IIC` | Innovation & Incubation Cell | Activity | **1** | Thu (P6) |
| `ASSOC` | Department Association Hour | Co-Curricular | **1** | Fri (P7) |
| **TOTAL** | | | **42** | **Full Weekly Schedule** |

---

## 4. Class 2 Timetable Status

- **Status**: **`PENDING COLLEGE DATA`**
- **Audit Finding**: No `timetable_class2.json` file exists in the repository.
- **Rule Enforced**: Class 2 timetable will **NOT** be fabricated. When the college administration delivers the Class 2 weekly schedule, it will be formatted into `college_seed/timetable_class2.json` matching the verified schema.

---

## 5. Ingestion Validation & Integrity Checks

An audit of [`college_seed/timetable_class1.json`](file:///C:/Users/Abishek/Desktop/am-oss/college_seed/timetable_class1.json) was conducted against the validation logic in [`app/services/college_importer.py`](file:///C:/Users/Abishek/Desktop/am-oss/app/services/college_importer.py):

| Check Description | Criteria | Result | Notes |
| :--- | :--- | :---: | :--- |
| **Class Name Integrity** | Matches `ClassSection.name` in `class_sections.json` | **PASS** | All 42 entries specify `"II Year CSE Cyber Security - Class 1"`. |
| **Day of Week Integrity** | Monday, Tuesday, Wednesday, Thursday, Friday, Saturday | **PASS** | Exactly 7 slots per weekday across all 6 days. |
| **Period Number Validity** | Integer between 1 and 7 | **PASS** | Valid period numbers 1 through 7 for every day. |
| **Subject Code Validity** | Matches `Subject.code` in `subjects.json` | **PASS** | All codes are valid. |
| **Duplicate Slot Detection** | Unique `(class_name, day_of_week, period_number)` | **PASS** | 0 duplicate slot collisions detected. |
| **Block Period Structure** | 3 continuous periods for labs | **PASS** | FDS LAB (Mon P5-P7), DS LAB (Tue P1-P3), JAVA LAB (Wed P1-P3). |
| **Total Valid Entries** | 42 expected for full 6-day week | **PASS** | 42 / 42 valid entries. |
| **Total Invalid Entries** | Corrupt, malformed, or out-of-range rows | **0** | None found. |

---

## 6. Relational Dependency Guard

```
[class_sections.json] ──┐
[subjects.json]       ──┼──► [faculty_assignments.json] ──► [timetable_class1.json]
[faculty.json]        ──┘              │                               │
                                       ▼                               ▼
                             FacultyAssignment (DB)           TimetableEntry (DB)
```

In the database schema, `TimetableEntry` contains a non-null foreign key `assignment_id` referencing `FacultyAssignment.id`:
1. `import_timetable()` resolves each slot's `(class_name, subject_code)` to an existing `FacultyAssignment`.
2. If faculty assignments have not yet been linked to real faculty members (`faculty_username: null` or placeholder), the importer records those timetable slots as `skipped_unassigned` without raising fatal database errors.
3. Once faculty records are ingested and linked in Step 6, `import_timetable()` will immediately link all 42 schedule slots.

---

## 7. Recommendation for Next Steps (Step 6)

1. **Step 6 (Data Integration & Seeding)**:
   - When official faculty names and assignments are confirmed by the college, populate `faculty.json` and `faculty_assignments.json`.
   - Run `import_college_seed_bundle()` or `python seed_college.py` to seed Class Sections, Periods, Subjects, Faculty, Faculty Assignments, and Timetable in dependency order.
   - When Class 2 timetable is supplied, ingest it via `POST /api/v1/admin/import/timetable`.
