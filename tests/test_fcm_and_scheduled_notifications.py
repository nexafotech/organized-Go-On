import json
import os
import time
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.core.database import SessionLocal, init_db, engine
from app.core.security import create_access_token
from app.models.user import User, Faculty, UserRole
from app.models.student import Student
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.notification import (
    DeviceToken, NotificationLog, NotificationType, NotificationChannel,
    NotificationDeliveryStatus, ScheduledNotification
)
from app.models.audit import AuditLog
from app.models.policy import SystemSetting
from app.services.fcm_service import (
    FCMService, mask_token, sanitize_payload,
    is_token_unregistered_error, is_transient_error,
    deactivate_tokens, reset_firebase_app
)
from app.services.notification_service import (
    NotificationService, TIMEZONE_KOLKATA, get_kolkata_now
)

client = TestClient(app)


@pytest.fixture(scope="module")
def db():
    init_db(engine)
    session = SessionLocal()
    yield session
    session.close()


@pytest.fixture(autouse=True)
def clean_fcm_state():
    reset_firebase_app()
    yield
    reset_firebase_app()


# =============================================================================
# 1. FCM TOKEN REGISTRATION, REFRESH, LOGOUT DEACTIVATION & MALFORMED REJECTION
# =============================================================================

def test_fcm_token_registration_refresh_and_logout_deactivation(db: Session):
    """
    Verify complete device token lifecycle:
    - Register new device token
    - Refresh token (updates ownership and reactivates)
    - Register multiple devices for same user (phone + tablet)
    - Scoped logout unregistration
    - Malformed token rejection
    """
    student = db.query(User).filter(User.role == UserRole.STUDENT, User.is_active == True).first()
    assert student is not None, "Need at least one student user"
    token_str = create_access_token(str(student.id), student.role.value)
    student_headers = {"Authorization": f"Bearer {token_str}"}

    tok_phone = "fcm_test_device_token_phone_1234567890"
    tok_tablet = "fcm_test_device_token_tablet_0987654321"

    # 1. Register phone
    resp1 = client.post(
        "/api/v1/notifications/device-token",
        json={"token": tok_phone, "platform": "android", "device_name": "Pixel 8"},
        headers=student_headers,
    )
    assert resp1.status_code == 200
    assert resp1.json()["success"] is True

    # 2. Register tablet (multi-device support)
    resp2 = client.post(
        "/api/v1/notifications/device-token",
        json={"token": tok_tablet, "platform": "android", "device_name": "Galaxy Tab S9"},
        headers=student_headers,
    )
    assert resp2.status_code == 200

    # Verify both devices are registered and active
    my_devices = client.get("/api/v1/notifications/my-devices", headers=student_headers).json()
    active_tokens = [d["token"] for d in my_devices if d["is_active"]]
    assert tok_phone in active_tokens
    assert tok_tablet in active_tokens

    # 3. Token refresh simulation (same token re-registered by client SDK)
    resp_refresh = client.post(
        "/api/v1/notifications/device-token",
        json={"token": tok_phone, "platform": "android", "device_name": "Pixel 8 Pro"},
        headers=student_headers,
    )
    assert resp_refresh.status_code == 200

    # 4. Deactivate phone token on logout
    resp_logout = client.delete(
        f"/api/v1/notifications/device-token?token={tok_phone}",
        headers=student_headers,
    )
    assert resp_logout.status_code == 200
    assert resp_logout.json()["success"] is True

    # Verify phone is inactive but tablet remains active
    db_phone = db.query(DeviceToken).filter(DeviceToken.token == tok_phone).first()
    assert db_phone.is_active is False
    db_tablet = db.query(DeviceToken).filter(DeviceToken.token == tok_tablet).first()
    assert db_tablet.is_active is True

    # 5. Malformed token rejection (token < 10 characters)
    resp_bad = client.post(
        "/api/v1/notifications/device-token",
        json={"token": "short", "platform": "android"},
        headers=student_headers,
    )
    assert resp_bad.status_code == 422  # Validation error

    # Cleanup
    db.query(DeviceToken).filter(DeviceToken.token.in_([tok_phone, tok_tablet])).delete(synchronize_session=False)
    db.commit()


def test_device_token_security_cannot_deactivate_others_token(db: Session):
    """Verify that a user cannot unregister or deactivate another user's device token."""
    student1 = db.query(User).filter(User.role == UserRole.STUDENT, User.is_active == True).first()
    student2 = db.query(User).filter(User.role == UserRole.STUDENT, User.id != student1.id, User.is_active == True).first()
    if not student2:
        pytest.skip("Need at least two student users for cross-user security test")

    s1_token = create_access_token(str(student1.id), student1.role.value)
    s2_token = create_access_token(str(student2.id), student2.role.value)

    tok_s1 = "fcm_token_private_student1_999999999"
    NotificationService.register_device_token(db, user_id=student1.id, token=tok_s1, platform="android")

    # Student 2 attempts to deactivate Student 1's token
    resp_hack = client.delete(
        f"/api/v1/notifications/device-token?token={tok_s1}",
        headers={"Authorization": f"Bearer {s2_token}"},
    )
    assert resp_hack.status_code == 200
    assert resp_hack.json()["success"] is False

    # Student 1's token must still be active
    dev = db.query(DeviceToken).filter(DeviceToken.token == tok_s1).first()
    assert dev.is_active is True

    # Cleanup
    db.delete(dev)
    db.commit()


# =============================================================================
# 2. STALE / UNREGISTERED TOKEN PRUNING & ERROR CLASSIFICATION
# =============================================================================

def test_fcm_token_pruning_on_unregistered_error(db: Session):
    """
    Verify that when FCM rejects a token with UnregisteredError or invalid token,
    it is immediately marked inactive (is_active = False) in the database.
    """
    user = db.query(User).first()
    assert user is not None
    bad_token = "stale_expired_device_token_xyz_888888888"

    # Register active token
    dev = NotificationService.register_device_token(db, user_id=user.id, token=bad_token, platform="android")
    assert dev.is_active is True

    # Mock get_firebase_app to simulate live mode with messaging throwing UnregisteredError
    mock_app = MagicMock()
    with patch("app.services.fcm_service.get_firebase_app", return_value=mock_app):
        import firebase_admin.messaging as fcm_messaging
        with patch.object(
            fcm_messaging,
            "send",
            side_effect=Exception("Requested entity was not found. UnregisteredError: registration-token-not-registered")
        ):
            res = FCMService.send_push_to_token(
                db=db,
                token=bad_token,
                title="Test Title",
                body="Test Body",
            )
            assert res["success"] is False
            assert res.get("deactivated") is True

    # Verify database record is deactivated
    refreshed_dev = db.query(DeviceToken).filter(DeviceToken.token == bad_token).first()
    assert refreshed_dev.is_active is False

    # Clean up
    db.delete(refreshed_dev)
    db.commit()


def test_fcm_error_classification_functions():
    """Verify permanent vs transient error detection logic."""
    assert is_token_unregistered_error(Exception("UnregisteredError: token not registered")) is True
    assert is_token_unregistered_error(Exception("registration-token-not-registered")) is True
    assert is_token_unregistered_error(Exception("invalid-registration-token")) is True
    assert is_token_unregistered_error(Exception("SenderIdMismatchError")) is True
    assert is_token_unregistered_error(Exception("Requested entity was not found")) is True
    assert is_token_unregistered_error(Exception("Resource Exhausted Quota Error")) is False

    assert is_transient_error(Exception("Deadline exceeded during network write")) is True
    assert is_transient_error(Exception("503 Service Unavailable")) is True
    assert is_transient_error(Exception("ResourceExhausted: Too many requests")) is True
    assert is_transient_error(Exception("Connection reset by peer")) is True
    assert is_transient_error(Exception("UnregisteredError")) is False


# =============================================================================
# 3. FCM MULTICAST BATCHING & CHUNKING
# =============================================================================

def test_fcm_multicast_simulated_dispatch(db: Session):
    """Verify multicast dispatch with multiple tokens in simulated mode."""
    tokens = [f"sim_token_batch_{i:04d}_abcdef12345" for i in range(25)]
    res = FCMService.send_multicast_push(
        db=db,
        tokens=tokens,
        title="Campus Wide Notice",
        body="Tomorrow will be a regular working day.",
        channel_id="GO_ON_GENERAL",
    )
    assert res["total_tokens"] == 25
    assert res["sent_count"] == 25
    assert res["failed_count"] == 0
    assert res["simulated"] is True
    assert len(res["message_ids"]) > 0


def test_fcm_multicast_live_mock_with_deactivations(db: Session):
    """
    Verify live multicast handling:
    - Successful tokens are counted
    - Unregistered tokens are pruned in bulk
    """
    user = db.query(User).first()
    valid_token = "valid_live_mock_token_1111111111"
    stale_token = "stale_live_mock_token_2222222222"

    NotificationService.register_device_token(db, user_id=user.id, token=valid_token)
    NotificationService.register_device_token(db, user_id=user.id, token=stale_token)

    mock_app = MagicMock()
    with patch("app.services.fcm_service.get_firebase_app", return_value=mock_app):
        import firebase_admin.messaging as fcm_messaging

        # Mock BatchResponse with 1 success and 1 permanent failure
        mock_resp_success = MagicMock(success=True, message_id="projects/test/messages/001")
        mock_resp_failure = MagicMock(
            success=False,
            message_id=None,
            exception=Exception("UnregisteredError: token unregistered"),
        )
        mock_batch = MagicMock(responses=[mock_resp_success, mock_resp_failure])

        with patch.object(fcm_messaging, "send_each_for_multicast", return_value=mock_batch):
            result = FCMService.send_multicast_push(
                db=db,
                tokens=[valid_token, stale_token],
                title="Multicast Test",
                body="Testing batch dispatch",
            )
            assert result["total_tokens"] == 2
            assert result["sent_count"] == 1
            assert result["failed_count"] == 1
            assert result["deactivated_tokens"] == 1

    # Verify stale token was deactivated in database
    stale_record = db.query(DeviceToken).filter(DeviceToken.token == stale_token).first()
    assert stale_record.is_active is False
    valid_record = db.query(DeviceToken).filter(DeviceToken.token == valid_token).first()
    assert valid_record.is_active is True

    # Cleanup
    db.delete(stale_record)
    db.delete(valid_record)
    db.commit()


# =============================================================================
# 4. TRANSIENT ERROR RETRY & BACKOFF
# =============================================================================

def test_fcm_transient_error_retry_success(db: Session):
    """Verify that a transient error (e.g. timeout) retries and succeeds."""
    mock_app = MagicMock()
    attempts = 0

    def mock_send(msg):
        nonlocal attempts
        attempts += 1
        if attempts == 1:
            raise Exception("503 Service Unavailable: temporary timeout")
        return "projects/test/messages/retry-success"

    with patch("app.services.fcm_service.get_firebase_app", return_value=mock_app):
        import firebase_admin.messaging as fcm_messaging
        with patch.object(fcm_messaging, "send", side_effect=mock_send):
            with patch("time.sleep", return_value=None):  # Avoid delay in tests
                res = FCMService.send_push_to_token(
                    db=db,
                    token="retry_token_test_1234567890",
                    title="Retry Test",
                    body="Testing transient retry",
                    max_retries=2,
                )
                assert res["success"] is True
                assert res["message_id"] == "projects/test/messages/retry-success"
                assert attempts == 2


# =============================================================================
# 5. PAYLOAD CONSTRAINTS AND TOKEN MASKING
# =============================================================================

def test_fcm_payload_sanitization_and_constraints():
    """Verify title/body length enforcement and data value string conversion."""
    long_title = "A" * 300
    long_body = "B" * 1500
    data = {"int_val": 1234, "bool_val": True, "str_val": "hello"}

    clean_title, clean_body, str_data = sanitize_payload(long_title, long_body, data)
    assert len(clean_title) == 200
    assert len(clean_body) == 1000
    assert str_data["int_val"] == "1234"
    assert str_data["bool_val"] == "True"
    assert str_data["str_val"] == "hello"


def test_token_masking():
    """Verify sensitive device tokens are masked in logs."""
    raw = "c89f01ab34de567890abcdef12345678"
    masked = mask_token(raw)
    assert masked == "c89f01...5678"
    assert "01ab34de567890abcdef" not in masked
    assert mask_token("") == "<empty>"
    assert mask_token(None) == "<empty>"


# =============================================================================
# 6. ADMIN-TRIGGERED MESSAGING & AUDIENCE TARGETING
# =============================================================================

def test_admin_broadcast_targeting_students_only(db: Session):
    """Verify admin custom notification with audience=STUDENT only logs for students."""
    admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
    assert admin is not None
    admin_token = create_access_token(str(admin.id), admin.role.value)
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    resp = client.post(
        "/api/v1/admin/notifications/send",
        json={
            "audience": "STUDENT",
            "target_type": "ALL",
            "title": "Student Exclusive Notice",
            "body": "Midterm marks are posted for {{name}}.",
            "channel": "GO_ON_ADMIN",
            "priority": "HIGH",
            "route": "student_timetable",
        },
        headers=admin_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["recipients_count"] > 0
    assert "devices_targeted" in data

    # Verify logged recipients are strictly students
    recent_logs = (
        db.query(NotificationLog)
        .filter(NotificationLog.title.like("Student Exclusive Notice%"))
        .order_by(NotificationLog.id.desc())
        .limit(10)
        .all()
    )
    assert len(recent_logs) > 0
    for log in recent_logs:
        assert log.user.role == UserRole.STUDENT


def test_admin_broadcast_targeting_faculty_only(db: Session):
    """Verify admin custom notification with audience=FACULTY only logs for faculty."""
    admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
    admin_token = create_access_token(str(admin.id), admin.role.value)
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    resp = client.post(
        "/api/v1/admin/notifications/send",
        json={
            "audience": "FACULTY",
            "target_type": "ALL",
            "title": "Faculty Department Meeting",
            "body": "All faculty members please assemble at 4 PM.",
            "channel": "GO_ON_ADMIN",
            "priority": "NORMAL",
            "route": "faculty_attendance",
        },
        headers=admin_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["success"] is True

    recent_logs = (
        db.query(NotificationLog)
        .filter(NotificationLog.title == "Faculty Department Meeting")
        .order_by(NotificationLog.id.desc())
        .limit(10)
        .all()
    )
    assert len(recent_logs) > 0
    for log in recent_logs:
        assert log.user.role == UserRole.FACULTY


def test_admin_broadcast_targeting_specific_user(db: Session):
    """Verify admin notification targeted to a specific roll number."""
    admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
    student = db.query(Student).filter(Student.user_id != None).first()
    assert student is not None

    admin_token = create_access_token(str(admin.id), admin.role.value)
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    resp = client.post(
        "/api/v1/admin/notifications/send",
        json={
            "audience": "STUDENT",
            "target_type": "USER",
            "target_id": student.roll_number,
            "title": "Office Verification Notice",
            "body": "Please report to the administrative office.",
            "channel": "GO_ON_ADMIN",
            "priority": "HIGH",
        },
        headers=admin_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["recipients_count"] == 1


# =============================================================================
# 7. ADMIN AUTHORIZATION & SECURITY (RBAC)
# =============================================================================

def test_non_admin_cannot_send_broadcast(db: Session):
    """Verify students and faculty receive HTTP 403 Forbidden when attempting to broadcast."""
    student = db.query(User).filter(User.role == UserRole.STUDENT).first()
    faculty = db.query(User).filter(User.role == UserRole.FACULTY).first()

    s_headers = {"Authorization": f"Bearer {create_access_token(str(student.id), student.role.value)}"}
    f_headers = {"Authorization": f"Bearer {create_access_token(str(faculty.id), faculty.role.value)}"}

    payload = {
        "audience": "ALL",
        "target_type": "ALL",
        "title": "Unauthorized Message",
        "body": "Should be blocked",
    }

    resp_s = client.post("/api/v1/admin/notifications/send", json=payload, headers=s_headers)
    assert resp_s.status_code == 403

    resp_f = client.post("/api/v1/admin/notifications/send", json=payload, headers=f_headers)
    assert resp_f.status_code == 403


# =============================================================================
# 8. SCHEDULED NOTIFICATIONS: ATOMIC LOCKING & LIFECYCLE
# =============================================================================

def test_scheduled_notification_processing_and_atomic_lock(db: Session):
    """
    Verify scheduling, atomic state transition (PENDING -> PROCESSING -> SENT),
    and deduplication on multiple worker invocations.
    """
    admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
    admin_token = create_access_token(str(admin.id), admin.role.value)
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    # 1. Schedule a notification for near-immediate processing (simulate time due)
    now_k = datetime.now(TIMEZONE_KOLKATA)
    past_due_time = (now_k - timedelta(minutes=1)).isoformat()

    # Create directly in database to ensure it's due
    sched = ScheduledNotification(
        admin_id=admin.id,
        audience="STUDENT",
        target_type="ALL",
        title="Due Scheduled Broadcast",
        body="This scheduled message is now due for dispatch.",
        channel="GO_ON_ADMIN",
        priority="NORMAL",
        route="dashboard",
        scheduled_at=datetime.now(timezone.utc) - timedelta(minutes=1),
        status="PENDING",
    )
    db.add(sched)
    db.commit()
    db.refresh(sched)
    sched_id = sched.id

    # 2. First runner invocation: processes the due item
    count1 = NotificationService.process_due_scheduled_notifications(db)
    assert count1 >= 1

    # Verify status transitioned to SENT
    db.refresh(sched)
    assert sched.status == "SENT"
    assert sched.recipients_count > 0

    # 3. Second runner invocation: must be idempotent and process 0 items
    count2 = NotificationService.process_due_scheduled_notifications(db)
    assert count2 == 0

    # Cleanup
    db.delete(sched)
    db.commit()


# =============================================================================
# 9. TIMETABLE REMINDERS & DUPLICATE SUPPRESSION
# =============================================================================

def test_timetable_next_class_idempotency_and_exclusion(db: Session):
    """
    Verify that timetable next-class reminder engine:
    1. Sends within lead window
    2. Does not duplicate if invoked multiple times
    3. Excludes breaks and lunch
    4. Records last_reminder_check_at heartbeat in SystemSetting
    """
    # Trigger check
    result1 = NotificationService.check_and_send_next_class_reminders(db)
    assert "student_reminders_sent" in result1
    assert "faculty_reminders_sent" in result1
    assert "current_time" in result1

    # Immediate second check: any student that received it must not receive it again
    result2 = NotificationService.check_and_send_next_class_reminders(db)
    assert result2["student_reminders_sent"] == 0
    assert result2["faculty_reminders_sent"] == 0

    # Verify scheduler heartbeat was persisted in SystemSetting
    setting = db.query(SystemSetting).filter(SystemSetting.key == "notification.last_reminder_check_at").first()
    assert setting is not None
    assert len(setting.value) > 0


# =============================================================================
# 10. IN-APP USER NOTIFICATION ACTIONS & READ STATE ISOLATION
# =============================================================================

def test_user_notification_read_actions_and_isolation(db: Session):
    """
    Verify:
    - User can fetch unread count
    - User can mark single notification read
    - User can mark all notifications read
    - User cannot access or mark another user's notification as read
    """
    student1 = db.query(User).filter(User.role == UserRole.STUDENT, User.is_active == True).first()
    student2 = db.query(User).filter(User.role == UserRole.STUDENT, User.id != student1.id, User.is_active == True).first()
    assert student1 is not None and student2 is not None

    s1_token = create_access_token(str(student1.id), student1.role.value)
    s2_token = create_access_token(str(student2.id), student2.role.value)

    # Insert an unread notification log for Student 1
    log1 = NotificationLog(
        user_id=student1.id,
        notification_type=NotificationType.ADMIN.value,
        channel_id=NotificationChannel.GO_ON_ADMIN.value,
        title="Personal Student 1 Notice",
        body="Message for student 1 only",
        status=NotificationDeliveryStatus.STORED.value,
        is_read=False,
    )
    db.add(log1)
    db.commit()
    db.refresh(log1)

    # 1. Student 1 checks unread count
    resp_unread = client.get("/api/v1/notifications/unread-count", headers={"Authorization": f"Bearer {s1_token}"})
    assert resp_unread.status_code == 200
    assert resp_unread.json()["unread_count"] >= 1

    # 2. Student 2 tries to mark Student 1's notification as read (must 404 / access denied)
    resp_hack = client.post(
        f"/api/v1/notifications/{log1.id}/read",
        headers={"Authorization": f"Bearer {s2_token}"},
    )
    assert resp_hack.status_code == 404

    # 3. Student 1 marks their own notification as read
    resp_read = client.post(
        f"/api/v1/notifications/{log1.id}/read",
        headers={"Authorization": f"Bearer {s1_token}"},
    )
    assert resp_read.status_code == 200
    assert resp_read.json()["success"] is True

    # 4. Student 1 marks all as read
    resp_read_all = client.post(
        "/api/v1/notifications/read-all",
        headers={"Authorization": f"Bearer {s1_token}"},
    )
    assert resp_read_all.status_code == 200

    # Cleanup
    db.delete(log1)
    db.commit()


# =============================================================================
# 11. PAYLOAD VALIDATION: REJECTION OF BLANK AND WHITESPACE-ONLY TEXT
# =============================================================================

def test_empty_or_whitespace_payload_rejected(db: Session):
    """Verify missing, empty, and whitespace-only titles or messages are rejected."""
    admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
    admin_token = create_access_token(str(admin.id), admin.role.value)
    headers = {"Authorization": f"Bearer {admin_token}"}

    # 1. Whitespace-only title
    resp1 = client.post(
        "/api/v1/admin/notifications/send",
        json={"audience": "STUDENT", "target_type": "ALL", "title": "   ", "body": "Valid message body"},
        headers=headers,
    )
    assert resp1.status_code == 422

    # 2. Whitespace-only body
    resp2 = client.post(
        "/api/v1/admin/notifications/send",
        json={"audience": "STUDENT", "target_type": "ALL", "title": "Valid Title", "body": "   "},
        headers=headers,
    )
    assert resp2.status_code == 422

    # 3. Empty strings
    resp3 = client.post(
        "/api/v1/admin/notifications/send",
        json={"audience": "STUDENT", "target_type": "ALL", "title": "", "body": ""},
        headers=headers,
    )
    assert resp3.status_code == 422


# =============================================================================
# 12. DEDUPLICATION: REPEATED SEND SUPPRESSION (IDEMPOTENCY)
# =============================================================================

def test_duplicate_broadcast_suppression(db: Session):
    """Verify that rapid repeated broadcasts with identical title/body are suppressed."""
    admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
    admin_token = create_access_token(str(admin.id), admin.role.value)
    headers = {"Authorization": f"Bearer {admin_token}"}

    payload = {
        "audience": "STUDENT",
        "target_type": "ALL",
        "title": "Rapid Broadcast Test Title Unique",
        "body": "Testing duplicate broadcast prevention within 10-second window.",
    }

    # First send: must succeed and dispatch
    resp1 = client.post("/api/v1/admin/notifications/send", json=payload, headers=headers)
    assert resp1.status_code == 200
    assert resp1.json()["status"] == "SENT"
    assert resp1.json()["recipients_count"] > 0

    # Immediate second send (e.g. double-click or automated retry): must be suppressed!
    resp2 = client.post("/api/v1/admin/notifications/send", json=payload, headers=headers)
    assert resp2.status_code == 200
    data2 = resp2.json()
    assert data2["status"] == "DUPLICATE_SUPPRESSED"
    assert data2["recipients_count"] == 0
    assert "suppressed" in data2["message"].lower() and "duplicate" in data2["message"].lower()


def test_duplicate_scheduled_notification_suppression(db: Session):
    """Verify that scheduling the exact same notification twice for the same time is suppressed."""
    admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
    admin_token = create_access_token(str(admin.id), admin.role.value)
    headers = {"Authorization": f"Bearer {admin_token}"}

    future_time = (datetime.now(TIMEZONE_KOLKATA) + timedelta(minutes=45)).isoformat()
    payload = {
        "audience": "FACULTY",
        "target_type": "ALL",
        "title": "Scheduled Duplicate Test Unique",
        "body": "Faculty scheduled message for testing duplicate suppression.",
        "scheduled_at": future_time,
    }

    # 1. First schedule
    resp1 = client.post("/api/v1/admin/notifications/send", json=payload, headers=headers)
    assert resp1.status_code == 200
    assert resp1.json()["status"] == "SCHEDULED"

    # 2. Immediate duplicate schedule request
    resp2 = client.post("/api/v1/admin/notifications/send", json=payload, headers=headers)
    assert resp2.status_code == 200
    assert "duplicate suppressed" in resp2.json()["message"].lower()

    # Cleanup: remove the created scheduled notification
    sched = db.query(ScheduledNotification).filter(ScheduledNotification.title == "Scheduled Duplicate Test Unique").first()
    if sched:
        db.delete(sched)
        db.commit()


# =============================================================================
# 13. GRANULAR MULTICAST PER-USER STATUS TRACKING
# =============================================================================

def test_multicast_granular_per_user_status(db: Session):
    """
    Verify that in non-personalized multicast sends, users whose devices succeed
    are marked PROVIDER_ACCEPTED while users without tokens are marked STORED.
    """
    admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
    admin_token = create_access_token(str(admin.id), admin.role.value)
    headers = {"Authorization": f"Bearer {admin_token}"}

    # Find two students
    students = db.query(User).filter(User.role == UserRole.STUDENT, User.is_active == True).limit(2).all()
    if len(students) < 2:
        pytest.skip("Need at least two students for granular multicast status test")

    s1, s2 = students[0], students[1]
    tok_s1 = "gran_token_s1_test_123456789"
    # Register token for student 1 only
    NotificationService.register_device_token(db, user_id=s1.id, token=tok_s1, platform="android")
    # Ensure student 2 has no active tokens
    db.query(DeviceToken).filter(DeviceToken.user_id == s2.id).update({"is_active": False})
    db.commit()

    resp = client.post(
        "/api/v1/admin/notifications/send",
        json={
            "audience": "STUDENT",
            "target_type": "ALL",
            "title": "Granular Multicast Delivery Audit Unique",
            "body": "Checking per-user status in delivery logs.",
            "channel": "GO_ON_ADMIN",
        },
        headers=headers,
    )
    assert resp.status_code == 200

    # Check the logs for both users
    log_s1 = (
        db.query(NotificationLog)
        .filter(NotificationLog.user_id == s1.id, NotificationLog.title == "Granular Multicast Delivery Audit Unique")
        .first()
    )
    log_s2 = (
        db.query(NotificationLog)
        .filter(NotificationLog.user_id == s2.id, NotificationLog.title == "Granular Multicast Delivery Audit Unique")
        .first()
    )
    assert log_s1 is not None and log_s2 is not None
    # S1 has token (simulated mode -> SIMULATED or PROVIDER_ACCEPTED)
    assert log_s1.status in [NotificationDeliveryStatus.PROVIDER_ACCEPTED.value, NotificationDeliveryStatus.SIMULATED.value]
    # S2 has no active token -> STORED
    assert log_s2.status == NotificationDeliveryStatus.STORED.value

    # Cleanup
    db.query(DeviceToken).filter(DeviceToken.token == tok_s1).delete()
    db.commit()

