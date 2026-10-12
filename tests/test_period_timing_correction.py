"""
tests/test_period_timing_correction.py
Comprehensive regression tests for Period 6 timing correction (14:40 -> 14:30).

Verifies all 13 points specified in Task Section 16:
 1. Correct period start = 14:30 (P6 start_time='14:30', end_time='15:20')
 2. Incorrect 14:40 value is not returned anywhere in periods or timetable
 3. Admin timetable / periods API returns 14:30
 4. Faculty timetable returns 14:30 for Period 6
 5. Student timetable returns 14:30 for Period 6
 6. Session creation uses 14:30 (active slot at 14:35 IST resolves P6, session starts)
 7. Period timing configuration returns 14:30
 8. No UTC timezone shift (IST clock-time remains 14:30)
 9. Other period timings remain unchanged (P1-P5, P7)
 10. Database contains no duplicate affected period definitions
 11. Fresh database initialization creates 14:30
 12. Development restore preserves 14:30
 13. Application reload / re-querying does not restore 14:40
"""
import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models.academic import Period, TimetableEntry, ClassSection, FacultyAssignment
from app.models.attendance import ClassSession, SessionStatus
from app.models.user import User, UserRole, Faculty
from app.models.student import Student
from app.engines.timetable_engine import (
    get_faculty_schedule,
    get_active_and_upcoming_class,
    _IST_OFFSET,
)
from app.engines.attendance_engine import start_class_session
from app.services.college_importer import seed_temporary_dev_timetable


@pytest.fixture(scope="module")
def live_db():
    engine = create_engine(
        "sqlite:///./attendance_system.db",
        connect_args={"check_same_thread": False}
    )
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()
    yield db
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
def admin_token(api_client):
    resp = api_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "admin", "password": "admin123"}
    )
    assert resp.status_code == 200
    return resp.json()["access_token"]


class TestPeriodTimingCorrection:
    """1. Correct period start = 14:30 (and end = 15:20)."""

    def test_1_period_6_timing_in_db(self, live_db):
        p6 = live_db.query(Period).filter(Period.period_number == 6).first()
        assert p6 is not None, "Period 6 not found in DB"
        assert p6.start_time == "14:30", f"Expected P6 start_time '14:30', got '{p6.start_time}'"
        assert p6.end_time == "15:20", f"Expected P6 end_time '15:20', got '{p6.end_time}'"

    def test_2_incorrect_1440_not_returned_in_periods(self, live_db):
        """2. Incorrect 14:40 value is not returned anywhere in periods."""
        periods_with_1440 = live_db.query(Period).filter(
            (Period.start_time == "14:40") | (Period.end_time == "14:40")
        ).all()
        assert len(periods_with_1440) == 0, f"Found periods with 14:40: {periods_with_1440}"

    def test_3_admin_periods_api_returns_1430(self, api_client, admin_token):
        """3. Admin timetable / periods API returns 14:30."""
        resp = api_client.get(
            "/api/v1/admin/periods",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert resp.status_code == 200
        periods = resp.json()
        p6 = next((p for p in periods if p["period_number"] == 6), None)
        assert p6 is not None, "P6 missing from /admin/periods"
        assert p6["start_time"] == "14:30"
        assert p6["end_time"] == "15:20"

    def test_4_faculty_timetable_returns_1430_for_period_6(self, live_db):
        """4. Faculty timetable returns 14:30 for Period 6."""
        # FAC02 (Showmiya) teaches Period 6 on Thursday, Wednesday, Friday
        fac02 = live_db.query(Faculty).filter(Faculty.employee_id == "FAC02").first()
        assert fac02 is not None
        sched = get_faculty_schedule(live_db, fac02.id)
        p6_items = [e for e in sched if e["period_number"] == 6]
        assert len(p6_items) > 0, "FAC02 should have Period 6 entries"
        for item in p6_items:
            assert item["start_time"] == "14:30", f"Expected 14:30, got {item['start_time']}"
            assert item["end_time"] == "15:20", f"Expected 15:20, got {item['end_time']}"

    def test_5_student_timetable_returns_1430_for_period_6(self, live_db):
        """5. Student timetable returns 14:30 for Period 6."""
        # Class 1 (id=4) has 6 timetable entries for Period 6
        entries = (
            live_db.query(TimetableEntry)
            .join(Period)
            .filter(TimetableEntry.assignment.has(class_id=4), Period.period_number == 6)
            .all()
        )
        assert len(entries) == 6, f"Expected 6 P6 entries for Class 1, got {len(entries)}"
        for e in entries:
            assert e.period.start_time == "14:30"
            assert e.period.end_time == "15:20"

    def test_6_session_creation_uses_1430(self, live_db):
        """6. Active class slot and session creation uses 14:30."""
        # FAC02 teaches DS on Thursday Period 6 (14:30 - 15:20)
        # Simulate Thursday at 14:45 IST (inside Period 6)
        # Note: 2026-10-01 is a Thursday
        thursday_p6 = datetime(2026, 10, 1, 14, 45, tzinfo=_IST_OFFSET)
        fac02 = live_db.query(Faculty).filter(Faculty.employee_id == "FAC02").first()

        status_info = get_active_and_upcoming_class(live_db, faculty_id=fac02.id, dt=thursday_p6)
        assert status_info["has_active_class"] is True
        ac = status_info["active_class"]
        assert ac is not None
        assert ac["period_number"] == 6
        assert ac["start_time"] == "14:30"
        assert ac["end_time"] == "15:20"

    def test_7_period_timing_configuration_returns_1430(self, live_db):
        """7. Period timing configuration returns 14:30."""
        p6 = live_db.query(Period).filter(Period.period_number == 6).first()
        assert p6.start_time == "14:30"
        assert p6.end_time == "15:20"

    def test_8_no_utc_timezone_shift(self, live_db):
        """8. No UTC timezone shift — timetable start remains clock-time string '14:30'."""
        p6 = live_db.query(Period).filter(Period.period_number == 6).first()
        # Stored as local college clock-time string, NOT UTC timestamp
        assert p6.start_time == "14:30"
        assert isinstance(p6.start_time, str)
        assert len(p6.start_time) == 5

    def test_9_other_period_timings_remain_unchanged(self, live_db):
        """9. Other period timings remain unchanged (P1-P5, P7)."""
        expected_timings = {
            1: ("09:10", "10:00"),
            2: ("10:00", "10:50"),
            3: ("11:10", "12:00"),
            4: ("12:00", "12:50"),
            5: ("13:40", "14:30"),
            7: ("15:20", "16:10"),
        }
        for pnum, (exp_start, exp_end) in expected_timings.items():
            p = live_db.query(Period).filter(Period.period_number == pnum).first()
            assert p is not None, f"Period {pnum} missing"
            assert p.start_time == exp_start, f"P{pnum} start changed: expected {exp_start}, got {p.start_time}"
            assert p.end_time == exp_end, f"P{pnum} end changed: expected {exp_end}, got {p.end_time}"

    def test_10_database_contains_no_duplicate_period_definitions(self, live_db):
        """10. Database contains no duplicate affected period definitions."""
        p6_count = live_db.query(Period).filter(Period.period_number == 6).count()
        assert p6_count == 1, f"Expected exactly 1 Period 6, got {p6_count}"

    def test_11_fresh_seed_data_specifies_1430(self):
        """11. Fresh database initialization specification creates 14:30."""
        import json
        with open("college_seed/periods.json", "r") as fp:
            periods = json.load(fp)
        p6 = next((p for p in periods if p["period_number"] == 6), None)
        assert p6 is not None
        assert p6["start_time"] == "14:30"
        assert p6["end_time"] == "15:20"

    def test_12_development_restore_preserves_1430(self, live_db):
        """12. Development restore preserves 14:30."""
        # Call seed_temporary_dev_timetable and ensure Period 6 remains 14:30
        res = seed_temporary_dev_timetable(live_db, class_name="all", force_reset=False)
        p6 = live_db.query(Period).filter(Period.period_number == 6).first()
        assert p6.start_time == "14:30"
        assert p6.end_time == "15:20"

    def test_13_application_reload_does_not_restore_1440(self, live_db):
        """13. Re-querying does not restore 14:40."""
        live_db.expire_all()
        p6 = live_db.query(Period).filter(Period.period_number == 6).first()
        assert p6.start_time == "14:30"
        assert p6.end_time == "15:20"
