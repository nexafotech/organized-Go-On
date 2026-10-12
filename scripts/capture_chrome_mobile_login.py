import asyncio
import json
import urllib.request
import websockets
import base64

async def take_mobile_screenshot():
    targets = json.loads(urllib.request.urlopen('http://127.0.0.1:6106/json').read())
    page = next(t for t in targets if 'localhost:3000' in t.get('url', ''))
    ws_url = page['webSocketDebuggerUrl']

    async with websockets.connect(ws_url) as ws:
        async def send_cmd(cmd_id, method, params=None):
            msg = {'id': cmd_id, 'method': method}
            if params:
                msg['params'] = params
            await ws.send(json.dumps(msg))
            while True:
                resp = await ws.recv()
                data = json.loads(resp)
                if data.get('id') == cmd_id:
                    return data

        await send_cmd(1, 'Page.enable')
        await send_cmd(2, 'Emulation.setDeviceMetricsOverride', {
            'width': 390,
            'height': 844,
            'deviceScaleFactor': 3,
            'mobile': True
        })
        await asyncio.sleep(1.5)

        res = await send_cmd(3, 'Page.captureScreenshot', {'format': 'png'})
        img_bytes = base64.b64decode(res['result']['data'])
        out_path = r"C:\Users\Abishek\Desktop\am-oss\chrome_login_mobile_view.png"
        with open(out_path, 'wb') as f:
            f.write(img_bytes)
        print(f"Saved mobile Chrome screenshot to {out_path}")

        await send_cmd(4, 'Emulation.clearDeviceMetricsOverride')

if __name__ == '__main__':
    asyncio.run(take_mobile_screenshot())
