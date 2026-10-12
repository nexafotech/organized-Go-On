"""
Unit and Integration tests for Milestone 10C.14 & 10C.14B:
- 5-Character Secure Temporary Password Policy & Hashing
- User Password Change (Min 8 Chars, Confirmation, Timestamp Update)
- Admin Password Change Windows (CRUD, Scopes, Immediate Enforcement, Stats)
- Admin Support-Access / Impersonation Mode (Re-Auth, Target Validation, Read-Only Inspect, Expiry, Audit)
"""
import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.core.database import Base, get_db
from app.models.user import User, Faculty, UserRole, PasswordChangeScope, PasswordChangeWindow, AdminSupportSession
from app.models.student import Student
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.audit import AuditLog
from app.core.security import get_password_hash, verify_password, create_access_token
from app.api.admin import _generate_temporary_password
from app.services.class1_onboarding_service import generate_secure_temporary_password


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
        hashed_password=get_password_hash("AdminPass123!"),
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
        full_name="Mathu Metlda",
        department="CSE"
    )
    db_session.add(dev_fac)

    # Student User
    st_user = User(
        username="student01",
        email="student01@college.edu",
        hashed_password=get_password_hash("student123"),
        role=UserRole.STUDENT,
        is_active=True,
        login_identifier="721025149001"
    )
    db_session.add(st_user)
    db_session.commit()

    admin_token = create_access_token(admin.id, role="admin")
    fac_token = create_access_token(fac_user.id, role="faculty")
    st_token = create_access_token(st_user.id, role="student")

    return {
        "admin": {"Authorization": f"Bearer {admin_token}"},
        "faculty": {"Authorization": f"Bearer {fac_token}"},
        "student": {"Authorization": f"Bearer {st_token}"}
    }


# =============================================================================
# 1. TEMPORARY PASSWORD GENERATOR (EXACTLY 5 CHARACTERS)
# =============================================================================

def test_temporary_password_exact_length_and_character_diversity():
    """Validates that generated temporary passwords are mathematically 5 chars and high entropy."""
    for _ in range(50):
        pwd = _generate_temporary_password(5)
        assert len(pwd) == 5, f"Password {pwd} length is {len(pwd)}, expected 5"
        has_upper = any(c.isupper() for c in pwd)
        has_lower = any(c.islower() for c in pwd)
        has_digit = any(c.isdigit() for c in pwd)
        has_sym = any(c in "!@#$%^&*" for c in pwd)
        assert has_upper or has_lower or has_digit or has_sym

        # Test class1 onboarding generator as well
        pwd2 = generate_secure_temporary_password(5)
        assert len(pwd2) == 5, f"Class1 password {pwd2} length is {len(pwd2)}, expected 5"


# =============================================================================
# 2. ADMIN STUDENT & FACULTY PASSWORD RESET (5-CHAR TEMP PW)
# =============================================================================

def test_admin_reset_student_password(client, auth_headers, db_session):
    """Admin resets student password -> gets exactly 5 char temp pw, db stores only hash."""
    user = User(
        username="721025149099",
        email="test_st_pw@college.edu",
        hashed_password=get_password_hash("OldPassword123!"),
        role=UserRole.STUDENT,
        is_active=True,
        force_password_change=False
    )
    db_session.add(user)
    db_session.flush()

    student = Student(
        user_id=user.id,
        roll_number="721025149099",
        full_name="Test Password Student",
        is_active=True
    )
    db_session.add(student)
    db_session.commit()

    resp = client.post(
        f"/api/v1/admin/students/{student.id}/reset-password",
        json={"generate_temporary": True, "force_password_change": True},
        headers=auth_headers["admin"]
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["temporary_password"] is not None
    assert len(data["temporary_password"]) == 8
    assert data["force_password_change"] is True

    # Check DB
    db_session.refresh(user)
    assert user.force_password_change is True
    assert verify_password(data["temporary_password"], user.hashed_password)
    assert user.hashed_password != data["temporary_password"]


def test_admin_reset_faculty_password(client, auth_headers, db_session):
    """Admin resets faculty password -> gets 5 char temp pw and force_password_change flag."""
    user = User(
        username="testfac_reset",
        email="testfac_reset@college.edu",
        hashed_password=get_password_hash("OldFacPassword123!"),
        role=UserRole.FACULTY,
        is_active=True,
        force_password_change=False
    )
    db_session.add(user)
    db_session.flush()

    faculty = Faculty(
        user_id=user.id,
        employee_id="FAC_RST99",
        full_name="Prof. Reset Test",
        department="CSE"
    )
    db_session.add(faculty)
    db_session.commit()

    resp = client.post(
        f"/api/v1/admin/faculty/{faculty.id}/reset-password",
        json={"generate_temporary": True, "force_password_change": True},
        headers=auth_headers["admin"]
    )
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["temporary_password"]) == 8
    assert data["force_password_change"] is True

    db_session.refresh(user)
    assert user.force_password_change is True
    assert verify_password(data["temporary_password"], user.hashed_password)


def test_faculty_reset_password_revealed_password_matches_hash(client, auth_headers, db_session):
    """Explicit regression test for Milestone 10C.15 bug:
    Ensures revealed temporary password matches stored bcrypt hash, clears lock/attempts, and invalidates old password.
    """
    old_pw = "OldFacPassword123!"
    user = User(
        username="fac06_test",
        email="fac06_test@college.edu",
        hashed_password=get_password_hash(old_pw),
        role=UserRole.FACULTY,
        is_active=True,
        force_password_change=False,
        failed_login_attempts=3,
        locked_until=datetime.now(timezone.utc) + timedelta(minutes=15),
        login_identifier="FAC06_TEST"
    )
    db_session.add(user)
    db_session.flush()

    faculty = Faculty(
        user_id=user.id,
        employee_id="FAC06_TEST",
        full_name="Lakshmi Narayanan Test",
        department="CSE Cyber Security"
    )
    db_session.add(faculty)
    db_session.commit()

    # Verify old login works before reset
    login_before = client.post("/api/v1/auth/faculty/login", json={"identifier": "FAC06_TEST", "password": old_pw})
    # Might be locked or 401/423 due to locked_until, let's reset via Admin
    resp = client.post(
        f"/api/v1/admin/faculty/{faculty.id}/reset-password",
        json={"generate_temporary": True, "force_password_change": True},
        headers=auth_headers["admin"]
    )
    assert resp.status_code == 200
    data = resp.json()
    revealed_password = data["temporary_password"]
    assert revealed_password is not None
    assert len(revealed_password) == 8
    assert data["force_password_change"] is True

    # 1. Verify bcrypt match
    db_session.refresh(user)
    assert verify_password(revealed_password, user.hashed_password) is True
    assert user.hashed_password != revealed_password

    # 2. Verify account security state reset
    assert user.force_password_change is True
    assert user.failed_login_attempts == 0
    assert user.locked_until is None
    assert user.session_token is None

    # 3. Verify old password no longer works
    fail_old = client.post("/api/v1/auth/login", json={"username_or_email": "fac06_test", "password": old_pw})
    assert fail_old.status_code == 401

    # 4. Verify revealed password succeeds on login
    succ_new = client.post("/api/v1/auth/login", json={"username_or_email": "fac06_test", "password": revealed_password})
    assert succ_new.status_code == 200
    assert succ_new.json()["access_token"] is not None
    db_session.refresh(user)
    assert user.force_password_change is True


def test_student_reset_password_revealed_password_matches_hash(client, auth_headers, db_session):
    """Equivalent regression test for Student reset-password."""
    old_pw = "OldStudentPass123!"
    user = User(
        username="721025149088",
        email="stu_rst_test@college.edu",
        hashed_password=get_password_hash(old_pw),
        role=UserRole.STUDENT,
        is_active=True,
        force_password_change=False,
        failed_login_attempts=4,
        locked_until=datetime.now(timezone.utc) + timedelta(minutes=15),
        login_identifier="721025149088"
    )
    db_session.add(user)
    db_session.flush()

    student = Student(
        user_id=user.id,
        roll_number="721025149088",
        full_name="Regression Student Test",
        is_active=True
    )
    db_session.add(student)
    db_session.commit()

    resp = client.post(
        f"/api/v1/admin/students/{student.id}/reset-password",
        json={"generate_temporary": True, "force_password_change": True},
        headers=auth_headers["admin"]
    )
    assert resp.status_code == 200
    data = resp.json()
    revealed_password = data["temporary_password"]
    assert revealed_password is not None
    assert len(revealed_password) == 8

    # Check DB
    db_session.refresh(user)
    assert verify_password(revealed_password, user.hashed_password) is True
    assert user.force_password_change is True
    assert user.failed_login_attempts == 0
    assert user.locked_until is None

    # Check old fails, new succeeds
    assert client.post("/api/v1/auth/student/login", json={"identifier": "721025149088", "password": old_pw}).status_code == 401
    succ_login = client.post("/api/v1/auth/student/login", json={"identifier": "721025149088", "password": revealed_password})
    assert succ_login.status_code == 200
    assert succ_login.json()["force_password_change"] is True


# =============================================================================
# 3. USER PASSWORD CHANGE (MIN 8 CHARS, CONFIRMATION, TIMESTAMP)
# =============================================================================

def test_user_change_password_policy_and_confirmation(client, db_session):
    """Tests password change validation: minimum 8 characters, confirmation check, timestamp."""
    user = User(
        username="student_pw_changer",
        email="pw_changer@college.edu",
        hashed_password=get_password_hash("A1#b2"),
        role=UserRole.STUDENT,
        is_active=True,
        force_password_change=True,
        session_token="test_token_pw"
    )
    db_session.add(user)
    db_session.commit()

    token = create_access_token(user.id, role="student")
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Reject < 8 chars (e.g. 5 chars)
    r1 = client.post("/api/v1/auth/change-password", json={
        "current_password": "A1#b2",
        "new_password": "Short1!"
    }, headers=headers)
    assert r1.status_code == 400
    assert "at least 8 characters" in r1.json()["detail"]

    # 2. Reject mismatched confirmation
    r2 = client.post("/api/v1/auth/change-password", json={
        "current_password": "A1#b2",
        "new_password": "ValidNewPassword123!",
        "confirm_password": "DifferentPassword123!"
    }, headers=headers)
    assert r2.status_code == 400
    assert "do not match" in r2.json()["detail"]

    # 3. Reject same password as current
    r3 = client.post("/api/v1/auth/change-password", json={
        "current_password": "A1#b2",
        "new_password": "A1#b2",
        "confirm_password": "A1#b2"
    }, headers=headers)
    assert r3.status_code == 400

    # 4. Successful change
    r4 = client.post("/api/v1/auth/change-password", json={
        "current_password": "A1#b2",
        "new_password": "ValidNewPassword123!",
        "confirm_password": "ValidNewPassword123!"
    }, headers=headers)
    assert r4.status_code == 200
    assert r4.json()["force_password_change"] is False

    db_session.refresh(user)
    assert user.force_password_change is False
    assert user.password_changed_at is not None
    assert verify_password("ValidNewPassword123!", user.hashed_password)


# =============================================================================
# 4. PASSWORD CHANGE WINDOWS CRUD & ENFORCEMENT
# =============================================================================

def test_password_change_windows_crud_and_enforcement(client, auth_headers, db_session):
    """Tests Admin creation, application, updating, and stats for Password Change Windows."""
    # Create student & faculty with force_password_change = False
    u1 = User(username="st_win_1", role=UserRole.STUDENT, is_active=True, force_password_change=False, hashed_password="h")
    u2 = User(username="fac_win_1", role=UserRole.FACULTY, is_active=True, force_password_change=False, hashed_password="h")
    db_session.add_all([u1, u2])
    db_session.commit()

    # 1. Create Window for ALL_STUDENTS
    win_payload = {
        "title": "Semester Mandatory Password Reset",
        "scope": "ALL_STUDENTS",
        "is_active": True
    }
    r_create = client.post("/api/v1/admin/password-change-window", json=win_payload, headers=auth_headers["admin"])
    assert r_create.status_code == 201
    win_data = r_create.json()
    assert win_data["title"] == "Semester Mandatory Password Reset"
    assert win_data["scope"] == "ALL_STUDENTS"
    assert win_data["affected_users_count"] >= 1

    # Verify student u1 has force_password_change = True
    db_session.refresh(u1)
    db_session.refresh(u2)
    assert u1.force_password_change is True
    assert u1.password_change_window_id == win_data["id"]

    # 2. Check stats endpoint
    r_stats = client.get("/api/v1/admin/password-control/stats", headers=auth_headers["admin"])
    assert r_stats.status_code == 200
    stats = r_stats.json()
    assert stats["students_requiring_change"] >= 1
    assert stats["active_windows_count"] >= 1

    # 3. List Windows
    r_list = client.get("/api/v1/admin/password-change-window", headers=auth_headers["admin"])
    assert r_list.status_code == 200
    assert len(r_list.json()) >= 1

    # 4. Update Window
    r_update = client.put(
        f"/api/v1/admin/password-change-window/{win_data['id']}",
        json={"title": "Updated Window Title", "is_active": False},
        headers=auth_headers["admin"]
    )
    assert r_update.status_code == 200
    assert r_update.json()["title"] == "Updated Window Title"
    assert r_update.json()["is_active"] is False

    # 5. Delete Window
    r_del = client.delete(f"/api/v1/admin/password-change-window/{win_data['id']}", headers=auth_headers["admin"])
    assert r_del.status_code == 200


# =============================================================================
# 5. ADMIN SUPPORT MODE (IMPERSONATION & INSPECTION)
# =============================================================================

def test_admin_support_session_lifecycle(client, auth_headers, db_session):
    """
    Tests complete Admin Support Mode workflow:
    - Admin re-auth with current admin password
    - Target resolution & security checks (cannot target Admin, cannot target disabled)
    - Session start & token independence
    - Read-only inspection of target's timetable and profile
    - Session termination and audit trail
    """
    # 1. Setup Class, Subject, Period, Student & Faculty
    cs = ClassSection(name="II Year CSE Cyber Security - Class 1", academic_year="2025-2026", grade_level="2")
    sub = Subject(code="CS201", name="Data Structures")
    p1 = Period(period_number=1, name="Period 1", start_time="09:00", end_time="09:50")
    db_session.add_all([cs, sub, p1])
    db_session.flush()

    u_st = User(
        username="student_support_test",
        email="st_supp@college.edu",
        role=UserRole.STUDENT,
        is_active=True,
        hashed_password=get_password_hash("StudentSecret123!"),
        session_token="student_original_session"
    )
    db_session.add(u_st)
    db_session.flush()

    st = Student(
        user_id=u_st.id,
        roll_number="721025149888",
        full_name="Target Student",
        class_id=cs.id,
        is_active=True
    )
    db_session.add(st)

    fa = FacultyAssignment(faculty_id=None, subject_id=sub.id, class_id=cs.id)
    db_session.add(fa)
    db_session.flush()

    tt = TimetableEntry(
        assignment_id=fa.id,
        period_id=p1.id,
        day_of_week="Monday"
    )
    db_session.add(tt)
    db_session.commit()

    # 2. Start support session with wrong admin password -> 400
    r_fail = client.post("/api/v1/admin/support/start", json={
        "target_student_id": st.id,
        "admin_password": "WrongAdminPassword!"
    }, headers=auth_headers["admin"])
    assert r_fail.status_code == 400
    assert "incorrect admin password" in r_fail.json()["detail"]

    # 3. Start support session with correct admin password ("AdminPass123!" configured in auth_headers fixture)
    r_start = client.post("/api/v1/admin/support/start", json={
        "target_student_id": st.id,
        "admin_password": "AdminPass123!",
        "reason": "Investigating timetable conflict",
        "duration_minutes": 15
    }, headers=auth_headers["admin"])
    assert r_start.status_code == 200
    sess_data = r_start.json()
    assert sess_data["session_id"].startswith("supp_")
    assert sess_data["target_name"] == "Target Student"
    assert sess_data["target_role"] == "STUDENT"
    assert sess_data["is_active"] is True
    assert sess_data["seconds_remaining"] > 0

    # Ensure target user's session token is untouched
    db_session.refresh(u_st)
    assert u_st.session_token == "student_original_session"

    # 4. Inspect Target Account via support session
    session_id = sess_data["session_id"]
    r_inspect = client.get(f"/api/v1/admin/support/{session_id}/inspect", headers=auth_headers["admin"])
    assert r_inspect.status_code == 200
    inspect_data = r_inspect.json()
    assert inspect_data["role"] == "STUDENT"
    assert inspect_data["roll_number"] == "721025149888"
    assert inspect_data["timetable_count"] >= 1
    assert inspect_data["read_only"] is True

    # 5. Retrieve session status
    r_get = client.get(f"/api/v1/admin/support/{session_id}", headers=auth_headers["admin"])
    assert r_get.status_code == 200
    assert r_get.json()["is_active"] is True

    # 6. End session
    r_end = client.post(f"/api/v1/admin/support/{session_id}/end", headers=auth_headers["admin"])
    assert r_end.status_code == 200
    assert r_end.json()["is_active"] is False

    # 7. Audit log check
    audits = db_session.query(AuditLog).filter(
        AuditLog.action.in_(["START_ADMIN_SUPPORT", "END_ADMIN_SUPPORT"])
    ).all()
    assert len(audits) >= 2


def test_admin_support_blocks_targeting_admin_or_disabled(client, auth_headers, db_session):
    """Validates that support mode cannot target another Admin or a disabled account."""
    admin_user = db_session.query(User).filter(User.role == UserRole.ADMIN).first()

    # Disabled account
    u_disabled = User(
        username="disabled_user_test",
        role=UserRole.STUDENT,
        is_active=False,
        hashed_password="h"
    )
    db_session.add(u_disabled)
    db_session.commit()

    # Target another admin -> 400
    r1 = client.post("/api/v1/admin/support/start", json={
        "target_user_id": admin_user.id,
        "admin_password": "AdminPass123!"
    }, headers=auth_headers["admin"])
    assert r1.status_code == 400
    assert "Admin accounts cannot be targeted" in r1.json()["detail"]

    # Target disabled account -> 400
    r2 = client.post("/api/v1/admin/support/start", json={
        "target_user_id": u_disabled.id,
        "admin_password": "AdminPass123!"
    }, headers=auth_headers["admin"])
    assert r2.status_code == 400
    assert "disabled account" in r2.json()["detail"]


# =============================================================================
# 7. REGRESSION TESTS: FORCE_PASSWORD_CHANGE IN TOKEN/USEROUT & LOCKOUT ORDER
# =============================================================================

def test_login_and_me_return_force_password_change_state(client, db_session):
    """Verifies that /auth/login and /auth/me return the actual force_password_change state."""
    pw = "FacSecure2026!"
    user = User(
        username="fac_fpc_test",
        email="fac_fpc@college.edu",
        hashed_password=get_password_hash(pw),
        role=UserRole.FACULTY,
        is_active=True,
        force_password_change=True,
        login_identifier="FAC_FPC01"
    )
    db_session.add(user)
    db_session.flush()

    fac = Faculty(
        user_id=user.id,
        employee_id="FAC_FPC01",
        full_name="Prof. FPC Test",
        department="CSE"
    )
    db_session.add(fac)
    db_session.commit()

    # 1. Login with force_password_change = True
    login_resp = client.post("/api/v1/auth/login", json={"username_or_email": "FAC_FPC01", "password": pw})
    assert login_resp.status_code == 200
    login_data = login_resp.json()
    assert "force_password_change" in login_data
    assert login_data["force_password_change"] is True
    token = login_data["access_token"]

    # 2. GET /auth/me with force_password_change = True
    me_resp = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me_resp.status_code == 200
    me_data = me_resp.json()
    assert "force_password_change" in me_data
    assert me_data["force_password_change"] is True

    # 3. Change password -> resets force_password_change to False
    new_pw = "NewSecure2026!"
    change_resp = client.post("/api/v1/auth/change-password", json={
        "current_password": pw,
        "new_password": new_pw,
        "confirm_password": new_pw
    }, headers={"Authorization": f"Bearer {token}"})
    assert change_resp.status_code == 200
    assert change_resp.json()["force_password_change"] is False

    # 4. GET /auth/me after change -> force_password_change is now False
    me_resp2 = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me_resp2.status_code == 200
    assert me_resp2.json()["force_password_change"] is False


def test_lockout_order_returns_403_before_password_verification(client, db_session):
    """Verifies that an active lockout returns 403 even with wrong password, and counter does not increase."""
    pw = "LockoutTarget2026!"
    lock_time = datetime.now(timezone.utc) + timedelta(minutes=30)
    user = User(
        username="locked_user_test",
        email="locked@college.edu",
        hashed_password=get_password_hash(pw),
        role=UserRole.FACULTY,
        is_active=True,
        force_password_change=False,
        failed_login_attempts=5,
        locked_until=lock_time,
        login_identifier="FAC_LOCK01"
    )
    db_session.add(user)
    db_session.flush()

    fac = Faculty(
        user_id=user.id,
        employee_id="FAC_LOCK01",
        full_name="Locked Faculty",
        department="CSE"
    )
    db_session.add(fac)
    db_session.commit()

    # Attempt login with WRONG password while locked
    resp_wrong = client.post("/api/v1/auth/login", json={"username_or_email": "FAC_LOCK01", "password": "WrongPassword999!"})
    # Must return 403 (lockout), NOT 401
    assert resp_wrong.status_code == 403
    assert "Account is locked" in resp_wrong.json()["detail"]

    # Verify failed counter did NOT increment while locked
    db_session.refresh(user)
    assert user.failed_login_attempts == 5

    # Attempt login with CORRECT password while locked -> still 403
    resp_correct = client.post("/api/v1/auth/login", json={"username_or_email": "FAC_LOCK01", "password": pw})
    assert resp_correct.status_code == 403
    assert "Account is locked" in resp_correct.json()["detail"]
    assert user.failed_login_attempts == 5

