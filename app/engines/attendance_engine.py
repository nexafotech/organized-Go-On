from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List, Optional
import logging
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from sqlalchemy import or_
from fastapi import HTTPException, status

from app.models.user import Faculty
from app.models.academic import TimetableEntry, FacultyAssignment, ClassSection, Subject, Period, assignment_authorized_faculty
from app.models.student import Student
from app.models.attendance import ClassSession, AttendanceRecord, SessionStatus, AttendanceStatus, RecognitionSource, ReviewStatus
from app.models.audit import AuditLog
from app.engines.timetable_engine import get_active_and_upcoming_class, get_ist_now, format_time_12h

logger = logging.getLogger(__name__)

def start_class_session(
    db: Session,
    faculty_id: int,
    dt: Optional[datetime] = None,
    timetable_entry_id: Optional[int] = None
) -> ClassSession:
    """
    Validates class slot for faculty and starts an ACTIVE ClassSession.
    Prevents duplicate active sessions for the same timetable entry and date.
    """
    if dt is None:
        dt = get_ist_now()

    date_str = dt.strftime("%Y-%m-%d")

    if timetable_entry_id is not None:
        raw_entry = db.query(TimetableEntry).filter(TimetableEntry.id == timetable_entry_id).first()
        if not raw_entry:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Timetable slot not found")
        if not raw_entry.assignment or not raw_entry.assignment.is_faculty_authorized(faculty_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You are not authorized to manage attendance for this timetable slot."
            )
        tt_entry_id = raw_entry.id
    else:
        # 1. Resolve current active class slot
        status_info = get_active_and_upcoming_class(db, faculty_id=faculty_id, dt=dt)
        if not status_info["has_active_class"] or not status_info["active_class"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot start session: No active class scheduled for your account at current time"
            )

        ac = status_info["active_class"]
        tt_entry_id = ac["timetable_entry_id"]
        date_str = ac["date"]

    # 2. Check for existing active or completed session for this timetable entry and date
    existing_session = db.query(ClassSession).filter(
        ClassSession.timetable_entry_id == tt_entry_id,
        ClassSession.date == date_str,
        ClassSession.status.in_([SessionStatus.ACTIVE, SessionStatus.COMPLETED])
    ).first()

    if existing_session:
        if existing_session.status == SessionStatus.ACTIVE:
            return existing_session
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="A session for this class slot has already been completed today."
            )

    # 3. Check if faculty already has another ACTIVE session running
    other_active = db.query(ClassSession).filter(
        ClassSession.faculty_id == faculty_id,
        ClassSession.status == SessionStatus.ACTIVE
    ).first()
    if other_active:
        return other_active

    # 4. Create new ACTIVE session
    new_session = ClassSession(
        timetable_entry_id=tt_entry_id,
        faculty_id=faculty_id,
        date=date_str,
        status=SessionStatus.ACTIVE,
        start_timestamp=datetime.now(timezone.utc)
    )
    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    return new_session

def get_session_details_with_roster(db: Session, session_id: int, faculty_id: Optional[int] = None) -> Dict[str, Any]:
    """
    Fetches session details, class information, student roster, and current attendance records.
    Ensures faculty ownership if faculty_id is provided.
    """
    session = db.query(ClassSession).filter(ClassSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Class session not found")

    if faculty_id is not None and session.faculty_id != faculty_id:
        is_auth = (
            session.timetable_entry
            and session.timetable_entry.assignment
            and session.timetable_entry.assignment.is_faculty_authorized(faculty_id)
        )
        if not is_auth:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not authorized to manage attendance for this timetable slot.")

    tt_entry = session.timetable_entry
    assignment = tt_entry.assignment if tt_entry else None
    class_sec = assignment.class_section if assignment else None
    subject = assignment.subject if assignment else None
    period = tt_entry.period if tt_entry else None

    # Load active students belonging to the class section
    students = []
    if class_sec:
        students = db.query(Student).filter(
            Student.class_id == class_sec.id,
            Student.is_active == True
        ).order_by(Student.roll_number.asc()).all()

    # Load existing attendance records for this session
    attendance_records = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id == session_id
    ).all()
    attendance_map = {att.student_id: att for att in attendance_records}

    present_count = 0
    absent_count = 0
    uncertain_count = 0

    student_roster = []
    for st in students:
        att = attendance_map.get(st.id)
        att_status = att.status.value if att else "UNMARKED"
        if att_status == "PRESENT":
            present_count += 1
        elif att_status == "ABSENT":
            absent_count += 1
        elif att_status == "UNCERTAIN":
            uncertain_count += 1

        student_roster.append({
            "student_id": st.id,
            "roll_number": st.roll_number,
            "full_name": st.full_name,
            "email": st.email,
            "attendance_status": att_status,
            "confidence": att.confidence if att else None,
            "recognized_via": att.recognized_via.value if att else None,
            "marked_at": att.marked_at.isoformat() if att and att.marked_at else None
        })

    total_students = len(students)
    remaining_count = total_students - (present_count + absent_count + uncertain_count)

    return {
        "session_id": session.id,
        "date": session.date,
        "status": session.status.value,
        "faculty_id": session.faculty_id,
        "faculty_name": session.faculty.full_name if session.faculty else None,
        "subject_code": subject.code if subject else "N/A",
        "subject_name": subject.name if subject else "N/A",
        "class_name": class_sec.name if class_sec else "N/A",
        "period_name": period.name if period else "N/A",
        "start_time": period.start_time if period else "N/A",
        "end_time": period.end_time if period else "N/A",
        "start_timestamp": session.start_timestamp.isoformat() if session.start_timestamp else None,
        "end_timestamp": session.end_timestamp.isoformat() if session.end_timestamp else None,
        "summary": {
            "total_students": total_students,
            "present_count": present_count,
            "absent_count": absent_count,
            "uncertain_count": uncertain_count,
            "remaining_count": max(0, remaining_count)
        },
        "roster": student_roster
    }

def record_manual_attendance(
    db: Session,
    session_id: int,
    student_id: int,
    status_val: AttendanceStatus,
    faculty_id: int
) -> AttendanceRecord:
    """
    Records or updates attendance for a student in an ACTIVE session.
    Enforces per-session deduplication (1 record per student per session).
    """
    session = db.query(ClassSession).filter(ClassSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    if session.faculty_id != faculty_id:
        is_auth = (
            session.timetable_entry
            and session.timetable_entry.assignment
            and session.timetable_entry.assignment.is_faculty_authorized(faculty_id)
        )
        if not is_auth:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not authorized to manage attendance for this timetable slot.")

    if session.status != SessionStatus.ACTIVE:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot mark attendance: Session is not ACTIVE")

    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    # Check for existing record in this session (Deduplication per session)
    existing_record = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id == session_id,
        AttendanceRecord.student_id == student_id
    ).first()

    if existing_record:
        existing_record.status = status_val
        existing_record.recognized_via = RecognitionSource.MANUAL
        existing_record.review_status = ReviewStatus.APPROVED
        existing_record.marked_at = datetime.now(timezone.utc)
        record = existing_record
    else:
        record = AttendanceRecord(
            session_id=session_id,
            student_id=student_id,
            status=status_val,
            confidence=100.0,
            recognized_via=RecognitionSource.MANUAL,
            review_status=ReviewStatus.APPROVED,
            marked_at=datetime.now(timezone.utc)
        )
        db.add(record)

    db.commit()
    db.refresh(record)
    return record

def complete_class_session(db: Session, session_id: int, faculty_id: int) -> ClassSession:
    """
    Transitions an ACTIVE session to COMPLETED status.
    Prevents further modifications by faculty.
    """
    session = db.query(ClassSession).filter(ClassSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    if session.faculty_id != faculty_id:
        is_auth = (
            session.timetable_entry
            and session.timetable_entry.assignment
            and session.timetable_entry.assignment.is_faculty_authorized(faculty_id)
        )
        if not is_auth:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not authorized to manage attendance for this timetable slot.")

    if session.status != SessionStatus.ACTIVE:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Cannot complete session in state {session.status.value}")

    session.status = SessionStatus.COMPLETED
    session.end_timestamp = datetime.now(timezone.utc)
    db.commit()
    db.refresh(session)
    return session

def admin_correct_attendance(
    db: Session,
    session_id: int,
    student_id: int,
    new_status: AttendanceStatus,
    reason: str,
    admin_user_id: int
) -> AttendanceRecord:
    """
    Explicit administrative correction workflow for attendance records.
    Records an entry in AuditLog.
    """
    session = db.query(ClassSession).filter(ClassSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    record = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id == session_id,
        AttendanceRecord.student_id == student_id
    ).first()

    old_status_str = record.status.value if record else "UNMARKED"

    if record:
        record.status = new_status
        record.marked_at = datetime.now(timezone.utc)
    else:
        record = AttendanceRecord(
            session_id=session_id,
            student_id=student_id,
            status=new_status,
            confidence=100.0,
            recognized_via=RecognitionSource.MANUAL,
            review_status=ReviewStatus.APPROVED,
            marked_at=datetime.now(timezone.utc)
        )
        db.add(record)

    # Log to AuditLog
    audit_entry = AuditLog(
        user_id=admin_user_id,
        action="ADMIN_ATTENDANCE_CORRECTION",
        details=f"Admin corrected attendance for Session #{session_id}, Student '{student.full_name}' ({student.roll_number}): {old_status_str} -> {new_status.value}. Reason: {reason}"
    )
    db.add(audit_entry)

    db.commit()
    db.refresh(record)
    return record


def get_faculty_available_attendance_periods(
    db: Session,
    faculty_id: int,
    dt: Optional[datetime] = None
) -> Dict[str, Any]:
    """
    Evaluates attendance availability for the faculty attendance-entry window:
    - TODAY: completed periods only (now_local >= scheduled period end_time)
    - YESTERDAY: all scheduled periods
    Strictly uses Asia/Kolkata local time.
    """
    if dt is None:
        dt = get_ist_now()

    today_date = dt.date()
    today_date_str = today_date.strftime("%Y-%m-%d")
    today_day = dt.strftime("%A")
    current_time_str = dt.strftime("%H:%M")

    yesterday_date = today_date - timedelta(days=1)
    yesterday_date_str = yesterday_date.strftime("%Y-%m-%d")
    yesterday_day = yesterday_date.strftime("%A")

    def _fetch_entries_for_day(day_name: str) -> List[TimetableEntry]:
        return (
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
                TimetableEntry.day_of_week == day_name
            )
            .distinct()
            .order_by(Period.period_number.asc())
            .all()
        )

    def _get_entry_status(entry: TimetableEntry, date_str: str, is_yesterday: bool) -> Dict[str, Any]:
        session = db.query(ClassSession).filter(
            ClassSession.timetable_entry_id == entry.id,
            ClassSession.date == date_str
        ).first()

        session_id = session.id if session else None
        has_records = False
        if session:
            has_records = db.query(AttendanceRecord).filter(
                AttendanceRecord.session_id == session.id
            ).count() > 0

        start = entry.period.start_time
        end = entry.period.end_time

        if is_yesterday:
            if has_records or (session and session.status == SessionStatus.COMPLETED):
                status_str = "ALREADY_MARKED"
                can_mark = False
                lock_reason = "Attendance has already been recorded for this period."
            else:
                status_str = "AVAILABLE"
                can_mark = True
                lock_reason = None
        else:
            if current_time_str >= end:
                if has_records or (session and session.status == SessionStatus.COMPLETED):
                    status_str = "ALREADY_MARKED"
                    can_mark = False
                    lock_reason = "Attendance has already been recorded for this period."
                else:
                    status_str = "AVAILABLE"
                    can_mark = True
                    lock_reason = None
            elif start <= current_time_str < end:
                status_str = "LOCKED"
                can_mark = False
                lock_reason = f"Attendance opens after this period ends at {format_time_12h(end)}"
            else:
                status_str = "LOCKED"
                can_mark = False
                lock_reason = f"Attendance opens after this period ends at {format_time_12h(end)}"

        return {
            "timetable_entry_id": entry.id,
            "period_id": entry.period.id,
            "period_number": entry.period.period_number,
            "period_name": entry.period.name,
            "start_time": start,
            "end_time": end,
            "subject_code": entry.assignment.subject.code,
            "subject_name": entry.assignment.subject.name,
            "class_id": entry.assignment.class_section.id,
            "class_name": entry.assignment.class_section.name,
            "date": date_str,
            "day_of_week": entry.day_of_week,
            "faculty_name": entry.assignment.display_faculty_name,
            "status": status_str,
            "can_mark": can_mark,
            "lock_reason": lock_reason,
            "session_id": session_id
        }

    today_entries = _fetch_entries_for_day(today_day)
    yesterday_entries = _fetch_entries_for_day(yesterday_day)

    today_periods = [_get_entry_status(e, today_date_str, is_yesterday=False) for e in today_entries]
    yesterday_periods = [_get_entry_status(e, yesterday_date_str, is_yesterday=True) for e in yesterday_entries]

    return {
        "today_date": today_date_str,
        "today_day": today_day,
        "yesterday_date": yesterday_date_str,
        "yesterday_day": yesterday_day,
        "current_time": current_time_str,
        "today_periods": today_periods,
        "yesterday_periods": yesterday_periods
    }


def get_faculty_periods_for_date(
    db: Session,
    faculty_id: int,
    date_str: str,
    dt: Optional[datetime] = None
) -> Dict[str, Any]:
    """
    Returns available timetable periods for a specific past or current date for authorized faculty.
    Strictly forbids future dates.
    Calculates completed/available/locked status based on date and time.
    """
    if dt is None:
        dt = get_ist_now()

    today_date = dt.date()
    today_date_str = today_date.strftime("%Y-%m-%d")
    current_time_str = dt.strftime("%H:%M")

    try:
        req_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid date format. Expected YYYY-MM-DD."
        )

    if req_date > today_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot mark attendance for future dates."
        )

    is_today = (date_str == today_date_str)
    day_name = req_date.strftime("%A")

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
            TimetableEntry.day_of_week == day_name
        )
        .distinct()
        .order_by(Period.period_number.asc())
        .all()
    )

    periods = []
    for entry in entries:
        session = db.query(ClassSession).filter(
            ClassSession.timetable_entry_id == entry.id,
            ClassSession.date == date_str
        ).first()

        session_id = session.id if session else None
        has_records = False
        if session:
            has_records = db.query(AttendanceRecord).filter(
                AttendanceRecord.session_id == session.id
            ).count() > 0

        start = entry.period.start_time
        end = entry.period.end_time

        if not is_today:
            if has_records or (session and session.status == SessionStatus.COMPLETED):
                status_str = "ALREADY_MARKED"
                can_mark = True
                lock_reason = None
            else:
                status_str = "AVAILABLE"
                can_mark = True
                lock_reason = None
        else:
            if current_time_str >= end:
                if has_records or (session and session.status == SessionStatus.COMPLETED):
                    status_str = "ALREADY_MARKED"
                    can_mark = True
                    lock_reason = None
                else:
                    status_str = "AVAILABLE"
                    can_mark = True
                    lock_reason = None
            else:
                status_str = "LOCKED"
                can_mark = False
                lock_reason = f"Attendance opens after this period ends at {format_time_12h(end)}"

        periods.append({
            "timetable_entry_id": entry.id,
            "period_id": entry.period.id,
            "period_number": entry.period.period_number,
            "period_name": entry.period.name,
            "start_time": start,
            "end_time": end,
            "subject_code": entry.assignment.subject.code,
            "subject_name": entry.assignment.subject.name,
            "class_id": entry.assignment.class_section.id,
            "class_name": entry.assignment.class_section.name,
            "date": date_str,
            "day_of_week": entry.day_of_week,
            "faculty_name": entry.assignment.display_faculty_name,
            "status": status_str,
            "can_mark": can_mark,
            "lock_reason": lock_reason,
            "session_id": session_id
        })

    return {
        "date": date_str,
        "day_of_week": day_name,
        "is_today": is_today,
        "periods": periods
    }



def get_faculty_attendance_roster(
    db: Session,
    faculty_id: int,
    timetable_entry_id: int,
    date_str: str,
    dt: Optional[datetime] = None
) -> Dict[str, Any]:
    """
    Validates eligibility and returns the student roster for marking attendance.
    Strictly enforces:
    - Date must be today or yesterday
    - Day of week must match timetable entry
    - Authenticated faculty must be authorized
    - Today's period must have ended
    """
    if dt is None:
        dt = get_ist_now()

    today_date = dt.date()
    today_date_str = today_date.strftime("%Y-%m-%d")
    yesterday_date = today_date - timedelta(days=1)
    yesterday_date_str = yesterday_date.strftime("%Y-%m-%d")

    # 1. Validate date window
    try:
        req_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid date format. Expected YYYY-MM-DD."
        )

    if req_date > today_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot mark attendance for future dates."
        )

    # 2. Validate timetable entry exists
    entry = db.query(TimetableEntry).filter(TimetableEntry.id == timetable_entry_id).first()
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Timetable slot not found."
        )

    # 3. Validate day of week match
    req_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    req_day_name = req_date.strftime("%A")
    if entry.day_of_week.lower() != req_day_name.lower():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Timetable slot #{timetable_entry_id} is scheduled for {entry.day_of_week}, which does not match date {date_str} ({req_day_name})."
        )

    # 4. Validate faculty authorization
    if not entry.assignment or not entry.assignment.is_faculty_authorized(faculty_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not authorized to mark attendance for this class."
        )

    # 5. If date is today, validate period has ended
    current_time_str = dt.strftime("%H:%M")
    if date_str == today_date_str:
        if current_time_str < entry.period.end_time:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Attendance isn't open yet. This period ends at {format_time_12h(entry.period.end_time)}."
            )

    # 6. Check existing session and records
    session = db.query(ClassSession).filter(
        ClassSession.timetable_entry_id == entry.id,
        ClassSession.date == date_str
    ).first()

    attendance_map = {}
    already_marked = False
    session_id = None
    if session:
        session_id = session.id
        records = db.query(AttendanceRecord).filter(AttendanceRecord.session_id == session.id).all()
        if records:
            already_marked = True
            attendance_map = {r.student_id: r for r in records}

    # 7. Load students for the class
    class_sec = entry.assignment.class_section
    students = (
        db.query(Student)
        .filter(Student.class_id == class_sec.id, Student.is_active == True)
        .order_by(Student.roll_number.asc())
        .all()
    )

    roster = []
    for s in students:
        rec = attendance_map.get(s.id)
        roster.append({
            "student_id": s.id,
            "roll_number": s.roll_number,
            "full_name": s.full_name,
            "email": s.email,
            "attendance_status": rec.status.value if rec else "UNMARKED",
            "od_reason": rec.od_reason if rec else None
        })

    return {
        "timetable_entry_id": entry.id,
        "date": date_str,
        "day_of_week": entry.day_of_week,
        "period_id": entry.period.id,
        "period_number": entry.period.period_number,
        "period_name": entry.period.name,
        "start_time": entry.period.start_time,
        "end_time": entry.period.end_time,
        "subject_code": entry.assignment.subject.code,
        "subject_name": entry.assignment.subject.name,
        "class_id": class_sec.id,
        "class_name": class_sec.name,
        "faculty_name": entry.assignment.display_faculty_name,
        "status": "ALREADY_MARKED" if already_marked else "AVAILABLE",
        "can_mark": True,
        "lock_reason": None,
        "session_id": session_id,
        "already_marked": already_marked,
        "roster": roster
    }


def submit_faculty_attendance(
    db: Session,
    faculty_id: int,
    user_id: int,
    timetable_entry_id: int,
    date_str: str,
    records: List[Any],
    dt: Optional[datetime] = None
) -> Dict[str, Any]:
    """
    Submits attendance for a completed timetable period.
    Strictly verifies:
    - Date window (today or yesterday)
    - Timetable day of week
    - Faculty authorization
    - Period end time (for today)
    - Student enrollment
    Creates or reuses ClassSession with exact class date.
    Deduplicates attendance records and creates an AuditLog.
    """
    if dt is None:
        dt = get_ist_now()

    today_date = dt.date()
    today_date_str = today_date.strftime("%Y-%m-%d")
    yesterday_date = today_date - timedelta(days=1)
    yesterday_date_str = yesterday_date.strftime("%Y-%m-%d")

    # 1. Validate date window strictly
    try:
        req_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid date format. Expected YYYY-MM-DD."
        )

    if req_date > today_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot mark attendance for future dates."
        )

    # 2. Validate timetable entry exists
    entry = db.query(TimetableEntry).filter(TimetableEntry.id == timetable_entry_id).first()
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Timetable slot not found."
        )

    # 3. Validate day of week
    req_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    req_day_name = req_date.strftime("%A")
    if entry.day_of_week.lower() != req_day_name.lower():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Timetable slot #{timetable_entry_id} is scheduled for {entry.day_of_week}, which does not match date {date_str} ({req_day_name})."
        )

    # 4. Validate faculty authorization
    if not entry.assignment or not entry.assignment.is_faculty_authorized(faculty_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not authorized to mark attendance for this class."
        )

    # 5. If date is today, re-validate period end time
    current_time_str = dt.strftime("%H:%M")
    if date_str == today_date_str:
        if current_time_str < entry.period.end_time:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Attendance isn't open yet. This period ends at {format_time_12h(entry.period.end_time)}."
            )

    # 6. Validate all student IDs belong to the class
    class_id = entry.assignment.class_id
    valid_student_ids = {
        s.id for s in db.query(Student.id).filter(
            Student.class_id == class_id,
            Student.is_active == True
        ).all()
    }
    for r in records:
        sid = r.get("student_id") if isinstance(r, dict) else r.student_id
        if sid not in valid_student_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Student ID {sid} is not enrolled in this class."
            )

    # 7. Find or create ClassSession
    existing_session = db.query(ClassSession).filter(
        ClassSession.timetable_entry_id == entry.id,
        ClassSession.date == date_str
    ).first()

    existing_record_count = 0
    if existing_session:
        session = existing_session
        session.status = SessionStatus.COMPLETED
        session.end_timestamp = datetime.now(timezone.utc)
        existing_record_count = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == session.id
        ).count()
    else:
        session = ClassSession(
            timetable_entry_id=entry.id,
            faculty_id=faculty_id,
            date=date_str,
            status=SessionStatus.COMPLETED,
            start_timestamp=datetime.now(timezone.utc),
            end_timestamp=datetime.now(timezone.utc)
        )
        db.add(session)
        db.flush()

    # 8. Upsert attendance records to prevent duplicates
    now_utc = datetime.now(timezone.utc)
    for r in records:
        sid = r.get("student_id") if isinstance(r, dict) else r.student_id
        st_val = r.get("status") if isinstance(r, dict) else r.status
        od_r = r.get("od_reason") if isinstance(r, dict) else getattr(r, "od_reason", None)

        if isinstance(st_val, str):
            st_val = AttendanceStatus(st_val)

        source = RecognitionSource.OD_OVERRIDE if st_val == AttendanceStatus.OD else RecognitionSource.MANUAL

        existing_record = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == session.id,
            AttendanceRecord.student_id == sid
        ).first()

        if existing_record:
            existing_record.status = st_val
            existing_record.od_reason = od_r
            existing_record.recognized_via = source
            existing_record.review_status = ReviewStatus.APPROVED
            existing_record.marked_by_user_id = user_id
            existing_record.marked_at = now_utc
        else:
            rec = AttendanceRecord(
                session_id=session.id,
                student_id=sid,
                status=st_val,
                confidence=100.0,
                recognized_via=source,
                review_status=ReviewStatus.APPROVED,
                od_reason=od_r,
                marked_by_user_id=user_id,
                marked_at=now_utc
            )
            db.add(rec)

    # 9. Audit Logging
    audit_action = "FACULTY_ATTENDANCE_CORRECTED" if existing_record_count > 0 else "FACULTY_ATTENDANCE_SUBMITTED"
    audit_log = AuditLog(
        user_id=user_id,
        action=audit_action,
        target=f"ClassSession #{session.id}",
        details=(
            f"Faculty ID {faculty_id} submitted attendance for Session #{session.id} "
            f"(TT #{entry.id}, {entry.assignment.subject.code}, {entry.assignment.class_section.name}, "
            f"{date_str} P{entry.period.period_number}): {len(records)} students recorded."
        ),
        timestamp=now_utc
    )
    db.add(audit_log)
    db.commit()
    db.refresh(session)

    return {
        "message": "Attendance submitted successfully.",
        "session_id": session.id,
        "date": session.date,
        "period_number": entry.period.period_number,
        "records_count": len(records),
        "status": session.status.value
    }


def get_class_advisor_available_periods(
    db: Session,
    faculty_id: int,
    dt: Optional[datetime] = None
) -> Dict[str, Any]:
    """
    Evaluates periods for the Class Advisor's assigned class:
    - TODAY: completed periods only (current_time >= period end_time)
    - YESTERDAY: all scheduled periods
    - Institutional Lunch Break (12:50 - 13:40): strictly excluded from attendance slots.
    """
    if dt is None:
        dt = get_ist_now()

    today_date = dt.date()
    today_date_str = today_date.strftime("%Y-%m-%d")
    today_day = dt.strftime("%A")
    current_time_str = dt.strftime("%H:%M")

    yesterday_date = today_date - timedelta(days=1)
    yesterday_date_str = yesterday_date.strftime("%Y-%m-%d")
    yesterday_day = yesterday_date.strftime("%A")

    # Find class section where this faculty is class advisor
    class_sec = db.query(ClassSection).filter(ClassSection.class_advisor_id == faculty_id).first()
    if not class_sec:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not assigned as a Class Advisor for any active class."
        )

    def _fetch_entries(day_name: str) -> List[TimetableEntry]:
        return (
            db.query(TimetableEntry)
            .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
            .join(Period, TimetableEntry.period_id == Period.id)
            .filter(
                FacultyAssignment.class_id == class_sec.id,
                TimetableEntry.day_of_week == day_name
            )
            .order_by(Period.period_number.asc())
            .all()
        )

    def _get_entry_status(entry: TimetableEntry, date_str: str, is_yesterday: bool) -> Dict[str, Any]:
        session = db.query(ClassSession).filter(
            ClassSession.timetable_entry_id == entry.id,
            ClassSession.date == date_str
        ).first()

        session_id = session.id if session else None
        has_records = False
        record_count = 0
        if session:
            records = db.query(AttendanceRecord).filter(AttendanceRecord.session_id == session.id).all()
            record_count = len(records)
            has_records = record_count > 0

        start = entry.period.start_time
        end = entry.period.end_time
        period_num = entry.period.period_number
        is_morning = period_num in (1, 2, 3, 4)
        session_type = "MORNING" if is_morning else "AFTERNOON"

        if is_yesterday:
            if has_records:
                status_str = "ALREADY_MARKED"
                can_mark = True
                lock_reason = None
            else:
                status_str = "AVAILABLE"
                can_mark = True
                lock_reason = None
        else:
            if current_time_str >= end:
                if has_records:
                    status_str = "ALREADY_MARKED"
                    can_mark = True
                    lock_reason = None
                else:
                    status_str = "AVAILABLE"
                    can_mark = True
                    lock_reason = None
            else:
                status_str = "LOCKED"
                can_mark = False
                lock_reason = f"Attendance opens after this period ends at {format_time_12h(end)}"

        subject_fac_name = entry.assignment.display_faculty_name if entry.assignment else "Unassigned"

        return {
            "timetable_entry_id": entry.id,
            "period_id": entry.period.id,
            "period_number": period_num,
            "period_name": entry.period.name,
            "start_time": start,
            "end_time": end,
            "session_type": session_type,
            "subject_code": entry.assignment.subject.code if entry.assignment and entry.assignment.subject else "N/A",
            "subject_name": entry.assignment.subject.name if entry.assignment and entry.assignment.subject else "N/A",
            "class_id": class_sec.id,
            "class_name": class_sec.name,
            "date": date_str,
            "day_of_week": entry.day_of_week,
            "subject_faculty_name": subject_fac_name,
            "status": status_str,
            "can_mark": can_mark,
            "lock_reason": lock_reason,
            "session_id": session_id,
            "record_count": record_count
        }

    today_entries = _fetch_entries(today_day)
    yesterday_entries = _fetch_entries(yesterday_day)

    today_periods = [_get_entry_status(e, today_date_str, is_yesterday=False) for e in today_entries]
    yesterday_periods = [_get_entry_status(e, yesterday_date_str, is_yesterday=True) for e in yesterday_entries]

    return {
        "is_class_advisor": True,
        "advised_class": {
            "id": class_sec.id,
            "name": class_sec.name,
            "academic_year": class_sec.academic_year,
            "grade_level": class_sec.grade_level,
        },
        "today_date": today_date_str,
        "today_day": today_day,
        "yesterday_date": yesterday_date_str,
        "yesterday_day": yesterday_day,
        "current_time": current_time_str,
        "day_end_time": "16:10",
        "today_periods": today_periods,
        "yesterday_periods": yesterday_periods,
        "lunch_break": {
            "start_time": "12:50",
            "end_time": "13:40",
            "label": "Lunch Break (12:50 PM - 01:40 PM)",
            "note": "Institutional break — strictly excluded from attendance marking and calculations."
        }
    }


def get_class_advisor_periods_for_date(
    db: Session,
    faculty_id: int,
    date_str: str,
    dt: Optional[datetime] = None
) -> Dict[str, Any]:
    """
    Returns timetable periods for the Class Advisor's advised class on any past or current date.
    Strictly forbids future dates.
    Institutional Lunch Break (12:50 - 13:40) is metadata-indicated and excluded from periods.
    """
    if dt is None:
        dt = get_ist_now()

    today_date = dt.date()
    today_date_str = today_date.strftime("%Y-%m-%d")
    current_time_str = dt.strftime("%H:%M")

    try:
        req_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid date format. Expected YYYY-MM-DD."
        )

    if req_date > today_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot mark attendance for future dates."
        )

    is_today = (date_str == today_date_str)
    day_name = req_date.strftime("%A")

    class_sec = db.query(ClassSection).filter(ClassSection.class_advisor_id == faculty_id).first()
    if not class_sec:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not assigned as a Class Advisor for any active class."
        )

    entries = (
        db.query(TimetableEntry)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .join(Period, TimetableEntry.period_id == Period.id)
        .filter(
            FacultyAssignment.class_id == class_sec.id,
            TimetableEntry.day_of_week == day_name
        )
        .order_by(Period.period_number.asc())
        .all()
    )

    periods = []
    for entry in entries:
        session = db.query(ClassSession).filter(
            ClassSession.timetable_entry_id == entry.id,
            ClassSession.date == date_str
        ).first()

        session_id = session.id if session else None
        has_records = False
        record_count = 0
        if session:
            records = db.query(AttendanceRecord).filter(AttendanceRecord.session_id == session.id).all()
            record_count = len(records)
            has_records = record_count > 0

        start = entry.period.start_time
        end = entry.period.end_time
        period_num = entry.period.period_number
        is_morning = period_num in (1, 2, 3, 4)
        session_type = "MORNING" if is_morning else "AFTERNOON"

        if not is_today:
            if has_records:
                status_str = "ALREADY_MARKED"
                can_mark = True
                lock_reason = None
            else:
                status_str = "AVAILABLE"
                can_mark = True
                lock_reason = None
        else:
            if current_time_str >= end:
                if has_records:
                    status_str = "ALREADY_MARKED"
                    can_mark = True
                    lock_reason = None
                else:
                    status_str = "AVAILABLE"
                    can_mark = True
                    lock_reason = None
            else:
                status_str = "LOCKED"
                can_mark = False
                lock_reason = f"Attendance opens after this period ends at {format_time_12h(end)}"

        subject_fac_name = entry.assignment.display_faculty_name if entry.assignment else "Unassigned"

        periods.append({
            "timetable_entry_id": entry.id,
            "period_id": entry.period.id,
            "period_number": period_num,
            "period_name": entry.period.name,
            "start_time": start,
            "end_time": end,
            "session_type": session_type,
            "subject_code": entry.assignment.subject.code if entry.assignment and entry.assignment.subject else "N/A",
            "subject_name": entry.assignment.subject.name if entry.assignment and entry.assignment.subject else "N/A",
            "class_id": class_sec.id,
            "class_name": class_sec.name,
            "date": date_str,
            "day_of_week": entry.day_of_week,
            "subject_faculty_name": subject_fac_name,
            "status": status_str,
            "can_mark": can_mark,
            "lock_reason": lock_reason,
            "session_id": session_id,
            "record_count": record_count
        })

    return {
        "is_class_advisor": True,
        "advised_class": {
            "id": class_sec.id,
            "name": class_sec.name,
            "academic_year": class_sec.academic_year,
            "grade_level": class_sec.grade_level,
        },
        "date": date_str,
        "day_of_week": day_name,
        "is_today": is_today,
        "periods": periods,
        "lunch_break": {
            "start_time": "12:50",
            "end_time": "13:40",
            "label": "Lunch Break (12:50 PM - 01:40 PM)",
            "note": "Institutional break — strictly excluded from attendance marking and calculations."
        }
    }


def get_class_advisor_attendance_roster(
    db: Session,
    faculty_id: int,
    timetable_entry_id: int,
    date_str: str,
    dt: Optional[datetime] = None
) -> Dict[str, Any]:
    """
    Returns student roster for a timetable period of the advised class.
    Enforces that faculty is the designated Class Advisor for this class section.
    """
    if dt is None:
        dt = get_ist_now()

    today_date = dt.date()
    today_date_str = today_date.strftime("%Y-%m-%d")
    yesterday_date = today_date - timedelta(days=1)
    yesterday_date_str = yesterday_date.strftime("%Y-%m-%d")

    # 1. Validate date window
    try:
        req_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid date format. Expected YYYY-MM-DD."
        )

    if req_date > today_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot mark attendance for future dates."
        )

    # 2. Timetable entry
    entry = db.query(TimetableEntry).filter(TimetableEntry.id == timetable_entry_id).first()
    if not entry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Timetable slot not found.")

    class_sec = entry.assignment.class_section if entry.assignment else None
    if not class_sec:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No class assigned to timetable slot.")

    # 3. Authorization: Faculty MUST be the Class Advisor for this class section
    if class_sec.class_advisor_id != faculty_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"You are not the assigned Class Advisor for {class_sec.name}. Class Advisor access denied."
        )

    # 4. Day of week check
    req_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    req_day_name = req_date.strftime("%A")
    if entry.day_of_week.lower() != req_day_name.lower():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Timetable slot #{timetable_entry_id} is for {entry.day_of_week}, which does not match date {date_str} ({req_day_name})."
        )

    # 5. For today, period must have ended
    current_time_str = dt.strftime("%H:%M")
    if date_str == today_date_str and current_time_str < entry.period.end_time:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Attendance cannot be entered before the period ends at {format_time_12h(entry.period.end_time)}."
        )

    # 6. Existing records
    session = db.query(ClassSession).filter(
        ClassSession.timetable_entry_id == entry.id,
        ClassSession.date == date_str
    ).first()

    attendance_map = {}
    already_marked = False
    session_id = None
    last_updated_at = None

    if session:
        session_id = session.id
        records = db.query(AttendanceRecord).filter(AttendanceRecord.session_id == session.id).all()
        if records:
            already_marked = True
            attendance_map = {r.student_id: r for r in records}
            timestamps = [
                r.updated_at or r.marked_at for r in records if (r.updated_at or r.marked_at)
            ]
            if timestamps:
                last_updated_at = max(timestamps).isoformat()

    # 7. Student roster
    students = (
        db.query(Student)
        .filter(Student.class_id == class_sec.id, Student.is_active == True)
        .order_by(Student.roll_number.asc())
        .all()
    )

    roster = []
    for s in students:
        rec = attendance_map.get(s.id)
        roster.append({
            "student_id": s.id,
            "roll_number": s.roll_number,
            "full_name": s.full_name,
            "email": s.email,
            "attendance_status": rec.status.value if rec else "UNMARKED",
            "od_reason": rec.od_reason if rec else None
        })

    subject_fac_name = entry.assignment.display_faculty_name if entry.assignment else "Unassigned"

    return {
        "timetable_entry_id": entry.id,
        "date": date_str,
        "day_of_week": entry.day_of_week,
        "period_id": entry.period.id,
        "period_number": entry.period.period_number,
        "period_name": entry.period.name,
        "start_time": entry.period.start_time,
        "end_time": entry.period.end_time,
        "subject_code": entry.assignment.subject.code if entry.assignment and entry.assignment.subject else "N/A",
        "subject_name": entry.assignment.subject.name if entry.assignment and entry.assignment.subject else "N/A",
        "class_id": class_sec.id,
        "class_name": class_sec.name,
        "subject_faculty_name": subject_fac_name,
        "status": "ALREADY_MARKED" if already_marked else "AVAILABLE",
        "can_mark": True,
        "session_id": session_id,
        "already_marked": already_marked,
        "last_updated_at": last_updated_at,
        "roster": roster
    }


def submit_class_advisor_attendance(
    db: Session,
    faculty_id: int,
    user_id: int,
    timetable_entry_id: int,
    date_str: str,
    records: List[Any],
    expected_last_updated: Optional[str] = None,
    dt: Optional[datetime] = None
) -> Dict[str, Any]:
    """
    Submits attendance as Class Advisor for any period of their advised class.
    Logs audit trail (CLASS_ADVISOR_ATTENDANCE_ADDED or CLASS_ADVISOR_ATTENDANCE_CORRECTED).
    Detects concurrency conflicts via expected_last_updated.
    """
    if dt is None:
        dt = get_ist_now()

    today_date = dt.date()
    today_date_str = today_date.strftime("%Y-%m-%d")
    yesterday_date = today_date - timedelta(days=1)
    yesterday_date_str = yesterday_date.strftime("%Y-%m-%d")

    # 1. Validate date window
    try:
        req_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid date format. Expected YYYY-MM-DD.")

    if req_date > today_date:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot mark attendance for future dates.")

    # 2. Timetable entry
    entry = db.query(TimetableEntry).filter(TimetableEntry.id == timetable_entry_id).first()
    if not entry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Timetable slot not found.")

    class_sec = entry.assignment.class_section if entry.assignment else None
    if not class_sec:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No class assigned to timetable slot.")

    # 3. Class Advisor RBAC
    if class_sec.class_advisor_id != faculty_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"You are not the assigned Class Advisor for {class_sec.name}."
        )

    # 4. Day of week
    req_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    req_day_name = req_date.strftime("%A")
    if entry.day_of_week.lower() != req_day_name.lower():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Timetable slot is for {entry.day_of_week}, which does not match date {date_str} ({req_day_name})."
        )

    # 5. Period end time for today
    current_time_str = dt.strftime("%H:%M")
    if date_str == today_date_str and current_time_str < entry.period.end_time:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Attendance cannot be entered before the period ends at {format_time_12h(entry.period.end_time)}."
        )

    # 6. Validate student enrollment
    valid_student_ids = {
        s.id for s in db.query(Student.id).filter(
            Student.class_id == class_sec.id,
            Student.is_active == True
        ).all()
    }
    for r in records:
        sid = r.get("student_id") if isinstance(r, dict) else r.student_id
        if sid not in valid_student_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Student ID {sid} is not enrolled in {class_sec.name}."
            )

    # 7. Check existing session and Concurrency
    existing_session = db.query(ClassSession).filter(
        ClassSession.timetable_entry_id == entry.id,
        ClassSession.date == date_str
    ).first()

    now_utc = datetime.now(timezone.utc)
    existing_records = []
    if existing_session:
        existing_records = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == existing_session.id
        ).all()

        # Concurrency check
        if expected_last_updated and existing_records:
            try:
                clean_exp = expected_last_updated.replace('Z', '+00:00')
                exp_dt = datetime.fromisoformat(clean_exp)
                current_latest_dt = max(
                    [r.updated_at or r.marked_at for r in existing_records if (r.updated_at or r.marked_at)] or [datetime.min.replace(tzinfo=timezone.utc)]
                )
                if current_latest_dt.tzinfo is None:
                    current_latest_dt = current_latest_dt.replace(tzinfo=timezone.utc)
                if exp_dt.tzinfo is None:
                    exp_dt = exp_dt.replace(tzinfo=timezone.utc)

                if current_latest_dt > exp_dt + timedelta(seconds=1):
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail="Conflict: This period's attendance was modified concurrently. Please reload the roster and review the latest changes before saving."
                    )
            except HTTPException:
                raise
            except Exception as e:
                logger.warning(f"Class advisor concurrency check parsing failed: {e}")

        session = existing_session
        session.status = SessionStatus.COMPLETED
        session.end_timestamp = now_utc
    else:
        session = ClassSession(
            timetable_entry_id=entry.id,
            faculty_id=entry.assignment.faculty_id or faculty_id,
            date=date_str,
            status=SessionStatus.COMPLETED,
            start_timestamp=now_utc,
            end_timestamp=now_utc
        )
        db.add(session)
        db.flush()

    # 8. Upsert attendance records
    for r in records:
        sid = r.get("student_id") if isinstance(r, dict) else r.student_id
        st_val = r.get("status") if isinstance(r, dict) else r.status
        od_r = r.get("od_reason") if isinstance(r, dict) else getattr(r, "od_reason", None)

        if isinstance(st_val, str):
            st_val = AttendanceStatus(st_val)

        source = RecognitionSource.OD_OVERRIDE if st_val == AttendanceStatus.OD else RecognitionSource.MANUAL

        existing_rec = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == session.id,
            AttendanceRecord.student_id == sid
        ).first()

        if existing_rec:
            existing_rec.status = st_val
            existing_rec.od_reason = od_r
            existing_rec.recognized_via = source
            existing_rec.review_status = ReviewStatus.APPROVED
            existing_rec.marked_by_user_id = user_id
            existing_rec.updated_at = now_utc
        else:
            rec = AttendanceRecord(
                session_id=session.id,
                student_id=sid,
                status=st_val,
                confidence=100.0,
                recognized_via=source,
                review_status=ReviewStatus.APPROVED,
                od_reason=od_r,
                marked_by_user_id=user_id,
                marked_at=now_utc,
                updated_at=now_utc
            )
            db.add(rec)

    # 9. Audit Logging
    audit_action = "CLASS_ADVISOR_ATTENDANCE_CORRECTED" if len(existing_records) > 0 else "CLASS_ADVISOR_ATTENDANCE_ADDED"
    faculty_obj = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    fac_name = faculty_obj.full_name if faculty_obj else str(faculty_id)

    audit_log = AuditLog(
        user_id=user_id,
        action=audit_action,
        target=f"ClassSession #{session.id}",
        details=(
            f"Class Advisor {fac_name} (ID {faculty_id}) saved attendance for {class_sec.name}, "
            f"P{entry.period.period_number} ({entry.assignment.subject.code}) on {date_str}: {len(records)} records."
        ),
        timestamp=now_utc
    )
    db.add(audit_log)
    db.commit()
    db.refresh(session)

    # 10. Compute updated daily summary
    daily_summary = get_class_daily_summary(db, class_sec.id, date_str)

    return {
        "message": f"Attendance successfully saved by Class Advisor for Period {entry.period.period_number}.",
        "session_id": session.id,
        "date": session.date,
        "period_number": entry.period.period_number,
        "records_count": len(records),
        "total_submitted": len(records),
        "updated_at": now_utc.isoformat(),
        "status": session.status.value,
        "daily_summary": daily_summary
    }


def get_class_daily_summary(db: Session, class_id: int, date_str: str) -> Dict[str, Any]:
    """
    Computes daily half-day summary for all students in a class on date_str:
    - Morning: P1-P4
    - Lunch Break: 12:50 - 13:40 (Excluded from calculation)
    - Afternoon: P5-P7
    """
    from app.engines.policy_engine import get_active_policy, derive_daily_half_day_status
    policy = get_active_policy(db)

    class_sec = db.query(ClassSection).filter(ClassSection.id == class_id).first()
    if not class_sec:
        raise HTTPException(status_code=404, detail="Class section not found")

    students = (
        db.query(Student)
        .filter(Student.class_id == class_id, Student.is_active == True)
        .order_by(Student.roll_number.asc())
        .all()
    )

    sessions = (
        db.query(ClassSession)
        .join(TimetableEntry, ClassSession.timetable_entry_id == TimetableEntry.id)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .filter(
            FacultyAssignment.class_id == class_id,
            ClassSession.date == date_str
        )
        .all()
    )

    session_ids = [s.id for s in sessions]
    records = []
    if session_ids:
        records = (
            db.query(AttendanceRecord)
            .filter(AttendanceRecord.session_id.in_(session_ids))
            .all()
        )

    student_records_map = {s.id: [] for s in students}
    for rec in records:
        if rec.student_id in student_records_map:
            pnum = rec.session.timetable_entry.period.period_number if (rec.session and rec.session.timetable_entry and rec.session.timetable_entry.period) else None
            student_records_map[rec.student_id].append({
                "period_number": pnum,
                "status": rec.status.value,
                "od_reason": rec.od_reason
            })

    full_day_present_count = 0
    half_day_present_count = 0
    full_day_absent_count = 0
    od_count = 0
    not_entered_count = 0
    partial_count = 0

    student_summaries = []
    for s in students:
        s_recs = student_records_map.get(s.id, [])
        derived = derive_daily_half_day_status(s_recs, policy)
        daily_res = derived["daily_result"]

        if daily_res == "FULL DAY PRESENT":
            full_day_present_count += 1
        elif daily_res == "HALF-DAY PRESENT":
            half_day_present_count += 1
        elif daily_res == "FULL DAY ABSENT":
            full_day_absent_count += 1
        elif daily_res == "OD":
            od_count += 1
        elif daily_res == "NOT ENTERED":
            not_entered_count += 1
        else:
            partial_count += 1

        student_summaries.append({
            "student_id": s.id,
            "roll_number": s.roll_number,
            "full_name": s.full_name,
            "morning_status": derived["morning"]["status"],
            "morning_text": derived["morning"]["summary_text"],
            "afternoon_status": derived["afternoon"]["status"],
            "afternoon_text": derived["afternoon"]["summary_text"],
            "daily_result": daily_res
        })

    return {
        "class_id": class_sec.id,
        "class_name": class_sec.name,
        "date": date_str,
        "total_students": len(students),
        "full_day_present_count": full_day_present_count,
        "half_day_present_count": half_day_present_count,
        "full_day_absent_count": full_day_absent_count,
        "od_count": od_count,
        "not_entered_count": not_entered_count,
        "partial_count": partial_count,
        "lunch_interval": "12:50 PM - 01:40 PM (Not Counted)",
        "students": student_summaries
    }
