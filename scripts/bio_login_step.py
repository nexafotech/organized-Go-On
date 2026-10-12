"""
Biometric enrollment - Step 1 only: get a clean STUDENT login.
Uses exact coordinates from UI dump.
STUDENT tab bounds from dump: [63,803][540,929] → center=(301, 866)
Student username EditText (after STUDENT tab click) at [60,1044][1020,1212] → center=(540, 1128)
Student password at [60,1248][1020,1476] → center=(540, 1362)
Student Sign In at [60,1524][1020,1668] → center=(540, 1596)
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
print(f"Password found (length {len(pw)})")

def adb(args):
    return subprocess.run([ADB, "-s", SERIAL] + args, capture_output=True, text=True)

def tap(x, y, d=1.0):
    adb(["shell", "input", "tap", str(x), str(y)])
    time.sleep(d)

def keyevent(k, d=0.3):
    adb(["shell", "input", "keyevent", str(k)])
    time.sleep(d)

def sc(name):
    adb(["shell", "screencap", "-p", f"/sdcard/{name}"])
    adb(["pull", f"/sdcard/{name}", os.path.join(OUT, name)])
    print(f"  >> {name}")

def dump_ui(local="__ui.xml"):
    adb(["shell", "uiautomator", "dump", "/sdcard/__ui.xml"])
    adb(["pull", "/sdcard/__ui.xml", os.path.join(OUT, local)])
    tree = ET.parse(os.path.join(OUT, local))
    root = tree.getroot()
    # print all text/desc nodes
    for n in root.iter("node"):
        txt = n.attrib.get("text","")
        desc = n.attrib.get("content-desc","")
        cls = n.attrib.get("class","")
        if txt or desc or "EditText" in cls:
            print(f"  cls={cls!r} text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")
    return root

def escape_for_adb(text):
    """Escape special shell characters for adb input text."""
    result = []
    for c in text:
        if c == ' ':
            result.append('%s')
        elif c in '&\\#^$()%@!"\'<>|;`~*?[]{}=+,-./':
            result.append(f'\\{c}')
        else:
            result.append(c)
    return ''.join(result)

# ── 1. Force-stop then launch ────────────────────────────────────────────────────
print("\n1. Launching app fresh...")
adb(["shell", "am", "force-stop", "com.aifaceattendance.mobile_app"])
time.sleep(1.5)
adb(["shell", "am", "start", "-n",
     "com.aifaceattendance.mobile_app/com.aifaceattendance.mobile_app.MainActivity"])
time.sleep(5.0)   # wait for full login screen render
sc("c01_login.png")

# ── 2. Dump UI to find exact login screen tab coordinates ─────────────────────
print("\n2. Dumping UI for exact coordinates...")
root = dump_ui("c_ui_login.xml")

# ── 3. Tap STUDENT tab ────────────────────────────────────────────────────────
print("\n3. Tapping STUDENT tab...")
# From the dump, STUDENT tab was at [63,803][540,929]  (center= 301, 866)
# But after fresh start it may be at slightly different Y - use content-desc match
student_x, student_y = 301, 866  # default

for n in root.iter("node"):
    desc = n.attrib.get("content-desc","")
    if "STUDENT" in desc:
        bounds = n.attrib["bounds"]
        nums = list(map(int, re.findall(r"\d+", bounds)))
        student_x = (nums[0]+nums[2])//2
        student_y = (nums[1]+nums[3])//2
        print(f"  STUDENT tab found at bounds={bounds} center=({student_x},{student_y})")
        break

tap(student_x, student_y, d=1.5)
sc("c02_student_tab.png")

# ── 4. Dump UI again to get post-tab-switch field coordinates ─────────────────
print("\n4. Dumping UI after STUDENT tab click...")
root = dump_ui("c_ui_student.xml")

# Find the EditText fields
edit_fields = [n for n in root.iter("node") if "EditText" in n.attrib.get("class","")]
print(f"  EditText nodes found: {len(edit_fields)}")
for i, n in enumerate(edit_fields):
    print(f"  [{i}] bounds={n.attrib.get('bounds','')} text={n.attrib.get('text','')!r}")

# ── 5. Fill username field (first EditText) ────────────────────────────────────
print("\n5. Filling username field...")
if len(edit_fields) >= 1:
    bounds = edit_fields[0].attrib["bounds"]
    nums = list(map(int, re.findall(r"\d+", bounds)))
    ux, uy = (nums[0]+nums[2])//2, (nums[1]+nums[3])//2
    print(f"  Tapping username at {ux},{uy}")
    tap(ux, uy, d=0.5)
else:
    tap(540, 1128, d=0.5)

# Clear existing text
for _ in range(20):
    adb(["shell", "input", "keyevent", "67"])
time.sleep(0.1)
# Select all + delete
adb(["shell", "input", "keyevent", "29"])  # CTRL+A
time.sleep(0.1)
adb(["shell", "input", "keyevent", "67"])  # backspace
time.sleep(0.1)
# Type username
adb(["shell", "input", "text", "721025149001"])
time.sleep(0.5)
sc("c03_username_typed.png")

# ── 6. Tap password field (second EditText) ────────────────────────────────────
print("\n6. Tapping password field...")
if len(edit_fields) >= 2:
    bounds = edit_fields[1].attrib["bounds"]
    nums = list(map(int, re.findall(r"\d+", bounds)))
    px, py = (nums[0]+nums[2])//2, (nums[1]+nums[3])//2
    print(f"  Tapping password at {px},{py}")
    tap(px, py, d=0.5)
else:
    tap(540, 1362, d=0.5)

for _ in range(30):
    adb(["shell", "input", "keyevent", "67"])
time.sleep(0.1)

# Type password
escaped_pw = escape_for_adb(pw)
print(f"  Typing password (length {len(pw)})...")
adb(["shell", "input", "text", escaped_pw])
time.sleep(0.5)
sc("c04_pw_typed.png")

# ── 7. Find and tap Sign In button ─────────────────────────────────────────────
print("\n7. Looking for Student Sign In button...")
# Re-dump to get sign in button (keyboard might shift it)
# First hide keyboard
keyevent(111, d=0.5)  # ESCAPE dismisses keyboard without going back in Flutter

root2 = dump_ui("c_ui_prefill.xml")
sc("c05_before_signin.png")

# find Student Sign In button
signin_x, signin_y = 540, 1596
for n in root2.iter("node"):
    desc = n.attrib.get("content-desc","")
    txt = n.attrib.get("text","")
    if "Sign In" in desc or "Sign In" in txt:
        bounds = n.attrib["bounds"]
        nums = list(map(int, re.findall(r"\d+", bounds)))
        signin_x = (nums[0]+nums[2])//2
        signin_y = (nums[1]+nums[3])//2
        print(f"  Sign In at {signin_x},{signin_y}")
        break

tap(signin_x, signin_y, d=6.0)
sc("c06_post_signin.png")

print("\n=== LOGIN STEP DONE ===")
print("Dumping post-login UI:")
root3 = dump_ui("c_ui_post.xml")
