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
from app.core.security import get_password_hash, create_access_token
from app.engines.timetable_engine import get_ist_now

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

    # Policy
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

    # Classes: Class 1 (advised by Faculty 1), Class 2 (no advisor)
    class1 = ClassSection(id=1, name="II Year CSE Cyber Security - Class 1", class_advisor_id=1)
    class2 = ClassSection(id=2, name="II Year CSE AI - Class 2", class_advisor_id=None)
    session.add_all([class1, class2])

    # Subjects
    sub1 = Subject(id=1, code="23CS301", name="Data Structures")
    sub2 = Subject(id=2, code="23CS302", name="Operating Systems")
    sub3 = Subject(id=3, code="23CS303", name="Database Systems")
    session.add_all([sub1, sub2, sub3])

    # Periods: P1 to P7
    periods = [
        Period(id=1, period_number=1, name="Period 1", start_time="09:10", end_time="10:00"),
        Period(id=2, period_number=2, name="Period 2", start_time="10:00", end_time="10:50"),
        Period(id=3, period_number=3, name="Period 3", start_time="11:10", end_time="12:00"),
        Period(id=4, period_number=4, name="Period 4", start_time="12:00", end_time="12:50"),
        Period(id=5, period_number=5, name="Period 5", start_time="13:40", end_time="14:30"),
        Period(id=6, period_number=6, name="Period 6", start_time="14:30", end_time="15:20"),
        Period(id=7, period_number=7, name="Period 7", start_time="15:20", end_time="16:10"),
    ]
    session.add_all(periods)

    # Faculty 1 (Advisor for Class 1, also teaches Sub 1 in Class 1)
    u_fac1 = User(
        id=10,
        username="fac01",
        email="fac01@college.edu",
        hashed_password=get_password_hash("faculty123"),
        role=UserRole.FACULTY,
        is_active=True,
    )
    fac1_profile = Faculty(id=1, user_id=10, employee_id="EMP01", full_name="Advisor Faculty", department="CSE")
    session.add_all([u_fac1, fac1_profile])

    # Faculty 2 (Only teaches Sub 2 in Class 1; NOT an advisor)
    u_fac2 = User(
        id=11,
        username="fac02",
        email="fac02@college.edu",
        hashed_password=get_password_hash("faculty123"),
        role=UserRole.FACULTY,
        is_active=True,
    )
    fac2_profile = Faculty(id=2, user_id=11, employee_id="EMP02", full_name="Regular Faculty", department="CSE")
    session.add_all([u_fac2, fac2_profile])

    # Admin User
    u_admin = User(
        id=99,
        username="admin",
        email="admin@college.edu",
        hashed_password=get_password_hash("admin123"),
        role=UserRole.ADMIN,
        is_active=True,
    )
    session.add(u_admin)

    # Assignments
    assign1 = FacultyAssignment(id=1, class_id=1, subject_id=1, faculty_id=1)
    assign2 = FacultyAssignment(id=2, class_id=1, subject_id=2, faculty_id=2)
    session.add_all([assign1, assign2])

    # Timetable entries
    tt1 = TimetableEntry(id=1, assignment_id=1, period_id=1, day_of_week="Monday")
    tt2 = TimetableEntry(id=2, assignment_id=2, period_id=2, day_of_week="Monday")
    session.add_all([tt1, tt2])

    # Student 1 in Class 1
    u_stu1 = User(
        id=20,
        username="stu01",
        email="stu01@college.edu",
        hashed_password=get_password_hash("student123"),
        role=UserRole.STUDENT,
        is_active=True,
    )
    stu1_profile = Student(
        id=1,
        user_id=20,
        roll_number="721025149001",
        full_name="Alice Student",
        class_id=1,
        is_active=True,
    )
    session.add_all([u_stu1, stu1_profile])

    # Student 2 in Class 1
    u_stu2 = User(
        id=21,
        username="stu02",
        email="stu02@college.edu",
        hashed_password=get_password_hash("student123"),
        role=UserRole.STUDENT,
        is_active=True,
    )
    stu2_profile = Student(
        id=2,
        user_id=21,
        roll_number="721025149002",
        full_name="Bob Student",
        class_id=1,
        is_active=True,
    )
    session.add_all([u_stu2, stu2_profile])

    # Sessions on 2026-09-28 (Monday)
    # Session 1: Period 1 (Sub 1, Faculty 1)
    s1 = ClassSession(
        id=1,
        timetable_entry_id=1,
        faculty_id=1,
        date="2026-09-28",
        status=SessionStatus.COMPLETED,
    )
    session.add(s1)

    # Records for Session 1: Stu 1 = PRESENT, Stu 2 = OD
    r1 = AttendanceRecord(
        session_id=1,
        student_id=1,
        status=AttendanceStatus.PRESENT,
        recognized_via=RecognitionSource.MANUAL,
    )
    r2 = AttendanceRecord(
        session_id=1,
        student_id=2,
        status=AttendanceStatus.OD,
        recognized_via=RecognitionSource.MANUAL,
        od_reason="Symposium",
    )
    session.add_all([r1, r2])

    # Session 2: Period 2 (Sub 2, Faculty 2)
    s2 = ClassSession(
        id=2,
        timetable_entry_id=2,
        faculty_id=2,
        date="2026-09-28",
        status=SessionStatus.COMPLETED,
    )
    session.add(s2)

    # Records for Session 2: Stu 1 = ABSENT, Stu 2 = PRESENT
    r3 = AttendanceRecord(
        session_id=2,
        student_id=1,
        status=AttendanceStatus.ABSENT,
        recognized_via=RecognitionSource.MANUAL,
    )
    r4 = AttendanceRecord(
        session_id=2,
        student_id=2,
        status=AttendanceStatus.PRESENT,
        recognized_via=RecognitionSource.MANUAL,
    )
    session.add_all([r3, r4])

    session.commit()
    yield session

    session.close()
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


# ─────────────────────────────────────────────────────────────
# 1. Student Report Tests
# ─────────────────────────────────────────────────────────────

def test_student_attendance_report(client, db_session):
    # Log in as Student 1 (user_id 20)
    token = create_access_token(subject=20, role="STUDENT")
    headers = {"Authorization": f"Bearer {token}"}

    res = client.get("/api/v1/student/attendance", headers=headers)
    assert res.status_code == 200
    data = res.json()

    assert data["student_id"] == 1
    assert data["full_name"] == "Alice Student"
    assert data["total"] == 2
    assert data["present"] == 1
    assert data["absent"] == 1
    assert data["od"] == 0
    assert data["percentage"] == 50.0

    # Date-wise verification
    assert "date_wise" in data
    assert len(data["date_wise"]) >= 1
    d_entry = data["date_wise"][0]
    assert d_entry["date"] == "2026-09-28"
    assert "lunch_interval" in d_entry
    assert "Not Counted" in d_entry["lunch_interval"]
    assert "morning_summary" in d_entry
    assert "afternoon_summary" in d_entry


def test_student_od_counted_as_present(client, db_session):
    # Log in as Student 2 (user_id 21, who had OD in P1, PRESENT in P2)
    token = create_access_token(subject=21, role="STUDENT")
    headers = {"Authorization": f"Bearer {token}"}

    res = client.get("/api/v1/student/attendance", headers=headers)
    assert res.status_code == 200
    data = res.json()

    assert data["student_id"] == 2
    assert data["total"] == 2
    assert data["present"] == 2  # 1 PRESENT + 1 OD
    assert data["od"] == 1
    assert data["percentage"] == 100.0


def test_student_cannot_access_faculty_reports(client, db_session):
    token = create_access_token(subject=20, role="STUDENT")
    headers = {"Authorization": f"Bearer {token}"}

    res = client.get("/api/v1/faculty/reports/class-summary?class_id=1", headers=headers)
    assert res.status_code == 403


# ─────────────────────────────────────────────────────────────
# 2. Faculty Report Authorization Tests
# ─────────────────────────────────────────────────────────────

def test_faculty_authorized_report_options_advisor_vs_regular(client, db_session):
    # Advisor (fac01, user_id 10)
    tok1 = create_access_token(subject=10, role="FACULTY")
    res1 = client.get("/api/v1/faculty/reports/authorized-options", headers={"Authorization": f"Bearer {tok1}"})
    assert res1.status_code == 200
    d1 = res1.json()
    assert d1["is_class_advisor"] is True
    assert d1["advised_class"]["id"] == 1
    assert any(c["is_advisor_for_class"] for c in d1["classes"])
    assert d1["current_date"] is not None
    assert d1["attendance_start_date"] is not None

    # Regular faculty (fac02, user_id 11)
    tok2 = create_access_token(subject=11, role="FACULTY")
    res2 = client.get("/api/v1/faculty/reports/authorized-options", headers={"Authorization": f"Bearer {tok2}"})
    assert res2.status_code == 200
    d2 = res2.json()
    assert d2["is_class_advisor"] is False
    assert d2["advised_class"] is None
    # Regular faculty only has assigned subjects
    for c in d2["classes"]:
        assert c["is_advisor_for_class"] is False
        for s in c["subjects"]:
            assert s["id"] == 2  # Only Sub 2 (OS)


def test_normal_faculty_date_matrix_strictly_scoped(client, db_session):
    """
    Scenario 1: Normal Faculty -> Class-wide matrix query.
    Verify that unrelated subjects (Sub 1 / Period 1) are NEVER in response!
    Only Sub 2 / Period 2 taught by fac02 must be returned.
    """
    tok = create_access_token(subject=11, role="FACULTY")
    headers = {"Authorization": f"Bearer {tok}"}

    res = client.get("/api/v1/faculty/reports/date-matrix?class_id=1&date=2026-09-28", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["is_class_advisor_scope"] is False
    assert len(data["periods"]) == 1
    assert data["periods"][0]["period_number"] == 2
    assert data["periods"][0]["subject_code"] == "23CS302"
    # Ensure Period 1 is NOT in periods list
    assert not any(p["period_number"] == 1 for p in data["periods"])

    # Ensure students' period_statuses only contain period 2
    for st in data["students"]:
        assert 1 not in st["period_statuses"]
        assert "1" not in st["period_statuses"]
        assert 2 in st["period_statuses"] or "2" in st["period_statuses"]


def test_normal_faculty_unauthorized_subject_returns_403(client, db_session):
    """
    Scenario 2 & 3: Normal Faculty manipulating subject_id to query another faculty's subject.
    fac02 teaches Sub 2, attempting to access Sub 1 -> must return 403 Forbidden.
    """
    tok = create_access_token(subject=11, role="FACULTY")
    headers = {"Authorization": f"Bearer {tok}"}

    # In date-matrix
    res1 = client.get("/api/v1/faculty/reports/date-matrix?class_id=1&date=2026-09-28&subject_id=1", headers=headers)
    assert res1.status_code == 403

    # In class-summary
    res2 = client.get("/api/v1/faculty/reports/class-summary?class_id=1&subject_id=1", headers=headers)
    assert res2.status_code == 403

    # In historical-matrix
    res3 = client.get("/api/v1/faculty/reports/historical-matrix?class_id=1&subject_id=1", headers=headers)
    assert res3.status_code == 403


def test_normal_faculty_unauthorized_class_returns_403(client, db_session):
    """
    Scenario 4: Normal Faculty manipulating class_id to access another class.
    fac02 not assigned to Class 2 -> 403 Forbidden.
    """
    tok = create_access_token(subject=11, role="FACULTY")
    headers = {"Authorization": f"Bearer {tok}"}

    res1 = client.get("/api/v1/faculty/reports/date-matrix?class_id=2&date=2026-09-28", headers=headers)
    assert res1.status_code == 403

    res2 = client.get("/api/v1/faculty/reports/class-summary?class_id=2", headers=headers)
    assert res2.status_code == 403

    res3 = client.get("/api/v1/faculty/reports/historical-matrix?class_id=2", headers=headers)
    assert res3.status_code == 403


def test_class_advisor_assigned_class_has_full_p1_p7_scope(client, db_session):
    """
    Scenario 6: Class Advisor for Class 1 can see all scheduled periods (P1 and P2).
    """
    tok = create_access_token(subject=10, role="FACULTY")
    headers = {"Authorization": f"Bearer {tok}"}

    res = client.get("/api/v1/faculty/reports/date-matrix?class_id=1&date=2026-09-28", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["is_class_advisor_scope"] is True
    # Advisor receives all 7 institutional periods P1-P7
    assert len(data["periods"]) == 7
    period_nums = [p["period_number"] for p in data["periods"]]
    assert 1 in period_nums
    assert 2 in period_nums

    # Lunch break verification
    assert "lunch_break" in data
    assert data["lunch_break"]["is_attendance_period"] is False
    assert data["lunch_break"]["start_time"] == "12:50"
    assert data["lunch_break"]["end_time"] == "13:40"


def test_class_advisor_unassigned_class_returns_403(client, db_session):
    """
    Scenario 7: Class Advisor 1 attempting to access Class 2 (which they do not advise and do not teach).
    """
    tok = create_access_token(subject=10, role="FACULTY")
    headers = {"Authorization": f"Bearer {tok}"}

    res = client.get("/api/v1/faculty/reports/date-matrix?class_id=2&date=2026-09-28", headers=headers)
    assert res.status_code == 403


def test_admin_full_matrix_access(client, db_session):
    """
    Scenario 9: Admin can access any class matrix across the institution.
    """
    tok = create_access_token(subject=99, role="ADMIN")
    headers = {"Authorization": f"Bearer {tok}"}

    res1 = client.get("/api/v1/faculty/reports/date-matrix?class_id=1&date=2026-09-28", headers=headers)
    assert res1.status_code == 200
    assert res1.json()["is_class_advisor_scope"] is True

    res2 = client.get("/api/v1/faculty/reports/date-matrix?class_id=2&date=2026-09-28", headers=headers)
    assert res2.status_code == 200
    assert res2.json()["is_class_advisor_scope"] is True


def test_historical_matrix_valid_range_and_scoping(client, db_session):
    """
    Scenario 10: Historical Matrix covers start date to today.
    Advisor gets full P1-P7 periods. Normal faculty gets only their periods.
    Future dates return 400 Bad Request.
    """
    # 1. Advisor query
    tok1 = create_access_token(subject=10, role="FACULTY")
    today_str = get_ist_now().date().isoformat()
    res1 = client.get(
        f"/api/v1/faculty/reports/historical-matrix?class_id=1&start_date=2026-09-28&end_date={today_str}",
        headers={"Authorization": f"Bearer {tok1}"},
    )
    assert res1.status_code == 200
    d1 = res1.json()
    assert d1["is_class_advisor_scope"] is True
    assert d1["total_dates"] >= 1
    # Sept 28 entry has both P1 and P2
    sep28 = next(d for d in d1["dates"] if d["date"] == "2026-09-28")
    assert len(sep28["periods"]) == 7

    # 2. Normal faculty query (fac02)
    tok2 = create_access_token(subject=11, role="FACULTY")
    res2 = client.get(
        f"/api/v1/faculty/reports/historical-matrix?class_id=1&start_date=2026-09-28&end_date={today_str}",
        headers={"Authorization": f"Bearer {tok2}"},
    )
    assert res2.status_code == 200
    d2 = res2.json()
    assert d2["is_class_advisor_scope"] is False
    sep28_fac2 = next(d for d in d2["dates"] if d["date"] == "2026-09-28")
    assert len(sep28_fac2["periods"]) == 1
    assert sep28_fac2["periods"][0]["period_number"] == 2

    # 3. Future dates return 400
    res3 = client.get(
        "/api/v1/faculty/reports/historical-matrix?class_id=1&start_date=2026-09-28&end_date=2099-12-31",
        headers={"Authorization": f"Bearer {tok1}"},
    )
    assert res3.status_code == 400
    assert "future" in res3.json()["detail"].lower()

    # 4. Date matrix future date returns 400
    res4 = client.get(
        "/api/v1/faculty/reports/date-matrix?class_id=1&date=2099-12-31",
        headers={"Authorization": f"Bearer {tok1}"},
    )
    assert res4.status_code == 400
    assert "future" in res4.json()["detail"].lower()
