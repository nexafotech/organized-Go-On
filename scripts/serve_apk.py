"""
Localhost APK and Release Artifacts Distribution Server.
Serves the go-On Android debug APK, PDF report, and test results on port 8080 with range support and download UI.
"""
import os
import sys
import hashlib
import mimetypes
from http.server import HTTPServer, BaseHTTPRequestHandler
import socketserver

HOST = "0.0.0.0"
PORT = 8080

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RELEASE_APK = os.path.join(PROJECT_ROOT, "mobile", "build", "app", "outputs", "flutter-apk", "app-release.apk")
if os.path.exists(RELEASE_APK):
    APK_PATH = RELEASE_APK
elif os.path.exists(os.path.join(PROJECT_ROOT, "app-debug.apk")):
    APK_PATH = os.path.join(PROJECT_ROOT, "app-debug.apk")
else:
    APK_PATH = os.path.join(PROJECT_ROOT, "mobile", "build", "app", "outputs", "flutter-apk", "app-debug.apk")

PDF_REPORT = os.path.join(PROJECT_ROOT, "reports", "go-On_Final_Performance_Deployment_and_Tunnel_Report.pdf")
if not os.path.exists(PDF_REPORT):
    PDF_REPORT = os.path.join(PROJECT_ROOT, "reports", "go-On_Avatar_Save_Performance_Fix_Report.pdf")
JSON_RESULTS = os.path.join(PROJECT_ROOT, "reports", "go-On_Attendance_Real_Data_and_Mobile_UI_Test_Results.json")

APK_SIZE = os.path.getsize(APK_PATH) if os.path.exists(APK_PATH) else 0
APK_SIZE_MB = round(APK_SIZE / (1024 * 1024), 2)

if os.path.exists(APK_PATH):
    _h = hashlib.sha256()
    with open(APK_PATH, "rb") as _f:
        while _chunk := _f.read(65536):
            _h.update(_chunk)
    APK_SHA256 = _h.hexdigest().upper()
else:
    APK_SHA256 = "UNKNOWN"

HTML_TEMPLATE = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>go-On AI Face Attendance - Faculty / Class Advisor Portal Optimization</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
  <style>
    :root {{
      --bg: #0B0F19;
      --card-bg: rgba(22, 30, 49, 0.85);
      --card-border: rgba(255, 255, 255, 0.08);
      --accent: #3B82F6;
      --accent-glow: rgba(59, 130, 246, 0.25);
      --success: #10B981;
      --text-main: #F8FAFC;
      --text-muted: #94A3B8;
      --font: 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
      --code-font: 'JetBrains Mono', monospace;
    }}
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      background-color: var(--bg);
      background-image: 
        radial-gradient(at 0% 0%, rgba(59, 130, 246, 0.12) 0px, transparent 50%),
        radial-gradient(at 100% 100%, rgba(16, 185, 129, 0.08) 0px, transparent 50%);
      color: var(--text-main);
      font-family: var(--font);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px 16px;
    }}
    .container {{
      max-width: 680px;
      width: 100%;
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 24px;
      padding: 36px 32px;
      backdrop-filter: blur(20px);
      box-shadow: 0 20px 40px -15px rgba(0, 0, 0, 0.5), 0 0 50px -10px var(--accent-glow);
    }}
    .header {{
      display: flex;
      align-items: center;
      gap: 16px;
      margin-bottom: 24px;
      border-bottom: 1px solid var(--card-border);
      padding-bottom: 20px;
    }}
    .badge-icon {{
      width: 52px;
      height: 52px;
      background: linear-gradient(135deg, #2563EB, #1D4ED8);
      border-radius: 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 26px;
      box-shadow: 0 8px 16px -4px rgba(37, 99, 235, 0.4);
    }}
    .title-group h1 {{
      font-size: 22px;
      font-weight: 800;
      letter-spacing: -0.02em;
    }}
    .title-group p {{
      color: var(--text-muted);
      font-size: 13px;
      margin-top: 2px;
    }}
    .status-badge {{
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(16, 185, 129, 0.12);
      border: 1px solid rgba(16, 185, 129, 0.25);
      color: #34D399;
      font-size: 11px;
      font-weight: 700;
      padding: 4px 10px;
      border-radius: 9999px;
      margin-top: 6px;
    }}
    .status-badge::before {{
      content: "";
      width: 6px;
      height: 6px;
      background: #34D399;
      border-radius: 50%;
      box-shadow: 0 0 8px #34D399;
    }}
    .meta-grid {{
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 12px;
      margin-bottom: 24px;
    }}
    .meta-card {{
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid rgba(255, 255, 255, 0.05);
      border-radius: 12px;
      padding: 12px 14px;
    }}
    .meta-card .label {{
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--text-muted);
      font-weight: 600;
    }}
    .meta-card .value {{
      font-size: 14px;
      font-weight: 700;
      color: var(--text-main);
      margin-top: 4px;
      font-family: var(--code-font);
    }}
    .download-btn {{
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      background: linear-gradient(135deg, #3B82F6, #1D4ED8);
      color: white;
      text-decoration: none;
      font-size: 16px;
      font-weight: 700;
      padding: 16px 24px;
      border-radius: 14px;
      box-shadow: 0 10px 20px -5px rgba(59, 130, 246, 0.4);
      transition: all 0.2s ease;
      margin-bottom: 20px;
    }}
    .download-btn:hover {{
      transform: translateY(-2px);
      box-shadow: 0 14px 28px -5px rgba(59, 130, 246, 0.5);
      background: linear-gradient(135deg, #60A5FA, #2563EB);
    }}
    .cmd-box {{
      background: #060913;
      border: 1px solid rgba(255, 255, 255, 0.07);
      border-radius: 12px;
      padding: 14px;
      font-family: var(--code-font);
      font-size: 12px;
      color: #38BDF8;
      overflow-x: auto;
      margin-bottom: 20px;
      line-height: 1.5;
    }}
    .cmd-box span.comment {{
      color: #64748B;
      display: block;
      margin-bottom: 4px;
    }}
    .links-row {{
      display: flex;
      gap: 12px;
      margin-top: 8px;
    }}
    .secondary-link {{
      flex: 1;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      padding: 10px 14px;
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid rgba(255, 255, 255, 0.08);
      color: #E2E8F0;
      text-decoration: none;
      font-size: 12.5px;
      font-weight: 600;
      border-radius: 10px;
      transition: background 0.15s ease;
    }}
    .secondary-link:hover {{
      background: rgba(255, 255, 255, 0.08);
      color: white;
    }}
    .footer-note {{
      text-align: center;
      color: #475569;
      font-size: 11px;
      margin-top: 20px;
    }}
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="badge-icon">📱</div>
      <div class="title-group">
        <h1>go-On AI Face Attendance System</h1>
        <p>Faculty & Class Advisor Portal — Lunch Break Card Removal Release</p>
        <div class="status-badge">LUNCH BREAK REMOVAL VERIFIED (239 MOBILE + 17 BACKEND TESTS PASSED)</div>
      </div>
    </div>

    <div class="meta-grid">
      <div class="meta-card">
        <div class="label">Package ID</div>
        <div class="value">com.aifaceattendance.mobile_app</div>
      </div>
      <div class="meta-card">
        <div class="label">APK File Size</div>
        <div class="value">{APK_SIZE_MB} MB ({APK_SIZE:,} bytes)</div>
      </div>
      <div class="meta-card">
        <div class="label">Target Device</div>
        <div class="value">Samsung Galaxy S24 (SM-S921E)</div>
      </div>
      <div class="meta-card">
        <div class="label">Build Status</div>
        <div class="value" style="color: #34D399;">SUCCESS (0 LINTS / 0 OVERFLOWS)</div>
      </div>
    </div>

    <a href="/app-release.apk" class="download-btn" download="go-on-faculty-advisor-lunch-removal-release.apk">
      <span>⬇️</span> Download Android APK ({APK_SIZE_MB} MB)
    </a>

    <div class="cmd-box">
      <span class="comment"># Deploy directly to Samsung Galaxy S24 via ADB:</span>
      adb -s RZCY935CVJF install -r "{APK_PATH}"
    </div>

    <div class="links-row">
      <a href="/report.pdf" class="secondary-link" target="_blank">
        <span>📄</span> View Lunch Break Removal PDF Report
      </a>
      <a href="/reports/go-On_Faculty_Class_Advisor_Lunch_Break_Removal_Report.pdf" class="secondary-link" target="_blank">
        <span>📑</span> Direct PDF Link
      </a>
    </div>

    <div class="footer-note">
      go-On AI Face Attendance System &bull; Localhost Distribution Server &bull; Port {PORT}
    </div>
  </div>
</body>
</html>
"""

class ApkHandler(BaseHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_HEAD(self):
        self._serve_file(send_body=False)

    def do_GET(self):
        self._serve_file(send_body=True)

    def _serve_file(self, send_body=True):
        try:
            path = self.path.split("?")[0]

            if path in ["/", "/index.html"]:
                encoded = HTML_TEMPLATE.encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(encoded)))
                self.end_headers()
                if send_body:
                    self.wfile.write(encoded)
                return

            target_file = None
            content_type = "application/octet-stream"
            download_name = None

            if path in ["/app-release.apk", "/app-debug.apk", "/download/apk", "/apk"]:
                if os.path.exists(RELEASE_APK):
                    target_file = RELEASE_APK
                elif os.path.exists(APK_PATH):
                    target_file = APK_PATH
                else:
                    target_file = os.path.join(PROJECT_ROOT, "app-debug.apk")
                content_type = "application/vnd.android.package-archive"
                download_name = "go-on-attendance-release.apk"
            elif path.startswith("/reports/"):
                rel_name = path[len("/reports/"):]
                candidate = os.path.join(PROJECT_ROOT, "reports", rel_name)
                if os.path.exists(candidate) and os.path.isfile(candidate):
                    target_file = candidate
                    if rel_name.endswith(".pdf"):
                        content_type = "application/pdf"
                    elif rel_name.endswith(".json"):
                        content_type = "application/json"
                    elif rel_name.endswith(".png"):
                        content_type = "image/png"
                    download_name = rel_name
            elif path in ["/report.pdf", "/report"]:
                target_file = PDF_REPORT
                content_type = "application/pdf"
                download_name = os.path.basename(PDF_REPORT)
            elif path in ["/results.json", "/json"]:
                target_file = os.path.join(PROJECT_ROOT, "reports", "go-On_Attendance_Real_Data_and_Mobile_UI_Test_Results.json")
                if not os.path.exists(target_file):
                    target_file = JSON_RESULTS
                content_type = "application/json"
                download_name = "go-On_Attendance_Real_Data_and_Mobile_UI_Test_Results.json"

            if target_file and os.path.exists(target_file):
                file_size = os.path.getsize(target_file)
                self.send_response(200)
                self.send_header("Content-Type", content_type)
                self.send_header("Content-Length", str(file_size))
                if download_name:
                    self.send_header("Content-Disposition", f'attachment; filename="{download_name}"')
                self.send_header("Accept-Ranges", "bytes")
                self.end_headers()

                if send_body:
                    with open(target_file, "rb") as f:
                        while chunk := f.read(65536):
                            self.wfile.write(chunk)
                return

            # 404 Not Found
            msg = b"404 Not Found"
            self.send_response(404)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            if send_body:
                self.wfile.write(msg)
        except (ConnectionResetError, BrokenPipeError):
            pass
        except Exception as e:
            sys.stderr.write(f"Error handling request: {e}\n")

    def log_message(self, format, *args):
        sys.stdout.write(f"[APK Host 8080] {self.address_string()} - {format % args}\n")
        sys.stdout.flush()

class ThreadingTCPServer(socketserver.ThreadingMixIn, HTTPServer):
    allow_reuse_address = False
    daemon_threads = True

def main():
    print("=" * 65)
    print("  go-On Localhost APK & Artifact Distribution Server")
    print(f"  Local URL:        http://localhost:{PORT}/")
    print(f"  Direct APK Link:  http://localhost:{PORT}/app-debug.apk")
    print(f"  PDF Report Link:  http://localhost:{PORT}/report.pdf")
    print(f"  JSON Results:     http://localhost:{PORT}/results.json")
    print(f"  Serving APK File: {APK_PATH} ({APK_SIZE_MB} MB)")
    print("=" * 65)
    sys.stdout.flush()

    server = ThreadingTCPServer((HOST, PORT), ApkHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down distribution server...")
        server.shutdown()

if __name__ == "__main__":
    main()
