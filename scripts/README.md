# Production College Data Validator

This directory contains standalone, read-only validation utilities for verifying the college seed and production data package prior to database ingestion.

---

## `validate_production_college_data.py`

A non-destructive, read-only Python utility that checks schema conformance, relational foreign-key integrity, timetable slot distribution, and security policies across all JSON data files in `college_seed/`.

### Execution
Run directly from the repository root:

```bash
python scripts/validate_production_college_data.py
```

### Optional Arguments
- `--dir <PATH>`: Custom directory path to validate (defaults to `college_seed`).
- `--json`: Output findings in JSON format for automated CI/CD pipeline integration.

### Exit Codes
- **`0` (PASS)**: All datasets are 100% verified with zero warnings, errors, or placeholder tokens. The dataset is production-ready.
- **`1` (WARN / PENDING)**: Schema and relational integrity are structurally sound, but template placeholder tokens or pending optional files (such as `timetable_class2.json`) were detected.
- **`2` (FAIL)**: Blocking production errors detected (e.g. duplicate primary keys, invalid subject codes, period overlaps, plaintext production passwords, or broken foreign key references).

---

## Validation Checks Performed

1. **Class Sections**: Required fields, non-empty names, uniqueness.
2. **Period Timings**: Sequence, non-overlapping intervals, valid 24-hour `HH:MM` syntax.
3. **Subjects**: Unique curriculum codes, required titles.
4. **Faculty**: Unique usernames, emails, employee IDs, placeholder detection, security checks.
5. **Students**: Unique roll numbers, emails, class section existence, placeholder detection.
6. **Faculty Assignments**: Class section existence, subject code validity, faculty username existence, duplicate assignment prevention.
7. **Timetable Grid**: Weekday validity, period existence, duplicate slot collision prevention, relational link to faculty assignments, Class 2 availability check.
8. **Security & Zero-Credential Enforcement**: Scan for plaintext passwords, tokens, or demo fixtures in production datasets.
