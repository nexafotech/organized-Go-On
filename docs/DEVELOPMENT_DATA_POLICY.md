# Development Data & Security Policy (`docs/DEVELOPMENT_DATA_POLICY.md`)

This policy establishes strict engineering guidelines regarding authentic college data, development seed files, credentials, and biometric assets across the Attendance Marker project.

---

## 1. Distinction Between Data Categories

### A. Raw Source Material (`college_data/`)
- Contains original scans, master timetable photos, official student roll sheets, and raw source photographs.
- **Purpose**: Archival reference and manual/OCR source verification.
- **Rules**: Must be preserved exactly as received. Never modify, crop, or invent data in this folder.

### B. Structured Application Seeds (`college_seed/`)
- Contains formatted JSON files (`subjects.json`, `timetable_class1.json`, `timetable_class2.json`, `students_class1_production.json`, `students_class2_development.json`).
- **Purpose**: Structured input for database initialization scripts (`app/services/college_importer.py`).
- **Rules**: Must accurately reflect verified source data. Changes must pass schema and validation tests (`scripts/validate_class1_student_roster.py`, `scripts/validate_class2_student_roster.py`).

### C. Runtime Development Database (`attendance_system.db`)
- Local SQLite database generated at runtime.
- **Rules**: Excluded from Git via `.gitignore`. **NEVER** commit `.db` or `.sqlite` files to Git.

### D. Confidential Student Credentials (`*.docx`)
- Documents containing temporary student plaintext passwords (e.g. `CLASS1_STUDENT_CREDENTIALS.docx`).
- **Rules**: Strictly private. Stored outside the repository and **NEVER** committed to Git.

### E. Automated Test Fixtures (`tests/`, `mobile/test/`)
- Synthetic test data (e.g., `Alice Smith`, `Bob Jones`, `John Doe`, `23CS001`) used in automated test suites.
- **Rules**: Must remain isolated to unit/widget test files and never mixed into production seeds.

---

## 2. Privacy & Biometric Data Handling

1. **Student Photographs**:
   - High-resolution student photographs are biometric source assets.
   - May only be stored within authorized private repository storage under `college_data/official_photos/`.
   - Never expose student photographs via public web endpoints, public static asset directories (`app/static/`), or public README embeds.
2. **Face Embeddings**:
   - Biometric face recognition vectors (128-dimensional floating-point embeddings) are generated dynamically from verified photographs and stored in the `face_embeddings` database table.
   - **Zero Fabrication**: Do not invent fake biometric vectors. Students without photos remain un-enrolled until verified photos are supplied.

---

## 3. Data Integrity & Anti-Fabrication Rules

1. **No Invented Register Numbers**:
   - Real college roll lists contain official gaps due to discontinued admissions, transfers, or lateral entries (e.g. Class 2 gaps at `721024149003`, `721024149009`, `721024149028`, `721024149048`).
   - Developers must **NEVER** invent dummy student accounts to fill numerical gaps.
2. **Capacity Enforcement**:
   - System capacity is constrained: Maximum **130 students** and **15 faculty**.
   - Current state: 64 Class 1 students + 55 Class 2 students = 119 students (11 remaining).
   - Capacity validation is enforced by `ProductionCollegeDataValidator` in `app/services/college_importer.py`.

---

## 4. Class 2 Onboarding Standard Operating Procedure

When onboarding Class 2 (`III Year CSE Cyber Security - Class 2`):
1. Run data validator: `python scripts/validate_class2_student_roster.py`.
2. Ensure 55 records match the official roster scans in `college_data/official_name_lists/`.
3. Import into database using `college_importer.py`.
4. Generate private credential register `CLASS2_STUDENT_CREDENTIALS.docx` **outside** Git.
5. Verify student login and personal timetable access.
6. Verify biometric enrollment once real photographs are matched.
