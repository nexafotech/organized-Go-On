"""
tests/test_faculty_assignments.py
Comprehensive test suite for Milestone 10C.13.1 — Faculty + Subject Assignment Finalization:
- Validation of temporary development faculty assignments (FAC01-FAC05) for Class 1 and Class 2
- Duplicate assignment rejection
- Inactive faculty rejection
- Non-existent faculty/class/subject rejection
- Unresolved assignment pending state ("Faculty assignment pending")
- Admin-only assignment modification and RBAC enforcement (Student & Faculty rejected with 403)
- Audit log recording for all assignment lifecycle events
- Dynamic API reflection in Admin, Student, and Faculty timetable endpoints
"""

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
def test_data(db_session):
    # Seed both Class 1 and Class 2 temporary dev timetable
    seed_result = seed_temporary_dev_timetable(db_session, class_name="all", force_reset=True)

    # 1. Admin User
    admin = User(
        username="admin_test",
        email="admin_test@college.edu",
        hashed_password=get_password_hash("AdminPass123!"),
        role=UserRole.ADMIN,
        is_active=True
    )
    db_session.add(admin)

    # 2. Get Class Sections
    cs1 = db_session.query(ClassSection).filter(ClassSection.name == "II Year CSE Cyber Security - Class 1").first()
    cs2 = db_session.query(ClassSection).filter(ClassSection.name == "III Year CSE Cyber Security - Class 2").first()

    # 3. Student User in Class 1
    student_user = User(
        username="stu_class1_001",
        email="stu1@college.edu",
        hashed_password=get_password_hash("StudentPass123!"),
        role=UserRole.STUDENT,
        is_active=True
    )
    db_session.add(student_user)
    db_session.flush()

    student_profile = Student(
        user_id=student_user.id,
        roll_number="721025149001",
        full_name="Abishek Student",
        class_id=cs1.id,
        semester="3",
        department="CSE Cyber Security"
    )
    db_session.add(student_profile)

    # 4. Existing Dev Faculty (e.g. FAC01)
    fac01 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC01").first()
    fac02 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC02").first()
    fac03 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC03").first()
    fac04 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC04").first()
    fac05 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC05").first()

    db_session.commit()

    admin_token = create_access_token(admin.id, role="admin")
    student_token = create_access_token(student_user.id, role="student")
    fac01_token = create_access_token(fac01.user_id, role="faculty")

    return {
        "admin_headers": {"Authorization": f"Bearer {admin_token}"},
        "student_headers": {"Authorization": f"Bearer {student_token}"},
        "faculty_headers": {"Authorization": f"Bearer {fac01_token}"},
        "cs1_id": cs1.id,
        "cs2_id": cs2.id,
        "fac01": fac01,
        "fac02": fac02,
        "fac03": fac03,
        "fac04": fac04,
        "fac05": fac05,
    }


def test_class1_and_class2_development_assignments_conformance(db_session, test_data):
    """Verify that all Class 1 and Class 2 subject-to-faculty assignments strictly match the confirmed specs."""
    cs1_id = test_data["cs1_id"]
    cs2_id = test_data["cs2_id"]

    # Expected Class 1 Mappings
    expected_c1 = {
        "DMC": "FAC07",
        "DS": "FAC02",
        "OOPS": "FAC03",
        "DPCO": "FAC06",
        "FDS": "FAC05",
        "DS LAB": "FAC02",
        "JAVA LAB": "FAC03",
        "ACE-I": "FAC08",
        "UHV": "FAC05",
        "LIB": "FAC05",
        "IIC": "FAC05",
        "TWM": "FAC01",
        "ASSOC": "FAC05",
        "FDS LAB": None,
        "IKS": "FAC05",
    }

    # Expected Class 2 Mappings
    expected_c2 = {
        "CF": "FAC05",
        "SDBMS": "FAC04",
        "CC": "FAC01",
        "LP": "FAC03",
        "AIML": "FAC04",
        "ESSS": "FAC02",
        "SDBMS LAB": "FAC04",
        "CC-I": "FAC03",
        "E&I": "FAC02",
        "LIB": "FAC02",
        "TWM": None,
        "IIC": "FAC02",
        "LINUX LAB": None,
        "CF LAB": None,
        "ESSS LAB": None,
    }

    # Verify Class 1
    c1_assignments = db_session.query(FacultyAssignment).filter(FacultyAssignment.class_id == cs1_id).all()
    assert len(c1_assignments) in [14, 15]
    for a in c1_assignments:
        expected_emp = expected_c1.get(a.subject.code)
        if expected_emp is None:
            assert a.faculty_id is None, f"Expected {a.subject.code} to be pending, got faculty {a.faculty_id}"
        else:
            assert a.faculty is not None, f"Expected {a.subject.code} to have faculty {expected_emp}"
            assert a.faculty.employee_id == expected_emp

    # Verify Class 2
    c2_assignments = db_session.query(FacultyAssignment).filter(FacultyAssignment.class_id == cs2_id).all()
    assert len(c2_assignments) == 15
    for a in c2_assignments:
        expected_emp = expected_c2.get(a.subject.code)
        if expected_emp is None:
            assert a.faculty_id is None, f"Expected {a.subject.code} to be pending, got faculty {a.faculty_id}"
        else:
            assert a.faculty is not None, f"Expected {a.subject.code} to have faculty {expected_emp}"
            assert a.faculty.employee_id == expected_emp


def test_duplicate_assignment_rejection(client, test_data, db_session):
    """Ensure that creating a duplicate assignment for the same (class, subject, faculty) is rejected with 400."""
    cs1_id = test_data["cs1_id"]
    fac07 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC07").first()
    dmc_sub = db_session.query(Subject).filter(Subject.code == "DMC").first()

    # DMC -> FAC07 already exists in Class 1
    payload = {
        "class_id": cs1_id,
        "subject_id": dmc_sub.id,
        "faculty_id": fac07.id
    }
    res = client.post("/api/v1/admin/assignments", json=payload, headers=test_data["admin_headers"])
    assert res.status_code == 400
    assert "already exists" in res.json()["detail"]


def test_inactive_faculty_rejection(client, test_data, db_session):
    """Ensure that assigning an inactive/disabled faculty member is rejected with 400."""
    cs1_id = test_data["cs1_id"]
    fac05 = test_data["fac05"]
    dmc_sub = db_session.query(Subject).filter(Subject.code == "DMC").first()

    # Disable FAC05
    fac05.user.is_active = False
    db_session.commit()

    # Attempt to assign disabled faculty via /admin/assignments
    payload = {
        "class_id": cs1_id,
        "subject_id": dmc_sub.id,
        "faculty_id": fac05.id
    }
    res = client.post("/api/v1/admin/assignments", json=payload, headers=test_data["admin_headers"])
    assert res.status_code == 400
    assert "Cannot assign inactive faculty member" in res.json()["detail"]

    # Re-enable FAC05 for cleanup
    fac05.user.is_active = True
    db_session.commit()


def test_nonexistent_faculty_rejection(client, test_data, db_session):
    """Ensure that assigning a non-existent faculty_id is rejected with 404."""
    cs1_id = test_data["cs1_id"]
    dmc_sub = db_session.query(Subject).filter(Subject.code == "DMC").first()

    payload = {
        "class_id": cs1_id,
        "subject_id": dmc_sub.id,
        "faculty_id": 999999
    }
    res = client.post("/api/v1/admin/assignments", json=payload, headers=test_data["admin_headers"])
    assert res.status_code == 404
    assert "Faculty ID 999999 not found" in res.json()["detail"]


def test_nonexistent_class_or_subject_rejection(client, test_data, db_session):
    """Ensure that specifying non-existent class or subject IDs returns 404."""
    fac01 = test_data["fac01"]
    dmc_sub = db_session.query(Subject).filter(Subject.code == "DMC").first()

    # Invalid class ID
    res = client.post("/api/v1/admin/assignments", json={
        "class_id": 999999,
        "subject_id": dmc_sub.id,
        "faculty_id": fac01.id
    }, headers=test_data["admin_headers"])
    assert res.status_code == 404
    assert "Class section ID 999999 not found" in res.json()["detail"]

    # Invalid subject ID
    res = client.post("/api/v1/admin/assignments", json={
        "class_id": test_data["cs1_id"],
        "subject_id": 999999,
        "faculty_id": fac01.id
    }, headers=test_data["admin_headers"])
    assert res.status_code == 404
    assert "Subject ID 999999 not found" in res.json()["detail"]


def test_unresolved_assignment_pending_state(client, test_data):
    """Verify that unassigned subjects/slots explicitly return 'Faculty assignment pending'."""
    # 1. Admin assignments API
    res = client.get("/api/v1/admin/assignments", headers=test_data["admin_headers"])
    assert res.status_code == 200
    assignments = res.json()

    pending_subs = ["FDS LAB", "LINUX LAB", "CF LAB", "ESSS LAB", "TWM", "ASSOC"]
    for a in assignments:
        if a["subject_code"] in pending_subs and a["faculty_id"] is None:
            assert a["faculty_name"] == "Faculty assignment pending"

    # 2. Timetable API
    res_tt = client.get(f"/api/v1/admin/timetable?class_id={test_data['cs1_id']}", headers=test_data["admin_headers"])
    assert res_tt.status_code == 200
    tt_slots = res_tt.json()
    fds_lab_slots = [s for s in tt_slots if s["subject_code"] == "FDS LAB"]
    assert len(fds_lab_slots) == 2
    for slot in fds_lab_slots:
        assert slot["faculty_name"] == "Faculty assignment pending"
        assert slot["faculty_id"] is None


def test_admin_only_assignment_modification(client, test_data, db_session):
    """Verify Admin can create, update, and delete faculty assignments."""
    cs1_id = test_data["cs1_id"]
    fac03 = test_data["fac03"]
    fac04 = test_data["fac04"]
    uhv_sub = db_session.query(Subject).filter(Subject.code == "UHV").first()

    # 1. Create a new custom assignment
    create_res = client.post("/api/v1/admin/assignments", json={
        "class_id": cs1_id,
        "subject_id": uhv_sub.id,
        "faculty_id": fac03.id
    }, headers=test_data["admin_headers"])
    assert create_res.status_code == 201
    assign_id = create_res.json()["id"]

    # 2. Update assignment to another faculty
    update_res = client.put(f"/api/v1/admin/assignments/{assign_id}", json={
        "class_id": cs1_id,
        "subject_id": uhv_sub.id,
        "faculty_id": fac04.id
    }, headers=test_data["admin_headers"])
    assert update_res.status_code == 200
    assert update_res.json()["faculty_id"] == fac04.id

    # 3. Delete assignment
    delete_res = client.delete(f"/api/v1/admin/assignments/{assign_id}", headers=test_data["admin_headers"])
    assert delete_res.status_code == 200
    assert delete_res.json()["message"] == "Assignment deleted successfully"


def test_rbac_student_and_faculty_cannot_modify_assignments(client, test_data):
    """Ensure non-admin users (Student and Faculty) cannot create, edit, or delete assignments (403)."""
    payload = {
        "class_id": test_data["cs1_id"],
        "subject_id": 1,
        "faculty_id": test_data["fac01"].id
    }

    # Student Attempts
    assert client.post("/api/v1/admin/assignments", json=payload, headers=test_data["student_headers"]).status_code == 403
    assert client.put("/api/v1/admin/assignments/1", json=payload, headers=test_data["student_headers"]).status_code == 403
    assert client.delete("/api/v1/admin/assignments/1", headers=test_data["student_headers"]).status_code == 403

    # Faculty Attempts
    assert client.post("/api/v1/admin/assignments", json=payload, headers=test_data["faculty_headers"]).status_code == 403
    assert client.put("/api/v1/admin/assignments/1", json=payload, headers=test_data["faculty_headers"]).status_code == 403
    assert client.delete("/api/v1/admin/assignments/1", headers=test_data["faculty_headers"]).status_code == 403


def test_audit_event_creation_for_assignments(client, test_data, db_session):
    """Verify that assignment lifecycle actions create corresponding AuditLog records."""
    cs1_id = test_data["cs1_id"]
    fac01 = test_data["fac01"]
    lib_sub = db_session.query(Subject).filter(Subject.code == "LIB").first()

    # Create assignment
    res_create = client.post("/api/v1/admin/assignments", json={
        "class_id": cs1_id,
        "subject_id": lib_sub.id,
        "faculty_id": fac01.id
    }, headers=test_data["admin_headers"])
    assert res_create.status_code == 201
    assign_id = res_create.json()["id"]

    audit_create = db_session.query(AuditLog).filter(
        AuditLog.action == "CREATE_FACULTY_ASSIGNMENT"
    ).order_by(AuditLog.id.desc()).first()
    assert audit_create is not None
    assert f"Assigned faculty {fac01.id}" in audit_create.details

    # Delete assignment
    client.delete(f"/api/v1/admin/assignments/{assign_id}", headers=test_data["admin_headers"])
    audit_delete = db_session.query(AuditLog).filter(
        AuditLog.action == "DELETE_FACULTY_ASSIGNMENT"
    ).order_by(AuditLog.id.desc()).first()
    assert audit_delete is not None
    assert f"Deleted assignment ID {assign_id}" in audit_delete.details


def test_student_and_faculty_timetable_apis(client, test_data):
    """Verify that student and faculty APIs return the correct personal schedule with proper faculty names."""
    # 1. Student Timetable API
    res_stu = client.get("/api/v1/student/timetable", headers=test_data["student_headers"])
    assert res_stu.status_code == 200
    stu_data = res_stu.json()
    assert stu_data["class_name"] == "II Year CSE Cyber Security - Class 1"
    assert len(stu_data["timetable"]) == 42

    # Check a known slot (e.g. DMC -> Princy)
    dmc_slots = [s for s in stu_data["timetable"] if s["subject_code"] == "DMC"]
    assert len(dmc_slots) == 6
    for s in dmc_slots:
        assert s["faculty_name"] == "Princy"

    # Check a pending slot (e.g. FDS LAB -> Faculty assignment pending)
    fds_lab_slots = [s for s in stu_data["timetable"] if s["subject_code"] == "FDS LAB"]
    assert len(fds_lab_slots) == 2
    for s in fds_lab_slots:
        assert s["faculty_name"] == "Faculty assignment pending"

    # 2. Faculty Timetable API
    res_fac = client.get("/api/v1/faculty/timetable", headers=test_data["faculty_headers"])
    assert res_fac.status_code == 200
    fac_data = res_fac.json()
    assert fac_data["faculty_name"] == "Mathu Metlda"
    # FAC01 teaches TWM (1 slot in Class 1) + CC (4 slots in Class 2) = 5 slots total
    assert len(fac_data["timetable"]) == 5
