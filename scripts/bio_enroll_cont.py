"""
Biometric enrollment from the ALREADY SCROLLED profile page.
Biometric Face Enrollment is visible at [144,1578][936,1722] → center=(540, 1650)
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

def dump_ui(local="__ui.xml"):
    adb(["shell", "uiautomator", "dump", "/sdcard/__ui.xml"])
    adb(["pull", "/sdcard/__ui.xml", os.path.join(OUT, local)])
    root = ET.parse(os.path.join(OUT, local)).getroot()
    return root

def center(bounds):
    nums = list(map(int, re.findall(r"\d+", bounds)))
    return (nums[0]+nums[2])//2, (nums[1]+nums[3])//2

def find_node_any(root, *keywords):
    """Find a node whose content-desc or text contains any of the keywords (case insensitive)."""
    for n in root.iter("node"):
        desc = n.attrib.get("content-desc","").lower()
        text = n.attrib.get("text","").lower()
        for kw in keywords:
            if kw.lower() in desc or kw.lower() in text:
                return n
    return None

# ── Check current screen ─────────────────────────────────────────────────────
print("Checking current screen state...")
root = dump_ui("e_ui_current.xml")
for n in root.iter("node"):
    txt = n.attrib.get("text","")
    desc = n.attrib.get("content-desc","")
    if txt or desc:
        print(f"  text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")

# ── Tap Biometric Face Enrollment button ────────────────────────────────────
print("\nLooking for Biometric button...")
bio = find_node_any(root, "Biometric Face", "Face Enrollment", "biometric")
if bio is not None:
    bx, by = center(bio.attrib["bounds"])
    print(f"  Found at {bx},{by} desc={bio.attrib.get('content-desc','')!r}")
    sc("e01_before_tap.png")
    tap(bx, by, d=4.0)
else:
    # Use hardcoded coordinate from dump
    print("  Not in current view; using hardcoded coordinate from last known position...")
    sc("e01_fallback.png")
    tap(540, 1650, d=4.0)  # from [144,1578][936,1722]

sc("e02_enrollment_screen.png")

# ── Check enrollment screen ────────────────────────────────────────────────
print("\nChecking enrollment screen (3s wait)...")
time.sleep(3.0)
root = dump_ui("e_ui_enroll.xml")
print("Enrollment screen nodes:")
for n in root.iter("node"):
    txt = n.attrib.get("text","")
    desc = n.attrib.get("content-desc","")
    if txt or desc:
        print(f"  text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")
sc("e03_enrollment_state.png")

# ── Start Enrollment (guidelines dialog) ──────────────────────────────────────
start_btn = find_node_any(root, "Start Enrollment", "Begin Enrollment", "Start")
if start_btn is not None:
    sx, sy = center(start_btn.attrib["bounds"])
    print(f"\nTapping Start Enrollment at {sx},{sy}")
    tap(sx, sy, d=3.0)
    sc("e04_after_start.png")
else:
    print("\nNo Start button visible - proceeding to camera check")

# ── Camera permission ──────────────────────────────────────────────────────────
print("\nChecking camera permission (2s)...")
time.sleep(2.0)
root = dump_ui("e_ui_perm.xml")
granted = False
for ptext in ["While using the app", "Allow only while using app", "Allow", "Only this time"]:
    pn = find_node_any(root, ptext)
    if pn is not None:
        px, py = center(pn.attrib["bounds"])
        print(f"Granting permission: {ptext!r} at {px},{py}")
        tap(px, py, d=2.0)
        granted = True
        break
if not granted:
    print("No permission dialog found (likely already granted)")

sc("e05_after_perm.png")

# ── Wait for camera ────────────────────────────────────────────────────────────
print("\nWaiting 6s for camera to initialize...")
time.sleep(6.0)
sc("e06_camera_ready.png")

root = dump_ui("e_ui_camera.xml")
print("Camera screen nodes:")
for n in root.iter("node"):
    txt = n.attrib.get("text","")
    desc = n.attrib.get("content-desc","")
    if txt or desc:
        print(f"  text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")

# ── Front capture ─────────────────────────────────────────────────────────────
print("\nCapturing FRONT pose (0°)...")
cap = find_node_any(root, "Capture")
if cap is not None:
    cx, cy = center(cap.attrib["bounds"])
    print(f"  Capture at {cx},{cy}")
    tap(cx, cy, d=5.0)
else:
    print("  Capture btn not found, tapping bottom center...")
    tap(540, 1950, d=5.0)
sc("e07_front.png")

# ── Left capture ──────────────────────────────────────────────────────────────
print("\nCapturing LEFT pose (-15°) [3s wait]...")
time.sleep(3.0)
root = dump_ui("e_ui_left.xml")
for n in root.iter("node"):
    txt = n.attrib.get("text","")
    desc = n.attrib.get("content-desc","")
    if txt or desc:
        print(f"  text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")
cap = find_node_any(root, "Capture")
if cap is not None:
    cx, cy = center(cap.attrib["bounds"])
    tap(cx, cy, d=5.0)
else:
    tap(540, 1950, d=5.0)
sc("e08_left.png")

# ── Right capture ─────────────────────────────────────────────────────────────
print("\nCapturing RIGHT pose (+15°) [3s wait]...")
time.sleep(3.0)
root = dump_ui("e_ui_right.xml")
for n in root.iter("node"):
    txt = n.attrib.get("text","")
    desc = n.attrib.get("content-desc","")
    if txt or desc:
        print(f"  text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")
cap = find_node_any(root, "Capture")
if cap is not None:
    cx, cy = center(cap.attrib["bounds"])
    tap(cx, cy, d=5.0)
else:
    tap(540, 1950, d=5.0)
sc("e09_right.png")

# ── Final result ──────────────────────────────────────────────────────────────
print("\nWaiting for enrollment processing (10s)...")
time.sleep(10.0)
sc("e10_result.png")

root = dump_ui("e_ui_result.xml")
print("Final result screen:")
for n in root.iter("node"):
    txt = n.attrib.get("text","")
    desc = n.attrib.get("content-desc","")
    if txt or desc:
        print(f"  text={txt!r} desc={desc!r} bounds={n.attrib.get('bounds','')}")

print("\n=== DONE ===")
