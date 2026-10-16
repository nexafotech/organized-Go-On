import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.core.database import SessionLocal, get_db
from app.models.user import User, UserRole, Faculty
from app.models.student import Student
from app.models.notification import (
    NotificationLog, DeviceToken, NotificationType, NotificationChannel,
    NotificationDeliveryStatus
)
from app.services.notification_service import NotificationService, TIMEZONE_KOLKATA
from app.core.security import create_access_token


@pytest.fixture
def db():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client():
    return TestClient(app)


import uuid


@pytest.fixture
def test_users(db: Session):
    """Creates isolated test users: admin, student1, student2, faculty."""
    uid = uuid.uuid4().hex[:8]
    
    # 1. Admin
    admin = User(
        username=f"audit_admin_{uid}",
        hashed_password="test_hashed_password",
        role=UserRole.ADMIN,
        is_active=True,
    )
    db.add(admin)

    # 2. Student 1
    stu1_user = User(
        username=f"audit_stu1_{uid}",
        hashed_password="test_hashed_password",
        role=UserRole.STUDENT,
        is_active=True,
    )
    db.add(stu1_user)
    db.flush()

    stu1 = Student(
        user_id=stu1_user.id,
        roll_number=f"ROLL1_{uid}",
        full_name="Audit Student One",
    )
    db.add(stu1)

    # 3. Student 2
    stu2_user = User(
        username=f"audit_stu2_{uid}",
        hashed_password="test_hashed_password",
        role=UserRole.STUDENT,
        is_active=True,
    )
    db.add(stu2_user)
    db.flush()

    stu2 = Student(
        user_id=stu2_user.id,
        roll_number=f"ROLL2_{uid}",
        full_name="Audit Student Two",
    )
    db.add(stu2)

    # 4. Faculty
    fac_user = User(
        username=f"audit_fac_{uid}",
        hashed_password="test_hashed_password",
        role=UserRole.FACULTY,
        is_active=True,
    )
    db.add(fac_user)
    db.flush()

    fac = Faculty(
        user_id=fac_user.id,
        employee_id=f"EMP_{uid}",
        full_name="Audit Faculty One",
        department="Computer Science",
    )
    db.add(fac)

    db.commit()
    db.refresh(admin)
    db.refresh(stu1_user)
    db.refresh(stu2_user)
    db.refresh(fac_user)

    return {
        "admin": admin,
        "student1": stu1_user,
        "student2": stu2_user,
        "faculty": fac_user,
    }


def auth_header(user: User) -> dict:
    role_str = user.role.value if hasattr(user.role, 'value') else str(user.role)
    token = create_access_token(subject=str(user.id), role=role_str)
    return {"Authorization": f"Bearer {token}"}


class TestNotificationDeleteAndPin:
    def test_soft_delete_persistence_and_inbox_exclusion(self, client: TestClient, db: Session, test_users: dict):
        student = test_users["student1"]
        headers = auth_header(student)

        # 1. Create 2 test notifications directly
        notif1 = NotificationLog(
            user_id=student.id,
            notification_type="GENERAL",
            channel_id="GO_ON_GENERAL",
            title="Notification 1 to Delete",
            body="This notification will be deleted via swipe-left.",
            status="STORED",
            is_read=False,
            is_deleted=False,
        )
        notif2 = NotificationLog(
            user_id=student.id,
            notification_type="GENERAL",
            channel_id="GO_ON_GENERAL",
            title="Notification 2 to Keep",
            body="This notification should remain in inbox.",
            status="STORED",
            is_read=False,
            is_deleted=False,
        )
        db.add_all([notif1, notif2])
        db.commit()
        db.refresh(notif1)
        db.refresh(notif2)

        # Initial unread count should be at least 2
        res_unread = client.get("/api/v1/notifications/unread-count", headers=headers)
        assert res_unread.status_code == 200
        initial_count = res_unread.json()["unread_count"]
        assert initial_count >= 2

        # 2. Perform soft-delete on notif1
        del_res = client.delete(f"/api/v1/notifications/{notif1.id}", headers=headers)
        assert del_res.status_code == 200
        assert del_res.json()["success"] is True

        # 3. Verify inbox history query excludes notif1
        hist_res = client.get("/api/v1/notifications/history", headers=headers)
        assert hist_res.status_code == 200
        items = hist_res.json()
        item_ids = [item["id"] for item in items]
        assert notif1.id not in item_ids
        assert notif2.id in item_ids

        # 4. Verify unread count decreased by 1
        res_unread_after = client.get("/api/v1/notifications/unread-count", headers=headers)
        assert res_unread_after.json()["unread_count"] == initial_count - 1

        # 5. Authoritative database check: row is preserved with is_deleted=True
        db.expire_all()
        db_row = db.query(NotificationLog).filter(NotificationLog.id == notif1.id).first()
        assert db_row is not None
        assert db_row.is_deleted is True
        assert db_row.deleted_at is not None

        # 6. Subsequent refresh / pagination query still excludes it
        hist_page2 = client.get("/api/v1/notifications/history?skip=0&limit=10", headers=headers)
        assert notif1.id not in [item["id"] for item in hist_page2.json()]

    def test_swipe_right_pin_persistence_and_ordering(self, client: TestClient, db: Session, test_users: dict):
        student = test_users["student1"]
        headers = auth_header(student)

        # Create 3 notifications with distinct creation timestamps
        base_time = datetime.now(timezone.utc) - timedelta(hours=3)
        n1 = NotificationLog(
            user_id=student.id,
            notification_type="GENERAL",
            channel_id="GO_ON_GENERAL",
            title="First Notice (Oldest)",
            body="Body 1",
            status="STORED",
            is_pinned=False,
            created_at=base_time,
        )
        n2 = NotificationLog(
            user_id=student.id,
            notification_type="GENERAL",
            channel_id="GO_ON_GENERAL",
            title="Second Notice (Middle)",
            body="Body 2",
            status="STORED",
            is_pinned=False,
            created_at=base_time + timedelta(hours=1),
        )
        n3 = NotificationLog(
            user_id=student.id,
            notification_type="GENERAL",
            channel_id="GO_ON_GENERAL",
            title="Third Notice (Newest)",
            body="Body 3",
            status="STORED",
            is_pinned=False,
            created_at=base_time + timedelta(hours=2),
        )
        db.add_all([n1, n2, n3])
        db.commit()
        db.refresh(n1)
        db.refresh(n2)
        db.refresh(n3)

        # Pin notification 1 (oldest notice)
        pin_res = client.post(f"/api/v1/notifications/{n1.id}/pin", headers=headers)
        assert pin_res.status_code == 200
        assert pin_res.json()["success"] is True

        # Query history: n1 must now be at the very top (index 0) even though it is the oldest
        hist_res = client.get("/api/v1/notifications/history", headers=headers)
        items = hist_res.json()
        assert items[0]["id"] == n1.id
        assert items[0]["is_pinned"] is True

        # Now pin notification 2 (pinned later -> higher pinned_at)
        pin_res2 = client.post(f"/api/v1/notifications/{n2.id}/pin", headers=headers)
        assert pin_res2.status_code == 200

        # Query history: n2 must be index 0, n1 index 1, n3 index 2 (deterministic pin sorting)
        hist_res2 = client.get("/api/v1/notifications/history", headers=headers)
        items2 = hist_res2.json()
        assert items2[0]["id"] == n2.id
        assert items2[1]["id"] == n1.id

        # Unpin notification 2
        unpin_res = client.post(f"/api/v1/notifications/{n2.id}/unpin", headers=headers)
        assert unpin_res.status_code == 200
        assert unpin_res.json()["success"] is True

        # Query history: n1 remains pinned at index 0, followed by n3 (newest unpinned), then n2
        hist_res3 = client.get("/api/v1/notifications/history", headers=headers)
        items3 = hist_res3.json()
        assert items3[0]["id"] == n1.id
        assert items3[0]["is_pinned"] is True

    def test_user_isolation_for_delete_and_pin(self, client: TestClient, db: Session, test_users: dict):
        student1 = test_users["student1"]
        student2 = test_users["student2"]
        h1 = auth_header(student1)
        h2 = auth_header(student2)

        # Create private notification for Student 2
        private_notif = NotificationLog(
            user_id=student2.id,
            notification_type="ACCOUNT",
            channel_id="GO_ON_ACCOUNT",
            title="Student 2 Private Notice",
            body="Confidential account credentials.",
            status="STORED",
            is_read=False,
            is_deleted=False,
        )
        db.add(private_notif)
        db.commit()
        db.refresh(private_notif)

        # 1. Student 1 must not see Student 2's notification in history
        hist1 = client.get("/api/v1/notifications/history", headers=h1).json()
        assert private_notif.id not in [it["id"] for it in hist1]

        # 2. Student 1 attempts to delete Student 2's notification -> 404
        del_attempt = client.delete(f"/api/v1/notifications/{private_notif.id}", headers=h1)
        assert del_attempt.status_code == 404

        # 3. Student 1 attempts to pin Student 2's notification -> 404
        pin_attempt = client.post(f"/api/v1/notifications/{private_notif.id}/pin", headers=h1)
        assert pin_attempt.status_code == 404

        # 4. Verify Student 2's notification is completely untouched
        db.refresh(private_notif)
        assert private_notif.is_deleted is False
        assert private_notif.is_pinned is False

        # 5. Student 2 can delete their own notification
        del_ok = client.delete(f"/api/v1/notifications/{private_notif.id}", headers=h2)
        assert del_ok.status_code == 200

    def test_role_isolation_broadcast_targeting(self, client: TestClient, db: Session, test_users: dict):
        admin = test_users["admin"]
        student = test_users["student1"]
        faculty = test_users["faculty"]
        h_admin = auth_header(admin)
        h_student = auth_header(student)
        h_faculty = auth_header(faculty)

        # 1. Admin sends broadcast to STUDENTS only
        res_stu = client.post(
            "/api/v1/admin/notifications/send",
            json={
                "audience": "STUDENT",
                "target_type": "ALL",
                "title": "Students Only Notice",
                "body": "Exam hall tickets are available.",
                "channel": "GO_ON_ADMIN",
                "priority": "NORMAL",
            },
            headers=h_admin,
        )
        assert res_stu.status_code == 200

        # Faculty inbox must NOT receive this student broadcast
        fac_hist = client.get("/api/v1/notifications/history", headers=h_faculty).json()
        assert not any("Students Only Notice" in it["title"] for it in fac_hist)

        # Student inbox MUST receive it
        stu_hist = client.get("/api/v1/notifications/history", headers=h_student).json()
        assert any("Students Only Notice" in it["title"] for it in stu_hist)

        # 2. Admin sends broadcast to FACULTY only
        res_fac = client.post(
            "/api/v1/admin/notifications/send",
            json={
                "audience": "FACULTY",
                "target_type": "ALL",
                "title": "Faculty Meeting Notice",
                "body": "Department meeting at 4 PM.",
                "channel": "GO_ON_ADMIN",
                "priority": "HIGH",
            },
            headers=h_admin,
        )
        assert res_fac.status_code == 200

        # Student inbox must NOT receive the faculty broadcast
        stu_hist2 = client.get("/api/v1/notifications/history", headers=h_student).json()
        assert not any("Faculty Meeting Notice" in it["title"] for it in stu_hist2)

        # Faculty inbox MUST receive it
        fac_hist2 = client.get("/api/v1/notifications/history", headers=h_faculty).json()
        assert any("Faculty Meeting Notice" in it["title"] for it in fac_hist2)

    def test_truthful_delivery_reporting_when_no_token(self, client: TestClient, db: Session, test_users: dict):
        admin = test_users["admin"]
        student = test_users["student1"]
        h_admin = auth_header(admin)

        # Ensure student1 has NO active device tokens
        db.query(DeviceToken).filter(DeviceToken.user_id == student.id).update({"is_active": False})
        db.commit()

        # Send targeted notification to this student
        res = client.post(
            "/api/v1/admin/notifications/send",
            json={
                "audience": "STUDENT",
                "target_type": "USER",
                "target_id": str(student.id),
                "title": "Targeted Audit Notice",
                "body": "Checking truthful status reporting.",
                "channel": "GO_ON_ADMIN",
                "priority": "NORMAL",
            },
            headers=h_admin,
        )
        assert res.status_code == 200
        data = res.json()
        assert data["recipients_count"] == 1
        assert data["devices_targeted"] == 0
        assert data["devices_sent"] == 0

        # Check DB log status is STORED, not a misleading SENT
        log = (
            db.query(NotificationLog)
            .filter(NotificationLog.user_id == student.id, NotificationLog.title == "Targeted Audit Notice")
            .first()
        )
        assert log is not None
        assert log.status == NotificationDeliveryStatus.STORED.value
        assert "No active device registered" in log.error_message

    def test_pinned_notification_cannot_be_deleted_until_unpinned(self, client: TestClient, db: Session, test_users: dict):
        student = test_users["student1"]
        headers = auth_header(student)

        # 1. Create a notification and pin it
        notif = NotificationLog(
            user_id=student.id,
            notification_type="GENERAL",
            channel_id="GO_ON_GENERAL",
            title="Important Pinned Notice",
            body="This notice must never be deleted while pinned.",
            status="STORED",
            is_read=False,
            is_pinned=True,
            pinned_at=datetime.now(timezone.utc),
            is_deleted=False,
        )
        db.add(notif)
        db.commit()
        db.refresh(notif)

        # 2. Attempt deletion while pinned -> MUST BE REJECTED WITH 400
        del_attempt = client.delete(f"/api/v1/notifications/{notif.id}", headers=headers)
        assert del_attempt.status_code == 400
        assert "Pinned notifications cannot be deleted" in del_attempt.json()["detail"]

        # 3. Verify in database: not deleted
        db.expire_all()
        check_db = db.query(NotificationLog).filter(NotificationLog.id == notif.id).first()
        assert check_db is not None
        assert check_db.is_deleted is False
        assert check_db.is_pinned is True

        # 4. Unpin the notification
        unpin_res = client.post(f"/api/v1/notifications/{notif.id}/unpin", headers=headers)
        assert unpin_res.status_code == 200
        assert unpin_res.json()["success"] is True

        # 5. Verify unpinned in database
        db.expire_all()
        check_unpinned = db.query(NotificationLog).filter(NotificationLog.id == notif.id).first()
        assert check_unpinned.is_pinned is False

        # 6. Now deletion must succeed
        del_success = client.delete(f"/api/v1/notifications/{notif.id}", headers=headers)
        assert del_success.status_code == 200
        assert del_success.json()["success"] is True

        # 7. Verify soft-deleted in database
        db.expire_all()
        check_deleted = db.query(NotificationLog).filter(NotificationLog.id == notif.id).first()
        assert check_deleted.is_deleted is True
        assert check_deleted.deleted_at is not None
