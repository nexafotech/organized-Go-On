import pytest
from datetime import datetime, date, timedelta
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.core.database import SessionLocal, Base, engine
from app.models.user import User, UserRole, Faculty
from app.models.academic import ClassSection, Subject, Period, TimetableEntry, FacultyAssignment
from app.models.student import Student
from app.models.attendance import AttendanceRecord, ClassSession, SessionStatus, AttendanceStatus
from app.models.policy import AttendancePolicy
from app.core.security import create_access_token


@pytest.fixture(scope="module")
def summary_test_client():
    client = TestClient(app)
    return client


@pytest.fixture(scope="module")
def setup_summary_test_db():
    db: Session = SessionLocal()

    # Ensure active policy exists with COUNT_AS_PRESENT
    policy = db.query(AttendancePolicy).filter(AttendancePolicy.is_active == True).first()
    if not policy:
        policy = AttendancePolicy(
            name="Default Test Policy",
            od_calculation_mode="COUNT_AS_PRESENT",
            exclude_no_class=True,
            exclude_suspended=True,
            unmarked_behavior="NOT_ENTERED",
            is_active=True
        )
        db.add(policy)
        db.commit()

    # Create distinct test faculty & user
    advisor_user = User(
        username="advisor_summary_user",
        email="advisor_summary@college.edu",
        hashed_password=create_access_token(subject=999, role="FACULTY"),  # Any valid string
        role=UserRole.FACULTY,
        is_active=True,
        session_token="valid_summary_token"
    )
    db.add(advisor_user)
    db.flush()

    advisor_faculty = Faculty(
        user_id=advisor_user.id,
        employee_id="FAC_SUMMARY_001",
        full_name="Dr. Summary Advisor",
        department="Computer Science"
    )
    db.add(advisor_faculty)
    db.flush()

    # Class 1: 64 students
    class_sec = ClassSection(
        name="CSE-Summary-64",
        grade_level="Year 2",
        academic_year="2026-2027",
        class_advisor_id=advisor_faculty.id
    )
    db.add(class_sec)
    db.flush()

    # Class 2: Empty class with no saved attendance
    empty_class = ClassSection(
        name="CSE-Summary-Empty",
        grade_level="Year 2",
        academic_year="2026-2027",
        class_advisor_id=advisor_faculty.id
    )
    db.add(empty_class)
    db.flush()

    # Create 64 distinct active students for class_sec
    students = []
    for i in range(1, 65):
        st = Student(
            roll_number=f"SUM64{i:03d}",
            full_name=f"Summary Student {i}",
            class_id=class_sec.id,
            is_active=True
        )
        db.add(st)
        students.append(st)
    db.flush()

    # Subjects
    sub1 = Subject(code="CS-101", name="Data Structures")
    sub2 = Subject(code="CS-102", name="Algorithms")
    db.add_all([sub1, sub2])
    db.flush()

    # Assignments
    asgn1 = FacultyAssignment(faculty_id=advisor_faculty.id, subject_id=sub1.id, class_id=class_sec.id)
    asgn2 = FacultyAssignment(faculty_id=advisor_faculty.id, subject_id=sub2.id, class_id=class_sec.id)
    db.add_all([asgn1, asgn2])
    db.flush()

    # Periods (P1 - P4)
    p1 = Period(period_number=101, name="Period S1", start_time="09:00", end_time="10:00")
    p2 = Period(period_number=102, name="Period S2", start_time="10:00", end_time="11:00")
    p3 = Period(period_number=103, name="Period S3", start_time="11:15", end_time="12:15")
    db.add_all([p1, p2, p3])
    db.flush()

    # Timetable entries: Monday P101 (Sub1), Monday P102 (Sub2), Wednesday P103 (Sub1)
    # Sunday has NO timetable entries
    tt1 = TimetableEntry(day_of_week="Monday", period_id=p1.id, assignment_id=asgn1.id)
    tt2 = TimetableEntry(day_of_week="Monday", period_id=p2.id, assignment_id=asgn2.id)
    tt3 = TimetableEntry(day_of_week="Wednesday", period_id=p3.id, assignment_id=asgn1.id)
    db.add_all([tt1, tt2, tt3])
    db.flush()

    # Create 3 Class Sessions:
    # Date 1 (Monday 2026-10-12): Period 101 (Sub1) and Period 102 (Sub2)
    sess1 = ClassSession(
        timetable_entry_id=tt1.id,
        faculty_id=advisor_faculty.id,
        date="2026-10-12",
        status=SessionStatus.COMPLETED
    )
    sess2 = ClassSession(
        timetable_entry_id=tt2.id,
        faculty_id=advisor_faculty.id,
        date="2026-10-12",
        status=SessionStatus.COMPLETED
    )
    # Date 2 (Wednesday 2026-10-14): Period 103 (Sub1)
    sess3 = ClassSession(
        timetable_entry_id=tt3.id,
        faculty_id=advisor_faculty.id,
        date="2026-10-14",
        status=SessionStatus.COMPLETED
    )
    # Date 3: Cancelled session (should be excluded)
    sess_cancelled = ClassSession(
        timetable_entry_id=tt1.id,
        faculty_id=advisor_faculty.id,
        date="2026-10-19",
        status=SessionStatus.CANCELLED
    )
    db.add_all([sess1, sess2, sess3, sess_cancelled])
    db.flush()

    # Populate attendance records across the 64 students:
    # Sess 1 (Monday P101, Sub1): All 64 students PRESENT
    for st in students:
        db.add(AttendanceRecord(session_id=sess1.id, student_id=st.id, status=AttendanceStatus.PRESENT))

    # Sess 2 (Monday P102, Sub2):
    # - Student 1 is ABSENT (demonstrates student marked Present in one period and Absent in another)
    # - Student 2 is OD (demonstrates OD record under current policy)
    # - Students 3..64 are PRESENT (62 students)
    db.add(AttendanceRecord(session_id=sess2.id, student_id=students[0].id, status=AttendanceStatus.ABSENT))
    db.add(AttendanceRecord(session_id=sess2.id, student_id=students[1].id, status=AttendanceStatus.OD, od_reason="Sports"))
    for st in students[2:]:
        db.add(AttendanceRecord(session_id=sess2.id, student_id=st.id, status=AttendanceStatus.PRESENT))

    # Sess 3 (Wednesday P103, Sub1): All 64 students ABSENT
    for st in students:
        db.add(AttendanceRecord(session_id=sess3.id, student_id=st.id, status=AttendanceStatus.ABSENT))

    db.commit()

    token = create_access_token(subject=advisor_user.id, role="FACULTY")

    yield {
        "db": db,
        "token": token,
        "advisor_user": advisor_user,
        "class_id": class_sec.id,
        "empty_class_id": empty_class.id,
        "sub1_id": sub1.id,
        "sub2_id": sub2.id,
        "student1_id": students[0].id,
        "student2_id": students[1].id,
    }

    # Cleanup test records
    db.close()


def test_1_class_with_64_distinct_students_and_multiple_scheduled_periods(summary_test_client, setup_summary_test_db):
    data = setup_summary_test_db
    token = data["token"]
    class_id = data["class_id"]

    res = summary_test_client.get(
        f"/api/v1/faculty/reports/class-summary?class_id={class_id}",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res.status_code == 200
    body = res.json()

    # Rule 1: Exactly 64 distinct students
    assert body["total_students"] == 64
    assert len(body["students"]) == 64

    # Rule 2: Scheduled periods = 3 (cancelled session excluded)
    assert body["total_periods"] == 3

    # Rule 3: Total marks = 64 students * 3 periods = 192 marks
    assert body["total_marks"] == 192

    # Sess 1: 64 Present
    # Sess 2: 62 Present + 1 OD + 1 Absent
    # Sess 3: 64 Absent
    # Pure Present = 64 + 62 = 126
    # OD = 1
    # Effective Present (COUNT_AS_PRESENT) = 126 + 1 = 127
    # Absent = 1 + 64 = 65
    assert body["pure_present"] == 126
    assert body["od"] == 1
    assert body["absent"] == 65
    assert body["present"] == 127

    # Distinct check: pure_present + absent + od == total_marks
    assert body["pure_present"] + body["absent"] + body["od"] == body["total_marks"]

    # Percentage: (127 / 192) * 100 = 66.15%
    expected_pct = round((127 / 192) * 100, 2)
    assert body["percentage"] == expected_pct


def test_2_several_students_with_different_statuses_across_different_periods(summary_test_client, setup_summary_test_db):
    data = setup_summary_test_db
    token = data["token"]
    class_id = data["class_id"]

    res = summary_test_client.get(
        f"/api/v1/faculty/reports/class-summary?class_id={class_id}",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res.status_code == 200
    body = res.json()

    student_rows = {s["roll_number"]: s for s in body["students"]}
    st1 = student_rows["SUM64001"]
    st2 = student_rows["SUM64002"]
    st3 = student_rows["SUM64003"]

    # Student 1: Sess1(P), Sess2(A), Sess3(A) -> Pure Present: 1, Absent: 2, OD: 0, Total: 3
    assert st1["pure_present"] == 1
    assert st1["absent"] == 2
    assert st1["od"] == 0
    assert st1["total"] == 3
    assert st1["percentage"] == round((1 / 3) * 100, 2)

    # Student 2: Sess1(P), Sess2(OD), Sess3(A) -> Pure Present: 1, Absent: 1, OD: 1, Total: 3
    # Effective present = 2
    assert st2["pure_present"] == 1
    assert st2["absent"] == 1
    assert st2["od"] == 1
    assert st2["present"] == 2
    assert st2["total"] == 3
    assert st2["percentage"] == round((2 / 3) * 100, 2)

    # Student 3: Sess1(P), Sess2(P), Sess3(A) -> Pure Present: 2, Absent: 1, OD: 0, Total: 3
    assert st3["pure_present"] == 2
    assert st3["absent"] == 1
    assert st3["od"] == 0
    assert st3["total"] == 3
    assert st3["percentage"] == round((2 / 3) * 100, 2)


def test_3_student_marked_present_in_one_period_and_absent_in_another(summary_test_client, setup_summary_test_db):
    data = setup_summary_test_db
    token = data["token"]
    class_id = data["class_id"]

    res = summary_test_client.get(
        f"/api/v1/faculty/reports/class-summary?class_id={class_id}&start_date=2026-10-12&end_date=2026-10-12",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res.status_code == 200
    body = res.json()

    st1 = next(s for s in body["students"] if s["roll_number"] == "SUM64001")
    # On 2026-10-12 (2 periods): Student 1 had 1 Present (P101) and 1 Absent (P102)
    assert st1["pure_present"] == 1
    assert st1["absent"] == 1
    assert st1["total"] == 2
    assert st1["percentage"] == 50.0


def test_4_od_records_under_current_attendance_policy(summary_test_client, setup_summary_test_db):
    data = setup_summary_test_db
    token = data["token"]
    class_id = data["class_id"]

    res = summary_test_client.get(
        f"/api/v1/faculty/reports/class-summary?class_id={class_id}",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res.status_code == 200
    body = res.json()

    # Under COUNT_AS_PRESENT:
    # 1 OD record is preserved in 'od' and counted toward 'present' in percentage
    assert body["od"] == 1
    assert body["pure_present"] == 126
    assert body["present"] == 127
    assert body["pure_present"] + body["od"] == body["present"]


def test_5_missing_or_cancelled_session_excluded_from_periods(summary_test_client, setup_summary_test_db):
    data = setup_summary_test_db
    token = data["token"]
    class_id = data["class_id"]

    # On 2026-10-19 there is a CANCELLED session
    res = summary_test_client.get(
        f"/api/v1/faculty/reports/class-summary?class_id={class_id}&start_date=2026-10-19&end_date=2026-10-19",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res.status_code == 200
    body = res.json()

    # Cancelled session must not be counted in total_periods
    assert body["total_periods"] == 0
    assert body["total_marks"] == 0
    assert body["present"] == 0
    assert body["absent"] == 0


def test_6_deduplication_guards_against_cartesian_join_multiplication(summary_test_client, setup_summary_test_db):
    data = setup_summary_test_db
    token = data["token"]
    class_id = data["class_id"]

    res = summary_test_client.get(
        f"/api/v1/faculty/reports/class-summary?class_id={class_id}",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res.status_code == 200
    body = res.json()

    # Exactly 64 student rows, no duplicates
    student_ids = [s["student_id"] for s in body["students"]]
    assert len(student_ids) == 64
    assert len(set(student_ids)) == 64


def test_7_class_with_no_saved_attendance(summary_test_client, setup_summary_test_db):
    data = setup_summary_test_db
    token = data["token"]
    empty_class_id = data["empty_class_id"]

    res = summary_test_client.get(
        f"/api/v1/faculty/reports/class-summary?class_id={empty_class_id}",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res.status_code == 200
    body = res.json()

    assert body["total_periods"] == 0
    assert body["total_marks"] == 0
    assert body["present"] == 0
    assert body["pure_present"] == 0
    assert body["absent"] == 0
    assert body["od"] == 0
    assert body["percentage"] == 0.0


def test_8_sunday_with_no_scheduled_classes(summary_test_client, setup_summary_test_db):
    data = setup_summary_test_db
    token = data["token"]
    class_id = data["class_id"]

    # 2026-10-18 was a Sunday
    res = summary_test_client.get(
        f"/api/v1/faculty/reports/class-summary?class_id={class_id}&start_date=2026-10-18&end_date=2026-10-18",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res.status_code == 200
    body = res.json()

    assert body["is_sunday"] is True
    assert body["has_scheduled_classes"] is False
    assert body["total_periods"] == 0
    assert "No Classes" in body["no_class_message"]
    assert "Sunday" in body["no_class_message"]


def test_9_historical_date_query_matches_exact_day_records(summary_test_client, setup_summary_test_db):
    data = setup_summary_test_db
    token = data["token"]
    class_id = data["class_id"]

    # Historical date: Wednesday 2026-10-14 (1 session: all 64 absent)
    res = summary_test_client.get(
        f"/api/v1/faculty/reports/class-summary?class_id={class_id}&start_date=2026-10-14&end_date=2026-10-14",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res.status_code == 200
    body = res.json()

    assert body["total_periods"] == 1
    assert body["total_students"] == 64
    assert body["total_marks"] == 64
    assert body["present"] == 0
    assert body["absent"] == 64
    assert body["percentage"] == 0.0


def test_10_switching_between_subjects_and_date_ranges(summary_test_client, setup_summary_test_db):
    data = setup_summary_test_db
    token = data["token"]
    class_id = data["class_id"]
    sub1_id = data["sub1_id"]
    sub2_id = data["sub2_id"]

    # Filter Subject 1 only (Sess1 and Sess3) -> 2 periods
    res_sub1 = summary_test_client.get(
        f"/api/v1/faculty/reports/class-summary?class_id={class_id}&subject_id={sub1_id}",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res_sub1.status_code == 200
    body1 = res_sub1.json()
    assert body1["total_periods"] == 2
    assert body1["total_marks"] == 128
    assert body1["present"] == 64  # Sess1 only
    assert body1["absent"] == 64   # Sess3 only

    # Filter Subject 2 only (Sess2) -> 1 period
    res_sub2 = summary_test_client.get(
        f"/api/v1/faculty/reports/class-summary?class_id={class_id}&subject_id={sub2_id}",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res_sub2.status_code == 200
    body2 = res_sub2.json()
    assert body2["total_periods"] == 1
    assert body2["total_marks"] == 64
    assert body2["present"] == 63  # 62 P + 1 OD
    assert body2["absent"] == 1


def test_11_report_with_no_eligible_periods(summary_test_client, setup_summary_test_db):
    data = setup_summary_test_db
    token = data["token"]
    class_id = data["class_id"]

    # Date in 2024 with no sessions
    res = summary_test_client.get(
        f"/api/v1/faculty/reports/class-summary?class_id={class_id}&start_date=2024-01-01&end_date=2024-01-07",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res.status_code == 200
    body = res.json()

    assert body["total_periods"] == 0
    assert body["total_marks"] == 0
    assert body["present"] == 0
    assert body["percentage"] == 0.0


def test_12_attendance_percentage_bounds_and_zero_division_guard(summary_test_client, setup_summary_test_db):
    data = setup_summary_test_db
    token = data["token"]
    class_id = data["class_id"]

    res = summary_test_client.get(
        f"/api/v1/faculty/reports/class-summary?class_id={class_id}",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res.status_code == 200
    body = res.json()

    assert 0.0 <= body["percentage"] <= 100.0
    for s in body["students"]:
        assert 0.0 <= s["percentage"] <= 100.0
