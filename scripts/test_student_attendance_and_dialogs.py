import subprocess, time, os, re, xml.etree.ElementTree as ET

ADB = r"C:\Users\Abishek\AppData\Local\Android\Sdk\platform-tools\adb.exe"
SERIAL = "FY6PHIEA69AMQ8HU"
OUT_DIR = r"C:\Users\Abishek\Desktop\am-oss\android_phase7_6_screens"

def adb(args):
    return subprocess.run([ADB, "-s", SERIAL] + args, capture_output=True, text=True)

def tap(x, y, d=0.8):
    print(f"Tapping ({x}, {y})...")
    adb(["shell", "input", "tap", str(x), str(y)])
    time.sleep(d)

def swipe(x1, y1, x2, y2, duration=350, d=0.8):
    print(f"Swiping from ({x1}, {y1}) to ({x2}, {y2})...")
    adb(["shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(duration)])
    time.sleep(d)

def capture(name):
    path_sd = f"/sdcard/{name}.png"
    path_local = os.path.join(OUT_DIR, f"{name}.png")
    adb(["shell", "screencap", "-p", path_sd])
    adb(["pull", path_sd, path_local])
    print(f"Saved: {path_local}")
    return path_local

def dump_ui(name="temp_dump"):
    tmp_xml = os.path.join(OUT_DIR, f"{name}.xml")
    adb(["shell", "uiautomator", "dump", f"/sdcard/{name}.xml"])
    adb(["pull", f"/sdcard/{name}.xml", tmp_xml])
    return ET.parse(tmp_xml).getroot()

# First dismiss the Sign Out dialog if still open
adb(["shell", "input", "keyevent", "4"])
time.sleep(0.5)

# 1. Tap Attendance Tab (center: x=405, y=2316)
print("Switching to Attendance tab (x=405, y=2316)...")
tap(405, 2316, d=1.5)
capture("step7_13_attendance_tab_real_top")

# Scroll Attendance Tab
swipe(540, 1800, 540, 800, duration=400, d=1.0)
capture("step7_14_attendance_tab_real_scrolled")

# Dump UI to find a clickable subject card
root = dump_ui("attendance_real")
clickables = [n for n in root.iter("node") if n.attrib.get("clickable") == "true" and int(re.findall(r"\d+", n.attrib.get("bounds","[0,0][0,0]"))[1]) < 2100 and int(re.findall(r"\d+", n.attrib.get("bounds","[0,0][0,0]"))[1]) > 300]
print(f"Found {len(clickables)} clickable items in attendance view")
if clickables:
    b = list(map(int, re.findall(r"\d+", clickables[0].attrib["bounds"])))
    cx, cy = (b[0]+b[2])//2, (b[1]+b[3])//2
    print(f"Tapping attendance item at {cx}, {cy}...")
    tap(cx, cy, d=1.2)
    capture("step7_15_attendance_detail_bottom_sheet")
    # Dismiss sheet
    adb(["shell", "input", "keyevent", "4"])
    time.sleep(0.6)

# 2. Switch back to Profile tab (x=945, y=2316)
print("Switching back to Profile tab...")
tap(945, 2316, d=1.2)

# Scroll down on Profile tab to see action buttons
swipe(540, 1800, 540, 700, duration=400, d=1.0)
capture("step7_16_profile_scrolled_actions")

# Dump UI to find Change Password and Biometric buttons
prof_root = dump_ui("profile_scrolled_ui")
pw_nodes = [n for n in prof_root.iter("node") if "password" in (n.attrib.get("text","") + n.attrib.get("content-desc","")).lower()]
if pw_nodes:
    b = list(map(int, re.findall(r"\d+", pw_nodes[0].attrib["bounds"])))
    cx, cy = (b[0]+b[2])//2, (b[1]+b[3])//2
    print(f"Tapping Change Password button at {cx}, {cy}...")
    tap(cx, cy, d=1.2)
    capture("step7_17_change_password_dialog_open")
    # Dismiss dialog
    adb(["shell", "input", "keyevent", "4"])
    time.sleep(0.6)

bio_nodes = [n for n in prof_root.iter("node") if any(k in (n.attrib.get("text","") + n.attrib.get("content-desc","")).lower() for k in ["biometric", "face", "enroll"])]
if bio_nodes:
    b = list(map(int, re.findall(r"\d+", bio_nodes[0].attrib["bounds"])))
    cx, cy = (b[0]+b[2])//2, (b[1]+b[3])//2
    print(f"Tapping Biometric Enrollment button at {cx}, {cy}...")
    tap(cx, cy, d=1.5)
    capture("step7_18_biometric_enrollment_screen")
    adb(["shell", "input", "keyevent", "4"])
    time.sleep(0.6)

print("Done attendance and dialogs inspection!")
