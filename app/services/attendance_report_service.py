"""
Date-range attendance report dataset (Phase 9).

ONE builder produces an ``AttendanceRangeReport``; the JSON preview endpoint,
the PDF renderer and the Excel renderer all consume that same object. No
attendance arithmetic lives in the renderers or in Flutter.

Reused existing project logic (not re-implemented):
  * ``get_active_policy`` / ``_status_counts`` / ``_safe_percentage`` from
    ``app.engines.policy_engine``  -> the percentage follows the active policy
    exactly like the existing Class Summary / Historical Matrix reports.
  * Authorization semantics mirror the existing ``/faculty/reports/*`` routes:
    Admin & the class's Class Advisor see every subject of the class; subject
    faculty see only classes/subjects they are assigned to teach.

Data rules:
  * Only persisted ``attendance_records`` are read. A missing record is never an
    ABSENT, and NOT_ENTERED is never converted to ABSENT.
  * Present / Absent / OD are kept as three separate counts (OD is NOT merged
    into Present in the visible counts). Only the *percentage* uses the active
    policy (default: OD counted as present).
  * Break / lunch are not timetable periods (P1-P7 only) so they can never
    appear in the data.
  * Biometric tables and data/student_faces are never touched.
"""
from __future__ import annotations

import logging
import re
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Dict, List, NamedTuple, Optional, Set, Tuple

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.config import settings
from app.engines.policy_engine import (
    get_active_policy,
    _status_counts,
    _safe_percentage,
)
from app.engines.timetable_engine import get_ist_now
from app.models.academic import (
    ClassSection,
    FacultyAssignment,
    Period,
    Subject,
    TimetableEntry,
)
from app.models.attendance import AttendanceRecord, AttendanceStatus, ClassSession
from app.models.student import Student
from app.models.user import User, UserRole

logger = logging.getLogger("attendance.report")

# Hard limits that keep generation bounded ("large report" protection).
MAX_RANGE_DAYS = 186            # ~6 months, inclusive
MAX_PDF_DETAIL_ROWS = 30000     # PDF only; Excel has no row cap within the range limit

_MARKED_STATUSES = (
    AttendanceStatus.PRESENT,
    AttendanceStatus.ABSENT,
    AttendanceStatus.OD,
)


# ─────────────────────────────────────────────────────────────
# Dataset types
# ─────────────────────────────────────────────────────────────

@dataclass
class StudentSummaryRow:
    roll_number: str
    full_name: str
    present: int
    absent: int
    od: int
    total_marked: int
    percentage: Optional[float]  # None => no marked entries in range (NOT 0%)


@dataclass
class DetailRow:
    date: date
    period_number: int
    period_name: str
    subject_code: str
    subject_name: str
    roll_number: str
    full_name: str
    status: str  # persisted status value, e.g. PRESENT / ABSENT / OD / NOT_ENTERED


@dataclass
class PeriodSummaryRow:
    date: date
    period_number: int
    period_name: str
    subject_code: str
    subject_name: str
    present: int
    absent: int
    od: int
    total_marked: int


@dataclass
class AttendanceRangeReport:
    institution: str
    class_name: str
    subject_label: str
    subject_code: Optional[str]
    from_date: date
    to_date: date
    generated_at: datetime
    scope_note: Optional[str]
    percentage_basis: str
    student_count: int
    present: int
    absent: int
    od: int
    total_marked: int
    percentage: Optional[float]
    has_records: bool
    summary: List[StudentSummaryRow] = field(default_factory=list)
    details: List[DetailRow] = field(default_factory=list)
    period_summary: List[PeriodSummaryRow] = field(default_factory=list)


@dataclass
class ReportScope:
    class_section: ClassSection
    subject: Optional[Subject]
    authorized_subject_ids: Optional[Set[int]]  # None => every subject of the class
    is_full_class_scope: bool
    scope_note: Optional[str]


class _RecView(NamedTuple):
    """Minimal object exposing ``.status`` for the existing ``_status_counts``."""
    status: AttendanceStatus


# ─────────────────────────────────────────────────────────────
# Validation + authorization
# ─────────────────────────────────────────────────────────────

def parse_and_validate_range(
    from_date: str,
    to_date: str,
    today: Optional[date] = None,
) -> Tuple[date, date]:
    """Validate an inclusive date range. Never swaps dates silently."""
    today = today or get_ist_now().date()
    try:
        f = datetime.strptime((from_date or "").strip(), "%Y-%m-%d").date()
        t = datetime.strptime((to_date or "").strip(), "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Expected YYYY-MM-DD.")

    if f > t:
        raise HTTPException(status_code=400, detail="From date cannot be after To date.")
    if t > today:
        raise HTTPException(
            status_code=400,
            detail="To date cannot be in the future. Attendance can only be reported up to today.",
        )
    if (t - f).days + 1 > MAX_RANGE_DAYS:
        raise HTTPException(
            status_code=400,
            detail=f"Date range is too large. Please select at most {MAX_RANGE_DAYS} days.",
        )
    return f, t


def resolve_report_scope(
    db: Session,
    current_user: User,
    class_id: int,
    subject_id: Optional[int],
) -> ReportScope:
    """
    Authorization is decided here, server-side, from the authenticated user.
    class_id / subject_id supplied by the client are never trusted.
    """
    cs = db.query(ClassSection).filter(ClassSection.id == class_id).first()
    if not cs:
        raise HTTPException(status_code=404, detail="Class section not found.")

    is_admin = current_user.role == UserRole.ADMIN
    faculty_id: Optional[int] = None
    if not is_admin:
        profile = current_user.faculty_profile
        if not profile:
            raise HTTPException(status_code=400, detail="Faculty profile not linked to user account")
        faculty_id = profile.id

    is_full_scope = is_admin or (faculty_id is not None and cs.class_advisor_id == faculty_id)

    subject: Optional[Subject] = None
    if subject_id is not None:
        subject = db.query(Subject).filter(Subject.id == subject_id).first()

    if is_full_scope:
        if subject_id is not None:
            if subject is None:
                raise HTTPException(status_code=404, detail="Subject not found.")
            taught = (
                db.query(FacultyAssignment.id)
                .filter(
                    FacultyAssignment.class_id == class_id,
                    FacultyAssignment.subject_id == subject_id,
                )
                .first()
            )
            if not taught:
                raise HTTPException(status_code=404, detail="This subject is not taught in the selected class.")
            return ReportScope(cs, subject, {subject_id}, True, None)
        return ReportScope(cs, None, None, True, None)

    assignments = (
        db.query(FacultyAssignment)
        .filter(FacultyAssignment.faculty_id == faculty_id, FacultyAssignment.class_id == class_id)
        .all()
    )
    if not assignments:
        raise HTTPException(
            status_code=403,
            detail="Not authorized: You do not have teaching assignments in this class.",
        )
    assigned = {a.subject_id for a in assignments}
    if subject_id is not None:
        if subject_id not in assigned:
            raise HTTPException(
                status_code=403,
                detail="Not authorized: You do not teach this subject in this class.",
            )
        return ReportScope(cs, subject, {subject_id}, False, None)
    return ReportScope(
        cs, None, assigned, False,
        "Limited to the subjects you teach in this class.",
    )


# ─────────────────────────────────────────────────────────────
# Dataset builder (bulk queries only: no per-student / per-session queries)
# ─────────────────────────────────────────────────────────────

def calculate_policy_percentage(present: int, absent: int, od: int, policy) -> Optional[float]:
    """Calculate percentage strictly according to active policy's OD mode and marked records."""
    mode = getattr(policy, "od_calculation_mode", "COUNT_AS_PRESENT")
    total_marked = present + absent + od
    if mode == "EXCLUDE_FROM_DENOMINATOR":
        denom = present + absent
        if denom == 0:
            return None
        return round((present / denom) * 100.0, 2)
    elif mode == "COUNT_AS_PRESENT":
        if total_marked == 0:
            return None
        return round(((present + od) / total_marked) * 100.0, 2)
    else:  # COUNT_SEPARATELY
        if total_marked == 0:
            return None
        return round((present / total_marked) * 100.0, 2)


def _percentage_basis(policy) -> str:
    mode = getattr(policy, "od_calculation_mode", "COUNT_AS_PRESENT")
    if mode == "COUNT_AS_PRESENT":
        return "Attendance % = (Present + OD) / Total Marked. OD is counted as present for the percentage, per the active attendance policy."
    if mode == "EXCLUDE_FROM_DENOMINATOR":
        return "Attendance % = Present / (Present + Absent). OD entries are excluded from the percentage, per the active attendance policy."
    return "Attendance % = Present / Total Marked. OD counts in the total but not as present, per the active attendance policy."


def build_attendance_range_report(
    db: Session,
    scope: ReportScope,
    from_dt: date,
    to_dt: date,
    generated_at: Optional[datetime] = None,
    include_details: bool = True,
) -> AttendanceRangeReport:
    cs = scope.class_section
    policy = get_active_policy(db)  # 1 query (+ possible default insert)

    # Query 1: active students of the class
    students = (
        db.query(Student.id, Student.roll_number, Student.full_name)
        .filter(Student.class_id == cs.id, Student.is_active == True)  # noqa: E712
        .order_by(Student.roll_number.asc())
        .all()
    )

    # Query 2: every persisted attendance record in range, in ONE joined query
    q = (
        db.query(
            ClassSession.date,
            Period.period_number,
            Period.name,
            Subject.code,
            Subject.name,
            Student.id,
            AttendanceRecord.status,
        )
        .select_from(AttendanceRecord)
        .join(ClassSession, AttendanceRecord.session_id == ClassSession.id)
        .join(TimetableEntry, ClassSession.timetable_entry_id == TimetableEntry.id)
        .join(Period, TimetableEntry.period_id == Period.id)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .join(Subject, FacultyAssignment.subject_id == Subject.id)
        .join(Student, AttendanceRecord.student_id == Student.id)
        .filter(
            FacultyAssignment.class_id == cs.id,
            Student.class_id == cs.id,
            Student.is_active == True,  # noqa: E712
            ClassSession.date >= from_dt.isoformat(),
            ClassSession.date <= to_dt.isoformat(),
        )
    )
    if scope.authorized_subject_ids is not None:
        q = q.filter(FacultyAssignment.subject_id.in_(scope.authorized_subject_ids))
    rows = q.all()

    by_student: Dict[int, List[_RecView]] = defaultdict(list)
    pure: Dict[int, Dict[str, int]] = defaultdict(lambda: {"P": 0, "A": 0, "OD": 0})
    period_groups: Dict[Tuple[str, int, str], Dict[str, object]] = {}
    detail_raw: List[Tuple[str, int, str, str, str, int, str]] = []

    for (d_str, p_num, p_name, s_code, s_name, st_id, status) in rows:
        by_student[st_id].append(_RecView(status))
        if status == AttendanceStatus.PRESENT:
            pure[st_id]["P"] += 1
        elif status == AttendanceStatus.ABSENT:
            pure[st_id]["A"] += 1
        elif status == AttendanceStatus.OD:
            pure[st_id]["OD"] += 1

        if status in _MARKED_STATUSES:
            key = (d_str, p_num, s_code)
            g = period_groups.get(key)
            if g is None:
                g = {"name": p_name, "subject_name": s_name, "P": 0, "A": 0, "OD": 0}
                period_groups[key] = g
            bucket = "P" if status == AttendanceStatus.PRESENT else "A" if status == AttendanceStatus.ABSENT else "OD"
            g[bucket] = int(g[bucket]) + 1  # type: ignore[arg-type]

        if include_details:
            detail_raw.append((d_str, p_num, p_name, s_code, s_name, st_id, status.value))

    # Student-wise summary: pure counts + policy-based percentage (existing helpers)
    student_lookup = {sid: (roll, name) for sid, roll, name in students}
    summary: List[StudentSummaryRow] = []
    agg_p = agg_a = agg_od = 0
    for sid, roll, name in students:
        c = pure.get(sid, {"P": 0, "A": 0, "OD": 0})
        total_marked = c["P"] + c["A"] + c["OD"]
        pct = calculate_policy_percentage(c["P"], c["A"], c["OD"], policy) if total_marked > 0 else None
        summary.append(StudentSummaryRow(
            roll_number=roll, full_name=name,
            present=c["P"], absent=c["A"], od=c["OD"],
            total_marked=total_marked, percentage=pct,
        ))
        agg_p += c["P"]
        agg_a += c["A"]
        agg_od += c["OD"]

    total_marked_all = agg_p + agg_a + agg_od
    overall_pct: Optional[float] = (
        calculate_policy_percentage(agg_p, agg_a, agg_od, policy) if total_marked_all > 0 else None
    )

    details: List[DetailRow] = []
    if include_details:
        for (d_str, p_num, p_name, s_code, s_name, st_id, status_val) in detail_raw:
            roll, name = student_lookup[st_id]
            details.append(DetailRow(
                date=datetime.strptime(d_str, "%Y-%m-%d").date(),
                period_number=p_num, period_name=p_name,
                subject_code=s_code, subject_name=s_name,
                roll_number=roll, full_name=name, status=status_val,
            ))
        details.sort(key=lambda r: (r.date, r.period_number, r.subject_code, r.roll_number))

    period_summary: List[PeriodSummaryRow] = []
    for (d_str, p_num, s_code), g in period_groups.items():
        p, a, od = int(g["P"]), int(g["A"]), int(g["OD"])  # type: ignore[arg-type]
        period_summary.append(PeriodSummaryRow(
            date=datetime.strptime(d_str, "%Y-%m-%d").date(),
            period_number=p_num, period_name=str(g["name"]),
            subject_code=s_code, subject_name=str(g["subject_name"]),
            present=p, absent=a, od=od, total_marked=p + a + od,
        ))
    period_summary.sort(key=lambda r: (r.date, r.period_number, r.subject_code))

    subject_label = "All Subjects"
    subject_code = None
    if scope.subject is not None:
        subject_label = f"{scope.subject.code} - {scope.subject.name}"
        subject_code = scope.subject.code

    report = AttendanceRangeReport(
        institution=settings.PROJECT_NAME,
        class_name=cs.name,
        subject_label=subject_label,
        subject_code=subject_code,
        from_date=from_dt,
        to_date=to_dt,
        generated_at=generated_at or get_ist_now().replace(tzinfo=None),
        scope_note=scope.scope_note,
        percentage_basis=_percentage_basis(policy),
        student_count=len(students),
        present=agg_p, absent=agg_a, od=agg_od,
        total_marked=total_marked_all,
        percentage=overall_pct,
        has_records=total_marked_all > 0,
        summary=summary,
        details=details,
        period_summary=period_summary,
    )
    logger.info(
        "attendance range report built class_id=%s subject=%s range=%s..%s students=%d marked=%d detail_rows=%d",
        cs.id, subject_code or "ALL", from_dt, to_dt, len(students), total_marked_all, len(details),
    )
    return report


# ─────────────────────────────────────────────────────────────
# Presentation helpers shared by both renderers
# ─────────────────────────────────────────────────────────────

def status_label(status: str) -> str:
    return status.replace("_", " ")


def format_date_dmy(d: date) -> str:
    return d.strftime("%d-%m-%Y")


def sanitize_filename_part(value: str, max_len: int = 40) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9]+", "_", value or "").strip("_")
    return cleaned[:max_len] or "report"


def build_report_filename(report: AttendanceRangeReport, extension: str) -> str:
    parts = ["attendance_report", sanitize_filename_part(report.class_name)]
    if report.subject_code:
        parts.append(sanitize_filename_part(report.subject_code, 20))
    parts.append(f"{report.from_date.isoformat()}_to_{report.to_date.isoformat()}")
    return "_".join(parts) + f".{extension.lstrip('.')}"
