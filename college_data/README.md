# College Source Resources (`college_data/`)

> [!CAUTION]
> **CONFIDENTIALITY & ACCESS RESTRICTION NOTICE**:
> This directory contains authentic college/student source material, official master timetables, and student roster documents.
> Access is strictly restricted to authorized project contributors.
> **DO NOT** redistribute, publish, or move these materials to a public repository.
> **DO NOT** expose student photographs through public documentation, static asset directories, or web portals.

---

## 1. Directory Structure

```text
college_data/
├── README.md                     # Confidentiality notice & data overview
├── INDEX.md                      # Resource catalog & lifecycle tracking
├── source_manifest.txt           # SHA-256 integrity checksums for all source files
├── official_timetable/           # Original timetable scans & faculty schedules
│   ├── README.md
│   └── [Source Timetable Images]
├── official_name_lists/          # Original official student roster scans
│   ├── README.md
│   └── [Source Roster Scans]
└── official_photos/              # Student/campus photographs for biometric enrollment
    ├── README.md
    └── [Source Photographs]
```

---

## 2. Distinction Between Source Data & Development Seeds

- **`college_data/` (This Directory)**:
  - Raw, unedited, authentic reference material received from official college sources (scans, photographs, sheets).
  - Used for manual verification, OCR transcription, and historical audit.
  - Serves as the primary source of truth for all academic schedules and rosters.
- **`college_seed/`**:
  - Structured, validated JSON files consumed by the backend importer (`app/services/college_importer.py`).
  - Generated and validated strictly from the source documents in `college_data/`.
- **Runtime Database (`attendance_system.db`)**:
  - Local runtime SQLite database generated dynamically from `college_seed/`.
  - **Never committed to Git**.
