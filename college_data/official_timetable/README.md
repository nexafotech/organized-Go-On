# Official Timetable Scans & Master Schedules (`college_data/official_timetable/`)

## 1. Overview
This folder contains the original, authentic photographs and scan captures of the official college master timetable schedules.

- **Original Source Folder**: `C:\Users\Abishek\OneDrive\Desktop\am-ttnl`
- **Copy Date**: 2026-08-20
- **Integrity**: Exact byte-for-byte replica with SHA-256 integrity verification recorded in `college_data/source_manifest.txt`.

---

## 2. File Manifest & Seed Mapping

| Copied Filename | File Size | Description & Class Scope | Seed Conversion Status |
| :--- | :--- | :--- | :--- |
| `WhatsApp Image 2026-08-18 at 3.42.38 PM (1).jpeg` | 160,048 B | **Class 1 Master Timetable**: Official weekly grid (Periods 1–7, Mon–Sat) for `II Year CSE Cyber Security - Class 1`. | **Fully Transcribed** into `college_seed/timetable_class1.json` (42 slots). |
| `WhatsApp Image 2026-08-18 at 9.39.52 PM.jpeg` | 95,337 B | **Class 2 Master Timetable**: Official weekly grid (Periods 1–7, Mon–Sat) for `III Year CSE Cyber Security - Class 2`. | **Fully Transcribed** into `college_seed/timetable_class2.json` (42 slots). |
| `WhatsApp Image 2026-08-18 at 9.56.17 PM.jpeg` | 147,884 B | **Class 1 Subject & Faculty Schedule**: Subject codes, full names, and assigned faculty breakdown. | **Fully Integrated** into `college_seed/subjects.json` and `college_seed/faculty_assignments.json`. |
| `WhatsApp Image 2026-08-20 at 8.35.50 PM.jpeg` | 182,094 B | **Master Timetable Notes & Faculty Allocation**: Allocation details and multi-faculty assignment notes. | **Fully Integrated** into `app/services/college_importer.py` multi-faculty specification. |
