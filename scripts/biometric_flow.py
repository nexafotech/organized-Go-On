"""
Step-by-step biometric enrollment flow on physical device RMX3998.
Logs in as 721025149001, navigates to Profile -> Face Biometric Enrollment,
then captures every step. Uses UI dump to get exact bounds at runtime.
"""
import os
import time
import subprocess
import xml.etree.ElementTree as ET
import openpyxl

ADB = r"C:\Users\Abishek\AppData\Local\Android\Sdk\platform-tools\adb.exe"
SERIAL = "FY6PHIEA69AMQ8HU"
EXCEL = r"C:\Users\Abishek\Documents\Attendance_Marker\ALL_ACCOUNT_CREDENTIALS_20260926.xlsx"
OUT = r"C:\Users\Abishek\.gemini\antigravity\brain\7f90dbc7-1f76-43d0-a6a4-acccb732defd"

# ── helpers ────────────────────────────────────────────────────────────────────
def run(args):
    return subprocess.run([ADB, "-s", SERIAL] + args, capture_output=True, text=True)

def shell(cmd):
    return subprocess.run([ADB, "-s", SERIAL, "shell"] + cmd.split(), capture_output=True, text=True).stdout.strip()

def tap(x, y, delay=1.0):
    run(["shell", "input", "tap", str(x), str(y)])
    time.sleep(delay)

def keyevent(code, delay=0.5):
    run(["shell", "input", "keyevent", str(code)])
    time.sleep(delay)

def swipe(x1, y1, x2, y2, dur=300, delay=1.0):
    run(["shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(dur)])
    time.sleep(delay)

def screenshot(name):
    path = f"/sdcard/{name}"
    run(["shell", "screencap", "-p", path])
    local = os.path.join(OUT, name)
    run(["pull", path, local])
    print(f"  >> {name}")
    return local

def dump_ui(name="ui.xml"):
    run(["shell", "uiautomator", "dump", "/sdcard/ui.xml"])
    run(["pull", "/sdcard/ui.xml", os.path.join(OUT, name)])
    tree = ET.parse(os.path.join(OUT, name))
    return tree.getroot()

def center(bounds):
    """Parse bounds='[x1,y1][x2,y2]' and return (cx, cy)."""
    import re
    nums = list(map(int, re.findall(r"\d+", bounds)))
    return (nums[0] + nums[2]) // 2, (nums[1] + nums[3]) // 2

def find_node(root, text=None, desc=None, cls=None):
    for n in root.iter("node"):
        if text is not None and text.lower() in n.attrib.get("text", "").lower():
            return n
        if desc is not None and desc.lower() in n.attrib.get("content-desc", "").lower():
            return n
        if cls is not None and cls in n.attrib.get("class", ""):
            return n
    return None

def get_student_pw(reg_no):
    wb = openpyxl.load_workbook(EXCEL)
    ws = wb["Students"]
    for row in range(5, ws.max_row + 1):
        r = str(ws.cell(row, 2).value or "").strip()
        if r == reg_no:
            return str(ws.cell(row, 5).value or "").strip()
    return None


# ── main flow ──────────────────────────────────────────────────────────────────
print("=== BIOMETRIC ENROLLMENT FLOW ===")

# 1. Force-stop and launch fresh
print("1. Launching app fresh...")
shell("am force-stop com.aifaceattendance.mobile_app")
time.sleep(1.0)
shell("am start -n com.aifaceattendance.mobile_app/.MainActivity")
time.sleep(3.5)
screenshot("bio_01_splash.png")

# 2. Wait for login screen - tap STUDENT tab if needed
print("2. Tapping STUDENT tab and entering credentials...")
time.sleep(1.0)
# Ensure we are on STUDENT tab (Tab 1)
tap(200, 866, delay=0.5)   # STUDENT tab
time.sleep(0.5)

pw = get_student_pw("721025149001")
assert pw, "Password not found!"

# Tap username field
tap(540, 1082, delay=0.5)
for _ in range(15):
    run(["shell", "input", "keyevent", "67"])
run(["shell", "input", "text", "721025149001"])
time.sleep(0.3)

# Tab to password
keyevent(61, delay=0.3)
for _ in range(30):
    run(["shell", "input", "keyevent", "67"])

# Type password
escaped = pw.replace("&", "\\&").replace(" ", "%s").replace("'", "\\'").replace('"', '\\"')
run(["shell", "input", "text", escaped])
time.sleep(0.3)

# Hide keyboard
keyevent(4, delay=0.5)
screenshot("bio_02_login_filled.png")

# 3. Sign In
print("3. Signing in...")
tap(540, 1520, delay=4.0)
screenshot("bio_03_student_dashboard.png")

# 4. Tap Profile tab (rightmost) - from bottom nav
print("4. Navigating to Profile...")
# dump to find Profile nav item
root = dump_ui("bio_ui_dash.xml")
profile_node = find_node(root, desc="Profile")
if profile_node is not None:
    cx, cy = center(profile_node.attrib["bounds"])
else:
    cx, cy = 833, 2300
tap(cx, cy, delay=2.0)
screenshot("bio_04_profile.png")

# 5. Scroll to see Biometric Enrollment button
print("5. Scrolling profile to find enrollment button...")
swipe(540, 1800, 540, 800, dur=300, delay=1.0)
screenshot("bio_05_profile_scrolled.png")

# 6. Tap "Face Biometric Enrollment"
print("6. Tapping Biometric Enrollment...")
root = dump_ui("bio_ui_profile.xml")
bio_node = find_node(root, desc="Face Biometric Enrollment") or find_node(root, text="Biometric Enrollment")
if bio_node is not None:
    cx, cy = center(bio_node.attrib["bounds"])
    print(f"   Found at {cx}, {cy}")
    tap(cx, cy, delay=3.0)
else:
    # fallback: scroll more and tap around expected location
    print("   Biometric button not found, scrolling more...")
    swipe(540, 1500, 540, 800, dur=300, delay=1.0)
    screenshot("bio_05b_profile_scrolled2.png")
    root = dump_ui("bio_ui_profile2.xml")
    bio_node = find_node(root, desc="Face Biometric Enrollment") or find_node(root, text="Biometric Enrollment")
    if bio_node:
        cx, cy = center(bio_node.attrib["bounds"])
        tap(cx, cy, delay=3.0)
    else:
        tap(540, 1350, delay=3.0)  # last resort

screenshot("bio_06_enrollment_screen.png")

# 7. Check if guidelines dialog appeared
print("7. Checking for enrollment guidelines...")
root = dump_ui("bio_ui_enrollment.xml")
start_node = find_node(root, text="Start Enrollment")
if start_node:
    print("   Guidelines dialog visible! Tapping Start Enrollment...")
    cx, cy = center(start_node.attrib["bounds"])
    tap(cx, cy, delay=2.0)
else:
    print("   No Start Enrollment button found – may already be in camera mode or loading...")

screenshot("bio_07_after_start.png")

# 8. Camera permission grant if needed
print("8. Checking for camera permission dialog...")
time.sleep(2)
root = dump_ui("bio_ui_perm.xml")
allow_node = find_node(root, text="Allow") or find_node(root, desc="Allow") or find_node(root, text="While using the app")
if allow_node:
    cx, cy = center(allow_node.attrib["bounds"])
    print(f"   Granting camera at {cx}, {cy}")
    tap(cx, cy, delay=2.0)
    screenshot("bio_08_camera_granted.png")
else:
    print("   No permission dialog (already granted)")
    screenshot("bio_08_camera_preview.png")

# 9. Give time for camera to initialize
print("9. Waiting for camera preview (5s)...")
time.sleep(5)
screenshot("bio_09_camera_preview.png")

# 10. Start the 3-pose capture
print("10. Performing front capture (0 degrees) - tapping Capture...")
root = dump_ui("bio_ui_camera.xml")
cap_node = find_node(root, text="Capture") or find_node(root, desc="Capture") or find_node(root, text="capture front")
if cap_node:
    cx, cy = center(cap_node.attrib["bounds"])
    tap(cx, cy, delay=3.0)
else:
    # Try center of screen
    tap(540, 1900, delay=3.0)
screenshot("bio_10_front_captured.png")

print("11. Waiting for left angle prompt...")
time.sleep(3)
screenshot("bio_11_left_prompt.png")

root = dump_ui("bio_ui_left.xml")
cap_node = find_node(root, text="Capture") or find_node(root, desc="Capture")
if cap_node:
    cx, cy = center(cap_node.attrib["bounds"])
    tap(cx, cy, delay=3.0)
else:
    tap(540, 1900, delay=3.0)
screenshot("bio_12_left_captured.png")

print("12. Waiting for right angle prompt...")
time.sleep(3)
screenshot("bio_13_right_prompt.png")

root = dump_ui("bio_ui_right.xml")
cap_node = find_node(root, text="Capture") or find_node(root, desc="Capture")
if cap_node:
    cx, cy = center(cap_node.attrib["bounds"])
    tap(cx, cy, delay=3.0)
else:
    tap(540, 1900, delay=3.0)
screenshot("bio_14_right_captured.png")

# 13. Wait for completion
print("13. Waiting for enrollment completion...")
time.sleep(5)
screenshot("bio_15_enrollment_result.png")

print("\n=== DONE ===")
