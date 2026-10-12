import subprocess, time

ADB = r"C:\Users\Abishek\AppData\Local\Android\Sdk\platform-tools\adb.exe"
SERIAL = "FY6PHIEA69AMQ8HU"

def adb(cmd):
    return subprocess.run(f'"{ADB}" -s {SERIAL} {cmd}', shell=True, capture_output=True, text=True).stdout.strip()

print("Focusing EditText at (540, 1240)...")
adb("shell input tap 540 1240")
time.sleep(0.5)

print("Moving to end and deleting all...")
adb("shell input keyevent 123")
for _ in range(40):
    adb("shell input keyevent 67")
time.sleep(0.3)

print("Typing http://127.0.0.1:8000 ...")
adb("shell input text http://127.0.0.1:8000")
time.sleep(0.5)

print("Dismissing keyboard...")
adb("shell input keyevent 111")
time.sleep(0.8)

print("Tapping Test Connection at (403, 1420)...")
adb("shell input tap 403 1420")
time.sleep(3.0)

print("Tapping Save at (768, 1912)...")
adb("shell input tap 768 1912")
time.sleep(1.0)

adb("shell screencap -p /sdcard/post_url_save.png")
adb(r'pull /sdcard/post_url_save.png "post_url_save.png"')
print("Done!")
