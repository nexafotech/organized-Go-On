"""
Continue from student dashboard - Navigate to Profile and do biometric enrollment.
All coordinates derived from live UI dump.
Profile tab: [720,2237][1080,2396] → center=(900, 2316)
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

def swipe(x1, y1, x2, y2, dur=300, d=1.0):
    adb(["shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(dur)])
    time.sleep(d)

def sc(name):
    adb(["shell", "screencap", "-p", f"/sdcard/{name}"])
    adb(["pull", f"/sdcard/{name}", os.path.join(OUT, name)])
    print(f"  >> {name}")

def dump_ui(local="__ui.xml"):
    adb(["shell", "uiautomator", "dump", "/sdcard/__ui.xml"])
    adb(["pull", "/sdcard/__ui.xml", os.path.join(OUT, local)])
    root = ET.parse(os.path.join(OUT, local)).getroot()
    return root

def center(bounds):
    nums = list(map(int, re.findall(r"\d+", bounds)))
    return (nums[0]+nums[2])//2, (nums[1]+nums[3])//2

def find_node(root, text=None, desc=None):
    for n in root.iter("node"):
        if text is not None and text.lower() in n.attrib.get("text","").lower():
            return n
        if desc is not None and desc.lower() in n.attrib.get("content-desc","").lower():
            return n
    return None

# ── 1. Navigate to Profile tab ────────────────────────────────────────────────
print("1. Tapping Profile tab...")
# From post-login dump: [720,2237][1080,2396] → (900, 2316)
tap(900, 2316, d=2.0)
sc("d01_profile.png")

# Dump to see profile screen contents
root = dump_ui("d_ui_profile1.xml")
print("   Profile screen nodes:")
for n in root.iter("node"):
    txt = n.attrib.get("text","")
    desc = n.attrib.get("content-desc","")
    if txt or desc:
        print(f"     text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")

# ── 2. Scroll down to find Biometric Enrollment button ─────────────────────────
print("\n2. Scrolling to find Biometric Enrollment...")
bio_node = find_node(root, desc="Face Biometric Enrollment") or find_node(root, desc="Biometric Enrollment") or find_node(root, text="Biometric Enrollment")

if bio_node is None:
    print("   Not in view, scrolling down...")
    swipe(540, 1800, 540, 900, dur=400, d=1.0)
    root = dump_ui("d_ui_profile2.xml")
    bio_node = find_node(root, desc="Face Biometric Enrollment") or find_node(root, desc="Biometric Enrollment") or find_node(root, text="Biometric Enrollment")
    print("   After scroll:")
    for n in root.iter("node"):
        txt = n.attrib.get("text","")
        desc = n.attrib.get("content-desc","")
        if txt or desc:
            print(f"     text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")

if bio_node is None:
    # Try another scroll
    swipe(540, 1800, 540, 900, dur=400, d=1.0)
    root = dump_ui("d_ui_profile3.xml")
    bio_node = find_node(root, desc="Face Biometric Enrollment") or find_node(root, desc="Biometric Enrollment") or find_node(root, text="Biometric Enrollment")

if bio_node is not None:
    bx, by = center(bio_node.attrib["bounds"])
    print(f"   Found Biometric button at {bx},{by}")
    sc("d02_before_tap_bio.png")
    tap(bx, by, d=3.0)
else:
    print("   Still not found. Full dump:")
    for n in root.iter("node"):
        txt = n.attrib.get("text","")
        desc = n.attrib.get("content-desc","")
        if txt or desc:
            print(f"     text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")
    sc("d02_debug.png")
    raise RuntimeError("Biometric button not found!")

sc("d03_enrollment_screen.png")

# ── 3. Check enrollment screen ────────────────────────────────────────────────
print("\n3. Checking enrollment screen...")
time.sleep(2.0)
root = dump_ui("d_ui_enroll.xml")
print("   Enrollment screen:")
for n in root.iter("node"):
    txt = n.attrib.get("text","")
    desc = n.attrib.get("content-desc","")
    if txt or desc:
        print(f"     text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")

# Check for guidelines/start button
start_node = find_node(root, text="Start Enrollment") or find_node(root, desc="Start Enrollment")
if start_node:
    sx, sy = center(start_node.attrib["bounds"])
    print(f"   Tapping Start Enrollment at {sx},{sy}")
    tap(sx, sy, d=3.0)
    sc("d04_after_start.png")
else:
    print("   No Start button - checking camera directly")
    sc("d04_no_start.png")

# ── 4. Camera permission ──────────────────────────────────────────────────────
print("\n4. Checking camera permission...")
time.sleep(2.0)
root = dump_ui("d_ui_perm.xml")
granted = False
for ptext in ["While using the app", "Allow only while using app", "Allow", "Only this time"]:
    pn = find_node(root, text=ptext)
    if pn is not None:
        px, py = center(pn.attrib["bounds"])
        print(f"   Granting permission: {ptext!r} at {px},{py}")
        tap(px, py, d=2.0)
        granted = True
        break
if not granted:
    print("   No permission dialog found (already granted)")

sc("d05_camera.png")

# ── 5. Wait for camera ready ──────────────────────────────────────────────────
print("\n5. Waiting for camera (6s)...")
time.sleep(6.0)
sc("d06_camera_ready.png")

# UI dump to check camera state
root = dump_ui("d_ui_camera.xml")
print("   Camera screen nodes:")
for n in root.iter("node"):
    txt = n.attrib.get("text","")
    desc = n.attrib.get("content-desc","")
    if txt or desc:
        print(f"     text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")

# ── 6. Capture - Front pose ───────────────────────────────────────────────────
print("\n6. Capturing front pose (0 degrees)...")
cap_node = find_node(root, text="Capture") or find_node(root, desc="Capture") or find_node(root, desc="capture")
if cap_node is not None:
    cx, cy = center(cap_node.attrib["bounds"])
    print(f"   Capture button at {cx},{cy}")
    tap(cx, cy, d=4.0)
else:
    print("   Capture button not found, tapping center-bottom area...")
    tap(540, 1950, d=4.0)
sc("d07_front_captured.png")

# ── 7. Capture - Left pose ────────────────────────────────────────────────────
print("\n7. Capturing left pose (-15 degrees)...")
time.sleep(2.0)
root = dump_ui("d_ui_left.xml")
for n in root.iter("node"):
    txt = n.attrib.get("text","")
    desc = n.attrib.get("content-desc","")
    if txt or desc:
        print(f"     text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")
cap_node = find_node(root, text="Capture") or find_node(root, desc="Capture")
if cap_node is not None:
    cx, cy = center(cap_node.attrib["bounds"])
    tap(cx, cy, d=4.0)
else:
    tap(540, 1950, d=4.0)
sc("d08_left_captured.png")

# ── 8. Capture - Right pose ───────────────────────────────────────────────────
print("\n8. Capturing right pose (+15 degrees)...")
time.sleep(2.0)
root = dump_ui("d_ui_right.xml")
for n in root.iter("node"):
    txt = n.attrib.get("text","")
    desc = n.attrib.get("content-desc","")
    if txt or desc:
        print(f"     text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")
cap_node = find_node(root, text="Capture") or find_node(root, desc="Capture")
if cap_node is not None:
    cx, cy = center(cap_node.attrib["bounds"])
    tap(cx, cy, d=4.0)
else:
    tap(540, 1950, d=4.0)
sc("d09_right_captured.png")

# ── 9. Wait for enrollment result ─────────────────────────────────────────────
print("\n9. Waiting for enrollment processing (10s)...")
time.sleep(10.0)
sc("d10_result.png")

root = dump_ui("d_ui_result.xml")
print("   Final result screen:")
for n in root.iter("node"):
    txt = n.attrib.get("text","")
    desc = n.attrib.get("content-desc","")
    if txt or desc:
        print(f"     text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")

print("\n=== BIOMETRIC ENROLLMENT COMPLETE ===")
