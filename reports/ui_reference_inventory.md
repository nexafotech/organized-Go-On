# UI Reference Design Inventory & Component Analysis

**Project:** go-On AI Face Attendance System  
**Audit Source Archive:** `E:\originalam\frontend ui design.zip` (15,286,228 bytes)  
**Extraction Directory:** `E:\originalam\design_reference`  
**Date of Audit:** October 14, 2026  
**Status:** Verification & Extraction Complete — 100% Parsed  

---

## 1. Executive Summary

This inventory documents every design token, typography asset, visual artifact, custom widget, layout pattern, and interactive component discovered in the reference design archive `frontend ui design.zip`.

The archive provides a comprehensive, luxury aesthetic designed around:
1. **Cream & Roasted Espresso Light Palette:** Dominated by a soft oat-cream ambient canvas (`#F6F1EA`), deep roasted espresso typography (`#221F1D`), warm terra-cotta primary accents (`#8C5A3C`), and subtle linen dividers (`#DDD5CA`).
2. **Apple Liquid Glass & Obsidian Abyss Dark Palette:** Dominated by deep midnight obsidian canvas (`#0D0B12`), violet-tinged card surfaces (`#1A1624` / `#262332`), and vivid jewel-tone status indicators (Electric Indigo `#818CF8`, Ice Cyan `#38BDF8`, Solar Amber `#F59E0B`, Emerald Mint `#10B981`).
3. **Editorial Typography:** Featuring `BrockScript` for bespoke cursive accent badges and `CaviarDreams` for minimalist geometric greetings and high-end metrics.
4. **Rich Interactive Visualizations:** Dynamic circular gauge dials (`InteractiveAttendanceOverviewCard`), multi-dimensional petal radar charts (`SubjectPetalChartCard`), and full-day chronological timeline cards (`FullDayBreakdownCard`).

---

## 2. Typography Assets Catalog

The archive contains 5 custom TrueType font files located in `assets/fonts/`:

| Font File | Font Family | Style / Weight | Intended UI Purpose | Integrated Target Path |
| :--- | :--- | :--- | :--- | :--- |
| `BrockScript.ttf` | `BrockScript` | Regular / Script | Editorial cursive badges, luxury tags, signature accents | `mobile/assets/fonts/BrockScript.ttf` |
| `CaviarDreams.ttf` | `CaviarDreams` | Regular (400) | Editorial headings, student greeting banners, metric labels | `mobile/assets/fonts/CaviarDreams.ttf` |
| `CaviarDreams_Bold.ttf` | `CaviarDreams` | Bold (700) | Card titles, percentage metrics, high-impact numbers | `mobile/assets/fonts/CaviarDreams_Bold.ttf` |
| `CaviarDreams_Italic.ttf` | `CaviarDreams` | Italic (400) | Subtle subheadings, contextual hints | `mobile/assets/fonts/CaviarDreams_Italic.ttf` |
| `CaviarDreams_BoldItalic.ttf` | `CaviarDreams` | Bold Italic (700) | High-contrast emphasis and editorial quotes | `mobile/assets/fonts/CaviarDreams_BoldItalic.ttf` |

### Pubspec Configuration Verification
All 5 font variations were added to `mobile/pubspec.yaml`:
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/fonts/
  fonts:
    - family: BrockScript
      fonts:
        - asset: assets/fonts/BrockScript.ttf
    - family: CaviarDreams
      fonts:
        - asset: assets/fonts/CaviarDreams.ttf
        - asset: assets/fonts/CaviarDreams_Bold.ttf
          weight: 700
        - asset: assets/fonts/CaviarDreams_Italic.ttf
          style: italic
        - asset: assets/fonts/CaviarDreams_BoldItalic.ttf
          weight: 700
          style: italic
```

---

## 3. Color Token System & Palette Specifications

The reference design establishes two authoritative, high-contrast themes:

### 3.1. Light Theme ("Cream & Roasted Espresso")
Designed for high legibility in bright classroom and outdoor daylight environments:

| Token Name | Hex Code | Visual Swatch Description | Usage in System |
| :--- | :--- | :--- | :--- |
| `canvasLight` | `#F6F1EA` | Soft warm oat linen | Main scaffold background |
| `surfaceLight` | `#FFFFFF` | Pure crisp white | Base glass card backgrounds with 0.85 opacity |
| `surfaceElevatedLight` | `#EDE5DB` | Warm linen tinted ivory | Elevated modal dialogs, drawers, dropdowns |
| `primaryLight` | `#8C5A3C` | Warm terra-cotta roasted espresso | Primary brand buttons, active tabs, header icons |
| `onPrimaryLight` | `#FFFFFF` | Crisp white | Text and icons on primary buttons |
| `accentLight` | `#D97706` | Solar amber gold | Status highlights, secondary actions, streak badges |
| `textPrimaryLight` | `#221F1D` | Deep roasted espresso | Titles, subject names, primary numerical readouts |
| `textSecondaryLight` | `#5C554E` | Warm earthy charcoal | Subtitles, class codes, timetable times |
| `textMutedLight` | `#8C827A` | Soft linen taupe | Captions, card borders, subtle metadata |
| `cardBorderLight` | `#E5DDD2` | Delicate oatmeal hairline | Specular card borders, table dividers |
| `presentLight` | `#16A34A` | Forest emerald green | Present badge, positive attendance metrics |
| `absentLight` | `#DC2626` | Deep crimson scarlet | Absent status chip, alert indicators |
| `odLight` | `#2563EB` | Royal cobalt azure | On-Duty status indicator, college duty pills |

### 3.2. Dark Theme ("Obsidian Abyss & Apple Liquid Glass")
Designed for low-glare evening study, battery saving on OLED screens, and luxury visual appeal:

| Token Name | Hex Code | Visual Swatch Description | Usage in System |
| :--- | :--- | :--- | :--- |
| `canvasDark` | `#0D0B12` | Deep obsidian midnight | Scaffold background with violet undertone |
| `surfaceDark` | `#1A1624` | Frosted dark obsidian | Base glass card fill with blur |
| `surfaceElevatedDark` | `#262332` | Elevated plum slate | Modal bottom sheets, dialogs, drawers |
| `primaryDark` | `#818CF8` | Radiant sapphire crystal | Primary interactive controls, selected chips |
| `onPrimaryDark` | `#0D0B12` | Deep midnight | High-contrast text on radiant primary buttons |
| `accentDark` | `#38BDF8` | Electric ice cyan | Active glowing rings, live pulse indicators |
| `textPrimaryDark` | `#F8FAFC` | Crisp luminescent white | Primary headlines, student metrics |
| `textSecondaryDark` | `#94A3B8` | Cool slate silver | Subheadings, period timing details |
| `textMutedDark` | `#64748B` | Subtle dusk gray | Footnotes, inactive indicators |
| `cardBorderDark` | `#2D283E` | Translucent glass hairline | Rim light borders with specular reflection |
| `presentDark` | `#22C55E` | Neon emerald mint | Present attendance status and gauge arc |
| `absentDark` | `#EF4444` | Neon coral red | Absent attendance status and gauge arc |
| `odDark` | `#38BDF8` | Cyan jewel tone | On-Duty attendance status and gauge arc |

---

## 4. Domain & UI Component Inventory

| Component Name | Source File | Category | Responsibilities & Capabilities |
| :--- | :--- | :--- | :--- |
| `InteractiveAttendanceOverviewCard` | `interactive_attendance_overview_card.dart` | Attendance Visualization | Dual-arc circular attendance dial with animated needle, floating frosted glass puck, target milestone indicator (75% / 85%), and quick-action metric breakdown. |
| `SubjectPetalChartCard` | `subject_petal_chart_card.dart` | Analytics & Insights | Radial petal radar chart visualizing subject-by-subject attendance distribution with interactive touch selection, grade classification, and risk radar. |
| `FullDayBreakdownCard` | `full_day_breakdown_card.dart` | Attendance & Timetable | Chronological daily timeline mapping periods 1 through 7, coffee/lunch break banners, and verified attendance statuses. |
| `AppScaffold` | `app_scaffold.dart` | Scaffold & Layout | Multi-layer ambient canvas with liquid blur orbs (`buildLiquidAmbientCanvas`), responsive safe area, and adaptive status bar theming. |
| `AppCard` / `GlassCard` | `app_card.dart` | Surface Containers | Specular rim lighting, dual-layer backdrop filter blur (`sigma: 16`), gradient glass borders, and subtle elevation shadows. |
| `AppButtons` | `app_buttons.dart` | Form Controls | Luxury pill-shaped buttons with rounded corners (`BorderRadius: 28`), tactile bounce animation, and glow elevation. |
| `AttendanceLegend` | `attendance_legend.dart` | Indicators | Status indicator chips with jewel-tone dots and bold count readouts. |
| `AttendanceSummaryCard` | `attendance_summary_card.dart` | Metrics Card | Three-column stat summary (Present, Absent, On-Duty) with percentage delta. |

---

## 5. Design Showcase & Mock Architecture

To allow product managers, designers, and developers to audit the full luxury reference design at runtime without disturbing active student or faculty backend sessions, the migration established:
- **`DesignMockData` (`lib/design_mode/design_mock_data.dart`):** Complete, self-contained mock models for students, faculties, attendance records, circular overview cards, petal charts, and full-day timetables.
- **`DesignGalleryScreen` (`lib/design_mode/design_gallery_screen.dart`):** An interactive multi-tab design gallery accessible from the student drawer, profile screen, and debug actions. It features:
  - Tab 1: Image 1 & 2 Luxury Profile Showcase (Anna K., 04 identity, Connect Card, Moments).
  - Tab 2: Attendance Visualization Showcase (Interactive Circular Dial, Petal Radar Chart, Timeline).
  - Tab 3: Matrix Timetable & Editorial Schedule Showcase.
  - Live Theme Mode Toggle (Warm Cream vs. Obsidian Abyss).
