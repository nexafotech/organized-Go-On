import subprocess, time, sys

ADB = r"C:\Users\Abishek\AppData\Local\Android\Sdk\platform-tools\adb.exe"
SERIAL = "FY6PHIEA69AMQ8HU"

def run_adb(cmd):
    return subprocess.run(f'"{ADB}" -s {SERIAL} {cmd}', shell=True, capture_output=True, text=True).stdout.strip()

url = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000"

print("1. Opening Server Settings Dialog...")
# Tap top right settings icon (bounds: [912,122][1056,266] -> center: 984, 194)
run_adb("shell input tap 984 194")
time.sleep(1.0)

print(f"2. Entering URL: {url}...")
# Tap the text field (bounds: [192,1156][888,1324] -> center: 540, 1240)
run_adb("shell input tap 540 1240")
time.sleep(0.5)

# Select all and delete
run_adb("shell input keyevent 29 --meta 114") # Ctrl+A
run_adb("shell input keyevent 67") # Backspace
for _ in range(40):
    run_adb("shell input keyevent 67")
time.sleep(0.3)

# Type the new url
run_adb(f"shell input text {url}")
time.sleep(0.5)

# Dismiss keyboard using ESCAPE (keyevent 111)
print("3. Dismissing keyboard...")
run_adb("shell input keyevent 111")
time.sleep(0.8)

# Tap Test Connection (bounds: [192,1360][615,1480] -> center: 403, 1420)
print("4. Tapping Test Connection...")
run_adb("shell input tap 403 1420")
time.sleep(2.5)

# Take screenshot of test connection result
run_adb("shell screencap -p /sdcard/test_conn_result.png")
run_adb(r'pull /sdcard/test_conn_result.png "test_conn_result.png"')

# Tap Save (bounds: [648,1840][888,1984] -> center: 768, 1912)
print("5. Tapping Save...")
run_adb("shell input tap 768 1912")
time.sleep(1.5)

# Capture final screen
run_adb("shell screencap -p /sdcard/post_save.png")
run_adb(r'pull /sdcard/post_save.png "post_save.png"')
print("Complete.")
