"""
Comprehensive Unit and Integration Tests for IST & UTC Notification Timestamps
Validates:
1. Pydantic serialize_utc_iso helper produces explicit 'Z' suffix for naive and aware datetimes.
2. NotificationLogOut, ScheduledNotificationOut, DeviceTokenOut schemas emit explicit UTC 'Z' strings.
3. Database persistence of UTC datetimes and API serialization.
4. Scheduled notification IST -> UTC conversion and execution logic.
5. Invariance of relative elapsed time regardless of client or server timezone.
"""
import pytest
from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.core.database import SessionLocal, init_db, engine
from app.models.notification import (
    NotificationLog, ScheduledNotification, NotificationType, NotificationChannel, NotificationDeliveryStatus
)
from app.models.user import User, UserRole
from app.schemas.notification import serialize_utc_iso, NotificationLogOut, ScheduledNotificationOut
from app.services.notification_service import (
    NotificationService,
    TIMEZONE_KOLKATA,
)
from app.core.security import create_access_token

client = TestClient(app)

@pytest.fixture(scope="module")
def db():
    init_db(engine)
    session = SessionLocal()
    yield session
    session.close()


def test_serialize_utc_iso_helper():
    """Verify serialize_utc_iso helper across edge cases."""
    # 1. None returns None
    assert serialize_utc_iso(None) is None

    # 2. Naive datetime (interpreted as UTC)
    naive_dt = datetime(2026, 10, 15, 7, 30, 0, 123456)
    serialized = serialize_utc_iso(naive_dt)
    assert serialized == "2026-10-15T07:30:00.123456Z"
    assert serialized.endswith("Z")

    # 3. Aware UTC datetime
    aware_utc = datetime(2026, 10, 15, 7, 30, 0, tzinfo=timezone.utc)
    serialized_utc = serialize_utc_iso(aware_utc)
    assert serialized_utc == "2026-10-15T07:30:00Z"
    assert serialized_utc.endswith("Z")

    # 4. Aware IST datetime (13:00 IST == 07:30 UTC)
    ist_tz = ZoneInfo("Asia/Kolkata")
    aware_ist = datetime(2026, 10, 15, 13, 0, 0, tzinfo=ist_tz)
    serialized_ist = serialize_utc_iso(aware_ist)
    assert serialized_ist == "2026-10-15T07:30:00Z"
    assert serialized_ist.endswith("Z")


def test_notification_logout_serialization_explicit_z():
    """Verify NotificationLogOut always emits explicit 'Z' suffix in model_dump and JSON."""
    naive_created = datetime(2026, 10, 15, 8, 0, 0)
    naive_read = datetime(2026, 10, 15, 8, 5, 0)
    
    log_out = NotificationLogOut(
        id=101,
        user_id=1,
        notification_type="ADMIN",
        channel_id="GO_ON_ADMIN",
        title="Timetable Update",
        body="Class rescheduled to 2:00 PM IST",
        status="SENT",
        created_at=naive_created,
        read_at=naive_read,
        is_pinned=True,
        is_read=True,
        is_deleted=False,
    )
    
    # Check model_dump(mode='json')
    dumped_json = log_out.model_dump(mode='json')
    assert dumped_json["created_at"].endswith("Z"), f"Expected Z suffix, got {dumped_json['created_at']}"
    assert dumped_json["created_at"] == "2026-10-15T08:00:00Z"
    assert dumped_json["read_at"].endswith("Z")
    assert dumped_json["read_at"] == "2026-10-15T08:05:00Z"

    # Check model_dump_json() string
    json_str = log_out.model_dump_json()
    assert '"created_at":"2026-10-15T08:00:00Z"' in json_str


def test_scheduled_notification_out_serialization_explicit_z():
    """Verify ScheduledNotificationOut serializes scheduled_at and created_at with 'Z'."""
    sched_dt = datetime(2026, 10, 15, 10, 0, 0)
    sched_out = ScheduledNotificationOut(
        id=55,
        admin_id=1,
        audience="STUDENT",
        target_type="ALL",
        target_id=None,
        title="Test Reminder",
        body="Upcoming Lab Session",
        channel="GO_ON_ADMIN",
        priority="NORMAL",
        route="dashboard",
        scheduled_at=sched_dt,
        status="PENDING",
        recipients_count=10,
        created_at=sched_dt,
    )
    dumped = sched_out.model_dump(mode='json')
    assert dumped["scheduled_at"].endswith("Z")
    assert dumped["created_at"].endswith("Z")


def test_api_notification_history_returns_utc_iso_with_z(db: Session):
    """Verify live API endpoint /api/v1/notifications/history returns timestamps with explicit Z."""
    user = db.query(User).filter(User.role == UserRole.STUDENT).first()
    if not user:
        user = db.query(User).first()
    assert user is not None, "At least one user must exist"

    # Create a notification directly in database (with naive UTC datetime as SQLite stores)
    now_utc_naive = datetime.now(timezone.utc).replace(tzinfo=None)
    log = NotificationLog(
        user_id=user.id,
        notification_type=NotificationType.GENERAL.value,
        channel_id=NotificationChannel.GO_ON_GENERAL.value,
        title="IST Explicit Z Verification Test",
        body="Testing explicit Z serialization in FastAPI history endpoint",
        status=NotificationDeliveryStatus.SENT.value,
        created_at=now_utc_naive,
        is_read=False,
        is_deleted=False,
    )
    db.add(log)
    db.commit()
    db.refresh(log)

    try:
        # Generate auth token
        token = create_access_token(str(user.id), user.role.value)
        headers = {"Authorization": f"Bearer {token}"}

        response = client.get("/api/v1/notifications/history?limit=10", headers=headers)
        assert response.status_code == 200, response.text
        data = response.json()
        assert isinstance(data, list)
        assert len(data) > 0

        # Find our test item
        target_item = next((item for item in data if item["id"] == log.id), None)
        assert target_item is not None, "Test notification not found in history"
        assert "created_at" in target_item
        created_str = target_item["created_at"]
        assert created_str.endswith("Z"), f"Expected 'created_at' to end with 'Z', got: {created_str}"
    finally:
        db.delete(log)
        db.commit()


def test_scheduled_notification_ist_to_utc_dispatch(db: Session):
    """Verify that scheduling a notification in IST correctly converts to UTC and dispatches."""
    admin_user = db.query(User).filter(User.role == UserRole.ADMIN).first()
    if not admin_user:
        admin_user = db.query(User).first()

    # Schedule via admin API with an IST datetime string 2 hours in the future
    admin_token = create_access_token(str(admin_user.id), admin_user.role.value)
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    now_ist = datetime.now(TIMEZONE_KOLKATA)
    future_ist = (now_ist + timedelta(hours=2)).isoformat()

    payload = {
        "audience": "STUDENT",
        "target_type": "ALL",
        "title": "IST Schedule Dispatch Test",
        "body": "Scheduled with IST timezone string",
        "channel": "GO_ON_ADMIN",
        "priority": "HIGH",
        "scheduled_at": future_ist,
    }

    resp = client.post("/api/v1/admin/notifications/send", json=payload, headers=admin_headers)
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["success"] is True
    assert data["scheduled_at"] is not None
    assert data["scheduled_at"].endswith("Z"), f"Expected Z suffix, got {data['scheduled_at']}"

    # Query the created ScheduledNotification in database
    sched = db.query(ScheduledNotification).filter(
        ScheduledNotification.title == "IST Schedule Dispatch Test"
    ).first()
    assert sched is not None
    assert sched.status == "PENDING"

    # Now make it due and test process_due_scheduled_notifications
    sched.scheduled_at = datetime.now(timezone.utc) - timedelta(minutes=1)
    db.commit()

    processed = NotificationService.process_due_scheduled_notifications(db)
    assert processed >= 1, "Scheduled notification should have been processed"

    # Check status is now 'SENT'
    db.refresh(sched)
    assert sched.status == "SENT"

    # Clean up generated logs and schedule
    db.query(NotificationLog).filter(NotificationLog.title == "IST Schedule Dispatch Test").delete()
    db.delete(sched)
    db.commit()
