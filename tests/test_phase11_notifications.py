import json
import pytest
from datetime import datetime
from zoneinfo import ZoneInfo
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.core.database import SessionLocal, init_db, engine
from app.models.user import User, Faculty, UserRole
from app.models.student import Student
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.notification import DeviceToken, NotificationLog, NotificationType, NotificationChannel
from app.models.audit import AuditLog
from app.services.notification_service import (
    NotificationService, format_time_12hr, is_break_or_lunch,
    substitute_template, TIMEZONE_KOLKATA
)

client = TestClient(app)


@pytest.fixture(scope="module")
def db():
    init_db(engine)
    session = SessionLocal()
    yield session
    session.close()


def test_time_formatting_and_break_detection():
    """Verify 12-hour time formatter and break/lunch detection."""
    assert format_time_12hr("09:10") == "9:10 AM"
    assert format_time_12hr("12:00") == "12:00 PM"
    assert format_time_12hr("13:40") == "1:40 PM"
    assert format_time_12hr("15:20") == "3:20 PM"

    assert is_break_or_lunch("Short Break", "BRK") is True
    assert is_break_or_lunch("Lunch Break", "LUNCH") is True
    assert is_break_or_lunch("Tea Interval", "INT") is True
    assert is_break_or_lunch("Computer Networks", "CET-II") is False
    assert is_break_or_lunch("Digital Principles", "DPCO") is False


def test_template_substitution():
    """Verify safe template variable substitution."""
    template = "Hello {{name}}, your next class is {{subject}} in {{room}} on {{date}}."
    ctx = {
        "name": "Abishek",
        "subject": "DPCO",
        "room": "Hall 1",
        "date": "2026-10-09"
    }
    rendered = substitute_template(template, ctx)
    assert rendered == "Hello Abishek, your next class is DPCO in Hall 1 on 2026-10-09."

    # Unknown variable is stripped safely
    assert substitute_template("Notice: {{unknown_var}} Today", {}) == "Notice:  Today"


def test_notification_settings_independence(db: Session):
    """Verify student and faculty notification settings are independent."""
    # Default settings
    settings = NotificationService.get_settings(db)
    assert "student_next_class_enabled" in settings
    assert "faculty_next_class_enabled" in settings
    assert "student_next_class_lead_minutes" in settings
    assert "faculty_next_class_lead_minutes" in settings

    # Update student only
    updated = NotificationService.update_settings(db, {
        "student_next_class_lead_minutes": 20,
        "student_next_class_enabled": False,
    })
    assert updated["student_next_class_lead_minutes"] == 20
    assert updated["student_next_class_enabled"] is False
    # Faculty should remain untouched
    assert updated["faculty_next_class_lead_minutes"] == 15
    assert updated["faculty_next_class_enabled"] is True

    # Restore defaults
    NotificationService.update_settings(db, {
        "student_next_class_lead_minutes": 10,
        "student_next_class_enabled": True,
        "faculty_next_class_lead_minutes": 15,
        "faculty_next_class_enabled": True,
    })


def test_device_token_lifecycle(db: Session):
    """Verify registering, updating, and deactivating FCM device tokens."""
    # Find any user
    user = db.query(User).filter(User.role == UserRole.STUDENT).first()
    if not user:
        user = db.query(User).first()
    assert user is not None

    test_token = "test_fcm_token_device_abc_1234567890"

    # Register
    dev = NotificationService.register_device_token(
        db=db,
        user_id=user.id,
        token=test_token,
        platform="android",
        device_name="Realme RMX3998",
    )
    assert dev.token == test_token
    assert dev.is_active is True
    assert dev.platform == "android"

    # Deactivate
    success = NotificationService.deactivate_device_token(db, test_token)
    assert success is True
    dev_db = db.query(DeviceToken).filter(DeviceToken.token == test_token).first()
    assert dev_db.is_active is False

    # Reactivate on re-registration
    dev_re = NotificationService.register_device_token(
        db=db,
        user_id=user.id,
        token=test_token,
        platform="android",
    )
    assert dev_re.is_active is True

    # Cleanup test token
    db.delete(dev_re)
    db.commit()


def test_student_next_class_finder_and_deduplication(db: Session):
    """
    Test student next class detection using actual timetable,
    lead time window, break exclusion, and idempotent deduplication.
    """
    # Find a student with a class that has timetable entries
    stu = db.query(Student).filter(Student.class_id != None, Student.user_id != None).first()
    assert stu is not None, "Need at least one student with class_id and user_id"

    # Query entries for this student's class
    tt = (
        db.query(TimetableEntry, Period, Subject)
        .join(Period, TimetableEntry.period_id == Period.id)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .join(Subject, FacultyAssignment.subject_id == Subject.id)
        .filter(FacultyAssignment.class_id == stu.class_id)
        .first()
    )
    assert tt is not None, "Need timetable entry for student class"
    entry, period, subject = tt

    # Simulate reference time 8 minutes before period start
    sh, sm = int(period.start_time.split(":")[0]), int(period.start_time.split(":")[1])
    sim_dt = datetime(2026, 10, 9, sh, sm, tzinfo=TIMEZONE_KOLKATA)
    # Match the day of week to the entry
    # Find weekday date for entry.day_of_week
    days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    target_weekday = days.index(entry.day_of_week) if entry.day_of_week in days else 0
    # adjust sim_dt to that weekday
    days_diff = (target_weekday - sim_dt.weekday()) % 7
    sim_date = sim_dt + pytest.importorskip("datetime").timedelta(days=days_diff)
    
    # 8 minutes before start: within 10-minute student lead window
    sim_test_dt = sim_date.replace(hour=sh, minute=sm) - pytest.importorskip("datetime").timedelta(minutes=8)

    # 1. First trigger: reminder should be sent
    res1 = NotificationService.check_and_send_next_class_reminders(db, reference_dt=sim_test_dt)
    assert res1["student_reminders_sent"] >= 1 or res1["student_reminders_skipped"] >= 1

    # 2. Second trigger with identical time: must be idempotent and NOT send duplicate!
    res2 = NotificationService.check_and_send_next_class_reminders(db, reference_dt=sim_test_dt)
    # The student who already received it should be skipped
    assert res2["student_reminders_sent"] == 0

    # 3. Trigger AFTER class start: must NOT send missed reminder (Section 43)
    after_class_dt = sim_date.replace(hour=sh, minute=sm) + pytest.importorskip("datetime").timedelta(minutes=5)
    res_after = NotificationService.check_and_send_next_class_reminders(db, reference_dt=after_class_dt)
    # Should not send for this period because it already started
    for d in res_after["details"]:
        assert d.get("period") != period.name


def test_custom_admin_notification_targeting_and_audit(db: Session):
    """
    Test Admin custom notification dispatch with student targeting,
    faculty targeting, class targeting, and audit logging.
    """
    admin_user = db.query(User).filter(User.role == UserRole.ADMIN).first()
    assert admin_user is not None

    # Send to ALL STUDENTS
    res_stu = NotificationService.send_custom_admin_notification(
        db=db,
        admin_user=admin_user,
        audience="STUDENT",
        target_type="ALL",
        target_id=None,
        title="Schedule Notice for {{name}}",
        body="Classes start at 9:10 AM on {{date}}.",
        channel="GO_ON_ADMIN",
        priority="HIGH",
    )
    assert res_stu["success"] is True
    assert res_stu["recipients_count"] > 0

    # Verify audit log was created
    audit = (
        db.query(AuditLog)
        .filter(AuditLog.action == "SEND_ADMIN_NOTIFICATION", AuditLog.user_id == admin_user.id)
        .order_by(AuditLog.id.desc())
        .first()
    )
    assert audit is not None
    assert "STUDENT" in audit.details

    # Send to ALL FACULTY
    res_fac = NotificationService.send_custom_admin_notification(
        db=db,
        admin_user=admin_user,
        audience="FACULTY",
        target_type="ALL",
        target_id=None,
        title="Faculty Briefing",
        body="Please submit attendance promptly today.",
        channel="GO_ON_ADMIN",
        priority="NORMAL",
    )
    assert res_fac["success"] is True
    assert res_fac["recipients_count"] > 0

    # Test error handling on invalid class ID
    with pytest.raises(ValueError):
        NotificationService.send_custom_admin_notification(
            db=db,
            admin_user=admin_user,
            audience="STUDENT",
            target_type="CLASS",
            target_id="",  # Missing required class target
            title="Class Notice",
            body="Notice body",
        )


def test_faculty_next_class_finder_and_deduplication(db: Session):
    """
    Test faculty next class detection using actual teaching assignments,
    faculty lead time, and idempotency.
    """
    fac = db.query(Faculty).join(User, Faculty.user_id == User.id).filter(User.is_active == True).first()
    assert fac is not None

    tt = (
        db.query(TimetableEntry, Period, Subject, FacultyAssignment)
        .join(Period, TimetableEntry.period_id == Period.id)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .join(Subject, FacultyAssignment.subject_id == Subject.id)
        .filter(FacultyAssignment.faculty_id == fac.id)
        .first()
    )
    if not tt:
        pytest.skip("Faculty has no teaching timetable entries in seed data")

    entry, period, subject, assignment = tt
    sh, sm = int(period.start_time.split(":")[0]), int(period.start_time.split(":")[1])
    days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    target_weekday = days.index(entry.day_of_week) if entry.day_of_week in days else 0
    sim_dt = datetime(2026, 10, 5, sh, sm, tzinfo=TIMEZONE_KOLKATA)
    days_diff = (target_weekday - sim_dt.weekday()) % 7
    sim_date = sim_dt + pytest.importorskip("datetime").timedelta(days=days_diff)

    # 12 minutes before start: within 15-minute faculty lead window
    sim_test_dt = sim_date.replace(hour=sh, minute=sm) - pytest.importorskip("datetime").timedelta(minutes=12)

    found = NotificationService.find_faculty_next_class(db, fac, sim_test_dt)
    assert found is not None
    assert found[1].period_number == period.period_number


def test_api_endpoints_and_rbac(db: Session):
    """
    Test notification REST API endpoints:
    - Admin settings GET/PUT
    - Admin composer POST
    - Admin trigger reminders POST
    - User device token register / delete
    - User history GET
    """
    from app.core.security import create_access_token

    admin_user = db.query(User).filter(User.role == UserRole.ADMIN).first()
    student_user = db.query(User).filter(User.role == UserRole.STUDENT).first()

    admin_token = create_access_token(str(admin_user.id), admin_user.role.value)
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    student_token = create_access_token(str(student_user.id), student_user.role.value)
    student_headers = {"Authorization": f"Bearer {student_token}"}

    # 1. Admin gets settings
    resp = client.get("/api/v1/admin/notifications/settings", headers=admin_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "student_next_class_lead_minutes" in data
    assert "faculty_next_class_lead_minutes" in data

    # 2. Student cannot access admin settings (RBAC)
    resp_forbidden = client.get("/api/v1/admin/notifications/settings", headers=student_headers)
    assert resp_forbidden.status_code == 403

    # 3. Admin updates settings
    resp_put = client.put(
        "/api/v1/admin/notifications/settings",
        json={"student_next_class_lead_minutes": 15, "faculty_next_class_lead_minutes": 20},
        headers=admin_headers
    )
    assert resp_put.status_code == 200
    assert resp_put.json()["student_next_class_lead_minutes"] == 15
    assert resp_put.json()["faculty_next_class_lead_minutes"] == 20

    # Restore defaults
    client.put(
        "/api/v1/admin/notifications/settings",
        json={"student_next_class_lead_minutes": 10, "faculty_next_class_lead_minutes": 15},
        headers=admin_headers
    )

    # 4. Student registers device token
    test_tok = "tok_api_test_9876543210_student"
    resp_tok = client.post(
        "/api/v1/notifications/device-token",
        json={"token": test_tok, "platform": "android", "device_name": "Realme RMX3998"},
        headers=student_headers
    )
    assert resp_tok.status_code == 200
    assert resp_tok.json()["success"] is True

    # 5. Student gets registered devices
    resp_devs = client.get("/api/v1/notifications/my-devices", headers=student_headers)
    assert resp_devs.status_code == 200
    assert any(d["token"] == test_tok for d in resp_devs.json())

    # 6. Student deletes token
    resp_del = client.delete(f"/api/v1/notifications/device-token?token={test_tok}", headers=student_headers)
    assert resp_del.status_code == 200
    assert resp_del.json()["success"] is True

    # 7. Admin sends custom broadcast
    resp_send = client.post(
        "/api/v1/admin/notifications/send",
        json={
            "audience": "STUDENT",
            "target_type": "ALL",
            "title": "Semester Examination Notice",
            "body": "Exam schedules have been published for {{date}}.",
            "channel": "GO_ON_ADMIN",
            "priority": "HIGH",
            "route": "student_timetable"
        },
        headers=admin_headers
    )
    assert resp_send.status_code == 200
    assert resp_send.json()["success"] is True
    assert resp_send.json()["recipients_count"] > 0

    # 8. Admin triggers next-class check
    resp_trig = client.post("/api/v1/admin/notifications/trigger-reminders", headers=admin_headers)
    assert resp_trig.status_code == 200
    assert "student_reminders_sent" in resp_trig.json()


def test_web_admin_notification_center_integration(db):
    """Verify that the Web Admin panel at /admin has the Notification Center entry point, valid DOM structure, and metrics endpoint."""
    resp = client.get("/admin")
    assert resp.status_code == 200
    html = resp.text

    # 1. Sidebar menu entry exists
    assert 'data-tab="notifications"' in html
    assert 'Notifications</span>' in html

    # 2. Tab content container exists and is an independent section
    assert 'id="tab-notifications"' in html

    # 3. DOM validity: ensure section tab-audit is closed before tab-notifications
    audit_idx = html.find('id="tab-audit"')
    notif_idx = html.find('id="tab-notifications"')
    assert audit_idx != -1 and notif_idx != -1
    assert audit_idx < notif_idx

    # The substring between tab-audit and tab-notifications must contain the closing </section>
    between_sections = html[audit_idx:notif_idx]
    assert '</section>' in between_sections, "tab-audit must be closed with </section> before tab-notifications opens"

    # All section tags in admin_panel.html must be balanced
    open_sections = html.count('<section ') + html.count('<section>')
    close_sections = html.count('</section>')
    assert open_sections == close_sections, f"Mismatched section tags: {open_sections} open vs {close_sections} close"

    # 4. Core Notification Center panels exist
    assert 'Next-Class Reminder Engine' in html
    assert 'Broadcast Notification Composer' in html
    assert 'Pending Scheduled Broadcasts' in html
    assert 'Notification Delivery & Audit Logs' in html
    assert 'notifStudentLead' in html
    assert 'notifFacultyLead' in html
    assert 'notifAudience' in html
    assert 'timingSchedule' in html

    # 5. Metrics API endpoint verification & RBAC
    admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
    student = db.query(User).filter(User.role == UserRole.STUDENT).first()
    from app.core.security import create_access_token
    admin_token = create_access_token(str(admin.id), admin.role.value)
    student_token = create_access_token(str(student.id), student.role.value)

    # Student forbidden
    res_stu = client.get("/api/v1/admin/notifications/metrics", headers={"Authorization": f"Bearer {student_token}"})
    assert res_stu.status_code == 403

    # Admin allowed
    res_adm = client.get("/api/v1/admin/notifications/metrics", headers={"Authorization": f"Bearer {admin_token}"})
    assert res_adm.status_code == 200
    metrics_data = res_adm.json()
    assert "active_device_tokens" in metrics_data
    assert "total_dispatched_logs" in metrics_data
    assert "pending_scheduled" in metrics_data
    assert "student_next_class_enabled" in metrics_data
    assert "faculty_next_class_enabled" in metrics_data


def test_scheduled_notification_lifecycle_and_rbac(db):
    """Verify scheduling notifications, queue retrieval, cancellation, processing, and RBAC security."""
    from datetime import timedelta
    admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
    student = db.query(User).filter(User.role == UserRole.STUDENT).first()

    from app.core.security import create_access_token
    admin_token = create_access_token(str(admin.id), admin.role.value)
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    student_token = create_access_token(str(student.id), student.role.value)
    student_headers = {"Authorization": f"Bearer {student_token}"}

    # 1. Non-admin (Student) blocked with 403 Forbidden
    resp_sched_forbidden = client.get("/api/v1/admin/notifications/scheduled", headers=student_headers)
    assert resp_sched_forbidden.status_code == 403

    # 2. Admin schedules a notification for future
    future_time = datetime.now(TIMEZONE_KOLKATA) + timedelta(minutes=25)
    resp_schedule = client.post(
        "/api/v1/admin/notifications/send",
        json={
            "audience": "STUDENT",
            "target_type": "ALL",
            "title": "Scheduled Campus Maintenance",
            "body": "Campus Wi-Fi maintenance will begin shortly.",
            "channel": "GO_ON_ADMIN",
            "priority": "NORMAL",
            "route": "dashboard",
            "scheduled_at": future_time.isoformat()
        },
        headers=admin_headers
    )
    assert resp_schedule.status_code == 200
    sched_data = resp_schedule.json()
    assert sched_data["success"] is True
    assert sched_data["status"] == "SCHEDULED"

    # 3. Admin retrieves scheduled list
    resp_list = client.get("/api/v1/admin/notifications/scheduled?status_filter=PENDING", headers=admin_headers)
    assert resp_list.status_code == 200
    items = resp_list.json()
    assert len(items) > 0
    matched = [i for i in items if i["title"] == "Scheduled Campus Maintenance"]
    assert len(matched) > 0
    sched_id = matched[0]["id"]

    # 4. Admin cancels the scheduled notification
    resp_cancel = client.delete(f"/api/v1/admin/notifications/scheduled/{sched_id}", headers=admin_headers)
    assert resp_cancel.status_code == 200
    assert resp_cancel.json()["success"] is True

    # 5. Verify cancel status in DB
    from app.models.notification import ScheduledNotification
    canceled_record = db.query(ScheduledNotification).filter(ScheduledNotification.id == sched_id).first()
    assert canceled_record.status == "CANCELLED"

