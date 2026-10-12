import asyncio
import json
import urllib.request
import websockets

async def get_console():
    targets = json.loads(urllib.request.urlopen('http://127.0.0.1:52176/json').read())
    page = next(t for t in targets if t['url'].startswith('http://localhost:52170'))
    print("Page URL:", page['url'])
    print("WS Debugger URL:", page['webSocketDebuggerUrl'])

    async with websockets.connect(page['webSocketDebuggerUrl']) as ws:
        await ws.send(json.dumps({'id': 1, 'method': 'Runtime.enable'}))
        await ws.send(json.dumps({'id': 2, 'method': 'Log.enable'}))
        await ws.send(json.dumps({'id': 3, 'method': 'Page.enable'}))
        # Reload to capture all console and exception events from start
        await ws.send(json.dumps({'id': 4, 'method': 'Page.reload'}))

        log_file = open('scripts/chrome_logs.txt', 'w', encoding='utf-8', errors='replace')
        try:
            while True:
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=8.0)
                    data = json.loads(msg)
                    method = data.get('method', '')
                    if method == 'Runtime.consoleAPICalled':
                        params = data['params']
                        t = params.get('type')
                        args = []
                        for a in params.get('args', []):
                            if 'value' in a:
                                args.append(str(a['value']))
                            elif 'description' in a:
                                args.append(str(a['description']))
                            else:
                                args.append(str(a))
                        line = f"[{t.upper()}] {' '.join(args)}"
                        log_file.write(line + '\n')
                        log_file.flush()
                    elif method == 'Runtime.exceptionThrown':
                        log_file.write(">>> EXCEPTION THROWN:\n")
                        details = data['params']['exceptionDetails']
                        log_file.write(f"Text: {details.get('text')}\n")
                        log_file.write(f"Exception: {details.get('exception', {}).get('description')}\n")
                        log_file.write(f"Stack: {details.get('stackTrace')}\n")
                        log_file.flush()
                    elif method == 'Log.entryAdded':
                        entry = data['params']['entry']
                        log_file.write(f"[LOG {entry.get('level')}] {entry.get('text')}\n")
                        log_file.flush()
                except asyncio.TimeoutError:
                    log_file.write("Finished listening.\n")
                    break
        finally:
            log_file.close()

if __name__ == '__main__':
    asyncio.run(get_console())
