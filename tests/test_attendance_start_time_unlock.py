"""
tests/test_attendance_start_time_unlock.py
Comprehensive test suite verifying that Faculty and Class Adviser attendance
unlocks at the period's scheduled START time (not end time).

Timezone: Asia/Kolkata (IST, UTC+5:30)
Display Format: 12-hour time with AM/PM (e.g., "1:40 PM")
"""

import pytest
from datetime import datetime, timezone, timedelta
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.models.academic import TimetableEntry, Period
from app.models.user import User, Faculty
from app.models.attendance import ClassSession, AttendanceRecord, AttendanceStatus, SessionStatus
from app.engines.timetable_engine import _IST_OFFSET, format_time_12h
from app.engines.attendance_engine import (
    get_faculty_available_attendance_periods,
    get_faculty_periods_for_date,
    get_faculty_attendance_roster,
    submit_faculty_attendance,
    get_class_advisor_available_periods,
    get_class_advisor_periods_for_date,
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


class TestAttendanceStartTimeUnlock:
    """Verifies that attendance opens at period start time across faculty and class advisor workflows."""

    def test_01_faculty_today_schedule_timing_transitions(self, db_session):
        """
        Verify period status across 4 distinct times:
        1. Before start time -> LOCKED with 'Attendance opens at <start>'
        2. At exact start time -> AVAILABLE with can_mark=True
        3. During period -> AVAILABLE with can_mark=True
        4. At/after end time -> AVAILABLE with can_mark=True (unless already marked)
        """
        # Find a faculty with active timetable entries
        entry = db_session.query(TimetableEntry).filter(
            TimetableEntry.assignment_id.isnot(None)
        ).first()
        assert entry is not None, "No timetable entries found in database"

        faculty_id = entry.assignment.faculty_id
        day_of_week = entry.day_of_week
        start_time = entry.period.start_time  # e.g., "09:10" or "13:40"
        end_time = entry.period.end_time      # e.g., "10:00" or "14:30"
        start_h, start_m = map(int, start_time.split(":"))
        end_h, end_m = map(int, end_time.split(":"))

        # Find a date matching the entry's day_of_week
        # We simulate 2026-10-19 (Monday) or target day
        ref_date = datetime(2026, 10, 26).date()
        while ref_date.strftime("%A").lower() != day_of_week.lower():
            ref_date += timedelta(days=1)

        year, month, day = ref_date.year, ref_date.month, ref_date.day

        # Case 1: 1 minute BEFORE start time
        before_dt = _make_ist_dt(year, month, day, start_h, start_m) - timedelta(seconds=1)
        res_before = get_faculty_available_attendance_periods(db_session, faculty_id=faculty_id, dt=before_dt)
        p_before = next(p for p in res_before["today_periods"] if p["timetable_entry_id"] == entry.id)
        assert p_before["status"] == "LOCKED"
        assert p_before["can_mark"] is False
        expected_start_12h = format_time_12h(start_time)
        assert f"Attendance opens at {expected_start_12h}" in p_before["lock_reason"]

        # Case 2: At EXACT start time
        exact_start_dt = _make_ist_dt(year, month, day, start_h, start_m, 0)
        res_exact = get_faculty_available_attendance_periods(db_session, faculty_id=faculty_id, dt=exact_start_dt)
        p_exact = next(p for p in res_exact["today_periods"] if p["timetable_entry_id"] == entry.id)
        assert p_exact["status"] == "AVAILABLE"
        assert p_exact["can_mark"] is True
        assert p_exact["lock_reason"] is None

        # Case 3: DURING period (15 minutes into period)
        during_dt = _make_ist_dt(year, month, day, start_h, start_m) + timedelta(minutes=15)
        res_during = get_faculty_available_attendance_periods(db_session, faculty_id=faculty_id, dt=during_dt)
        p_during = next(p for p in res_during["today_periods"] if p["timetable_entry_id"] == entry.id)
        assert p_during["status"] == "AVAILABLE"
        assert p_during["can_mark"] is True
        assert p_during["lock_reason"] is None

        # Case 4: At EXACT end time
        end_dt = _make_ist_dt(year, month, day, end_h, end_m, 0)
        res_end = get_faculty_available_attendance_periods(db_session, faculty_id=faculty_id, dt=end_dt)
        p_end = next(p for p in res_end["today_periods"] if p["timetable_entry_id"] == entry.id)
        assert p_end["status"] == "AVAILABLE"
        assert p_end["can_mark"] is True
        assert p_end["lock_reason"] is None

    def test_02_class_advisor_timing_transitions(self, db_session):
        """
        Verify Class Advisor available-periods unlock at start time.
        """
        # Find a Class Advisor
        entry = db_session.query(TimetableEntry).join(TimetableEntry.assignment).filter(
            TimetableEntry.assignment_id.isnot(None)
        ).first()
        assert entry is not None

        class_sec = entry.assignment.class_section
        advisor_id = class_sec.class_advisor_id
        if not advisor_id:
            pytest.skip("No class advisor configured for class section")

        day_of_week = entry.day_of_week
        start_time = entry.period.start_time
        start_h, start_m = map(int, start_time.split(":"))

        ref_date = datetime(2026, 10, 26).date()
        while ref_date.strftime("%A").lower() != day_of_week.lower():
            ref_date += timedelta(days=1)
        year, month, day = ref_date.year, ref_date.month, ref_date.day

        # Before start time
        before_dt = _make_ist_dt(year, month, day, start_h, start_m) - timedelta(minutes=5)
        res_before = get_class_advisor_available_periods(db_session, faculty_id=advisor_id, dt=before_dt)
        p_before = next((p for p in res_before["today_periods"] if p["timetable_entry_id"] == entry.id), None)
        if p_before:
            assert p_before["status"] == "LOCKED"
            assert p_before["can_mark"] is False
            assert f"Attendance opens at {format_time_12h(start_time)}" in p_before["lock_reason"]

        # At start time
        start_dt = _make_ist_dt(year, month, day, start_h, start_m, 0)
        res_start = get_class_advisor_available_periods(db_session, faculty_id=advisor_id, dt=start_dt)
        p_start = next((p for p in res_start["today_periods"] if p["timetable_entry_id"] == entry.id), None)
        if p_start:
            assert p_start["status"] == "AVAILABLE"
            assert p_start["can_mark"] is True
            assert p_start["lock_reason"] is None

    def test_03_roster_access_enforces_start_time(self, db_session):
        """
        Verify that get_faculty_attendance_roster rejects requests before start time
        and allows requests during or after the start time.
        """
        entry = db_session.query(TimetableEntry).filter(
            TimetableEntry.assignment_id.isnot(None)
        ).first()
        faculty_id = entry.assignment.faculty_id
        day_of_week = entry.day_of_week
        start_time = entry.period.start_time
        start_h, start_m = map(int, start_time.split(":"))

        ref_date = datetime(2026, 10, 19).date()
        while ref_date.strftime("%A").lower() != day_of_week.lower():
            ref_date += timedelta(days=1)
        year, month, day = ref_date.year, ref_date.month, ref_date.day
        date_str = ref_date.strftime("%Y-%m-%d")

        # 10 seconds before start time -> Rejected with 400
        before_dt = _make_ist_dt(year, month, day, start_h, start_m) - timedelta(seconds=10)
        with pytest.raises(HTTPException) as exc_info:
            get_faculty_attendance_roster(
                db_session, faculty_id=faculty_id, timetable_entry_id=entry.id, date_str=date_str, dt=before_dt
            )
        assert exc_info.value.status_code == 400
        assert "starts at" in exc_info.value.detail
        assert format_time_12h(start_time) in exc_info.value.detail

        # During period -> Allowed (HTTP 200 equivalent)
        during_dt = _make_ist_dt(year, month, day, start_h, start_m) + timedelta(minutes=10)
        roster = get_faculty_attendance_roster(
            db_session, faculty_id=faculty_id, timetable_entry_id=entry.id, date_str=date_str, dt=during_dt
        )
        assert roster["date"] == date_str
        assert len(roster["roster"]) > 0

    def test_04_class_advisor_roster_enforces_start_time(self, db_session):
        """
        Verify that get_class_advisor_attendance_roster rejects requests before start time
        and allows requests during the period.
        """
        entry = db_session.query(TimetableEntry).join(TimetableEntry.assignment).filter(
            TimetableEntry.assignment_id.isnot(None)
        ).first()
        class_sec = entry.assignment.class_section
        advisor_id = class_sec.class_advisor_id
        if not advisor_id:
            pytest.skip("No class advisor configured")

        day_of_week = entry.day_of_week
        start_time = entry.period.start_time
        start_h, start_m = map(int, start_time.split(":"))

        ref_date = datetime(2026, 10, 19).date()
        while ref_date.strftime("%A").lower() != day_of_week.lower():
            ref_date += timedelta(days=1)
        date_str = ref_date.strftime("%Y-%m-%d")
        year, month, day = ref_date.year, ref_date.month, ref_date.day

        # Before start time -> Rejected with 400
        before_dt = _make_ist_dt(year, month, day, start_h, start_m) - timedelta(seconds=30)
        with pytest.raises(HTTPException) as exc_info:
            get_class_advisor_attendance_roster(
                db_session, faculty_id=advisor_id, timetable_entry_id=entry.id, date_str=date_str, dt=before_dt
            )
        assert exc_info.value.status_code == 400
        assert "starts at" in exc_info.value.detail
        assert format_time_12h(start_time) in exc_info.value.detail

        # At start time -> Allowed
        start_dt = _make_ist_dt(year, month, day, start_h, start_m, 0)
        roster = get_class_advisor_attendance_roster(
            db_session, faculty_id=advisor_id, timetable_entry_id=entry.id, date_str=date_str, dt=start_dt
        )
        assert roster["date"] == date_str
        assert len(roster["roster"]) > 0

    def test_05_period_5_after_lunch_unlocks_at_1340(self, db_session):
        """
        Period 5 (13:40 - 14:30) following lunch break (12:50 - 13:40)
        specifically verifies the user's report that P5 unlocks at 1:40 PM, not 2:30 PM.
        """
        p5 = db_session.query(Period).filter(Period.period_number == 5).first()
        assert p5 is not None
        assert p5.start_time == "13:40"
        assert p5.end_time == "14:30"

        # Verify format_time_12h
        assert format_time_12h(p5.start_time) == "1:40 PM"
        assert format_time_12h(p5.end_time) == "2:30 PM"

        # Find any timetable entry for Period 5
        entry = db_session.query(TimetableEntry).filter(
            TimetableEntry.period_id == p5.id,
            TimetableEntry.assignment_id.isnot(None)
        ).first()

        if entry:
            faculty_id = entry.assignment.faculty_id
            ref_date = datetime(2026, 10, 19).date()
            while ref_date.strftime("%A").lower() != entry.day_of_week.lower():
                ref_date += timedelta(days=1)
            year, month, day = ref_date.year, ref_date.month, ref_date.day

            # At 1:35 PM (during lunch break, 5 min before P5): LOCKED
            at_1335 = _make_ist_dt(year, month, day, 13, 35)
            res = get_faculty_available_attendance_periods(db_session, faculty_id=faculty_id, dt=at_1335)
            p = next(x for x in res["today_periods"] if x["timetable_entry_id"] == entry.id)
            assert p["status"] == "LOCKED"
            assert "Attendance opens at 1:40 PM" in p["lock_reason"]

            # At 1:40 PM (P5 starts): AVAILABLE
            at_1340 = _make_ist_dt(year, month, day, 13, 40)
            res = get_faculty_available_attendance_periods(db_session, faculty_id=faculty_id, dt=at_1340)
            p = next(x for x in res["today_periods"] if x["timetable_entry_id"] == entry.id)
            assert p["status"] == "AVAILABLE"
            assert p["can_mark"] is True
            assert p["lock_reason"] is None
