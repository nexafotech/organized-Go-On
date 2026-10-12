from typing import List, Dict, Any, Optional
from datetime import datetime, date, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.user import User, UserRole, Faculty
from app.models.academic import ClassSection, Subject, Period, TimetableEntry, FacultyAssignment
from app.models.student import Student
from app.models.attendance import AttendanceRecord, ClassSession
from app.api.deps import require_faculty
from app.engines.timetable_engine import get_faculty_schedule, get_active_and_upcoming_class, get_ist_now
from app.engines.policy_engine import get_active_policy, derive_daily_half_day_status, _status_counts, _safe_percentage
from app.schemas.faculty_attendance import (
    AvailablePeriodsResponse,
    FacultyAttendanceRosterResponse,
    FacultyAttendanceSubmitRequest,
    FacultyAttendanceSubmitResponse,
    ClassAdvisorAvailablePeriodsResponse,
    ClassAdvisorAttendanceRosterResponse,
    ClassAdvisorAttendanceSubmitRequest,
    ClassAdvisorAttendanceSubmitResponse,
    ClassDailySummaryResponse,
    AdvisedClassInfo,
    LunchBreakInfo,
    AuthorizedSubjectOption,
    AuthorizedClassOption,
    FacultyAuthorizedReportOptionsResponse,
    FacultyStudentAttendanceRow,
    FacultyClassSummaryResponse,
    FacultyStudentReportPeriodItem,
    FacultyStudentReportDateEntry,
    FacultyStudentDetailResponse,
    DateMatrixPeriodHeader,
    DateMatrixStudentRow,
    FacultyDateMatrixResponse,
    HistoricalMatrixDateEntry,
    FacultyHistoricalMatrixResponse,
    FacultyPeriodsForDateResponse,
    ClassAdvisorPeriodsForDateResponse,
)
from app.engines.attendance_engine import (
    get_faculty_available_attendance_periods,
    get_faculty_attendance_roster,
    submit_faculty_attendance,
    get_class_advisor_available_periods,
    get_class_advisor_attendance_roster,
    submit_class_advisor_attendance,
    get_class_daily_summary,
    get_faculty_periods_for_date,
    get_class_advisor_periods_for_date,
)

router = APIRouter(prefix="/faculty", tags=["Faculty Operations"], dependencies=[Depends(require_faculty)])


def _resolve_faculty_id(current_user: User, db: Session) -> int:
    if current_user.role == UserRole.ADMIN and not current_user.faculty_profile:
        faculties = db.query(Faculty).all()
        if not faculties:
            raise HTTPException(status_code=400, detail="No faculty profiles exist")
        return faculties[0].id
    if not current_user.faculty_profile:
        raise HTTPException(status_code=400, detail="Faculty profile not linked to user account")
    return current_user.faculty_profile.id


@router.get("/timetable")
@router.get("/schedule")
def get_my_timetable(
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Returns personalized timetable for logged-in faculty user.
    """
    faculty_id = _resolve_faculty_id(current_user, db)
    faculty_name = current_user.faculty_profile.full_name if current_user.faculty_profile else "Admin View"

    schedule = get_faculty_schedule(db, faculty_id=faculty_id)
    return {
        "faculty_id": faculty_id,
        "faculty_name": faculty_name,
        "timetable": schedule
    }


@router.get("/active-class")
def get_my_active_class(
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Determines active/upcoming class using server-side date, time, and DB timetable.
    """
    faculty_id = _resolve_faculty_id(current_user, db)
    faculty_name = current_user.faculty_profile.full_name if current_user.faculty_profile else "Admin View"

    status_data = get_active_and_upcoming_class(db, faculty_id=faculty_id)
    status_data["faculty_name"] = faculty_name

    # Check if faculty is class advisor
    cs = db.query(ClassSection).filter(ClassSection.class_advisor_id == faculty_id).first()
    status_data["is_class_advisor"] = cs is not None
    status_data["advised_class"] = {
        "id": cs.id,
        "class_id": cs.id,
        "name": cs.name,
        "class_name": cs.name,
        "academic_year": cs.academic_year,
        "grade_level": cs.grade_level,
    } if cs else None

    return status_data


@router.get("/attendance/available-periods", response_model=AvailablePeriodsResponse)
def get_available_attendance_periods(
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Returns timetable periods eligible for attendance marking:
    - Today's completed periods (and active/future periods with lock status)
    - Yesterday's scheduled periods
    Calculated strictly against Asia/Kolkata server time.
    """
    faculty_id = _resolve_faculty_id(current_user, db)
    return get_faculty_available_attendance_periods(db, faculty_id=faculty_id)


@router.get("/attendance/periods-for-date", response_model=FacultyPeriodsForDateResponse)
def get_periods_for_date(
    date: str,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Returns timetable periods for a specific past or current date for authorized faculty.
    Strictly forbids future dates.
    """
    faculty_id = _resolve_faculty_id(current_user, db)
    return get_faculty_periods_for_date(db, faculty_id=faculty_id, date_str=date)


@router.get("/attendance/roster/{timetable_entry_id}", response_model=FacultyAttendanceRosterResponse)
def get_attendance_roster(
    timetable_entry_id: int,
    date: str,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Retrieves authorized student roster for a specific timetable slot and date.
    Strictly verifies:
    - Date is today or yesterday
    - Day of week matches slot
    - Slot has completed (if today)
    - Faculty is authorized
    """
    faculty_id = _resolve_faculty_id(current_user, db)
    return get_faculty_attendance_roster(
        db, faculty_id=faculty_id, timetable_entry_id=timetable_entry_id, date_str=date
    )


@router.post("/attendance/submit", response_model=FacultyAttendanceSubmitResponse)
def submit_attendance(
    payload: FacultyAttendanceSubmitRequest,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Submits attendance records for a completed period (today or yesterday).
    Re-validates authorization, date window, period end time, and student enrollment server-side.
    Creates or reuses ClassSession with exact class date.
    Deduplicates records and writes an AuditLog.
    """
    faculty_id = _resolve_faculty_id(current_user, db)
    return submit_faculty_attendance(
        db=db,
        faculty_id=faculty_id,
        user_id=current_user.id,
        timetable_entry_id=payload.timetable_entry_id,
        date_str=payload.date,
        records=payload.records
    )


# ─────────────────────────────────────────────────────────────
# Class Advisor Operations
# ─────────────────────────────────────────────────────────────

@router.get("/class-advisor/class")
def get_class_advisor_class(
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """Returns the advised class details for the logged-in faculty."""
    faculty_id = _resolve_faculty_id(current_user, db)
    cs = db.query(ClassSection).filter(ClassSection.class_advisor_id == faculty_id).first()
    return {
        "is_class_advisor": cs is not None,
        "advised_class": {
            "id": cs.id,
            "class_id": cs.id,
            "name": cs.name,
            "class_name": cs.name,
            "academic_year": cs.academic_year,
            "grade_level": cs.grade_level,
        } if cs else None
    }


@router.get("/class-advisor/available-periods", response_model=ClassAdvisorAvailablePeriodsResponse)
def get_class_advisor_periods(
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Returns timetable periods for the faculty's advised class:
    - Today's completed periods
    - Yesterday's periods
    - Lunch break excluded
    """
    faculty_id = _resolve_faculty_id(current_user, db)
    return get_class_advisor_available_periods(db, faculty_id=faculty_id)


@router.get("/class-advisor/periods-for-date", response_model=ClassAdvisorPeriodsForDateResponse)
def get_class_advisor_periods_for_date_endpoint(
    date: str,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Returns timetable periods for the Class Advisor's advised class on any past or current date.
    Strictly forbids future dates.
    Institutional Lunch Break (12:50 - 13:40) is metadata-indicated and excluded from periods.
    """
    faculty_id = _resolve_faculty_id(current_user, db)
    return get_class_advisor_periods_for_date(db, faculty_id=faculty_id, date_str=date)


@router.get("/class-advisor/roster/{timetable_entry_id}", response_model=ClassAdvisorAttendanceRosterResponse)
def get_class_advisor_roster(
    timetable_entry_id: int,
    date: str,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Returns student roster for a specific period of the advised class.
    Enforces Class Advisor authorization and concurrency tracking.
    """
    faculty_id = _resolve_faculty_id(current_user, db)
    return get_class_advisor_attendance_roster(
        db, faculty_id=faculty_id, timetable_entry_id=timetable_entry_id, date_str=date
    )


@router.post("/class-advisor/submit", response_model=ClassAdvisorAttendanceSubmitResponse)
def submit_class_advisor_attendance_endpoint(
    payload: ClassAdvisorAttendanceSubmitRequest,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Saves or edits period attendance as Class Advisor.
    Supports concurrency control via expected_last_updated.
    Returns updated session information and daily summary.
    """
    faculty_id = _resolve_faculty_id(current_user, db)
    return submit_class_advisor_attendance(
        db=db,
        faculty_id=faculty_id,
        user_id=current_user.id,
        timetable_entry_id=payload.timetable_entry_id,
        date_str=payload.date,
        records=payload.records,
        expected_last_updated=payload.expected_last_updated
    )


@router.get("/class-advisor/daily-summary", response_model=ClassDailySummaryResponse)
def get_daily_class_summary_endpoint(
    date: str,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Returns the daily half-day summary (Morning P1-P4, Afternoon P5-P7, Lunch excluded)
    for the faculty's advised class on the specified date.
    """
    faculty_id = _resolve_faculty_id(current_user, db)
    cs = db.query(ClassSection).filter(ClassSection.class_advisor_id == faculty_id).first()
    if not cs:
        raise HTTPException(status_code=403, detail="You are not assigned as Class Advisor for any class.")
    return get_class_daily_summary(db, class_id=cs.id, date_str=date)


# ─────────────────────────────────────────────────────────────
# Faculty Attendance View & Report Endpoints
# ─────────────────────────────────────────────────────────────

@router.get("/reports/authorized-options", response_model=FacultyAuthorizedReportOptionsResponse)
def get_faculty_authorized_report_options(
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Returns list of authorized classes and subjects for attendance reporting.
    - Admins can view ALL classes and ALL subjects.
    - Class Advisors can view their advised class and ALL subjects taught in it.
    - Subject Faculty can view only classes and subjects they have teaching assignments for.
    """
    is_admin = (current_user.role == UserRole.ADMIN)
    faculty_id = _resolve_faculty_id(current_user, db) if not is_admin else 0
    faculty = db.query(Faculty).filter(Faculty.id == faculty_id).first() if faculty_id else None
    faculty_name = faculty.full_name if faculty else (current_user.username or "Administrator")

    ist_today = get_ist_now().date().isoformat()
    classes_dict = {}

    if is_admin:
        # Admin gets all classes and all subjects taught in each class
        all_classes = db.query(ClassSection).order_by(ClassSection.id.asc()).all()
        for cs in all_classes:
            sub_ids = (
                db.query(FacultyAssignment.subject_id)
                .filter(FacultyAssignment.class_id == cs.id)
                .distinct()
                .all()
            )
            subjects = []
            for (s_id,) in sub_ids:
                sub = db.query(Subject).filter(Subject.id == s_id).first()
                if sub:
                    subjects.append(AuthorizedSubjectOption(
                        id=sub.id,
                        code=sub.code,
                        name=sub.name,
                        is_teaching=True
                    ))
            subjects.sort(key=lambda s: s.code)
            classes_dict[cs.id] = AuthorizedClassOption(
                id=cs.id,
                name=cs.name,
                grade_level=cs.grade_level,
                academic_year=cs.academic_year,
                is_advisor_for_class=True,
                subjects=subjects
            )

        earliest_date = db.query(func.min(ClassSession.date)).scalar()
        attendance_start_date = earliest_date if earliest_date else ist_today

        return FacultyAuthorizedReportOptionsResponse(
            faculty_id=0,
            faculty_name=faculty_name,
            is_class_advisor=True,
            advised_class=None,
            classes=sorted(list(classes_dict.values()), key=lambda c: c.id),
            current_date=ist_today,
            attendance_start_date=attendance_start_date
        )

    # Regular Faculty or Class Advisor
    cs_advised = db.query(ClassSection).filter(ClassSection.class_advisor_id == faculty_id).first()
    is_advisor = cs_advised is not None

    advised_info = None
    if cs_advised:
        advised_info = AdvisedClassInfo(
            id=cs_advised.id,
            name=cs_advised.name,
            class_id=cs_advised.id,
            class_name=cs_advised.name,
            academic_year=cs_advised.academic_year,
            grade_level=cs_advised.grade_level
        )

    # If Class Advisor, add advised class with ALL subjects taught in that class
    if cs_advised:
        sub_ids = db.query(FacultyAssignment.subject_id).filter(
            FacultyAssignment.class_id == cs_advised.id
        ).distinct().all()
        subjects = []
        for (s_id,) in sub_ids:
            sub = db.query(Subject).filter(Subject.id == s_id).first()
            if sub:
                is_teach = db.query(FacultyAssignment).filter(
                    FacultyAssignment.faculty_id == faculty_id,
                    FacultyAssignment.class_id == cs_advised.id,
                    FacultyAssignment.subject_id == s_id
                ).first() is not None
                subjects.append(AuthorizedSubjectOption(
                    id=sub.id,
                    code=sub.code,
                    name=sub.name,
                    is_teaching=is_teach
                ))
        subjects.sort(key=lambda s: s.code)
        classes_dict[cs_advised.id] = AuthorizedClassOption(
            id=cs_advised.id,
            name=cs_advised.name,
            grade_level=cs_advised.grade_level,
            academic_year=cs_advised.academic_year,
            is_advisor_for_class=True,
            subjects=subjects
        )

    # Add other teaching assignments (where faculty is NOT advisor: show ONLY subjects they teach!)
    assignments = db.query(FacultyAssignment).filter(FacultyAssignment.faculty_id == faculty_id).all()
    for a in assignments:
        cid = a.class_id
        if cid not in classes_dict:
            cs = db.query(ClassSection).filter(ClassSection.id == cid).first()
            if cs:
                classes_dict[cid] = AuthorizedClassOption(
                    id=cs.id,
                    name=cs.name,
                    grade_level=cs.grade_level,
                    academic_year=cs.academic_year,
                    is_advisor_for_class=False,
                    subjects=[]
                )
        sub = db.query(Subject).filter(Subject.id == a.subject_id).first()
        if sub and cid in classes_dict:
            # If not advisor for this class, only include subjects the faculty actually teaches
            if not classes_dict[cid].is_advisor_for_class:
                existing_sub_ids = {s.id for s in classes_dict[cid].subjects}
                if sub.id not in existing_sub_ids:
                    classes_dict[cid].subjects.append(AuthorizedSubjectOption(
                        id=sub.id,
                        code=sub.code,
                        name=sub.name,
                        is_teaching=True
                    ))

    for c in classes_dict.values():
        c.subjects.sort(key=lambda s: s.code)

    classes_list = sorted(list(classes_dict.values()), key=lambda c: c.id)

    # Earliest attendance session date for this faculty's authorized scope
    q_earliest = (
        db.query(func.min(ClassSession.date))
        .join(TimetableEntry, ClassSession.timetable_entry_id == TimetableEntry.id)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
    )
    if cs_advised:
        q_earliest = q_earliest.filter(
            or_(
                FacultyAssignment.faculty_id == faculty_id,
                FacultyAssignment.class_id == cs_advised.id
            )
        )
    else:
        q_earliest = q_earliest.filter(FacultyAssignment.faculty_id == faculty_id)

    earliest_date = q_earliest.scalar()
    attendance_start_date = earliest_date if earliest_date else ist_today

    return FacultyAuthorizedReportOptionsResponse(
        faculty_id=faculty_id,
        faculty_name=faculty_name,
        is_class_advisor=is_advisor,
        advised_class=advised_info,
        classes=classes_list,
        current_date=ist_today,
        attendance_start_date=attendance_start_date
    )


@router.get("/reports/class-summary", response_model=FacultyClassSummaryResponse)
def get_faculty_class_summary(
    class_id: int,
    subject_id: Optional[int] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Returns student-by-student attendance summary for an authorized class section.
    Can be filtered by subject and date range.
    Enforces strict RBAC:
    - Class Advisors can view all subjects for their advised class.
    - Subject Faculty can only view subjects they are assigned to teach.
    """
    faculty_id = _resolve_faculty_id(current_user, db)
    cs = db.query(ClassSection).filter(ClassSection.id == class_id).first()
    if not cs:
        raise HTTPException(status_code=404, detail="Class section not found.")

    is_advisor = (cs.class_advisor_id == faculty_id)

    # Authorization verification
    assigned_sub_ids = set()
    if not is_advisor:
        assignments = db.query(FacultyAssignment).filter(
            FacultyAssignment.faculty_id == faculty_id,
            FacultyAssignment.class_id == class_id
        ).all()
        if not assignments:
            raise HTTPException(
                status_code=403,
                detail="Not authorized: You do not have teaching assignments in this class."
            )
        assigned_sub_ids = {a.subject_id for a in assignments}
        if subject_id and subject_id not in assigned_sub_ids:
            raise HTTPException(
                status_code=403,
                detail="Not authorized: You do not teach this subject in this class."
            )

    policy = get_active_policy(db)
    students = (
        db.query(Student)
        .filter(Student.class_id == class_id, Student.is_active == True)
        .order_by(Student.roll_number.asc())
        .all()
    )

    # Filter class sessions
    session_query = (
        db.query(ClassSession)
        .join(TimetableEntry, ClassSession.timetable_entry_id == TimetableEntry.id)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .filter(FacultyAssignment.class_id == class_id)
    )

    if subject_id:
        session_query = session_query.filter(FacultyAssignment.subject_id == subject_id)
    elif not is_advisor:
        session_query = session_query.filter(FacultyAssignment.subject_id.in_(assigned_sub_ids))

    if start_date:
        session_query = session_query.filter(ClassSession.date >= start_date)
    if end_date:
        session_query = session_query.filter(ClassSession.date <= end_date)

    sessions = session_query.all()
    session_ids = [s.id for s in sessions]

    student_rows = []
    total_class_periods = len(sessions)
    agg_present = 0
    agg_absent = 0
    agg_od = 0
    agg_total = 0

    if session_ids:
        records = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id.in_(session_ids)
        ).all()
        rec_by_student = {}
        for r in records:
            rec_by_student.setdefault(r.student_id, []).append(r)

        for st in students:
            st_recs = rec_by_student.get(st.id, [])
            counts = _status_counts(st_recs, policy)
            pct = _safe_percentage(counts["present"], counts["total"])
            student_rows.append(FacultyStudentAttendanceRow(
                student_id=st.id,
                roll_number=st.roll_number,
                full_name=st.full_name,
                total=counts["total"],
                present=counts["present"],
                absent=counts["absent"],
                od=counts["od"],
                percentage=pct
            ))
            agg_present += counts["present"]
            agg_absent += counts["absent"]
            agg_od += counts["od"]
            agg_total += counts["total"]
    else:
        for st in students:
            student_rows.append(FacultyStudentAttendanceRow(
                student_id=st.id,
                roll_number=st.roll_number,
                full_name=st.full_name,
                total=0,
                present=0,
                absent=0,
                od=0,
                percentage=0.0
            ))

    overall_pct = _safe_percentage(agg_present, agg_total)

    subject_code = None
    subject_name = None
    if subject_id:
        sub = db.query(Subject).filter(Subject.id == subject_id).first()
        if sub:
            subject_code = sub.code
            subject_name = sub.name

    return FacultyClassSummaryResponse(
        class_id=class_id,
        class_name=cs.name,
        subject_id=subject_id,
        subject_code=subject_code,
        subject_name=subject_name,
        is_class_advisor_scope=is_advisor and (subject_id is None),
        total_periods=total_class_periods,
        present=agg_present,
        absent=agg_absent,
        od=agg_od,
        percentage=overall_pct,
        students=student_rows
    )


@router.get("/reports/student-detail", response_model=FacultyStudentDetailResponse)
def get_faculty_student_detail(
    student_id: int,
    subject_id: Optional[int] = None,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Returns detailed attendance history (period-by-period & date-by-date)
    for a specific student within the faculty's authorized scope.
    """
    faculty_id = _resolve_faculty_id(current_user, db)
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    cs = student.class_section
    class_name = cs.name if cs else "Unknown Class"
    is_advisor = (cs is not None and cs.class_advisor_id == faculty_id)

    # Authorization check
    assigned_sub_ids = set()
    if not is_advisor:
        assignments = db.query(FacultyAssignment).filter(
            FacultyAssignment.faculty_id == faculty_id,
            FacultyAssignment.class_id == student.class_id
        ).all()
        if not assignments:
            raise HTTPException(
                status_code=403,
                detail="Not authorized: You do not teach this student's class."
            )
        assigned_sub_ids = {a.subject_id for a in assignments}
        if subject_id and subject_id not in assigned_sub_ids:
            raise HTTPException(
                status_code=403,
                detail="Not authorized: You do not teach this subject to this student."
            )

    policy = get_active_policy(db)

    # Query attendance records
    rec_query = (
        db.query(AttendanceRecord)
        .join(ClassSession, AttendanceRecord.session_id == ClassSession.id)
        .join(TimetableEntry, ClassSession.timetable_entry_id == TimetableEntry.id)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .filter(AttendanceRecord.student_id == student_id)
        .order_by(ClassSession.date.asc())
    )

    if subject_id:
        rec_query = rec_query.filter(FacultyAssignment.subject_id == subject_id)
    elif not is_advisor:
        rec_query = rec_query.filter(FacultyAssignment.subject_id.in_(assigned_sub_ids))

    records = rec_query.all()
    counts = _status_counts(records, policy)
    pct = _safe_percentage(counts["present"], counts["total"])

    # Group by date
    date_map = {}
    for rec in records:
        session = rec.session
        date_str = session.date
        tt = session.timetable_entry
        period = tt.period if tt else None
        asgn = tt.assignment if tt else None
        subj = asgn.subject if asgn else None
        fac = asgn.faculty if asgn else None

        if date_str not in date_map:
            date_map[date_str] = {"date": date_str, "periods": []}

        date_map[date_str]["periods"].append(FacultyStudentReportPeriodItem(
            period_number=period.period_number if period else 0,
            period_name=period.name if period else "Period",
            subject_code=subj.code if subj else None,
            subject_name=subj.name if subj else None,
            faculty_name=fac.full_name if fac else None,
            status=rec.status.value,
            od_reason=rec.od_reason
        ))

    date_entries = []
    for date_str in sorted(date_map.keys()):
        d = date_map[date_str]
        d["periods"].sort(key=lambda p: p.period_number)

        day_derived = derive_daily_half_day_status(
            [{"period_number": p.period_number, "status": p.status, "od_reason": p.od_reason} for p in d["periods"]],
            policy
        )
        date_entries.append(FacultyStudentReportDateEntry(
            date=date_str,
            morning_status=day_derived["morning"]["status"],
            morning_summary=day_derived["morning"]["summary_text"],
            afternoon_status=day_derived["afternoon"]["status"],
            afternoon_summary=day_derived["afternoon"]["summary_text"],
            daily_result=day_derived["daily_result"],
            lunch_interval="12:50 PM - 01:40 PM (Not Counted)",
            periods=d["periods"]
        ))

    subject_code = None
    subject_name = None
    if subject_id:
        sub = db.query(Subject).filter(Subject.id == subject_id).first()
        if sub:
            subject_code = sub.code
            subject_name = sub.name

    return FacultyStudentDetailResponse(
        student_id=student.id,
        roll_number=student.roll_number,
        full_name=student.full_name,
        class_id=student.class_id or 0,
        class_name=class_name,
        subject_id=subject_id,
        subject_code=subject_code,
        subject_name=subject_name,
        total=counts["total"],
        present=counts["present"],
        absent=counts["absent"],
        od=counts["od"],
        percentage=pct,
        date_wise=date_entries
    )


@router.get("/reports/date-matrix", response_model=FacultyDateMatrixResponse)
def get_faculty_date_matrix(
    class_id: int,
    date: str,
    subject_id: Optional[int] = None,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Returns the date-wise attendance matrix scoped strictly by authorization:
    - Admin: full access to class (all periods P1-P7), optionally filtered by subject.
    - Class Advisor: full access to advised class (all periods P1-P7), optionally filtered by subject.
    - Subject Faculty: STRICTLY authorized subject/class periods only.
      Unrelated subjects and other faculty's periods are NEVER returned.
    """
    is_admin = (current_user.role == UserRole.ADMIN)
    faculty_id = _resolve_faculty_id(current_user, db) if not is_admin else 0
    cs = db.query(ClassSection).filter(ClassSection.id == class_id).first()
    if not cs:
        raise HTTPException(status_code=404, detail="Class section not found.")

    is_advisor = is_admin or (cs.class_advisor_id == faculty_id)

    authorized_sub_ids = set()
    is_class_advisor_scope = False

    if is_advisor:
        if subject_id:
            sub = db.query(Subject).filter(Subject.id == subject_id).first()
            if not sub:
                raise HTTPException(status_code=404, detail="Subject not found.")
            authorized_sub_ids = {subject_id}
            is_class_advisor_scope = False
        else:
            is_class_advisor_scope = True
    else:
        assignments = db.query(FacultyAssignment).filter(
            FacultyAssignment.faculty_id == faculty_id,
            FacultyAssignment.class_id == class_id
        ).all()
        if not assignments:
            raise HTTPException(
                status_code=403,
                detail="Not authorized: You are neither Class Advisor nor an assigned faculty for this class."
            )
        faculty_sub_ids = {a.subject_id for a in assignments}
        if subject_id:
            if subject_id not in faculty_sub_ids:
                raise HTTPException(
                    status_code=403,
                    detail="Not authorized: You do not teach this subject in this class."
                )
            authorized_sub_ids = {subject_id}
        else:
            authorized_sub_ids = faculty_sub_ids
        is_class_advisor_scope = False

    try:
        dt = datetime.strptime(date, "%Y-%m-%d")
        day_name = dt.strftime("%A")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid date format. Expected YYYY-MM-DD.")

    ist_today = get_ist_now().date()
    if dt.date() > ist_today:
        raise HTTPException(status_code=400, detail="Matrix date cannot be in the future.")

    policy = get_active_policy(db)
    students = (
        db.query(Student)
        .filter(Student.class_id == class_id, Student.is_active == True)
        .order_by(Student.roll_number.asc())
        .all()
    )

    period_headers = []
    session_by_period = {}

    if is_class_advisor_scope:
        # Full class advisor matrix: all P1-P7
        periods = db.query(Period).order_by(Period.period_number.asc()).all()
        for p in periods:
            tt = (
                db.query(TimetableEntry)
                .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
                .filter(
                    FacultyAssignment.class_id == class_id,
                    func.upper(TimetableEntry.day_of_week) == day_name.upper(),
                    TimetableEntry.period_id == p.id
                )
                .first()
            )
            if tt:
                asgn = tt.assignment
                sub = asgn.subject if asgn else None
                fac = asgn.faculty if asgn else None
                sess = db.query(ClassSession).filter(
                    ClassSession.timetable_entry_id == tt.id,
                    ClassSession.date == date
                ).first()
                present_count = 0
                absent_count = 0
                od_count = 0
                total_marked = 0
                status_str = "PENDING"
                if sess:
                    session_by_period[p.period_number] = sess
                    for r in sess.attendance_records:
                        if r.status.value == "PRESENT":
                            present_count += 1
                        elif r.status.value == "ABSENT":
                            absent_count += 1
                        elif r.status.value == "OD":
                            od_count += 1
                    total_marked = present_count + absent_count + od_count
                    status_str = "MARKED" if total_marked > 0 else "PENDING"

                period_headers.append(DateMatrixPeriodHeader(
                    period_number=p.period_number,
                    period_name=p.name,
                    start_time=p.start_time,
                    end_time=p.end_time,
                    subject_code=sub.code if sub else None,
                    subject_name=sub.name if sub else None,
                    faculty_name=fac.full_name if fac else None,
                    status=status_str,
                    present_count=present_count,
                    absent_count=absent_count,
                    od_count=od_count,
                    total_marked=total_marked
                ))
            else:
                period_headers.append(DateMatrixPeriodHeader(
                    period_number=p.period_number,
                    period_name=p.name,
                    start_time=p.start_time,
                    end_time=p.end_time,
                    status="NO_CLASS"
                ))
    else:
        # Subject Faculty scope: ONLY authorized subject periods!
        tt_query = (
            db.query(TimetableEntry)
            .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
            .join(Period, TimetableEntry.period_id == Period.id)
            .filter(
                FacultyAssignment.class_id == class_id,
                FacultyAssignment.subject_id.in_(authorized_sub_ids),
                func.upper(TimetableEntry.day_of_week) == day_name.upper()
            )
        )
        if not is_admin and not is_advisor:
            tt_query = tt_query.filter(FacultyAssignment.faculty_id == faculty_id)

        tts = tt_query.order_by(Period.period_number.asc()).all()

        for tt in tts:
            p = tt.period
            asgn = tt.assignment
            sub = asgn.subject if asgn else None
            fac = asgn.faculty if asgn else None
            sess = db.query(ClassSession).filter(
                ClassSession.timetable_entry_id == tt.id,
                ClassSession.date == date
            ).first()
            present_count = 0
            absent_count = 0
            od_count = 0
            total_marked = 0
            status_str = "PENDING"
            if sess:
                session_by_period[p.period_number] = sess
                for r in sess.attendance_records:
                    if r.status.value == "PRESENT":
                        present_count += 1
                    elif r.status.value == "ABSENT":
                        absent_count += 1
                    elif r.status.value == "OD":
                        od_count += 1
                total_marked = present_count + absent_count + od_count
                status_str = "MARKED" if total_marked > 0 else "PENDING"

            period_headers.append(DateMatrixPeriodHeader(
                period_number=p.period_number,
                period_name=p.name,
                start_time=p.start_time,
                end_time=p.end_time,
                subject_code=sub.code if sub else None,
                subject_name=sub.name if sub else None,
                faculty_name=fac.full_name if fac else None,
                status=status_str,
                present_count=present_count,
                absent_count=absent_count,
                od_count=od_count,
                total_marked=total_marked
            ))

    found_session_ids = [s.id for s in session_by_period.values()]
    all_records = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id.in_(found_session_ids)
    ).all() if found_session_ids else []
    rec_map = {(r.session_id, r.student_id): r for r in all_records}

    student_rows = []
    for st in students:
        p_statuses = {}
        st_period_list = []
        for hdr in period_headers:
            p_num = hdr.period_number
            sess = session_by_period.get(p_num)
            if sess:
                rec = rec_map.get((sess.id, st.id))
                st_val = rec.status.value if rec else "NOT_ENTERED"
                od_r = rec.od_reason if rec else None
            else:
                st_val = "NOT_ENTERED"
                od_r = None

            p_statuses[p_num] = st_val
            st_period_list.append({"period_number": p_num, "status": st_val, "od_reason": od_r})

        if is_class_advisor_scope:
            hd = derive_daily_half_day_status(st_period_list, policy)
            m_stat = hd["morning"]["status"]
            a_stat = hd["afternoon"]["status"]
            d_res = hd["daily_result"]
        else:
            if any(it["status"] == "PRESENT" for it in st_period_list):
                d_res = "PRESENT"
            elif any(it["status"] == "OD" for it in st_period_list):
                d_res = "OD"
            elif any(it["status"] == "ABSENT" for it in st_period_list):
                d_res = "ABSENT"
            else:
                d_res = "NOT_ENTERED"
            m_stat = d_res
            a_stat = d_res

        student_rows.append(DateMatrixStudentRow(
            student_id=st.id,
            roll_number=st.roll_number,
            full_name=st.full_name,
            period_statuses=p_statuses,
            morning_status=m_stat,
            afternoon_status=a_stat,
            daily_result=d_res
        ))

    sub_code_out = None
    sub_name_out = None
    sub_id_out = None
    if len(authorized_sub_ids) == 1:
        single_sub_id = list(authorized_sub_ids)[0]
        sub_obj = db.query(Subject).filter(Subject.id == single_sub_id).first()
        if sub_obj:
            sub_id_out = sub_obj.id
            sub_code_out = sub_obj.code
            sub_name_out = sub_obj.name

    return FacultyDateMatrixResponse(
        class_id=class_id,
        class_name=cs.name,
        subject_id=sub_id_out,
        subject_code=sub_code_out,
        subject_name=sub_name_out,
        is_class_advisor_scope=is_class_advisor_scope,
        date=date,
        day_of_week=day_name,
        periods=period_headers,
        lunch_break=LunchBreakInfo(),
        students=student_rows
    )


@router.get("/reports/historical-matrix", response_model=FacultyHistoricalMatrixResponse)
def get_faculty_historical_matrix(
    class_id: int,
    subject_id: Optional[int] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Returns historical date-by-date attendance matrix covering start_date to end_date:
    - Class Advisor / Admin: view full class across all periods P1-P7.
    - Subject Faculty: view ONLY authorized subject/class periods. Unrelated subjects are never returned.
    """
    is_admin = (current_user.role == UserRole.ADMIN)
    faculty_id = _resolve_faculty_id(current_user, db) if not is_admin else 0
    cs = db.query(ClassSection).filter(ClassSection.id == class_id).first()
    if not cs:
        raise HTTPException(status_code=404, detail="Class section not found.")

    is_advisor = is_admin or (cs.class_advisor_id == faculty_id)

    authorized_sub_ids = set()
    is_class_advisor_scope = False

    if is_advisor:
        if subject_id:
            sub = db.query(Subject).filter(Subject.id == subject_id).first()
            if not sub:
                raise HTTPException(status_code=404, detail="Subject not found.")
            authorized_sub_ids = {subject_id}
            is_class_advisor_scope = False
        else:
            is_class_advisor_scope = True
    else:
        assignments = db.query(FacultyAssignment).filter(
            FacultyAssignment.faculty_id == faculty_id,
            FacultyAssignment.class_id == class_id
        ).all()
        if not assignments:
            raise HTTPException(
                status_code=403,
                detail="Not authorized: You are neither Class Advisor nor an assigned faculty for this class."
            )
        faculty_sub_ids = {a.subject_id for a in assignments}
        if subject_id:
            if subject_id not in faculty_sub_ids:
                raise HTTPException(
                    status_code=403,
                    detail="Not authorized: You do not teach this subject in this class."
                )
            authorized_sub_ids = {subject_id}
        else:
            authorized_sub_ids = faculty_sub_ids
        is_class_advisor_scope = False

    # Date range bounds determination
    ist_today = get_ist_now().date()
    ist_today_str = ist_today.isoformat()

    # Determine attendance_start_date from earliest session
    q_earliest = (
        db.query(func.min(ClassSession.date))
        .join(TimetableEntry, ClassSession.timetable_entry_id == TimetableEntry.id)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .filter(FacultyAssignment.class_id == class_id)
    )
    if not is_class_advisor_scope:
        q_earliest = q_earliest.filter(FacultyAssignment.subject_id.in_(authorized_sub_ids))

    earliest_session_date = q_earliest.scalar()
    attendance_start_date = earliest_session_date if earliest_session_date else ist_today_str

    effective_start = start_date if (start_date and start_date.strip()) else attendance_start_date
    effective_end = end_date if (end_date and end_date.strip()) else ist_today_str

    try:
        s_dt = datetime.strptime(effective_start, "%Y-%m-%d").date()
        e_dt = datetime.strptime(effective_end, "%Y-%m-%d").date()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid date format. Expected YYYY-MM-DD.")

    if e_dt > ist_today:
        raise HTTPException(status_code=400, detail="End date cannot be in the future.")
    if s_dt > e_dt:
        raise HTTPException(status_code=400, detail="Start date cannot be after end date.")

    policy = get_active_policy(db)
    students = (
        db.query(Student)
        .filter(Student.class_id == class_id, Student.is_active == True)
        .order_by(Student.roll_number.asc())
        .all()
    )

    all_periods = db.query(Period).order_by(Period.period_number.asc()).all()

    # Generate dates
    cur_date = s_dt
    date_entries = []
    all_sess_ids = []

    while cur_date <= e_dt:
        cur_date_str = cur_date.isoformat()
        day_name = cur_date.strftime("%A")

        period_headers = []
        session_by_period = {}

        if is_class_advisor_scope:
            for p in all_periods:
                tt = (
                    db.query(TimetableEntry)
                    .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
                    .filter(
                        FacultyAssignment.class_id == class_id,
                        func.upper(TimetableEntry.day_of_week) == day_name.upper(),
                        TimetableEntry.period_id == p.id
                    )
                    .first()
                )
                if tt:
                    asgn = tt.assignment
                    sub = asgn.subject if asgn else None
                    fac = asgn.faculty if asgn else None
                    sess = db.query(ClassSession).filter(
                        ClassSession.timetable_entry_id == tt.id,
                        ClassSession.date == cur_date_str
                    ).first()
                    p_cnt, a_cnt, od_cnt, tot = 0, 0, 0, 0
                    stat = "PENDING"
                    if sess:
                        session_by_period[p.period_number] = sess
                        all_sess_ids.append(sess.id)
                        for r in sess.attendance_records:
                            if r.status.value == "PRESENT":
                                p_cnt += 1
                            elif r.status.value == "ABSENT":
                                a_cnt += 1
                            elif r.status.value == "OD":
                                od_cnt += 1
                        tot = p_cnt + a_cnt + od_cnt
                        stat = "MARKED" if tot > 0 else "PENDING"

                    period_headers.append(DateMatrixPeriodHeader(
                        period_number=p.period_number,
                        period_name=p.name,
                        start_time=p.start_time,
                        end_time=p.end_time,
                        subject_code=sub.code if sub else None,
                        subject_name=sub.name if sub else None,
                        faculty_name=fac.full_name if fac else None,
                        status=stat,
                        present_count=p_cnt,
                        absent_count=a_cnt,
                        od_count=od_cnt,
                        total_marked=tot
                    ))
                else:
                    period_headers.append(DateMatrixPeriodHeader(
                        period_number=p.period_number,
                        period_name=p.name,
                        start_time=p.start_time,
                        end_time=p.end_time,
                        status="NO_CLASS"
                    ))
        else:
            # Subject Faculty scope: ONLY authorized periods
            tt_query = (
                db.query(TimetableEntry)
                .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
                .join(Period, TimetableEntry.period_id == Period.id)
                .filter(
                    FacultyAssignment.class_id == class_id,
                    FacultyAssignment.subject_id.in_(authorized_sub_ids),
                    func.upper(TimetableEntry.day_of_week) == day_name.upper()
                )
            )
            if not is_admin and not is_advisor:
                tt_query = tt_query.filter(FacultyAssignment.faculty_id == faculty_id)

            tts = tt_query.order_by(Period.period_number.asc()).all()

            for tt in tts:
                p = tt.period
                asgn = tt.assignment
                sub = asgn.subject if asgn else None
                fac = asgn.faculty if asgn else None
                sess = db.query(ClassSession).filter(
                    ClassSession.timetable_entry_id == tt.id,
                    ClassSession.date == cur_date_str
                ).first()
                p_cnt, a_cnt, od_cnt, tot = 0, 0, 0, 0
                stat = "PENDING"
                if sess:
                    session_by_period[p.period_number] = sess
                    all_sess_ids.append(sess.id)
                    for r in sess.attendance_records:
                        if r.status.value == "PRESENT":
                            p_cnt += 1
                        elif r.status.value == "ABSENT":
                            a_cnt += 1
                        elif r.status.value == "OD":
                            od_cnt += 1
                    tot = p_cnt + a_cnt + od_cnt
                    stat = "MARKED" if tot > 0 else "PENDING"

                period_headers.append(DateMatrixPeriodHeader(
                    period_number=p.period_number,
                    period_name=p.name,
                    start_time=p.start_time,
                    end_time=p.end_time,
                    subject_code=sub.code if sub else None,
                    subject_name=sub.name if sub else None,
                    faculty_name=fac.full_name if fac else None,
                    status=stat,
                    present_count=p_cnt,
                    absent_count=a_cnt,
                    od_count=od_cnt,
                    total_marked=tot
                ))

        # Query records for this date
        f_s_ids = [s.id for s in session_by_period.values()]
        records = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id.in_(f_s_ids)
        ).all() if f_s_ids else []
        rec_map = {(r.session_id, r.student_id): r for r in records}

        has_classes = any(h.status != "NO_CLASS" for h in period_headers) if is_class_advisor_scope else len(period_headers) > 0

        st_rows = []
        if has_classes:
            for st in students:
                p_statuses = {}
                st_period_list = []
                for hdr in period_headers:
                    p_num = hdr.period_number
                    sess = session_by_period.get(p_num)
                    if sess:
                        rec = rec_map.get((sess.id, st.id))
                        st_val = rec.status.value if rec else "NOT_ENTERED"
                        od_r = rec.od_reason if rec else None
                    else:
                        st_val = "NOT_ENTERED"
                        od_r = None

                    p_statuses[p_num] = st_val
                    st_period_list.append({"period_number": p_num, "status": st_val, "od_reason": od_r})

                if is_class_advisor_scope:
                    hd = derive_daily_half_day_status(st_period_list, policy)
                    m_stat = hd["morning"]["status"]
                    a_stat = hd["afternoon"]["status"]
                    d_res = hd["daily_result"]
                else:
                    if any(it["status"] == "PRESENT" for it in st_period_list):
                        d_res = "PRESENT"
                    elif any(it["status"] == "OD" for it in st_period_list):
                        d_res = "OD"
                    elif any(it["status"] == "ABSENT" for it in st_period_list):
                        d_res = "ABSENT"
                    else:
                        d_res = "NOT_ENTERED"
                    m_stat = d_res
                    a_stat = d_res

                st_rows.append(DateMatrixStudentRow(
                    student_id=st.id,
                    roll_number=st.roll_number,
                    full_name=st.full_name,
                    period_statuses=p_statuses,
                    morning_status=m_stat,
                    afternoon_status=a_stat,
                    daily_result=d_res
                ))

        date_entries.append(HistoricalMatrixDateEntry(
            date=cur_date_str,
            day_of_week=day_name,
            periods=period_headers,
            lunch_break=LunchBreakInfo(),
            students=st_rows,
            has_scheduled_classes=has_classes
        ))

        cur_date += timedelta(days=1)

    # Compute student summary across all sessions in this historical matrix
    all_matrix_records = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id.in_(all_sess_ids)
    ).all() if all_sess_ids else []
    records_by_student = {}
    for r in all_matrix_records:
        records_by_student.setdefault(r.student_id, []).append(r)

    student_summary_rows = []
    for st in students:
        s_recs = records_by_student.get(st.id, [])
        counts = _status_counts(s_recs, policy)
        pct = _safe_percentage(counts["present"], counts["total"])
        student_summary_rows.append(FacultyStudentAttendanceRow(
            student_id=st.id,
            roll_number=st.roll_number,
            full_name=st.full_name,
            total=counts["total"],
            present=counts["present"],
            absent=counts["absent"],
            od=counts["od"],
            percentage=pct
        ))

    sub_code_out = None
    sub_name_out = None
    sub_id_out = None
    if len(authorized_sub_ids) == 1:
        single_sub_id = list(authorized_sub_ids)[0]
        sub_obj = db.query(Subject).filter(Subject.id == single_sub_id).first()
        if sub_obj:
            sub_id_out = sub_obj.id
            sub_code_out = sub_obj.code
            sub_name_out = sub_obj.name

    return FacultyHistoricalMatrixResponse(
        class_id=class_id,
        class_name=cs.name,
        subject_id=sub_id_out,
        subject_code=sub_code_out,
        subject_name=sub_name_out,
        is_class_advisor_scope=is_class_advisor_scope,
        attendance_start_date=attendance_start_date,
        current_date=ist_today_str,
        start_date=effective_start,
        end_date=effective_end,
        total_dates=len(date_entries),
        dates=date_entries,
        students=student_summary_rows
    )


