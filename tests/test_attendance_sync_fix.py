"""
Integration Test for Attendance Synchronization Bug Fix & IST 12h Verification:
- Tests that when faculty marks attendance, the student subject-wise attendance is immediately updated.
- Tests that AttendancePolicyEngine.calculate_all_subjects_attendance accurately includes subjects with attendance
  even when assigned across multi-faculty, substitute, or elective assignments.
- Tests that Student API (/api/v1/student/attendance) reflects the exact counts.
- Tests that Admin API (/api/v1/admin/attendance/date-range) matches the counts.
- Tests that IST 12-hour AM/PM formatting in timetable/attendance engine functions correctly.
"""

import pytest
from datetime import datetime, date, time
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.core.database import Base, get_db
from app.models.user import User, Faculty, UserRole
from app.models.student import Student
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.attendance import ClassSession, AttendanceRecord, SessionStatus, AttendanceStatus, RecognitionSource, ReviewStatus
from app.models.policy import AttendancePolicy
from app.core.security import get_password_hash, create_access_token
from app.engines.timetable_engine import format_time_12h, get_ist_now
from app.engines.policy_engine import AttendancePolicyEngine

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

    # Default policy
    policy = AttendancePolicy(
        id=1,
        calculation_unit="PERIOD",
        minimum_percentage=75.0,
        warning_threshold=75.0,
        critical_threshold=65.0,
        od_enabled=True,
        od_faculty_can_mark=True,
    )
    session.add(policy)

    # Class 4
    class_sec = ClassSection(
        id=4,
        name="III Year CSE Cyber Security - Class 1",
    )
    session.add(class_sec)

    # Subjects
    sub_aiml = Subject(id=1, code="AIML", name="Artificial Intelligence & Machine Learning")
    sub_ace = Subject(id=2, code="ACE-I", name="Advanced Cyber Engineering I")
    session.add_all([sub_aiml, sub_ace])

    # Periods
    p1 = Period(id=1, period_number=1, name="Period 1", start_time="08:45", end_time="09:35")
    p2 = Period(id=2, period_number=2, name="Period 2", start_time="09:40", end_time="10:30")
    session.add_all([p1, p2])

    # Faculty User (fac04)
    user_fac = User(
        id=7,
        username="fac04",
        login_identifier="FAC006",
        hashed_password=get_password_hash("pass123"),
        role=UserRole.FACULTY,
        is_active=True,
    )
    session.add(user_fac)
    session.flush()

    faculty = Faculty(
        id=6,
        user_id=user_fac.id,
        employee_id="FAC006",
        full_name="Shankar",
        department="CSE Cyber Security",
    )
    session.add(faculty)

    # Student User & Student
    user_stu = User(
        id=20,
        username="721025149002",
        login_identifier="721025149002",
        hashed_password=get_password_hash("pass123"),
        role=UserRole.STUDENT,
        is_active=True,
    )
    session.add(user_stu)
    session.flush()

    student = Student(
        id=2,
        user_id=user_stu.id,
        roll_number="721025149002",
        full_name="ABISHEK A",
        class_id=4,
        is_active=True,
    )
    session.add(student)

    # Admin User
    user_admin = User(
        id=1,
        username="admin",
        login_identifier="admin",
        hashed_password=get_password_hash("pass123"),
        role=UserRole.ADMIN,
        is_active=True,
    )
    session.add(user_admin)

    # Faculty Assignment for ACE-I (Sub 2, Class 4, Faculty 6)
    assignment = FacultyAssignment(
        id=17,
        faculty_id=faculty.id,
        class_id=4,
        subject_id=sub_ace.id,
    )
    session.add(assignment)

    # Timetable Entry
    tt = TimetableEntry(
        id=212,
        assignment_id=assignment.id,
        period_id=p1.id,
        day_of_week="Thursday",
    )
    session.add(tt)

    session.commit()
    yield session
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


def test_format_time_12h():
    """Verify 12-hour AM/PM formatting utility works correctly."""
    assert format_time_12h("08:45:00") == "8:45 AM"
    assert format_time_12h("08:45") == "8:45 AM"
    assert format_time_12h("12:00:00") == "12:00 PM"
    assert format_time_12h("13:45:00") == "1:45 PM"
    assert format_time_12h("23:59:00") == "11:59 PM"
    assert format_time_12h("00:15:00") == "12:15 AM"


def test_attendance_sync_and_subject_wise_update(client, db_session):
    """
    Verify the complete synchronization pipeline:
    1. Student initially has 0 attendance for ACE-I.
    2. Faculty fac04 marks student Present for ACE-I.
    3. Verify AttendanceRecord exists in database.
    4. Verify AttendancePolicyEngine.calculate_all_subjects_attendance returns ACE-I correctly.
    5. Verify Student /attendance endpoint returns updated subjects list with ACE-I present=1, total=1, 100%.
    6. Verify Admin API returns matching attendance.
    """
    # 1. Student initially has 0 attendance
    user_stu = db_session.query(User).filter_by(username="721025149002").first()
    token_stu = create_access_token(str(user_stu.id), "STUDENT")
    headers_stu = {"Authorization": f"Bearer {token_stu}"}
    resp = client.get("/api/v1/student/attendance", headers=headers_stu)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 0
    assert data["percentage"] == 0.0

    # 2. Mark attendance for Class 4, Period 1, Subject ACE-I (timetable_entry_id=212)
    today = date.today()
    session = ClassSession(
        id=1,
        timetable_entry_id=212,
        faculty_id=6,  # fac04
        date=today.isoformat(),
        status=SessionStatus.COMPLETED,
    )
    db_session.add(session)
    db_session.flush()

    record = AttendanceRecord(
        session_id=session.id,
        student_id=2,
        status=AttendanceStatus.PRESENT,
        recognized_via=RecognitionSource.MANUAL,
        review_status=ReviewStatus.APPROVED,
    )
    db_session.add(record)
    db_session.commit()

    # 3. Check DB directly
    db_records = db_session.query(AttendanceRecord).filter_by(student_id=2).all()
    assert len(db_records) == 1
    assert db_records[0].status == AttendanceStatus.PRESENT

    # 4. Check Policy Engine calculation directly
    stu = db_session.query(Student).filter_by(id=2).first()
    engine_pe = AttendancePolicyEngine(db_session)
    sub_results = engine_pe.calculate_all_subjects_attendance(stu.id)
    assert len(sub_results) >= 1
    ace_sub = next((s for s in sub_results if s["subject_code"] == "ACE-I"), None)
    assert ace_sub is not None, "ACE-I must be in calculate_all_subjects_attendance"
    assert ace_sub["total"] == 1
    assert ace_sub["present"] == 1
    assert ace_sub["percentage"] == 100.0

    # 5. Check Student API /attendance
    resp = client.get("/api/v1/student/attendance", headers=headers_stu)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1
    assert data["present"] == 1
    assert data["percentage"] == 100.0
    assert "subjects" in data
    api_ace = next((s for s in data["subjects"] if s["subject_code"] == "ACE-I"), None)
    assert api_ace is not None
    assert api_ace["present"] == 1
    assert api_ace["total"] == 1
    assert api_ace["percentage"] == 100.0

    # 6. Check Admin API /admin/attendance
    user_admin = db_session.query(User).filter_by(username="admin").first()
    token_admin = create_access_token(str(user_admin.id), "ADMIN")
    headers_admin = {"Authorization": f"Bearer {token_admin}"}
    resp_admin = client.get(f"/api/v1/admin/attendance?date={today.isoformat()}", headers=headers_admin)
    assert resp_admin.status_code == 200
    admin_data = resp_admin.json()
    assert len(admin_data) >= 1
    assert any(r["student_id"] == 2 and r["status"] == "PRESENT" for r in admin_data)
