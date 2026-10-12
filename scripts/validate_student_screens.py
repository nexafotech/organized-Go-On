import subprocess, time, os, re, xml.etree.ElementTree as ET

ADB = r"C:\Users\Abishek\AppData\Local\Android\Sdk\platform-tools\adb.exe"
SERIAL = "FY6PHIEA69AMQ8HU"
OUT_DIR = r"C:\Users\Abishek\Desktop\am-oss\android_phase7_6_screens"
os.makedirs(OUT_DIR, exist_ok=True)

def adb(args):
    return subprocess.run([ADB, "-s", SERIAL] + args, capture_output=True, text=True)

def tap(x, y, d=0.8):
    print(f"Tapping ({x}, {y})...")
    adb(["shell", "input", "tap", str(x), str(y)])
    time.sleep(d)

def swipe(x1, y1, x2, y2, duration=300, d=0.8):
    print(f"Swiping from ({x1}, {y1}) to ({x2}, {y2})...")
    adb(["shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(duration)])
    time.sleep(d)

def capture(name):
    path_sd = f"/sdcard/{name}.png"
    path_local = os.path.join(OUT_DIR, f"{name}.png")
    adb(["shell", "screencap", "-p", path_sd])
    adb(["pull", path_sd, path_local])
    print(f"Saved screenshot: {path_local}")
    return path_local

def dump_ui(name="ui_dump"):
    tmp_xml = os.path.join(OUT_DIR, f"{name}.xml")
    adb(["shell", "uiautomator", "dump", f"/sdcard/{name}.xml"])
    adb(["pull", f"/sdcard/{name}.xml", tmp_xml])
    return ET.parse(tmp_xml).getroot()

def center(bounds):
    nums = list(map(int, re.findall(r"\d+", bounds)))
    return (nums[0]+nums[2])//2, (nums[1]+nums[3])//2

def find_nodes_by_text_or_desc(root, pattern):
    results = []
    p = re.compile(pattern, re.IGNORECASE)
    for n in root.iter("node"):
        text = n.attrib.get("text", "")
        desc = n.attrib.get("content-desc", "")
        if p.search(text) or p.search(desc):
            results.append(n)
    return results

print("=== STARTING STUDENT UI VALIDATION ===")

# 1. Capture current Student Dashboard Top
capture("step7_01_student_dashboard_top")

# Scroll down on Dashboard to see remainder of Dashboard
swipe(540, 1800, 540, 600, duration=400, d=1.0)
capture("step7_02_student_dashboard_bottom")

# Scroll back up to top
swipe(540, 600, 540, 1800, duration=400, d=1.0)

# Dump UI to find navigation items
root = dump_ui("dashboard_ui")
nav_nodes = find_nodes_by_text_or_desc(root, "Attendance|Timetable|Profile|Dashboard")
print("Found navigation nodes:")
for n in nav_nodes:
    print(f"  {n.attrib.get('text') or n.attrib.get('content-desc')} -> {n.attrib.get('bounds')}")

# 2. Navigate to Attendance tab
att_nodes = find_nodes_by_text_or_desc(root, "Attendance")
if att_nodes:
    bx, by = center(att_nodes[0].attrib["bounds"])
    tap(bx, by, d=1.5)
else:
    # default attendance tab position in 4-item bar (approx x=375, y=2280)
    tap(375, 2280, d=1.5)

capture("step7_03_student_attendance_tab_top")

# Scroll down on Attendance tab
swipe(540, 1800, 540, 600, duration=400, d=1.0)
capture("step7_04_student_attendance_tab_scrolled")

# Dump Attendance UI to find clickable cards/dates for detail sheets
att_root = dump_ui("attendance_ui")
# Look for a subject or date item
subj_nodes = [n for n in att_root.iter("node") if n.attrib.get("clickable") == "true" and "Attendance" not in n.attrib.get("content-desc","")]
if subj_nodes:
    # tap first clickable card
    sx, sy = center(subj_nodes[0].attrib["bounds"])
    print(f"Tapping subject/date card at {sx},{sy}...")
    tap(sx, sy, d=1.5)
    capture("step7_05_student_detail_sheet")
    # dismiss sheet by tapping top scrim or pressing back
    adb(["shell", "input", "keyevent", "4"])
    time.sleep(0.8)

# 3. Navigate to Timetable tab
tap(640, 2280, d=1.5) # approx 3rd tab (Timetable)
capture("step7_06_student_timetable_tab")

# Dump timetable UI to inspect day chips
tt_root = dump_ui("timetable_ui")
chips = find_nodes_by_text_or_desc(tt_root, "Mon|Tue|Wed|Thu|Fri|Sat")
print(f"Found {len(chips)} day chips")
if len(chips) >= 2:
    cx, cy = center(chips[1].attrib["bounds"])
    print(f"Tapping day chip {chips[1].attrib.get('text') or chips[1].attrib.get('content-desc')} at {cx},{cy}")
    tap(cx, cy, d=1.0)
    capture("step7_07_student_timetable_day_selected")

# Scroll down on timetable
swipe(540, 1800, 540, 800, duration=400, d=1.0)
capture("step7_08_student_timetable_scrolled")

# 4. Navigate to Profile tab
tap(920, 2280, d=1.5) # approx 4th tab (Profile)
capture("step7_09_student_profile_tab")

# Dump Profile UI
prof_root = dump_ui("profile_ui")
# Look for Change Password button
pw_btn = find_nodes_by_text_or_desc(prof_root, "Change Password|Password")
if pw_btn:
    px, py = center(pw_btn[0].attrib["bounds"])
    print(f"Tapping Change Password at {px},{py}")
    tap(px, py, d=1.2)
    capture("step7_10_change_password_dialog")
    # dismiss dialog by pressing back or cancel
    adb(["shell", "input", "keyevent", "4"])
    time.sleep(0.8)

# Check Biometric enrollment button if visible
bio_btn = find_nodes_by_text_or_desc(prof_root, "Biometric|Face Enrollment|Enroll")
if bio_btn:
    bx, by = center(bio_btn[0].attrib["bounds"])
    print(f"Tapping Biometric Enrollment at {bx},{by}")
    tap(bx, by, d=1.5)
    capture("step7_11_biometric_enrollment_screen")
    # back out to profile
    adb(["shell", "input", "keyevent", "4"])
    time.sleep(0.8)

# Look for Sign Out button
signout_btn = find_nodes_by_text_or_desc(prof_root, "Sign Out|Logout")
if signout_btn:
    so_x, so_y = center(signout_btn[0].attrib["bounds"])
    print(f"Tapping Sign Out button at {so_x},{so_y}")
    tap(so_x, so_y, d=1.2)
    capture("step7_12_signout_dialog")
    # dismiss dialog with Cancel so we don't accidentally sign out before verifying everything
    adb(["shell", "input", "keyevent", "4"])
    time.sleep(0.8)

print("=== COMPLETED STUDENT UI NAVIGATION PASS ===")
