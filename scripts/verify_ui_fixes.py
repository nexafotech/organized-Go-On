import asyncio
import base64
import json
import os
import subprocess
import tempfile
import time
import urllib.request
import websockets
import sys

sys.path.insert(0, os.path.abspath("."))

from app.core.database import SessionLocal
from app.models.user import User, UserRole
from app.core.security import create_access_token

ARTIFACT_DIR = r"C:\Users\rethi\.gemini\antigravity\brain\a6e80ca8-ffe5-4ef6-8d58-9a47b86643b8"

async def capture_ui_verification():
    user_data_dir = tempfile.mkdtemp(prefix="chrome_ui_verify_")
    chrome_path = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
    port = 9333
    
    db = SessionLocal()
    try:
        admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
        token = create_access_token(str(admin.id), admin.role.value)
    finally:
        db.close()
    
    cmd = [
        chrome_path,
        "--headless=new",
        f"--remote-debugging-port={port}",
        f"--user-data-dir={user_data_dir}",
        "--disable-gpu",
        "--no-first-run",
        "--no-default-browser-check",
        "--window-size=1600,950",
        "about:blank"
    ]
    
    proc = subprocess.Popen(cmd)
    try:
        ws_url = None
        for _ in range(30):
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{port}/json/version", timeout=1) as resp:
                    data = json.loads(resp.read().decode())
                    ws_url = data.get("webSocketDebuggerUrl")
                    if ws_url:
                        break
            except Exception:
                time.sleep(0.3)
                
        if not ws_url:
            print("ERROR: Chrome did not expose webSocketDebuggerUrl")
            return

        async with websockets.connect(ws_url) as ws:
            async def send_cmd(method, params=None):
                cmd_id = int(time.time() * 1000) % 1000000 + os.getpid()
                msg = {"id": cmd_id, "method": method, "params": params or {}}
                await ws.send(json.dumps(msg))
                while True:
                    resp_str = await ws.recv()
                    resp = json.loads(resp_str)
                    if resp.get("id") == cmd_id:
                        return resp

            new_target = await send_cmd("Target.createTarget", {"url": "about:blank"})
            target_id = new_target["result"]["targetId"]
            page_ws_url = f"ws://127.0.0.1:{port}/devtools/page/{target_id}"

            async with websockets.connect(page_ws_url) as page_ws:
                msg_id = 0
                async def page_cmd(method, params=None):
                    nonlocal msg_id
                    msg_id += 1
                    msg = {"id": msg_id, "method": method, "params": params or {}}
                    await page_ws.send(json.dumps(msg))
                    while True:
                        resp_str = await page_ws.recv()
                        resp = json.loads(resp_str)
                        if resp.get("id") == msg_id:
                            return resp

                await page_cmd("Page.enable")
                await page_cmd("Runtime.enable")
                await page_cmd("Network.enable")

                # Set cookie before navigating
                await page_cmd("Network.setCookie", {
                    "name": "am_token",
                    "value": token,
                    "domain": "localhost",
                    "path": "/"
                })

                # Navigate to admin
                print("1. Navigating to http://localhost:8000/admin...")
                await page_cmd("Page.navigate", {"url": "http://localhost:8000/admin#dashboard"})
                await asyncio.sleep(2.0)

                # Set localStorage as well and trigger auth check
                auth_script = f"""
                (async () => {{
                    localStorage.setItem('access_token', '{token}');
                    if (typeof checkAdminAuth === 'function') {{
                        await checkAdminAuth();
                    }}
                    if (typeof switchTab === 'function') {{
                        switchTab('dashboard');
                    }}
                    return true;
                }})()
                """
                await page_cmd("Runtime.evaluate", {
                    "expression": auth_script,
                    "awaitPromise": True
                })
                await asyncio.sleep(2.0)

                # Capture Dashboard
                shot_resp = await page_cmd("Page.captureScreenshot", {"format": "png"})
                dash_path = os.path.join(ARTIFACT_DIR, "fixed_admin_dashboard.png")
                with open(dash_path, "wb") as f:
                    f.write(base64.b64decode(shot_resp["result"]["data"]))
                print(f"Captured: {dash_path}")

                # Switch to Students tab
                print("2. Switching to students tab...")
                await page_cmd("Runtime.evaluate", {
                    "expression": "if (typeof switchTab === 'function') switchTab('students');",
                    "awaitPromise": True
                })
                await asyncio.sleep(2.0)
                shot_resp = await page_cmd("Page.captureScreenshot", {"format": "png"})
                stu_path = os.path.join(ARTIFACT_DIR, "fixed_admin_students.png")
                with open(stu_path, "wb") as f:
                    f.write(base64.b64decode(shot_resp["result"]["data"]))
                print(f"Captured: {stu_path}")

                # Switch to Notifications tab
                print("3. Switching to notifications tab...")
                await page_cmd("Runtime.evaluate", {
                    "expression": "if (typeof switchTab === 'function') switchTab('notifications');",
                    "awaitPromise": True
                })
                await asyncio.sleep(2.0)
                shot_resp = await page_cmd("Page.captureScreenshot", {"format": "png"})
                notif_path = os.path.join(ARTIFACT_DIR, "fixed_admin_notifications.png")
                with open(notif_path, "wb") as f:
                    f.write(base64.b64decode(shot_resp["result"]["data"]))
                print(f"Captured: {notif_path}")

                # Switch to Attendance tab
                print("4. Switching to attendance tab...")
                await page_cmd("Runtime.evaluate", {
                    "expression": "if (typeof switchTab === 'function') switchTab('attendance');",
                    "awaitPromise": True
                })
                await asyncio.sleep(2.0)
                shot_resp = await page_cmd("Page.captureScreenshot", {"format": "png"})
                att_path = os.path.join(ARTIFACT_DIR, "fixed_admin_attendance.png")
                with open(att_path, "wb") as f:
                    f.write(base64.b64decode(shot_resp["result"]["data"]))
                print(f"Captured: {att_path}")

                # 5. Navigate to Flutter Web
                print("5. Navigating to http://localhost:3000/ for Flutter Web...")
                await page_cmd("Page.navigate", {"url": "http://localhost:3000/"})
                # Flutter web takes a few seconds to load canvas / wasm / dom
                await asyncio.sleep(6.0)
                shot_resp = await page_cmd("Page.captureScreenshot", {"format": "png"})
                web_path = os.path.join(ARTIFACT_DIR, "fixed_flutter_web.png")
                with open(web_path, "wb") as f:
                    f.write(base64.b64decode(shot_resp["result"]["data"]))
                print(f"Captured: {web_path}")

    finally:
        try:
            proc.terminate()
            proc.wait(timeout=3)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass

if __name__ == "__main__":
    asyncio.run(capture_ui_verification())
