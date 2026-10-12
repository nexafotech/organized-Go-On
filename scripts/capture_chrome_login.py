import asyncio
import json
import urllib.request
import websockets
import base64

async def take_screenshot():
    # 1. Fetch targets from Chrome debug port 6106
    targets = json.loads(urllib.request.urlopen('http://127.0.0.1:6106/json').read())
    page = next(t for t in targets if 'localhost:3000' in t.get('url', ''))
    print("Connecting to Page:", page['url'])
    ws_url = page['webSocketDebuggerUrl']

    async with websockets.connect(ws_url) as ws:
        # Enable page
        await ws.send(json.dumps({'id': 1, 'method': 'Page.enable'}))
        await ws.recv()

        # Wait a moment for rendering
        await asyncio.sleep(2.0)

        # Capture screenshot
        await ws.send(json.dumps({
            'id': 2,
            'method': 'Page.captureScreenshot',
            'params': {
                'format': 'png'
            }
        }))
        res = await ws.recv()
        data = json.loads(res)
        img_bytes = base64.b64decode(data['result']['data'])
        out_path = r"C:\Users\Abishek\Desktop\am-oss\chrome_login_header_cleaned.png"
        with open(out_path, 'wb') as f:
            f.write(img_bytes)
        print(f"Saved Chrome screenshot to {out_path}")

if __name__ == '__main__':
    asyncio.run(take_screenshot())
