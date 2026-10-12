from fastapi import APIRouter
from app.api.auth import router as auth_router
from app.api.admin import router as admin_router
from app.api.faculty import router as faculty_router
from app.api.faculty_sessions import router as faculty_sessions_router
from app.api.admin_sessions import router as admin_sessions_router
from app.api.admin_enrollment import router as admin_enrollment_router
from app.api.faculty_recognition import router as faculty_recognition_router, batch_router as faculty_batch_recognition_router
from app.api.faculty_reports_export import router as faculty_reports_export_router
from app.api.student import router as student_router
from app.api.admin_settings import router as admin_settings_router
from app.api.admin_settings import audit_router as audit_router
from app.api.notifications import router as notifications_router, admin_router as admin_notifications_router

api_router = APIRouter()
api_router.include_router(auth_router)
api_router.include_router(admin_router)
api_router.include_router(faculty_router)
api_router.include_router(faculty_sessions_router)
api_router.include_router(admin_sessions_router)
api_router.include_router(admin_enrollment_router)
api_router.include_router(faculty_recognition_router)
api_router.include_router(faculty_batch_recognition_router)
api_router.include_router(faculty_reports_export_router)
# M4
api_router.include_router(student_router)
api_router.include_router(admin_settings_router)
api_router.include_router(audit_router)
# Phase 11: Push Notifications & Reminders
api_router.include_router(notifications_router)
api_router.include_router(admin_notifications_router)

@api_router.get("/health")
def api_health_check():
    return {"status": "ok", "api": "v1"}
