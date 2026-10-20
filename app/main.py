import os
from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.database import engine, Base, init_db
from app.api import api_router

# Ensure DB tables are created and migrated
init_db(engine)

import asyncio
import logging
from contextlib import asynccontextmanager

scheduler_logger = logging.getLogger("scheduler")

async def next_class_reminder_scheduler_loop():
    """
    Lightweight, efficient periodic scheduler running every 60 seconds
    to check timetable windows and dispatch next-class reminders in Asia/Kolkata timezone.
    """
    while True:
        try:
            await asyncio.sleep(60)
            from app.core.database import SessionLocal
            from app.services.notification_service import NotificationService
            db = SessionLocal()
            try:
                NotificationService.process_due_scheduled_notifications(db)
                NotificationService.check_and_send_next_class_reminders(db)
            finally:
                db.close()
        except asyncio.CancelledError:
            break
        except Exception as e:
            scheduler_logger.warning("Next-class scheduler loop encountered error: %s", e)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Launch background scheduler task
    task = asyncio.create_task(next_class_reminder_scheduler_loop())
    yield
    # Shutdown: Cancel background scheduler task
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan,
)

# CORS middleware setup - restrict origins safely when credentials are enabled
cors_origins = list(settings.CORS_ALLOWED_ORIGINS)
env_cors = os.getenv("CORS_ORIGINS", "")
if env_cors:
    for origin in env_cors.split(","):
        o = origin.strip()
        if o and o not in cors_origins:
            cors_origins.append(o)

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_origin_regex=settings.CORS_ORIGIN_REGEX,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["*"],
)

# Mount Static Files
static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")

# Register API Router
app.include_router(api_router, prefix=settings.API_V1_STR)

from app.api.admin_web import router as admin_web_router
app.include_router(admin_web_router)

from fastapi import Response, status
from sqlalchemy import text

@app.get("/health")
def health_check():
    """Basic liveness probe."""
    return {"status": "ok", "project": settings.PROJECT_NAME, "version": settings.VERSION}

@app.get("/health/live")
def liveness_check():
    """Liveness probe verifying HTTP server responsiveness."""
    return {"status": "alive", "project": settings.PROJECT_NAME}

@app.get("/health/ready")
def readiness_check(response: Response):
    """Readiness probe verifying database connectivity."""
    try:
        from app.core.database import SessionLocal
        db = SessionLocal()
        try:
            db.execute(text("SELECT 1"))
            return {
                "status": "ready",
                "database": "connected",
                "project": settings.PROJECT_NAME,
                "version": settings.VERSION
            }
        finally:
            db.close()
    except Exception as e:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {
            "status": "not_ready",
            "database": "disconnected",
            "error": "Database connectivity check failed"
        }

# Mount Flutter Web Application (if built)
flutter_web_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "mobile", "build", "web")
if os.path.exists(flutter_web_dir):
    app.mount("/", StaticFiles(directory=flutter_web_dir, html=True), name="flutter_web")
else:
    @app.get("/", response_class=HTMLResponse)
    def index(request: Request):
        template_path = os.path.join(os.path.dirname(__file__), "templates", "index.html")
        if os.path.exists(template_path):
            with open(template_path, "r", encoding="utf-8") as f:
                return f.read()
        return "<h1>Go-On Attendance System API Backend</h1><p>Visit <a href='/docs'>/docs</a> for API documentation.</p>"
