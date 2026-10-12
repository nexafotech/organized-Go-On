import io
import pytest
from datetime import datetime, timezone
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.main import app
from app.models.academic import TimetableEntry, FacultyAssignment, Period, ClassSection, Subject
from app.models.user import User, Faculty, UserRole
from app.models.student import Student
from app.models.attendance import ClassSession, AttendanceRecord, AttendanceStatus, SessionStatus
from app.models.audit import AuditLog
from app.engines.timetable_engine import _IST_OFFSET, get_ist_now
from app.engines.attendance_engine import (
    get_faculty_periods_for_date,
    get_class_advisor_periods_for_date,
    get_faculty_attendance_roster,
    submit_faculty_attendance,
    get_class_advisor_attendance_roster,
    submit_class_advisor_attendance,
)

def _make_ist_dt(year, month, day, hour=0, minute=0, second=0):
    return datetime(year, month, day, hour, minute, second, tzinfo=_IST_OFFSET)

@pytest.fixture(scope="module")
def db_session():
    db = SessionLocal()
    yield db
    db.close()

class TestPhase8RetrospectiveAttendance:
    def test_01_faculty_periods_for_past_date(self, db_session):
        """Past date matching weekday returns scheduled periods for faculty."""
        # Faculty 6 (Shankar) has Tuesday classes. 2026-09-22 was Tuesday.
        simulated_now = _make_ist_dt(2026, 9, 29, 14, 0)
        res = get_faculty_periods_for_date(db_session, faculty_id=6, date_str="2026-09-22", dt=simulated_now)
        assert res["date"] == "2026-09-22"
        assert res["day_of_week"] == "Tuesday"
        assert res["is_today"] is False
        assert len(res["periods"]) > 0
        for p in res["periods"]:
            assert p["can_mark"] is True
            assert p["status"] in ("AVAILABLE", "ALREADY_MARKED")

    def test_02_faculty_periods_for_future_date_rejected(self, db_session):
        """Future date is strictly rejected with 400 Bad Request."""
        simulated_now = _make_ist_dt(2026, 9, 29, 14, 0)
        with pytest.raises(HTTPException) as exc_info:
            get_faculty_periods_for_date(db_session, faculty_id=6, date_str="2026-10-05", dt=simulated_now)
        assert exc_info.value.status_code == 400
        assert "Cannot mark attendance for future dates" in exc_info.value.detail

    def test_03_class_advisor_periods_for_past_date(self, db_session):
        """Class Advisor can retrieve all periods of advised class for past dates."""
        # Find a faculty that is class advisor
        sec = db_session.query(ClassSection).filter(ClassSection.class_advisor_id.isnot(None)).first()
        assert sec is not None, "ClassSection with class_advisor_id must exist"
        advisor_id = sec.class_advisor_id

        simulated_now = _make_ist_dt(2026, 9, 29, 14, 0)
        res = get_class_advisor_periods_for_date(db_session, faculty_id=advisor_id, date_str="2026-09-22", dt=simulated_now)
        assert res["is_class_advisor"] is True
        assert res["advised_class"]["id"] == sec.id
        assert res["date"] == "2026-09-22"
        assert res["day_of_week"] == "Tuesday"
        assert "lunch_break" in res
        assert res["lunch_break"]["start_time"] == "12:50"
        assert res["lunch_break"]["end_time"] == "13:40"
        for p in res["periods"]:
            assert p["can_mark"] is True

    def test_04_class_advisor_future_date_rejected(self, db_session):
        """Class advisor querying future date is strictly rejected with 400."""
        sec = db_session.query(ClassSection).filter(ClassSection.class_advisor_id.isnot(None)).first()
        advisor_id = sec.class_advisor_id
        simulated_now = _make_ist_dt(2026, 9, 29, 14, 0)
        with pytest.raises(HTTPException) as exc_info:
            get_class_advisor_periods_for_date(db_session, faculty_id=advisor_id, date_str="2026-10-10", dt=simulated_now)
        assert exc_info.value.status_code == 400
        assert "Cannot mark attendance for future dates" in exc_info.value.detail

    def test_05_class_advisor_non_advisor_rejected(self, db_session):
        """Faculty who is not a class advisor is rejected with 403."""
        # Find faculty who is not advisor
        all_advisor_ids = {s.class_advisor_id for s in db_session.query(ClassSection).all() if s.class_advisor_id}
        non_advisor = db_session.query(Faculty).filter(~Faculty.id.in_(all_advisor_ids)).first()
        if non_advisor:
            simulated_now = _make_ist_dt(2026, 9, 29, 14, 0)
            with pytest.raises(HTTPException) as exc_info:
                get_class_advisor_periods_for_date(db_session, faculty_id=non_advisor.id, date_str="2026-09-22", dt=simulated_now)
            assert exc_info.value.status_code == 403

    def test_06_retrospective_attendance_submission_and_upsert(self, db_session):
        """Submit attendance for a past date; verify records and verify re-submission updates without duplicates."""
        simulated_now = _make_ist_dt(2026, 9, 29, 14, 0)
        # Shankar (ID 6) Tuesday TT entry
        entry = (
            db_session.query(TimetableEntry)
            .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
            .filter(FacultyAssignment.faculty_id == 6, TimetableEntry.day_of_week == "Tuesday")
            .first()
        )
        assert entry is not None

        # Clean any existing test session for 2026-09-15 (Tuesday, 2 weeks prior)
        past_date = "2026-09-15"
        old_sess = db_session.query(ClassSession).filter(ClassSession.timetable_entry_id == entry.id, ClassSession.date == past_date).first()
        if old_sess:
            db_session.query(AttendanceRecord).filter(AttendanceRecord.session_id == old_sess.id).delete()
            db_session.delete(old_sess)
            db_session.commit()

        # Load students
        class_id = entry.assignment.class_id
        students = db_session.query(Student).filter(Student.class_id == class_id, Student.is_active == True).all()
        assert len(students) > 0

        # Mark 3 present, rest absent
        records = []
        for i, st in enumerate(students):
            st_status = "PRESENT" if i < 3 else "ABSENT"
            records.append({"student_id": st.id, "status": st_status})

        sub_res = submit_faculty_attendance(
            db=db_session,
            faculty_id=6,
            user_id=1,
            timetable_entry_id=entry.id,
            date_str=past_date,
            records=records,
            dt=simulated_now
        )
        assert sub_res["records_count"] == len(students)
        session_id = sub_res["session_id"]

        # Verify roster now shows ALREADY_MARKED and matches submitted statuses
        roster_res = get_faculty_attendance_roster(
            db=db_session,
            faculty_id=6,
            timetable_entry_id=entry.id,
            date_str=past_date,
            dt=simulated_now
        )
        assert roster_res["already_marked"] is True
        present_in_roster = [r for r in roster_res["roster"] if r["attendance_status"] == "PRESENT"]
        assert len(present_in_roster) == 3

        # Re-submission (edit one to OD)
        records[0]["status"] = "OD"
        records[0]["od_reason"] = "Retrospective Symposium OD"
        sub_res2 = submit_faculty_attendance(
            db=db_session,
            faculty_id=6,
            user_id=1,
            timetable_entry_id=entry.id,
            date_str=past_date,
            records=records,
            dt=simulated_now
        )
        assert sub_res2["session_id"] == session_id  # Reused same session

        # Verify no duplicate records created in DB
        db_records_count = db_session.query(AttendanceRecord).filter(AttendanceRecord.session_id == session_id).count()
        assert db_records_count == len(students)

        # Cleanup test session
        db_session.query(AttendanceRecord).filter(AttendanceRecord.session_id == session_id).delete()
        db_session.query(ClassSession).filter(ClassSession.id == session_id).delete()
        db_session.commit()

class TestPhase8BatchPhotoRecognition:
    def test_01_future_date_rejected_in_batch(self, db_session):
        """Batch recognition endpoint rejects future dates with 400."""
        # Use TestClient with authenticated faculty headers
        client = TestClient(app)
        # Login faculty (Shankar)
        login_res = client.post("/api/v1/auth/login", json={"identifier": "fac06", "password": "Password@123"})
        if login_res.status_code == 200:
            token = login_res.json()["token"]
            headers = {"Authorization": f"Bearer {token}"}
            data = {"timetable_entry_id": 160, "date": "2029-01-01"}
            files = [("files", ("test.jpg", b"fakebytes", "image/jpeg"))]
            res = client.post("/api/v1/faculty/attendance/batch-recognize", data=data, files=files, headers=headers)
            assert res.status_code == 400
            assert "Cannot process recognition for future dates" in res.json()["detail"]

    def test_02_day_mismatch_rejected_in_batch(self, db_session):
        """Batch recognition endpoint rejects day of week mismatch."""
        client = TestClient(app)
        login_res = client.post("/api/v1/auth/login", json={"identifier": "fac06", "password": "Password@123"})
        if login_res.status_code == 200:
            token = login_res.json()["token"]
            headers = {"Authorization": f"Bearer {token}"}
            # TT 160 is Tuesday. 2026-09-21 is Monday.
            data = {"timetable_entry_id": 160, "date": "2026-09-21"}
            files = [("files", ("test.jpg", b"fakebytes", "image/jpeg"))]
            res = client.post("/api/v1/faculty/attendance/batch-recognize", data=data, files=files, headers=headers)
            assert res.status_code == 400
            assert "does not match date" in res.json()["detail"]

    def test_03_empty_files_rejected(self, db_session):
        """Empty batch is rejected."""
        client = TestClient(app)
        login_res = client.post("/api/v1/auth/login", json={"identifier": "fac06", "password": "Password@123"})
        if login_res.status_code == 200:
            token = login_res.json()["token"]
            headers = {"Authorization": f"Bearer {token}"}
            data = {"timetable_entry_id": 160, "date": "2026-09-22"}
            res = client.post("/api/v1/faculty/attendance/batch-recognize", data=data, files=[], headers=headers)
            assert res.status_code in (400, 422)

    def test_04_batch_recognition_partial_failure_tolerance(self, db_session):
        """Batch recognition processes valid images and handles partial errors gracefully."""
        client = TestClient(app)
        login_res = client.post("/api/v1/auth/login", json={"identifier": "fac06", "password": "Password@123"})
        if login_res.status_code == 200:
            token = login_res.json()["token"]
            headers = {"Authorization": f"Bearer {token}"}
            # TT 160 is Tuesday. 2026-09-22 is Tuesday.
            data = {"timetable_entry_id": 160, "date": "2026-09-22"}
            # Send 2 images: one 0-byte file (fails gracefully), one 1x1 jpeg (0 faces detected, status NO_FACES)
            # Minimal 1x1 black JPEG
            tiny_jpeg = b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.\' ",#\x1c\x1c(7),01444\x1f\'9=82<.342\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\xff\xda\x00\x08\x01\x01\x00\x00?\x00\xbf\x00\xff\xd9'

            files = [
                ("files", ("bad_empty.jpg", b"", "image/jpeg")),
                ("files", ("classroom_angle1.jpg", tiny_jpeg, "image/jpeg")),
            ]
            res = client.post("/api/v1/faculty/attendance/batch-recognize", data=data, files=files, headers=headers)
            assert res.status_code == 200
            body = res.json()
            assert body["total_photos"] == 2
            assert body["photos_failed"] == 1
            assert body["photos_processed"] == 1
            assert len(body["photo_summaries"]) == 2
            assert body["photo_summaries"][0]["status"] == "ERROR"
            assert body["photo_summaries"][1]["status"] == "NO_FACES"
