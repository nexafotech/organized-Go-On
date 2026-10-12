from typing import List, Optional
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.user import User, Faculty
from app.models.student import Student
from app.models.academic import ClassSection, Subject, TimetableEntry, FacultyAssignment
from app.models.attendance import (
    ClassSession, AttendanceRecord, AttendanceStatus, SessionStatus,
    RecognitionSource, ReviewStatus
)
from app.models.audit import AuditLog
from app.api.deps import require_admin
from app.engines.attendance_engine import get_session_details_with_roster, admin_correct_attendance
from app.schemas.academic import (
    ClassSessionCreate, ClassSessionUpdate, ClassSessionOut,
    AttendanceRecordOut, AttendanceManualCreate, AttendanceUpdate
)

router = APIRouter(prefix="/admin", tags=["Admin Sessions & Audit"], dependencies=[Depends(require_admin)])


class AdminCorrectionRequest(BaseModel):
    student_id: int
    new_status: AttendanceStatus
    reason: str


def _build_attendance_out(rec: AttendanceRecord) -> AttendanceRecordOut:
    sess = rec.session
    tt = sess.timetable_entry if sess else None
    assign = tt.assignment if tt else None
    st = rec.student

    return AttendanceRecordOut(
        id=rec.id,
        session_id=rec.session_id,
        student_id=rec.student_id,
        student_roll=st.roll_number if st else None,
        student_name=st.full_name if st else None,
        class_name=assign.class_section.name if (assign and assign.class_section) else (st.class_section.name if (st and st.class_section) else None),
        subject_code=assign.subject.code if (assign and assign.subject) else None,
        subject_name=assign.subject.name if (assign and assign.subject) else None,
        session_date=sess.date if sess else None,
        status=rec.status.value if hasattr(rec.status, "value") else str(rec.status),
        confidence=rec.confidence,
        recognized_via=rec.recognized_via.value if hasattr(rec.recognized_via, "value") else str(rec.recognized_via),
        review_status=rec.review_status.value if hasattr(rec.review_status, "value") else str(rec.review_status),
        od_reason=rec.od_reason,
        marked_by_name=f"User #{rec.marked_by_user_id}" if rec.marked_by_user_id else None,
        marked_at=rec.marked_at.isoformat() if rec.marked_at else None,
    )


# ==========================================
# ATTENDANCE RECORDS MANAGEMENT
# ==========================================

@router.get("/attendance", response_model=List[AttendanceRecordOut])
def admin_list_attendance(
    student_id: Optional[int] = None,
    class_id: Optional[int] = None,
    subject_id: Optional[int] = None,
    date: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    session_id: Optional[int] = None,
    status: Optional[str] = None,
    limit: int = 200,
    offset: int = 0,
    db: Session = Depends(get_db)
):
    """Admin endpoint to query and filter attendance records across classes, subjects, dates, and students."""
    query = db.query(AttendanceRecord).join(ClassSession, AttendanceRecord.session_id == ClassSession.id)

    if student_id is not None:
        query = query.filter(AttendanceRecord.student_id == student_id)
    if session_id is not None:
        query = query.filter(AttendanceRecord.session_id == session_id)
    if date:
        query = query.filter(ClassSession.date == date)
    if date_from:
        query = query.filter(ClassSession.date >= date_from)
    if date_to:
        query = query.filter(ClassSession.date <= date_to)
    if status:
        try:
            st_enum = AttendanceStatus(status.upper())
            query = query.filter(AttendanceRecord.status == st_enum)
        except ValueError:
            pass

    if class_id is not None or subject_id is not None:
        query = query.outerjoin(TimetableEntry, ClassSession.timetable_entry_id == TimetableEntry.id).outerjoin(
            FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id
        )
        if class_id is not None:
            query = query.filter(FacultyAssignment.class_id == class_id)
        if subject_id is not None:
            query = query.filter(FacultyAssignment.subject_id == subject_id)

    records = query.order_by(AttendanceRecord.id.desc()).offset(offset).limit(limit).all()
    return [_build_attendance_out(r) for r in records]


@router.post("/attendance/manual", response_model=AttendanceRecordOut, status_code=status.HTTP_201_CREATED)
def admin_manual_create_attendance(
    data: AttendanceManualCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Admin manually adds or updates an attendance record."""
    sess = db.query(ClassSession).filter(ClassSession.id == data.session_id).first()
    if not sess:
        raise HTTPException(status_code=404, detail=f"Session ID {data.session_id} not found")
    st = db.query(Student).filter(Student.id == data.student_id).first()
    if not st:
        raise HTTPException(status_code=404, detail=f"Student ID {data.student_id} not found")

    try:
        status_enum = AttendanceStatus(data.status.upper())
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid attendance status '{data.status}'")

    existing = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id == data.session_id,
        AttendanceRecord.student_id == data.student_id
    ).first()

    if existing:
        old_status = existing.status.value
        existing.status = status_enum
        existing.recognized_via = RecognitionSource.MANUAL
        existing.review_status = ReviewStatus.APPROVED
        existing.od_reason = data.od_reason
        existing.marked_by_user_id = current_user.id
        existing.marked_at = datetime.now(timezone.utc)
        record = existing
        audit_msg = f"Updated attendance for student #{st.id} ({st.roll_number}) in session #{sess.id}: {old_status} -> {status_enum.value}"
    else:
        record = AttendanceRecord(
            session_id=data.session_id,
            student_id=data.student_id,
            status=status_enum,
            confidence=100.0,
            recognized_via=RecognitionSource.MANUAL,
            review_status=ReviewStatus.APPROVED,
            od_reason=data.od_reason,
            marked_by_user_id=current_user.id,
            marked_at=datetime.now(timezone.utc)
        )
        db.add(record)
        audit_msg = f"Manually added attendance ({status_enum.value}) for student #{st.id} ({st.roll_number}) in session #{sess.id}"

    db.flush()
    audit = AuditLog(
        user_id=current_user.id,
        action="ATTENDANCE_MANUAL_ADDED",
        target=st.roll_number,
        details=audit_msg
    )
    db.add(audit)
    db.commit()
    db.refresh(record)
    return _build_attendance_out(record)


@router.put("/attendance/{record_id}", response_model=AttendanceRecordOut)
def admin_update_attendance(
    record_id: int,
    data: AttendanceUpdate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Admin updates or corrects an existing attendance record."""
    rec = db.query(AttendanceRecord).filter(AttendanceRecord.id == record_id).first()
    if not rec:
        raise HTTPException(status_code=404, detail="Attendance record not found")

    try:
        new_st = AttendanceStatus(data.status.upper())
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid status '{data.status}'")

    old_st = rec.status.value
    rec.status = new_st
    if data.review_status:
        try:
            rec.review_status = ReviewStatus(data.review_status.upper())
        except ValueError:
            pass
    if data.od_reason is not None:
        rec.od_reason = data.od_reason

    rec.marked_by_user_id = current_user.id
    rec.marked_at = datetime.now(timezone.utc)

    st_roll = rec.student.roll_number if rec.student else f"Student #{rec.student_id}"
    audit = AuditLog(
        user_id=current_user.id,
        action="ATTENDANCE_CORRECTED",
        target=st_roll,
        details=f"Corrected attendance record #{record_id} ({st_roll}) in session #{rec.session_id}: {old_st} -> {new_st.value}"
    )
    db.add(audit)
    db.commit()
    db.refresh(rec)
    return _build_attendance_out(rec)


@router.delete("/attendance/{record_id}")
def admin_delete_attendance(
    record_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Admin deletes an attendance record with audit logging."""
    rec = db.query(AttendanceRecord).filter(AttendanceRecord.id == record_id).first()
    if not rec:
        raise HTTPException(status_code=404, detail="Attendance record not found")

    st_roll = rec.student.roll_number if rec.student else f"Student #{rec.student_id}"
    audit = AuditLog(
        user_id=current_user.id,
        action="ATTENDANCE_DELETED",
        target=st_roll,
        details=f"Deleted attendance record #{record_id} ({st_roll}, Status: {rec.status.value}) from session #{rec.session_id}"
    )
    db.add(audit)
    db.delete(rec)
    db.commit()
    return {"message": "Attendance record deleted successfully", "record_id": record_id}


# ==========================================
# CLASS SESSION MANAGEMENT
# ==========================================

@router.get("/sessions")
def admin_list_sessions(
    date: Optional[str] = None,
    class_id: Optional[int] = None,
    faculty_id: Optional[int] = None,
    status: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """Lists all class sessions in the system with optional filters."""
    query = db.query(ClassSession)
    if date:
        query = query.filter(ClassSession.date == date)
    if faculty_id is not None:
        query = query.filter(ClassSession.faculty_id == faculty_id)
    if status:
        try:
            st_enum = SessionStatus(status.upper())
            query = query.filter(ClassSession.status == st_enum)
        except ValueError:
            pass
    if class_id is not None:
        query = (
            query.join(TimetableEntry, ClassSession.timetable_entry_id == TimetableEntry.id)
            .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
            .filter(FacultyAssignment.class_id == class_id)
        )

    sessions = query.order_by(ClassSession.id.desc()).all()
    result = []
    for s in sessions:
        tt_entry = s.timetable_entry
        assignment = tt_entry.assignment if tt_entry else None
        result.append({
            "id": s.id,
            "session_id": s.id,
            "timetable_entry_id": s.timetable_entry_id,
            "faculty_id": s.faculty_id,
            "date": s.date,
            "status": s.status.value,
            "faculty_name": s.faculty.full_name if s.faculty else "Unknown",
            "subject_code": assignment.subject.code if assignment and assignment.subject else "N/A",
            "subject_name": assignment.subject.name if assignment and assignment.subject else "N/A",
            "class_name": assignment.class_section.name if assignment and assignment.class_section else "N/A",
            "attendance_count": len(s.attendance_records or []),
            "start_timestamp": s.start_timestamp.isoformat() if s.start_timestamp else None,
            "end_timestamp": s.end_timestamp.isoformat() if s.end_timestamp else None
        })
    return result


@router.get("/sessions/{session_id}")
def admin_get_session_details(session_id: int, db: Session = Depends(get_db)):
    """Admin endpoint to inspect any session and its student roster/records."""
    return get_session_details_with_roster(db, session_id=session_id, faculty_id=None)


@router.post("/sessions", status_code=status.HTTP_201_CREATED)
def admin_create_session(
    data: ClassSessionCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Admin creates a new class session."""
    fac = db.query(Faculty).filter(Faculty.id == data.faculty_id).first()
    if not fac:
        raise HTTPException(status_code=404, detail=f"Faculty ID {data.faculty_id} not found")

    if data.timetable_entry_id:
        tt = db.query(TimetableEntry).filter(TimetableEntry.id == data.timetable_entry_id).first()
        if not tt:
            raise HTTPException(status_code=404, detail=f"Timetable Entry ID {data.timetable_entry_id} not found")

    sess_status = SessionStatus.SCHEDULED
    if data.status:
        try:
            sess_status = SessionStatus(data.status.upper())
        except ValueError:
            pass

    sess = ClassSession(
        timetable_entry_id=data.timetable_entry_id,
        faculty_id=data.faculty_id,
        date=data.date,
        status=sess_status,
        start_timestamp=datetime.now(timezone.utc) if sess_status == SessionStatus.ACTIVE else None
    )
    db.add(sess)
    db.flush()

    audit = AuditLog(
        user_id=current_user.id,
        action="SESSION_CREATED",
        target=f"Session #{sess.id}",
        details=f"Created session #{sess.id} for faculty {fac.full_name} on {data.date} (status={sess_status.value})"
    )
    db.add(audit)
    db.commit()
    db.refresh(sess)

    tt_entry = sess.timetable_entry
    assignment = tt_entry.assignment if tt_entry else None
    return {
        "id": sess.id,
        "session_id": sess.id,
        "timetable_entry_id": sess.timetable_entry_id,
        "faculty_id": sess.faculty_id,
        "date": sess.date,
        "status": sess.status.value,
        "faculty_name": sess.faculty.full_name if sess.faculty else "Unknown",
        "subject_code": assignment.subject.code if assignment and assignment.subject else "N/A",
        "subject_name": assignment.subject.name if assignment and assignment.subject else "N/A",
        "class_name": assignment.class_section.name if assignment and assignment.class_section else "N/A",
        "attendance_count": 0,
        "start_timestamp": sess.start_timestamp.isoformat() if sess.start_timestamp else None,
        "end_timestamp": sess.end_timestamp.isoformat() if sess.end_timestamp else None
    }


@router.put("/sessions/{session_id}")
def admin_update_session(
    session_id: int,
    data: ClassSessionUpdate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Admin updates an existing class session."""
    sess = db.query(ClassSession).filter(ClassSession.id == session_id).first()
    if not sess:
        raise HTTPException(status_code=404, detail="Session not found")

    changes = []
    if data.date and data.date != sess.date:
        changes.append(f"date: {sess.date} -> {data.date}")
        sess.date = data.date
    if data.faculty_id and data.faculty_id != sess.faculty_id:
        fac = db.query(Faculty).filter(Faculty.id == data.faculty_id).first()
        if not fac:
            raise HTTPException(status_code=404, detail=f"Faculty ID {data.faculty_id} not found")
        changes.append(f"faculty_id: {sess.faculty_id} -> {data.faculty_id}")
        sess.faculty_id = data.faculty_id
    if data.status:
        try:
            new_st = SessionStatus(data.status.upper())
            changes.append(f"status: {sess.status.value} -> {new_st.value}")
            sess.status = new_st
            if new_st == SessionStatus.COMPLETED and not sess.end_timestamp:
                sess.end_timestamp = datetime.now(timezone.utc)
            elif new_st == SessionStatus.ACTIVE and not sess.start_timestamp:
                sess.start_timestamp = datetime.now(timezone.utc)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid session status '{data.status}'")

    audit = AuditLog(
        user_id=current_user.id,
        action="SESSION_UPDATED",
        target=f"Session #{sess.id}",
        details=f"Updated session #{sess.id}: {', '.join(changes) if changes else 'no changes'}"
    )
    db.add(audit)
    db.commit()
    db.refresh(sess)

    tt_entry = sess.timetable_entry
    assignment = tt_entry.assignment if tt_entry else None
    return {
        "id": sess.id,
        "session_id": sess.id,
        "timetable_entry_id": sess.timetable_entry_id,
        "faculty_id": sess.faculty_id,
        "date": sess.date,
        "status": sess.status.value,
        "faculty_name": sess.faculty.full_name if sess.faculty else "Unknown",
        "subject_code": assignment.subject.code if assignment and assignment.subject else "N/A",
        "subject_name": assignment.subject.name if assignment and assignment.subject else "N/A",
        "class_name": assignment.class_section.name if assignment and assignment.class_section else "N/A",
        "attendance_count": len(sess.attendance_records or []),
        "start_timestamp": sess.start_timestamp.isoformat() if sess.start_timestamp else None,
        "end_timestamp": sess.end_timestamp.isoformat() if sess.end_timestamp else None
    }


@router.delete("/sessions/{session_id}")
def admin_delete_session(
    session_id: int,
    cascade: bool = False,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Admin safely deletes a class session with referential safety checks."""
    sess = db.query(ClassSession).filter(ClassSession.id == session_id).first()
    if not sess:
        raise HTTPException(status_code=404, detail="Session not found")

    rec_count = db.query(AttendanceRecord).filter(AttendanceRecord.session_id == session_id).count()
    if rec_count > 0 and not cascade:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete session #{session_id} because it contains {rec_count} attendance record(s). Set cascade=true to confirm deletion of the session and its records."
        )

    audit = AuditLog(
        user_id=current_user.id,
        action="SESSION_DELETED",
        target=f"Session #{sess.id}",
        details=f"Deleted session #{sess.id} (Date: {sess.date}, Attendance Records: {rec_count})"
    )
    db.add(audit)
    db.delete(sess)
    db.commit()
    return {"message": "Session deleted successfully", "session_id": session_id, "deleted_records": rec_count}


@router.post("/sessions/{session_id}/correction")
def admin_correct_session_attendance(
    session_id: int,
    data: AdminCorrectionRequest,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Admin endpoint for explicit attendance correction with audit logging."""
    record = admin_correct_attendance(
        db,
        session_id=session_id,
        student_id=data.student_id,
        new_status=data.new_status,
        reason=data.reason,
        admin_user_id=current_user.id
    )

    return {
        "message": "Admin correction applied and logged to AuditLog",
        "record_id": record.id,
        "student_id": record.student_id,
        "new_status": record.status.value,
        "reason": data.reason
    }


@router.get("/audit-logs")
def admin_get_audit_logs(db: Session = Depends(get_db)):
    """Lists audit history logs."""
    logs = db.query(AuditLog).order_by(AuditLog.timestamp.desc()).limit(200).all()
    result = []
    for log in logs:
        result.append({
            "id": log.id,
            "user_id": log.user_id,
            "username": log.user.username if log.user else "System",
            "action": log.action,
            "target": log.target,
            "details": log.details,
            "timestamp": log.timestamp.isoformat() if log.timestamp else None
        })
    return result
