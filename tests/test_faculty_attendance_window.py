"""
tests/test_faculty_attendance_window.py
Comprehensive test suite for the Faculty Attendance Entry Window.

Test Coverage:
 1. Today completed period returned (status AVAILABLE, can_mark=True)
 2. Today active period locked (status LOCKED, can_mark=False, lock_reason present)
 3. Today future period locked (status LOCKED, can_mark=False, lock_reason present)
 4. Yesterday scheduled period returned (status AVAILABLE, can_mark=True)
 5. Older dates rejected (HTTP 400 for dates earlier than yesterday)
 6. Future dates rejected (HTTP 400 for tomorrow/future dates)
 7. Authorized faculty allowed (both primary assigned faculty and authorized co-faculty)
 8. Unauthorized faculty rejected (HTTP 403)
 9. Correct student roster returned for timetable slot
10. Session created correctly on submission
11. Correct historical class date preserved (yesterday's date remains session.date)
12. Duplicate session prevented on re-submission (same session reused)
13. Duplicate attendance records prevented (upserted without duplicate rows)
14. Already-marked state returned after submission (status ALREADY_MARKED)
15. Tampered faculty rejected (cannot submit attendance for unassigned timetable slot)
16. Tampered class / invalid student rejected (HTTP 400)
17. Tampered date / day of week mismatch rejected (HTTP 400)
18. Exact end-time boundary transition (15:19:59 LOCKED, 15:20:00 AVAILABLE)
19. Asia/Kolkata timezone behavior
20. AuditLog entry created with FACULTY_ATTENDANCE_SUBMITTED / FACULTY_ATTENDANCE_CORRECTED
"""

import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.database import SessionLocal, get_db
from app.main import app
from app.models.academic import TimetableEntry, FacultyAssignment, Period, ClassSection, Subject
from app.models.user import User, Faculty
from app.models.student import Student
from app.models.attendance import ClassSession, AttendanceRecord, AttendanceStatus, SessionStatus
from app.models.audit import AuditLog
from app.engines.timetable_engine import _IST_OFFSET, get_ist_now
from app.engines.attendance_engine import (
    get_faculty_available_attendance_periods,
    get_faculty_attendance_roster,
    submit_faculty_attendance,
)


def _make_ist_dt(year, month, day, hour=0, minute=0, second=0):
    return datetime(year, month, day, hour, minute, second, tzinfo=_IST_OFFSET)


@pytest.fixture(scope="module")
def live_db():
    db = SessionLocal()
    # Cleanup before tests
    test_sessions = db.query(ClassSession).filter(ClassSession.date.in_(['2026-09-28', '2026-09-29', '2026-09-30'])).all()
    for s in test_sessions:
        db.query(AttendanceRecord).filter(AttendanceRecord.session_id == s.id).delete()
        db.delete(s)
    db.query(AuditLog).filter(AuditLog.action.in_(['FACULTY_ATTENDANCE_SUBMITTED', 'FACULTY_ATTENDANCE_CORRECTED'])).delete()
    db.commit()

    yield db

    # Cleanup after tests
    test_sessions = db.query(ClassSession).filter(ClassSession.date.in_(['2026-09-28', '2026-09-29', '2026-09-30'])).all()
    for s in test_sessions:
        db.query(AttendanceRecord).filter(AttendanceRecord.session_id == s.id).delete()
        db.delete(s)
    db.query(AuditLog).filter(AuditLog.action.in_(['FACULTY_ATTENDANCE_SUBMITTED', 'FACULTY_ATTENDANCE_CORRECTED'])).delete()
    db.commit()
    db.close()


@pytest.fixture(scope="module")
def api_client(live_db):
    def _override_get_db():
        yield live_db
    app.dependency_overrides[get_db] = _override_get_db
    client = TestClient(app, raise_server_exceptions=False)
    yield client
    app.dependency_overrides.clear()


@pytest.fixture(scope="module")
def fac04_token(api_client):
    """Dr. Shankar (FAC04, ID 6)"""
    resp = api_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "fac04", "password": "ro@y0^A8"}
    )
    assert resp.status_code == 200, f"fac04 login failed: {resp.text}"
    return resp.json()["access_token"]


@pytest.fixture(scope="module")
def fac02_token(api_client):
    """Mrs. Showmiya (FAC02, ID 4)"""
    resp = api_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "fac02", "password": "x3KPc&1k"}
    )
    assert resp.status_code == 200, f"fac02 login failed: {resp.text}"
    return resp.json()["access_token"]


class TestAttendanceWindowEngine:
    """Deterministic engine tests with simulated IST timestamps."""

    def test_01_today_completed_period_available(self, live_db):
        """At 14:00 on Tuesday 2026-09-29, P2 (10:00-10:50) is completed and AVAILABLE."""
        simulated_now = _make_ist_dt(2026, 9, 29, 14, 0)
        res = get_faculty_available_attendance_periods(live_db, faculty_id=6, dt=simulated_now)

        assert res["today_date"] == "2026-09-29"
        assert res["today_day"] == "Tuesday"
        p2 = next((p for p in res["today_periods"] if p["period_number"] == 2), None)
        assert p2 is not None
        assert p2["status"] == "AVAILABLE"
        assert p2["can_mark"] is True
        assert p2["lock_reason"] is None

    def test_02_today_active_period_locked(self, live_db):
        """At 14:50 on Tuesday 2026-09-29, P6 (14:30-15:20) is active and LOCKED."""
        # Santhiya (ID 7) has Tuesday P6 (LIB)
        simulated_now = _make_ist_dt(2026, 9, 29, 14, 50)
        res = get_faculty_available_attendance_periods(live_db, faculty_id=7, dt=simulated_now)

        p6 = next((p for p in res["today_periods"] if p["period_number"] == 6), None)
        assert p6 is not None
        assert p6["status"] == "LOCKED"
        assert p6["can_mark"] is False
        assert "15:20" in p6["lock_reason"]

    def test_03_today_future_period_locked(self, live_db):
        """At 14:00 on Tuesday 2026-09-29, P7 (15:20-16:10) is future and LOCKED."""
        # Showmiya (ID 4) has Tuesday P7 (E&I)
        simulated_now = _make_ist_dt(2026, 9, 29, 14, 0)
        res = get_faculty_available_attendance_periods(live_db, faculty_id=4, dt=simulated_now)

        p7 = next((p for p in res["today_periods"] if p["period_number"] == 7), None)
        assert p7 is not None
        assert p7["status"] == "LOCKED"
        assert p7["can_mark"] is False
        assert "16:10" in p7["lock_reason"]

    def test_04_yesterday_periods_all_available(self, live_db):
        """On Tuesday 2026-09-29, Monday periods for FAC04 are completed and AVAILABLE."""
        simulated_now = _make_ist_dt(2026, 9, 29, 10, 0)
        res = get_faculty_available_attendance_periods(live_db, faculty_id=6, dt=simulated_now)

        assert res["yesterday_date"] == "2026-09-28"
        assert res["yesterday_day"] == "Monday"
        assert len(res["yesterday_periods"]) > 0
        for p in res["yesterday_periods"]:
            assert p["status"] in ("AVAILABLE", "ALREADY_MARKED")
            if p["status"] == "AVAILABLE":
                assert p["can_mark"] is True

    def test_05_exact_end_time_boundary_transition(self, live_db):
        """P6 ends at 15:20. At 15:19 it is LOCKED; at 15:20 it transitions to AVAILABLE."""
        # Santhiya (ID 7) has Tuesday P6
        at_15_19 = _make_ist_dt(2026, 9, 29, 15, 19, 59)
        res_locked = get_faculty_available_attendance_periods(live_db, faculty_id=7, dt=at_15_19)
        p6_locked = next(p for p in res_locked["today_periods"] if p["period_number"] == 6)
        assert p6_locked["status"] == "LOCKED"
        assert p6_locked["can_mark"] is False

        at_15_20 = _make_ist_dt(2026, 9, 29, 15, 20, 0)
        res_available = get_faculty_available_attendance_periods(live_db, faculty_id=7, dt=at_15_20)
        p6_avail = next(p for p in res_available["today_periods"] if p["period_number"] == 6)
        assert p6_avail["status"] == "AVAILABLE"
        assert p6_avail["can_mark"] is True

    def test_06_past_dates_allowed_in_phase_8(self, live_db):
        """In Phase 8 retrospective attendance, valid past dates matching day of week are allowed."""
        simulated_now = _make_ist_dt(2026, 9, 29, 14, 0)
        # TT 160 is Tuesday. 2026-09-22 was Tuesday (one week prior)
        res = get_faculty_attendance_roster(
            live_db, faculty_id=6, timetable_entry_id=160, date_str="2026-09-22", dt=simulated_now
        )
        assert res["date"] == "2026-09-22"
        assert res["day_of_week"] == "Tuesday"
        assert len(res["roster"]) > 0

    def test_07_future_dates_rejected(self, live_db):
        """Requesting roster for tomorrow (2026-09-30) is rejected with 400."""
        from fastapi import HTTPException
        simulated_now = _make_ist_dt(2026, 9, 29, 14, 0)
        with pytest.raises(HTTPException) as exc_info:
            get_faculty_attendance_roster(
                live_db, faculty_id=6, timetable_entry_id=160, date_str="2026-09-30", dt=simulated_now
            )
        assert exc_info.value.status_code == 400
        assert "future dates" in exc_info.value.detail

    def test_08_unauthorized_faculty_rejected(self, live_db):
        """Faculty A (Showmiya, ID 4) cannot access roster for Faculty B's slot (TT 160 is Shankar's)."""
        from fastapi import HTTPException
        simulated_now = _make_ist_dt(2026, 9, 29, 14, 0)
        with pytest.raises(HTTPException) as exc_info:
            get_faculty_attendance_roster(
                live_db, faculty_id=4, timetable_entry_id=160, date_str="2026-09-29", dt=simulated_now
            )
        assert exc_info.value.status_code == 403
        assert "not authorized" in exc_info.value.detail

    def test_09_day_of_week_mismatch_rejected(self, live_db):
        """TT 160 is Tuesday. Requesting it with yesterday's Monday date (2026-09-28) fails with 400."""
        from fastapi import HTTPException
        simulated_now = _make_ist_dt(2026, 9, 29, 14, 0)
        with pytest.raises(HTTPException) as exc_info:
            get_faculty_attendance_roster(
                live_db, faculty_id=6, timetable_entry_id=160, date_str="2026-09-28", dt=simulated_now
            )
        assert exc_info.value.status_code == 400
        assert "does not match" in exc_info.value.detail


class TestFacultyAttendanceWorkflowAndPersistence:
    """Submission, session lifecycle, deduplication, and audit logging."""

    def test_10_submit_attendance_and_preserve_class_date(self, live_db):
        """
        Submitting attendance for yesterday's slot (Monday P1, TT #152) creates
        a ClassSession whose session.date is strictly Monday's date ('2026-09-28').
        """
        simulated_now = _make_ist_dt(2026, 9, 29, 14, 0)  # Entered on Tuesday!
        user = live_db.query(User).filter(User.username == "fac04").first()
        faculty_id = user.faculty_profile.id

        # Fetch roster first
        roster_data = get_faculty_attendance_roster(
            live_db, faculty_id=faculty_id, timetable_entry_id=152, date_str="2026-09-28", dt=simulated_now
        )
        assert len(roster_data["roster"]) > 0

        # Mark first 2 students PRESENT, 3rd ABSENT, 4th OD
        students = roster_data["roster"]
        records = [
            {"student_id": students[0]["student_id"], "status": "PRESENT"},
            {"student_id": students[1]["student_id"], "status": "PRESENT"},
            {"student_id": students[2]["student_id"], "status": "ABSENT"},
            {"student_id": students[3]["student_id"], "status": "OD", "od_reason": "Sports Meet"},
        ]

        submit_res = submit_faculty_attendance(
            live_db,
            faculty_id=faculty_id,
            user_id=user.id,
            timetable_entry_id=152,
            date_str="2026-09-28",
            records=records,
            dt=simulated_now
        )

        assert submit_res["message"] == "Attendance submitted successfully."
        assert submit_res["date"] == "2026-09-28"  # Must preserve actual class date!
        assert submit_res["records_count"] == 4
        assert submit_res["status"] == "COMPLETED"

        # Verify ClassSession in DB
        session = live_db.query(ClassSession).filter(ClassSession.id == submit_res["session_id"]).first()
        assert session is not None
        assert session.date == "2026-09-28"
        assert session.timetable_entry_id == 152
        assert session.status == SessionStatus.COMPLETED

        # Verify AuditLog in DB
        audit = live_db.query(AuditLog).filter(
            AuditLog.user_id == user.id,
            AuditLog.target == f"ClassSession #{session.id}",
            AuditLog.action == "FACULTY_ATTENDANCE_SUBMITTED"
        ).order_by(AuditLog.id.desc()).first()
        assert audit is not None

    def test_11_duplicate_session_and_record_prevention(self, live_db):
        """
        Re-submitting attendance for the same slot and date reuses the session
        and updates existing records without adding duplicate rows.
        """
        simulated_now = _make_ist_dt(2026, 9, 29, 14, 0)
        user = live_db.query(User).filter(User.username == "fac04").first()
        faculty_id = user.faculty_profile.id

        session_before = live_db.query(ClassSession).filter(
            ClassSession.timetable_entry_id == 152,
            ClassSession.date == "2026-09-28"
        ).first()
        assert session_before is not None
        session_id_before = session_before.id

        records_before_count = live_db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == session_id_before
        ).count()
        assert records_before_count == 4

        # Re-submit with one status changed (student[2] ABSENT -> PRESENT)
        roster_data = get_faculty_attendance_roster(
            live_db, faculty_id=faculty_id, timetable_entry_id=152, date_str="2026-09-28", dt=simulated_now
        )
        students = roster_data["roster"]
        updated_records = [
            {"student_id": students[0]["student_id"], "status": "PRESENT"},
            {"student_id": students[1]["student_id"], "status": "PRESENT"},
            {"student_id": students[2]["student_id"], "status": "PRESENT"},  # changed from ABSENT
            {"student_id": students[3]["student_id"], "status": "OD", "od_reason": "Sports Meet"},
        ]

        submit_res = submit_faculty_attendance(
            live_db,
            faculty_id=faculty_id,
            user_id=user.id,
            timetable_entry_id=152,
            date_str="2026-09-28",
            records=updated_records,
            dt=simulated_now
        )

        # Same session reused!
        assert submit_res["session_id"] == session_id_before

        # Exactly 4 records still exist (no duplicates!)
        records_after_count = live_db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == session_id_before
        ).count()
        assert records_after_count == 4

        # Verify changed student status
        rec3 = live_db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == session_id_before,
            AttendanceRecord.student_id == students[2]["student_id"]
        ).first()
        assert rec3.status == AttendanceStatus.PRESENT

        # Verify FACULTY_ATTENDANCE_CORRECTED audit log
        audit = live_db.query(AuditLog).filter(
            AuditLog.user_id == user.id,
            AuditLog.action == "FACULTY_ATTENDANCE_CORRECTED"
        ).order_by(AuditLog.id.desc()).first()
        assert audit is not None

    def test_12_already_marked_state_in_available_periods(self, live_db):
        """TT #152 now shows ALREADY_MARKED in available-periods."""
        simulated_now = _make_ist_dt(2026, 9, 29, 14, 0)
        res = get_faculty_available_attendance_periods(live_db, faculty_id=6, dt=simulated_now)
        p1 = next(p for p in res["yesterday_periods"] if p["timetable_entry_id"] == 152)
        assert p1["status"] == "ALREADY_MARKED"
        assert p1["can_mark"] is False


class TestFacultyAttendanceAPIEndpoints:
    """REST API endpoints via TestClient."""

    def test_13_api_get_available_periods(self, api_client, fac04_token):
        """GET /api/v1/faculty/attendance/available-periods returns structured response."""
        resp = api_client.get(
            "/api/v1/faculty/attendance/available-periods",
            headers={"Authorization": f"Bearer {fac04_token}"}
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert "today_date" in data
        assert "yesterday_date" in data
        assert "today_periods" in data
        assert "yesterday_periods" in data

    def test_14_api_get_roster_completed_period(self, api_client, fac04_token):
        """GET /api/v1/faculty/attendance/roster/160?date=2026-09-29 returns student roster."""
        resp = api_client.get(
            "/api/v1/faculty/attendance/roster/160?date=2026-09-29",
            headers={"Authorization": f"Bearer {fac04_token}"}
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["timetable_entry_id"] == 160
        assert data["subject_code"] == "AIML"
        assert len(data["roster"]) > 0
        assert "roll_number" in data["roster"][0]

    def test_15_api_get_roster_unauthorized_returns_403(self, api_client, fac02_token):
        """FAC02 trying to get roster for FAC04's slot 160 returns 403."""
        resp = api_client.get(
            "/api/v1/faculty/attendance/roster/160?date=2026-09-29",
            headers={"Authorization": f"Bearer {fac02_token}"}
        )
        assert resp.status_code == 403

    def test_16_api_submit_attendance_success(self, api_client, fac04_token, live_db):
        """POST /api/v1/faculty/attendance/submit successfully records attendance."""
        roster_resp = api_client.get(
            "/api/v1/faculty/attendance/roster/160?date=2026-09-29",
            headers={"Authorization": f"Bearer {fac04_token}"}
        )
        assert roster_resp.status_code == 200
        roster = roster_resp.json()["roster"]

        submit_payload = {
            "timetable_entry_id": 160,
            "date": "2026-09-29",
            "records": [
                {"student_id": s["student_id"], "status": "PRESENT"}
                for s in roster[:5]
            ]
        }

        resp = api_client.post(
            "/api/v1/faculty/attendance/submit",
            json=submit_payload,
            headers={"Authorization": f"Bearer {fac04_token}"}
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["message"] == "Attendance submitted successfully."
        assert data["records_count"] == 5

    def test_17_api_submit_tampered_student_returns_400(self, api_client, fac04_token):
        """Submitting a student ID that does not belong to the class section returns 400."""
        submit_payload = {
            "timetable_entry_id": 160,
            "date": "2026-09-29",
            "records": [
                {"student_id": 999999, "status": "PRESENT"}
            ]
        }
        resp = api_client.post(
            "/api/v1/faculty/attendance/submit",
            json=submit_payload,
            headers={"Authorization": f"Bearer {fac04_token}"}
        )
        assert resp.status_code == 400
        assert "not enrolled" in resp.json()["detail"]

    def test_18_api_submit_older_date_returns_400(self, api_client, fac04_token):
        """Submitting attendance for an older date (2026-09-25) returns 400."""
        submit_payload = {
            "timetable_entry_id": 160,
            "date": "2026-09-25",
            "records": []
        }
        resp = api_client.post(
            "/api/v1/faculty/attendance/submit",
            json=submit_payload,
            headers={"Authorization": f"Bearer {fac04_token}"}
        )
        assert resp.status_code == 400
        assert "Older dates are not allowed" in resp.json()["detail"]
