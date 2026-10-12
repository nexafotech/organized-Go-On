"""
Final enrollment - tap Take Photo buttons correctly.
App is on STEP 1/3 FRONT.
Take Photo for FRONTAL: [48,1871][1032,2015] -> center=(540,1943)
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
        cls = n.attrib.get("class","")
        desc = n.attrib.get("content-desc","")
        txt = n.attrib.get("text","")
        if txt or desc or "Button" in cls:
            print(f"  cls={cls!r} desc={desc!r} txt={txt!r} bounds={n.attrib.get('bounds','')}")
    return root

def center(bounds_str):
    nums = list(map(int, re.findall(r"\d+", bounds_str)))
    return (nums[0]+nums[2])//2, (nums[1]+nums[3])//2

def find_btn(root, *keywords):
    """Find button whose desc exactly contains one of the keywords."""
    for n in root.iter("node"):
        desc = n.attrib.get("content-desc","")
        txt = n.attrib.get("text","")
        for kw in keywords:
            if kw.lower() in desc.lower() or kw.lower() in txt.lower():
                return n
    return None

# ── 1. Check current state ─────────────────────────────────────────────────────
print("1. Current state:")
sc("g01_state.png")
root = dump_and_print("g_ui_state.xml")

# ── 2. Tap Take Photo for FRONTAL ──────────────────────────────────────────────
print("\n2. Tapping 'Take Photo for FRONTAL'...")
# Known from dump: bounds=[48,1871][1032,2015] -> center=(540, 1943)
btn = find_btn(root, "Take Photo for FRONTAL", "Take Photo for Front")
if btn is not None:
    bx, by = center(btn.attrib["bounds"])
    print(f"   Found at {bx},{by}")
    tap(bx, by, d=5.0)
else:
    print("   Not found, using hardcoded (540, 1943)")
    tap(540, 1943, d=5.0)
sc("g02_after_frontal.png")

# ── 3. Check for Step 2 ─────────────────────────────────────────────────────────
print("\n3. Checking for Step 2 (LEFT pose)...")
time.sleep(2.0)
root = dump_and_print("g_ui_step2.xml")
sc("g03_step2.png")

btn2 = find_btn(root, "Take Photo for LEFT", "Take Photo for Left", "SLIGHT LEFT")
if btn2 is not None:
    bx, by = center(btn2.attrib["bounds"])
    print(f"   Take Photo LEFT at {bx},{by}")
    tap(bx, by, d=5.0)
else:
    # Check if we're still on step 1 (capture failed or step advanced)
    progress = find_btn(root, "ENROLLMENT IN PROGRESS")
    if progress:
        desc = progress.attrib.get("content-desc","")
        print(f"   Progress: {desc!r}")
    print("   Tapping at (540, 1943) as fallback...")
    tap(540, 1943, d=5.0)
sc("g04_after_left.png")

# ── 4. Check for Step 3 ─────────────────────────────────────────────────────────
print("\n4. Checking for Step 3 (RIGHT pose)...")
time.sleep(2.0)
root = dump_and_print("g_ui_step3.xml")
sc("g05_step3.png")

btn3 = find_btn(root, "Take Photo for RIGHT", "Take Photo for Right", "SLIGHT RIGHT")
if btn3 is not None:
    bx, by = center(btn3.attrib["bounds"])
    print(f"   Take Photo RIGHT at {bx},{by}")
    tap(bx, by, d=5.0)
else:
    print("   Tapping at (540, 1943) as fallback...")
    tap(540, 1943, d=5.0)
sc("g06_after_right.png")

# ── 5. Wait for result ────────────────────────────────────────────────────────
print("\n5. Waiting for enrollment result (15s)...")
time.sleep(15.0)
sc("g07_result.png")
print("Final state:")
root = dump_and_print("g_ui_final.xml")

print("\n=== DONE ===")
