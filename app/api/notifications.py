import logging
from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.user import User
from app.models.notification import NotificationLog, NotificationType, ScheduledNotification, DeviceToken
from app.schemas.notification import (
    DeviceTokenCreate, DeviceTokenOut,
    NotificationSettingsOut, NotificationSettingsUpdate,
    AdminCustomNotificationCreate, AdminCustomNotificationResponse,
    NotificationLogOut, NextClassReminderCheckResult,
    ScheduledNotificationOut,
    UnreadCountOut, NotificationActionResponse,
)
from app.api.deps import get_current_user, require_admin
from app.services.notification_service import NotificationService, TIMEZONE_KOLKATA

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/notifications", tags=["Notifications"])
admin_router = APIRouter(prefix="/admin/notifications", tags=["Admin Notifications"])


# ─────────────────────────────────────────────────────────────────────────────
# User Device Token Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/device-token")
def register_device_token(
    payload: DeviceTokenCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Registers an FCM device token for the currently authenticated user.
    """
    dev = NotificationService.register_device_token(
        db=db,
        user_id=current_user.id,
        token=payload.token,
        platform=payload.platform,
        device_name=payload.device_name,
    )
    return {
        "success": True,
        "token_id": dev.id,
        "platform": dev.platform,
        "device_name": dev.device_name,
        "message": "Device token successfully registered",
    }


@router.delete("/device-token")
def unregister_device_token(
    token: str = Query(..., min_length=10),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Deactivates a device token upon logout, securely scoped to the current authenticated user.
    """
    success = NotificationService.deactivate_device_token(db=db, token=token, user_id=current_user.id)
    return {
        "success": success,
        "message": "Device token deactivated" if success else "Token not found or not owned by user",
    }


@router.get("/my-devices", response_model=List[DeviceTokenOut])
def get_my_devices(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Returns all active registered devices for the current user.
    """
    return NotificationService.get_user_device_tokens(db=db, user_id=current_user.id)


@router.get("/history", response_model=List[NotificationLogOut])
def get_my_notification_history(
    skip: int = Query(0, ge=0, description="Pagination offset"),
    limit: int = Query(50, ge=1, le=100, description="Items per page"),
    unread_only: bool = Query(False, description="Filter only unread notifications"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Returns recent notifications delivered to the current authenticated user.
    Strictly isolated: never exposes notifications from another user.
    """
    query = db.query(NotificationLog).filter(NotificationLog.user_id == current_user.id)
    if unread_only:
        query = query.filter(NotificationLog.is_read == False)
    logs = (
        query
        .order_by(NotificationLog.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return logs


@router.get("/unread-count", response_model=UnreadCountOut)
def get_my_unread_count(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Returns the total unread notification count for the current authenticated user.
    """
    count = NotificationService.get_unread_count(db=db, user_id=current_user.id)
    return {"unread_count": count}


@router.post("/{log_id}/read", response_model=NotificationActionResponse)
def mark_notification_read(
    log_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Marks a notification as read if it belongs to current authenticated user.
    """
    success = NotificationService.mark_notification_as_read(db=db, log_id=log_id, user_id=current_user.id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found or access denied",
        )
    return {
        "success": True,
        "id": log_id,
        "message": "Notification marked as read",
    }


@router.post("/read-all", response_model=NotificationActionResponse)
def mark_all_notifications_read(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Marks all notifications for the current authenticated user as read.
    """
    count = NotificationService.mark_all_notifications_as_read(db=db, user_id=current_user.id)
    return {
        "success": True,
        "count": count,
        "message": f"{count} notifications marked as read",
    }


# ─────────────────────────────────────────────────────────────────────────────
# Admin Notification Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@admin_router.get("/metrics")
def get_notification_metrics(
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Retrieves summary metrics for the Admin Notification Center:
    Active registered device tokens, total dispatched logs, pending scheduled items,
    and reminder configuration state.
    """
    active_tokens = db.query(DeviceToken).filter(DeviceToken.is_active == True).count()
    total_logs = db.query(NotificationLog).count()
    pending_scheduled = db.query(ScheduledNotification).filter(ScheduledNotification.status == "PENDING").count()
    settings = NotificationService.get_settings(db)
    return {
        "active_device_tokens": active_tokens,
        "total_dispatched_logs": total_logs,
        "pending_scheduled": pending_scheduled,
        "student_next_class_enabled": bool(settings.get("student_next_class_enabled", True)),
        "student_next_class_lead_minutes": int(settings.get("student_next_class_lead_minutes", 10)),
        "faculty_next_class_enabled": bool(settings.get("faculty_next_class_enabled", True)),
        "faculty_next_class_lead_minutes": int(settings.get("faculty_next_class_lead_minutes", 15)),
        "attendance_status_enabled": bool(settings.get("attendance_status_enabled", True)),
        "admin_announcements_enabled": bool(settings.get("admin_announcements_enabled", True)),
    }


@admin_router.get("/settings", response_model=NotificationSettingsOut)
def get_notification_settings(
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Retrieves current Admin notification configuration.
    """
    settings = NotificationService.get_settings(db)
    return NotificationSettingsOut(**settings)


@admin_router.put("/settings", response_model=NotificationSettingsOut)
def update_notification_settings(
    payload: NotificationSettingsUpdate,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Updates Admin notification configuration (independent student/faculty lead times and switches).
    """
    updates = payload.model_dump(exclude_unset=True)
    updated = NotificationService.update_settings(db, updates)
    return NotificationSettingsOut(**updated)


@admin_router.post("/send", response_model=AdminCustomNotificationResponse)
def send_custom_notification(
    payload: AdminCustomNotificationCreate,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Admin sends custom notification targeting Students, Faculty, or All users.
    Supports targeting by Class or specific User, with safe template substitution.
    """
    try:
        res = NotificationService.send_custom_admin_notification(
            db=db,
            admin_user=admin,
            audience=payload.audience,
            target_type=payload.target_type,
            target_id=payload.target_id,
            title=payload.title,
            body=payload.body,
            channel=payload.channel,
            priority=payload.priority,
            route=payload.route,
            scheduled_at=payload.scheduled_at,
        )
        return AdminCustomNotificationResponse(**res)
    except ValueError as val_err:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(val_err))
    except Exception as exc:
        logger.exception("Failed to send custom notification: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Notification sending failed: {str(exc)}",
        )


@admin_router.get("/scheduled", response_model=List[ScheduledNotificationOut])
def get_scheduled_notifications(
    status_filter: Optional[str] = Query(None, description="Optional status filter (PENDING, SENT, CANCELLED)"),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Retrieves pending or past scheduled notifications created by administrators.
    """
    query = db.query(ScheduledNotification)
    if status_filter:
        query = query.filter(ScheduledNotification.status == status_filter.upper())
    return query.order_by(ScheduledNotification.scheduled_at.desc()).limit(100).all()


@admin_router.delete("/scheduled/{schedule_id}")
def cancel_scheduled_notification(
    schedule_id: int,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Cancels a pending scheduled notification.
    """
    success = NotificationService.cancel_scheduled_notification(db=db, sched_id=schedule_id, admin_user=admin)
    if not success:
        raise HTTPException(status_code=404, detail="Scheduled notification not found or already processed")
    return {"success": True, "message": f"Scheduled notification {schedule_id} cancelled"}


@admin_router.post("/trigger-reminders", response_model=NextClassReminderCheckResult)
def trigger_next_class_reminders(
    reference_time: Optional[str] = Query(None, description="Optional ISO or HH:MM reference time for simulation"),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Triggers an on-demand check of the Next-Class Reminder Engine.
    Uses Asia/Kolkata timezone and timetable source of truth.
    """
    ref_dt = None
    if reference_time:
        try:
            if "T" in reference_time:
                ref_dt = datetime.fromisoformat(reference_time).replace(tzinfo=TIMEZONE_KOLKATA)
            elif ":" in reference_time:
                now_k = datetime.now(TIMEZONE_KOLKATA)
                parts = reference_time.split(":")
                ref_dt = now_k.replace(hour=int(parts[0]), minute=int(parts[1]), second=0)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Invalid reference_time format: {e}")

    result = NotificationService.check_and_send_next_class_reminders(db=db, reference_dt=ref_dt)
    return NextClassReminderCheckResult(**result)


@admin_router.get("/logs", response_model=List[NotificationLogOut])
def get_notification_logs(
    notification_type: Optional[str] = Query(None),
    limit: int = Query(100, ge=1, le=500),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Retrieves system notification logs for Admin inspection and verification.
    """
    query = db.query(NotificationLog)
    if notification_type:
        query = query.filter(NotificationLog.notification_type == notification_type)
    return query.order_by(NotificationLog.created_at.desc()).limit(limit).all()

