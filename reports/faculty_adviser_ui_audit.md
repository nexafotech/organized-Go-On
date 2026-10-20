# Go-On Faculty & Class Adviser Portal UI/UX Alignment Audit & Refactoring Plan

**Project:** go-On college attendance application  
**Date:** October 18, 2026  
**Status:** Audit Completed — Implementation Plan Prepared  
**Primary Reference:** Student Portal (`mobile/lib/student/screens/student_dashboard_screen.dart`)

---

## 1. Executive Summary

This audit assesses the visual design, layout architecture, typography, responsiveness, and user experience of the **Faculty** and **Class Adviser** portals in the go-On mobile application against the high-quality benchmark established by the **Student Portal**.

While the student portal delivers a premium experience with liquid ambient backdrops, frosted glass cards, signature `CaviarDreams` typography, an integrated header card with drawer navigation, and a floating glass navigation dock, the faculty and class adviser portals currently suffer from architectural inconsistencies:
- A rigid material `AppBar` with 4 cramped action icons that causes header crowding on mobile screens.
- A "double header" problem on the faculty dashboard (AppBar on top + duplicate hero card below).
- A rigid rectangular `BottomNavigationBar` glued to the screen edge instead of the floating glass navigation dock.
- Missing signature `CaviarDreams` typography on faculty greetings and names.
- Missing the liquid ambient glow canvas, making faculty screens appear flat and visually disconnected.
- Inconsistent card corner radii, button hierarchies, and table stylings across the class adviser screens.

All role-specific business logic, attendance marking, SCRFD + ArcFace AI session review, period window validations, and class adviser authoritative privileges will be 100% preserved while aligning the visual presentation with the student portal design language.

---

## 2. Portal Architecture & Screen Inventory

| Portal / Module | File Location | Key Roles & Capabilities |
| :--- | :--- | :--- |
| **Student Reference** | `mobile/lib/student/screens/student_dashboard_screen.dart` | Student summary, concentric ring gauge, petal chart, daily history, floating glass nav, drawer |
| **Student Timetable** | `mobile/lib/student/screens/student_timetable_screen.dart` | Weekly schedule, period cards, status chips |
| **Faculty Dashboard** | `mobile/lib/faculty/screens/faculty_dashboard_screen.dart` | Active class slot, timetable overview, session resume, quick access cards |
| **Faculty Attendance** | `mobile/lib/faculty/screens/faculty_attendance_screen.dart` | Available periods (Today, Yesterday, Past Dates), period cards |
| **Faculty Attendance Entry** | `mobile/lib/faculty/screens/faculty_attendance_entry_screen.dart` | Student roster list, P/A/OD radio toggles, camera AI batch recognize |
| **Class Adviser Screen** | `mobile/lib/faculty/screens/faculty_class_advisor_screen.dart` | Advised class P1–P7 periods, daily summary modal, authoritative period access |
| **Class Adviser Entry** | `mobile/lib/faculty/screens/faculty_class_advisor_entry_screen.dart` | Authoritative roster entry for advised class across all periods |
| **Faculty Reports** | `mobile/lib/faculty/screens/faculty_attendance_report_screen.dart` | Class summary, daily matrix, historical matrix, PDF/Excel export |
| **Faculty Profile** | `mobile/lib/faculty/screens/faculty_profile_screen.dart` | Account details, password change, sign out |

---

## 3. Screen-by-Screen Comparison: Student Portal vs. Faculty Portal

### A. Scaffold & Background Backdrop
| Attribute | Student Portal (Reference) | Faculty & Adviser Portal (Current) | Defect / Alignment Goal |
| :--- | :--- | :--- | :--- |
| **Background** | `_buildLiquidAmbientCanvas()` with blurred optical caustics | Plain flat `colors.background` | **DEF-04**: Add liquid ambient glow to faculty dashboard |
| **Top App Bar** | No rigid AppBar; integrated header card with drawer trigger | Rigid `AppBar` with 4 cramped icon buttons | **DEF-01**: Remove cramped AppBar; integrate actions into header/drawer |
| **Navigation Dock** | Floating glass pill dock (`borderRadius: 32`, blur, margin) | Rigid rectangular `BottomNavigationBar` glued to bottom edge | **DEF-02**: Upgrade to floating glass navigation dock |
| **Navigation Drawer** | Full frosted pearl glass drawer with role pill & services | None (all actions crammed into AppBar) | **DEF-05**: Implement faculty navigation drawer |

### B. Header & Identity Presentation
| Attribute | Student Portal (Reference) | Faculty Portal (Current) | Defect / Alignment Goal |
| :--- | :--- | :--- | :--- |
| **Header Layout** | Top Row: Logo (left), Role pill + Notification + Avatar (right) | AppBar title + 4 icons; then separate Hero card below | **DEF-01**: Eliminate duplicate header; unify into single hero card |
| **Typography** | `CaviarDreams` 28px bold for user name, `Welcome Back!` | Standard sans-serif for name; tiny `bodySmall` greeting | **DEF-03**: Apply `CaviarDreams` typography to faculty name |
| **Role Pill** | Gold accent `STUDENT` pill (`colors.accentStrong`) | Standard border `FACULTY` or `CLASS ADVISOR` | Standardize with student role badge styling |
| **Metadata** | Horizontal Wrap with badge, class, department chips | Stacked plain text lines (`Faculty ID: ...`) | Upgrade to clean icon-chip wrap |

### C. Dashboard Cards & Content Hierarchy
| Section | Student Portal (Reference) | Faculty Portal (Current) | Defect / Alignment Goal |
| :--- | :--- | :--- | :--- |
| **Active Slot Card** | Concentric rings gauge + petal chart | "Current Scheduled Slot" card | Refine card styling with glass gradient and active badge |
| **Empty Slot State** | Clean glass card with subtle icon & message | Generic standard card | Align with student empty state styling |
| **Quick Action Cards** | Clean modular cards with responsive touch targets | Squeezed 2-column row with 11px cut-off subtitles | **DEF-06**: Harmonize card padding, font scale, button heights |
| **Class Adviser Card** | N/A (Role specific) | Heavy hero card with repetitive descriptive text | Make compact, professional, and action-focused |

---

## 4. Confirmed UI/UX Defects Inventory

1. **[DEF-01] Double Header Clutter in Faculty Dashboard:** The standard `AppBar` containing 4 icon buttons (`[notif, report, theme, logout]`) plus title stacks directly above the Faculty Identity Hero Card, wasting over 120px of mobile vertical screen space.
2. **[DEF-02] Rigid Material BottomNavigationBar:** Faculty and Class Adviser screens use an unstyled bottom navigation bar glued to the viewport edge instead of the floating glass pill navigation dock used by the student portal.
3. **[DEF-03] Missing `CaviarDreams` Signature Typography:** Faculty member names and section titles use system default sans-serif, breaking brand continuity.
4. **[DEF-04] Missing Liquid Ambient Glow Canvas:** Faculty screens lack the optical background caustics that give the student portal its depth.
5. **[DEF-05] Missing Faculty Navigation Drawer:** Unlike the student portal which houses secondary services and settings in a frosted drawer, faculty screens place secondary controls as cramped icon buttons.
6. **[DEF-06] Inconsistent Corner Radii & Elevation:** Mixed usage of `AppRadius.smallBorder`, `AppRadius.mediumBorder`, `AppRadius.pillBorder`, and hardcoded `14` / `16` / `28` values across faculty cards.
7. **[DEF-07] Class Adviser Portal TabBar & Header Redundancy:** Advised class banner repeats across multiple views with standard underline tab indicators.
8. **[DEF-08] Action Button Sizing & Touch Targets:** Squeezed quick access cards have 11px text and buttons with zero minimum touch targets.
9. **[DEF-09] Dark Mode Surface Tuning:** Excessive shadow opacity and mismatched surface tints in attendance table dialogs.
10. **[DEF-10] Responsive Tablet & Desktop Centering:** Need unified `ConstrainedBox(maxWidth: 1080)` wrapper across all tabs.

---

## 5. Phased Implementation Plan

### Phase 1: Unify Header & Navigation Framework
- Implement `_buildFacultyDrawer()` mirroring the student drawer structure (Go-On logo, role pill, faculty credentials, timetable, reports, password change, theme toggle, sign out).
- Replace the rigid `AppBar` and double-header on `FacultyDashboardScreen` with the integrated single-card liquid glass hero header.
- Wrap bottom navigation in the floating glass pill dock (`borderRadius: 32`, `BackdropFilter`, specular gradient).

### Phase 2: Redesign Faculty Dashboard Hero & Typography
- Render faculty full name in `CaviarDreams` 28px bold.
- Display `GoOnLogo` on top-left (touchable to open drawer), role pill (`FACULTY` or `CLASS ADVISOR`), unread notification bell with badge counter, and `UserAvatarWidget` on top-right.
- Add `_buildLiquidAmbientCanvas()` background to faculty dashboard.

### Phase 3: Refine Active Class Slot & Quick Access Cards
- Modernize the "Current Scheduled Slot" card with subtle glass gradient, pulsing "ACTIVE NOW" badge, and clean period/time/class metadata.
- Clean up empty slot state when no teaching class is scheduled.
- Rebalance the Quick Access Cards ("Attendance Reports" & "Mark Attendance") with proportional typography and consistent touch targets.

### Phase 4: Modernize Class Adviser & Attendance Portal
- Update `FacultyClassAdvisorScreen` and `FacultyAttendanceScreen` with glass tab bars, clean period cards, and refined daily summary modals.
- Align status badge colors with the central design tokens (`colors.present`, `colors.absent`, `colors.od`).

### Phase 5: Responsive Verification & Regression Testing
- Validate mobile viewports (Samsung Galaxy S24, 360px-412px width), tablet (768px), and laptop/desktop (1080px max width).
- Run `flutter analyze` and `flutter test` (203+ tests).
- Verify attendance workflows, AI batch recognition, and report exports remain 100% functional.

---

## 6. Faculty Timetable UI Redesign (Reference Image 1 Alignment) — Completed

### A. Architectural & Visual Upgrades
1. **7-Day Dynamic Capsule Selector Strip:**
   - Replaced plain button bar with an interactive 7-day capsule selector inspired by Reference Image 1.
   - Computes real-world calendar dates dynamically for the current week using Indian Standard Time (IST, UTC+05:30) via `TimezoneUtils.toIst()`.
   - Displays weekday label (`Mon` .. `Sun`) on top and calendar day number below.
   - Selected day is encapsulated in a vertical rounded pill capsule (`borderRadius: 22`) with solid contrast fill and bottom indicator dot.
   - Indicates the current real-world day with an accent border and dot, and marks days with scheduled periods with subtle class indicator dots.
   - Sized responsively using `Expanded` across the 7 days with zero horizontal overflow on standard mobile devices (360px–412px).

2. **Daily Summary Subheader:**
   - Title Case day name (e.g. `Monday`, `Wednesday`) with clean typography.
   - Human-readable formatted date (e.g. `18 October 2026`).
   - `TODAY` pill badge with active green indicator dot when viewing the current day.
   - Dynamic session counter chip (`N Sessions` or `0 Sessions`).

3. **Pastel Session Cards:**
   - Sized with generous padding and smooth `borderRadius: 24` matching Reference Image 1.
   - Implemented a 5-tone harmonious palette cycling by index:
     - Card 0: Soft Peach / Apricot (`0xFFFDF1E7` light / `0xFF221812` dark with `#E88A4B` accent)
     - Card 1: Soft Cloud Slate / Periwinkle (`0xFFEEF4F8` light / `0xFF131C24` dark with `#5BA4DC` accent)
     - Card 2: Soft Sky / Aqua Mint (`0xFFE8F6F6` light / `0xFF122223` dark with `#43C5C1` accent)
     - Card 3: Soft Butter Sand (`0xFFFAF6E5` light / `0xFF211D12` dark with `#D4B743` accent)
     - Card 4: Soft Lavender / Lilac (`0xFFF5EFF8` light / `0xFF201424` dark with `#BB70E0` accent)
   - Integrated period time pill (`Period 1 • 9:10 AM - 10:00 AM`) with clock icon.
   - Circular trailing action button (42x42 round button) matching Reference Image 1:
     - Tapping on today's classes opens `FacultyAttendanceEntryScreen` directly to record attendance.
     - Tapping on other days opens an informative modal bottom sheet with period details.
   - Preserves exact subtitle format `'Code: ${item.subjectCode} | Class: ${item.className}'` ensuring 100% test compatibility.

4. **Welcoming Empty State:**
   - Replaced plain grey icon with a gentle card container (`borderRadius: 24`), warm sun/calendar icon, friendly contextual copy, and a one-tap "Go to Today" button.

### B. Automated Testing & Verification
- **Static Analysis:** `flutter analyze` executed with **0 issues found**.
- **Test Suite:** `flutter test` executed with **207/207 tests passing** (including 4 dedicated widget tests in `test/faculty_timetable_redesign_test.dart`).
- **Release APK Built:**
  - File: `mobile/build/app/outputs/flutter-apk/app-release.apk`
  - Size: **65.8 MB** (69,037,130 bytes)
  - Build Version: `2.0.0+6`
  - Target: Real Android Devices (ARM64/x86_64 production release).

