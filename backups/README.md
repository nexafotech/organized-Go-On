# Database Backups Directory (`backups/`)

This directory stores point-in-time snapshot backups of SQLite databases before running migrations, cleanups, or schema upgrades.

> [!NOTE]
> Database binaries (`*.db`, `*.sqlite`) are excluded from Git version control via `.gitignore`.

---

## Restoring Backups

To restore a previously backed up SQLite database:
```powershell
Copy-Item backups\attendance_system_pre_cleanup_20261020.db attendance_system.db
```

To create a new backup:
```powershell
python scripts/audit_database.py
```
