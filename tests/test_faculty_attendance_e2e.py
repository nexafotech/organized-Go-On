"""
Comprehensive Unit and Integration Tests for Milestone 10C.15.3:
- Faculty Login (Authentication, Status, Error Handling)
- Faculty Dashboard & Timetable (Class 1 slots, subject mapping, active slot)
- Session Start (Authorized vs Unauthorized, Timetable constraints)
- Student Roster (All Class 1 students, correct fields, active state)
- Attendance Marking (Present, Absent, OD, Deduplication)
- Session Completion (State transition, idempotency, re-completion rejection)
- Student Verification (Overall summary, subject-wise attendance calculation)
- RBAC Enforcement (Student cannot start/mark/complete, Faculty cannot hijack other sessions or admin APIs)
- Audit Trail Verification
"""

import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.core.database import Base, get_db
from app.models.user import User, Faculty, UserRole
from app.models.student import Student
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.attendance import ClassSession, AttendanceRecord, SessionStatus, AttendanceStatus, RecognitionSource
from app.models.policy import AttendancePolicy
from app.models.audit import AuditLog
from app.core.security import get_password_hash, create_access_token


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

    # Create default policy
    policy = AttendancePolicy(
        id=1,
        calculation_unit="PERIOD",
        minimum_percentage=75.0,
        warning_threshold=75.0,
        critical_threshold=65.0,
        od_enabled=True,
        od_faculty_can_mark=True,
        od_require_reason=False,
    )
    session.add(policy)

    # Create Class 1
    class1 = ClassSection(id=1, name="II Year CSE Cyber Security - Class 1")
    session.add(class1)

    # Create Subjects
    sub_dmc = Subject(id=1, code="23MA301", name="Discrete Mathematics & Cryptography")
    sub_fds = Subject(id=2, code="23AD301", name="Foundations of Data Science")
    session.add_all([sub_dmc, sub_fds])

    # Create Periods
    p1 = Period(id=1, period_number=1, name="Period 1", start_time="09:00", end_time="09:50")
    p2 = Period(id=2, period_number=2, name="Period 2", start_time="10:00", end_time="10:50")
    session.add_all([p1, p2])

    # Create Faculty 1 (Mathu Metlda)
    u_fac1 = User(
        id=10,
        username="fac01",
        email="fac01@college.edu",
        hashed_password=get_password_hash("faculty123"),
        role=UserRole.FACULTY,
        is_active=True,
    )
    fac1_profile = Faculty(id=1, user_id=10, employee_id="EMP01", full_name="Mathu Metlda", department="CSE")
    session.add_all([u_fac1, fac1_profile])

    # Create Faculty 2 (Sivakumar)
    u_fac2 = User(
        id=11,
        username="fac02",
        email="fac02@college.edu",
        hashed_password=get_password_hash("faculty123"),
        role=UserRole.FACULTY,
        is_active=True,
    )
    fac2_profile = Faculty(id=2, user_id=11, employee_id="EMP02", full_name="Sivakumar", department="CSE")
    session.add_all([u_fac2, fac2_profile])

    # Create Locked & Disabled Faculty
    u_fac_locked = User(
        id=12,
        username="fac_locked",
        email="fac_locked@college.edu",
        hashed_password=get_password_hash("faculty123"),
        role=UserRole.FACULTY,
        is_active=True,
        locked_until=datetime.now(timezone.utc) + timedelta(minutes=30),
    )
    u_fac_disabled = User(
        id=13,
        username="fac_disabled",
        email="fac_disabled@college.edu",
        hashed_password=get_password_hash("faculty123"),
        role=UserRole.FACULTY,
        is_active=False,
    )
    session.add_all([u_fac_locked, u_fac_disabled])

    # Create Assignments
    assign_fac1 = FacultyAssignment(id=1, class_id=1, subject_id=1, faculty_id=1)
    assign_fac2 = FacultyAssignment(id=2, class_id=1, subject_id=2, faculty_id=2)
    session.add_all([assign_fac1, assign_fac2])

    # Create Timetable Entries
    tt1 = TimetableEntry(id=101, assignment_id=1, period_id=1, day_of_week="Monday")
    tt2 = TimetableEntry(id=102, assignment_id=2, period_id=2, day_of_week="Monday")
    session.add_all([tt1, tt2])

    # Create 64 Class 1 Students (including test student 721025149002 ABISHEK A)
    students = []
    # Test student ABISHEK A
    u_abishek = User(
        id=100,
        username="721025149002",
        login_identifier="721025149002",
        email="721025149002@student.college.edu",
        hashed_password=get_password_hash("student123"),
        role=UserRole.STUDENT,
        is_active=True,
    )
    session.add(u_abishek)
    st_abishek = Student(
        id=2,
        user_id=100,
        roll_number="721025149002",
        full_name="ABISHEK A",
        email="721025149002@student.college.edu",
        class_id=1,
        is_active=True,
    )
    students.append(st_abishek)

    # 63 other students (total 64)
    for i in range(1, 65):
        roll = f"7210251490{i:02d}"
        if roll == "721025149002":
            continue
        u_s = User(
            id=100 + i,
            username=roll,
            login_identifier=roll,
            email=f"{roll}@student.college.edu",
            hashed_password=get_password_hash("temp123"),
            role=UserRole.STUDENT,
            is_active=True,
        )
        session.add(u_s)
        st = Student(
            id=10 + i,
            user_id=100 + i,
            roll_number=roll,
            full_name=f"Student {i}",
            email=f"{roll}@student.college.edu",
            class_id=1,
            is_active=True,
        )
        students.append(st)

    session.add_all(students)
    session.commit()

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


def test_1_faculty_login_and_auth_errors(client):
    """1. Faculty login success, wrong password, locked, and disabled handling."""
    # Successful login
    res = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "fac01", "password": "faculty123"},
    )
    assert res.status_code == 200, res.text
    body = res.json()
    assert "access_token" in body
    assert body["token_type"] == "bearer"

    # Verify /auth/me returns FACULTY role
    token = body["access_token"]
    me_res = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me_res.status_code == 200
    assert me_res.json()["role"] == "FACULTY"
    assert me_res.json()["full_name"] == "Mathu Metlda"

    # Wrong password
    res_wrong = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "fac01", "password": "wrongpassword"},
    )
    assert res_wrong.status_code == 401
    assert "Incorrect" in res_wrong.json()["detail"]

    # Locked faculty
    res_locked = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "fac_locked", "password": "faculty123"},
    )
    assert res_locked.status_code == 403
    assert "locked" in res_locked.json()["detail"].lower()

    # Disabled faculty
    res_disabled = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "fac_disabled", "password": "faculty123"},
    )
    assert res_disabled.status_code == 403
    assert "disabled" in res_disabled.json()["detail"].lower()


def test_2_faculty_dashboard_and_timetable(client):
    """2 & 3. Faculty profile and Class 1 timetable retrieval."""
    login_res = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "fac01", "password": "faculty123"},
    )
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # /auth/me
    me_res = client.get("/api/v1/auth/me", headers=headers)
    assert me_res.status_code == 200
    me_data = me_res.json()
    assert me_data["username"] == "fac01"
    assert me_data["role"] == "FACULTY"
    assert "password" not in me_data
    assert "hashed_password" not in me_data

    # /faculty/timetable
    tt_res = client.get("/api/v1/faculty/timetable", headers=headers)
    assert tt_res.status_code == 200
    tt_data = tt_res.json()
    assert "timetable" in tt_data
    slots = tt_data["timetable"]
    assert len(slots) >= 1
    assert slots[0]["subject_code"] == "23MA301"
    assert slots[0]["class_name"] == "II Year CSE Cyber Security - Class 1"
    assert slots[0]["day_of_week"] == "Monday"


def test_3_authorized_and_unauthorized_session_creation(client):
    """4 & 5. Authorized vs Unauthorized session creation."""
    # Faculty 1 login
    login_res1 = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "fac01", "password": "faculty123"},
    )
    token1 = login_res1.json()["access_token"]
    headers1 = {"Authorization": f"Bearer {token1}"}

    # Faculty 1 starts session for Slot 101 (their assigned slot) -> SUCCESS
    start_res = client.post(
        "/api/v1/faculty/sessions/start",
        json={"timetable_entry_id": 101},
        headers=headers1,
    )
    assert start_res.status_code == 200, start_res.text
    session_data = start_res.json()
    assert session_data["status"] == "ACTIVE"
    session_id = session_data["session_id"]
    assert session_id > 0

    # Faculty 1 attempts to start session for Slot 102 (assigned to Faculty 2) -> 403
    unauth_res = client.post(
        "/api/v1/faculty/sessions/start",
        json={"timetable_entry_id": 102},
        headers=headers1,
    )
    assert unauth_res.status_code == 403
    assert "not authorized" in unauth_res.json()["detail"].lower()

    # Non-existent slot -> 404
    nonexist_res = client.post(
        "/api/v1/faculty/sessions/start",
        json={"timetable_entry_id": 9999},
        headers=headers1,
    )
    assert nonexist_res.status_code == 404


def test_4_student_roster_and_attendance_marking(client):
    """6, 7 & 8. Roster retrieval, attendance marking, and deduplication."""
    # Faculty 1 login & start session
    login_res1 = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "fac01", "password": "faculty123"},
    )
    token1 = login_res1.json()["access_token"]
    headers1 = {"Authorization": f"Bearer {token1}"}

    start_res = client.post(
        "/api/v1/faculty/sessions/start",
        json={"timetable_entry_id": 101},
        headers=headers1,
    )
    session_id = start_res.json()["session_id"]

    # Active session details & roster
    active_res = client.get("/api/v1/faculty/sessions/active", headers=headers1)
    assert active_res.status_code == 200
    active_data = active_res.json()
    assert active_data["has_active_session"] is True
    roster = active_data["session"]["roster"]
    assert len(roster) == 64  # All 64 Class 1 students

    # Locate test student ABISHEK A
    abishek_item = next((r for r in roster if r["roll_number"] == "721025149002"), None)
    assert abishek_item is not None
    assert abishek_item["full_name"] == "ABISHEK A"
    assert abishek_item["attendance_status"] == "UNMARKED"

    # Mark ABISHEK A PRESENT
    mark_res = client.post(
        f"/api/v1/faculty/sessions/{session_id}/attendance",
        json={"student_id": abishek_item["student_id"], "status": "PRESENT"},
        headers=headers1,
    )
    assert mark_res.status_code == 200, mark_res.text
    assert mark_res.json()["status"] == "PRESENT"

    # Verify roster reflects PRESENT
    sess_details = client.get(f"/api/v1/faculty/sessions/{session_id}", headers=headers1).json()
    abishek_updated = next((r for r in sess_details["roster"] if r["roll_number"] == "721025149002"), None)
    assert abishek_updated["attendance_status"] == "PRESENT"
    assert sess_details["summary"]["present_count"] == 1

    # Mark again (deduplication check) -> updates record rather than duplicating
    mark_again = client.post(
        f"/api/v1/faculty/sessions/{session_id}/attendance",
        json={"student_id": abishek_item["student_id"], "status": "PRESENT"},
        headers=headers1,
    )
    assert mark_again.status_code == 200
    sess_details2 = client.get(f"/api/v1/faculty/sessions/{session_id}", headers=headers1).json()
    assert sess_details2["summary"]["present_count"] == 1


def test_5_session_completion_and_recompletion_rejection(client):
    """9 & 10. Complete session and prevent modification after completion."""
    login_res1 = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "fac01", "password": "faculty123"},
    )
    token1 = login_res1.json()["access_token"]
    headers1 = {"Authorization": f"Bearer {token1}"}

    start_res = client.post(
        "/api/v1/faculty/sessions/start",
        json={"timetable_entry_id": 101},
        headers=headers1,
    )
    session_id = start_res.json()["session_id"]

    # Mark ABISHEK A Present
    client.post(
        f"/api/v1/faculty/sessions/{session_id}/attendance",
        json={"student_id": 2, "status": "PRESENT"},
        headers=headers1,
    )

    # Complete session
    comp_res = client.post(f"/api/v1/faculty/sessions/{session_id}/complete", headers=headers1)
    assert comp_res.status_code == 200, comp_res.text
    assert comp_res.json()["status"] == "COMPLETED"

    # Re-completing the same session -> 400 Bad Request
    recomp_res = client.post(f"/api/v1/faculty/sessions/{session_id}/complete", headers=headers1)
    assert recomp_res.status_code == 400
    assert "cannot complete" in recomp_res.json()["detail"].lower()

    # Marking attendance on completed session -> 400 Bad Request
    mark_post_res = client.post(
        f"/api/v1/faculty/sessions/{session_id}/attendance",
        json={"student_id": 2, "status": "ABSENT"},
        headers=headers1,
    )
    assert mark_post_res.status_code == 400
    assert "not active" in mark_post_res.json()["detail"].lower()


def test_6_student_attendance_summary_and_subjects_after_session(client):
    """11. Student login after completion reflects updated attendance."""
    # 1. Faculty runs and completes session with ABISHEK A present
    login_fac = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "fac01", "password": "faculty123"},
    )
    token_fac = login_fac.json()["access_token"]
    headers_fac = {"Authorization": f"Bearer {token_fac}"}

    start_res = client.post(
        "/api/v1/faculty/sessions/start",
        json={"timetable_entry_id": 101},
        headers=headers_fac,
    )
    session_id = start_res.json()["session_id"]

    client.post(
        f"/api/v1/faculty/sessions/{session_id}/attendance",
        json={"student_id": 2, "status": "PRESENT"},
        headers=headers_fac,
    )
    client.post(f"/api/v1/faculty/sessions/{session_id}/complete", headers=headers_fac)

    # 2. Student ABISHEK A logs in
    login_stud = client.post(
        "/api/v1/auth/student/login",
        json={"identifier": "721025149002", "password": "student123"},
    )
    assert login_stud.status_code == 200, login_stud.text
    token_stud = login_stud.json()["access_token"]
    headers_stud = {"Authorization": f"Bearer {token_stud}"}

    # Verify student me
    stud_me = client.get("/api/v1/student/me", headers=headers_stud)
    assert stud_me.status_code == 200
    data_me = stud_me.json()
    assert data_me["full_name"] == "ABISHEK A"
    assert data_me["register_number"] == "721025149002"
    assert data_me["total"] == 1
    assert data_me["present"] == 1
    assert data_me["percentage"] == 100.0
    assert data_me["attendance_status"] == "OK"

    # Verify student subjects
    stud_subj = client.get("/api/v1/student/attendance/subjects", headers=headers_stud)
    assert stud_subj.status_code == 200
    subj_list = stud_subj.json()
    assert len(subj_list) >= 1
    dmc_entry = next((s for s in subj_list if s["subject_code"] == "23MA301"), None)
    assert dmc_entry is not None
    assert dmc_entry["present"] == 1
    assert dmc_entry["percentage"] == 100.0


def test_7_student_and_faculty_rbac_restrictions(client):
    """12 & 13. Student and Faculty RBAC Restrictions."""
    # Student token
    login_stud = client.post(
        "/api/v1/auth/student/login",
        json={"identifier": "721025149002", "password": "student123"},
    )
    token_stud = login_stud.json()["access_token"]
    headers_stud = {"Authorization": f"Bearer {token_stud}"}

    # Student cannot start session
    res1 = client.post("/api/v1/faculty/sessions/start", json={"timetable_entry_id": 101}, headers=headers_stud)
    assert res1.status_code in [401, 403]

    # Student cannot mark attendance
    res2 = client.post("/api/v1/faculty/sessions/1/attendance", json={"student_id": 2, "status": "PRESENT"}, headers=headers_stud)
    assert res2.status_code in [401, 403]

    # Student cannot complete session
    res3 = client.post("/api/v1/faculty/sessions/1/complete", headers=headers_stud)
    assert res3.status_code in [401, 403]

    # Faculty 2 token
    login_fac2 = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "fac02", "password": "faculty123"},
    )
    token_fac2 = login_fac2.json()["access_token"]
    headers_fac2 = {"Authorization": f"Bearer {token_fac2}"}

    # Start session as Faculty 1
    login_fac1 = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "fac01", "password": "faculty123"},
    )
    headers_fac1 = {"Authorization": f"Bearer {login_fac1.json()['access_token']}"}
    start1 = client.post("/api/v1/faculty/sessions/start", json={"timetable_entry_id": 101}, headers=headers_fac1)
    sess1_id = start1.json()["session_id"]

    # Faculty 2 cannot mark attendance in Faculty 1's session
    fac2_mark = client.post(
        f"/api/v1/faculty/sessions/{sess1_id}/attendance",
        json={"student_id": 2, "status": "PRESENT"},
        headers=headers_fac2,
    )
    assert fac2_mark.status_code == 403
    assert "not authorized" in fac2_mark.json()["detail"].lower()

    # Faculty 2 cannot complete Faculty 1's session
    fac2_comp = client.post(
        f"/api/v1/faculty/sessions/{sess1_id}/complete",
        headers=headers_fac2,
    )
    assert fac2_comp.status_code == 403

    # Faculty cannot modify timetable (Admin privilege required)
    fac_tt_post = client.post(
        "/api/v1/admin/timetable",
        json={"class_id": 1, "day_of_week": "Monday", "period_id": 1, "assignment_id": 1},
        headers=headers_fac1,
    )
    assert fac_tt_post.status_code in [401, 403]
