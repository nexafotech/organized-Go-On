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

async def run_verification():
    user_data_dir = tempfile.mkdtemp(prefix="chrome_test_profile_")
    chrome_path = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
    port = 9222
    
    # Pre-generate valid admin token
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
        "--window-size=1400,900",
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

                # Navigate directly to notifications tab!
                print("1. Navigating directly to http://localhost:8000/admin#notifications with auth cookie...")
                await page_cmd("Page.navigate", {"url": "http://localhost:8000/admin#notifications"})
                await asyncio.sleep(2.0)

                # Set localStorage as well and trigger auth check / tab switch if needed
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
                await asyncio.sleep(2.0)

                # Step 4: Verify DOM structure and computed styles
                verify_script = """
                (() => {
                    const notifSec = document.getElementById('tab-notifications');
                    const auditSec = document.getElementById('tab-audit');
                    const notifMenu = document.querySelector('.menu-item[data-tab="notifications"]');
                    
                    const notifParent = notifSec ? notifSec.parentElement.tagName + '.' + notifSec.parentElement.className : 'null';
                    const isInsideAudit = auditSec ? auditSec.contains(notifSec) : false;

                    const notifStyle = notifSec ? window.getComputedStyle(notifSec).display : 'null';
                    const auditStyle = auditSec ? window.getComputedStyle(auditSec).display : 'null';

                    const devicesText = document.getElementById('statNotifDevices') ? document.getElementById('statNotifDevices').innerText : '';
                    const stuStatusText = document.getElementById('statNotifStudentStatus') ? document.getElementById('statNotifStudentStatus').innerText : '';
                    const facStatusText = document.getElementById('statNotifFacultyStatus') ? document.getElementById('statNotifFacultyStatus').innerText : '';
                    const totalLogsText = document.getElementById('statNotifTotalLogs') ? document.getElementById('statNotifTotalLogs').innerText : '';

                    const logRows = document.querySelectorAll('#notificationLogsTable tbody tr').length;
                    const schedRows = document.querySelectorAll('#scheduledNotificationsTable tbody tr').length;
                    const pageTitle = document.getElementById('pageTitle') ? document.getElementById('pageTitle').innerText : '';

                    return {
                        hash: window.location.hash,
                        pageTitle: pageTitle,
                        menuActive: notifMenu ? notifMenu.classList.contains('active') : false,
                        notifActive: notifSec ? notifSec.classList.contains('active') : false,
                        notifComputedDisplay: notifStyle,
                        auditComputedDisplay: auditStyle,
                        notifParent: notifParent,
                        isInsideAudit: isInsideAudit,
                        metrics: {
                            devices: devicesText,
                            studentStatus: stuStatusText,
                            facultyStatus: facStatusText,
                            totalLogs: totalLogsText
                        },
                        tableRows: {
                            logs: logRows,
                            scheduled: schedRows
                        }
                    };
                })()
                """
                dom_eval = await page_cmd("Runtime.evaluate", {
                    "expression": verify_script,
                    "returnByValue": True
                })
                dom_result = dom_eval["result"].get("value", {})
                print("DOM & Display Verification Result:")
                print(json.dumps(dom_result, indent=2))

                # Step 5: Capture full-page screenshot
                shot_res = await page_cmd("Page.captureScreenshot", {"format": "png"})
                img_data = base64.b64decode(shot_res["result"]["data"])
                out_img = r"C:\Users\Abishek\Desktop\am-oss\chrome_admin_notifications_live.png"
                with open(out_img, "wb") as f:
                    f.write(img_data)
                print(f"Captured screenshot to: {out_img} ({len(img_data)} bytes)")

    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except Exception:
            proc.kill()

if __name__ == "__main__":
    asyncio.run(run_verification())
