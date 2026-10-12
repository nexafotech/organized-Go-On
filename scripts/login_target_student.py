import subprocess, time

ADB = r"C:\Users\Abishek\AppData\Local\Android\Sdk\platform-tools\adb.exe"
SERIAL = "FY6PHIEA69AMQ8HU"

def adb(cmd):
    return subprocess.run(f'"{ADB}" -s {SERIAL} {cmd}', shell=True, capture_output=True, text=True).stdout.strip()

print("1. Focusing Student ID field at (540, 1355)...")
adb("shell input tap 540 1355")
time.sleep(0.5)

print("2. Entering username: 721025149004...")
adb("shell input text 721025149004")
time.sleep(0.5)

print("3. Focusing Password field at (540, 1589)...")
adb("shell input tap 540 1589")
time.sleep(0.5)

# Password: L45^h&CC%tBDpc
# In adb shell input text, characters like ^, &, % need escaping
pw_escaped = "L45\\^h\\&CC\\%tBDpc"
print(f"4. Entering password: {pw_escaped}...")
adb(f"shell input text '{pw_escaped}'")
time.sleep(0.5)

print("5. Dismissing keyboard via ESCAPE...")
adb("shell input keyevent 111")
time.sleep(0.8)

# Capture login screen pre-click
adb("shell screencap -p /sdcard/stu4_filled.png")
adb(r'pull /sdcard/stu4_filled.png "stu4_filled.png"')

print("6. Tapping Student Sign In at (540, 1808)...")
adb("shell input tap 540 1808")
time.sleep(4.0)

print("7. Capturing post-login screen...")
adb("shell screencap -p /sdcard/stu4_dashboard_actual.png")
adb(r'pull /sdcard/stu4_dashboard_actual.png "stu4_dashboard_actual.png"')
print("Done!")
