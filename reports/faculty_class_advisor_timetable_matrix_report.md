# go-On — Weekly Matrix Timetable View in Faculty & Class Advisor Portals

**Date:** October 19, 2026  
**Target Platform:** Flutter Mobile (Samsung Galaxy S24, 393 × 851 dp) & FastAPI Backend  
**Reference Design:** Student Portal Timetable Weekly Matrix Panel

---

## 1. Overview & Objective

The weekly matrix timetable view from the student portal has been implemented across both the **Faculty Portal** and **Class Advisor Portal**:
- **7-day horizontal column layout** (Monday through Sunday) with date chips and highlighted "Today" pill.
- **Left-hand time rail** with explicit start times for all 9 daily slots (Periods P1–P7, Tea Break at 10:35 AM, Lunch Break at 12:45 PM).
- **Subject cards with soft pastel palettes** (`#EAE3F7` Lavender for FDS, `#FDE7D2` Peach for DMC, `#D9F2E6` Mint for OOPS, `#DCEBFB` Soft Blue for DPCO, `#FEE0E0` Rose for DS, etc.).
- **Multi-period consecutive block merging** (e.g., 2-period lab or multi-slot lectures span contiguous vertical blocks with a single consolidated card).
- **Distinct horizontal divider bars** for institutional breaks (Tea Break 10:35–10:55, Lunch Break 12:45–01:45).
- **Interactive detail bottom sheet** upon tapping any class card showing full course code, subject name, period timing, classroom/venue, faculty/staff name, and attendance status.
- **Seamless mode switcher** in the Faculty Portal between **Day Agenda** and **Weekly Matrix**, plus an Advisor toggle between **My Schedule** and **Class Schedule** (`II Year CSE Cyber Security - Class 1`).
- **Dedicated "CLASS SCHEDULE" tab** in the Class Advisor Portal alongside Today, Yesterday, and Past Dates.

---

## 2. Architectural & Implementation Summary

### 2.1 Backend Endpoints (`app/api/faculty.py`)
- **`GET /api/v1/faculty/class-advisor/timetable`**:
  - Validates authentication (`faculty` or `admin` role).
  - Identifies the authenticated faculty's assigned class/section (e.g., `II Year CSE Cyber Security - Class 1`, `class_id: 2`).
  - Queries `Timetable` records for Monday through Sunday (Days 1 to 7, Periods 1 to 7).
  - Returns a unified payload of 42 timetable entries with course codes, subject names, faculty names, room numbers, and timings.
- **`GET /api/v1/faculty/class/{class_id}/timetable`**:
  - Allows querying any class section timetable with role authorization.

### 2.2 Reusable Matrix Widget (`mobile/lib/widgets/timetable/weekly_matrix_timetable_view.dart`)
- **Grid Layout**: 
  - Synchronized two-dimensional scrolling (fixed left time rail + horizontally scrollable day columns with vertical period scrolling).
  - Custom column width (88 dp per day) calibrated for Samsung Galaxy S24 (393 dp viewport) allowing 3.5 days visible at once with smooth snapping and scroll hints.
- **Slot Alignment**:
  - P1: 08:45 AM – 09:40 AM
  - P2: 09:40 AM – 10:35 AM
  - Tea Break: 10:35 AM – 10:55 AM (Horizontal subtle bar)
  - P3: 10:55 AM – 11:50 AM
  - P4: 11:50 AM – 12:45 PM
  - Lunch Break: 12:45 PM – 01:45 PM (Horizontal subtle bar)
  - P5: 01:45 PM – 02:40 PM
  - P6: 02:40 PM – 03:30 PM
  - P7: 03:30 PM – 04:20 PM
- **Consecutive Period Merging**:
  - Automatically merges identical consecutive periods on the same day into a unified single card spanning the full combined height (e.g., P3 + P4 OOPS Lab).
- **Theme Awareness**:
  - Supports both **Warm Light** (`#FFFBF9`, `#F7EFE9`) and **Obsidian Dark** (`#171417`, `#201B20`), adapting card text contrast, border opacity, and background tinting.

### 2.3 Faculty Dashboard Integration (`mobile/lib/faculty/screens/faculty_dashboard_screen.dart`)
- Added **View Switcher Icon Button** in the AppBar:
  - Toggles between `TimetableViewMode.dayAgenda` (default day view) and `TimetableViewMode.weeklyGrid` (weekly matrix view).
- Added **Advisor Scope Selector** (`Key('scope_my_schedule')` vs `Key('scope_class_schedule')`):
  - Visible whenever the faculty is a designated Class Advisor (`isClassAdvisor == true`).
  - Lets faculty switch between their personal teaching timetable and their class's complete timetable.
- Addressed narrow mobile overflow risks by using `Flexible` containers on time/period badges and constrained titles.

### 2.4 Class Advisor Portal Integration (`mobile/lib/faculty/screens/faculty_class_advisor_screen.dart`)
- Expanded the top tab bar to 4 tabs:
  - `[ TODAY | YESTERDAY | PAST DATES | CLASS SCHEDULE ]`
- Configured with `isScrollable: true`, `tabAlignment: TabAlignment.start`, and `labelPadding: EdgeInsets.symmetric(horizontal: 12)` to prevent tab clipping on Samsung Galaxy S24 (393 dp).
- Renders `WeeklyMatrixTimetableView` directly inside the 4th tab with live data from `facultyService.classAdvisorSchedule`.

---

## 3. Verification & Test Suite Summary

### 3.1 Automated Tests Executed
1. **`test/faculty_and_advisor_timetable_matrix_test.dart`** (4 test groups, 4 passed):
   - `WeeklyMatrixTimetableView` renders 7 days (Mon–Sun), time rail slots (P1–P7, Tea, Lunch), and pastel cards.
   - Faculty Dashboard Timetable tab toggles between Day Agenda and Weekly Grid view modes and switches between "My Schedule" and "Class Schedule".
   - Class Advisor Screen contains the `CLASS SCHEDULE` tab and renders the full matrix.
   - Galaxy S24 layout test (393 × 851 dp) in Obsidian Dark theme passes with **0 RenderFlex overflow**.
2. **Regression Test Suites** (14 passed):
   - `test/faculty_timetable_redesign_test.dart`
   - `test/faculty_class_advisor_lunch_break_removal_test.dart`
   - `test/student_timetable_seven_day_test.dart`
3. **Static Analysis**:
   - `flutter analyze`: **0 warnings, 0 errors, No issues found!**

### 3.2 Release Artifacts
- **Release APK**: Built successfully via `flutter build apk --release` (66.2 MB compiled / 69.3 MB on disk).
- **Location**: `E:\originalam\app-release.apk`
- **Wireless Download URL**: `http://192.168.29.56:8080/app-release.apk` (served via port 8080 daemon).
