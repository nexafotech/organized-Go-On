"""Redo student login with proper STUDENT tab and coordinates from UI dump."""
import subprocess, time, openpyxl

ADB = r"C:\Users\Abishek\AppData\Local\Android\Sdk\platform-tools\adb.exe"
EXCEL = r"C:\Users\Abishek\Documents\Attendance_Marker\ALL_ACCOUNT_CREDENTIALS_20260926.xlsx"
SERIAL = "FY6PHIEA69AMQ8HU"
OUT = r"C:\Users\Abishek\.gemini\antigravity\brain\7f90dbc7-1f76-43d0-a6a4-acccb732defd"

wb = openpyxl.load_workbook(EXCEL)
ws = wb["Students"]
pw = None
for row in range(5, ws.max_row + 1):
    r = str(ws.cell(row, 2).value or "").strip()
    if r == "721025149001":
        pw = str(ws.cell(row, 5).value or "").strip()
        break
assert pw, "Password not found"
print("Password found, length:", len(pw))

def adb(args):
    subprocess.run([ADB, "-s", SERIAL] + args, check=True)

def screencap(name):
    adb(["shell", "screencap", "-p", f"/sdcard/{name}"])
    subprocess.run([ADB, "-s", SERIAL, "pull", f"/sdcard/{name}", f"{OUT}\\{name}"], check=True)
    print(f"  >> {name}")

# Dismiss keyboard
adb(["shell", "input", "keyevent", "4"])
time.sleep(0.5)

# Tap STUDENT tab (center of [63,682][540,808] = (301, 745))
print("Tapping STUDENT tab...")
adb(["shell", "input", "tap", "301", "745"])
time.sleep(0.8)

# Clear username field at [60,847][1020,1015] center=(540,931)
print("Tapping username field...")
adb(["shell", "input", "tap", "540", "931"])
time.sleep(0.5)
for _ in range(15):
    adb(["shell", "input", "keyevent", "67"])
adb(["shell", "input", "text", "721025149001"])
time.sleep(0.3)

# TAB to password
adb(["shell", "input", "keyevent", "61"])
time.sleep(0.3)
for _ in range(30):
    adb(["shell", "input", "keyevent", "67"])

# Type password (escape special chars for adb shell input text)
# Characters that need escaping: space, &, #, ^, $, (, ), %, @, !, \, ', "
def escape_for_adb(text):
    """Escape text for adb shell input text command."""
    result = []
    for c in text:
        if c == ' ':
            result.append('%s')
        elif c in '&\\#^$()%@!"\'':
            result.append(f'\\{c}')
        else:
            result.append(c)
    return ''.join(result)

escaped = escape_for_adb(pw)
adb(["shell", "input", "text", escaped])
time.sleep(0.3)

# Dismiss keyboard
adb(["shell", "input", "keyevent", "4"])
time.sleep(0.8)
screencap("bio_redo_login.png")

# Sign In - Student Sign In button expected at approx (540, 1520) but UI was compressed
# Let's get a fresh UI dump to find it
adb(["shell", "uiautomator", "dump", "/sdcard/login.xml"])
subprocess.run([ADB, "-s", SERIAL, "pull", "/sdcard/login.xml", f"{OUT}\\login_state.xml"], check=True)

import xml.etree.ElementTree as ET
tree = ET.parse(f"{OUT}\\login_state.xml")
for n in tree.iter("node"):
    txt = n.attrib.get("text", "")
    desc = n.attrib.get("content-desc", "")
    cls = n.attrib.get("class", "")
    bounds = n.attrib.get("bounds", "")
    if txt or desc:
        print(f"cls={cls} text={txt!r} desc={desc!r} bounds={bounds}")
