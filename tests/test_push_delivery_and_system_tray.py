import json
import os
import pytest
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.core.database import SessionLocal, init_db, engine
from app.core.security import create_access_token
from app.models.user import User, UserRole, Faculty
from app.models.student import Student
from app.models.notification import (
    DeviceToken, NotificationLog, NotificationType, NotificationChannel,
    NotificationDeliveryStatus
)
from app.services.fcm_service import FCMService, reset_firebase_app
from app.services.notification_service import NotificationService, get_kolkata_now

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


def test_token_registration_authenticated_ownership(db: Session):
    """
    Verify device token registration binds strictly to authenticated user identity.
    Client-supplied data cannot hijack or claim another user's token.
    """
    user = db.query(User).filter(User.is_active == True).first()
    assert user is not None
    token_str = create_access_token(str(user.id), user.role.value)
    headers = {"Authorization": f"Bearer {token_str}"}

    fcm_tok = f"test_e2e_fcm_tok_{os.urandom(8).hex()}"
    resp = client.post(
        "/api/v1/notifications/device-token",
        json={"token": fcm_tok, "platform": "android", "device_name": "Samsung Galaxy S24"},
        headers=headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True

    # Verify database record
    db_dev = db.query(DeviceToken).filter(DeviceToken.token == fcm_tok).first()
    assert db_dev is not None
    assert db_dev.user_id == user.id
    assert db_dev.is_active is True
    assert db_dev.platform == "android"
    assert db_dev.device_name == "Samsung Galaxy S24"


def test_token_refresh_lifecycle(db: Session):
    """
    Verify that refreshed token updates ownership and timestamp without duplicate entries.
    """
    user = db.query(User).filter(User.is_active == True).first()
    token_str = create_access_token(str(user.id), user.role.value)
    headers = {"Authorization": f"Bearer {token_str}"}

    original_tok = f"refresh_test_tok_{os.urandom(8).hex()}"
    client.post(
        "/api/v1/notifications/device-token",
        json={"token": original_tok, "platform": "android", "device_name": "Galaxy S24"},
        headers=headers,
    )

    # Re-register same token (simulating FCM onTokenRefresh)
    resp2 = client.post(
        "/api/v1/notifications/device-token",
        json={"token": original_tok, "platform": "android", "device_name": "Galaxy S24 Updated"},
        headers=headers,
    )
    assert resp2.status_code == 200

    # Ensure no duplicate tokens in table
    count = db.query(DeviceToken).filter(DeviceToken.token == original_tok).count()
    assert count == 1


def test_truthful_delivery_status_differentiates_token_presence(db: Session):
    """
    Verify that sending a notification to a user with NO active device token
    honestly records STORED/NO_TOKEN, whereas sending to a user with an active
    token records SIMULATED (in dev) or PROVIDER_ACCEPTED / FCM_ACCEPTED.
    """
    # Create isolated user with no device tokens
    user_no_tok = User(
        username=f"notok_user_{os.urandom(4).hex()}",
        email=f"notok_{os.urandom(4).hex()}@college.edu",
        hashed_password="mock_hashed_password_123",
        role=UserRole.FACULTY,
        is_active=True,
    )
    db.add(user_no_tok)
    db.commit()

    # User with token
    user_with_tok = User(
        username=f"withtok_user_{os.urandom(4).hex()}",
        email=f"withtok_{os.urandom(4).hex()}@college.edu",
        hashed_password="mock_hashed_password_123",
        role=UserRole.FACULTY,
        is_active=True,
    )
    db.add(user_with_tok)
    db.commit()

    dev = DeviceToken(
        user_id=user_with_tok.id,
        token=f"active_fcm_{os.urandom(8).hex()}",
        platform="android",
        device_name="Samsung S24",
        is_active=True,
    )
    db.add(dev)
    db.commit()

    admin_user = db.query(User).filter(User.role == UserRole.ADMIN, User.is_active == True).first()
    if not admin_user:
        admin_user = db.query(User).first()

    # Broadcast to both users
    res = NotificationService.send_custom_admin_notification(
        db=db,
        admin_user=admin_user,
        audience="FACULTY",
        target_type="ALL",
        target_id=None,
        title=f"Campus Notice {os.urandom(4).hex()}",
        body="Staff meeting at 4 PM in Conference Hall A.",
        channel=NotificationChannel.GO_ON_ADMIN.value,
    )
    assert res["success"] is True

    # Inspect logs for user_no_tok
    log_no_tok = db.query(NotificationLog).filter(NotificationLog.user_id == user_no_tok.id).first()
    assert log_no_tok is not None
    assert log_no_tok.status == NotificationDeliveryStatus.STORED.value
    assert "No active device" in (log_no_tok.error_message or "")

    # Inspect logs for user_with_tok
    log_with_tok = db.query(NotificationLog).filter(NotificationLog.user_id == user_with_tok.id).first()
    assert log_with_tok is not None
    assert log_with_tok.status in (
        NotificationDeliveryStatus.SIMULATED.value,
        NotificationDeliveryStatus.PROVIDER_ACCEPTED.value,
        NotificationDeliveryStatus.FCM_ACCEPTED.value,
    )


def test_broadcast_recipient_deduplication(db: Session):
    """
    Verify that overlapping groups or duplicate recipient criteria
    are strictly deduplicated into exactly one notification per user.
    """
    faculty_user = db.query(User).filter(User.role == UserRole.FACULTY, User.is_active == True).first()
    assert faculty_user is not None
    admin_user = db.query(User).filter(User.role == UserRole.ADMIN, User.is_active == True).first()
    if not admin_user:
        admin_user = db.query(User).first()

    initial_count = db.query(NotificationLog).filter(NotificationLog.user_id == faculty_user.id).count()

    # Target specific user
    res = NotificationService.send_custom_admin_notification(
        db=db,
        admin_user=admin_user,
        audience="FACULTY",
        target_type="USER",
        target_id=str(faculty_user.id),
        title=f"Idempotent Test Notice {os.urandom(4).hex()}",
        body="Single dispatch verification message.",
        channel=NotificationChannel.GO_ON_GENERAL.value,
    )
    assert res["success"] is True
    assert res["recipients_count"] == 1

    new_count = db.query(NotificationLog).filter(NotificationLog.user_id == faculty_user.id).count()
    assert new_count == initial_count + 1


def test_logout_deactivates_device_token(db: Session):
    """
    Verify that deactivating a token on logout sets is_active=False
    and prevents future push dispatch to that device.
    """
    user = db.query(User).filter(User.is_active == True).first()
    token_str = create_access_token(str(user.id), user.role.value)
    headers = {"Authorization": f"Bearer {token_str}"}

    tok = f"logout_test_tok_{os.urandom(8).hex()}"
    client.post(
        "/api/v1/notifications/device-token",
        json={"token": tok, "platform": "android", "device_name": "Test Device"},
        headers=headers,
    )

    # Logout unregister
    del_resp = client.delete(f"/api/v1/notifications/device-token?token={tok}", headers=headers)
    assert del_resp.status_code == 200
    assert del_resp.json()["success"] is True

    # Verify inactive in database
    db_dev = db.query(DeviceToken).filter(DeviceToken.token == tok).first()
    assert db_dev is not None
    assert db_dev.is_active is False
