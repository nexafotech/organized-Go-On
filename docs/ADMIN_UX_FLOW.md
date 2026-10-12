# Admin Web Panel UX Flow & Navigation Specification
**Attendance Marker System**

---

## 1. Overview & Architecture

The Admin Web Panel is a single-page responsive dashboard delivered at `/admin`. It provides administrative control over students, faculty, academic departments, class sections, subjects, timetables, attendance policies, system/AI settings, bulk seed data imports, and security audit logs.

---

## 2. Navigation Structure

```text
Admin Web Panel (/admin)
├── 1. Dashboard Overview (#tab-dashboard)
│   ├── Statistics Cards (Total Students, Faculty, Classes, Active Sessions)
│   ├── Attendance Summary (Present, Absent, OD, Overall Rate)
│   └── Live Audit Stream
├── 2. Student Management (#tab-students)
│   ├── Student Search & Class Filter
│   ├── Create Student Account Modal
│   ├── Enable / Disable Account Toggle
│   ├── Reset Password Modal
│   └── Face Enrollment Trigger
├── 3. Faculty Management (#tab-faculty)
│   ├── Faculty Search & Department Filter
│   ├── Create Faculty Account Modal
│   ├── Enable / Disable Account Toggle
│   └── Reset Password Modal
├── 4. Classes & Subjects (#tab-academic)
│   ├── Class Sections List & Add Modal
│   └── Subjects List & Add Modal
├── 5. Periods & Timetable Matrix (#tab-timetable)
│   ├── Period Timing Configurator & Overlap Guard
│   └── Interactive Class Timetable Grid
├── 6. Faculty Assignments (#tab-assignments)
│   ├── Active Assignments List
│   └── Unassigned Pairs Highlight & Assignment Modal
├── 7. Policy & Settings (#tab-settings)
│   ├── Attendance Policy Form
│   ├── System Auth Settings Form
│   └── AI Engine Configuration Form (Quantized Toggle & Warning Banner)
├── 8. Bulk Seed Data Import Center (#tab-bulk-import)
│   ├── JSON Upload / Paste Forms
│   └── Import Results Modal Summary
└── 9. Security Audit Trail (#tab-audit)
    └── Paginated Audit Events Log Table
```

---

## 3. Detailed Screen Actions & Inputs

### Student Management Flow:
1. **Search**: Input text filters student table by name or roll number instantly.
2. **Create Account**: Modal with fields `Roll Number`, `Full Name`, `Email`, `Class Section`, `Password`.
3. **Account Toggles**:
   - `Disable Account`: Changes badge to `Disabled` (Red); blocks student login.
   - `Reset Password`: Opens modal for setting a new password.
   - `Force Password Change`: Toggles flag requiring student to update password on next login.

### AI Engine Configuration Flow:
- **Quantized Model Toggle**: Default `ON`.
- **Low-End Device Warning**: If disabled on low-memory device, renders banner:
  $$\text{\textsf{⚠️ Full-precision mode may increase processing time and memory usage on this device.}}$$
