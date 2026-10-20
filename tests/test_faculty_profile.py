import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.database import SessionLocal
from app.models.user import User, Faculty, UserRole
from app.core.security import create_access_token
from app.core.avatars import VALID_AVATAR_IDS

client = TestClient(app)


@pytest.fixture
def db_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def test_faculty_profile_endpoints_auth(db_session):
    # 1. Unauthenticated request should fail with 401
    res = client.get("/api/v1/faculty/profile")
    assert res.status_code == 401

    # 2. Student token should be rejected with 403
    student_user = db_session.query(User).filter(User.role == UserRole.STUDENT).first()
    if student_user:
        student_token = create_access_token(subject=student_user.id, role="student")
        res_student = client.get("/api/v1/faculty/profile", headers={"Authorization": f"Bearer {student_token}"})
        assert res_student.status_code == 403


def test_faculty_profile_get_and_update(db_session):
    # Find or use test faculty user
    fac_user = db_session.query(User).filter(User.role == UserRole.FACULTY).first()
    if not fac_user:
        pytest.skip("No faculty user in test database")

    token = create_access_token(subject=fac_user.id, role="faculty")
    headers = {"Authorization": f"Bearer {token}"}

    # 1. GET /api/v1/faculty/profile
    res = client.get("/api/v1/faculty/profile", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["success"] is True
    assert data["user_id"] == fac_user.id
    assert "full_name" in data
    assert "email" in data
    assert "phone" in data
    assert "avatar_id" in data
    assert "is_class_advisor" in data

    original_name = data["full_name"]
    original_email = data["email"]

    # 2. Validation failures: short name
    bad_name_res = client.patch(
        "/api/v1/faculty/profile",
        json={"full_name": "A"},
        headers=headers,
    )
    assert bad_name_res.status_code == 400
    assert "at least 2 characters" in bad_name_res.json()["detail"]

    # 3. Validation failures: invalid email
    bad_email_res = client.patch(
        "/api/v1/faculty/profile",
        json={"email": "invalid-email-address"},
        headers=headers,
    )
    assert bad_email_res.status_code == 400
    assert "Invalid email" in bad_email_res.json()["detail"]

    # 4. Validation failures: invalid phone
    bad_phone_res = client.patch(
        "/api/v1/faculty/profile",
        json={"phone": "123"},
        headers=headers,
    )
    assert bad_phone_res.status_code == 400
    assert "valid contact phone" in bad_phone_res.json()["detail"]

    # 5. Validation failures: invalid avatar
    bad_av_res = client.patch(
        "/api/v1/faculty/profile",
        json={"avatar_id": "nonexistent_avatar_999"},
        headers=headers,
    )
    assert bad_av_res.status_code == 400
    assert "Invalid avatar ID" in bad_av_res.json()["detail"]

    # 6. Valid Update
    target_avatar = list(VALID_AVATAR_IDS)[0]
    valid_patch = {
        "full_name": "Prof. Tested Faculty",
        "phone": "+91 98765 43210",
        "avatar_id": target_avatar,
    }
    update_res = client.patch(
        "/api/v1/faculty/profile",
        json=valid_patch,
        headers=headers,
    )
    assert update_res.status_code == 200
    updated_data = update_res.json()
    assert updated_data["full_name"] == "Prof. Tested Faculty"
    assert updated_data["phone"] == "+91 98765 43210"
    assert updated_data["avatar_id"] == target_avatar

    # 7. Quick Avatar Update endpoint
    second_avatar = list(VALID_AVATAR_IDS)[1]
    avatar_res = client.patch(
        "/api/v1/faculty/avatar",
        json={"avatar_id": second_avatar},
        headers=headers,
    )
    assert avatar_res.status_code == 200
    assert avatar_res.json()["avatar_id"] == second_avatar

    # 8. Unchanged avatar fast-path returns immediately
    unchanged_res = client.patch(
        "/api/v1/faculty/avatar",
        json={"avatar_id": second_avatar},
        headers=headers,
    )
    assert unchanged_res.status_code == 200
    assert unchanged_res.json()["message"] == "Avatar unchanged"

    # Restore original name if needed
    client.patch(
        "/api/v1/faculty/profile",
        json={"full_name": original_name},
        headers=headers,
    )
