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

# CORS middleware setup
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
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

@app.get("/health")
def health_check():
    return {"status": "ok", "project": settings.PROJECT_NAME, "version": settings.VERSION}

@app.get("/", response_class=HTMLResponse)
def index(request: Request):
    template_path = os.path.join(os.path.dirname(__file__), "templates", "index.html")
    if os.path.exists(template_path):
        with open(template_path, "r", encoding="utf-8") as f:
            return f.read()
    return "<h1>Go-On Attendance System API Backend</h1><p>Visit <a href='/docs'>/docs</a> for API documentation.</p>"
