import subprocess, time

ADB = r"C:\Users\Abishek\AppData\Local\Android\Sdk\platform-tools\adb.exe"
SERIAL = "FY6PHIEA69AMQ8HU"

def run_adb(cmd):
    return subprocess.run(f'"{ADB}" -s {SERIAL} {cmd}', shell=True, capture_output=True, text=True).stdout.strip()

print("1. Tapping into Server Base URL field...")
run_adb("shell input tap 540 1240")
time.sleep(0.8)

print("2. Clearing existing URL...")
run_adb("shell input keyevent KEYCODE_MOVE_END")
for _ in range(35):
    run_adb("shell input keyevent 67")
time.sleep(0.5)

print("3. Typing http://127.0.0.1:8000 ...")
run_adb("shell input text 'http://127.0.0.1:8000'")
time.sleep(0.8)

print("4. Closing keyboard via ESCAPE...")
run_adb("shell input keyevent 111")
time.sleep(1.0)

print("5. Tapping Test Connection at (403, 1420)...")
run_adb("shell input tap 403 1420")
time.sleep(3.0)

run_adb("shell screencap -p /sdcard/test_result_127.png")
run_adb(r'pull /sdcard/test_result_127.png "test_result_127.png"')

print("6. Tapping Save at (768, 1912)...")
run_adb("shell input tap 768 1912")
time.sleep(1.5)

run_adb("shell screencap -p /sdcard/post_save_127.png")
run_adb(r'pull /sdcard/post_save_127.png "post_save_127.png"')
print("Done!")
