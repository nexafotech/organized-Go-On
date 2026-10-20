# STEP-BY-STEP SETUP AND DEPLOYMENT GUIDE — GO-ON

This guide provides end-to-end instructions for running, testing, building, and deploying the **go-On — AI Face Attendance System** on a local Windows development machine and to **Zoho Catalyst (AppSail)**.

---

## 1. Prerequisites and Required Tools

Verify that the following tools are installed on your Windows development environment:

| Tool | Recommended Version | Verification Command |
| :--- | :--- | :--- |
| **Python** | 3.10+ (Current: `3.14.5`) | `python --version` |
| **Flutter SDK** | 3.24+ (Current: `3.47.7`) | `flutter --version` |
| **Node.js** | 18+ (Current: `v24.16.0`) | `node --version` |
| **npm** | 9+ (Current: `11.13.0`) | `npm --version` |
| **Git** | 2.40+ (Current: `2.54.0`) | `git --version` |
| **Java JDK** | OpenJDK 17 LTS | `java -version` |
| **Android SDK / ADB** | API 34+ / Platform-Tools 37 | `adb version` |
| **Zoho Catalyst CLI** | 1.28.0+ | `catalyst --version` |

---

## 2. Locating and Opening the Project

1. Open PowerShell on Windows.
2. Navigate to the project root:
   ```powershell
   cd E:\originalam
   ```
3. Confirm repository integrity:
   ```powershell
   git status
   ```

---

## 3. Tool Installation (If Missing)

- **Node.js & npm**: Download the LTS installer from [nodejs.org](https://nodejs.org/).
- **Flutter SDK**: Extract to a directory (e.g. `C:\src\flutter`) and add `bin` to your system `PATH`.
- **Zoho Catalyst CLI**:
  ```powershell
  npm install -g zcatalyst-cli
  ```
  Verify with:
  ```powershell
  catalyst --version
  ```

---

## 4. Configuring Python & Backend Dependencies

1. From the project root (`E:\originalam`), install required packages:
   ```powershell
   pip install -r requirements.txt
   ```
2. Verify ONNX Runtime and OpenCV:
   ```powershell
   python -c "import onnxruntime, cv2; print('ONNX:', onnxruntime.__version__, '| OpenCV:', cv2.__version__)"
   ```

---

## 5. Environment Variables Configuration

1. Copy the safe `.env.example` template to `.env`:
   ```powershell
   Copy-Item .env.example .env
   ```
2. Generate a secure secret key:
   ```powershell
   python -c "import secrets; print(secrets.token_hex(32))"
   ```
3. Update `.env` with the generated `SECRET_KEY`. **Never commit `.env` to Git.**

---

## 6. Initializing and Migrating the Database

1. The project uses SQLite by default (`attendance_system.db`).
2. Run database migrations via Alembic:
   ```powershell
   alembic upgrade head
   ```
3. Verify database tables:
   ```powershell
   python scripts/_audit_db.py
   ```

---

## 7. Running the Full Stack Locally

Execute the pre-configured Windows launcher:
```powershell
.\run_all.bat
```
This starts:
- **FastAPI Backend**: `http://localhost:8000` (Docs: `http://localhost:8000/docs`)
- **Flutter Web Gateway**: `http://localhost:3000`
- Opens the browser automatically to `http://localhost:3000`.

---

## 8. Authenticating with Zoho Catalyst

To deploy to Zoho Catalyst, log in via your Zoho account:

1. In PowerShell, run the official login command:
   ```powershell
   catalyst login
   ```
   *Note: If your account is registered in the India data center, specify `--dc in`:*
   ```powershell
   catalyst login --dc in
   ```
2. A browser window will open prompting you to authorize the Catalyst CLI.
3. Once authorized, verify your login status:
   ```powershell
   catalyst whoami
   ```
4. List your existing Catalyst projects:
   ```powershell
   catalyst project:list
   ```
5. Bind your local directory to your existing student/target project:
   ```powershell
   catalyst project:use <PROJECT_ID_OR_NAME>
   ```

---

## 9. Deploying the Backend to Zoho Catalyst (AppSail)

The project includes pre-configured deployment manifests:
- `catalyst.json`: Project and resource definitions.
- `app-config.json`: AppSail runtime, memory, and startup command configuration.
- `scripts/run_catalyst.py`: Platform-independent startup entry point that dynamically reads `$X_ZOHO_CATALYST_LISTEN_PORT`.

### Deployment Steps:
1. Deploy specifically to the **Development** environment:
   ```powershell
   catalyst deploy --only appsail
   ```
2. The CLI will bundle the application and output the live development URL:
   `https://<appsail-subdomain>.catalystappsail.in/`
3. Verify the live health endpoint:
   ```powershell
   curl https://<YOUR_DEPLOYED_URL>/health
   ```
   Expected response:
   ```json
   {"status":"ok","project":"Go-On Attendance System","version":"2.0.0"}
   ```

---

## 10. Database Persistence & Model Storage on Cloud

1. **Ephemeral Storage Warning**: AppSail instances have an ephemeral local disk. Any changes written to a local `attendance_system.db` file will be lost if the container is recycled or redeployed.
2. **Production Strategy**:
   - Provision a managed PostgreSQL instance (e.g. AWS RDS, Supabase, Neon, or Zoho Catalyst Data Store).
   - Set the `DATABASE_URL` environment variable in the Catalyst AppSail Console:
     `DATABASE_URL=postgresql://user:password@host:5432/dbname`
   - Run `alembic upgrade head` to establish the schema on the managed database.

---

## 11. Connecting the Flutter Mobile Application

1. Open `mobile/lib/core/config/api_config.dart`.
2. Update the default or staging URL to point to your deployed Catalyst URL:
   ```dart
   static String get defaultUrl {
     return 'https://<YOUR_CATALYST_URL>';
   }
   ```
3. Alternatively, launch the app and configure the backend URL dynamically in the app's Developer/Server Settings screen.

---

## 12. Building and Installing the Android APK

1. Navigate to the mobile directory:
   ```powershell
   cd E:\originalam\mobile
   ```
2. Run analyzer and tests:
   ```powershell
   flutter analyze lib/
   flutter test
   ```
3. Build the release APK:
   ```powershell
   flutter build apk --release
   ```
   The APK will be generated at:
   `mobile/build/app/outputs/flutter-apk/app-release.apk`
4. Connect your Android test phone (Samsung Galaxy S24) via USB and install:
   ```powershell
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

---

## 13. Routine Backup & Rollback

- **Database Backup**:
  ```powershell
  Copy-Item attendance_system.db "E:\backups\attendance_system_$(Get-Date -Format 'yyyyMMdd_HHmmss').db"
  ```
- **Rollback Catalyst Deployment**:
  In the Zoho Catalyst Web Console, navigate to **AppSail > Deployments**, select the previous working build version, and click **Rollback**.
