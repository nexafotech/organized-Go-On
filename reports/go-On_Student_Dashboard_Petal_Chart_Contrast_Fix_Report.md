# go-On — Student Dashboard Petal Chart Text Visibility & Semantic Contrast Fix Report

**Project:** go-On Mobile Attendance Application  
**Root Path:** `E:\originalam`  
**Flutter Application:** `E:\originalam\mobile`  
**Target File:** `mobile/lib/widgets/attendance/subject_petal_chart_card.dart`  
**Associated Screen:** `mobile/lib/student/screens/student_dashboard_screen.dart`  
**Verification Date:** October 20, 2026  
**Build Status:** Clean Debug APK Built (`E:\originalam\app-debug.apk`)  

---

## 1. Executive Summary

In the Student Portal dashboard (`SubjectPetalChartCard`), after attendance was recorded, the “Today's Schedule” Nightingale Rose / Petal Chart became nearly unreadable. Dark chart segments and text had insufficient contrast, causing completed period text (such as `P1 • Present ✓`) to render in dark charcoal/black text over dark charcoal backgrounds. Furthermore, inside each segment, the subject name was printed twice in succession (e.g., `Foundations\nFoundations`), causing visual clutter and truncation.

We performed a deep inspection of the painter and color architecture in `_NightingalePetalPainter` and `SubjectClassItem`, identified the root causes, and redesigned the segment fills and typography using high-contrast, accessible semantic jewel tones without disrupting timetable integration, day scrubbing, or animations.

---

## 2. Root Cause Analysis

1. **Flawed Surface Luminance Evaluation:**
   - In `_NightingalePetalPainter`, Step A drew a dark obsidian base (`#383544` to `#1E1C25`) for completed periods (`remainingFraction == 0.0`).
   - However, the text luminance calculation evaluated `item.petalColor.computeLuminance()`. For Period 1 (morning), `petalColor` was interpolated as pearlescent cream (`#F7F5EE`, luminance = 0.93 > 0.45).
   - Because the luminance check falsely reported a light surface, the text color was assigned `#1B1922` (near-black text), painted directly on top of the dark obsidian background.
   - For `PeriodAttendanceStatus.present` and `PeriodAttendanceStatus.od`, this logic failed completely, rendering dark text on a dark base.

2. **Monochrome Charcoal Petal Fills:**
   - When classes completed, all periods faded to identical dark charcoal obsidian `#383544`, losing semantic distinction between Present (attended), Absent (missed), OD (on-duty), and Pending (unrecorded).

3. **Duplicated Subject Label Text:**
   - In `_drawPetalText`, three `TextPainter` instances were rendered: Line 1 (`numberText`), Line 2 (`labelText`), and Line 3 (`subLabel`).
   - For every status (`present`, `absent`, `od`, `pending`, `upcoming`), both `labelText` and `subLabel` received `item.shortName`, printing the subject name twice stacked on top of each other.

---

## 3. Implemented Engineering Fixes

### A. Semantic Jewel Tone Palette (`_NightingalePetalPainter` Step A)
Each period segment now renders with an accessible, high-contrast jewel-toned gradient and distinct glowing border:
- **Present:** Rich forest emerald gradient (`#166534` to `#0D3820`) with `#34D399` translucent border and `#10B981` ambient shadow.
- **Absent:** Rich ruby wine gradient (`#7F1D1D` to `#450A0A`) with `#F87171` translucent border and `#F43F5E` shadow.
- **On-Duty (OD):** Royal sapphire blue gradient (`#1E40AF` to `#172554`) with `#60A5FA` translucent border and `#3B82F6` shadow.
- **In-Progress (Live):** Emerald active liquid crystal progression with `#10B981` pulsating edge wave.
- **Pending / Unrecorded:** Sleek slate-graphite gradient (`#334155` to `#1E293B`) with `#FCD34D` amber status accent.
- **Upcoming:** Dynamic chromatic petal fill matching time-of-day progression with automatic contrast adaptation.

### B. High-Contrast Text Guarantee & Shadow Halos
- `isLightSurface` is now strictly `false` for all recorded, completed, and pending periods, guaranteeing `mainColor = Colors.white` and `subjectColor = #F8FAFC`.
- Added a soft text drop shadow (`Shadow(color: Colors.black54, blurRadius: 3.5, offset: Offset(0, 1))`) ensuring crisp readability across specular highlights and gradients.
- Status badges feature vivid semantic accents:
  - Present: Bright emerald `#4ADE80`
  - Absent: Bright coral `#FCA5A5`
  - OD: Bright sky blue `#93C5FD`
  - Pending: Bright amber `#FCD34D`

### C. Elimination of Duplicate Subject Line
`_drawPetalText` now lays out exactly two clean lines:
- **Line 1 (Header):** `P{n} • {Status / Time}` (e.g., `P1 • Present ✓`, `P2 • Absent ✗`, `P3 • On-Duty`, `P4 • 11:50 AM`)
- **Line 2 (Subject):** `item.shortName` (single clean, unclipped occurrence)

### D. Center Aperture Hub & Timeline Polish
- Center hub displays attended summary (e.g., `1/3 Present`) with bright emerald `#34D399` and crisp `#F1F5F9` sub-label.
- When tapping any petal, the hub dynamically highlights that period's status with high-contrast text and border.
- The List View leading badge and timeline bar now dynamically reflect status colors for seamless cross-mode coherence.

---

## 4. Verification & Testing

1. **Flutter Analysis:**
   - `flutter analyze lib/widgets/attendance/ lib/student/` -> **0 issues found** (passed in 7.6s).
2. **Automated Widget & Accuracy Tests:**
   - `test/subject_petal_chart_card_test.dart` -> **4/4 tests passed** (verified Present, Absent, OD, Pending, Dark Theme, and List View toggle).
   - `test/student_sunday_and_dashboard_accuracy_test.dart` -> **6/6 tests passed**.
   - `test/student_attendance_remove_overall_today_test.dart` -> **Passed**.
   - `test/student_attendance_legend_test.dart` -> **Passed**.
3. **Artifact Deployment:**
   - Debug APK generated: `build/app/outputs/flutter-apk/app-debug.apk`
   - Copied to workspace root: `E:\originalam\app-debug.apk`
