# Student Mobile App UX Flow & Threshold Reporting Specification
**Attendance Marker Mobile Suite**

---

## 1. Primary Student Workflow

```text
Student Login Screen (Roll Number + Password)
        │
        ▼
Student Mobile Dashboard
        │
        ├── Student Profile Header (Name, Register No, Class Section)
        ├── Overall Attendance Card (% & Status Badge)
        ├── Risk Status Message (SAFE / WARNING / CRITICAL)
        ├── Classes Needed / Classes Missable Calculator
        │
        ├── [ Attendance Tab ]
        │   ├── Subject-wise Attendance Breakdown
        │   └── Expandable Period & Date Log
        │
        ├── [ Timetable Tab ]
        │   └── Today's Schedule & Period Timings
        │
        └── [ Profile Tab ]
            └── Student Account Details & Password Update
```

---

## 2. Risk Status & Threshold Logic

The dashboard evaluates overall attendance percentage against minimum required threshold ($75\%$):

### SAFE Status ($\ge 75\%$):
- **Card Styling**: Emerald Green Accent Border (`#10B981`).
- **Header**: `SAFE ATTENDANCE STATUS`
- **Primary Message**: *"Your attendance is above the required minimum threshold of 75%."*
- **Calculated Metric**: *"Classes you can miss while remaining safe: X classes."*

### WARNING Status ($70\% - 74.9\%$):
- **Card Styling**: Amber Yellow Accent Border (`#F59E0B`).
- **Header**: `ATTENDANCE WARNING`
- **Primary Message**: *"Your attendance is approaching the minimum requirement."*
- **Calculated Metric**: *"Required classes to attend to reach safe status: Y classes."*

### CRITICAL Status ($< 70\%$):
- **Card Styling**: Crimson Red Accent Border (`#EF4444`).
- **Header**: `CRITICAL ATTENDANCE DEFICIT`
- **Primary Message**: *"Attendance below required minimum."*
- **Calculated Metric**: *"Required classes to reach minimum: Z classes."*

---

## 3. Period & Subject Attendance Display

Displays backend-derived metrics without duplicating calculations on mobile client:

```text
Foundations of Data Science (FDS) — 85.0% Overall
┌─────────────────────────────────────────────────────────┐
│ Period 1 (09:10 - 10:00) | Present: 17 | Rate: 85.0%    │
│ Period 4 (12:00 - 12:50) | Present: 17 | Rate: 85.0%    │
└─────────────────────────────────────────────────────────┘
```
