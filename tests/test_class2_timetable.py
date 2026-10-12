import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token
from app.models.user import User, Faculty, UserRole
from app.models.student import Student
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
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
        is_active=True,
        login_identifier="admin"
    )
    db_session.add(admin)

    # Faculty User (FAC04 - Shankar)
    fac_user = User(
        username="fac04",
        email="fac04@college.edu",
        hashed_password=get_password_hash("faculty123"),
        role=UserRole.FACULTY,
        is_active=True,
        login_identifier="FAC04"
    )
    db_session.add(fac_user)
    db_session.flush()

    fac_profile = Faculty(
        user_id=fac_user.id,
        employee_id="FAC04",
        full_name="Shankar",
        department="CSE Cyber Security"
    )
    db_session.add(fac_profile)

    # Seed both dev timetables
    seed_temporary_dev_timetable(db_session, class_name="all", force_reset=True)


    cs1 = db_session.query(ClassSection).filter(ClassSection.name == "II Year CSE Cyber Security - Class 1").first()
    cs2 = db_session.query(ClassSection).filter(ClassSection.name == "III Year CSE Cyber Security - Class 2").first()

    # Create Student in Class 2
    student_user = User(
        username="23CY201",
        email="student201@college.edu",
        hashed_password=get_password_hash("student123"),
        role=UserRole.STUDENT,
        is_active=True,
        login_identifier="23CY201"
    )
    db_session.add(student_user)
    db_session.flush()

    student_profile = Student(
        user_id=student_user.id,
        roll_number="23CY201",
        full_name="Bob Cyber",
        class_id=cs2.id,
        semester="3",
        department="CSE Cyber Security",
        is_active=True
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
        "admin_user": admin,
        "fac_user": fac_user,
        "fac_profile": fac_profile,
        "cs1": cs1,
        "cs2": cs2,
        "student": student_profile
    }


# ----------------------------------------------------
# 1. 42 Slots for Class 2 & No Duplicates
# ----------------------------------------------------
def test_class2_has_42_slots_and_no_duplicates(db_session, auth_headers):
    cs2 = auth_headers["cs2"]
    entries = (
        db_session.query(TimetableEntry)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .filter(FacultyAssignment.class_id == cs2.id)
        .all()
    )
    assert len(entries) == 42

    # Verify no duplicate (day_of_week, period_id)
    seen_slots = set()
    for e in entries:
        slot = (e.day_of_week, e.period_id)
        assert slot not in seen_slots
        seen_slots.add(slot)
    assert len(seen_slots) == 42


# ----------------------------------------------------
# 2. Subject Codes & Period Distribution for Class 2
# ----------------------------------------------------
def test_class2_subject_codes_and_distribution(client, auth_headers):
    cs2 = auth_headers["cs2"]
    res = client.get(f"/api/v1/admin/timetable?class_id={cs2.id}", headers=auth_headers["admin"])
    assert res.status_code == 200
    timetable = res.json()
    assert len(timetable) == 42

    # Verify Monday slots: AIML, LP, SDBMS, LP, ESSS, SDBMS LAB, SDBMS LAB
    mon_slots = [s for s in timetable if s["day_of_week"] == "Monday"]
    mon_slots.sort(key=lambda s: s["period_number"])
    assert len(mon_slots) == 7
    expected_mon_codes = ["AIML", "LP", "SDBMS", "LP", "ESSS", "SDBMS LAB", "SDBMS LAB"]
    actual_mon_codes = [s["subject_code"] for s in mon_slots]
    assert actual_mon_codes == expected_mon_codes

    # Verify Saturday slots: CF, AIML, CF LAB, CF LAB, CF, CF, CF
    sat_slots = [s for s in timetable if s["day_of_week"] == "Saturday"]
    sat_slots.sort(key=lambda s: s["period_number"])
    assert len(sat_slots) == 7
    expected_sat_codes = ["CF", "AIML", "CF LAB", "CF LAB", "CF", "CF", "CF"]
    actual_sat_codes = [s["subject_code"] for s in sat_slots]
    assert actual_sat_codes == expected_sat_codes


# ----------------------------------------------------
# 3. Unresolved Labs Handled as "Faculty assignment pending"
# ----------------------------------------------------
def test_unresolved_labs_render_pending_faculty(client, auth_headers):
    cs2 = auth_headers["cs2"]
    res = client.get(f"/api/v1/admin/timetable?class_id={cs2.id}", headers=auth_headers["admin"])
    assert res.status_code == 200
    timetable = res.json()

    # Find LINUX LAB, CF LAB, ESSS LAB slots
    pending_slots = [s for s in timetable if s["subject_code"] in ("LINUX LAB", "CF LAB", "ESSS LAB")]
    assert len(pending_slots) == 6  # 2 periods each

    for s in pending_slots:
        assert s["faculty_id"] is None
        assert s["faculty_name"] == "Faculty assignment pending"


# ----------------------------------------------------
# 4. Admin CRUD on Class 2: Create, Edit, Move, Duplicate, Delete
# ----------------------------------------------------
def test_admin_crud_workflow_on_class2(client, auth_headers, db_session):
    cs2 = auth_headers["cs2"]
    admin_h = auth_headers["admin"]

    # 1. Delete a slot (e.g. Monday P1)
    mon_slots = client.get(f"/api/v1/admin/timetable?class_id={cs2.id}&day_of_week=Monday", headers=admin_h).json()
    mon_p1 = next(s for s in mon_slots if s["period_number"] == 1)
    del_res = client.delete(f"/api/v1/admin/timetable/{mon_p1['id']}", headers=admin_h)
    assert del_res.status_code == 200

    # Verify count is now 41
    tt_after_del = client.get(f"/api/v1/admin/timetable?class_id={cs2.id}", headers=admin_h).json()
    assert len(tt_after_del) == 41

    # 2. Re-create the slot via POST /timetable
    sub_aiml = db_session.query(Subject).filter(Subject.code == "AIML").first()
    p1 = db_session.query(Period).filter(Period.period_number == 1).first()
    fac04 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC04").first()

    create_payload = {
        "class_id": cs2.id,
        "subject_id": sub_aiml.id,
        "faculty_id": fac04.id,
        "day_of_week": "Monday",
        "period_id": p1.id,
        "room": "Room 202"
    }
    create_res = client.post("/api/v1/admin/timetable", json=create_payload, headers=admin_h)
    assert create_res.status_code == 201, create_res.json()
    new_slot = create_res.json()
    assert new_slot["room"] == "Room 202"
    assert new_slot["subject_code"] == "AIML"
    new_slot_id = new_slot["id"]

    # 3. Edit the slot (update room)
    edit_payload = {
        "room": "Cyber Lab 1"
    }
    edit_res = client.put(f"/api/v1/admin/timetable/{new_slot_id}", json=edit_payload, headers=admin_h)
    assert edit_res.status_code == 200
    assert edit_res.json()["room"] == "Cyber Lab 1"

    # 4. Duplicate prevention test: attempting to add duplicate slot on Monday P1
    dup_attempt = client.post("/api/v1/admin/timetable", json=create_payload, headers=admin_h)
    assert dup_attempt.status_code == 400
    assert "already occupied" in dup_attempt.json()["detail"].lower()


# ----------------------------------------------------
# 5. Non-Admin Forbidden (RBAC)
# ----------------------------------------------------
def test_non_admin_cannot_modify_class2_timetable(client, auth_headers):
    cs2 = auth_headers["cs2"]
    fac_h = auth_headers["faculty"]

    # Faculty attempt to create slot
    p = client.post("/api/v1/admin/timetable", json={
        "class_id": cs2.id,
        "subject_id": 1,
        "day_of_week": "Monday",
        "period_id": 1
    }, headers=fac_h)
    assert p.status_code == 403

    # Faculty attempt to reset dev timetable
    r = client.post(f"/api/v1/admin/timetable/reset-dev?class_id={cs2.id}", headers=fac_h)
    assert r.status_code == 403


# ----------------------------------------------------
# 6. Class 1 Isolation (Class 1 remains completely intact)
# ----------------------------------------------------
def test_class1_remains_intact_and_isolated(client, auth_headers, db_session):
    cs1 = auth_headers["cs1"]
    cs2 = auth_headers["cs2"]
    admin_h = auth_headers["admin"]

    # Verify Class 1 has 42 slots
    c1_res = client.get(f"/api/v1/admin/timetable?class_id={cs1.id}", headers=admin_h)
    assert c1_res.status_code == 200
    c1_slots = c1_res.json()
    assert len(c1_slots) == 42

    # Verify Class 1 Monday P1 is FDS (Class 1 subject, not Class 2 AIML)
    c1_mon_p1 = next(s for s in c1_slots if s["day_of_week"] == "Monday" and s["period_number"] == 1)
    assert c1_mon_p1["subject_code"] == "FDS"

    # Reset only Class 2
    res = client.post(f"/api/v1/admin/timetable/reset-dev?class_id={cs2.id}", headers=admin_h)
    assert res.status_code == 200

    # Verify Class 1 is still exactly 42 slots
    c1_check = client.get(f"/api/v1/admin/timetable?class_id={cs1.id}", headers=admin_h).json()
    assert len(c1_check) == 42


# ----------------------------------------------------
# 7. Student Timetable API Returns Class 2 Schedule
# ----------------------------------------------------
def test_student_timetable_api_returns_class2(client, auth_headers):
    # Logged in as Class 2 Student (23CY201)
    st_token = create_access_token(auth_headers["student"].user_id, role="student")
    st_h = {"Authorization": f"Bearer {st_token}"}

    res = client.get("/api/v1/student/timetable", headers=st_h)
    assert res.status_code == 200
    data = res.json()
    assert data["class_name"] == "III Year CSE Cyber Security - Class 2"
    assert len(data["timetable"]) == 42

    # Monday P1 should be AIML
    mon_p1 = next(s for s in data["timetable"] if s["day_of_week"] == "Monday" and s["period_number"] == 1)
    assert mon_p1["subject_code"] == "AIML"


# ----------------------------------------------------
# 8. Faculty Timetable API Returns Assigned Class 2 Entries
# ----------------------------------------------------
def test_faculty_timetable_api_returns_class2_slots(client, auth_headers):
    # Logged in as Faculty FAC04 (Shankar)
    fac_token = create_access_token(auth_headers["fac_user"].id, role="faculty")
    fac_h = {"Authorization": f"Bearer {fac_token}"}

    res = client.get("/api/v1/faculty/timetable", headers=fac_h)
    assert res.status_code == 200
    data = res.json()
    tt = data["timetable"]

    # FAC04 is assigned to Class 2 AIML, SDBMS, SDBMS LAB
    c2_slots = [s for s in tt if s["class_name"] == "III Year CSE Cyber Security - Class 2"]
    assert len(c2_slots) > 0
    assigned_codes = set(s["subject_code"] for s in c2_slots)
    assert "AIML" in assigned_codes
    assert "SDBMS" in assigned_codes


# ----------------------------------------------------
# 9. Audit Logging on Class 2 Operations
# ----------------------------------------------------
def test_audit_logging_on_class2_operations(client, auth_headers, db_session):
    cs2 = auth_headers["cs2"]
    admin_h = auth_headers["admin"]

    # Trigger a reset dev timetable for Class 2
    client.post(f"/api/v1/admin/timetable/reset-dev?class_id={cs2.id}", headers=admin_h)

    # Check audit log in database
    logs = db_session.query(AuditLog).filter(AuditLog.action == "RESET_DEV_TIMETABLE").all()
    assert len(logs) > 0
    assert "Class 2" in logs[-1].details
