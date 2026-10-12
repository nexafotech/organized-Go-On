import subprocess
import sys

ADB = r"C:\Users\Abishek\AppData\Local\Android\Sdk\platform-tools\adb.exe"

def safe_type(text):
    # On Android shell, characters like ^, &, ;, (, ), <, >, |, *, ?, [, ], ~, +, =, %, \
    # can be escaped with backslash
    escaped = []
    for c in text:
        if c in ['^', '&', ';', '(', ')', '<', '>', '|', '*', '?', '[', ']', '~', '$', '`', '"', "'", '\\']:
            escaped.append('\\' + c)
        elif c == ' ':
            escaped.append('%s')
        else:
            escaped.append(c)
    arg = "".join(escaped)
    subprocess.run([ADB, "shell", "input", "text", arg])

if __name__ == "__main__":
    from verify_problem18_device import get_faculty_password, tap, clear_text_field, keyevent
    pw = get_faculty_password("fac05")
    tap(540, 1256, delay=0.5)
    clear_text_field(20)
    safe_type(pw)
    keyevent(4, delay=0.5)
