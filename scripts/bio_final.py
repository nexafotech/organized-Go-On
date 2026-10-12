"""
Final biometric enrollment attempt.
App is currently on Biometric Face Enrollment guidelines screen.
Start Enrollment button: bounds=[168,1897][912,2041] -> center=(540, 1969)
"""
import subprocess, time, xml.etree.ElementTree as ET, re, os

ADB = r"C:\Users\Abishek\AppData\Local\Android\Sdk\platform-tools\adb.exe"
SERIAL = "FY6PHIEA69AMQ8HU"
OUT = r"C:\Users\Abishek\.gemini\antigravity\brain\7f90dbc7-1f76-43d0-a6a4-acccb732defd"

def adb(args):
    return subprocess.run([ADB, "-s", SERIAL] + args, capture_output=True, text=True)

def tap(x, y, d=1.0):
    adb(["shell", "input", "tap", str(x), str(y)])
    time.sleep(d)

def sc(name):
    adb(["shell", "screencap", "-p", f"/sdcard/{name}"])
    adb(["pull", f"/sdcard/{name}", os.path.join(OUT, name)])
    print(f"  >> {name}")

def dump_and_print(local="__ui.xml"):
    adb(["shell", "uiautomator", "dump", "/sdcard/__ui.xml"])
    adb(["pull", "/sdcard/__ui.xml", os.path.join(OUT, local)])
    root = ET.parse(os.path.join(OUT, local)).getroot()
    for n in root.iter("node"):
        txt = n.attrib.get("text","")
        desc = n.attrib.get("content-desc","")
        cls = n.attrib.get("class","")
        if txt or desc or "Button" in cls:
            print(f"  cls={cls!r} text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")
    return root

def center_from_bounds(bounds_str):
    nums = list(map(int, re.findall(r"\d+", bounds_str)))
    return (nums[0]+nums[2])//2, (nums[1]+nums[3])//2

# ── Verify current state ─────────────────────────────────────────────────────
print("Current state:")
sc("f01_current.png")
root = dump_and_print("f_ui_current.xml")

# Find Start Enrollment button by exact content-desc
start_x, start_y = 540, 1969  # known from last dump: [168,1897][912,2041]
for n in root.iter("node"):
    desc = n.attrib.get("content-desc","")
    if desc == "Start Enrollment":
        sx, sy = center_from_bounds(n.attrib["bounds"])
        print(f"Start Enrollment EXACT at {sx},{sy} bounds={n.attrib['bounds']}")
        start_x, start_y = sx, sy
        break

print(f"\nTapping Start Enrollment at {start_x},{start_y}...")
tap(start_x, start_y, d=4.0)
sc("f02_after_start.png")

print("Checking for camera permission...")
time.sleep(2.0)
root2 = dump_and_print("f_ui_perm.xml")

# Grant camera permission if needed
for ptext in ["While using the app", "Allow only while using app", "Allow", "Only this time"]:
    for n in root2.iter("node"):
        txt = n.attrib.get("text","")
        desc = n.attrib.get("content-desc","")
        if ptext.lower() in txt.lower() or ptext.lower() in desc.lower():
            px, py = center_from_bounds(n.attrib["bounds"])
            print(f"  Granting: {ptext!r} at {px},{py}")
            tap(px, py, d=2.0)
            break

sc("f03_post_perm.png")

print("\nWaiting 8s for camera to open and stabilize...")
time.sleep(8.0)
sc("f04_camera.png")

root3 = dump_and_print("f_ui_camera.xml")

# Look for capture button (NOT 'Capture Guidelines')
# The real capture button on the camera screen will have desc containing "capture" but NOT "guidelines"
cap_x, cap_y = 540, 1950  # fallback
for n in root3.iter("node"):
    desc = n.attrib.get("content-desc","").lower()
    txt = n.attrib.get("text","").lower()
    bounds = n.attrib.get("bounds","")
    if ("capture" in desc or "capture" in txt) and "guideline" not in desc:
        cx, cy = center_from_bounds(bounds)
        print(f"  FOUND capture at {cx},{cy} desc={n.attrib.get('content-desc','')} bounds={bounds}")
        cap_x, cap_y = cx, cy
        break

print(f"\nCapturing FRONT (0 deg) at {cap_x},{cap_y}...")
tap(cap_x, cap_y, d=5.0)
sc("f05_front.png")

print("Waiting for LEFT pose prompt (3s)...")
time.sleep(3.0)
root4 = dump_and_print("f_ui_left.xml")
sc("f06_left_prompt.png")

cap_x, cap_y = 540, 1950
for n in root4.iter("node"):
    desc = n.attrib.get("content-desc","").lower()
    txt = n.attrib.get("text","").lower()
    bounds = n.attrib.get("bounds","")
    if ("capture" in desc or "capture" in txt) and "guideline" not in desc:
        cx, cy = center_from_bounds(bounds)
        cap_x, cap_y = cx, cy
        break

print(f"Capturing LEFT at {cap_x},{cap_y}...")
tap(cap_x, cap_y, d=5.0)
sc("f07_left.png")

print("Waiting for RIGHT pose prompt (3s)...")
time.sleep(3.0)
root5 = dump_and_print("f_ui_right.xml")
sc("f08_right_prompt.png")

cap_x, cap_y = 540, 1950
for n in root5.iter("node"):
    desc = n.attrib.get("content-desc","").lower()
    txt = n.attrib.get("text","").lower()
    bounds = n.attrib.get("bounds","")
    if ("capture" in desc or "capture" in txt) and "guideline" not in desc:
        cx, cy = center_from_bounds(bounds)
        cap_x, cap_y = cx, cy
        break

print(f"Capturing RIGHT at {cap_x},{cap_y}...")
tap(cap_x, cap_y, d=5.0)
sc("f09_right.png")

print("\nWaiting for enrollment processing (12s)...")
time.sleep(12.0)
sc("f10_final.png")
print("Final screen:")
dump_and_print("f_ui_final.xml")

print("\n=== DONE ===")
