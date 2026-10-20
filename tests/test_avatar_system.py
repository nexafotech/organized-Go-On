import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.avatars import AVATAR_CATALOG, resolve_avatar, is_valid_avatar, VALID_AVATAR_IDS
from app.core.database import SessionLocal
from app.models.student import Student
from app.core.security import create_access_token

client = TestClient(app)

def test_avatar_catalog_integrity():
    assert len(AVATAR_CATALOG) == 16
    masculine = [a for a in AVATAR_CATALOG if a["category"] == "masculine"]
    feminine = [a for a in AVATAR_CATALOG if a["category"] == "feminine"]
    neutral = [a for a in AVATAR_CATALOG if a.get("is_neutral", False)]

    assert len(masculine) == 8
    assert len(feminine) == 8
    assert len(neutral) == 6

    for a in AVATAR_CATALOG:
        assert a["id"] in VALID_AVATAR_IDS
        assert a["asset"].endswith(".png")
        assert a["url"].startswith("/static/avatars/")
        assert len(a["tags"]) >= 2

def test_deterministic_avatar_assignment():
    # Same identifier always resolves to the exact same avatar
    av1 = resolve_avatar(None, "721025149001")
    av2 = resolve_avatar(None, "721025149001")
    assert av1 == av2

    # Different identifiers resolve to distinct avatars
    av_a = resolve_avatar(None, "721025149001")
    av_b = resolve_avatar(None, "721025149002")
    assert av_a != av_b

    # Explicit avatar overrides deterministic calculation
    assert resolve_avatar("avatar_f4", "721025149001") == "avatar_f4"

    # Invalid avatar falls back deterministically
    assert resolve_avatar("fake_avatar_id", "721025149001") == av_a

def test_student_avatar_api_endpoints():
    db = SessionLocal()
    try:
        student = db.query(Student).filter(Student.roll_number == "721025149001").first()
        if not student:
            pytest.skip("Student 721025149001 not found in test db")

        token = create_access_token(subject=student.user_id, role="student")
        headers = {"Authorization": f"Bearer {token}"}

        # 1. Fetch avatar catalog
        res = client.get("/api/v1/student/avatars", headers=headers)
        assert res.status_code == 200
        avatars = res.json()
        assert len(avatars) == 16

        # 2. Filter by category
        res_m = client.get("/api/v1/student/avatars?category=masculine", headers=headers)
        assert res_m.status_code == 200
        assert len(res_m.json()) == 8

        res_f = client.get("/api/v1/student/avatars?category=feminine", headers=headers)
        assert res_f.status_code == 200
        assert len(res_f.json()) == 8

        res_n = client.get("/api/v1/student/avatars?category=neutral", headers=headers)
        assert res_n.status_code == 200
        assert len(res_n.json()) == 6

        # 3. Check /student/me returns resolved avatar
        res_me = client.get("/api/v1/student/me", headers=headers)
        assert res_me.status_code == 200
        assert "avatar_id" in res_me.json()
        assert res_me.json()["avatar_id"] is not None

        # 4. Reject invalid avatar update
        res_bad = client.put("/api/v1/student/avatar", json={"avatar_id": "invalid_avatar_xyz"}, headers=headers)
        assert res_bad.status_code == 400

        # 5. Successfully update avatar
        res_update = client.put("/api/v1/student/avatar", json={"avatar_id": "avatar_f3"}, headers=headers)
        assert res_update.status_code == 200
        assert res_update.json()["success"] is True
        assert res_update.json()["avatar_id"] == "avatar_f3"

        # 6. Verify persistence in /student/me and /student/profile
        res_me2 = client.get("/api/v1/student/me", headers=headers)
        assert res_me2.json()["avatar_id"] == "avatar_f3"

        res_prof = client.get("/api/v1/student/profile", headers=headers)
        assert res_prof.json()["avatar_id"] == "avatar_f3"

        # 7. Update via /student/profile
        res_patch = client.patch("/api/v1/student/profile", json={"avatar_id": "avatar_m1"}, headers=headers)
        assert res_patch.status_code == 200
        assert res_patch.json()["avatar_id"] == "avatar_m1"

        # 8. Unchanged avatar fast-path test
        res_unchanged = client.put("/api/v1/student/avatar", json={"avatar_id": "avatar_m1"}, headers=headers)
        assert res_unchanged.status_code == 200
        assert res_unchanged.json()["success"] is True
        assert res_unchanged.json()["message"] == "Avatar unchanged"

        # Restore original or deterministic state
        client.put("/api/v1/student/avatar", json={"avatar_id": "avatar_m1"}, headers=headers)

    finally:
        db.close()
