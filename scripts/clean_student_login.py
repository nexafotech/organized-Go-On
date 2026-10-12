"""
Login as student 721025149001 on the clean screen.
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

def adb(args):
    return subprocess.run([ADB, "-s", SERIAL] + args, capture_output=True, text=True)

def tap(x, y, d=0.5):
    adb(["shell", "input", "tap", str(x), str(y)])
    time.sleep(d)

def dump_ui(local="__ui.xml"):
    adb(["shell", "uiautomator", "dump", "/sdcard/__ui.xml"])
    adb(["pull", "/sdcard/__ui.xml", os.path.join(OUT, local)])
    return ET.parse(os.path.join(OUT, local)).getroot()

def center(bounds):
    nums = list(map(int, re.findall(r"\d+", bounds)))
    return (nums[0]+nums[2])//2, (nums[1]+nums[3])//2

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

root = dump_ui("login_fields.xml")
edit_nodes = [n for n in root.iter("node") if "EditText" in n.attrib.get("class","")]
print(f"EditText nodes found: {len(edit_nodes)}")

# Username
if len(edit_nodes) >= 1:
    ux, uy = center(edit_nodes[0].attrib["bounds"])
    print(f"Tapping username at {ux},{uy}")
    tap(ux, uy)
    for _ in range(20):
        adb(["shell", "input", "keyevent", "67"])
    adb(["shell", "input", "text", "721025149001"])
    time.sleep(0.3)

# Password
if len(edit_nodes) >= 2:
    px, py = center(edit_nodes[1].attrib["bounds"])
    print(f"Tapping password at {px},{py}")
    tap(px, py)
    for _ in range(30):
        adb(["shell", "input", "keyevent", "67"])
    escaped_pw = escape_for_adb(pw)
    adb(["shell", "input", "text", escaped_pw])
    time.sleep(0.3)

# Dismiss keyboard with ESCAPE
adb(["shell", "input", "keyevent", "111"])
time.sleep(0.5)

# Find Sign In button
root2 = dump_ui("login_pre_signin.xml")
for n in root2.iter("node"):
    desc = n.attrib.get("content-desc","")
    if "Student Sign In" in desc or "Sign In" in desc:
        bx, by = center(n.attrib["bounds"])
        print(f"Tapping Sign In at {bx},{by}")
        tap(bx, by, d=4.0)
        break

adb(["shell", "screencap", "-p", "/sdcard/post_login_dash.png"])
adb(["pull", "/sdcard/post_login_dash.png", os.path.join(OUT, "post_login_dash.png")])
print("Done.")
