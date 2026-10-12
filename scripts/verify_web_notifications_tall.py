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

async def run_tall_screenshot():
    user_data_dir = tempfile.mkdtemp(prefix="chrome_test_profile_tall_")
    chrome_path = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
    port = 9222
    
    from app.core.database import SessionLocal
    from app.models.user import User, UserRole
    from app.core.security import create_access_token

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
        "--window-size=1400,2200",
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

        async with websockets.connect(ws_url, max_size=10485760) as ws:
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

            async with websockets.connect(page_ws_url, max_size=10485760) as page_ws:
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

                await page_cmd("Network.setCookie", {
                    "name": "am_token",
                    "value": token,
                    "domain": "localhost",
                    "path": "/"
                })

                await page_cmd("Page.navigate", {"url": "http://localhost:8000/admin#notifications"})
                await asyncio.sleep(2.0)

                script = f"""
                (async () => {{
                    localStorage.setItem('access_token', '{token}');
                    if (typeof checkAdminAuth === 'function') {{
                        await checkAdminAuth();
                    }}
                    if (typeof switchTab === 'function') {{
                        switchTab('notifications');
                    }}
                    return true;
                }})()
                """
                await page_cmd("Runtime.evaluate", {
                    "expression": script,
                    "awaitPromise": True
                })
                await asyncio.sleep(2.5)

                # Capture full-height screenshot
                shot_res = await page_cmd("Page.captureScreenshot", {"format": "png", "captureBeyondViewport": True})
                img_data = base64.b64decode(shot_res["result"]["data"])
                out_img = r"C:\Users\Abishek\Desktop\am-oss\chrome_admin_notifications_full.png"
                with open(out_img, "wb") as f:
                    f.write(img_data)
                print(f"Captured full height screenshot to: {out_img} ({len(img_data)} bytes)")

    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except Exception:
            proc.kill()

if __name__ == "__main__":
    asyncio.run(run_tall_screenshot())
