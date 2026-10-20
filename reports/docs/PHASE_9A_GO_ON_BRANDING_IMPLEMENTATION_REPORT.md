# Phase 9A — Go-On Official Branding & Logo Implementation Report

**Product Name:** Go-On  
**Target Repository:** `C:\Users\Abishek\Desktop\am-oss`  
**Git Branch:** `ui-redesign-phase9-attendance-export`  
**Commit Hash:** `e366f59`  
**Execution Date:** 2026-10-07  

---

## 1. Executive Summary

Phase 9A establishes the authoritative visual brand identity **Go-On** across all surfaces of the Attendance Marker project without altering any underlying authentication, database, authorization, biometric, timetable, or attendance calculations.

Every logo asset across Android, Web, Flutter UI, PDF report, and Excel workbook was generated as a strict technical derivative of the single official logo image supplied by the product owner (`media_1791362581883.png`). The logo artwork was never redesigned, reshaped, recolored, or replaced with a generic icon. Its warm beige/gold appearance and geometric styling are 100% preserved.

---

## 2. Branding Changes Overview

| Surface | Previous Label / Asset | New Label / Asset | Notes |
|---|---|---|---|
| **App Name** | `AI Face Attendance` / `Attendance Marker` | `Go-On` | Exact capitalization preserved |
| **Splash Screen** | Material `face_retouching_natural_rounded` + generic title | Official `Go-On` logo + `Go-On` wordmark | Centered on Espresso GlassCard, respects reduced motion |
| **Login Screen** | Generic icon in hero card + duplicated AppBar title | Official `Go-On` logo + `Go-On` in Espresso hero card | Single clean brand presentation, server actions preserved |
| **Student Dashboard** | Plain text title | `Go-On` logo badge (30dp) on home tab AppBar | Clean hierarchy, other tabs show screen titles |
| **Faculty Dashboard** | Plain text title | `Go-On` logo badge (30dp) on home tab AppBar | Clean hierarchy, other tabs show screen titles |
| **Admin Face Screen**| Plain text column | `Go-On` logo (30dp) directly on Espresso AppBar | High contrast, authoritative institutional header |
| **Android App** | `android:label="AI Face Attendance"` | `android:label="Go-On"` | App ID and package ID preserved |
| **Android Launcher**| Generic default Flutter mipmaps | Adaptive icon (foreground + `#2B1A13` background) + legacy rounded mipmaps | Density variants `mdpi` to `xxxhdpi` |
| **Flutter Web Title**| `attendance_marker_mobile` | `Go-On` | Updated in `index.html` & `manifest.json` |
| **Web Icons & Favicon** | Default blue Flutter icons | `Go-On` adaptive icons & 64x64 favicon on Espresso base | Preserves CanvasKit and local build configs |
| **PDF Report** | Text header `ATTENDANCE REPORT` | Official `Go-On` badge (17mm) + `Go-On` header | Fixed aspect ratio, unbloated file size |
| **Excel Export** | Raw table header on row 1 | Dedicated `Go-On` brand block (rows 1-5) + embedded badge | Professional typography on Summary sheet |

---

## 3. Logo Asset Architecture

The official uploaded logo image was archived to:
`mobile/assets/branding/source/go_on_logo_original.png`

Using a deterministic alpha matte pipeline (`scripts/generate_go_on_brand_assets.py`), the off-white backdrop was separated while preserving anti-aliased edges and gradients.

### Derived Assets Created:
1. **In-App Transparent Logo (`mobile/assets/branding/go_on_logo.png`):**
   - 512x512 RGBA transparent PNG.
   - Preserves native beige/gold tones.
   - Used in `GoOnLogo` and `GoOnLockup` widgets.
2. **Android Adaptive Launcher Icons:**
   - Background: `mobile/android/app/src/main/res/values/ic_launcher_background.xml` (`#2B1A13`, Espresso token).
   - Adaptive foreground: `mobile/android/app/src/main/res/drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher_foreground.png` (within 66dp safe zone).
   - Legacy launcher mipmaps: `mobile/android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`.
   - Adaptive icon XML: `mobile/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`.
3. **Web Icons & PWA:**
   - `mobile/web/favicon.png` (64x64).
   - `mobile/web/icons/Icon-192.png` & `Icon-512.png`.
   - `mobile/web/icons/Icon-maskable-192.png` & `Icon-maskable-512.png`.
4. **Backend Export Badge (`app/assets/branding/go_on_badge.png`):**
   - 256x256 RGBA PNG (Espresso tile with centered logo).
   - Embedded in both PDF and Excel reports for visual identity consistency.

---

## 4. Flutter UI & Reusable Component System

Implemented [`mobile/lib/widgets/common/go_on_brand.dart`](file:///C:/Users/Abishek/Desktop/am-oss/mobile/lib/widgets/common/go_on_brand.dart) and exported through [`mobile/lib/widgets/widgets.dart`](file:///C:/Users/Abishek/Desktop/am-oss/mobile/lib/widgets/widgets.dart):

* **`GoOnBrand`:**
  - Constants for `name = 'Go-On'` and accessibility label `logoSemanticLabel = 'Go-On logo'`.
* **`GoOnLogo`:**
  - Clean `Image.asset` wrapper with `FilterQuality.high`, fixed square aspect ratio, and semantic accessibility labelling.
* **`GoOnLogoBadge`:**
  - Logo rendered on a small rounded Espresso (`#2B1A13`) container to ensure optimal contrast when rendered on light surfaces (e.g., Cream AppBars).
* **`GoOnLockup`:**
  - Vertical (`vertical`) and Horizontal (`horizontal`) alignments of the official logo paired with the `Go-On` typography.
  - Guarantees single-line rendering without unwanted word wraps.

---

## 5. Report Export Branding

### A. PDF Attendance Report (`app/services/attendance_report_pdf.py`)
- Standardized header utilizing `_brand_header()` Table:
  - Embeds `go_on_badge.png` constrained to a 17mm x 17mm square bounding box (strictly maintaining 1:1 aspect ratio).
  - Displays `Go-On` in 20pt bold Espresso, `ATTENDANCE REPORT` in 11pt, and institution line in 9pt.
  - Includes full fallback: if the image asset is ever absent, the report renders text branding without throwing errors.
  - Document metadata title: `Go-On Attendance Report - {class_name}`.
  - Overall file size remains lightweight (< 200 KB).

### B. Excel Attendance Report (`app/services/attendance_report_excel.py`)
- Sheet 1 ("Summary") includes a dedicated `_write_brand_block()`:
  - Row 1: `Go-On` in 18pt Espresso with the embedded logo badge placed in cell `A1`.
  - Row 2: `Attendance Report` subtitle.
  - Rows 3-5: Metadata for `Class`, `Subject`, and `Date Range`.
  - Row 7: Data table header (auto-filter dynamically anchored to `A7:G{last_row}`).
  - Sheets 2 ("Daily Attendance") and 3 ("Period Summary") maintain clean, unadorned operational tables with headers on row 1.

---

## 6. Verification & Test Results

### A. Flutter Analysis
```
flutter analyze
No issues found! (ran in 5.6s)
```
- **0 errors, 0 warnings, 0 lints.**

### B. Flutter Tests
```
flutter test
124 / 124 tests passed! (100% success rate)
```
- Includes [`mobile/test/go_on_branding_test.dart`](file:///C:/Users/Abishek/Desktop/am-oss/mobile/test/go_on_branding_test.dart) covering asset integrity, aspect ratio preservation, semantics labels, and large text scales.
- Includes responsive multi-size tests in [`mobile/test/login_ux_test.dart`](file:///C:/Users/Abishek/Desktop/am-oss/mobile/test/login_ux_test.dart) across 320x640, 360x800, 390x844, and 430x932 with 1.0x and 2.0x text scaling with 0 overflow errors.

### C. Backend Export & Brand Tests
```
pytest tests/test_phase9_attendance_export.py -v
24 passed in 26.38s (100% success rate)
```
- All Phase 9 + Phase 9A report tests passed, including `test_24_pdf_carries_go_on_logo_and_stays_small`.

### D. Android Release Build
```
flutter build apk --release
√ Built build\app\outputs\flutter-apk\app-release.apk (55.3MB)
```
- Packaged cleanly with new adaptive launcher icon resources and updated application label.

### E. Flutter Web Build
```
flutter build web
√ Built build\web
```
- Local CanvasKit configuration preserved. Browser title verified as `Go-On`.

---

## 7. Changed Files Summary

```
M  app/services/attendance_report_excel.py
M  app/services/attendance_report_pdf.py
A  app/services/report_branding.py
A  app/assets/branding/go_on_badge.png
M  mobile/android/app/src/main/AndroidManifest.xml
M  mobile/android/app/src/main/res/drawable/launch_background.xml
M  mobile/android/app/src/main/res/drawable-v21/launch_background.xml
A  mobile/android/app/src/main/res/values/ic_launcher_background.xml
A  mobile/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
M  mobile/android/app/src/main/res/mipmap-*/ic_launcher.png (5 densities)
A  mobile/android/app/src/main/res/drawable-*/ic_launcher_foreground.png (5 densities)
M  mobile/pubspec.yaml
A  mobile/assets/branding/go_on_logo.png
A  mobile/assets/branding/source/go_on_logo_original.png
A  mobile/lib/widgets/common/go_on_brand.dart
M  mobile/lib/widgets/widgets.dart
M  mobile/lib/main.dart
M  mobile/lib/auth/screens/splash_screen.dart
M  mobile/lib/auth/screens/login_screen.dart
M  mobile/lib/student/screens/student_dashboard_screen.dart
M  mobile/lib/faculty/screens/faculty_dashboard_screen.dart
M  mobile/lib/admin/screens/admin_student_face_screen.dart
M  mobile/web/index.html
M  mobile/web/manifest.json
M  mobile/web/favicon.png
M  mobile/web/icons/Icon-*.png (4 files)
M  mobile/test/widget_test.dart
M  mobile/test/login_ux_test.dart
A  mobile/test/go_on_branding_test.dart
M  tests/test_phase9_attendance_export.py
A  scripts/generate_go_on_brand_assets.py
```

---

## 8. Conclusion

Phase 9A is complete. The application is visibly, authoritatively, and consistently branded **Go-On** across Mobile, Web, Android OS integration, PDF documents, and Excel workbooks, anchored by the product owner's official logo.
