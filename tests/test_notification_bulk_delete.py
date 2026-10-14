import pytest
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.core.database import SessionLocal, get_db
from app.models.user import User, UserRole
from app.models.notification import NotificationLog, NotificationChannel, NotificationType, NotificationDeliveryStatus
from app.services.notification_service import NotificationService
from app.core.security import create_access_token

client = TestClient(app)

@pytest.fixture
def db_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@pytest.fixture
def test_users(db_session: Session):
    # Retrieve or create test user 1 (faculty or student)
    user1 = db_session.query(User).filter(User.username == "test_bulk_user1").first()
    if not user1:
        user1 = User(
            username="test_bulk_user1",
            email="test_bulk_user1@college.edu",
            hashed_password="fakehashedpassword",
            role=UserRole.FACULTY.value,
            is_active=True,
        )
        db_session.add(user1)
        db_session.commit()
        db_session.refresh(user1)

    # User 2 to verify role/user isolation
    user2 = db_session.query(User).filter(User.username == "test_bulk_user2").first()
    if not user2:
        user2 = User(
            username="test_bulk_user2",
            email="test_bulk_user2@college.edu",
            hashed_password="fakehashedpassword",
            role=UserRole.STUDENT.value,
            is_active=True,
        )
        db_session.add(user2)
        db_session.commit()
        db_session.refresh(user2)

    return user1, user2

def create_sample_notifications(db: Session, user_id: int, count: int, pinned_indices: list):
    logs = []
    for i in range(count):
        is_pinned = i in pinned_indices
        log = NotificationLog(
            user_id=user_id,
            notification_type=NotificationType.GENERAL.value,
            channel_id=NotificationChannel.GO_ON_GENERAL.value,
            title=f"Notification #{i + 1} for User {user_id}",
            body=f"Body content for notification #{i + 1}",
            status=NotificationDeliveryStatus.SENT.value,
            is_read=False,
            is_pinned=is_pinned,
            pinned_at=datetime.now(timezone.utc) if is_pinned else None,
            is_deleted=False,
            created_at=datetime.now(timezone.utc),
        )
        db.add(log)
        logs.append(log)
    db.commit()
    for l in logs:
        db.refresh(l)
    return logs

def test_bulk_delete_unpinned_preserves_pinned(db_session: Session, test_users):
    user1, user2 = test_users
    # Clean previous logs for user1
    db_session.query(NotificationLog).filter(NotificationLog.user_id == user1.id).delete()
    db_session.commit()

    # Create 5 notifications: index 0 and 2 are pinned (2 pinned, 3 unpinned)
    create_sample_notifications(db_session, user1.id, count=5, pinned_indices=[0, 2])

    token = create_access_token(subject=str(user1.id), role=user1.role)
    headers = {"Authorization": f"Bearer {token}"}

    # Execute bulk delete
    response = client.delete("/api/v1/notifications/unpinned", headers=headers)
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["success"] is True
    assert data["deleted_count"] == 3
    assert data["pinned_preserved_count"] == 2

    # Query active notifications via history API
    history_resp = client.get("/api/v1/notifications/history", headers=headers)
    assert history_resp.status_code == 200
    active_items = history_resp.json()
    assert len(active_items) == 2
    for item in active_items:
        assert item["is_pinned"] is True
        assert item["is_deleted"] is False

def test_bulk_delete_when_all_are_pinned(db_session: Session, test_users):
    user1, _ = test_users
    db_session.query(NotificationLog).filter(NotificationLog.user_id == user1.id).delete()
    db_session.commit()

    # All 3 notifications are pinned
    create_sample_notifications(db_session, user1.id, count=3, pinned_indices=[0, 1, 2])

    token = create_access_token(subject=str(user1.id), role=user1.role)
    headers = {"Authorization": f"Bearer {token}"}

    response = client.delete("/api/v1/notifications/unpinned", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["deleted_count"] == 0
    assert data["pinned_preserved_count"] == 3

    # All 3 remain active
    history_resp = client.get("/api/v1/notifications/history", headers=headers)
    assert len(history_resp.json()) == 3

def test_bulk_delete_when_empty(db_session: Session, test_users):
    user1, _ = test_users
    db_session.query(NotificationLog).filter(NotificationLog.user_id == user1.id).delete()
    db_session.commit()

    token = create_access_token(subject=str(user1.id), role=user1.role)
    headers = {"Authorization": f"Bearer {token}"}

    response = client.delete("/api/v1/notifications/unpinned", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["deleted_count"] == 0
    assert data["pinned_preserved_count"] == 0

def test_bulk_delete_user_isolation(db_session: Session, test_users):
    user1, user2 = test_users
    # Clear both
    db_session.query(NotificationLog).filter(NotificationLog.user_id.in_([user1.id, user2.id])).delete()
    db_session.commit()

    # User 1: 4 unpinned
    create_sample_notifications(db_session, user1.id, count=4, pinned_indices=[])
    # User 2: 4 unpinned
    create_sample_notifications(db_session, user2.id, count=4, pinned_indices=[])

    token1 = create_access_token(subject=str(user1.id), role=user1.role)
    token2 = create_access_token(subject=str(user2.id), role=user2.role)

    # User 1 performs bulk delete
    resp1 = client.delete("/api/v1/notifications/unpinned", headers={"Authorization": f"Bearer {token1}"})
    assert resp1.status_code == 200
    assert resp1.json()["deleted_count"] == 4

    # User 2 notifications must remain 100% intact!
    resp2 = client.get("/api/v1/notifications/history", headers={"Authorization": f"Bearer {token2}"})
    assert resp2.status_code == 200
    assert len(resp2.json()) == 4

def test_unpin_then_bulk_delete(db_session: Session, test_users):
    user1, _ = test_users
    db_session.query(NotificationLog).filter(NotificationLog.user_id == user1.id).delete()
    db_session.commit()

    # 1 pinned notification
    logs = create_sample_notifications(db_session, user1.id, count=1, pinned_indices=[0])
    pinned_id = logs[0].id

    token = create_access_token(subject=str(user1.id), role=user1.role)
    headers = {"Authorization": f"Bearer {token}"}

    # Unpin it
    unpin_resp = client.post(f"/api/v1/notifications/{pinned_id}/unpin", headers=headers)
    assert unpin_resp.status_code == 200

    # Bulk delete should now delete it
    del_resp = client.delete("/api/v1/notifications/unpinned", headers=headers)
    assert del_resp.status_code == 200
    data = del_resp.json()
    assert data["deleted_count"] == 1
    assert data["pinned_preserved_count"] == 0

def test_post_alias_endpoint(db_session: Session, test_users):
    user1, _ = test_users
    db_session.query(NotificationLog).filter(NotificationLog.user_id == user1.id).delete()
    db_session.commit()

    create_sample_notifications(db_session, user1.id, count=2, pinned_indices=[1])

    token = create_access_token(subject=str(user1.id), role=user1.role)
    headers = {"Authorization": f"Bearer {token}"}

    # Test POST /delete-unpinned alias
    resp = client.post("/api/v1/notifications/delete-unpinned", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["deleted_count"] == 1
    assert resp.json()["pinned_preserved_count"] == 1
