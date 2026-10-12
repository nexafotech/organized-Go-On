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
from app.models.notification import DeviceToken, NotificationLog
from app.models.audit import AuditLog
from app.core.security import create_access_token

async def execute_admin_broadcast():
    print("=== Step 1: Pre-broadcast Audit & Diagnostics ===")
    db = SessionLocal()
    try:
        active_students = db.query(User).filter(User.role == UserRole.STUDENT, User.is_active == True).count()
        total_students = db.query(User).filter(User.role == UserRole.STUDENT).count()
        active_tokens = db.query(DeviceToken).filter(DeviceToken.is_active == True).count()
        admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
        token = create_access_token(str(admin.id), admin.role.value)
        print(f"Total Student Accounts in DB: {total_students}")
        print(f"Active Student Accounts (Expected Recipients): {active_students}")
        print(f"Active FCM Device Tokens in DB: {active_tokens}")
    finally:
        db.close()

    print("\n=== Step 2: Executing Broadcast through Web Admin Console via CDP ===")
    user_data_dir = tempfile.mkdtemp(prefix="chrome_broadcast_")
    chrome_path = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
    port = 9224

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
            cmd_counter = 0
            async def send_cmd(method, params=None):
                nonlocal cmd_counter
                cmd_counter += 1
                msg = {"id": cmd_counter, "method": method, "params": params or {}}
                await ws.send(json.dumps(msg))
                while True:
                    resp_str = await ws.recv()
                    resp = json.loads(resp_str)
                    if resp.get("id") == cmd_counter:
                        return resp

            new_target = await send_cmd("Target.createTarget", {"url": "about:blank"})
            target_id = new_target["result"]["targetId"]
            page_ws_url = f"ws://127.0.0.1:{port}/devtools/page/{target_id}"

            async with websockets.connect(page_ws_url) as page_ws:
                page_counter = 0
                async def page_cmd(method, params=None):
                    nonlocal page_counter
                    page_counter += 1
                    msg = {"id": page_counter, "method": method, "params": params or {}}
                    await page_ws.send(json.dumps(msg))
                    while True:
                        resp_str = await page_ws.recv()
                        resp = json.loads(resp_str)
                        if resp.get("id") == page_counter:
                            return resp

                await page_cmd("Page.enable")
                await page_cmd("Runtime.enable")
                await page_cmd("Network.enable")

                # Set authenticated admin cookie
                await page_cmd("Network.setCookie", {
                    "name": "am_token",
                    "value": token,
                    "domain": "localhost",
                    "path": "/"
                })

                # Navigate to notifications tab
                print("Navigating to http://localhost:8000/admin#notifications...")
                await page_cmd("Page.navigate", {"url": "http://localhost:8000/admin#notifications"})
                await asyncio.sleep(2.0)

                # Set token in localStorage and switch to notifications tab
                init_script = f"""
                localStorage.setItem('access_token', '{token}');
                if (typeof switchTab === 'function') {{
                    switchTab('notifications');
                }}
                """
                await page_cmd("Runtime.evaluate", {"expression": init_script})
                await asyncio.sleep(2.0)

                # Populate form fields
                print("Populating Form Fields in Admin Notification Center:")
                print(" - Audience: Students Only (STUDENT)")
                print(" - Scope: Entire Selected Audience (ALL)")
                print(" - Channel: GO_ON_ADMIN (High-Importance Heads-Up)")
                print(" - Priority: HIGH")
                print(" - Title: Go-On Test")
                print(" - Body: hello students")
                print(" - Timing: Send Immediately")

                populate_script = """
                (() => {
                    const aud = document.getElementById('notifAudience');
                    if (aud) {
                        aud.value = 'STUDENT';
                        aud.dispatchEvent(new Event('change', { bubbles: true }));
                    }
                    const tgt = document.getElementById('notifTargetType');
                    if (tgt) {
                        tgt.value = 'ALL';
                        tgt.dispatchEvent(new Event('change', { bubbles: true }));
                    }
                    const chan = document.getElementById('notifChannel');
                    if (chan) {
                        chan.value = 'GO_ON_ADMIN';
                        chan.dispatchEvent(new Event('change', { bubbles: true }));
                    }
                    const prio = document.getElementById('notifPriority');
                    if (prio) {
                        prio.value = 'HIGH';
                        prio.dispatchEvent(new Event('change', { bubbles: true }));
                    }
                    const tNow = document.getElementById('timingNow');
                    if (tNow) {
                        tNow.checked = true;
                        tNow.dispatchEvent(new Event('change', { bubbles: true }));
                    }
                    const titleEl = document.getElementById('notifTitle');
                    if (titleEl) {
                        titleEl.value = 'Go-On Test';
                        titleEl.dispatchEvent(new Event('input', { bubbles: true }));
                    }
                    const bodyEl = document.getElementById('notifBody');
                    if (bodyEl) {
                        bodyEl.value = 'hello students';
                        bodyEl.dispatchEvent(new Event('input', { bubbles: true }));
                    }
                    return {
                        audience: aud ? aud.value : null,
                        targetType: tgt ? tgt.value : null,
                        channel: chan ? chan.value : null,
                        priority: prio ? prio.value : null,
                        title: titleEl ? titleEl.value : null,
                        body: bodyEl ? bodyEl.value : null
                    };
                })()
                """
                form_state = await page_cmd("Runtime.evaluate", {"expression": populate_script, "returnByValue": True})
                print("Populated form values:", json.dumps(form_state.get("result", {}).get("value", {}), indent=2))

                # Submit form via btnSendNotif click or form submit
                print("\nSubmitting Broadcast via Admin Notification Center...")
                submit_script = """
                (() => {
                    const btn = document.getElementById('btnSendNotif');
                    if (btn) {
                        btn.click();
                        return "clicked_btnSendNotif";
                    }
                    const form = document.getElementById('customNotificationForm');
                    if (form) {
                        form.requestSubmit();
                        return "requestSubmit_form";
                    }
                    return "not_found";
                })()
                """
                sub_res = await page_cmd("Runtime.evaluate", {"expression": submit_script, "returnByValue": True})
                print("Submit trigger result:", sub_res.get("result", {}).get("value"))

                # Wait for API roundtrip
                await asyncio.sleep(3.5)

                # Capture UI feedback alert
                alert_script = """
                (() => {
                    const resAlert = document.getElementById('notifComposerResult');
                    return {
                        className: resAlert ? resAlert.className : null,
                        innerText: resAlert ? resAlert.innerText.trim() : null
                    };
                })()
                """
                alert_val = await page_cmd("Runtime.evaluate", {"expression": alert_script, "returnByValue": True})
                print("\nAdmin Console Alert Result:", json.dumps(alert_val.get("result", {}).get("value", {}), indent=2))

                # Take screenshot proof
                ss = await page_cmd("Page.captureScreenshot", {"format": "png"})
                if "result" in ss and "data" in ss["result"]:
                    with open("broadcast_submitted_proof.png", "wb") as f:
                        f.write(base64.b64decode(ss["result"]["data"]))
                    print("Proof screenshot saved to broadcast_submitted_proof.png")

    finally:
        proc.terminate()

    print("\n=== Step 3: Database & Audit Verification ===")
    db = SessionLocal()
    try:
        latest_audit = (
            db.query(AuditLog)
            .filter(AuditLog.action == "SEND_ADMIN_NOTIFICATION")
            .order_by(AuditLog.timestamp.desc())
            .first()
        )
        if latest_audit:
            print(f"Latest Audit Log Entry:")
            print(f" - Audit ID: {latest_audit.id}")
            print(f" - Action: {latest_audit.action}")
            print(f" - Timestamp: {latest_audit.timestamp}")
            print(f" - Details: {latest_audit.details}")

        latest_logs = (
            db.query(NotificationLog)
            .filter(NotificationLog.title == "Go-On Test")
            .order_by(NotificationLog.created_at.desc())
            .all()
        )
        print(f"\nTotal Notification Logs created for 'Go-On Test': {len(latest_logs)}")
        if latest_logs:
            sample = latest_logs[:3]
            print(f"Sample Notification Logs (First 3):")
            for log in sample:
                print(f" - Log ID: {log.id} | User ID: {log.user_id} | Channel: {log.channel_id} | Title: {log.title} | Status: {log.status} | Created: {log.created_at}")

    finally:
        db.close()

if __name__ == "__main__":
    asyncio.run(execute_admin_broadcast())
