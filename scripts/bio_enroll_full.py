"""
Full biometric enrollment flow - clean restart.
Properly logs in on STUDENT tab, navigates to Profile, taps enrollment.
"""
import subprocess, time, openpyxl, xml.etree.ElementTree as ET, re, os, sys

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
print(f"Password found (length {len(pw)})")

def adb(args, check=False):
    return subprocess.run([ADB, "-s", SERIAL] + args, capture_output=True, text=True)

def tap(x, y, d=1.0):
    adb(["shell", "input", "tap", str(x), str(y)])
    time.sleep(d)

def keyevent(k, d=0.4):
    adb(["shell", "input", "keyevent", str(k)])
    time.sleep(d)

def swipe(x1, y1, x2, y2, dur=300, d=1.0):
    adb(["shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(dur)])
    time.sleep(d)

def sc(name):
    adb(["shell", "screencap", "-p", f"/sdcard/{name}"])
    adb(["pull", f"/sdcard/{name}", os.path.join(OUT, name)])
    print(f"  >> {name}")

def ui_dump(local="__ui.xml"):
    adb(["shell", "uiautomator", "dump", "/sdcard/__ui.xml"])
    adb(["pull", "/sdcard/__ui.xml", os.path.join(OUT, local)])
    return ET.parse(os.path.join(OUT, local)).getroot()

def find(root, **kw):
    for n in root.iter("node"):
        ok = True
        for k, v in kw.items():
            if v.lower() not in n.attrib.get(k, "").lower():
                ok = False; break
        if ok:
            return n
    return None

def center(bounds):
    nums = list(map(int, re.findall(r"\d+", bounds)))
    return (nums[0]+nums[2])//2, (nums[1]+nums[3])//2

def escape_for_adb(text):
    result = []
    for c in text:
        if c == ' ':
            result.append('%s')
        elif c in '&\\#^$()%@!"\'<>|;`~':
            result.append(f'\\{c}')
        else:
            result.append(c)
    return ''.join(result)

# ── 1. Force-stop, close app drawer if open ────────────────────────────────────
print("1. Launching app fresh...")
adb(["shell", "am", "force-stop", "com.aifaceattendance.mobile_app"])
time.sleep(1.0)
# Press HOME to dismiss any overlay
keyevent(3, d=0.5)   # HOME
time.sleep(0.3)
# Start app
adb(["shell", "am", "start", "-n",
     "com.aifaceattendance.mobile_app/com.aifaceattendance.mobile_app.MainActivity"])
time.sleep(4.0)
sc("b01_launch.png")

# ── 2. Tap STUDENT tab ──────────────────────────────────────────────────────────
print("2. Switching to STUDENT tab...")
root = ui_dump("b_ui_login.xml")
# find STUDENT tab
student_tab = find(root, **{"content-desc": "STUDENT"}) or find(root, text="STUDENT")
if student_tab:
    x, y = center(student_tab.attrib["bounds"])
    print(f"   STUDENT tab at {x},{y}")
    tap(x, y, d=0.5)
else:
    tap(200, 745, d=0.5)  # fallback from earlier dump

# ── 3. Fill username ────────────────────────────────────────────────────────────
print("3. Filling username...")
root = ui_dump("b_ui_student.xml")
uname = None
for n in root.iter("node"):
    if "EditText" in n.attrib.get("class", ""):
        uname = n
        break
if uname:
    x, y = center(uname.attrib["bounds"])
    tap(x, y, d=0.5)
else:
    tap(540, 931, d=0.5)

for _ in range(20):
    keyevent(67, d=0.02)   # backspace x20
adb(["shell", "input", "text", "721025149001"])
time.sleep(0.3)
sc("b02_username.png")

# ── 4. TAB to password field ────────────────────────────────────────────────────
print("4. Filling password...")
keyevent(61, d=0.3)   # TAB
for _ in range(30):
    keyevent(67, d=0.01)  # backspace x30

escaped_pw = escape_for_adb(pw)
print(f"   Escaped password: {'*' * len(pw)}")
adb(["shell", "input", "text", escaped_pw])
time.sleep(0.3)
sc("b03_pw_entered.png")

# ── 5. Hide keyboard and Sign In ────────────────────────────────────────────────
print("5. Hiding keyboard with ESCAPE and signing in...")
keyevent(111, d=0.5)   # ESCAPE to hide keyboard without going back
# Dump to find sign-in button
root = ui_dump("b_ui_prefill.xml")
sc("b04_prefill.png")

signin = find(root, **{"content-desc": "Student Sign In"}) or find(root, text="Sign In")
if signin:
    x, y = center(signin.attrib["bounds"])
    print(f"   Sign In button at {x},{y}")
    tap(x, y, d=5.0)
else:
    # Try tap at known Sign In button area
    tap(540, 1520, d=5.0)

sc("b05_post_login.png")

# Check if we landed on dashboard
root = ui_dump("b_ui_dash.xml")
print("   Post-login UI nodes (text/desc):")
for n in root.iter("node"):
    txt = n.attrib.get("text", "")
    desc = n.attrib.get("content-desc", "")
    if txt or desc:
        print(f"     {txt!r} / {desc!r}")

# ── 6. Navigate to Profile ──────────────────────────────────────────────────────
print("6. Navigating to Profile...")
profile_tab = find(root, **{"content-desc": "Profile"})
if profile_tab:
    x, y = center(profile_tab.attrib["bounds"])
    tap(x, y, d=2.0)
else:
    tap(833, 2300, d=2.0)
sc("b06_profile.png")

# ── 7. Find and tap Biometric Enrollment ────────────────────────────────────────
print("7. Looking for Biometric Enrollment button...")
root = ui_dump("b_ui_profile.xml")
bio = (find(root, **{"content-desc": "Face Biometric Enrollment"}) or
       find(root, **{"content-desc": "Biometric Enrollment"}) or
       find(root, text="Biometric Enrollment") or
       find(root, text="Face Biometric"))
if bio:
    x, y = center(bio.attrib["bounds"])
    print(f"   Found at {x},{y}")
    tap(x, y, d=3.0)
else:
    # scroll down and try again
    print("   Not visible, scrolling...")
    swipe(540, 1800, 540, 800, d=1.0)
    root = ui_dump("b_ui_profile2.xml")
    bio = (find(root, **{"content-desc": "Face Biometric Enrollment"}) or
           find(root, **{"content-desc": "Biometric Enrollment"}) or
           find(root, text="Biometric Enrollment") or
           find(root, text="Face Biometric"))
    if bio:
        x, y = center(bio.attrib["bounds"])
        print(f"   Found at {x},{y}")
        tap(x, y, d=3.0)
    else:
        print("   Still not found, dumping all text nodes:")
        for n in root.iter("node"):
            txt = n.attrib.get("text","")
            desc = n.attrib.get("content-desc","")
            if txt or desc:
                print(f"     {txt!r} / {desc!r} bounds={n.attrib.get('bounds','')}")
        sc("b07_profile_debug.png")
        sys.exit(1)

sc("b07_enrollment_page.png")

# ── 8. Check for guidelines or camera ───────────────────────────────────────────
print("8. Checking enrollment screen...")
time.sleep(2)
root = ui_dump("b_ui_enroll.xml")
print("   Enrollment screen nodes:")
for n in root.iter("node"):
    txt = n.attrib.get("text","")
    desc = n.attrib.get("content-desc","")
    cls = n.attrib.get("class","")
    bounds = n.attrib.get("bounds","")
    if txt or desc:
        print(f"     cls={cls!r} text={txt!r} desc={desc!r} bounds={bounds}")

# Check for Start Enrollment button
start_btn = find(root, text="Start Enrollment") or find(root, **{"content-desc": "Start Enrollment"})
if start_btn:
    x, y = center(start_btn.attrib["bounds"])
    print(f"   Tapping Start Enrollment at {x},{y}")
    tap(x, y, d=3.0)
    sc("b08_after_start.png")
else:
    print("   No Start Enrollment button visible - may be on camera already")
    sc("b08_camera_direct.png")

# Camera permission grant
print("9. Checking camera permission...")
time.sleep(1.5)
root = ui_dump("b_ui_perm.xml")
for perm_text in ["Allow", "While using the app", "Only this time"]:
    perm = find(root, text=perm_text)
    if perm:
        x, y = center(perm.attrib["bounds"])
        print(f"   Granting: {perm_text} at {x},{y}")
        tap(x, y, d=2.0)
        break
else:
    print("   No permission dialog (already granted)")

sc("b09_camera.png")

# Wait for camera
print("10. Camera preview (5s)...")
time.sleep(5)
sc("b10_camera_preview.png")

# Capture button
print("11. Capturing front pose...")
root = ui_dump("b_ui_cap1.xml")
cap = find(root, text="Capture") or find(root, **{"content-desc": "Capture"})
if cap:
    x, y = center(cap.attrib["bounds"])
    tap(x, y, d=4.0)
else:
    tap(540, 1900, d=4.0)
sc("b11_front_captured.png")

print("12. Capturing left pose...")
time.sleep(2)
root = ui_dump("b_ui_cap2.xml")
cap = find(root, text="Capture") or find(root, **{"content-desc": "Capture"})
if cap:
    x, y = center(cap.attrib["bounds"])
    tap(x, y, d=4.0)
else:
    tap(540, 1900, d=4.0)
sc("b12_left_captured.png")

print("13. Capturing right pose...")
time.sleep(2)
root = ui_dump("b_ui_cap3.xml")
cap = find(root, text="Capture") or find(root, **{"content-desc": "Capture"})
if cap:
    x, y = center(cap.attrib["bounds"])
    tap(x, y, d=4.0)
else:
    tap(540, 1900, d=4.0)
sc("b13_right_captured.png")

print("14. Waiting for enrollment result (8s)...")
time.sleep(8)
sc("b14_result.png")

# Final state dump
root = ui_dump("b_ui_result.xml")
print("   Final screen nodes:")
for n in root.iter("node"):
    txt = n.attrib.get("text","")
    desc = n.attrib.get("content-desc","")
    if txt or desc:
        print(f"     {txt!r} / {desc!r}")

print("\n=== BIOMETRIC ENROLLMENT COMPLETE ===")
