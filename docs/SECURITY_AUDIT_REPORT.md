# Security Audit & Vulnerability Remediation Report — go-On

## 1. Executive Summary

This security audit report provides an exhaustive assessment of the **go-On** attendance system. All critical security domains—including authentication, authorization, session persistence, credential management, biometric data isolation, and network communication—have been systematically audited and remediated.

---

## 2. Security Findings & Remediations Matrix

| ID | Category | Severity | Description | Status | Remediation Details |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **SEC-01** | Information Disclosure | **CRITICAL** | Diagnostic server fallback was spoofing HTTP 200 and returning stack tracebacks. | **RESOLVED** | Removed diagnostic fallback server completely from `main.py` and `scripts/run_catalyst.py`. Startup failures now cleanly exit with non-zero code (`sys.exit(1)`). |
| **SEC-02** | Credential Exposure | **CRITICAL** | Risk of deploying credentials spreadsheets or local databases to cloud runtime. | **RESOLVED** | Hardened `.catalystignore` with explicit exclusions for `*.xlsx`, `*.db`, `*.sqlite`, `.env`, and private service accounts. |
| **SEC-03** | Biometric Privacy | **HIGH** | Raw face photographs potentially lingering in filesystem or memory. | **RESOLVED** | Enforced in-memory buffer processing; raw images are destroyed immediately following vector feature extraction. |
| **SEC-04** | Authentication | **HIGH** | Bcrypt password truncation and DoS resistance. | **RESOLVED** | Standardized password hashing using passlib bcrypt with strict 72-byte truncation boundary checks. |
| **SEC-05** | Authorization (RBAC) | **HIGH** | Potential privilege escalation across Admin, Faculty, and Student roles. | **RESOLVED** | Enforced FastAPI server-side role dependencies (`require_admin`, `require_faculty`) on all sensitive routes. |
| **SEC-06** | Session Security | **MEDIUM** | Token tampering and cookie hijacking risks. | **RESOLVED** | Signed JWTs using `HS256` with configurable expiration; browser cookies set with `HttpOnly`, `Secure`, and `SameSite=Strict`. |
| **SEC-07** | Network & CORS | **MEDIUM** | Overly permissive cross-origin requests. | **RESOLVED** | CORS middleware restricted to configured origins in `settings.CORS_ALLOWED_ORIGINS`; wildcards blocked in production. |

---

## 3. Cryptographic Standards & Key Management

### 3.1 Password Storage
- **Algorithm**: `bcrypt` (Blowfish-based cipher) with dynamic salt stretching.
- **Salt Generation**: Cryptographically secure pseudo-random number generator (CSPRNG) via OS entropy pool.
- **Hash Verification**: Constant-time comparison to protect against timing attacks.

### 3.2 Token Issuance & Verification
- **Token Format**: RFC 7519 JSON Web Token (JWT).
- **Signing Algorithm**: HMAC using SHA-256 (`HS256`).
- **Signature Secret**: Sourced exclusively from `SECRET_KEY` environment variable. Never hardcoded into source control.
- **Payload Constraints**: Contains subject (`sub`), role claims, and epoch expiration (`exp`). Plaintext passwords and sensitive personal information are strictly omitted from token payloads.

---

## 4. Biometric Data Protection & Compliance

### 4.1 Embedding Generation
- Uses InsightFace ArcFace ResNet-50 (`w600k_r50.onnx`) producing a 512-dimensional vector:
  $$\mathbf{v} \in \mathbb{R}^{512}, \quad \|\mathbf{v}\|_2 = 1.0$$
- Vector mappings are mathematically one-way: reconstructing the original photographic portrait from a 512D unit vector is computationally infeasible.

### 4.2 Storage Separation
- Biometric vectors are isolated in the `face_embeddings` table and linked exclusively via foreign key `student_id`.
- No name, email, phone number, or credential is stored directly in the `face_embeddings` table.

---

## 5. Audit Logging & Compliance Trails

- All security-sensitive actions—including account creation, password resets, biometric enrollments, and privilege elevation—are recorded in `audit_logs`:
  - `action`: Specific operation performed.
  - `user_id`: Target entity ID.
  - `admin_id`: Acting administrator ID.
  - `timestamp`: UTC timestamp with ISO 8601 formatting.
  - `ip_address`: Request client IP.
