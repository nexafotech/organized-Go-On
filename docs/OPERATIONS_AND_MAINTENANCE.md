# Operations, Maintenance & Runbook Guide — go-On

## 1. Overview

This document provides system administrators, DevOps engineers, and support personnel with operational instructions for running, monitoring, backing up, and troubleshooting the **go-On** attendance system.

---

## 2. Routine Operations & Service Management

### 2.1 Starting Services

#### Local Development
```powershell
# 1. Activate Python virtual environment and run FastAPI
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# 2. In a separate terminal, serve web client
python scripts/serve_web.py

# 3. Serve mobile APK distribution portal
python scripts/serve_apk.py
```

#### Zoho Catalyst AppSail
- Service lifecycle is automatically managed by the Zoho Catalyst runtime.
- Entrypoint: `python scripts/run_catalyst.py`
- Catalyst listens on `$X_ZOHO_CATALYST_LISTEN_PORT` and exposes TLS-terminated endpoints.

### 2.2 Health Verification & Probes
- **Liveness Probe**: `GET /api/v1/health`
  - Expected Response: `{"status": "ok", "app": "go-on", "version": "1.0.0"}`
- **Database Connectivity**: `GET /api/v1/health/db`
  - Returns `200 OK` when the active database pool responds within < 50ms.

---

## 3. Database Administration & Backup Procedures

### 3.1 SQLite Automated Backups
To create an atomic, non-locking backup of the SQLite database:
```powershell
# Run the backup script
python scripts/backup_database.py
```
This script executes SQLite's VACUUM INTO command, producing a timestamped snapshot in `backups/` without disrupting concurrent readers or writers.

### 3.2 Backup Retention Policy
- Daily snapshots retained for 14 days.
- Weekly snapshots retained for 8 weeks.
- Monthly snapshots archived into cold storage for 1 calendar year.

### 3.3 Database Migrations (Alembic)
When applying schema alterations:
```powershell
# 1. Check current migration revision
alembic current

# 2. Generate migration script after model changes
alembic revision --autogenerate -m "describe_migration"

# 3. Apply pending migrations
alembic upgrade head
```

---

## 4. Background Scheduler & Notification Monitoring

### 4.1 Asia/Kolkata Notification Scheduler
The background scheduler (`app/core/scheduler.py`) evaluates timetable slots every 60 seconds:
- Sends class start reminders to students and faculty 10 minutes prior to lecture start.
- Verifies attendance completion and dispatches automated absentee alerts.

### 4.2 Troubleshooting Stalled Notifications
If users report missing push notifications:
1. Verify Firebase service account credentials validity:
   ```powershell
   python -c "from app.core.config import settings; print(bool(settings.FIREBASE_CREDENTIALS_PATH))"
   ```
2. Inspect the notification audit log:
   ```sql
   SELECT id, user_id, title, status, created_at FROM notification_logs ORDER BY created_at DESC LIMIT 20;
   ```
3. Check system time synchronization (NTP). The scheduler relies on Asia/Kolkata timezone matching.

---

## 5. Capacity & Performance Scaling

### 5.1 Benchmarked Scale Limits
- **Student Capacity**: 5,000 active students per institutional instance.
- **Faculty Capacity**: 250 concurrent faculty members.
- **Classroom Throughput**: Up to 60 students recognized and marked per minute using SCRFD-10G and ArcFace ResNet-50.

### 5.2 Migrating from SQLite to Managed PostgreSQL
When active concurrent users exceed 500, migrate the database engine:
1. Provision a PostgreSQL instance (AWS RDS, Supabase, or Zoho Catalyst Data Store).
2. Set `DATABASE_URL=postgresql+psycopg://user:password@host:5432/dbname` in `.env`.
3. Run `alembic upgrade head` to build schema on PostgreSQL.
4. Export data using `scripts/migrate_sqlite_to_postgres.py`.

---

## 6. Emergency Disaster Recovery

### 6.1 Restoring Database from Backup
```powershell
# 1. Stop the application server
# 2. Copy the verified snapshot to primary location
Copy-Item "E:\backups\go-on-backup-20261018-phase1\attendance_system.db" -Destination "E:\originalam\attendance_system.db" -Force

# 3. Verify SQLite integrity
sqlite3 attendance_system.db "PRAGMA integrity_check;"

# 4. Restart FastAPI service
```
