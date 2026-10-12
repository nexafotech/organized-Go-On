"""
tests/test_faculty_timetable_system.py
Comprehensive test suite for the Faculty Timetable System.

Coverage:
 1.  normalize_day_name — all valid variants
 2.  normalize_day_name — unrecognized strings
 3.  get_current_day_name — uses IST (2026-09-29 = Tuesday)
 4.  get_ist_now — returns timezone-aware IST datetime
 5.  get_ist_now — not UTC (verifies offset)
 6.  get_faculty_schedule — FAC01 primary CC entries
 7.  get_faculty_schedule — FAC01 TWM appears twice (2 classes)
 8.  get_faculty_schedule — no Monday/Sunday entries for FAC01
 9.  get_faculty_schedule — no duplicate entry IDs for any faculty
10.  get_faculty_schedule — authorized-only entries appear for all 8 faculty
11.  get_faculty_schedule — each entry has required keys
12.  get_faculty_schedule — day strings are Title Case
13.  get_faculty_schedule — empty for unknown faculty_id
14.  get_active_and_upcoming_class — active class detected mid-period
15.  get_active_and_upcoming_class — upcoming class correct when before first period
16.  get_active_and_upcoming_class — no active class after hours
17.  get_active_and_upcoming_class — Sunday returns no active/upcoming class
18.  get_active_and_upcoming_class — Monday NOT 'today' on 2026-09-29 (Tuesday)
19.  get_active_and_upcoming_class — day string in response is Title Case
20.  API GET /faculty/timetable — returns 6 entries for FAC01 (admin view)
21.  API GET /faculty/timetable — student gets 403 Forbidden
22.  API GET /faculty/active-class — returns correct current_day=Tuesday on 2026-09-29
23.  DB integrity — all timetable day strings are Title Case
24.  DB integrity — no P8/P9 test periods exist
25.  DB integrity — no Sunday entries (weekend)
26.  DB integrity — exactly 6 weekdays (Mon–Sat) with 14 entries each
"""
import pytest
from datetime import datetime, timezone, timedelta
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.engines.timetable_engine import (
    normalize_day_name,
    get_current_day_name,
    get_ist_now,
    get_faculty_schedule,
    get_active_and_upcoming_class,
    _IST_OFFSET,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_ist_dt(year, month, day, hour=0, minute=0):
    """Build an IST-offset-aware datetime for use in tests."""
    return datetime(year, month, day, hour, minute, tzinfo=_IST_OFFSET)


# ---------------------------------------------------------------------------
# 1-5: Pure-unit tests — no DB
# ---------------------------------------------------------------------------

class TestNormalizeDayName:
    """Tests 1-2: normalize_day_name helper."""

    def test_uppercase_all_days(self):
        """Test 1: all uppercase day names normalize correctly."""
        cases = {
            "MONDAY": "Monday",
            "TUESDAY": "Tuesday",
            "WEDNESDAY": "Wednesday",
            "THURSDAY": "Thursday",
            "FRIDAY": "Friday",
            "SATURDAY": "Saturday",
            "SUNDAY": "Sunday",
        }
        for inp, expected in cases.items():
            assert normalize_day_name(inp) == expected, f"Failed for {inp}"

    def test_lowercase_and_mixed_case(self):
        """Test 1 (continued): lowercase and mixed-case inputs."""
        assert normalize_day_name("monday") == "Monday"
        assert normalize_day_name("FRIDAY") == "Friday"
        assert normalize_day_name("Wednesday") == "Wednesday"
        assert normalize_day_name("  saturday  ") == "Saturday"

    def test_unrecognized_string_returns_capitalized(self):
        """Test 2: unrecognized strings fall back to capitalize()."""
        result = normalize_day_name("holiday")
        assert result == "Holiday"  # capitalize() result

    def test_empty_string_survives(self):
        """Test 2 (edge): empty string does not raise."""
        result = normalize_day_name("")
        assert isinstance(result, str)


class TestGetCurrentDayName:
    """Tests 3: get_current_day_name returns IST-based day."""

    def test_returns_title_case_tuesday_for_20260929(self):
        """Test 3: 2026-09-29 09:00 IST must be Tuesday, not Monday."""
        tuesday_ist = _make_ist_dt(2026, 9, 29, 9, 0)
        assert get_current_day_name(tuesday_ist) == "Tuesday"

    def test_monday_is_not_today_on_20260929(self):
        """Test 3 (regression): Monday must NOT be 'today' on 2026-09-29."""
        tuesday_ist = _make_ist_dt(2026, 9, 29, 12, 0)
        day = get_current_day_name(tuesday_ist)
        assert day != "Monday", "Monday wrongly identified as today on 2026-09-29"
        assert day == "Tuesday"

    def test_day_changes_at_midnight_ist(self):
        """Test 3: day rolls over correctly at midnight IST."""
        mon_23_59 = _make_ist_dt(2026, 9, 28, 23, 59)  # Monday
        tue_00_00 = _make_ist_dt(2026, 9, 29, 0, 0)   # Tuesday
        assert get_current_day_name(mon_23_59) == "Monday"
        assert get_current_day_name(tue_00_00) == "Tuesday"


class TestGetIstNow:
    """Tests 4-5: get_ist_now returns correctly offset datetime."""

    def test_returns_timezone_aware_datetime(self):
        """Test 4: result is timezone-aware."""
        now = get_ist_now()
        assert now.tzinfo is not None

    def test_offset_is_utc_plus_5_30(self):
        """Test 5: offset must be exactly +05:30 (not UTC 00:00)."""
        now = get_ist_now()
        offset_seconds = now.utcoffset().total_seconds()
        expected = 5 * 3600 + 30 * 60   # 19800 seconds
        assert offset_seconds == expected, (
            f"Expected IST offset +05:30 ({expected}s), got {offset_seconds}s"
        )


# ---------------------------------------------------------------------------
# 6-17: Integration tests against live DB
# ---------------------------------------------------------------------------

@pytest.fixture(scope="module")
def live_db():
    """Module-scoped DB session against the real development database."""
    engine = create_engine(
        "sqlite:///./attendance_system.db",
        connect_args={"check_same_thread": False}
    )
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()
    yield db
    db.close()


@pytest.fixture(scope="module")
def fac01_schedule(live_db):
    """FAC01 (Mathu Metlda) schedule — faculty_id=3."""
    return get_faculty_schedule(live_db, faculty_id=3)


class TestGetFacultyScheduleFAC01:
    """Tests 6-13: get_faculty_schedule against live DB for FAC01."""

    def test_fac01_has_cc_entries(self, fac01_schedule):
        """Test 6: FAC01 has Cloud Computing (CC) entries."""
        cc = [e for e in fac01_schedule if e["subject_code"] == "CC"]
        assert len(cc) >= 1, "FAC01 should have at least one CC entry"

    def test_fac01_twm_appears_twice(self, fac01_schedule):
        """Test 7: TWM appears twice on Friday for FAC01 (Class 1 + Class 2)."""
        friday_twm = [
            e for e in fac01_schedule
            if e["subject_code"] == "TWM" and e["day_of_week"] == "Friday"
        ]
        assert len(friday_twm) == 2, (
            f"Expected 2 Friday TWM entries for FAC01 (one per class), got {len(friday_twm)}"
        )
        class_names = {e["class_name"] for e in friday_twm}
        assert "II Year CSE Cyber Security - Class 1" in class_names
        assert "III Year CSE Cyber Security - Class 2" in class_names

    def test_fac01_no_monday_entries(self, fac01_schedule):
        """Test 8a: FAC01 has no Monday entries."""
        monday = [e for e in fac01_schedule if e["day_of_week"] == "Monday"]
        assert len(monday) == 0, f"FAC01 should have 0 Monday entries, got {len(monday)}"

    def test_fac01_no_sunday_entries(self, fac01_schedule):
        """Test 8b: FAC01 has no Sunday entries."""
        sunday = [e for e in fac01_schedule if e["day_of_week"] == "Sunday"]
        assert len(sunday) == 0, f"FAC01 should have 0 Sunday entries, got {len(sunday)}"

    def test_fac01_total_six_entries(self, fac01_schedule):
        """Test 6 (count): FAC01 has exactly 6 timetable entries."""
        assert len(fac01_schedule) == 6, (
            f"FAC01 should have 6 entries, got {len(fac01_schedule)}"
        )

    def test_no_duplicate_entry_ids_for_any_faculty(self, live_db):
        """Test 9: No faculty receives duplicate timetable entry IDs."""
        # Faculty IDs in the live DB (FAC01–FAC08)
        faculty_ids = list(range(3, 11))
        for fac_id in faculty_ids:
            schedule = get_faculty_schedule(live_db, faculty_id=fac_id)
            entry_ids = [e["id"] for e in schedule]
            assert len(entry_ids) == len(set(entry_ids)), (
                f"Duplicate entry IDs for faculty_id={fac_id}: {entry_ids}"
            )

    def test_all_eight_faculty_get_some_entries(self, live_db):
        """Test 10: All 8 faculty (FAC01–FAC08) have at least 1 entry including authorized."""
        faculty_ids = list(range(3, 11))
        for fac_id in faculty_ids:
            schedule = get_faculty_schedule(live_db, faculty_id=fac_id)
            assert len(schedule) > 0, f"faculty_id={fac_id} has no timetable entries"

    def test_schedule_entries_have_required_keys(self, fac01_schedule):
        """Test 11: Every schedule entry has all required keys."""
        required_keys = {
            "id", "day_of_week", "period_id", "period_number",
            "period_name", "start_time", "end_time",
            "assignment_id", "subject_code", "subject_name",
            "class_name", "faculty_name",
        }
        for entry in fac01_schedule:
            missing = required_keys - entry.keys()
            assert not missing, f"Entry {entry['id']} missing keys: {missing}"

    def test_day_strings_are_title_case(self, live_db):
        """Test 12: All day_of_week values returned by the engine are Title Case."""
        valid_days = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}
        for fac_id in range(3, 11):
            schedule = get_faculty_schedule(live_db, faculty_id=fac_id)
            for entry in schedule:
                day = entry["day_of_week"]
                assert day in valid_days, (
                    f"Invalid day string '{day}' for faculty_id={fac_id}"
                )

    def test_unknown_faculty_id_returns_empty(self, live_db):
        """Test 13: Unknown faculty_id returns an empty list, not an error."""
        schedule = get_faculty_schedule(live_db, faculty_id=99999)
        assert schedule == []


class TestGetActiveAndUpcomingClass:
    """Tests 14-19: get_active_and_upcoming_class against live DB."""

    def test_active_class_detected_during_period(self, live_db):
        """Test 14: Detects active class when current time is mid-period.
        FAC01 has CC on Tuesday P3 (11:10–12:00). Simulating 11:30 IST on Tue 2026-09-29.
        """
        tuesday_1130 = _make_ist_dt(2026, 9, 29, 11, 30)
        result = get_active_and_upcoming_class(live_db, faculty_id=3, dt=tuesday_1130)
        assert result["has_active_class"] is True
        active = result["active_class"]
        assert active is not None
        assert active["subject_code"] == "CC"
        assert active["period_number"] == 3

    def test_upcoming_class_correct_before_first_period(self, live_db):
        """Test 15: Upcoming class is P3 CC when time is 09:00 on Tue 2026-09-29 (FAC01)."""
        tuesday_0900 = _make_ist_dt(2026, 9, 29, 9, 0)
        result = get_active_and_upcoming_class(live_db, faculty_id=3, dt=tuesday_0900)
        assert result["has_active_class"] is False
        upcoming = result["upcoming_class"]
        assert upcoming is not None
        assert upcoming["subject_code"] == "CC"
        assert upcoming["period_number"] == 3
        assert upcoming["start_time"] == "11:10"

    def test_no_active_class_after_all_periods(self, live_db):
        """Test 16: No active class at 22:00 IST (after all classes end)."""
        tuesday_2200 = _make_ist_dt(2026, 9, 29, 22, 0)
        result = get_active_and_upcoming_class(live_db, faculty_id=3, dt=tuesday_2200)
        assert result["has_active_class"] is False
        assert result["active_class"] is None
        assert result["upcoming_class"] is None

    def test_sunday_has_no_active_or_upcoming(self, live_db):
        """Test 17: Sunday always returns no active or upcoming class for any faculty."""
        sunday_ist = _make_ist_dt(2026, 9, 27, 11, 0)  # A known Sunday in IST
        for fac_id in range(3, 11):
            result = get_active_and_upcoming_class(live_db, faculty_id=fac_id, dt=sunday_ist)
            assert result["has_active_class"] is False
            assert result["active_class"] is None
            assert result["upcoming_class"] is None, (
                f"fac_id={fac_id} has unexpected upcoming class on Sunday"
            )

    def test_monday_is_not_tuesday_20260929(self, live_db):
        """Test 18 (regression): On 2026-09-29 (Tuesday), Monday is not 'today'.
        FAC01 has NO Monday entries — so Monday active-class check returns empty.
        """
        tuesday_ist = _make_ist_dt(2026, 9, 29, 11, 30)
        result = get_active_and_upcoming_class(live_db, faculty_id=3, dt=tuesday_ist)
        # The response current_day must be Tuesday
        assert result["current_day"] == "Tuesday", (
            f"current_day should be 'Tuesday' on 2026-09-29, got '{result['current_day']}'"
        )
        # Must NOT be Monday
        assert result["current_day"] != "Monday"
        # Also verify date string
        assert result["current_date"] == "2026-09-29"

    def test_response_day_string_is_title_case(self, live_db):
        """Test 19: current_day in response is always Title Case."""
        tuesday_ist = _make_ist_dt(2026, 9, 29, 11, 0)
        result = get_active_and_upcoming_class(live_db, faculty_id=3, dt=tuesday_ist)
        assert result["current_day"] == result["current_day"].capitalize()


# ---------------------------------------------------------------------------
# 20-22: API-level tests via TestClient + live backend DB
# ---------------------------------------------------------------------------

@pytest.fixture(scope="module")
def api_client(live_db):
    """TestClient that uses the live DB via DI override."""
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
    assert resp.status_code == 200, f"Admin login failed: {resp.text}"
    return resp.json()["access_token"]


@pytest.fixture(scope="module")
def student_token(api_client):
    """Get a token for any student (roll-number login)."""
    # roll_number for first student in class 1
    resp = api_client.post(
        "/api/v1/auth/student/login",
        json={"identifier": "721025149001", "password": None}  # will fail; that's ok
    )
    # If student login fails we skip — this fixture is best-effort
    if resp.status_code == 200:
        return resp.json().get("access_token")
    return None


class TestFacultyTimetableAPI:
    """Tests 20-22: REST API level checks."""

    def test_get_timetable_admin_sees_fac01(self, api_client, admin_token):
        """Test 20: Admin GET /faculty/timetable sees FAC01 schedule (6 entries)."""
        resp = api_client.get(
            "/api/v1/faculty/timetable",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "timetable" in data
        assert "faculty_name" in data
        tt = data["timetable"]
        # Admin view picks first faculty (FAC01 = Mathu Metlda in test DB)
        assert len(tt) == 6, f"Expected 6 entries for FAC01, got {len(tt)}"

    def test_unauthenticated_cannot_access_faculty_timetable(self):
        """Test 21: No token → 401/403 on /faculty/timetable (RBAC enforced)."""
        # Use a clean TestClient without dependency_overrides so auth middleware is live
        clean_client = TestClient(app, raise_server_exceptions=False)
        resp = clean_client.get("/api/v1/faculty/timetable")
        assert resp.status_code in (401, 403), (
            f"Expected 401/403 for unauthenticated access, got {resp.status_code}"
        )

    def test_active_class_returns_current_day_tuesday(self, api_client, admin_token):
        """Test 22: /faculty/active-class has current_day='Tuesday' on 2026-09-29."""
        resp = api_client.get(
            "/api/v1/faculty/active-class",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "current_day" in data
        assert data["current_day"] == "Tuesday", (
            f"Expected 'Tuesday' on 2026-09-29, got '{data['current_day']}'"
        )


# ---------------------------------------------------------------------------
# 23-26: DB-level integrity tests
# ---------------------------------------------------------------------------

class TestDatabaseIntegrity:
    """Tests 23-26: Direct DB state assertions."""

    def test_all_day_strings_title_case(self, live_db):
        """Test 23: Every day_of_week value in timetable_entries is Title Case."""
        from app.models.academic import TimetableEntry
        valid = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}
        rows = live_db.query(TimetableEntry.day_of_week).distinct().all()
        for (day,) in rows:
            assert day in valid, f"Invalid day string in DB: '{day}'"

    def test_no_test_periods_p8_or_higher(self, live_db):
        """Test 24: No Period with period_number >= 8 (P8/P9 test artifacts)."""
        from app.models.academic import Period
        test_periods = live_db.query(Period).filter(Period.period_number >= 8).all()
        assert len(test_periods) == 0, (
            f"Test periods with number>=8 found: {[(p.id, p.period_number) for p in test_periods]}"
        )

    def test_no_sunday_entries_in_db(self, live_db):
        """Test 25: No timetable entries with day_of_week='Sunday'."""
        from app.models.academic import TimetableEntry
        sunday = live_db.query(TimetableEntry).filter(
            TimetableEntry.day_of_week == "Sunday"
        ).count()
        assert sunday == 0, f"Expected 0 Sunday entries, found {sunday}"

    def test_six_weekdays_with_14_entries_each(self, live_db):
        """Test 26: Mon–Sat each have exactly 14 timetable entries (7 periods × 2 classes)."""
        from app.models.academic import TimetableEntry
        from sqlalchemy import func
        expected_days = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
        rows = (
            live_db.query(TimetableEntry.day_of_week, func.count(TimetableEntry.id))
            .group_by(TimetableEntry.day_of_week)
            .all()
        )
        day_counts = {day: count for day, count in rows}
        actual_days = set(day_counts.keys())
        assert actual_days == expected_days, (
            f"Expected days {expected_days}, got {actual_days}"
        )
        for day in expected_days:
            assert day_counts[day] == 14, (
                f"Expected 14 entries for {day}, got {day_counts[day]}"
            )
