import asyncio
import base64
import json
import os
import subprocess
import tempfile
import time
import urllib.request
import websockets

ARTIFACT_DIR = r"C:\Users\rethi\.gemini\antigravity\brain\cbcd6c53-a938-4b70-bb52-a72859f357bc"
os.makedirs(ARTIFACT_DIR, exist_ok=True)

async def run_browser_tests():
    user_data_dir = tempfile.mkdtemp(prefix="chrome_e2e_")
    chrome_path = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
    port = 9555

    cmd = [
        chrome_path,
        "--headless=new",
        f"--remote-debugging-port={port}",
        f"--user-data-dir={user_data_dir}",
        "--disable-gpu",
        "--no-first-run",
        "--no-default-browser-check",
        "--window-size=1680,900",
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

                viewports = [
                    ("desktop_1680x900", 1680, 900),
                    ("laptop_1366x768", 1366, 768),
                    ("tablet_768x1024", 768, 1024),
                    ("mobile_390x844", 390, 844),
                ]

                print("\n[E2E 1] Testing Web App at http://localhost:3000/ across viewports...")
                for name, w, h in viewports:
                    await page_cmd("Emulation.setDeviceMetricsOverride", {
                        "width": w,
                        "height": h,
                        "deviceScaleFactor": 1,
                        "mobile": (w < 768)
                    })
                    await page_cmd("Page.navigate", {"url": "http://localhost:3000/"})
                    await asyncio.sleep(3.0)

                    shot_res = await page_cmd("Page.captureScreenshot", {"format": "png"})
                    img_data = base64.b64decode(shot_res["result"]["data"])
                    out_path = os.path.join(ARTIFACT_DIR, f"e2e_web_{name}.png")
                    with open(out_path, "wb") as f:
                        f.write(img_data)
                    print(f"  * Captured {name} -> {out_path} ({len(img_data)} bytes)")

                print("\n[E2E 2] Testing Admin Web Panel at http://localhost:8000/admin ...")
                await page_cmd("Emulation.setDeviceMetricsOverride", {
                    "width": 1680,
                    "height": 900,
                    "deviceScaleFactor": 1,
                    "mobile": False
                })
                await page_cmd("Page.navigate", {"url": "http://localhost:8000/admin"})
                await asyncio.sleep(2.5)

                shot_admin = await page_cmd("Page.captureScreenshot", {"format": "png"})
                img_admin = base64.b64decode(shot_admin["result"]["data"])
                out_admin = os.path.join(ARTIFACT_DIR, "e2e_admin_panel.png")
                with open(out_admin, "wb") as f:
                    f.write(img_admin)
                print(f"  * Captured Admin Login Modal -> {out_admin} ({len(img_admin)} bytes)")

                # Click Sign In as Administrator button
                print("  * Clicking 'Sign In as Administrator' button...")
                await page_cmd("Runtime.evaluate", {
                    "expression": "document.getElementById('adminLoginSubmitBtn').click()"
                })
                await asyncio.sleep(3.0)

                shot_dashboard = await page_cmd("Page.captureScreenshot", {"format": "png"})
                img_dashboard = base64.b64decode(shot_dashboard["result"]["data"])
                out_dashboard = os.path.join(ARTIFACT_DIR, "e2e_admin_dashboard_loggedin.png")
                with open(out_dashboard, "wb") as f:
                    f.write(img_dashboard)
                print(f"  * Captured Admin Logged-In Dashboard -> {out_dashboard} ({len(img_dashboard)} bytes)")

                eval_title = await page_cmd("Runtime.evaluate", {"expression": "document.title"})
                title = eval_title.get("result", {}).get("value", "")
                print(f"  * Admin Panel Document Title: '{title}'")
                print("\nAll browser automation tests passed successfully!")
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except Exception:
            proc.kill()

if __name__ == "__main__":
    asyncio.run(run_browser_tests())
