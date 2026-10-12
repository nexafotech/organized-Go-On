import subprocess, time, openpyxl, os, re, xml.etree.ElementTree as ET

ADB = r"C:\Users\Abishek\AppData\Local\Android\Sdk\platform-tools\adb.exe"
SERIAL = "FY6PHIEA69AMQ8HU"
EXCEL = r"C:\Users\Abishek\Documents\Attendance_Marker\ALL_ACCOUNT_CREDENTIALS_20260926.xlsx"
SCREEN_DIR = r"C:\Users\Abishek\Desktop\am-oss\android_phase7_6_screens"
os.makedirs(SCREEN_DIR, exist_ok=True)

wb = openpyxl.load_workbook(EXCEL)
ws = wb["Students"]
target_user = "721025149004"
pw = None
for row in range(5, ws.max_row + 1):
    if str(ws.cell(row, 2).value or "").strip() == target_user:
        pw = str(ws.cell(row, 5).value or "").strip()
        break

if not pw:
    # fallback to provided credentials if needed
    pw = "L45^h&CC%tBDpc"

def adb(args):
    return subprocess.run([ADB, "-s", SERIAL] + args, capture_output=True, text=True)

def tap(x, y, d=0.5):
    adb(["shell", "input", "tap", str(x), str(y)])
    time.sleep(d)

def escape_for_adb(text):
    result = []
    for c in text:
        if c == ' ':
            result.append('%s')
        elif c in '&\\#^$()%@!"\'<>|;`~*?[]{}=+,-./':
            result.append(f'\\{c}')
        else:
            result.append(c)
    return ''.join(result)

def dump_ui():
    tmp_xml = os.path.join(SCREEN_DIR, "temp_ui.xml")
    adb(["shell", "uiautomator", "dump", "/sdcard/ui_temp.xml"])
    adb(["pull", "/sdcard/ui_temp.xml", tmp_xml])
    return ET.parse(tmp_xml).getroot()

def center(bounds):
    nums = list(map(int, re.findall(r"\d+", bounds)))
    return (nums[0]+nums[2])//2, (nums[1]+nums[3])//2

def capture(name):
    path_sd = f"/sdcard/{name}.png"
    path_local = os.path.join(SCREEN_DIR, f"{name}.png")
    adb(["shell", "screencap", "-p", path_sd])
    adb(["pull", path_sd, path_local])
    return path_local

print("Step 1: Inspecting current UI...")
root = dump_ui()
edit_nodes = [n for n in root.iter("node") if "EditText" in n.attrib.get("class","")]
print(f"Found {len(edit_nodes)} EditText nodes")

# Tap Student ID
if len(edit_nodes) >= 1:
    ux, uy = center(edit_nodes[0].attrib["bounds"])
    print(f"Tapping student ID field at {ux},{uy}")
    tap(ux, uy)
    # Clear field
    for _ in range(25):
        adb(["shell", "input", "keyevent", "67"])
    adb(["shell", "input", "text", target_user])
    time.sleep(0.3)

# Tap Password
if len(edit_nodes) >= 2:
    px, py = center(edit_nodes[1].attrib["bounds"])
    print(f"Tapping password field at {px},{py}")
    tap(px, py)
    # Clear field
    for _ in range(35):
        adb(["shell", "input", "keyevent", "67"])
    escaped_pw = escape_for_adb(pw)
    adb(["shell", "input", "text", escaped_pw])
    time.sleep(0.3)

# Dismiss keyboard
adb(["shell", "input", "keyevent", "111"])
time.sleep(0.5)

capture("01_student_login_filled")

# Find and tap Sign In button
root = dump_ui()
for n in root.iter("node"):
    desc = n.attrib.get("content-desc","")
    if "Student Sign In" in desc or "Sign In" in desc:
        bx, by = center(n.attrib["bounds"])
        print(f"Tapping Sign In at {bx},{by}")
        tap(bx, by, d=3.5)
        break

capture("02_student_dashboard")
print("Login completed and dashboard captured.")
