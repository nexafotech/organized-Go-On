# ZOHO CATALYST DEPLOYMENT RUNBOOK — GO-ON

This runbook establishes standard operating procedures for deploying, maintaining, monitoring, and rolling back the **go-On** application on **Zoho Catalyst (AppSail)**.

---

## 1. Pre-Deployment Verification Checklist

Before initiating any deployment:
- [ ] Confirm local database backup exists in `E:\backups\`.
- [ ] Confirm Git working tree is clean (`git status`).
- [ ] Ensure all 38 backend pytests and 203 Flutter tests pass.
- [ ] Confirm `catalyst.json` and `app-config.json` exist.
- [ ] Verify that no secrets, `.env` files, or `.db` files are included in git tracking.
- [ ] Obtain explicit approval before promoting from Development to Production.

---

## 2. Environment Architecture Overview

The system uses a two-tier deployment structure:

| Tier | Catalyst Environment | Intended Usage | Approval Required? |
| :--- | :--- | :--- | :--- |
| **Tier 1** | **Development / Staging** | Integration testing, API validation, Flutter dev testing | Automatic / Developer |
| **Tier 2** | **Production** | Live faculty, student attendance, college deployment | **Explicit Approval Required** |

---

## 3. Staging Deployment Procedure (Step-by-Step)

### Step 1: Catalyst Authentication
```powershell
# Open interactive login in browser
catalyst login

# If your account is in India data center:
catalyst login --dc in
```

### Step 2: Select Project & Environment
```powershell
# List existing projects
catalyst project:list

# Select your student/target project
catalyst project:use <PROJECT_NAME_OR_ID>
```

### Step 3: Deploy AppSail Backend
```powershell
# Deploy exclusively to Development environment
catalyst deploy --only appsail
```

### Step 4: Verify Live Service Health
Once the deployment finishes, the CLI will display the live URL (e.g. `https://go-on-backend-dev.catalystappsail.in/`):
```powershell
# Query health check endpoint
curl -i https://<DEPLOYED_URL>/health

# Query Swagger API Docs
curl -i https://<DEPLOYED_URL>/docs
```
Expected HTTP status: `200 OK`.

---

## 4. Production Promotion Procedure

Promotion to production must only occur after staging has been validated for at least 24 hours without critical errors.

1. **Request Approval**: Present staging test results, database migration plan, and rollback checklist to the project owner.
2. **Configure Production Database**:
   - Ensure an external, managed PostgreSQL database is provisioned.
   - Configure the production connection string in the Catalyst Console:
     `DATABASE_URL=postgresql://user:password@host:5432/go_on_prod`
3. **Execute Production Deployment**:
   In the Zoho Catalyst Web Console, navigate to **AppSail > Deployments**, click **Promote to Production**, and verify build health.

---

## 5. Post-Deployment Smoke Tests

Execute the following smoke tests on the live endpoint:
1. `GET /health` -> Returns `{"status":"ok", "version":"2.0.0"}`
2. `POST /api/v1/auth/login` -> Authenticates faculty test user `fac04`
3. `POST /api/v1/auth/student/login` -> Authenticates student test user `721025149002`
4. `GET /api/v1/student/timetable` -> Returns 7-period schedule
5. `GET /api/v1/student/attendance` -> Returns student attendance metrics

---

## 6. Incident Response & Rollback Procedures

### Scenario A: AppSail Startup Crash or Dependency Failure
1. Inspect live container logs:
   Navigate to **Zoho Catalyst Console > AppSail > Logs > Application Logs**.
2. If the build or runtime failed, revert to the last stable deployment in the Catalyst Console:
   **AppSail > Deployments > Previous Version > Rollback**.
3. Re-verify the `/health` endpoint.

### Scenario B: Database Schema Conflict or Corruption
1. Stop incoming write traffic by setting the AppSail service to Maintenance Mode.
2. Restore database state from the most recent backup in `E:\backups\`:
   ```powershell
   Copy-Item "E:\backups\go-on-backup-20261018-phase1\attendance_system.db" "E:\originalam\attendance_system.db"
   ```
3. Run Alembic verification:
   ```powershell
   alembic current
   ```

### Scenario C: FCM Notification Storm or Loop
1. To immediately halt scheduled automated notifications, set the environment variable:
   `DISABLE_NOTIFICATION_SCHEDULER=true`
2. Restart the AppSail service.
