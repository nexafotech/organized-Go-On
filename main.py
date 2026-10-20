"""
go-On Catalyst AppSail Production Entry Point
"""
import os
import sys
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("appsail")

# Resolve base and bundled lib paths
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LIB_DIR = os.path.join(BASE_DIR, "lib")
if os.path.exists(LIB_DIR) and LIB_DIR not in sys.path:
    sys.path.insert(0, LIB_DIR)
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

raw_port = (
    os.environ.get("X_ZOHO_CATALYST_LISTEN_PORT")
    or os.environ.get("PORT")
    or "9000"
)
try:
    PORT = int(raw_port)
except ValueError:
    PORT = 9000

HOST = "0.0.0.0"

if __name__ == "__main__":
    try:
        import uvicorn
        from app.main import app

        logger.info("Starting go-On backend server on %s:%d (Environment: %s)", HOST, PORT, os.environ.get("ENVIRONMENT", "staging"))
        sys.stdout.flush()

        uvicorn.run(
            app,
            host=HOST,
            port=PORT,
            proxy_headers=True,
            forwarded_allow_ips="*",
            log_level="info"
        )
    except Exception as e:
        logger.critical("Fatal startup failure: %s", str(e), exc_info=True)
        sys.stderr.flush()
        # Clean exit with error code - never spoof healthy status with diagnostic fallback server
        sys.exit(1)
