# Rollback, Disaster Recovery & Incident Response Runbook — go-On

## 1. Overview & Rollback Triggers

This runbook defines deterministic, step-by-step procedures to revert code, configuration, database schemas, and cloud deployment states in the event of an operational failure, regression, or data anomaly.

### Rollback Decision Triggers
- **Fatal Cloud Startup**: AppSail container fails to bind port or health check returns HTTP 503 for > 3 consecutive minutes.
- **Database Schema Inconsistency**: Unrecoverable migration error or database corruption.
- **Authentication Blackout**: Users or administrators cannot log in due to JWT/Bcrypt token verification failure.
- **Data Loss / Accidental Mutation**: Erroneous deletion or corruption of student records or attendance logs.

---

## 2. Zoho Catalyst AppSail Cloud Rollback

### 2.1 Reverting via Catalyst Console
1. Navigate to the **Zoho Catalyst Console**:  
   `https://catalyst.zoho.com/`
2. Select the **GO-ON** project (ID: `80167000000013053`) and open **AppSail**.
3. Select service **`go-on-backend`**.
4. Open the **Deployments / Versions** tab.
5. Identify the last known stable deployment version timestamp.
6. Click **Revert / Rollback to This Version** and confirm.
7. Verify health status on `https://go-on-backend-50046794941.development.catalystappsail.in/health`.

### 2.2 Expedited CLI Re-Deployment
If redeploying from a verified local commit:
```powershell
# 1. Checkout the known stable commit
git checkout <stable_commit_hash>

# 2. Deploy to Development environment
catalyst deploy --only appsail

# 3. Verify health probes
curl.exe -i https://go-on-backend-50046794941.development.catalystappsail.in/health
```

---

## 3. Database Restoration & Recovery

### 3.1 Restoring Local SQLite Database from Verified Backup
Isolated backups are preserved at `E:\backups\go-on-backup-20261018-phase1\`.

```powershell
# Step 1: Stop any active FastAPI or Uvicorn instances
Get-Process python | Where-Object { $_.CommandLine -like "*uvicorn*" } | Stop-Process -Force

# Step 2: Archive the damaged database
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
Move-Item "E:\originalam\attendance_system.db" -Destination "E:\originalam\attendance_system_corrupted_$timestamp.db"

# Step 3: Copy verified backup into repository root
Copy-Item "E:\backups\go-on-backup-20261018-phase1\attendance_system.db" -Destination "E:\originalam\attendance_system.db"

# Step 4: Verify SQLite database integrity
python -c "import sqlite3; conn = sqlite3.connect('attendance_system.db'); print('Integrity:', conn.execute('PRAGMA integrity_check;').fetchall()); conn.close()"

# Step 5: Verify Alembic revision alignment
python -m alembic current
```

### 3.2 Alembic Migration Rollback
If a newly applied Alembic migration causes schema regressions:
```powershell
# Downgrade by 1 revision
python -m alembic downgrade -1

# Or downgrade to specific stable target
python -m alembic downgrade dd70ea345d25
```

---

## 4. Git Repository Recovery

In the event of working tree disruption or uncommitted file corruption:
- A full Git bundle snapshot is preserved at:  
  `E:\backups\go-on-backup-20261018-phase1\repo_backup_20261018.bundle`
- This bundle contains the entire commit history, all branches, and tags.

To verify or inspect the bundle:
```powershell
git bundle verify "E:\backups\go-on-backup-20261018-phase1\repo_backup_20261018.bundle"
```

---

## 5. Mobile Application Client Rollback

If a newly installed APK exhibits startup regressions:
1. Uninstall the regressed APK from the test device (Samsung Galaxy S24):
   ```powershell
   adb -s RZCY935CVJF uninstall com.example.mobile
   ```
2. Reinstall the verified release APK:
   ```powershell
   adb -s RZCY935CVJF install -r "E:\originalam\mobile\build\app\outputs\flutter-apk\app-release.apk"
   ```
3. Launch and verify login screen appears immediately without theme flashing.
