"""
Production Web Server for Go-On Flutter Web Build.
Serves mobile/build/web on port 3000 with CORS and WASM MIME support.
"""
import os
import sys
import json
import mimetypes
import http.server
import socketserver
import urllib.request
import urllib.error

HOST = "0.0.0.0"
PORT = 3000
WEB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "mobile", "build", "web"))
USE_REDIRECT_FALLBACK = False

if not os.path.isdir(WEB_DIR):
    print(f"Notice: Flutter web build directory not found at: {WEB_DIR}")
    print("Enabling smart gateway fallback to redirect traffic to http://localhost:8000")
    USE_REDIRECT_FALLBACK = True

mimetypes.init()
mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/javascript", ".js")
mimetypes.add_type("application/json", ".json")
mimetypes.add_type("image/png", ".png")
mimetypes.add_type("image/webp", ".webp")
mimetypes.add_type("video/webm", ".webm")
mimetypes.add_type("image/x-icon", ".ico")
mimetypes.add_type("text/html", ".html")

class FlutterWebHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def _is_proxy_path(self):
        return (
            self.path.startswith("/api/") or
            self.path.startswith("/health") or
            self.path.startswith("/docs") or
            self.path.startswith("/openapi.json") or
            self.path.startswith("/assets/avatars/") or
            self.path.startswith("/assets/assets/avatars/")
        )

    def _proxy_request(self, method):
        backend_url = f"http://127.0.0.1:8000{self.path}"
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else None

        # Build headers to forward
        headers = {}
        for k, v in self.headers.items():
            if k.lower() not in ("host", "content-length"):
                headers[k] = v
        headers["Host"] = "127.0.0.1:8000"

        try:
            req = urllib.request.Request(backend_url, data=body, headers=headers, method=method)
            with urllib.request.urlopen(req, timeout=30) as resp:
                resp_status = resp.status
                resp_headers = resp.headers
                resp_body = resp.read()
        except urllib.error.HTTPError as e:
            resp_status = e.code
            resp_headers = e.headers
            resp_body = e.read()
        except Exception as e:
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"detail": f"Backend Gateway Error: {str(e)}"}).encode())
            return

        self.send_response(resp_status)
        for k, v in resp_headers.items():
            if k.lower() not in ("content-length", "transfer-encoding", "connection"):
                self.send_header(k, v)
        self.send_header("Content-Length", str(len(resp_body)))
        self.end_headers()
        self.wfile.write(resp_body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        if self._is_proxy_path():
            return self._proxy_request("GET")

        # Force fresh response, bypass browser 304 Not Modified cache
        if "If-Modified-Since" in self.headers:
            del self.headers["If-Modified-Since"]
        if "If-None-Match" in self.headers:
            del self.headers["If-None-Match"]

        target_path = self.translate_path(self.path)
        # If requested path does not exist and has no extension, fallback to index.html (SPA routing)
        if not os.path.exists(target_path) and "." not in os.path.basename(self.path):
            self.path = "/index.html"
        return super().do_GET()

    def do_POST(self):
        if self._is_proxy_path():
            return self._proxy_request("POST")
        self.send_response(404)
        self.end_headers()

    def do_PUT(self):
        if self._is_proxy_path():
            return self._proxy_request("PUT")
        self.send_response(404)
        self.end_headers()

    def do_DELETE(self):
        if self._is_proxy_path():
            return self._proxy_request("DELETE")
        self.send_response(404)
        self.end_headers()

    def do_PATCH(self):
        if self._is_proxy_path():
            return self._proxy_request("PATCH")
        self.send_response(404)
        self.end_headers()

    def do_HEAD(self):
        if "If-Modified-Since" in self.headers:
            del self.headers["If-Modified-Since"]
        if "If-None-Match" in self.headers:
            del self.headers["If-None-Match"]
        return super().do_HEAD()

    def log_message(self, format, *args):
        # Concise logging
        sys.stdout.write(f"[Web 3000] {self.address_string()} - {format % args}\n")
        sys.stdout.flush()

class RedirectHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(302)
        self.send_header("Location", f"http://localhost:8000{self.path}")
        self.end_headers()

    def do_HEAD(self):
        self.send_response(302)
        self.send_header("Location", f"http://localhost:8000{self.path}")
        self.end_headers()

    def log_message(self, format, *args):
        sys.stdout.write(f"[Web 3000 Redirect] {self.address_string()} - {format % args}\n")
        sys.stdout.flush()

class ThreadingTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True

def run():
    print("=" * 60)
    print("  Go-On Web Gateway Server (Port 3000)")
    if USE_REDIRECT_FALLBACK:
        print("  Mode: Forwarding gateway to http://localhost:8000")
    else:
        print(f"  Serving: {WEB_DIR}")
    print(f"  URL:  http://localhost:{PORT} and http://127.0.0.1:{PORT}")
    print("=" * 60)
    sys.stdout.flush()

    handler = FlutterWebHandler if not USE_REDIRECT_FALLBACK else RedirectHandler
    with ThreadingTCPServer((HOST, PORT), handler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down web server...")
            httpd.shutdown()

if __name__ == "__main__":
    run()
