"""
Zoho Catalyst AppSail Production/Staging Entry Point for go-On Backend.
Dynamically binds to $X_ZOHO_CATALYST_LISTEN_PORT, $PORT, or default 9000.
Loads bundled Linux dependencies from ./lib.
"""
import os
import sys
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("appsail")

# Add bundled library path to sys.path
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB_DIR = os.path.join(BASE_DIR, "lib")
if os.path.exists(LIB_DIR) and LIB_DIR not in sys.path:
    sys.path.insert(0, LIB_DIR)
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

def main():
    raw_port = (
        os.environ.get("X_ZOHO_CATALYST_LISTEN_PORT")
        or os.environ.get("PORT")
        or "9000"
    )
    try:
        port = int(raw_port)
    except ValueError:
        port = 9000

    host = os.environ.get("HOST", "0.0.0.0")

    try:
        import uvicorn
        from app.main import app

        logger.info("Starting go-On backend on %s:%d (Environment: %s)", host, port, os.environ.get("ENVIRONMENT", "staging"))
        sys.stdout.flush()

        uvicorn.run(
            app,
            host=host,
            port=port,
            proxy_headers=True,
            forwarded_allow_ips="*",
            log_level="info"
        )
    except Exception as e:
        logger.critical("Fatal startup failure: %s", str(e), exc_info=True)
        sys.stderr.flush()
        # Clean non-zero exit on failure
        sys.exit(1)

if __name__ == "__main__":
    main()
