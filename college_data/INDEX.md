# College Data Resource Index (`college_data/INDEX.md`)

This index catalog tracks all official college source resources, development datasets, credential stores, and databases across the Attendance Marker project.

| Resource Type | Storage Location | Purpose | Current Lifecycle Status |
| :--- | :--- | :--- | :--- |
| **Official Timetable** | `college_data/official_timetable/` | Reference timetable scans & master schedule photos | **Archived & Transcribed** into `college_seed/timetable_class1.json` and `timetable_class2.json` |
| **Official Name Lists** | `college_data/official_name_lists/` | Official student roster photographs & roll sheets | **Archived & Transcribed** (Class 1: 64 students onboarded; Class 2: 55 students prepared) |
| **Official Photos** | `college_data/official_photos/` | Source photographs for student facial verification | **Archived**; awaiting Class 2 biometric alignment & enrollment (Milestone 10C.13) |
| **Development Seed Data** | `college_seed/` | Structured JSON seed files for automated database initialization | **Active & Synchronized** with backend importer |
| **Student Credentials** | **OUTSIDE GIT** (`CLASS1_STUDENT_CREDENTIALS.docx`, etc.) | Confidential plaintext login credentials for distribution | **Restricted & Private** (Never committed to version control) |
| **Runtime Database** | **LOCAL ONLY** (`attendance_system.db`) | SQLite development database instance | **Local Development Only** (Auto-initialized on backend start, excluded from Git) |
