import io
import pytest
from datetime import datetime, date, timedelta
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import openpyxl

from app.main import app
from app.core.database import Base, get_db
from app.models.user import User, Faculty, UserRole
from app.models.student import Student
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.attendance import ClassSession, AttendanceRecord, SessionStatus, AttendanceStatus, RecognitionSource
from app.models.policy import AttendancePolicy
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

    # Active Policy (OD counted as present)
    policy = AttendancePolicy(
        id=1,
        calculation_unit="PERIOD",
        minimum_percentage=75.0,
        warning_threshold=75.0,
        critical_threshold=65.0,
        od_enabled=True,
        od_faculty_can_mark=True,
        od_require_reason=False,
        od_calculation_mode="COUNT_AS_PRESENT",
        is_active=True,
    )
    session.add(policy)

    # Class 1 (advised by Faculty 1), Class 2 (no advisor / different class)
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

    # Faculty 1 (Advisor for Class 1; teaches Sub 1 in Class 1)
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

    # Faculty 2 (Only teaches Sub 2 in Class 1; NOT advisor)
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

    # Students in Class 1: Alice, Bob, Charlie
    stu1 = Student(id=1, roll_number="721025149001", full_name="Alice Student", class_id=1, is_active=True)
    stu2 = Student(id=2, roll_number="721025149002", full_name="Bob Student", class_id=1, is_active=True)
    stu3 = Student(id=3, roll_number="721025149003", full_name="Charlie Student", class_id=1, is_active=True)
    session.add_all([stu1, stu2, stu3])

    # Attendance data on 2026-09-21 (Monday, 2 weeks ago)
    # Session 1: Period 1 (Sub 1, Faculty 1)
    # Alice: PRESENT, Bob: OD, Charlie: ABSENT
    s1 = ClassSession(id=1, timetable_entry_id=1, faculty_id=1, date="2026-09-21", status=SessionStatus.COMPLETED)
    session.add(s1)
    r1_1 = AttendanceRecord(session_id=1, student_id=1, status=AttendanceStatus.PRESENT, recognized_via=RecognitionSource.MANUAL)
    r1_2 = AttendanceRecord(session_id=1, student_id=2, status=AttendanceStatus.OD, recognized_via=RecognitionSource.MANUAL, od_reason="Symposium")
    r1_3 = AttendanceRecord(session_id=1, student_id=3, status=AttendanceStatus.ABSENT, recognized_via=RecognitionSource.MANUAL)
    session.add_all([r1_1, r1_2, r1_3])

    # Session 2: Period 2 (Sub 2, Faculty 2)
    # Alice: PRESENT, Bob: PRESENT, Charlie: NOT_ENTERED
    s2 = ClassSession(id=2, timetable_entry_id=2, faculty_id=2, date="2026-09-21", status=SessionStatus.COMPLETED)
    session.add(s2)
    r2_1 = AttendanceRecord(session_id=2, student_id=1, status=AttendanceStatus.PRESENT, recognized_via=RecognitionSource.MANUAL)
    r2_2 = AttendanceRecord(session_id=2, student_id=2, status=AttendanceStatus.PRESENT, recognized_via=RecognitionSource.MANUAL)
    r2_3 = AttendanceRecord(session_id=2, student_id=3, status=AttendanceStatus.NOT_ENTERED, recognized_via=RecognitionSource.MANUAL)
    session.add_all([r2_1, r2_2, r2_3])

    # Attendance data on 2026-09-28 (Monday, 1 week ago)
    # Session 3: Period 1 (Sub 1, Faculty 1)
    # Alice: ABSENT, Bob: PRESENT, Charlie: PRESENT
    s3 = ClassSession(id=3, timetable_entry_id=1, faculty_id=1, date="2026-09-28", status=SessionStatus.COMPLETED)
    session.add(s3)
    r3_1 = AttendanceRecord(session_id=3, student_id=1, status=AttendanceStatus.ABSENT, recognized_via=RecognitionSource.MANUAL)
    r3_2 = AttendanceRecord(session_id=3, student_id=2, status=AttendanceStatus.PRESENT, recognized_via=RecognitionSource.MANUAL)
    r3_3 = AttendanceRecord(session_id=3, student_id=3, status=AttendanceStatus.PRESENT, recognized_via=RecognitionSource.MANUAL)
    session.add_all([r3_1, r3_2, r3_3])

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


def _auth_header(user_id: int, role: str = "FACULTY") -> dict:
    token = create_access_token(subject=user_id, role=role)
    return {"Authorization": f"Bearer {token}"}


# ─────────────────────────────────────────────────────────────
# 23 Scenarios Test Suite
# ─────────────────────────────────────────────────────────────

class TestPhase9AttendanceExport:

    def test_01_valid_date_range_report_json(self, client):
        """1. Valid date-range report returns 200 and accurate structure."""
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(10),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["class_name"] == "II Year CSE Cyber Security - Class 1"
        assert data["from_date"] == "2026-09-21"
        assert data["to_date"] == "2026-09-28"
        assert data["has_records"] is True
        assert len(data["summary"]) == 3
        assert len(data["period_summary"]) >= 2

    def test_02_one_day_report(self, client):
        """2. Single-day report where from_date == to_date."""
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&from_date=2026-09-21&to_date=2026-09-21",
            headers=_auth_header(10),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["from_date"] == "2026-09-21"
        assert data["to_date"] == "2026-09-21"
        assert data["has_records"] is True
        # On 2026-09-21:
        # S1: Alice(P), Bob(OD), Charlie(A)
        # S2: Alice(P), Bob(P), Charlie(NOT_ENTERED)
        # Marked totals: Present=3, Absent=1, OD=1 => Total Marked = 5
        assert data["present"] == 3
        assert data["absent"] == 1
        assert data["od"] == 1
        assert data["total_marked"] == 5

    def test_03_multi_day_report(self, client):
        """3. Multi-day report spanning multiple dates."""
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&from_date=2026-09-20&to_date=2026-09-30",
            headers=_auth_header(10),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["has_records"] is True
        # Total sessions in range: S1 (3 marked), S2 (2 marked), S3 (3 marked) = 8 marked
        assert data["total_marked"] == 8

    def test_04_invalid_from_greater_than_to(self, client):
        """4. Invalid range where from_date > to_date rejects with 400."""
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&from_date=2026-09-28&to_date=2026-09-21",
            headers=_auth_header(10),
        )
        assert resp.status_code == 400
        assert "From date cannot be after To date" in resp.json()["detail"]

    def test_05_future_date_handling(self, client):
        """5. Future dates are strictly rejected with 400."""
        future_date = (date.today() + timedelta(days=10)).isoformat()
        resp = client.get(
            f"/api/v1/faculty/reports/range?class_id=1&from_date=2026-09-01&to_date={future_date}",
            headers=_auth_header(10),
        )
        assert resp.status_code == 400
        assert "To date cannot be in the future" in resp.json()["detail"]

    def test_06_no_record_range(self, client):
        """6. Range with zero attendance records."""
        # Range in 2026-08 where no sessions exist
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&from_date=2026-08-01&to_date=2026-08-05",
            headers=_auth_header(10),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["has_records"] is False
        assert data["total_marked"] == 0
        assert data["percentage"] is None

        # For PDF / Excel, empty range raises 404 NO_RECORDS_AVAILABLE
        pdf_resp = client.get(
            "/api/v1/faculty/reports/range/pdf?class_id=1&from_date=2026-08-01&to_date=2026-08-05",
            headers=_auth_header(10),
        )
        assert pdf_resp.status_code == 404
        assert "NO_RECORDS_AVAILABLE" in str(pdf_resp.json()["detail"])

        excel_resp = client.get(
            "/api/v1/faculty/reports/range/excel?class_id=1&from_date=2026-08-01&to_date=2026-08-05",
            headers=_auth_header(10),
        )
        assert excel_resp.status_code == 404
        assert "NO_RECORDS_AVAILABLE" in str(excel_resp.json()["detail"])

    def test_07_present_count_accurate(self, client):
        """7. Present count matches exact persisted count."""
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(10),
        )
        data = resp.json()
        # Alice: S1=P, S2=P, S3=A -> 2 P
        # Bob: S1=OD, S2=P, S3=P -> 2 P
        # Charlie: S1=A, S2=NOT_ENTERED, S3=P -> 1 P
        # Total P = 5
        assert data["present"] == 5
        alice = next(s for s in data["summary"] if s["roll_number"] == "721025149001")
        assert alice["present"] == 2

    def test_08_absent_count_accurate(self, client):
        """8. Absent count matches exact persisted count."""
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(10),
        )
        data = resp.json()
        # Alice: 1 A (in S3)
        # Bob: 0 A
        # Charlie: 1 A (in S1)
        # Total A = 2
        assert data["absent"] == 2
        charlie = next(s for s in data["summary"] if s["roll_number"] == "721025149003")
        assert charlie["absent"] == 1

    def test_09_od_count_accurate(self, client):
        """9. OD count is kept separate and accurate."""
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(10),
        )
        data = resp.json()
        # Bob has 1 OD (S1)
        assert data["od"] == 1
        bob = next(s for s in data["summary"] if s["roll_number"] == "721025149002")
        assert bob["od"] == 1

    def test_10_total_marked_accurate(self, client):
        """10. Total marked equals Present + Absent + OD."""
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(10),
        )
        data = resp.json()
        assert data["total_marked"] == data["present"] + data["absent"] + data["od"]
        assert data["total_marked"] == 8

    def test_11_attendance_percentage_follows_policy(self, client):
        """11. Attendance percentage follows active policy (COUNT_AS_PRESENT)."""
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(10),
        )
        data = resp.json()
        # Bob: Present=2, OD=1, Total=3. Under COUNT_AS_PRESENT: (2+1)/3 = 100.0%
        bob = next(s for s in data["summary"] if s["roll_number"] == "721025149002")
        assert bob["percentage"] == 100.0
        # Alice: Present=2, Absent=1, Total=3 -> 2/3 = 66.67%
        alice = next(s for s in data["summary"] if s["roll_number"] == "721025149001")
        assert alice["percentage"] == 66.67
        # Overall: Present=5, OD=1, Total=8 -> (5+1)/8 = 75.0%
        assert data["percentage"] == 75.0

    def test_12_single_subject_report(self, client):
        """12. Filter by single subject (e.g. Sub 1 Data Structures)."""
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&subject_id=1&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(10),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["subject_code"] == "23CS301"
        # Sub 1 had Session 1 (3 entries) and Session 3 (3 entries) = 6 marked
        assert data["total_marked"] == 6

    def test_13_all_subject_report_advisor(self, client):
        """13. Class Advisor scope includes all subjects when subject_id is omitted."""
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(10),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["subject_label"] == "All Subjects"
        assert data["subject_code"] is None
        assert data["total_marked"] == 8

    def test_14_faculty_authorization_subject_scope(self, client):
        """14. Regular faculty (fac02) can query their assigned subject."""
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&subject_id=2&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(11),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["subject_code"] == "23CS302"
        # S2 only: Alice=P, Bob=P, Charlie=NOT_ENTERED => total marked = 2
        assert data["total_marked"] == 2

    def test_15_class_advisor_authorization(self, client):
        """15. Class Advisor can query both all subjects and specific subjects."""
        # Query Sub 2 (which advisor does not teach personally, but is advisor of the class)
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&subject_id=2&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(10),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["subject_code"] == "23CS302"

    def test_16_unauthorized_class_rejected(self, client):
        """16. Requesting a class with no teaching assignment or advisor role returns 403."""
        # Faculty 2 has no assignment in Class 2
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=2&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(11),
        )
        assert resp.status_code == 403
        assert "Not authorized" in resp.json()["detail"]

    def test_17_unauthorized_subject_rejected(self, client):
        """17. Requesting a subject that the faculty does not teach returns 403."""
        # Faculty 2 teaches Sub 2, tries to request Sub 1 in Class 1
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&subject_id=1&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(11),
        )
        assert resp.status_code == 403
        assert "Not authorized" in resp.json()["detail"]

    def test_18_pdf_generation_validity(self, client):
        """18. PDF generation endpoint returns valid A4 PDF stream."""
        resp = client.get(
            "/api/v1/faculty/reports/range/pdf?class_id=1&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(10),
        )
        assert resp.status_code == 200
        assert resp.headers["Content-Type"] == "application/pdf"
        assert "attachment; filename=" in resp.headers["Content-Disposition"]
        assert resp.content.startswith(b"%PDF")
        assert len(resp.content) > 1000

    def test_19_excel_generation_validity(self, client):
        """19. Excel generation returns valid .xlsx with the 3 required sheets."""
        resp = client.get(
            "/api/v1/faculty/reports/range/excel?class_id=1&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(10),
        )
        assert resp.status_code == 200
        assert "spreadsheetml.sheet" in resp.headers["Content-Type"]
        assert "attachment; filename=" in resp.headers["Content-Disposition"]
        
        # Load workbook
        wb = openpyxl.load_workbook(io.BytesIO(resp.content))
        assert "Summary" in wb.sheetnames
        assert "Daily Attendance" in wb.sheetnames
        assert "Period Summary" in wb.sheetnames

        ws_sum = wb["Summary"]
        # Go-On brand block (rows 1-5), table header on row 7
        assert ws_sum.cell(row=1, column=2).value == "Go-On"
        assert ws_sum.cell(row=2, column=2).value == "Attendance Report"
        assert ws_sum.cell(row=3, column=1).value == "Class"
        assert ws_sum.cell(row=4, column=1).value == "Subject"
        assert ws_sum.cell(row=5, column=1).value == "Date Range"
        assert ws_sum.cell(row=5, column=2).value == "21-09-2026 to 28-09-2026"
        assert len(ws_sum._images) == 1   # the official logo badge
        assert ws_sum.cell(row=7, column=1).value == "Register Number"
        assert ws_sum.cell(row=7, column=2).value == "Student Name"
        assert ws_sum.cell(row=7, column=7).value == "Attendance %"
        # Other sheets keep their header on row 1 and carry no brand block
        assert wb["Daily Attendance"].cell(row=1, column=1).value == "Date"
        assert wb["Period Summary"].cell(row=1, column=1).value == "Date"

    def test_24_pdf_carries_go_on_logo_and_stays_small(self, client):
        """24. PDF embeds the official logo image (not oversized) and the Go-On title."""
        resp = client.get(
            "/api/v1/faculty/reports/range/pdf?class_id=1&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(10),
        )
        assert resp.status_code == 200
        assert b"/Subtype /Image" in resp.content
        assert b"Go-On Attendance Report" in resp.content
        assert len(resp.content) < 200_000   # 256px badge, not a full-res copy

    def test_20_pdf_and_excel_totals_match_backend_dataset(self, client):
        """20. Totals in Excel exactly match JSON preview totals."""
        json_resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(10),
        )
        json_data = json_resp.json()

        excel_resp = client.get(
            "/api/v1/faculty/reports/range/excel?class_id=1&from_date=2026-09-21&to_date=2026-09-28",
            headers=_auth_header(10),
        )
        wb = openpyxl.load_workbook(io.BytesIO(excel_resp.content))
        ws = wb["Summary"]

        # Rows 8 to 10 are students (3 students; header is row 7)
        row_map = {}
        for r in range(8, 11):
            roll = ws.cell(row=r, column=1).value
            p = ws.cell(row=r, column=3).value
            a = ws.cell(row=r, column=4).value
            od = ws.cell(row=r, column=5).value
            tot = ws.cell(row=r, column=6).value
            row_map[roll] = {"P": p, "A": a, "OD": od, "Total": tot}

        for st in json_data["summary"]:
            excel_st = row_map[st["roll_number"]]
            assert excel_st["P"] == st["present"]
            assert excel_st["A"] == st["absent"]
            assert excel_st["OD"] == st["od"]
            assert excel_st["Total"] == st["total_marked"]

    def test_21_missing_attendance_not_converted_to_absent(self, client):
        """21. Dates with no scheduled class / sessions are not fabricated as ABSENT."""
        # From 2026-09-21 to 2026-09-27: only Monday 2026-09-21 had classes.
        # Tuesday-Sunday had NO attendance records.
        # Ensure total marked remains exactly what was recorded on Monday (5 marked).
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&from_date=2026-09-21&to_date=2026-09-27",
            headers=_auth_header(10),
        )
        data = resp.json()
        assert data["total_marked"] == 5
        # Absent count must NOT be inflated with fake absences for Tue-Sun
        assert data["absent"] == 1

    def test_22_unmarked_not_converted_to_absent(self, client):
        """22. NOT_ENTERED records are not converted to ABSENT in report counts."""
        # In Session 2, Charlie has status NOT_ENTERED
        resp = client.get(
            "/api/v1/faculty/reports/range?class_id=1&subject_id=2&from_date=2026-09-21&to_date=2026-09-21",
            headers=_auth_header(10),
        )
        data = resp.json()
        charlie = next(s for s in data["summary"] if s["roll_number"] == "721025149003")
        # Charlie has 0 marked (not 1 absent!)
        assert charlie["absent"] == 0
        assert charlie["present"] == 0
        assert charlie["total_marked"] == 0
        assert charlie["percentage"] is None  # Not 0%!

    def test_23_large_date_range_query_avoids_n_plus_one(self, client, db_session):
        """23. Query count does not scale with number of students or sessions."""
        queries = []

        def before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
            queries.append(statement)

        event.listen(engine, "before_cursor_execute", before_cursor_execute)
        try:
            resp = client.get(
                "/api/v1/faculty/reports/range?class_id=1&from_date=2026-09-01&to_date=2026-09-30",
                headers=_auth_header(10),
            )
            assert resp.status_code == 200
            # Total database queries for building the range report should be small and bounded (<= 15 queries)
            assert len(queries) <= 15
        finally:
            event.remove(engine, "before_cursor_execute", before_cursor_execute)
