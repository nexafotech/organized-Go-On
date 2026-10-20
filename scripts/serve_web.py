"""
Production Web Server for Go-On Flutter Web Build.
Serves mobile/build/web on port 3000 with CORS and WASM MIME support.
"""
import os
import sys
import mimetypes
import http.server
import socketserver

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
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
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
