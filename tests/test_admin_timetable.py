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
from app.models.student import Student
from app.models.audit import AuditLog
from app.services.college_importer import seed_temporary_dev_timetable

# In-memory SQLite for testing
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
def auth_headers(db_session):
    # Admin User
    admin = User(
        username="admin",
        email="admin@college.edu",
        hashed_password=get_password_hash("admin123"),
        role=UserRole.ADMIN,
        is_active=True
    )
    db_session.add(admin)

    # Faculty User
    fac_user = User(
        username="faculty",
        email="faculty@college.edu",
        hashed_password=get_password_hash("faculty123"),
        role=UserRole.FACULTY,
        is_active=True
    )
    db_session.add(fac_user)
    db_session.flush()

    faculty_profile = Faculty(
        user_id=fac_user.id,
        employee_id="FAC-001",
        full_name="Prof. Turing",
        department="CSE Cyber Security"
    )
    db_session.add(faculty_profile)

    # Student User
    cs = ClassSection(name="II Year CSE Cyber Security - Class 1", grade_level="II Year", academic_year="2026-2027")
    db_session.add(cs)
    db_session.flush()

    student_user = User(
        username="stu001",
        email="stu001@college.edu",
        hashed_password=get_password_hash("student123"),
        role=UserRole.STUDENT,
        is_active=True
    )
    db_session.add(student_user)
    db_session.flush()

    student_profile = Student(
        user_id=student_user.id,
        roll_number="CS26001",
        full_name="Alice Smith",
        class_id=cs.id,
        semester="3",
        department="CSE Cyber Security"
    )
    db_session.add(student_profile)
    db_session.commit()

    admin_token = create_access_token(admin.id, role="admin")
    faculty_token = create_access_token(fac_user.id, role="faculty")
    student_token = create_access_token(student_user.id, role="student")

    return {
        "admin": {"Authorization": f"Bearer {admin_token}"},
        "faculty": {"Authorization": f"Bearer {faculty_token}"},
        "student": {"Authorization": f"Bearer {student_token}"},
        "class_id": cs.id,
        "faculty_id": faculty_profile.id,
        "student_id": student_profile.id,
    }


def test_seed_temporary_dev_timetable(db_session):
    """Ensure seed_temporary_dev_timetable populates 42 slots, temporary faculty, and unassigned FDS LAB."""
    res = seed_temporary_dev_timetable(db_session, force_reset=True)
    assert res["status"] == "success"
    assert res["created_slots"] == 42
    assert res["total_slots"] == 42

    # Check 7 periods exist
    periods = db_session.query(Period).all()
    assert len(periods) == 7

    # Check temporary faculty FAC01-FAC05 exist
    fac_emps = [f.employee_id for f in db_session.query(Faculty).all()]
    for expected in ["FAC01", "FAC02", "FAC03", "FAC04", "FAC05"]:
        assert expected in fac_emps

    # Check FDS LAB has null faculty_id (pending assignment)
    fds_lab_sub = db_session.query(Subject).filter(Subject.code == "FDS LAB").first()
    assert fds_lab_sub is not None
    fa = db_session.query(FacultyAssignment).filter(FacultyAssignment.subject_id == fds_lab_sub.id).first()
    assert fa is not None
    assert fa.faculty_id is None

    # Check 42 entries
    entries = db_session.query(TimetableEntry).all()
    assert len(entries) == 42


def test_admin_timetable_crud_workflow(client, auth_headers, db_session):
    """Test full create, read, update, delete workflow with audit logging and collision validation."""
    seed_temporary_dev_timetable(db_session, force_reset=True)

    # 1. Read Timetable
    res = client.get("/api/v1/admin/timetable", headers=auth_headers["admin"])
    assert res.status_code == 200
    entries = res.json()
    assert len(entries) == 42

    # Check that unassigned slot has faculty_name="Faculty assignment pending"
    fds_lab_entries = [e for e in entries if e["subject_code"] == "FDS LAB"]
    assert len(fds_lab_entries) >= 2
    for e in fds_lab_entries:
        assert e["faculty_name"] == "Faculty assignment pending"

    # 2. Collision Validation on Create
    first_entry = entries[0]
    dup_payload = {
        "class_id": first_entry["class_id"],
        "day_of_week": first_entry["day_of_week"],
        "period_id": first_entry["period_id"],
        "subject_id": first_entry["subject_id"]
    }
    col_res = client.post("/api/v1/admin/timetable", json=dup_payload, headers=auth_headers["admin"])
    assert col_res.status_code == 400
    assert "already occupied" in col_res.json()["detail"].lower()

    # 3. Update Timetable Entry
    entry_id = first_entry["id"]
    update_payload = {
        "room": "Lab 4",
        "day_of_week": first_entry["day_of_week"],
        "period_id": first_entry["period_id"],
        "subject_id": first_entry["subject_id"]
    }
    up_res = client.put(f"/api/v1/admin/timetable/{entry_id}", json=update_payload, headers=auth_headers["admin"])
    assert up_res.status_code == 200
    assert up_res.json()["room"] == "Lab 4"

    # Check Audit Log for Update
    audit = db_session.query(AuditLog).filter(AuditLog.action == "UPDATE_TIMETABLE_ENTRY").first()
    assert audit is not None
    assert f"#{entry_id}" in audit.details

    # 4. Delete Entry
    del_res = client.delete(f"/api/v1/admin/timetable/{entry_id}", headers=auth_headers["admin"])
    assert del_res.status_code == 200

    # Verify count is 41
    res_after_del = client.get("/api/v1/admin/timetable", headers=auth_headers["admin"])
    assert len(res_after_del.json()) == 41

    # Check Audit Log for Delete
    audit_del = db_session.query(AuditLog).filter(AuditLog.action == "DELETE_TIMETABLE_ENTRY").first()
    assert audit_del is not None


def test_admin_move_and_duplicate_slot(client, auth_headers, db_session):
    """Test Move and Duplicate slot endpoints with collision checks."""
    seed_temporary_dev_timetable(db_session, force_reset=True)

    # 1. Delete Monday Period 1 so it becomes empty
    mon_p1 = (
        db_session.query(TimetableEntry)
        .join(Period, TimetableEntry.period_id == Period.id)
        .filter(TimetableEntry.day_of_week == "Monday", Period.period_number == 1)
        .first()
    )
    p1_id = mon_p1.period_id
    db_session.delete(mon_p1)
    db_session.commit()

    # 2. Pick Monday Period 2 and move it to Monday Period 1
    mon_p2 = (
        db_session.query(TimetableEntry)
        .join(Period, TimetableEntry.period_id == Period.id)
        .filter(TimetableEntry.day_of_week == "Monday", Period.period_number == 2)
        .first()
    )
    p2_entry_id = mon_p2.id
    p2_period_id = mon_p2.period_id

    move_payload = {
        "target_day_of_week": "Monday",
        "target_period_id": p1_id
    }
    move_res = client.post(f"/api/v1/admin/timetable/{p2_entry_id}/move", json=move_payload, headers=auth_headers["admin"])
    assert move_res.status_code == 200
    assert move_res.json()["period_id"] == p1_id
    assert move_res.json()["day_of_week"] == "Monday"

    # Now Monday Period 2 is empty. Duplicate the slot back to Monday Period 2!
    dup_payload = {
        "target_day_of_week": "Monday",
        "target_period_id": p2_period_id
    }
    dup_res = client.post(f"/api/v1/admin/timetable/{p2_entry_id}/duplicate", json=dup_payload, headers=auth_headers["admin"])
    assert dup_res.status_code == 201
    assert dup_res.json()["day_of_week"] == "Monday"

    # Attempting to duplicate again to occupied slot should return 400
    col_dup = client.post(f"/api/v1/admin/timetable/{p2_entry_id}/duplicate", json=dup_payload, headers=auth_headers["admin"])
    assert col_dup.status_code == 400


def test_admin_reset_dev_timetable_endpoint(client, auth_headers, db_session):
    """Test POST /api/v1/admin/timetable/reset-dev endpoint."""
    res = client.post("/api/v1/admin/timetable/reset-dev", headers=auth_headers["admin"])
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "success"
    assert data["created_slots"] == 42

    # Verify Audit Log
    audit = db_session.query(AuditLog).filter(AuditLog.action == "RESET_DEV_TIMETABLE").first()
    assert audit is not None


def test_rbac_restrictions_on_timetable(client, auth_headers, db_session):
    """Ensure Student and Faculty cannot modify timetable, but can view their timetable."""
    seed_temporary_dev_timetable(db_session, force_reset=True)

    # 1. Faculty attempt to create slot -> 403 Forbidden
    payload = {"class_id": 1, "day_of_week": "Monday", "period_id": 1, "subject_id": 1}
    fac_res = client.post("/api/v1/admin/timetable", json=payload, headers=auth_headers["faculty"])
    assert fac_res.status_code == 403

    # 2. Student attempt to delete slot -> 403 Forbidden
    stu_res = client.delete("/api/v1/admin/timetable/1", headers=auth_headers["student"])
    assert stu_res.status_code == 403

    # 3. Student reading /api/v1/student/timetable -> 200 OK
    stu_tt = client.get("/api/v1/student/timetable", headers=auth_headers["student"])
    assert stu_tt.status_code == 200
    tt_items = stu_tt.json()["timetable"]
    assert len(tt_items) == 42
    # Ensure unassigned displays "Faculty assignment pending"
    fds_lab_item = next(item for item in tt_items if item["subject_code"] == "FDS LAB")
    assert fds_lab_item["faculty_name"] == "Faculty assignment pending"
