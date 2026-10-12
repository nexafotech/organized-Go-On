from datetime import datetime, time, timezone, timedelta
from typing import Optional, Dict, Any, List
from sqlalchemy.orm import Session
from app.models.academic import Period, TimetableEntry, FacultyAssignment, Subject, ClassSection
from app.models.user import Faculty

# IST = UTC+05:30
_IST_OFFSET = timezone(timedelta(hours=5, minutes=30))

# Canonical day-name ordering (matches strftime %A / DB values)
_DAY_ORDER = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
_DAY_UPPER_MAP = {d.upper(): d for d in _DAY_ORDER}


def get_ist_now() -> datetime:
    """
    Return current datetime in IST (Asia/Kolkata, UTC+05:30).
    Tries zoneinfo first; falls back to a fixed UTC+05:30 offset so the
    engine is never silently governed by server-local timezone.
    """
    try:
        from zoneinfo import ZoneInfo
        return datetime.now(ZoneInfo("Asia/Kolkata"))
    except Exception:
        # Fallback: fixed UTC+05:30 offset (always correct for IST)
        return datetime.now(timezone.utc).astimezone(_IST_OFFSET)


def normalize_day_name(day: str) -> str:
    """
    Canonicalize any day string to Title Case matching DB values
    (e.g. 'MONDAY' -> 'Monday', 'monday' -> 'Monday', 'Monday' -> 'Monday').
    Returns the original string if not recognized.
    """
    return _DAY_UPPER_MAP.get(day.strip().upper(), day.strip().capitalize())


def get_current_day_name(dt: Optional[datetime] = None) -> str:
    """Return the Title-Case weekday name for *dt* in IST."""
    if dt is None:
        dt = get_ist_now()
    return dt.strftime("%A")


def get_current_time_str(dt: Optional[datetime] = None) -> str:
    """Return HH:MM string for *dt* in IST."""
    if dt is None:
        dt = get_ist_now()
    return dt.strftime("%H:%M")


# ── Authoritative Institutional Schedule Constants ────────────────────────────
INSTITUTIONAL_SCHEDULE = {
    1: {"name": "Period 1", "start": "09:10", "end": "10:00", "half": "MORNING"},
    2: {"name": "Period 2", "start": "10:00", "end": "10:50", "half": "MORNING"},
    3: {"name": "Period 3", "start": "11:10", "end": "12:00", "half": "MORNING"},
    4: {"name": "Period 4", "start": "12:00", "end": "12:50", "half": "MORNING"},
    5: {"name": "Period 5", "start": "13:40", "end": "14:30", "half": "AFTERNOON"},
    6: {"name": "Period 6", "start": "14:30", "end": "15:20", "half": "AFTERNOON"},
    7: {"name": "Period 7", "start": "15:20", "end": "16:10", "half": "AFTERNOON"},
}

SHORT_BREAK_START = "10:50"
SHORT_BREAK_END = "11:10"
LUNCH_BREAK_START = "12:50"
LUNCH_BREAK_END = "13:40"
COLLEGE_DAY_END = "16:10"


def is_lunch_break(time_str: str) -> bool:
    """Check if given HH:MM time falls strictly within the lunch break window (12:50 - 13:40)."""
    return LUNCH_BREAK_START <= time_str < LUNCH_BREAK_END


def is_short_break(time_str: str) -> bool:
    """Check if given HH:MM time falls strictly within the short break window (10:50 - 11:10)."""
    return SHORT_BREAK_START <= time_str < SHORT_BREAK_END


def is_after_college_day(time_str: str) -> bool:
    """Check if given HH:MM time is at or after 16:10 (college day ended)."""
    return time_str >= COLLEGE_DAY_END


def get_faculty_schedule(db: Session, faculty_id: int) -> List[Dict[str, Any]]:
    """Retrieve full timetable schedule for a specific faculty member (assigned or authorized)."""
    from app.models.academic import assignment_authorized_faculty
    from sqlalchemy import or_

    entries = (
        db.query(TimetableEntry)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .join(Period, TimetableEntry.period_id == Period.id)
        .outerjoin(assignment_authorized_faculty, assignment_authorized_faculty.c.assignment_id == FacultyAssignment.id)
        .filter(
            or_(
                FacultyAssignment.faculty_id == faculty_id,
                assignment_authorized_faculty.c.faculty_id == faculty_id
            )
        )
        .distinct()
        .order_by(Period.period_number.asc())
        .all()
    )

    result = []
    for entry in entries:
        result.append({
            "id": entry.id,
            "day_of_week": entry.day_of_week,
            "period_id": entry.period.id,
            "period_number": entry.period.period_number,
            "period_name": entry.period.name,
            "start_time": entry.period.start_time,
            "end_time": entry.period.end_time,
            "assignment_id": entry.assignment.id,
            "subject_code": entry.assignment.subject.code,
            "subject_name": entry.assignment.subject.name,
            "class_name": entry.assignment.class_section.name,
            "faculty_name": entry.assignment.display_faculty_name,
        })
    return result

def get_active_and_upcoming_class(db: Session, faculty_id: int, dt: Optional[datetime] = None) -> Dict[str, Any]:
    """
    Evaluates current IST time against configured DB timetable to find:
    - Active class (currently in progress)
    - Next upcoming class for today
    (Considers both primary assigned faculty and secondary authorized faculty)
    """
    from app.models.academic import assignment_authorized_faculty
    from sqlalchemy import or_

    if dt is None:
        dt = get_ist_now()

    current_day = dt.strftime("%A")  # Title Case, matches DB (e.g. 'Tuesday')
    current_time_str = dt.strftime("%H:%M")
    current_date_str = dt.strftime("%Y-%m-%d")


    # Fetch today's timetable entries for this faculty (assigned or authorized)
    entries = (
        db.query(TimetableEntry)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .join(Period, TimetableEntry.period_id == Period.id)
        .join(Subject, FacultyAssignment.subject_id == Subject.id)
        .join(ClassSection, FacultyAssignment.class_id == ClassSection.id)
        .outerjoin(assignment_authorized_faculty, assignment_authorized_faculty.c.assignment_id == FacultyAssignment.id)
        .filter(
            or_(
                FacultyAssignment.faculty_id == faculty_id,
                assignment_authorized_faculty.c.faculty_id == faculty_id
            ),
            TimetableEntry.day_of_week == current_day
        )
        .distinct()
        .order_by(Period.period_number.asc())
        .all()
    )

    active_class = None
    upcoming_class = None

    for entry in entries:
        start = entry.period.start_time
        end = entry.period.end_time

        # Active class check (start <= current_time <= end)
        if start <= current_time_str <= end:
            active_class = {
                "timetable_entry_id": entry.id,
                "assignment_id": entry.assignment.id,
                "day_of_week": current_day,
                "date": current_date_str,
                "period_number": entry.period.period_number,
                "period_name": entry.period.name,
                "start_time": start,
                "end_time": end,
                "subject_code": entry.assignment.subject.code,
                "subject_name": entry.assignment.subject.name,
                "class_name": entry.assignment.class_section.name,
                "class_id": entry.assignment.class_section.id,
                "subject_id": entry.assignment.subject.id
            }
        # Upcoming class check (start > current_time)
        elif current_time_str < start and upcoming_class is None:
            upcoming_class = {
                "timetable_entry_id": entry.id,
                "assignment_id": entry.assignment.id,
                "day_of_week": current_day,
                "date": current_date_str,
                "period_number": entry.period.period_number,
                "period_name": entry.period.name,
                "start_time": start,
                "end_time": end,
                "subject_code": entry.assignment.subject.code,
                "subject_name": entry.assignment.subject.name,
                "class_name": entry.assignment.class_section.name,
                "class_id": entry.assignment.class_section.id,
                "subject_id": entry.assignment.subject.id
            }

    return {
        "current_date": current_date_str,
        "current_day": current_day,
        "current_time": current_time_str,
        "active_class": active_class,
        "upcoming_class": upcoming_class,
        "has_active_class": active_class is not None
    }
