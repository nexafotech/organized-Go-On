# Security Architecture & Data Handling Policy — go-On

## 1. Security Overview

**go-On** handles sensitive institutional and biometric data, including student identification records, facial embeddings, user credentials, and academic attendance logs. The system is engineered to comply with modern data privacy and defense-in-depth principles.

---

## 2. Authentication & Authorization

### 2.1 Password Hashing & Storage
- Passwords are never stored in plaintext.
- All credentials are encrypted using **Bcrypt** with salt stretching (`passlib.context.CryptContext(schemes=["bcrypt"], deprecated="auto")`).
- Passwords are truncated at 72 bytes internally as required by the native bcrypt specification to prevent denial-of-service via oversized hash payloads.

### 2.2 Token Management
- **Stateless Access Tokens**: Encoded using **HMAC-SHA256 (`HS256`)**.
- Tokens contain:
  - `sub`: Unique user identifier (integer/UUID).
  - `role`: Role claim (`admin`, `faculty`, `student`).
  - `exp`: Expiration timestamp (default: 60 minutes for active sessions).
- Secret keys are loaded dynamically from environment variables (`SECRET_KEY`) and never committed into source control.

### 2.3 Session Isolation & Role-Based Access Control (RBAC)
- All endpoints strictly enforce role authorization via FastAPI dependencies (`get_current_active_user`, `require_role(["admin"])`, `require_role(["faculty"])`).
- Cross-tenant data leakage is prevented: students can only access their own attendance logs and profiles; faculty can only view schedules and attendance for courses assigned to them.

---

## 3. Biometric & Facial Data Protection

### 3.1 Raw Image Handling
- **Zero Raw Image Retention**: Images submitted during facial verification are processed entirely in memory.
- Once face detection (SCRFD) and feature extraction (ArcFace) complete, raw image buffers are immediately discarded and freed from memory.
- Facial photos are never saved to disk or transmitted to external third-party cloud services.

### 3.2 Feature Vector (Embedding) Storage
- Biometric identity is represented as an anonymous **512-dimensional floating-point vector**.
- Vector representations are one-way: mathematically, a person's original facial image cannot be reconstructed from an ArcFace embedding vector.
- Vector records in the database link solely to an internal `student_id` without external personal identifiers.

### 3.3 Anti-Spoofing & Model Security
- DeepInsight SCRFD-10G applies multi-scale anchor boxes to reject low-resolution or heavily distorted face inputs.
- Cosine similarity thresholding enforces a strict match requirement ($0.60$ or higher) to minimize false acceptance rates (FAR < 0.001%).

---

## 4. Network & Transport Layer Security

### 4.1 HTTPS & TLS
- In development/local testing, plaintext HTTP is permitted on local loopback (`127.0.0.1`).
- In production (Zoho Catalyst AppSail / Cloud), all incoming traffic is terminated with **TLS 1.3 / HTTPS**.
- Cookies are transmitted with `Secure`, `HttpOnly`, and `SameSite=Strict` attributes to protect against Cross-Site Scripting (XSS) and Cross-Site Request Forgery (CSRF).

### 4.2 Cross-Origin Resource Sharing (CORS)
- CORS middleware is locked down to authorized domains specified in `CORS_ORIGINS`.
- Wildcard `*` origins are strictly prohibited in production configurations.

---

## 5. Credential & Environment Variable Hygiene

1. **`.env` Exclusion**: `.gitignore` strictly rejects `.env`, `.env.*`, `firebase-credentials.json`, and service account keys.
2. **Safe Template Distribution**: A sanitized `.env.example` file is provided with empty placeholders for developers.
3. **Automated Audit**: Continuous verification confirms that no database snapshots containing real PII or live cryptographic private keys are pushed to remote Git repositories.

---

## 6. Incident Response & Vulnerability Reporting

If a vulnerability or credential exposure is detected:
1. **Rotate Keys**: Immediately invalidate all issued JWT tokens by changing `SECRET_KEY`.
2. **Revoke Database Access**: Invalidate existing database credentials and rotate service credentials.
3. **Database Audit**: Inspect `notification_logs` and `attendance_logs` for abnormal access patterns.
4. **Patch & Deploy**: Follow the rollback or expedited patch workflow in [DEPLOYMENT_RUNBOOK.md](DEPLOYMENT_RUNBOOK.md).
