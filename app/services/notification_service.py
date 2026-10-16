import json
import logging
import re
from datetime import datetime, date, timedelta, timezone
from typing import Dict, Any, List, Optional, Tuple
from zoneinfo import ZoneInfo
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func

from app.models.notification import (
    DeviceToken, NotificationLog, NotificationType, NotificationChannel,
    NotificationDeliveryStatus, ScheduledNotification,
)
from app.models.policy import SystemSetting
from app.models.academic import TimetableEntry, Period, FacultyAssignment, ClassSection, Subject, assignment_authorized_faculty
from app.models.student import Student
from app.models.user import User, Faculty, UserRole
from app.models.audit import AuditLog
from app.services.fcm_service import FCMService

logger = logging.getLogger(__name__)

TIMEZONE_KOLKATA = ZoneInfo("Asia/Kolkata")

# Default notification settings keys & values
DEFAULT_NOTIFICATION_SETTINGS = {
    "notification.student_next_class_enabled": ("true", "Enable automatic next-class reminders for students"),
    "notification.student_next_class_lead_minutes": ("10", "Minutes before class to notify students (e.g. 5, 10, 15, 20, 30)"),
    "notification.faculty_next_class_enabled": ("true", "Enable automatic next-class reminders for faculty"),
    "notification.faculty_next_class_lead_minutes": ("15", "Minutes before class to notify faculty (e.g. 5, 10, 15, 20, 30)"),
    "notification.attendance_status_enabled": ("true", "Enable notifications for attendance markings and updates"),
    "notification.admin_announcements_enabled": ("true", "Enable custom broadcast announcements from admin"),
}


def get_kolkata_now() -> datetime:
    """Returns the current datetime in Asia/Kolkata timezone."""
    return datetime.now(TIMEZONE_KOLKATA)


def format_time_12hr(time_str: str) -> str:
    """Converts 24-hr HH:MM string to readable 12-hr format (e.g., '09:10' -> '9:10 AM', '13:40' -> '1:40 PM')."""
    try:
        t = datetime.strptime(time_str.strip(), "%H:%M")
        # Format as e.g. '9:10 AM' without leading zero on hour
        hour = t.hour % 12 or 12
        ampm = "AM" if t.hour < 12 else "PM"
        return f"{hour}:{t.minute:02d} {ampm}"
    except Exception:
        return time_str


def parse_hhmm(time_str: str) -> Tuple[int, int]:
    """Parses 'HH:MM' string to (hour, minute) integers."""
    parts = time_str.strip().split(":")
    return int(parts[0]), int(parts[1])


def is_break_or_lunch(subject_name: Optional[str], subject_code: Optional[str]) -> bool:
    """
    Checks if a period represents a break, lunch, or non-teaching interval.
    These must NEVER be targeted for next-class reminders.
    """
    s_name = (subject_name or "").lower()
    s_code = (subject_code or "").lower()
    excluded_keywords = ["break", "lunch", "interval", "recess", "tea"]
    return any(k in s_name or k in s_code for k in excluded_keywords)


def substitute_template(
    template_str: str,
    context: Dict[str, str],
) -> str:
    """
    Safely substitutes {{variable}} tags using values from context dictionary.
    Unknown or missing tags are replaced with empty string or left benignly.
    """
    result = template_str
    for key, val in context.items():
        result = re.sub(r"\{\{\s*" + re.escape(key) + r"\s*\}\}", str(val), result)
    # Remove any unreplaced {{variable}} safely
    result = re.sub(r"\{\{\s*[\w.-]+\s*\}\}", "", result)
    return result.strip()


class NotificationService:
    @staticmethod
    def get_settings(db: Session) -> Dict[str, Any]:
        """Returns current notification settings from SystemSetting table."""
        res = {}
        for key, (default_val, desc) in DEFAULT_NOTIFICATION_SETTINGS.items():
            setting = db.query(SystemSetting).filter(SystemSetting.key == key).first()
            val = setting.value if setting else default_val
            short_key = key.replace("notification.", "")
            if "enabled" in short_key:
                res[short_key] = val.lower() == "true"
            elif "lead_minutes" in short_key:
                try:
                    res[short_key] = int(val)
                except ValueError:
                    res[short_key] = int(default_val)
            else:
                res[short_key] = val
        return res

    @staticmethod
    def update_settings(db: Session, updates: Dict[str, Any]) -> Dict[str, Any]:
        """Updates notification settings in SystemSetting table."""
        for key_suffix, new_val in updates.items():
            if new_val is None:
                continue
            full_key = f"notification.{key_suffix}"
            if full_key in DEFAULT_NOTIFICATION_SETTINGS:
                setting = db.query(SystemSetting).filter(SystemSetting.key == full_key).first()
                str_val = str(new_val).lower() if isinstance(new_val, bool) else str(new_val)
                if setting:
                    setting.value = str_val
                    setting.updated_at = datetime.now(timezone.utc)
                else:
                    setting = SystemSetting(
                        key=full_key,
                        value=str_val,
                        description=DEFAULT_NOTIFICATION_SETTINGS[full_key][1],
                    )
                    db.add(setting)
        db.commit()
        return NotificationService.get_settings(db)

    @staticmethod
    def register_device_token(
        db: Session,
        user_id: int,
        token: str,
        platform: str = "android",
        device_name: Optional[str] = None,
    ) -> DeviceToken:
        """
        Registers or updates an FCM device token for a user.
        If the token exists for another user or inactive, updates ownership and reactivates.
        """
        token = token.strip()
        existing = db.query(DeviceToken).filter(DeviceToken.token == token).first()
        if existing:
            existing.user_id = user_id
            existing.platform = platform
            if device_name:
                existing.device_name = device_name
            existing.is_active = True
            existing.updated_at = datetime.now(timezone.utc)
            db.commit()
            db.refresh(existing)
            return existing

        dev = DeviceToken(
            user_id=user_id,
            token=token,
            platform=platform,
            device_name=device_name,
            is_active=True,
        )
        db.add(dev)
        db.commit()
        db.refresh(dev)
        return dev

    @staticmethod
    def deactivate_device_token(db: Session, token: str, user_id: Optional[int] = None) -> bool:
        """Deactivates a device token (e.g. on logout), enforcing user ownership if user_id is provided."""
        token = token.strip()
        query = db.query(DeviceToken).filter(DeviceToken.token == token)
        if user_id is not None:
            query = query.filter(DeviceToken.user_id == user_id)
        updated = query.update({"is_active": False})
        db.commit()
        return updated > 0

    @staticmethod
    def get_unread_count(db: Session, user_id: int) -> int:
        """Returns the number of unread notifications for a user, excluding soft-deleted items."""
        return db.query(NotificationLog).filter(
            NotificationLog.user_id == user_id,
            NotificationLog.is_read == False,
            NotificationLog.is_deleted == False,
        ).count()

    @staticmethod
    def get_user_notification_history(
        db: Session,
        user_id: int,
        skip: int = 0,
        limit: int = 50,
        unread_only: bool = False,
    ) -> List[NotificationLog]:
        """
        Returns notifications for the user, strictly excluding soft-deleted items.
        Sorted deterministically:
        1. Pinned notifications first (ordered by pinned_at.desc(), then created_at.desc())
        2. Unpinned notifications (ordered by created_at.desc())
        """
        query = db.query(NotificationLog).filter(
            NotificationLog.user_id == user_id,
            NotificationLog.is_deleted == False,
        )
        if unread_only:
            query = query.filter(NotificationLog.is_read == False)
        return (
            query
            .order_by(
                NotificationLog.is_pinned.desc(),
                NotificationLog.pinned_at.desc(),
                NotificationLog.created_at.desc(),
            )
            .offset(skip)
            .limit(limit)
            .all()
        )

    @staticmethod
    def soft_delete_notification(db: Session, log_id: int, user_id: int) -> bool:
        """
        Soft-deletes a notification for the authenticated user so it never reappears
        in the user's inbox, while preserving audit/admin history.
        Strictly preserves pinned notifications (returns False if pinned).
        """
        log = db.query(NotificationLog).filter(
            NotificationLog.id == log_id,
            NotificationLog.user_id == user_id,
            NotificationLog.is_deleted == False,
        ).first()
        if not log:
            return False
        if log.is_pinned:
            # Pinned notifications are strictly protected from deletion
            return False
        log.is_deleted = True
        log.deleted_at = datetime.now(timezone.utc)
        db.commit()
        return True

    @staticmethod
    def delete_all_unpinned_notifications(db: Session, user_id: int) -> dict:
        """
        Transactional bulk soft-deletion of all unpinned notifications for the authenticated user.
        Strictly preserves every pinned notification.
        Preserves administrative audit history while ensuring unpinned notifications
        never reappear in the user's inbox, counts, or history.
        """
        try:
            now = datetime.now(timezone.utc)
            pinned_count = db.query(NotificationLog).filter(
                NotificationLog.user_id == user_id,
                NotificationLog.is_deleted == False,
                NotificationLog.is_pinned == True,
            ).count()

            unpinned_query = db.query(NotificationLog).filter(
                NotificationLog.user_id == user_id,
                NotificationLog.is_deleted == False,
                NotificationLog.is_pinned == False,
            )

            deleted_count = unpinned_query.update(
                {
                    NotificationLog.is_deleted: True,
                    NotificationLog.deleted_at: now,
                },
                synchronize_session="fetch",
            )
            db.commit()

            return {
                "success": True,
                "deleted_count": deleted_count,
                "pinned_preserved_count": pinned_count,
                "message": f"Successfully deleted {deleted_count} unpinned notification(s). Kept {pinned_count} pinned notification(s).",
            }
        except Exception:
            db.rollback()
            raise

    @staticmethod
    def pin_notification(db: Session, log_id: int, user_id: int) -> bool:
        """
        Pins a notification to the top for the authenticated user.
        """
        log = db.query(NotificationLog).filter(
            NotificationLog.id == log_id,
            NotificationLog.user_id == user_id,
            NotificationLog.is_deleted == False,
        ).first()
        if not log:
            return False
        log.is_pinned = True
        log.pinned_at = datetime.now(timezone.utc)
        db.commit()
        return True

    @staticmethod
    def unpin_notification(db: Session, log_id: int, user_id: int) -> bool:
        """
        Unpins a notification for the authenticated user.
        """
        log = db.query(NotificationLog).filter(
            NotificationLog.id == log_id,
            NotificationLog.user_id == user_id,
            NotificationLog.is_deleted == False,
        ).first()
        if not log:
            return False
        log.is_pinned = False
        log.pinned_at = None
        db.commit()
        return True

    @staticmethod
    def mark_notification_as_read(db: Session, log_id: int, user_id: int) -> bool:
        """Marks a specific notification as read for the user."""
        log = db.query(NotificationLog).filter(
            NotificationLog.id == log_id,
            NotificationLog.user_id == user_id,
            NotificationLog.is_deleted == False,
        ).first()
        if not log:
            return False
        if not log.is_read:
            log.is_read = True
            log.read_at = datetime.now(timezone.utc)
            db.commit()
        return True

    @staticmethod
    def mark_all_notifications_as_read(db: Session, user_id: int) -> int:
        """Marks all notifications as read for a user."""
        now = datetime.now(timezone.utc)
        updated = db.query(NotificationLog).filter(
            NotificationLog.user_id == user_id,
            NotificationLog.is_read == False,
            NotificationLog.is_deleted == False,
        ).update({"is_read": True, "read_at": now})
        db.commit()
        return updated

    @staticmethod
    def get_user_device_tokens(db: Session, user_id: int) -> List[DeviceToken]:
        """Returns all active device tokens for a given user."""
        return db.query(DeviceToken).filter(DeviceToken.user_id == user_id, DeviceToken.is_active == True).all()

    @staticmethod
    def find_student_next_class(
        db: Session,
        student: Student,
        current_dt: Optional[datetime] = None,
    ) -> Optional[Tuple[TimetableEntry, Period, Subject, ClassSection]]:
        """
        Finds the next upcoming teaching period for a student today, excluding breaks and lunch.
        """
        if not student.class_id:
            return None

        current_dt = current_dt or get_kolkata_now()
        day_name = current_dt.strftime("%A")  # e.g., 'Monday'
        current_minutes = current_dt.hour * 60 + current_dt.minute

        # Fetch timetable entries for the student's class section today
        entries = (
            db.query(TimetableEntry, Period, Subject, ClassSection)
            .join(Period, TimetableEntry.period_id == Period.id)
            .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
            .join(Subject, FacultyAssignment.subject_id == Subject.id)
            .join(ClassSection, FacultyAssignment.class_id == ClassSection.id)
            .filter(
                FacultyAssignment.class_id == student.class_id,
                TimetableEntry.day_of_week == day_name,
            )
            .order_by(Period.start_time.asc())
            .all()
        )

        for entry, period, subject, class_section in entries:
            # Exclude break and lunch
            if is_break_or_lunch(subject.name, subject.code):
                continue

            sh, sm = parse_hhmm(period.start_time)
            period_start_minutes = sh * 60 + sm

            # Next class must be in the future
            if period_start_minutes > current_minutes:
                return entry, period, subject, class_section

        return None

    @staticmethod
    def find_faculty_next_class(
        db: Session,
        faculty: Faculty,
        current_dt: Optional[datetime] = None,
    ) -> Optional[Tuple[TimetableEntry, Period, Subject, ClassSection]]:
        """
        Finds the next upcoming teaching period for a faculty member today, excluding breaks and lunch.
        """
        current_dt = current_dt or get_kolkata_now()
        day_name = current_dt.strftime("%A")
        current_minutes = current_dt.hour * 60 + current_dt.minute

        # Fetch timetable entries for this faculty's assignments today
        # Check both primary faculty and co-authorized faculty
        entries = (
            db.query(TimetableEntry, Period, Subject, ClassSection, FacultyAssignment)
            .join(Period, TimetableEntry.period_id == Period.id)
            .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
            .join(Subject, FacultyAssignment.subject_id == Subject.id)
            .join(ClassSection, FacultyAssignment.class_id == ClassSection.id)
            .filter(TimetableEntry.day_of_week == day_name)
            .order_by(Period.start_time.asc())
            .all()
        )

        for entry, period, subject, class_section, assignment in entries:
            # Check if this assignment belongs to this faculty
            if not assignment.is_faculty_authorized(faculty.id):
                continue

            # Exclude break and lunch
            if is_break_or_lunch(subject.name, subject.code):
                continue

            sh, sm = parse_hhmm(period.start_time)
            period_start_minutes = sh * 60 + sm

            if period_start_minutes > current_minutes:
                return entry, period, subject, class_section

        return None

    @staticmethod
    def check_and_send_next_class_reminders(
        db: Session,
        reference_dt: Optional[datetime] = None,
    ) -> Dict[str, Any]:
        """
        Authoritative engine that checks timetable for both Students and Faculty
        and sends reminders within the configured lead time windows.
        Idempotent: will never send duplicate notifications for the same user, date, and timetable entry.
        """
        now_dt = reference_dt or get_kolkata_now()
        date_str = now_dt.strftime("%Y-%m-%d")
        current_minutes = now_dt.hour * 60 + now_dt.minute

        settings = NotificationService.get_settings(db)
        student_enabled = settings.get("student_next_class_enabled", True)
        student_lead = settings.get("student_next_class_lead_minutes", 10)
        faculty_enabled = settings.get("faculty_next_class_enabled", True)
        faculty_lead = settings.get("faculty_next_class_lead_minutes", 15)

        student_sent = 0
        student_skipped = 0
        faculty_sent = 0
        faculty_skipped = 0
        details = []

        # -------------------------------------------------------------
        # 1. PROCESS STUDENT NEXT-CLASS REMINDERS
        # -------------------------------------------------------------
        if student_enabled:
            # Get all active students with a linked user account
            students = (
                db.query(Student)
                .filter(Student.is_active == True, Student.user_id != None)
                .all()
            )

            for stu in students:
                next_class_info = NotificationService.find_student_next_class(db, stu, now_dt)
                if not next_class_info:
                    continue

                entry, period, subject, class_sec = next_class_info
                sh, sm = parse_hhmm(period.start_time)
                start_minutes = sh * 60 + sm
                window_start = start_minutes - student_lead

                # Only send if current time is within [start_time - lead_time, start_time)
                # If current_minutes >= start_minutes, class already started (Section 43: do not send)
                if window_start <= current_minutes < start_minutes:
                    # Idempotency check: verify not already sent today for this user and timetable entry
                    already_sent = (
                        db.query(NotificationLog)
                        .filter(
                            NotificationLog.user_id == stu.user_id,
                            NotificationLog.notification_type == NotificationType.NEXT_CLASS_STUDENT.value,
                            NotificationLog.reference_date == date_str,
                            NotificationLog.timetable_entry_id == entry.id,
                        )
                        .first()
                    )

                    if already_sent:
                        student_skipped += 1
                        continue

                    # Construct message
                    time_12 = format_time_12hr(period.start_time)
                    subj_display = subject.name or subject.code
                    if entry.room:
                        body_msg = f"Your next class is {subj_display} — {period.name} at {time_12} in Room {entry.room}."
                    else:
                        body_msg = f"Your next class is {subj_display} — {period.name} at {time_12}."

                    title_msg = "Go-On • Next Class"
                    channel_id = NotificationChannel.GO_ON_NEXT_CLASS.value
                    data_payload = {
                        "type": "next_class",
                        "route": "student_timetable",
                        "period_id": str(period.id),
                        "timetable_entry_id": str(entry.id),
                        "subject": subj_display,
                    }

                    # Send push to student's active devices
                    push_res = FCMService.send_push_to_user_devices(
                        db=db,
                        user_id=stu.user_id,
                        title=title_msg,
                        body=body_msg,
                        data=data_payload,
                        channel_id=channel_id,
                        high_importance=True,
                    )

                    # Determine truthful delivery status
                    if not push_res:
                        del_status = NotificationDeliveryStatus.STORED.value
                        err_note = "No active device registered. Stored in notification history."
                    elif any(r.get("simulated", False) for r in push_res):
                        del_status = NotificationDeliveryStatus.SIMULATED.value
                        err_note = "Simulated push dispatch."
                    elif any(r.get("success", False) for r in push_res):
                        del_status = NotificationDeliveryStatus.PROVIDER_ACCEPTED.value
                        err_note = None
                    else:
                        del_status = NotificationDeliveryStatus.FAILED.value
                        err_note = "Push notification delivery failed for user device(s)."

                    # Record in notification log for idempotency and inbox history
                    log = NotificationLog(
                        user_id=stu.user_id,
                        notification_type=NotificationType.NEXT_CLASS_STUDENT.value,
                        channel_id=channel_id,
                        title=title_msg,
                        body=body_msg,
                        data_payload=json.dumps(data_payload),
                        reference_date=date_str,
                        period_id=period.id,
                        timetable_entry_id=entry.id,
                        status=del_status,
                        error_message=err_note,
                    )
                    db.add(log)
                    db.commit()

                    student_sent += 1
                    details.append({
                        "user_id": stu.user_id,
                        "role": "STUDENT",
                        "roll_number": stu.roll_number,
                        "subject": subj_display,
                        "period": period.name,
                        "time": time_12,
                        "devices_notified": len(push_res),
                    })

        # -------------------------------------------------------------
        # 2. PROCESS FACULTY NEXT-CLASS REMINDERS
        # -------------------------------------------------------------
        if faculty_enabled:
            faculty_members = (
                db.query(Faculty)
                .join(User, Faculty.user_id == User.id)
                .filter(User.is_active == True)
                .all()
            )

            for fac in faculty_members:
                next_class_info = NotificationService.find_faculty_next_class(db, fac, now_dt)
                if not next_class_info:
                    continue

                entry, period, subject, class_sec = next_class_info
                sh, sm = parse_hhmm(period.start_time)
                start_minutes = sh * 60 + sm
                window_start = start_minutes - faculty_lead

                if window_start <= current_minutes < start_minutes:
                    already_sent = (
                        db.query(NotificationLog)
                        .filter(
                            NotificationLog.user_id == fac.user_id,
                            NotificationLog.notification_type == NotificationType.NEXT_CLASS_FACULTY.value,
                            NotificationLog.reference_date == date_str,
                            NotificationLog.timetable_entry_id == entry.id,
                        )
                        .first()
                    )

                    if already_sent:
                        faculty_skipped += 1
                        continue

                    time_12 = format_time_12hr(period.start_time)
                    subj_display = subject.name or subject.code
                    class_name = class_sec.name
                    if entry.room:
                        body_msg = f"Your next class is {subj_display} for {class_name}, {period.name} at {time_12} in Room {entry.room}."
                    else:
                        body_msg = f"Your next class is {subj_display} for {class_name}, {period.name} at {time_12}."

                    title_msg = "Go-On • Next Class"
                    channel_id = NotificationChannel.GO_ON_NEXT_CLASS.value
                    data_payload = {
                        "type": "next_class",
                        "route": "faculty_attendance",
                        "period_id": str(period.id),
                        "timetable_entry_id": str(entry.id),
                        "class_id": str(class_sec.id),
                        "subject": subj_display,
                    }

                    push_res = FCMService.send_push_to_user_devices(
                        db=db,
                        user_id=fac.user_id,
                        title=title_msg,
                        body=body_msg,
                        data=data_payload,
                        channel_id=channel_id,
                        high_importance=True,
                    )

                    # Determine truthful delivery status
                    if not push_res:
                        del_status = NotificationDeliveryStatus.STORED.value
                        err_note = "No active device registered. Stored in notification history."
                    elif any(r.get("simulated", False) for r in push_res):
                        del_status = NotificationDeliveryStatus.SIMULATED.value
                        err_note = "Simulated push dispatch."
                    elif any(r.get("success", False) for r in push_res):
                        del_status = NotificationDeliveryStatus.PROVIDER_ACCEPTED.value
                        err_note = None
                    else:
                        del_status = NotificationDeliveryStatus.FAILED.value
                        err_note = "Push notification delivery failed for user device(s)."

                    log = NotificationLog(
                        user_id=fac.user_id,
                        notification_type=NotificationType.NEXT_CLASS_FACULTY.value,
                        channel_id=channel_id,
                        title=title_msg,
                        body=body_msg,
                        data_payload=json.dumps(data_payload),
                        reference_date=date_str,
                        period_id=period.id,
                        timetable_entry_id=entry.id,
                        status=del_status,
                        error_message=err_note,
                    )
                    db.add(log)
                    db.commit()

                    faculty_sent += 1
                    details.append({
                        "user_id": fac.user_id,
                        "role": "FACULTY",
                        "employee_id": fac.employee_id,
                        "subject": subj_display,
                        "class_section": class_name,
                        "period": period.name,
                        "time": time_12,
                        "devices_notified": len(push_res),
                    })

        try:
            last_run_setting = db.query(SystemSetting).filter(SystemSetting.key == "notification.last_reminder_check_at").first()
            if last_run_setting:
                last_run_setting.value = now_dt.isoformat()
            else:
                db.add(SystemSetting(
                    key="notification.last_reminder_check_at",
                    value=now_dt.isoformat(),
                    description="Last heartbeat timestamp of Next-Class Reminder Engine",
                ))
            db.commit()
        except Exception:
            pass

        return {
            "date": date_str,
            "current_time": now_dt.strftime("%H:%M"),
            "timezone": "Asia/Kolkata",
            "student_reminders_sent": student_sent,
            "faculty_reminders_sent": faculty_sent,
            "student_reminders_skipped": student_skipped,
            "faculty_reminders_skipped": faculty_skipped,
            "details": details,
        }

    @staticmethod
    def _dispatch_notification_to_recipients(
        db: Session,
        admin_user: Optional[User],
        audience: str,
        target_type: str,
        target_id: Optional[str],
        title: str,
        body: str,
        channel: str = "GO_ON_ADMIN",
        priority: str = "NORMAL",
        route: Optional[str] = None,
        template_vars: Optional[Dict[str, str]] = None,
    ) -> Dict[str, Any]:
        """
        Internal dispatcher resolving recipients, performing template substitution,
        sending FCM pushes, and saving notification logs.
        """
        audience = audience.strip().upper()
        target_type = target_type.strip().upper()
        channel = channel.strip()
        is_high = priority.strip().upper() == "HIGH"
        safe_route = route.strip() if route else "profile"

        allowed_routes = {
            "student_timetable", "faculty_timetable", "faculty_attendance",
            "reports", "profile", "admin_biometrics", "announcements", "dashboard"
        }
        if safe_route not in allowed_routes:
            safe_route = "profile"

        recipient_users: List[User] = []

        if audience == "STUDENT":
            if target_type == "ALL":
                recipient_users = (
                    db.query(User)
                    .filter(User.role == UserRole.STUDENT, User.is_active == True)
                    .all()
                )
            elif target_type == "CLASS":
                if not target_id:
                    raise ValueError("Target class identifier required for CLASS target type")
                target_clean = str(target_id).strip()
                students_query = db.query(Student).join(User, Student.user_id == User.id).filter(User.is_active == True)
                if target_clean.isdigit():
                    students_query = students_query.filter(Student.class_id == int(target_clean))
                else:
                    students_query = students_query.join(ClassSection, Student.class_id == ClassSection.id).filter(
                        func.lower(ClassSection.name) == target_clean.lower()
                    )
                students = students_query.all()
                recipient_users = [s.user for s in students if s.user and s.user.is_active]
                if not recipient_users:
                    raise ValueError(f"No active students found in class '{target_id}'")
            elif target_type == "USER":
                if not target_id:
                    raise ValueError("Target user identifier required for USER target type")
                target_clean = str(target_id).strip()
                # 1. Match roll number or username (case-insensitive)
                u = (
                    db.query(User)
                    .join(Student, Student.user_id == User.id)
                    .filter(
                        User.role == UserRole.STUDENT,
                        User.is_active == True,
                        or_(
                            func.lower(User.username) == target_clean.lower(),
                            func.lower(Student.roll_number) == target_clean.lower(),
                        )
                    )
                    .first()
                )
                # 2. If numeric, check User.id or Student.id
                if not u and target_clean.isdigit():
                    num_id = int(target_clean)
                    u = db.query(User).filter(User.id == num_id, User.role == UserRole.STUDENT, User.is_active == True).first()
                    if not u:
                        s = db.query(Student).filter(Student.id == num_id).first()
                        if s and s.user and s.user.is_active:
                            u = s.user
                if not u:
                    raise ValueError(f"Student user '{target_id}' not found")
                recipient_users = [u]

        elif audience == "FACULTY":
            if target_type == "ALL":
                recipient_users = (
                    db.query(User)
                    .filter(User.role == UserRole.FACULTY, User.is_active == True)
                    .all()
                )
            elif target_type == "CLASS":
                if not target_id:
                    raise ValueError("Target class identifier required for CLASS target type")
                target_clean = str(target_id).strip()
                assignments_query = db.query(FacultyAssignment)
                if target_clean.isdigit():
                    assignments_query = assignments_query.filter(FacultyAssignment.class_id == int(target_clean))
                else:
                    assignments_query = assignments_query.join(ClassSection, FacultyAssignment.class_id == ClassSection.id).filter(
                        func.lower(ClassSection.name) == target_clean.lower()
                    )
                assignments = assignments_query.all()
                user_ids = set()
                for a in assignments:
                    if a.faculty and a.faculty.user_id:
                        user_ids.add(a.faculty.user_id)
                    for f in a.authorized_faculty:
                        if f.user_id:
                            user_ids.add(f.user_id)
                recipient_users = db.query(User).filter(User.id.in_(user_ids), User.is_active == True).all()
                if not recipient_users:
                    raise ValueError(f"No active faculty assigned to class '{target_id}'")
            elif target_type == "USER":
                if not target_id:
                    raise ValueError("Target user identifier required for USER target type")
                target_clean = str(target_id).strip()
                # 1. Match employee_id or username (case-insensitive)
                u = (
                    db.query(User)
                    .join(Faculty, Faculty.user_id == User.id)
                    .filter(
                        User.role == UserRole.FACULTY,
                        User.is_active == True,
                        or_(
                            func.lower(User.username) == target_clean.lower(),
                            func.lower(Faculty.employee_id) == target_clean.lower(),
                        )
                    )
                    .first()
                )
                # 2. If numeric, check User.id or Faculty.id
                if not u and target_clean.isdigit():
                    num_id = int(target_clean)
                    u = db.query(User).filter(User.id == num_id, User.role == UserRole.FACULTY, User.is_active == True).first()
                    if not u:
                        f = db.query(Faculty).filter(Faculty.id == num_id).first()
                        if f and f.user and f.user.is_active:
                            u = f.user
                if not u:
                    raise ValueError(f"Faculty user '{target_id}' not found")
                recipient_users = [u]

        elif audience == "ALL":
            if target_type == "ALL":
                recipient_users = db.query(User).filter(User.is_active == True).all()
            elif target_type == "CLASS":
                target_clean = str(target_id).strip()
                sq = db.query(Student).join(User, Student.user_id == User.id).filter(User.is_active == True)
                if target_clean.isdigit():
                    sq = sq.filter(Student.class_id == int(target_clean))
                else:
                    sq = sq.join(ClassSection, Student.class_id == ClassSection.id).filter(
                        func.lower(ClassSection.name) == target_clean.lower()
                    )
                stus = sq.all()
                aq = db.query(FacultyAssignment)
                if target_clean.isdigit():
                    aq = aq.filter(FacultyAssignment.class_id == int(target_clean))
                else:
                    aq = aq.join(ClassSection, FacultyAssignment.class_id == ClassSection.id).filter(
                        func.lower(ClassSection.name) == target_clean.lower()
                    )
                assigns = aq.all()
                u_ids = {s.user_id for s in stus if s.user_id}
                for a in assigns:
                    if a.faculty and a.faculty.user_id:
                        u_ids.add(a.faculty.user_id)
                    for f in a.authorized_faculty:
                        if f.user_id:
                            u_ids.add(f.user_id)
                recipient_users = db.query(User).filter(User.id.in_(u_ids), User.is_active == True).all()
                if not recipient_users:
                    raise ValueError(f"No active recipients found for class '{target_id}'")
            elif target_type == "USER" and target_id:
                target_clean = str(target_id).strip()
                u = db.query(User).filter(func.lower(User.username) == target_clean.lower(), User.is_active == True).first()
                if not u:
                    u = (
                        db.query(User)
                        .join(Faculty, Faculty.user_id == User.id)
                        .filter(func.lower(Faculty.employee_id) == target_clean.lower(), User.is_active == True)
                        .first()
                    )
                if not u:
                    u = (
                        db.query(User)
                        .join(Student, Student.user_id == User.id)
                        .filter(func.lower(Student.roll_number) == target_clean.lower(), User.is_active == True)
                        .first()
                    )
                if not u and target_clean.isdigit():
                    num_id = int(target_clean)
                    u = db.query(User).filter(User.id == num_id, User.is_active == True).first()
                    if not u:
                        f = db.query(Faculty).filter(Faculty.id == num_id).first()
                        if f and f.user and f.user.is_active:
                            u = f.user
                    if not u:
                        s = db.query(Student).filter(Student.id == num_id).first()
                        if s and s.user and s.user.is_active:
                            u = s.user
                if not u:
                    raise ValueError(f"Target user '{target_id}' not found")
                recipient_users = [u]

        base_vars = template_vars or {}
        now_dt = get_kolkata_now()
        base_vars.setdefault("date", now_dt.strftime("%d-%m-%Y"))

        recipients_count = len(recipient_users)
        date_str = now_dt.strftime("%Y-%m-%d")

        devices_targeted_count = 0
        devices_sent_count = 0
        devices_failed_count = 0
        deactivated_tokens_count = 0

        # Pre-fetch all active device tokens for the recipient group in a single query
        user_ids = [u.id for u in recipient_users]
        active_tokens = (
            db.query(DeviceToken)
            .filter(DeviceToken.user_id.in_(user_ids), DeviceToken.is_active == True)
            .all()
        )
        tokens_by_user: Dict[int, List[DeviceToken]] = {}
        for dev in active_tokens:
            tokens_by_user.setdefault(dev.user_id, []).append(dev)

        # Check if personalized template substitution is needed
        has_per_user_vars = any(tag in title or tag in body for tag in ["{{name}}", "{{class_name}}", "{{roll_number}}", "{{employee_id}}"])

        logs_to_add: List[NotificationLog] = []

        if not has_per_user_vars:
            # Common broadcast message across all recipients
            resolved_title = substitute_template(title, base_vars)
            resolved_body = substitute_template(body, base_vars)

            data_payload = {
                "type": "admin_custom",
                "route": safe_route,
                "audience": audience,
                "priority": "high" if is_high else "normal",
            }

            all_token_strings = list({dev.token for dev in active_tokens if dev.token})
            multicast_res = {
                "total_tokens": 0,
                "sent_count": 0,
                "failed_count": 0,
                "deactivated_tokens": 0,
                "simulated": False,
            }
            if all_token_strings:
                multicast_res = FCMService.send_multicast_push(
                    db=db,
                    tokens=all_token_strings,
                    title=resolved_title,
                    body=resolved_body,
                    data=data_payload,
                    channel_id=channel,
                    high_importance=is_high,
                )

            devices_targeted_count = multicast_res.get("total_tokens", 0)
            devices_sent_count = multicast_res.get("sent_count", 0)
            devices_failed_count = multicast_res.get("failed_count", 0)
            deactivated_tokens_count = multicast_res.get("deactivated_tokens", 0)
            is_simulated = multicast_res.get("simulated", False)

            successful_tokens_set = set(multicast_res.get("successful_tokens", []))
            failed_tokens_set = set(multicast_res.get("failed_tokens", []))

            # Record notification log for each recipient
            for user in recipient_users:
                user_tokens = [dev.token for dev in tokens_by_user.get(user.id, []) if dev.token]
                if not user_tokens:
                    del_status = NotificationDeliveryStatus.STORED.value
                    err_note = "No active device registered. Stored in notification history."
                elif is_simulated:
                    del_status = NotificationDeliveryStatus.SIMULATED.value
                    err_note = "Simulated push dispatch."
                elif any(t in successful_tokens_set for t in user_tokens):
                    del_status = NotificationDeliveryStatus.PROVIDER_ACCEPTED.value
                    err_note = None
                elif all(t in failed_tokens_set for t in user_tokens):
                    del_status = NotificationDeliveryStatus.FAILED.value
                    err_note = "Push notification delivery failed for user device(s)."
                else:
                    del_status = NotificationDeliveryStatus.PROVIDER_ACCEPTED.value if devices_sent_count > 0 else NotificationDeliveryStatus.FAILED.value
                    err_note = None if devices_sent_count > 0 else "Push delivery failed."

                log = NotificationLog(
                    user_id=user.id,
                    notification_type=NotificationType.ADMIN.value,
                    channel_id=channel,
                    title=resolved_title,
                    body=resolved_body,
                    data_payload=json.dumps(data_payload),
                    reference_date=date_str,
                    status=del_status,
                    error_message=err_note,
                    is_read=False,
                )
                logs_to_add.append(log)
                if len(logs_to_add) >= 250:
                    db.add_all(logs_to_add)
                    db.commit()
                    logs_to_add.clear()
        else:
            # Personalized per-user messages
            data_payload = {
                "type": "admin_custom",
                "route": safe_route,
                "audience": audience,
                "priority": "high" if is_high else "normal",
            }
            for user in recipient_users:
                user_vars = dict(base_vars)
                user_vars.setdefault("name", user.username)
                if user.role == UserRole.STUDENT and user.student_profile:
                    user_vars["name"] = user.student_profile.full_name
                    if user.student_profile.class_section:
                        user_vars.setdefault("class_name", user.student_profile.class_section.name)
                elif user.role == UserRole.FACULTY and user.faculty_profile:
                    user_vars["name"] = user.faculty_profile.full_name

                resolved_title = substitute_template(title, user_vars)
                resolved_body = substitute_template(body, user_vars)

                user_devices = tokens_by_user.get(user.id, [])
                push_results = []
                for dev in user_devices:
                    devices_targeted_count += 1
                    res = FCMService.send_push_to_token(
                        db=db,
                        token=dev.token,
                        title=resolved_title,
                        body=resolved_body,
                        data=data_payload,
                        channel_id=channel,
                        high_importance=is_high,
                    )
                    push_results.append(res)
                    if res.get("success"):
                        devices_sent_count += 1
                    else:
                        devices_failed_count += 1
                    if res.get("deactivated"):
                        deactivated_tokens_count += 1

                if not push_results:
                    delivery_status = NotificationDeliveryStatus.STORED.value
                    error_msg = "No registered push device tokens. Notification stored in database history."
                elif any(r.get("simulated", False) for r in push_results):
                    is_simulated = True
                    delivery_status = NotificationDeliveryStatus.SIMULATED.value
                    error_msg = "Simulated push dispatch (Firebase credentials not configured)."
                elif any(r.get("success", False) for r in push_results):
                    delivery_status = NotificationDeliveryStatus.PROVIDER_ACCEPTED.value
                    error_msg = None
                else:
                    delivery_status = NotificationDeliveryStatus.FAILED.value
                    error_msg = "; ".join([r.get("error", "Push failed") for r in push_results if not r.get("success")])

                log = NotificationLog(
                    user_id=user.id,
                    notification_type=NotificationType.ADMIN.value,
                    channel_id=channel,
                    title=resolved_title,
                    body=resolved_body,
                    data_payload=json.dumps(data_payload),
                    reference_date=date_str,
                    status=delivery_status,
                    error_message=error_msg,
                    is_read=False,
                )
                logs_to_add.append(log)
                if len(logs_to_add) >= 250:
                    db.add_all(logs_to_add)
                    db.commit()
                    logs_to_add.clear()

        if logs_to_add:
            db.add_all(logs_to_add)
            db.commit()

        recipients_without_tokens_count = sum(1 for u in recipient_users if not tokens_by_user.get(u.id))

        # Truthful aggregate status determination
        if devices_targeted_count == 0:
            overall_status = NotificationDeliveryStatus.NO_TOKEN.value
            overall_message = f"Stored in in-app inbox for {recipients_count} recipient(s). No active push device tokens registered."
            fcm_accepted_count = 0
        elif is_simulated:
            overall_status = NotificationDeliveryStatus.SIMULATED.value
            overall_message = f"Simulated push dispatch executed for {recipients_count} recipient(s) across {devices_targeted_count} device token(s) (Firebase credentials not configured)."
            fcm_accepted_count = 0
        elif devices_sent_count > 0 and (devices_failed_count > 0 or recipients_without_tokens_count > 0):
            overall_status = NotificationDeliveryStatus.PARTIAL_FAILURE.value
            overall_message = f"Partial delivery: push accepted for {devices_sent_count} device(s), {devices_failed_count} failed, {recipients_without_tokens_count} recipient(s) without active tokens."
            fcm_accepted_count = devices_sent_count
        elif devices_sent_count > 0 and devices_failed_count == 0:
            overall_status = NotificationDeliveryStatus.FCM_ACCEPTED.value
            overall_message = f"Push delivery accepted by FCM for {devices_sent_count} device(s) across {recipients_count} recipient(s)."
            fcm_accepted_count = devices_sent_count
        elif devices_failed_count > 0 and devices_sent_count == 0:
            overall_status = NotificationDeliveryStatus.FAILED.value
            overall_message = f"Push delivery failed for all {devices_failed_count} targeted device(s) across {recipients_count} recipient(s)."
            fcm_accepted_count = 0
        else:
            overall_status = NotificationDeliveryStatus.RECORDED.value
            overall_message = f"Successfully processed notification for {recipients_count} recipient(s)."
            fcm_accepted_count = 0

        admin_id = admin_user.id if admin_user else None
        mode_str = "SIMULATED" if is_simulated else "REAL_FCM"
        audit = AuditLog(
            user_id=admin_id,
            action="SEND_ADMIN_NOTIFICATION",
            details=(
                f"Audience: {audience} | Target: {target_type} ({target_id or 'all'}) | "
                f"Mode: {mode_str} | Status: {overall_status} | "
                f"Recipients: {recipients_count} ({recipients_without_tokens_count} without tokens) | "
                f"Devices: {devices_targeted_count} targeted, {devices_sent_count} sent, {devices_failed_count} failed | "
                f"Channel: {channel} | Title: {title[:50]}"
            ),
        )
        db.add(audit)
        db.commit()

        return {
            "success": True,
            "recipients_count": recipients_count,
            "devices_targeted": devices_targeted_count,
            "devices_sent": devices_sent_count,
            "devices_failed": devices_failed_count,
            "deactivated_tokens": deactivated_tokens_count,
            "is_simulated": is_simulated,
            "tokens_found": devices_targeted_count,
            "recipients_without_tokens": recipients_without_tokens_count,
            "fcm_accepted": fcm_accepted_count,
            "notification_type": NotificationType.ADMIN.value,
            "channel": channel,
            "title": title,
            "body": body,
            "status": overall_status,
            "message": overall_message,
        }


    @staticmethod
    def send_custom_admin_notification(
        db: Session,
        admin_user: User,
        audience: str,
        target_type: str,
        target_id: Optional[str],
        title: str,
        body: str,
        channel: str = "GO_ON_ADMIN",
        priority: str = "NORMAL",
        route: Optional[str] = None,
        template_vars: Optional[Dict[str, str]] = None,
        scheduled_at: Optional[datetime] = None,
    ) -> Dict[str, Any]:
        """
        Sends an Admin custom notification immediately or schedules it for future delivery.
        """
        safe_route = route.strip() if route else "profile"
        if scheduled_at:
            now_utc = datetime.now(timezone.utc)
            target_utc = (
                scheduled_at.astimezone(timezone.utc)
                if scheduled_at.tzinfo
                else scheduled_at.replace(tzinfo=TIMEZONE_KOLKATA).astimezone(timezone.utc)
            )
            if target_utc > now_utc + timedelta(seconds=30):
                # Duplicate suppression for pending scheduled items
                existing_sched = (
                    db.query(ScheduledNotification)
                    .filter(
                        ScheduledNotification.admin_id == admin_user.id,
                        ScheduledNotification.audience == audience.strip().upper(),
                        ScheduledNotification.target_type == target_type.strip().upper(),
                        ScheduledNotification.target_id == target_id,
                        ScheduledNotification.title == title.strip(),
                        ScheduledNotification.body == body.strip(),
                        ScheduledNotification.status == "PENDING",
                        ScheduledNotification.scheduled_at == target_utc,
                    )
                    .first()
                )
                if existing_sched:
                    return {
                        "success": True,
                        "recipients_count": 0,
                        "notification_type": NotificationType.ADMIN.value,
                        "channel": channel,
                        "title": title,
                        "body": body,
                        "status": "SCHEDULED",
                        "scheduled_at": existing_sched.scheduled_at,
                        "message": f"Notification already scheduled for {target_utc.strftime('%Y-%m-%d %H:%M:%S UTC')} (duplicate suppressed)",
                    }

                sched = ScheduledNotification(
                    admin_id=admin_user.id,
                    audience=audience.strip().upper(),
                    target_type=target_type.strip().upper(),
                    target_id=target_id,
                    title=title,
                    body=body,
                    channel=channel.strip(),
                    priority=priority.strip().upper(),
                    route=safe_route,
                    scheduled_at=target_utc,
                    status="PENDING",
                )
                db.add(sched)
                audit = AuditLog(
                    user_id=admin_user.id,
                    action="SCHEDULE_ADMIN_NOTIFICATION",
                    details=f"Audience: {audience} | Target: {target_type} ({target_id or 'all'}) | Scheduled for: {target_utc.isoformat()} | Channel: {channel} | Title: {title[:50]}",
                )
                db.add(audit)
                db.commit()
                db.refresh(sched)
                return {
                    "success": True,
                    "recipients_count": 0,
                    "notification_type": NotificationType.ADMIN.value,
                    "channel": channel,
                    "title": title,
                    "body": body,
                    "status": "SCHEDULED",
                    "scheduled_at": sched.scheduled_at,
                    "message": f"Notification successfully scheduled for {target_utc.strftime('%Y-%m-%d %H:%M:%S UTC')}",
                }

        # Duplicate broadcast suppression: check if an identical notification was sent by this admin within 10 seconds
        ten_seconds_ago = datetime.now(timezone.utc) - timedelta(seconds=10)
        recent_duplicate = (
            db.query(AuditLog)
            .filter(
                AuditLog.user_id == (admin_user.id if admin_user else None),
                AuditLog.action == "SEND_ADMIN_NOTIFICATION",
                AuditLog.timestamp >= ten_seconds_ago,
                AuditLog.details.like(f"%Audience: {audience.strip().upper()} | Target: {target_type.strip().upper()}%"),
                AuditLog.details.like(f"%Title: {title.strip()[:50]}%"),
            )
            .first()
        )
        if recent_duplicate:
            logger.info("Suppressed duplicate broadcast within 10s window: %s", recent_duplicate.details)
            return {
                "success": True,
                "recipients_count": 0,
                "devices_targeted": 0,
                "devices_sent": 0,
                "devices_failed": 0,
                "deactivated_tokens": 0,
                "notification_type": NotificationType.ADMIN.value,
                "channel": channel,
                "title": title,
                "body": body,
                "status": "DUPLICATE_SUPPRESSED",
                "message": "Duplicate broadcast suppressed within 10-second deduplication window.",
            }

        return NotificationService._dispatch_notification_to_recipients(
            db=db,
            admin_user=admin_user,
            audience=audience,
            target_type=target_type,
            target_id=target_id,
            title=title,
            body=body,
            channel=channel,
            priority=priority,
            route=route,
            template_vars=template_vars,
        )

    @staticmethod
    def process_due_scheduled_notifications(db: Session) -> int:
        """
        Processes and dispatches pending scheduled notifications whose scheduled_at time has arrived.
        Uses atomic state transition to prevent concurrent scheduler workers from duplicate dispatch.
        """
        now_utc = datetime.now(timezone.utc)
        now_utc_naive = now_utc.replace(tzinfo=None)
        due_items = (
            db.query(ScheduledNotification)
            .filter(
                ScheduledNotification.status == "PENDING",
                or_(
                    ScheduledNotification.scheduled_at <= now_utc,
                    ScheduledNotification.scheduled_at <= now_utc_naive,
                ),
            )
            .all()
        )
        if not due_items:
            return 0

        dispatched_count = 0
        for item in due_items:
            # Atomic lock: transition status from PENDING to PROCESSING to prevent duplicate dispatch
            updated = (
                db.query(ScheduledNotification)
                .filter(
                    ScheduledNotification.id == item.id,
                    ScheduledNotification.status == "PENDING",
                )
                .update({"status": "PROCESSING"})
            )
            db.commit()
            if updated == 0:
                continue  # Already claimed by another worker

            try:
                admin_user = item.admin or db.query(User).filter(User.role == UserRole.ADMIN).first()
                res = NotificationService._dispatch_notification_to_recipients(
                    db=db,
                    admin_user=admin_user,
                    audience=item.audience,
                    target_type=item.target_type,
                    target_id=item.target_id,
                    title=item.title,
                    body=item.body,
                    channel=item.channel,
                    priority=item.priority,
                    route=item.route,
                )
                item.status = "SENT"
                item.recipients_count = res.get("recipients_count", 0)
                dispatched_count += 1
            except Exception as e:
                logger.exception("Failed to dispatch scheduled notification ID %s: %s", item.id, e)
                item.status = "FAILED"
            db.commit()
        return dispatched_count


    @staticmethod
    def cancel_scheduled_notification(db: Session, sched_id: int, admin_user: User) -> bool:
        """Cancels a pending scheduled notification."""
        item = db.query(ScheduledNotification).filter(ScheduledNotification.id == sched_id).first()
        if not item or item.status != "PENDING":
            return False
        item.status = "CANCELLED"
        audit = AuditLog(
            user_id=admin_user.id,
            action="CANCEL_SCHEDULED_NOTIFICATION",
            details=f"Cancelled Scheduled Notification ID {sched_id} ({item.title[:40]})",
        )
        db.add(audit)
        db.commit()
        return True
