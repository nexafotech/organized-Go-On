# Changelog & Version History — go-On

All notable changes to the **go-On** AI Face Attendance System are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0-catalyst.1] - 2026-10-18

### Added
- **Zoho Catalyst AppSail Manifests**: Created `catalyst.json` and `app-config.json` configuring Python 3.11 with 2048 MB memory ceiling for computer vision inference.
- **Dynamic Port Dispatcher**: Implemented `scripts/run_catalyst.py` to seamlessly bind `$X_ZOHO_CATALYST_LISTEN_PORT` and `$PORT` for Catalyst serverless deployment.
- **Institutional Documentation Suite**: Added `PROJECT_DISCOVERY.md`, `STEP_BY_STEP_SETUP_AND_DEPLOYMENT.md`, `TEST_RESULTS.md`, `DEPLOYMENT_RUNBOOK.md`, `PROJECT_STRUCTURE.md`, `SECURITY_AND_DATA_HANDLING.md`, and `OPERATIONS_AND_MAINTENANCE.md`.
- **High-Capacity Scale Verification**: Added `test_capacity_scale_5000.py` verifying system stability under 5,000 students and 250 faculty scale.
- **Sanitized Environment Configuration**: Added `.env.example` template with secure defaults and zero credential leakage.

### Changed
- **Adaptive Splash Implementation**: Fully resolved the unwanted dark startup loading screen. Replaced with theme-aware adaptive splash screen respecting user theme preference and native transitions.
- **Git Security Rules**: Hardened `.gitignore` to prevent any inadvertent staging of `.env`, `.pem`, `.key`, `.bundle`, and Catalyst project metadata files.

### Verified
- **Backend Quality**: 38/38 pytests passing with 100% pass rate.
- **Flutter Analysis**: Clean static analysis with 0 errors, 0 warnings across all mobile code.
- **Flutter Widget Tests**: 203/203 unit and widget tests passing on Flutter 3.47.7.
- **Physical Device**: Verified on Samsung Galaxy S24 (`SM-S921E`).

---

## [0.9.8-adaptive-splash] - 2026-10-16

### Added
- High-resolution adaptive splash screen assets featuring gold Go-On branding and "from NEXAFO" attribution.
- Synchronous theme bootstrapping from `SharedPreferences` to eliminate startup theme flashing.

### Fixed
- Addressed dark screen flicker on light mode cold boot.
- Synchronized initial route redirection with authentication session validity.

---

## [0.9.5-onnx-engine] - 2026-09-25

### Added
- DeepInsight SCRFD-10G face detection engine (`det_10g.onnx`).
- ArcFace ResNet-50 512D feature extraction engine (`w600k_r50.onnx`).
- Pluggable `BaseRecognitionEngine` architecture separating computer vision models from core attendance logic.

---

## [0.8.0-milestone-10c] - 2026-08-19

### Added
- Multi-faculty authorized access model for timetable slots.
- Cross-platform attendance export APIs (CSV/Excel).
- In-app notification center and Firebase Cloud Messaging integration.
