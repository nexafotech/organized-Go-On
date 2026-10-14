# Go-On UI/UX Design Studio (`ui-desine`)

This directory is an independent, 100% matching copy of the current **Go-On UI/UX design architecture**.

---

## 🌟 What Makes This Ideal for UI Designers

1. **Direct Flutter Project**: Open `E:\originalam\ui-desine` directly in VS Code, Android Studio, or Cursor. It is ready to run immediately.
2. **Interactive Design Showcase (`lib/design_mode/`)**:
   - Boots directly into the **Go-On Design Studio** gallery.
   - 1-click preview of **every single screen** in the app (Student Dashboard, Timetable, Attendance Gauge, Faculty Dashboard, Period Marker, Advisor Matrix, Reports, etc.).
   - Pre-loaded with realistic mock student and faculty data so designers do **NOT** need the Python backend or database running.
3. **Hot Reload Ready**: Press **`r`** in the terminal or save any file in VS Code to see your changes live on screen instantly.
4. **Completely Isolated**: Modifying files here will **NOT** alter the production mobile application or backend.

---

## 🚀 How to Run the Design Studio

Open a terminal inside this directory (`E:\originalam\ui-desine`):

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run in Google Chrome (recommended for rapid design iteration)
flutter run -d chrome
```

Or run on a connected iPhone or Android device / emulator:
```bash
flutter run
```

---

## 🎨 Screen & Code Map

| Screen / Feature | Location |
| :--- | :--- |
| **Design Studio Gallery** | `lib/design_mode/design_gallery_screen.dart` |
| **Mock Data Repository** | `lib/design_mode/design_mock_data.dart` |
| **Brand Colors & Design Tokens** | `lib/core/theme/app_tokens.dart` *(Espresso `#2B1A13`, Warm Beige, Accent Gold)* |
| **Material 3 Themes & Typography** | `lib/core/theme/app_theme.dart` |
| **Reusable Buttons & Cards** | `lib/widgets/common/` |
| **Attendance Gauges & Status Chips** | `lib/widgets/attendance/` |
| **Student Dashboard & Timetable** | `lib/student/screens/` |
| **Faculty Dashboard & Attendance** | `lib/faculty/screens/` |
| **Auth & Splash Screens** | `lib/auth/screens/` |
| **Admin Management UI** | `lib/admin/screens/` |
| **Brand Logos & Graphic Assets** | `assets/branding/` |

---

## 🎯 Design System Guidelines
Read [`DESIGN_SYSTEM_GUIDE.md`](./DESIGN_SYSTEM_GUIDE.md) for full color palettes, typography specifications, and corner radius tokens.
