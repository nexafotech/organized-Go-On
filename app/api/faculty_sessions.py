"""
M4: Extended Faculty Sessions API with OD marking support.
OD is a first-class attendance status — not simply "present".
Faculty can mark individual or bulk OD within their own active session only.
"""

from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.user import User, UserRole, Faculty
from app.models.attendance import AttendanceStatus, AttendanceRecord, RecognitionSource, ClassSession, SessionStatus
from app.models.audit import AuditLog
from app.models.policy import AttendancePolicy
from app.schemas.student_auth import ODMarkRequest, BulkODRequest
from app.api.deps import require_faculty
from app.engines.attendance_engine import (
    start_class_session,
    get_session_details_with_roster,
    record_manual_attendance,
    complete_class_session
)
from app.engines.policy_engine import get_active_policy

router = APIRouter(prefix="/faculty/sessions", tags=["Faculty Sessions"], dependencies=[Depends(require_faculty)])


class MarkAttendanceRequest(BaseModel):
    student_id: int
    status: AttendanceStatus  # PRESENT, ABSENT, or OD
    od_reason: Optional[str] = None


def _add_audit(db: Session, actor_user_id: int, action: str, details: str):
    log = AuditLog(user_id=actor_user_id, action=action, details=details)
    db.add(log)


def _validate_session_ownership(db: Session, session_id: int, faculty_id: int) -> ClassSession:
    """Validate that the session exists and belongs to or is authorized for the faculty."""
    session = db.query(ClassSession).filter(ClassSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    if session.faculty_id != faculty_id:
        is_auth = (
            session.timetable_entry
            and session.timetable_entry.assignment
            and session.timetable_entry.assignment.is_faculty_authorized(faculty_id)
        )
        if not is_auth:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You are not authorized to manage attendance for this timetable slot."
            )
    if session.status != SessionStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session is not ACTIVE"
        )
    return session


def _validate_student_in_session(db: Session, session: ClassSession, student_id: int):
    """Ensure the student belongs to the class for this session."""
    from app.models.student import Student
    from app.models.academic import TimetableEntry, FacultyAssignment

    student = db.query(Student).filter(Student.id == student_id, Student.is_active == True).first()
    if not student:
        raise HTTPException(status_code=404, detail=f"Student {student_id} not found or not active")

    # Resolve class via timetable entry
    tt = session.timetable_entry
    if tt and tt.assignment:
        class_id = tt.assignment.class_id
        if student.class_id != class_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Student {student_id} is not enrolled in this session's class"
            )


# ─────────────────────────────────────────────────────────────────────────────
# Existing endpoints (preserved from M1/M2/M3)
# ─────────────────────────────────────────────────────────────────────────────

class StartSessionRequest(BaseModel):
    timetable_entry_id: Optional[int] = None


@router.post("/start")
def faculty_start_session(
    data: Optional[StartSessionRequest] = None,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """Starts an attendance session for the faculty's current active class slot or specified slot."""
    if not current_user.faculty_profile:
        raise HTTPException(status_code=400, detail="Faculty profile not linked")

    entry_id = data.timetable_entry_id if data else None
    session = start_class_session(db, faculty_id=current_user.faculty_profile.id, timetable_entry_id=entry_id)
    return {
        "message": "Attendance session started successfully",
        "session_id": session.id,
        "status": session.status.value,
        "date": session.date
    }

@router.get("/active")
def faculty_get_active_session(
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """Retrieves active session and roster if one is running."""
    if not current_user.faculty_profile:
        raise HTTPException(status_code=400, detail="Faculty profile not linked")

    faculty_id = current_user.faculty_profile.id
    active_session = db.query(ClassSession).filter(
        ClassSession.faculty_id == faculty_id,
        ClassSession.status == SessionStatus.ACTIVE
    ).first()

    if not active_session:
        from app.models.academic import TimetableEntry, FacultyAssignment, assignment_authorized_faculty
        from sqlalchemy import or_
        active_session = (
            db.query(ClassSession)
            .join(TimetableEntry, ClassSession.timetable_entry_id == TimetableEntry.id)
            .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
            .outerjoin(assignment_authorized_faculty, assignment_authorized_faculty.c.assignment_id == FacultyAssignment.id)
            .filter(
                ClassSession.status == SessionStatus.ACTIVE,
                or_(
                    FacultyAssignment.faculty_id == faculty_id,
                    assignment_authorized_faculty.c.faculty_id == faculty_id
                )
            )
            .first()
        )

    if not active_session:
        return {"has_active_session": False, "session": None}

    details = get_session_details_with_roster(db, session_id=active_session.id, faculty_id=faculty_id)
    return {"has_active_session": True, "session": details}

@router.get("/{session_id}")
def faculty_get_session_details(
    session_id: int,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """Gets details and roster for a specific session owned by the faculty."""
    if not current_user.faculty_profile:
        raise HTTPException(status_code=400, detail="Faculty profile not linked")

    return get_session_details_with_roster(
        db, session_id=session_id, faculty_id=current_user.faculty_profile.id
    )

@router.post("/{session_id}/attendance")
def faculty_mark_attendance(
    session_id: int,
    data: MarkAttendanceRequest,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Marks a student PRESENT, ABSENT, or OD in an active session.
    OD is a first-class status — stored separately from PRESENT.
    """
    if not current_user.faculty_profile:
        raise HTTPException(status_code=400, detail="Faculty profile not linked")

    faculty_id = current_user.faculty_profile.id

    # For OD: check policy allows faculty to mark OD
    if data.status == AttendanceStatus.OD:
        policy = get_active_policy(db)
        if not policy.od_enabled:
            raise HTTPException(status_code=400, detail="OD marking is disabled by policy")
        if not policy.od_faculty_can_mark:
            raise HTTPException(status_code=403, detail="Faculty is not allowed to mark OD by policy")
        if policy.od_require_reason and not data.od_reason:
            raise HTTPException(status_code=400, detail="OD reason is required by policy")

    # Use record_manual_attendance for PRESENT/ABSENT (preserves M1/M2/M3 behavior)
    if data.status in [AttendanceStatus.PRESENT, AttendanceStatus.ABSENT]:
        record = record_manual_attendance(
            db, session_id=session_id, student_id=data.student_id,
            status_val=data.status, faculty_id=faculty_id
        )
        return {
            "message": "Attendance marked successfully",
            "record_id": record.id,
            "student_id": record.student_id,
            "status": record.status.value,
            "marked_at": record.marked_at.isoformat()
        }

    # For OD: custom handling to store od_reason
    session = _validate_session_ownership(db, session_id, faculty_id)
    _validate_student_in_session(db, session, data.student_id)

    # Check for existing record (upsert)
    existing = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id == session_id,
        AttendanceRecord.student_id == data.student_id
    ).first()

    if existing:
        existing.status = AttendanceStatus.OD
        existing.od_reason = data.od_reason
        existing.recognized_via = RecognitionSource.OD_OVERRIDE
        existing.marked_by_user_id = current_user.id
        record = existing
    else:
        record = AttendanceRecord(
            session_id=session_id,
            student_id=data.student_id,
            status=AttendanceStatus.OD,
            od_reason=data.od_reason,
            recognized_via=RecognitionSource.OD_OVERRIDE,
            marked_by_user_id=current_user.id,
        )
        db.add(record)

    _add_audit(db, current_user.id, "MARK_OD",
               f"Faculty {faculty_id} marked OD for student {data.student_id} in session {session_id}")
    db.commit()
    db.refresh(record)

    return {
        "message": "OD marked successfully",
        "record_id": record.id,
        "student_id": record.student_id,
        "status": record.status.value,
        "od_reason": record.od_reason,
        "marked_at": record.marked_at.isoformat()
    }


# ─────────────────────────────────────────────────────────────────────────────
# M4: Dedicated OD endpoint — single or bulk
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/{session_id}/od")
def faculty_mark_od(
    session_id: int,
    data: BulkODRequest,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Mark one or multiple students as OD for an active session.
    Faculty can only mark OD in their own active session.
    Students must be enrolled in the session's class.

    OD is NOT the same as PRESENT — it is stored separately.
    """
    if not current_user.faculty_profile:
        raise HTTPException(status_code=400, detail="Faculty profile not linked")

    faculty_id = current_user.faculty_profile.id
    policy = get_active_policy(db)

    if not policy.od_enabled:
        raise HTTPException(status_code=400, detail="OD is disabled by attendance policy")
    if not policy.od_faculty_can_mark:
        raise HTTPException(status_code=403, detail="Faculty is not permitted to mark OD per policy")
    if policy.od_require_reason and not data.od_reason:
        raise HTTPException(status_code=400, detail="OD reason is required by policy")

    # Validate session ownership and active status
    session = _validate_session_ownership(db, session_id, faculty_id)

    if len(data.student_ids) > 1 and not policy.od_allow_multiple_periods:
        raise HTTPException(status_code=400, detail="Bulk OD across multiple students not allowed by policy")

    results = []
    for student_id in data.student_ids:
        _validate_student_in_session(db, session, student_id)

        # Upsert: update if exists, create if not
        existing = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == session_id,
            AttendanceRecord.student_id == student_id
        ).first()

        if existing:
            existing.status = AttendanceStatus.OD
            existing.od_reason = data.od_reason
            existing.recognized_via = RecognitionSource.OD_OVERRIDE
            existing.marked_by_user_id = current_user.id
            record = existing
        else:
            record = AttendanceRecord(
                session_id=session_id,
                student_id=student_id,
                status=AttendanceStatus.OD,
                od_reason=data.od_reason,
                recognized_via=RecognitionSource.OD_OVERRIDE,
                marked_by_user_id=current_user.id,
            )
            db.add(record)

        results.append({
            "student_id": student_id,
            "status": "OD",
            "od_reason": data.od_reason,
        })

    _add_audit(db, current_user.id, "MARK_BULK_OD",
               f"Faculty {faculty_id} marked OD for {len(data.student_ids)} students in session {session_id}. Reason: {data.od_reason}")
    db.commit()

    return {
        "message": f"OD marked for {len(data.student_ids)} student(s)",
        "session_id": session_id,
        "od_reason": data.od_reason,
        "results": results,
    }


@router.post("/{session_id}/complete")
def faculty_complete_session(
    session_id: int,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """Completes the session, transitioning it to COMPLETED status."""
    if not current_user.faculty_profile:
        raise HTTPException(status_code=400, detail="Faculty profile not linked")

    session = complete_class_session(
        db, session_id=session_id, faculty_id=current_user.faculty_profile.id
    )

    return {
        "message": "Attendance session completed successfully",
        "session_id": session.id,
        "status": session.status.value,
        "end_timestamp": session.end_timestamp.isoformat() if session.end_timestamp else None
    }
