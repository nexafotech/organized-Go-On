"""
Clean student login and navigate to Biometric Enrollment.
"""
import subprocess, time, openpyxl, xml.etree.ElementTree as ET, re, os

ADB = r"C:\Users\Abishek\AppData\Local\Android\Sdk\platform-tools\adb.exe"
SERIAL = "FY6PHIEA69AMQ8HU"
EXCEL = r"C:\Users\Abishek\Documents\Attendance_Marker\ALL_ACCOUNT_CREDENTIALS_20260926.xlsx"
OUT = r"C:\Users\Abishek\.gemini\antigravity\brain\7f90dbc7-1f76-43d0-a6a4-acccb732defd"

wb = openpyxl.load_workbook(EXCEL)
ws = wb["Students"]
pw = None
for row in range(5, ws.max_row + 1):
    if str(ws.cell(row, 2).value or "").strip() == "721025149001":
        pw = str(ws.cell(row, 5).value or "").strip()
        break
assert pw, "Password not found"

def adb(args):
    return subprocess.run([ADB, "-s", SERIAL] + args, capture_output=True, text=True)

def tap(x, y, d=0.8):
    adb(["shell", "input", "tap", str(x), str(y)])
    time.sleep(d)

def escape_for_adb(text):
    result = []
    for c in text:
        if c == ' ':
            result.append('%s')
        elif c in '&\\#^$()%@!"\'<>|;`~*?[]{}=+,-./':
            result.append(f'\\{c}')
        else:
            result.append(c)
    return ''.join(result)

# First dismiss keyboard if open
adb(["shell", "input", "keyevent", "111"])
time.sleep(0.5)

# Tap STUDENT tab
tap(301, 866, d=0.8)

# Tap username
tap(540, 1052, d=0.5)
for _ in range(25):
    adb(["shell", "input", "keyevent", "67"])
adb(["shell", "input", "text", "721025149001"])
time.sleep(0.3)

# Tap password
tap(540, 1256, d=0.5)
for _ in range(25):
    adb(["shell", "input", "keyevent", "67"])
adb(["shell", "input", "text", escape_for_adb(pw)])
time.sleep(0.3)

# Dismiss keyboard
adb(["shell", "input", "keyevent", "111"])
time.sleep(0.8)

# Tap Sign In
tap(540, 1277, d=5.0)

# Pull dashboard screenshot
adb(["shell", "screencap", "-p", "/sdcard/step1_dash.png"])
adb(["pull", "/sdcard/step1_dash.png", os.path.join(OUT, "step1_dash.png")])
print("Step 1 (Dashboard) done.")

# Tap Profile tab [720,2237][1080,2396] -> (900, 2316)
tap(900, 2316, d=2.0)
adb(["shell", "screencap", "-p", "/sdcard/step2_profile.png"])
adb(["pull", "/sdcard/step2_profile.png", os.path.join(OUT, "step2_profile.png")])
print("Step 2 (Profile) done.")

# Scroll to reveal Biometric Face Enrollment
adb(["shell", "input", "swipe", "540", "1800", "540", "900", "400"])
time.sleep(1.0)
adb(["shell", "input", "swipe", "540", "1800", "540", "900", "400"])
time.sleep(1.0)

# Tap Biometric Face Enrollment at [144,1578][936,1722] -> (540, 1650)
tap(540, 1650, d=3.0)
adb(["shell", "screencap", "-p", "/sdcard/step3_enrollment_guide.png"])
adb(["pull", "/sdcard/step3_enrollment_guide.png", os.path.join(OUT, "step3_enrollment_guide.png")])
print("Step 3 (Enrollment Guide) done.")

# Tap Start Enrollment at (540, 1969)
tap(540, 1969, d=3.0)
adb(["shell", "screencap", "-p", "/sdcard/step4_capture_screen.png"])
adb(["pull", "/sdcard/step4_capture_screen.png", os.path.join(OUT, "step4_capture_screen.png")])
print("Step 4 (Capture Screen) done.")
