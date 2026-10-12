import subprocess, time, os

ADB = r"C:\Users\Abishek\AppData\Local\Android\Sdk\platform-tools\adb.exe"
SERIAL = "FY6PHIEA69AMQ8HU"
SCREEN_DIR = r"C:\Users\Abishek\Desktop\am-oss\android_phase7_6_screens"
os.makedirs(SCREEN_DIR, exist_ok=True)

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

def capture(name):
    path_sd = f"/sdcard/{name}.png"
    path_local = os.path.join(SCREEN_DIR, f"{name}.png")
    adb(["shell", "screencap", "-p", path_sd])
    adb(["pull", path_sd, path_local])
    return path_local

# 1. Dismiss any open keyboard
adb(["shell", "input", "keyevent", "4"])
time.sleep(0.5)

# 2. Tap username field
print("Tapping username field...")
tap(540, 1355, 0.5)
# Select all and delete: move cursor to end, delete 30 chars
for _ in range(30):
    adb(["shell", "input", "keyevent", "67"])
adb(["shell", "input", "text", "721025149004"])
time.sleep(0.3)

# Dismiss keyboard to restore screen positions
adb(["shell", "input", "keyevent", "4"])
time.sleep(0.6)

# 3. Tap password field
print("Tapping password field...")
tap(540, 1589, 0.5)
for _ in range(35):
    adb(["shell", "input", "keyevent", "67"])

target_pw = "L45^h&CC%tBDpc"
escaped_pw = escape_for_adb(target_pw)
adb(["shell", "input", "text", escaped_pw])
time.sleep(0.3)

# Dismiss keyboard
adb(["shell", "input", "keyevent", "4"])
time.sleep(0.6)

capture("01_student_login_filled_clean")

# 4. Tap Sign In button (540, 1808)
print("Tapping Sign In...")
tap(540, 1808, 4.0)

capture("02_student_dashboard_live")
print("Finished!")
