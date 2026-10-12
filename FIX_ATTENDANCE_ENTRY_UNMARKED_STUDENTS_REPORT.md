# Attendance Marker — Attendance Entry Unmarked Students Fix Report

## Overview
- **Issue**: Opening a new attendance marking session defaulted every student to `PRESENT` (Total = 64, Present = 64, Absent = 0, OD = 0) with all `[P]` buttons preselected.
- **Resolution**: Implemented the `UNMARKED` state for new attendance sessions across the backend and frontend. In a new session, all students start `UNMARKED` with neutral `[P] [A] [OD]` buttons, counters start at `Total = N, Present = 0, Absent = 0, OD = 0, Unmarked = N`, and a student only transitions to a status upon explicit faculty selection.
- **Git Branch**: `fix/attendance-entry-unmarked-students`
- **Commit Hash**: `aa47a9d`

---

## 1. Root Cause Analysis
1. **Backend Roster Default**: In `app/engines/attendance_engine.py` (`get_faculty_attendance_roster` line 555 and `get_class_advisor_attendance_roster` line 1024), when no attendance record existed (`rec is None`), the API returned `"attendance_status": rec.status.value if rec else "PRESENT"` instead of `"UNMARKED"`.
2. **Model Default**: In `mobile/lib/models/faculty_attendance_model.dart` line 122, `StudentRosterItem.fromJson` defaulted missing values to `'PRESENT'` (`json['attendance_status'] as String? ?? 'PRESENT'`).
3. **Screen Initialization Overwrite**: In `mobile/lib/faculty/screens/faculty_attendance_entry_screen.dart` (lines 67-69) and `faculty_class_advisor_entry_screen.dart` (lines 73-75), the `_loadRoster()` callback explicitly overwrote `'UNMARKED'` to `'PRESENT'`:
   ```dart
   if (s.attendanceStatus == 'UNMARKED') {
     s.attendanceStatus = 'PRESENT';
   }
   ```
This caused every new session to display all students marked as `PRESENT`.

---

## 2. Summary of Changes
### Backend (`app/engines/attendance_engine.py`)
- **Lines 555 & 1024**: Updated fallback from `"PRESENT"` to `"UNMARKED"` when no `AttendanceRecord` exists for a student in `get_faculty_attendance_roster` and `get_class_advisor_attendance_roster`.
- Existing attendance records (`rec.status.value`) continue to be loaded and preserved when editing/resuming existing sessions (Case B).

### Flutter Client Model (`mobile/lib/models/faculty_attendance_model.dart`)
- **Line 122**: Updated `StudentRosterItem.fromJson` default value from `'PRESENT'` to `'UNMARKED'`.

### Faculty Attendance Entry Screen (`mobile/lib/faculty/screens/faculty_attendance_entry_screen.dart`)
- **`_loadRoster()`**: Removed the loop statement that overwrote `UNMARKED` to `PRESENT`.
- **Counters**: Added dynamic `unmarkedCount = _students.where((s) => s.attendanceStatus == 'UNMARKED').length` calculation.
- **Header Summary Card**: Added `_buildStatCounter('Unmarked', '$unmarkedCount', colors.textMuted)` to display the live count of unmarked students alongside Total, Present, Absent, and OD.
- **Student Row UI**: Neutral styling is preserved for `[P] [A] [OD]` when `UNMARKED`. Selecting a status explicitly marks that student and highlights only that button.
- **Bulk Actions**: "All Present" and "All Absent" explicitly mark every student and update counters accordingly.
- **Search & Filter**: Preserved student object state across search queries.
- **Submission Guard**: Added validation in `_submitAttendance()` to prevent submitting if `unmarkedCount > 0`, displaying a clear warning SnackBar:
  `"Cannot submit: X students remain unmarked. Please mark all students as Present, Absent, or OD."`

### Class Advisor Entry Screen (`mobile/lib/faculty/screens/faculty_class_advisor_entry_screen.dart`)
- **`_loadRoster()`**: Removed `UNMARKED` overwrite to `PRESENT`.
- **Counter Bar**: Added `_buildCounterChip('UNMARKED', '$unmarkedCount', colors.textMuted)` chip.
- **Submission Guard**: Blocks saving as Class Advisor if any students remain `UNMARKED`.

---

## 3. How UNMARKED is Represented
- **Data Model**: `attendanceStatus == 'UNMARKED'`.
- **Student Row**: All three status chips `[P] [A] [OD]` render with neutral styling (`colors.surfaceMuted` background, `colors.border` border, `colors.textSecondary` text, zero elevation).
- **Selection**:
  - Tapping `P` -> marks `PRESENT`, highlights green with white text.
  - Tapping `A` -> marks `ABSENT`, highlights red with white text.
  - Tapping `OD` -> opens existing On-Duty reason dialog; upon confirmation marks `OD`, highlights amber with white text.
  - Switching between buttons moves the student between counters with zero duplicate counts.

---

## 4. Counter Behavior
- **Initial State (New Session)**:
  - Total = N
  - Present = 0
  - Absent = 0
  - OD = 0
  - Unmarked = N
- **During Marking**:
  - Marking student Present: Present increments, Unmarked decrements.
  - Changing student from Present to Absent: Present decrements, Absent increments, Unmarked unchanged.
  - Changing student from Absent to OD: Absent decrements, OD increments, Unmarked unchanged.
- **Bulk Actions**:
  - "All Present": Present = Total, Absent = 0, OD = 0, Unmarked = 0.
  - "All Absent": Present = 0, Absent = Total, OD = 0, Unmarked = 0.

---

## 5. Submit Behavior
- `UNMARKED` is **never** silently converted to `PRESENT`.
- If faculty attempts to submit while any students remain unmarked, submission is blocked with an informative SnackBar specifying the exact count of unmarked students.
- Only once all students are explicitly marked (`unmarkedCount == 0`) does submission proceed to the backend API.

---

## 6. Verification & Test Results
### Flutter Tests
- **`flutter test test/unmarked_attendance_entry_test.dart`**:
  - Test 1-5: New session starts with all students UNMARKED and counters correct (Total=3, P=0, A=0, OD=0, Unmarked=3) -> **PASSED**
  - Test 6-10: Selecting Present, Absent, OD updates counters and student status dynamically -> **PASSED**
  - Test 11: All Present bulk action explicitly marks all students Present -> **PASSED**
  - Test 12: All Absent bulk action explicitly marks all students Absent -> **PASSED**
  - Test 13: Search/filter preserves selected attendance status -> **PASSED**
  - Test 14: Case B: Existing saved attendance statuses are restored correctly -> **PASSED**
  - Test 15: Submission blocked with warning when unmarked students exist -> **PASSED**
  - Test 16: Submission succeeds when all students are marked and records contain no UNMARKED status -> **PASSED**
- **`flutter test test/unmarked_class_advisor_entry_test.dart`**:
  - Advisor screen starts with all students UNMARKED -> **PASSED**
  - Advisor screen blocks submission when students are UNMARKED -> **PASSED**
  - Advisor screen marks All Present and submits successfully -> **PASSED**
- **Full Flutter Test Suite**: **110 / 110 tests passed**.
- **`flutter analyze`**: **0 issues found**.

### Backend Tests
- **`pytest tests/test_faculty_attendance_window.py -k "TestAttendanceWindowEngine"`**: **9 / 9 passed in 6.94s**.
