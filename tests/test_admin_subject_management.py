import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token
from app.models.user import User, Faculty, UserRole
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.services.college_importer import seed_temporary_dev_timetable

SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture(scope="function")
def test_setup(db_session):
    # Seed dev timetable (includes UHV, 42 Class 1 slots, 42 Class 2 slots)
    seed_temporary_dev_timetable(db_session, class_name="all", force_reset=True)

    # 1. Admin user
    admin = User(
        username="admin_user",
        email="admin@college.edu",
        hashed_password=get_password_hash("AdminPass123!"),
        role=UserRole.ADMIN,
        is_active=True,
    )
    db_session.add(admin)

    # 2. Faculty user
    fac_user = User(
        username="fac_user",
        email="fac@college.edu",
        hashed_password=get_password_hash("FacultyPass123!"),
        role=UserRole.FACULTY,
        is_active=True,
    )
    db_session.add(fac_user)

    # 3. Student user
    stu_user = User(
        username="stu_user",
        email="stu@college.edu",
        hashed_password=get_password_hash("StudentPass123!"),
        role=UserRole.STUDENT,
        is_active=True,
    )
    db_session.add(stu_user)
    db_session.commit()

    admin_token = create_access_token(admin.id, role=UserRole.ADMIN.value)
    fac_token = create_access_token(fac_user.id, role=UserRole.FACULTY.value)
    stu_token = create_access_token(stu_user.id, role=UserRole.STUDENT.value)

    return {
        "admin_headers": {"Authorization": f"Bearer {admin_token}"},
        "fac_headers": {"Authorization": f"Bearer {fac_token}"},
        "stu_headers": {"Authorization": f"Bearer {stu_token}"},
    }


def test_1_admin_can_create_subject(client, test_setup, db_session):
    """1. ADMIN can create subject (uses TSUB-NEW — IKS is now part of the seed data)."""
    payload = {
        "code": "TSUB-NEW",
        "name": "Test New Subject",
        "description": "A test subject not present in the seed data",
    }
    res = client.post("/api/v1/admin/subjects", json=payload, headers=test_setup["admin_headers"])
    assert res.status_code == 201
    data = res.json()
    assert data["code"] == "TSUB-NEW"
    assert data["name"] == "Test New Subject"
    assert data["description"] == payload["description"]
    assert "id" in data

    # Verify persisted in database
    sub = db_session.query(Subject).filter(Subject.code == "TSUB-NEW").first()
    assert sub is not None
    assert sub.name == "Test New Subject"


def test_2_duplicate_code_rejected(client, test_setup, db_session):
    """2. Duplicate code rejected."""
    # First create IKS
    client.post(
        "/api/v1/admin/subjects",
        json={"code": "IKS", "name": "Indian Knowledge System"},
        headers=test_setup["admin_headers"],
    )

    # Attempt to create duplicate IKS (exact and case-insensitive)
    res_exact = client.post(
        "/api/v1/admin/subjects",
        json={"code": "IKS", "name": "Different Name"},
        headers=test_setup["admin_headers"],
    )
    assert res_exact.status_code == 400
    assert "already exists" in res_exact.json()["detail"].lower()

    res_case = client.post(
        "/api/v1/admin/subjects",
        json={"code": "iks", "name": "Different Name 2"},
        headers=test_setup["admin_headers"],
    )
    assert res_case.status_code == 400
    assert "already exists" in res_case.json()["detail"].lower()


def test_3_duplicate_name_rejected(client, test_setup, db_session):
    """3. Duplicate name rejected."""
    # Create IKS
    client.post(
        "/api/v1/admin/subjects",
        json={"code": "IKS", "name": "Indian Knowledge System"},
        headers=test_setup["admin_headers"],
    )

    # Attempt to create subject with different code but same name
    res = client.post(
        "/api/v1/admin/subjects",
        json={"code": "IKS2", "name": "Indian Knowledge System"},
        headers=test_setup["admin_headers"],
    )
    assert res.status_code == 400
    assert "already exists" in res.json()["detail"].lower()


def test_4_empty_code_rejected(client, test_setup):
    """4. Empty code rejected."""
    res_empty = client.post(
        "/api/v1/admin/subjects",
        json={"code": "", "name": "Some Subject"},
        headers=test_setup["admin_headers"],
    )
    assert res_empty.status_code == 400
    assert "code cannot be empty" in res_empty.json()["detail"].lower()

    res_whitespace = client.post(
        "/api/v1/admin/subjects",
        json={"code": "   ", "name": "Some Subject"},
        headers=test_setup["admin_headers"],
    )
    assert res_whitespace.status_code == 400
    assert "code cannot be empty" in res_whitespace.json()["detail"].lower()


def test_5_empty_name_rejected(client, test_setup):
    """5. Empty name rejected."""
    res_empty = client.post(
        "/api/v1/admin/subjects",
        json={"code": "NEWCODE", "name": ""},
        headers=test_setup["admin_headers"],
    )
    assert res_empty.status_code == 400
    assert "name cannot be empty" in res_empty.json()["detail"].lower()

    res_whitespace = client.post(
        "/api/v1/admin/subjects",
        json={"code": "NEWCODE", "name": "   "},
        headers=test_setup["admin_headers"],
    )
    assert res_whitespace.status_code == 400
    assert "name cannot be empty" in res_whitespace.json()["detail"].lower()


def test_6_faculty_cannot_create_subject(client, test_setup):
    """6. FACULTY cannot create subject."""
    res = client.post(
        "/api/v1/admin/subjects",
        json={"code": "IKS", "name": "Indian Knowledge System"},
        headers=test_setup["fac_headers"],
    )
    assert res.status_code == 403
    assert "admin privilege required" in res.json()["detail"].lower()


def test_7_student_cannot_create_subject(client, test_setup):
    """7. STUDENT cannot create subject."""
    res = client.post(
        "/api/v1/admin/subjects",
        json={"code": "IKS", "name": "Indian Knowledge System"},
        headers=test_setup["stu_headers"],
    )
    assert res.status_code == 403
    assert "admin privilege required" in res.json()["detail"].lower()


def test_8_newly_created_iks_appears_in_subject_list(client, test_setup):
    """8. Newly created subject (TSUB-NEW) appears in subject list (IKS is now seeded, so we use TSUB-NEW)."""
    # List subjects before creation
    res_before = client.get("/api/v1/admin/subjects", headers=test_setup["admin_headers"])
    assert res_before.status_code == 200
    codes_before = [s["code"] for s in res_before.json()]
    assert "TSUB-NEW" not in codes_before

    # Create TSUB-NEW
    create_res = client.post(
        "/api/v1/admin/subjects",
        json={"code": "TSUB-NEW", "name": "Test New Subject"},
        headers=test_setup["admin_headers"],
    )
    assert create_res.status_code == 201

    # List subjects after creation
    res_after = client.get("/api/v1/admin/subjects", headers=test_setup["admin_headers"])
    assert res_after.status_code == 200
    subjects_after = res_after.json()
    new_entry = next((s for s in subjects_after if s["code"] == "TSUB-NEW"), None)
    assert new_entry is not None
    assert new_entry["name"] == "Test New Subject"


def test_9_existing_uhv_record_remains_unchanged(client, test_setup, db_session):
    """9. Existing UHV record remains unchanged."""
    uhv_before = db_session.query(Subject).filter(Subject.code == "UHV").first()
    assert uhv_before is not None
    uhv_id = uhv_before.id
    uhv_name = uhv_before.name

    # Create IKS
    client.post(
        "/api/v1/admin/subjects",
        json={"code": "IKS", "name": "Indian Knowledge System"},
        headers=test_setup["admin_headers"],
    )

    # Re-query UHV
    uhv_after = db_session.query(Subject).filter(Subject.code == "UHV").first()
    assert uhv_after is not None
    assert uhv_after.id == uhv_id
    assert uhv_after.name == uhv_name
    assert uhv_after.code == "UHV"

    # Both UHV and IKS exist independently
    iks = db_session.query(Subject).filter(Subject.code == "IKS").first()
    assert iks is not None
    assert iks.id != uhv_id


def test_10_existing_timetable_entries_remain_unchanged(client, test_setup, db_session):
    """10. Existing timetable entries remain unchanged when a new subject (TSUB-NEW) is created."""
    # Count timetable entries before
    tt_count_before = db_session.query(TimetableEntry).count()
    fa_count_before = db_session.query(FacultyAssignment).count()
    assert tt_count_before == 84  # 42 for Class 1 + 42 for Class 2

    # Create TSUB-NEW (IKS is already seeded, so we use TSUB-NEW)
    client.post(
        "/api/v1/admin/subjects",
        json={"code": "TSUB-NEW", "name": "Test New Subject"},
        headers=test_setup["admin_headers"],
    )

    # Count timetable entries and assignments after
    tt_count_after = db_session.query(TimetableEntry).count()
    fa_count_after = db_session.query(FacultyAssignment).count()
    assert tt_count_after == tt_count_before
    assert fa_count_after == fa_count_before

    # Verify no timetable entry is assigned to TSUB-NEW
    new_sub = db_session.query(Subject).filter(Subject.code == "TSUB-NEW").first()
    assert new_sub is not None
    new_assignments = db_session.query(FacultyAssignment).filter(FacultyAssignment.subject_id == new_sub.id).count()
    assert new_assignments == 0
