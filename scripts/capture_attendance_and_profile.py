import subprocess, time, os

ADB = r"C:\Users\Abishek\AppData\Local\Android\Sdk\platform-tools\adb.exe"
SERIAL = "FY6PHIEA69AMQ8HU"
OUT_DIR = r"C:\Users\Abishek\Desktop\am-oss\android_phase7_6_screens"

def adb(args):
    return subprocess.run([ADB, "-s", SERIAL] + args, capture_output=True, text=True)

def tap(x, y, d=1.0):
    print(f"Tapping ({x}, {y})...")
    adb(["shell", "input", "tap", str(x), str(y)])
    time.sleep(d)

def swipe(x1, y1, x2, y2, duration=350, d=1.0):
    print(f"Swiping ({x1}, {y1}) -> ({x2}, {y2})...")
    adb(["shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(duration)])
    time.sleep(d)

def capture(name):
    path_sd = f"/sdcard/{name}.png"
    path_local = os.path.join(OUT_DIR, f"{name}.png")
    adb(["shell", "screencap", "-p", path_sd])
    adb(["pull", path_sd, path_local])
    print(f"Captured: {path_local}")
    return path_local

# Tap Attendance Tab (tab 2: x=405, y=2316)
tap(405, 2316, d=1.5)
capture("student_03_attendance_tab")

# Scroll down
swipe(540, 1800, 540, 700, duration=400, d=1.2)
capture("student_04_attendance_scrolled")

# Tap on a subject card (e.g. at 540, 1000)
tap(540, 1000, d=1.5)
capture("student_05_subject_detail_sheet")

# Tap near top (e.g. 540, 200) to dismiss bottom sheet without back key
tap(540, 200, d=1.0)
capture("student_05_sheet_dismissed")

# Switch back to Profile tab (tab 4: x=945, y=2316)
tap(945, 2316, d=1.2)
# Scroll down on Profile
swipe(540, 1800, 540, 700, duration=400, d=1.2)
capture("student_06_profile_actions")

print("Done student detailed navigation!")
