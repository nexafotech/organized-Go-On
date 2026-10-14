import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token
from app.core.config import settings
from app.models.user import User, Faculty, UserRole
from app.models.student import Student
from app.models.academic import ClassSection
from app.models.audit import AuditLog
from app.services.college_importer import import_students, import_faculty, ImportValidationError
from datetime import datetime, timezone, timedelta
from app.core.datetime_utils import normalize_utc_datetime
from scripts.validate_production_college_data import ProductionCollegeDataValidator, LEVEL_FAIL

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

    # Dev Faculty (FAC01)
    fac_user = User(
        username="fac01",
        email="fac01@college.edu",
        hashed_password=get_password_hash("faculty123"),
        role=UserRole.FACULTY,
        is_active=True,
        login_identifier="FAC01"
    )
    db_session.add(fac_user)
    db_session.flush()

    dev_fac = Faculty(
        user_id=fac_user.id,
        employee_id="FAC01",
        full_name="Dr. Alan Turing",
        department="Computer Science"
    )
    db_session.add(dev_fac)

    # Class Sections
    cs1 = ClassSection(name="Class 1", grade_level="1", academic_year="2026-2027")
    cs2 = ClassSection(name="Class 2", grade_level="2", academic_year="2026-2027")
    db_session.add_all([cs1, cs2])
    db_session.commit()

    admin_token = create_access_token(admin.id, role="admin")
    faculty_token = create_access_token(fac_user.id, role="faculty")

    return {
        "admin": {"Authorization": f"Bearer {admin_token}"},
        "faculty": {"Authorization": f"Bearer {faculty_token}"},
        "admin_user": admin,
        "fac_user": fac_user,
        "fac_profile": dev_fac,
        "class_1": cs1,
        "class_2": cs2
    }


# ----------------------------------------------------
# 1. Capacity Stats API
# ----------------------------------------------------
def test_capacity_stats_endpoint(client, auth_headers):
    response = client.get("/api/v1/admin/capacity-stats", headers=auth_headers["admin"])
    assert response.status_code == 200
    data = response.json()
    assert "students" in data
    assert "faculty" in data
    assert data["students"]["max"] == settings.MAX_STUDENTS
    assert data["students"]["current"] == 0
    assert data["students"]["remaining"] == settings.MAX_STUDENTS
    assert data["faculty"]["max"] == settings.MAX_FACULTY
    assert data["faculty"]["current"] == 1  # FAC01 seeded
    assert data["faculty"]["remaining"] == settings.MAX_FACULTY - 1


# ----------------------------------------------------
# 2. Student Capacity Limit (Boundary Enforcement)
# ----------------------------------------------------
def test_student_capacity_limit_enforced(client, auth_headers, db_session, monkeypatch):
    monkeypatch.setattr(settings, "MAX_STUDENTS", 130)
    cs = auth_headers["class_1"]
    # Bulk insert 130 students directly to test boundary
    for i in range(130):
        u = User(username=f"23ST{i:03d}", hashed_password="hash", role=UserRole.STUDENT, is_active=True, login_identifier=f"23ST{i:03d}")
        db_session.add(u)
        db_session.flush()
        st = Student(user_id=u.id, roll_number=f"23ST{i:03d}", full_name=f"Student {i}", class_id=cs.id, is_active=True)
        db_session.add(st)
    db_session.commit()

    # Attempt to create 131st student via admin API
    payload = {
        "roll_number": "23ST999",
        "full_name": "Overflow Student",
        "email": "overflow@student.edu",
        "class_id": cs.id,
        "generate_temporary": True
    }
    response = client.post("/api/v1/admin/students", json=payload, headers=auth_headers["admin"])
    assert response.status_code == 400
    assert "Maximum student capacity of 130 has been reached" in response.json()["detail"]


# ----------------------------------------------------
# 3. Faculty Capacity Limit (Boundary Enforcement)
# ----------------------------------------------------
def test_faculty_capacity_limit_enforced(client, auth_headers, db_session, monkeypatch):
    monkeypatch.setattr(settings, "MAX_FACULTY", 15)
    # Add 14 more faculty to reach 15 (FAC01 already seeded)
    for i in range(2, 16):
        u = User(username=f"fac{i:02d}", hashed_password="hash", role=UserRole.FACULTY, is_active=True, login_identifier=f"FAC{i:02d}")
        db_session.add(u)
        db_session.flush()
        f = Faculty(user_id=u.id, employee_id=f"FAC{i:02d}", full_name=f"Faculty {i}", department="CSE")
        db_session.add(f)
    db_session.commit()

    # Attempt to create 16th faculty via admin API
    payload = {
        "employee_id": "FAC16",
        "full_name": "Overflow Faculty",
        "username": "fac16",
        "email": "fac16@college.edu",
        "generate_temporary": True
    }
    response = client.post("/api/v1/admin/faculty", json=payload, headers=auth_headers["admin"])
    assert response.status_code == 400
    assert "Maximum faculty capacity of 15 has been reached" in response.json()["detail"]


# ----------------------------------------------------
# 4. Student Create with Temporary Password & Hashing
# ----------------------------------------------------
def test_student_create_temporary_password(client, auth_headers, db_session):
    payload = {
        "roll_number": "23CY001",
        "full_name": "Grace Hopper",
        "email": "grace@student.edu",
        "department": "Cyber Security",
        "semester": "3",
        "generate_temporary": True,
        "force_password_change": True
    }
    response = client.post("/api/v1/admin/students", json=payload, headers=auth_headers["admin"])
    assert response.status_code == 201
    data = response.json()
    assert data["roll_number"] == "23CY001"
    assert data["temporary_password"] is not None
    assert len(data["temporary_password"]) == 8
    assert data["force_password_change"] is True

    # Verify user in database has hashed password and force_password_change set
    user = db_session.query(User).filter(User.username == "23CY001").first()
    assert user is not None
    assert user.hashed_password != data["temporary_password"]
    assert user.force_password_change is True
    assert user.is_active is True


# ----------------------------------------------------
# 5. Faculty Create with Temporary Password & Hashing
# ----------------------------------------------------
def test_faculty_create_temporary_password(client, auth_headers, db_session):
    payload = {
        "employee_id": "EMP101",
        "full_name": "Dr. Katherine Johnson",
        "username": "kjohnson",
        "email": "kjohnson@college.edu",
        "department": "Mathematics",
        "generate_temporary": True,
        "force_password_change": True
    }
    response = client.post("/api/v1/admin/faculty", json=payload, headers=auth_headers["admin"])
    assert response.status_code == 201
    data = response.json()
    assert data["employee_id"] == "EMP101"
    assert data["temporary_password"] is not None
    assert data["force_password_change"] is True
    assert data["is_dev_account"] is False

    user = db_session.query(User).filter(User.username == "kjohnson").first()
    assert user is not None
    assert user.hashed_password != data["temporary_password"]
    assert user.force_password_change is True


# ----------------------------------------------------
# 6. Non-Admin Forbidden (RBAC)
# ----------------------------------------------------
def test_non_admin_cannot_manage_accounts(client, auth_headers):
    # Student create attempt
    r1 = client.post("/api/v1/admin/students", json={"roll_number": "23CY002", "full_name": "Test"}, headers=auth_headers["faculty"])
    assert r1.status_code == 403

    # Faculty create attempt
    r2 = client.post("/api/v1/admin/faculty", json={"employee_id": "EMP102", "full_name": "Test", "username": "t", "email": "t@t.com"}, headers=auth_headers["faculty"])
    assert r2.status_code == 403


# ----------------------------------------------------
# 7. Dev Faculty Pill Indicator & Editability
# ----------------------------------------------------
def test_dev_faculty_indicator_and_edit(client, auth_headers, monkeypatch):
    monkeypatch.setenv("DEV_FACULTY_EMP_IDS", "FAC01")
    response = client.get("/api/v1/admin/faculty", headers=auth_headers["admin"])
    assert response.status_code == 200
    fac_list = response.json()
    fac01 = next(f for f in fac_list if f["employee_id"] == "FAC01")
    assert fac01["is_dev_account"] is True

    # Dev faculty must remain fully editable
    update_res = client.put(f"/api/v1/admin/faculty/{fac01['id']}", json={
        "full_name": "Dr. Alan Turing (Updated)",
        "department": "Theoretical CS",
        "email": "alan.turing@college.edu",
        "is_active": True
    }, headers=auth_headers["admin"])
    assert update_res.status_code == 200
    assert update_res.json()["full_name"] == "Dr. Alan Turing (Updated)"
    assert update_res.json()["department"] == "Theoretical CS"


# ----------------------------------------------------
# 8. Disable & Enable Student Workflow
# ----------------------------------------------------
def test_disable_and_enable_student(client, auth_headers):
    # Create student
    create_res = client.post("/api/v1/admin/students", json={
        "roll_number": "23CY010",
        "full_name": "Ada Lovelace",
        "password": "Password123!",
        "generate_temporary": False
    }, headers=auth_headers["admin"])
    st_id = create_res.json()["id"]

    # Verify student can login initially via student login endpoint
    login_res = client.post("/api/v1/auth/student/login", json={"identifier": "23CY010", "password": "Password123!"})
    assert login_res.status_code == 200

    # Disable student
    dis_res = client.post(f"/api/v1/admin/students/{st_id}/disable", headers=auth_headers["admin"])
    assert dis_res.status_code == 200
    assert dis_res.json()["is_active"] is False

    # Login now rejected with 403
    bad_login = client.post("/api/v1/auth/student/login", json={"identifier": "23CY010", "password": "Password123!"})
    assert bad_login.status_code == 403
    assert "disabled" in bad_login.json()["detail"].lower()

    # Re-enable student
    en_res = client.post(f"/api/v1/admin/students/{st_id}/enable", headers=auth_headers["admin"])
    assert en_res.status_code == 200
    assert en_res.json()["is_active"] is True

    # Login succeeds again
    ok_login = client.post("/api/v1/auth/student/login", json={"identifier": "23CY010", "password": "Password123!"})
    assert ok_login.status_code == 200


# ----------------------------------------------------
# 9. Disable & Enable Faculty Workflow
# ----------------------------------------------------
def test_disable_and_enable_faculty(client, auth_headers):
    # Create faculty
    create_res = client.post("/api/v1/admin/faculty", json={
        "employee_id": "EMP201",
        "full_name": "Dr. Claude Shannon",
        "username": "cshannon",
        "email": "shannon@college.edu",
        "password": "Password123!",
        "generate_temporary": False
    }, headers=auth_headers["admin"])
    fac_id = create_res.json()["id"]

    # Verify login initially works via faculty login endpoint
    login_res = client.post("/api/v1/auth/login", json={"username_or_email": "cshannon", "password": "Password123!"})
    assert login_res.status_code == 200

    # Disable faculty
    dis_res = client.post(f"/api/v1/admin/faculty/{fac_id}/disable", headers=auth_headers["admin"])
    assert dis_res.status_code == 200
    assert dis_res.json()["is_active"] is False

    # Login rejected with 403
    bad_login = client.post("/api/v1/auth/login", json={"username_or_email": "cshannon", "password": "Password123!"})
    assert bad_login.status_code == 403

    # Re-enable faculty
    en_res = client.post(f"/api/v1/admin/faculty/{fac_id}/enable", headers=auth_headers["admin"])
    assert en_res.status_code == 200
    assert en_res.json()["is_active"] is True

    # Login succeeds
    ok_login = client.post("/api/v1/auth/login", json={"username_or_email": "cshannon", "password": "Password123!"})
    assert ok_login.status_code == 200


# ----------------------------------------------------
# 10. Password Reset & Force Password Change Endpoints
# ----------------------------------------------------
def test_student_and_faculty_password_reset_and_force_change(client, auth_headers, db_session):
    # Create student
    st_res = client.post("/api/v1/admin/students", json={
        "roll_number": "23CY020",
        "full_name": "Margaret Hamilton",
        "password": "OldPassword1!",
        "generate_temporary": False
    }, headers=auth_headers["admin"])
    st_id = st_res.json()["id"]

    # Reset password with temporary generator
    reset_res = client.post(f"/api/v1/admin/students/{st_id}/reset-password", json={
        "generate_temporary": True,
        "force_password_change": True
    }, headers=auth_headers["admin"])
    assert reset_res.status_code == 200
    reset_data = reset_res.json()
    assert reset_data["temporary_password"] is not None
    assert reset_data["force_password_change"] is True

    # Verify old password fails and new temporary password works
    fail_login = client.post("/api/v1/auth/student/login", json={"identifier": "23CY020", "password": "OldPassword1!"})
    assert fail_login.status_code == 401

    succ_login = client.post("/api/v1/auth/student/login", json={"identifier": "23CY020", "password": reset_data["temporary_password"]})
    assert succ_login.status_code == 200

    # Force password change endpoint for faculty
    fac_id = auth_headers["fac_profile"].id
    force_res = client.post(f"/api/v1/admin/faculty/{fac_id}/force-password-change", headers=auth_headers["admin"])
    assert force_res.status_code == 200
    assert force_res.json()["force_password_change"] is True


# ----------------------------------------------------
# 11. Security: Plaintext Passwords Never Exposed in GET
# ----------------------------------------------------
def test_get_apis_never_expose_plaintext_passwords(client, auth_headers):
    # Create student with temp password
    client.post("/api/v1/admin/students", json={
        "roll_number": "23CY030",
        "full_name": "Tim Berners-Lee",
        "generate_temporary": True
    }, headers=auth_headers["admin"])

    # GET students
    st_list = client.get("/api/v1/admin/students", headers=auth_headers["admin"]).json()
    st_obj = next(s for s in st_list if s["roll_number"] == "23CY030")
    assert "password" not in st_obj
    assert "hashed_password" not in st_obj
    assert st_obj.get("temporary_password") is None

    # GET faculty
    fac_list = client.get("/api/v1/admin/faculty", headers=auth_headers["admin"]).json()
    for f in fac_list:
        assert "password" not in f
        assert "hashed_password" not in f
        assert f.get("temporary_password") is None


# ----------------------------------------------------
# 12. Importer Capacity Limits Validation
# ----------------------------------------------------
def test_importer_enforces_capacity_limits(db_session, monkeypatch):
    monkeypatch.setattr(settings, "MAX_FACULTY", 15)
    monkeypatch.setattr(settings, "MAX_STUDENTS", 130)
    # Attempt to import 16 faculty records (limit 15)
    overflow_faculty = [
        {"employee_id": f"TEST_FAC_{i:02d}", "username": f"testfac{i:02d}", "full_name": f"Test Fac {i}", "email": f"fac{i}@test.com"}
        for i in range(16)
    ]
    with pytest.raises(ImportValidationError) as exc_info:
        import_faculty(db_session, overflow_faculty)
    assert "Maximum faculty capacity of 15 has been reached" in str(exc_info.value.errors)

    # Attempt to import 131 student records (limit 130)
    overflow_students = [
        {"roll_number": f"TEST_ST_{i:03d}", "full_name": f"Test Student {i}", "email": f"st{i}@test.com"}
        for i in range(131)
    ]
    with pytest.raises(ImportValidationError) as exc_info_st:
        import_students(db_session, overflow_students)
    assert "Maximum student capacity of 130 has been reached" in str(exc_info_st.value.errors)


# ----------------------------------------------------
# 13. Validator Script Capacity Validation
# ----------------------------------------------------
def test_validator_script_flags_capacity_overflow(tmp_path, monkeypatch):
    import scripts.validate_production_college_data as val_mod
    monkeypatch.setattr(val_mod, "MAX_FACULTY", 15)
    validator = ProductionCollegeDataValidator(base_dir=str(tmp_path))
    # Test faculty capacity overflow
    fake_faculty = [{"employee_id": f"F{i}", "username": f"u{i}", "full_name": f"N{i}", "email": f"e{i}@c.edu"} for i in range(16)]
    with open(tmp_path / "faculty.json", "w") as f:
        import json
        json.dump(fake_faculty, f)

    validator.validate_faculty()
    fail_findings = [f for f in validator.findings if f.level == LEVEL_FAIL and f.field == "capacity"]
    assert len(fail_findings) > 0
    assert "exceeds maximum system capacity of 15" in fail_findings[0].problem


# ----------------------------------------------------
# 14. Audit Log Verification
# ----------------------------------------------------
def test_audit_logs_recorded_for_account_actions(client, auth_headers, db_session):
    # Perform various admin actions
    client.post("/api/v1/admin/students", json={"roll_number": "23CY099", "full_name": "Audit Test Student", "generate_temporary": True}, headers=auth_headers["admin"])
    st = db_session.query(Student).filter(Student.roll_number == "23CY099").first()
    st_id = st.id

    client.post(f"/api/v1/admin/students/{st_id}/disable", headers=auth_headers["admin"])
    client.post(f"/api/v1/admin/students/{st_id}/enable", headers=auth_headers["admin"])
    client.post(f"/api/v1/admin/students/{st_id}/reset-password", json={"generate_temporary": True}, headers=auth_headers["admin"])
    client.post(f"/api/v1/admin/students/{st_id}/force-password-change", headers=auth_headers["admin"])

    actions = [a.action for a in db_session.query(AuditLog).all()]

    assert "CREATE_STUDENT" in actions
    assert "DISABLE_STUDENT" in actions
    assert "ENABLE_STUDENT" in actions
    assert "RESET_STUDENT_PASSWORD" in actions
    assert "FORCE_PASSWORD_CHANGE_STUDENT" in actions


# ----------------------------------------------------
# 15. Datetime Normalization & Lock Status Regression
# ----------------------------------------------------
def test_normalize_utc_datetime_helper():
    """Unit tests for normalize_utc_datetime helper."""
    # 1. None returns None
    assert normalize_utc_datetime(None) is None

    # 2. Naive datetime gets timezone.utc attached
    naive = datetime(2026, 8, 19, 12, 0, 0)
    aware = normalize_utc_datetime(naive)
    assert aware.tzinfo == timezone.utc
    assert aware.year == 2026 and aware.month == 8 and aware.day == 19
    assert aware.hour == 12 and aware.minute == 0

    # 3. Aware datetime is safely preserved / converted to UTC
    now_utc = datetime.now(timezone.utc)
    res = normalize_utc_datetime(now_utc)
    assert res.tzinfo == timezone.utc
    assert res == now_utc


def test_admin_students_list_datetime_naive_and_aware_support(client, auth_headers, db_session):
    """
    Tests that GET /api/v1/admin/students succeeds with:
    - locked_until is NULL
    - locked_until is a naive future datetime (is_locked=True)
    - locked_until is a naive past datetime (is_locked=False)
    - locked_until is an aware future UTC datetime (is_locked=True)
    - locked_until is an aware past UTC datetime (is_locked=False)
    Ensures NO HTTP 500 error is thrown.
    """
    cs = ClassSection(name="II Year CSE Cyber Security - Class 1", academic_year="2025-2026", grade_level="2")
    db_session.add(cs)
    db_session.flush()

    # 1. Student with locked_until = NULL
    u1 = User(
        username="721025149001",
        email="s1@college.edu",
        role=UserRole.STUDENT,
        is_active=True,
        hashed_password=get_password_hash("Secret123!"),
        locked_until=None
    )
    db_session.add(u1)
    db_session.flush()
    s1 = Student(user_id=u1.id, roll_number="721025149001", full_name="Student None Lock", class_id=cs.id, is_active=True)
    db_session.add(s1)

    # 2. Student with naive future locked_until (active lock)
    u2 = User(
        username="721025149002",
        email="s2@college.edu",
        role=UserRole.STUDENT,
        is_active=True,
        hashed_password=get_password_hash("Secret123!"),
        locked_until=datetime(2099, 12, 31, 23, 59, 59)  # Naive future
    )
    db_session.add(u2)
    db_session.flush()
    s2 = Student(user_id=u2.id, roll_number="721025149002", full_name="Student Naive Future Lock", class_id=cs.id, is_active=True)
    db_session.add(s2)

    # 3. Student with naive past locked_until (expired lock)
    u3 = User(
        username="721025149003",
        email="s3@college.edu",
        role=UserRole.STUDENT,
        is_active=True,
        hashed_password=get_password_hash("Secret123!"),
        locked_until=datetime(2020, 1, 1, 0, 0, 0)  # Naive past
    )
    db_session.add(u3)
    db_session.flush()
    s3 = Student(user_id=u3.id, roll_number="721025149003", full_name="Student Naive Past Lock", class_id=cs.id, is_active=True)
    db_session.add(s3)

    # 4. Student with aware future locked_until (active lock)
    u4 = User(
        username="721025149004",
        email="s4@college.edu",
        role=UserRole.STUDENT,
        is_active=True,
        hashed_password=get_password_hash("Secret123!"),
        locked_until=datetime.now(timezone.utc) + timedelta(days=10)  # Aware future
    )
    db_session.add(u4)
    db_session.flush()
    s4 = Student(user_id=u4.id, roll_number="721025149004", full_name="Student Aware Future Lock", class_id=cs.id, is_active=True)
    db_session.add(s4)

    # 5. Student with aware past locked_until (expired lock)
    u5 = User(
        username="721025149005",
        email="s5@college.edu",
        role=UserRole.STUDENT,
        is_active=True,
        hashed_password=get_password_hash("Secret123!"),
        locked_until=datetime.now(timezone.utc) - timedelta(days=10)  # Aware past
    )
    db_session.add(u5)
    db_session.flush()
    s5 = Student(user_id=u5.id, roll_number="721025149005", full_name="Student Aware Past Lock", class_id=cs.id, is_active=True)
    db_session.add(s5)

    db_session.commit()

    # Call GET /api/v1/admin/students
    response = client.get("/api/v1/admin/students", headers=auth_headers["admin"])
    assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"

    data = response.json()
    assert len(data) >= 5

    student_map = {item["roll_number"]: item for item in data}

    # Verify lock statuses
    assert student_map["721025149001"]["is_locked"] is False
    assert student_map["721025149002"]["is_locked"] is True
    assert student_map["721025149003"]["is_locked"] is False
    assert student_map["721025149004"]["is_locked"] is True
    assert student_map["721025149005"]["is_locked"] is False


def test_admin_faculty_list_datetime_naive_and_aware_support(client, auth_headers, db_session):
    """
    Tests that GET /api/v1/admin/faculty succeeds with naive and aware locked_until without 500 error.
    """
    # Create faculty with naive future locked_until
    u_fac = User(
        username="fac_naive_lock",
        email="fac_naive@college.edu",
        role=UserRole.FACULTY,
        is_active=True,
        hashed_password=get_password_hash("FacultySecret123!"),
        locked_until=datetime(2099, 1, 1, 0, 0, 0)
    )
    db_session.add(u_fac)
    db_session.flush()
    f = Faculty(user_id=u_fac.id, employee_id="FAC_NAIVE", full_name="Faculty Naive Lock", department="CSE", phone="9876543210")
    db_session.add(f)
    db_session.commit()

    response = client.get("/api/v1/admin/faculty", headers=auth_headers["admin"])
    assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"

    data = response.json()
    fac_map = {item["employee_id"]: item for item in data}
    assert fac_map["FAC_NAIVE"]["is_locked"] is True
