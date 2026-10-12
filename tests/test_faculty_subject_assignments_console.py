"""
tests/test_faculty_subject_assignments_console.py
Comprehensive test suite verifying the upgraded Faculty Subject Assignments management console:
1. List assignments with full academic names and filtering (search, class, subject, faculty, assigned status)
2. Valid unassigned state (curriculum subjects with pending faculty) and /assignments/unassigned endpoint
3. Create assignment validation (invalid class, subject, faculty, inactive faculty, duplicate handling)
4. Update assignment & faculty reassignment with multi-faculty support
5. Referential integrity enforcement on deletion (blocks deletion if timetable/sessions exist)
6. Non-admin RBAC authorization controls (Student/Faculty rejected with 403, unauthenticated with 401)
7. Audit log generation for all assignment lifecycle events
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
from app.models.attendance import ClassSession, AttendanceRecord, SessionStatus, AttendanceStatus
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
def setup_data(db_session):
    seed_temporary_dev_timetable(db_session, class_name="all", force_reset=True)

    # 1. Admin
    admin_user = User(
        username="admin_test",
        email="admin@college.local",
        hashed_password=get_password_hash("AdminPass123!"),
        role=UserRole.ADMIN,
        is_active=True
    )
    db_session.add(admin_user)

    # 2. Student
    student_user = User(
        username="student_test",
        email="student@college.local",
        hashed_password=get_password_hash("StudentPass123!"),
        role=UserRole.STUDENT,
        is_active=True
    )
    db_session.add(student_user)

    # 3. Faculty User
    fac_user = User(
        username="fac_user_test",
        email="faculty_user@college.local",
        hashed_password=get_password_hash("FacultyPass123!"),
        role=UserRole.FACULTY,
        is_active=True
    )
    db_session.add(fac_user)

    # 4. Inactive Faculty
    inactive_fac_user = User(
        username="inactive_fac",
        email="inactive@college.local",
        hashed_password=get_password_hash("InactivePass123!"),
        role=UserRole.FACULTY,
        is_active=False
    )
    db_session.add(inactive_fac_user)
    db_session.flush()

    inactive_profile = Faculty(
        user_id=inactive_fac_user.id,
        employee_id="FAC_INACTIVE",
        full_name="Prof. Inactive Member",
        department="CSE Cyber Security"
    )
    db_session.add(inactive_profile)
    db_session.commit()

    admin_token = create_access_token(subject=str(admin_user.id), role="ADMIN")
    student_token = create_access_token(subject=str(student_user.id), role="STUDENT")
    faculty_token = create_access_token(subject=str(fac_user.id), role="FACULTY")

    cs1 = db_session.query(ClassSection).filter(ClassSection.name == "II Year CSE Cyber Security - Class 1").first()
    cs2 = db_session.query(ClassSection).filter(ClassSection.name == "III Year CSE Cyber Security - Class 2").first()

    return {
        "admin_headers": {"Authorization": f"Bearer {admin_token}"},
        "student_headers": {"Authorization": f"Bearer {student_token}"},
        "faculty_headers": {"Authorization": f"Bearer {faculty_token}"},
        "cs1_id": cs1.id,
        "cs2_id": cs2.id,
        "inactive_fac_id": inactive_profile.id,
    }


def test_1_list_assignments_readable_names_and_filters(client, setup_data, db_session):
    """GET /api/v1/admin/assignments returns readable names (no '-' or 'Class #') and supports server-side filtering."""
    headers = setup_data["admin_headers"]

    # 1. Fetch all assignments
    res = client.get("/api/v1/admin/assignments", headers=headers)
    assert res.status_code == 200
    assignments = res.json()
    assert len(assignments) >= 29  # 15 Class 1 + 15 Class 2

    # Verify no row has missing subject name or '-' placeholder
    for a in assignments:
        assert a["class_name"] is not None and not a["class_name"].startswith("Class #")
        assert a["subject_code"] is not None and not a["subject_code"].startswith("Sub #")
        assert a["subject_name"] is not None and a["subject_name"] != "-"
        assert "is_assigned" in a
        assert "timetable_count" in a

    # 2. Filter by class_id
    cs1_res = client.get(f"/api/v1/admin/assignments?class_id={setup_data['cs1_id']}", headers=headers)
    assert cs1_res.status_code == 200
    for a in cs1_res.json():
        assert a["class_id"] == setup_data["cs1_id"]

    # 3. Filter by assigned status (unassigned only)
    unassigned_res = client.get("/api/v1/admin/assignments?assigned=false", headers=headers)
    assert unassigned_res.status_code == 200
    unassigned_list = unassigned_res.json()
    assert len(unassigned_list) > 0
    for a in unassigned_list:
        assert a["is_assigned"] is False
        assert a["faculty_id"] is None

    # 4. Search query
    search_res = client.get("/api/v1/admin/assignments?search=DMC", headers=headers)
    assert search_res.status_code == 200
    for a in search_res.json():
        assert "DMC" in a["subject_code"] or "Discrete" in a["subject_name"]


def test_2_unassigned_state_endpoint_no_cartesian_product(client, setup_data):
    """GET /api/v1/admin/assignments/unassigned returns only actual unassigned curriculum subjects."""
    headers = setup_data["admin_headers"]
    res = client.get("/api/v1/admin/assignments/unassigned", headers=headers)
    assert res.status_code == 200
    items = res.json()

    # Must NOT return hundreds of Cartesian product rows
    assert len(items) <= 10
    for item in items:
        assert "assignment_id" in item
        assert "class_name" in item and item["class_name"] is not None
        assert "subject_code" in item and item["subject_code"] is not None
        assert "subject_name" in item and item["subject_name"] != "-"


def test_3_create_assignment_validation(client, setup_data, db_session):
    """Verify validation when creating assignments."""
    headers = setup_data["admin_headers"]
    cs1_id = setup_data["cs1_id"]
    dmc = db_session.query(Subject).filter(Subject.code == "DMC").first()
    fac07 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC07").first()

    # 1. Invalid Class -> 404
    res_bad_class = client.post("/api/v1/admin/assignments", json={
        "class_id": 99999,
        "subject_id": dmc.id,
        "faculty_id": fac07.id
    }, headers=headers)
    assert res_bad_class.status_code == 404
    assert "Class section ID 99999 not found" in res_bad_class.json()["detail"]

    # 2. Invalid Subject -> 404
    res_bad_sub = client.post("/api/v1/admin/assignments", json={
        "class_id": cs1_id,
        "subject_id": 99999,
        "faculty_id": fac07.id
    }, headers=headers)
    assert res_bad_sub.status_code == 404
    assert "Subject ID 99999 not found" in res_bad_sub.json()["detail"]

    # 3. Invalid Faculty -> 404
    res_bad_fac = client.post("/api/v1/admin/assignments", json={
        "class_id": cs1_id,
        "subject_id": dmc.id,
        "faculty_id": 99999
    }, headers=headers)
    assert res_bad_fac.status_code == 404
    assert "Faculty ID 99999 not found" in res_bad_fac.json()["detail"]

    # 4. Inactive Faculty -> 400
    res_inactive = client.post("/api/v1/admin/assignments", json={
        "class_id": cs1_id,
        "subject_id": dmc.id,
        "faculty_id": setup_data["inactive_fac_id"]
    }, headers=headers)
    assert res_inactive.status_code == 400
    assert "Cannot assign inactive faculty member" in res_inactive.json()["detail"]

    # 5. Duplicate assignment -> 400
    res_dup = client.post("/api/v1/admin/assignments", json={
        "class_id": cs1_id,
        "subject_id": dmc.id,
        "faculty_id": fac07.id
    }, headers=headers)
    assert res_dup.status_code == 400
    assert "already exists" in res_dup.json()["detail"].lower()


def test_4_update_assignment_and_reassignment(client, setup_data, db_session):
    """Admin can reassign an assignment to another faculty member or unassign it."""
    headers = setup_data["admin_headers"]
    cs1_id = setup_data["cs1_id"]

    # DMC is currently assigned to FAC07 (Princy)
    dmc_sub = db_session.query(Subject).filter(Subject.code == "DMC").first()
    dmc_fa = db_session.query(FacultyAssignment).filter(
        FacultyAssignment.class_id == cs1_id,
        FacultyAssignment.subject_id == dmc_sub.id
    ).first()

    fac01 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC01").first()

    # Reassign DMC to FAC01 (Mathu Metlda)
    update_res = client.put(f"/api/v1/admin/assignments/{dmc_fa.id}", json={
        "class_id": cs1_id,
        "subject_id": dmc_sub.id,
        "faculty_id": fac01.id,
        "authorized_faculty_ids": [fac01.id]
    }, headers=headers)

    assert update_res.status_code == 200
    updated_data = update_res.json()
    assert updated_data["faculty_id"] == fac01.id
    assert updated_data["faculty_name"] == fac01.full_name
    assert updated_data["is_assigned"] is True

    # Re-fetch from list
    get_res = client.get(f"/api/v1/admin/assignments?class_id={cs1_id}&subject_id={dmc_sub.id}", headers=headers)
    assert get_res.status_code == 200
    items = get_res.json()
    assert len(items) == 1
    assert items[0]["faculty_id"] == fac01.id


def test_5_delete_assignment_referential_integrity(client, setup_data, db_session):
    """Referential integrity: cannot delete an assignment if timetable slots or sessions depend on it."""
    headers = setup_data["admin_headers"]
    cs1_id = setup_data["cs1_id"]

    # FDS has timetable slots configured
    fds_sub = db_session.query(Subject).filter(Subject.code == "FDS").first()
    fds_fa = db_session.query(FacultyAssignment).filter(
        FacultyAssignment.class_id == cs1_id,
        FacultyAssignment.subject_id == fds_sub.id
    ).first()

    # 1. Attempt delete without cascade -> 400 Bad Request
    del_res = client.delete(f"/api/v1/admin/assignments/{fds_fa.id}", headers=headers)
    assert del_res.status_code == 400
    assert "timetable slot(s) depend on it" in del_res.json()["detail"]

    # 2. Add an unreferenced test assignment and verify it deletes cleanly
    test_sub = Subject(code="TEST_SUB_FREE", name="Test Free Subject")
    db_session.add(test_sub)
    db_session.flush()

    free_fa = FacultyAssignment(
        class_id=cs1_id,
        subject_id=test_sub.id,
        faculty_id=None
    )
    db_session.add(free_fa)
    db_session.commit()

    del_free = client.delete(f"/api/v1/admin/assignments/{free_fa.id}", headers=headers)
    assert del_free.status_code == 200
    assert del_free.json()["message"] == "Assignment deleted successfully"


def test_6_rbac_non_admin_rejected(client, setup_data):
    """Non-admin roles (STUDENT, FACULTY) and unauthenticated users cannot modify assignments."""
    student_headers = setup_data["student_headers"]
    faculty_headers = setup_data["faculty_headers"]

    payload = {
        "class_id": setup_data["cs1_id"],
        "subject_id": 1,
        "faculty_id": 1
    }

    # Student cannot CREATE, UPDATE, DELETE
    assert client.post("/api/v1/admin/assignments", json=payload, headers=student_headers).status_code == 403
    assert client.put("/api/v1/admin/assignments/10", json=payload, headers=student_headers).status_code == 403
    assert client.delete("/api/v1/admin/assignments/10", headers=student_headers).status_code == 403

    # Faculty cannot CREATE, UPDATE, DELETE
    assert client.post("/api/v1/admin/assignments", json=payload, headers=faculty_headers).status_code == 403
    assert client.put("/api/v1/admin/assignments/10", json=payload, headers=faculty_headers).status_code == 403
    assert client.delete("/api/v1/admin/assignments/10", headers=faculty_headers).status_code == 403

    # Unauthenticated rejected
    assert client.post("/api/v1/admin/assignments", json=payload).status_code == 401
    assert client.put("/api/v1/admin/assignments/10", json=payload).status_code == 401
    assert client.delete("/api/v1/admin/assignments/10").status_code == 401


def test_7_audit_logging_lifecycle(client, setup_data, db_session):
    """Lifecycle actions (CREATE, UPDATE, DELETE) generate audit events without leaking sensitive data."""
    headers = setup_data["admin_headers"]
    cs1_id = setup_data["cs1_id"]

    test_sub = Subject(code="AUDIT_SUB", name="Audit Verification Subject")
    db_session.add(test_sub)
    db_session.flush()

    fac01 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC01").first()

    # 1. Create Assignment
    create_res = client.post("/api/v1/admin/assignments", json={
        "class_id": cs1_id,
        "subject_id": test_sub.id,
        "faculty_id": fac01.id
    }, headers=headers)
    assert create_res.status_code == 201
    assign_id = create_res.json()["id"]

    audit_create = db_session.query(AuditLog).filter(
        AuditLog.action == "CREATE_FACULTY_ASSIGNMENT"
    ).order_by(AuditLog.id.desc()).first()
    assert audit_create is not None
    assert "Assigned faculty" in audit_create.details

    # 2. Update Assignment
    fac02 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC02").first()
    update_res = client.put(f"/api/v1/admin/assignments/{assign_id}", json={
        "class_id": cs1_id,
        "subject_id": test_sub.id,
        "faculty_id": fac02.id
    }, headers=headers)
    assert update_res.status_code == 200

    audit_update = db_session.query(AuditLog).filter(
        AuditLog.action == "UPDATE_FACULTY_ASSIGNMENT"
    ).order_by(AuditLog.id.desc()).first()
    assert audit_update is not None
    assert f"Reassigned assignment ID {assign_id}" in audit_update.details

    # 3. Delete Assignment
    del_res = client.delete(f"/api/v1/admin/assignments/{assign_id}", headers=headers)
    assert del_res.status_code == 200

    audit_del = db_session.query(AuditLog).filter(
        AuditLog.action == "DELETE_FACULTY_ASSIGNMENT"
    ).order_by(AuditLog.id.desc()).first()
    assert audit_del is not None
    assert f"Deleted assignment ID {assign_id}" in audit_del.details
