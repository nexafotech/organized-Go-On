"""
M4: Student Portal API

All endpoints derive student identity from the authenticated session.
Students can ONLY access their own data — no student_id parameter bypass.
"""

import json
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session
from typing import List, Optional, Dict, Any

from app.core.database import get_db
from app.models.user import User
from app.models.student import Student
from app.models.academic import TimetableEntry, FacultyAssignment, Period, Subject
from app.models.attendance import FaceEmbedding
from app.models.audit import AuditLog
from app.schemas.student_auth import (
    StudentMeOut, StudentAttendanceReport, SubjectAttendanceRow,
    SubjectAttendanceDetail, DateWiseEntry, PeriodEntry,
    AvatarCatalogItem, AvatarUpdateIn
)
from app.core.avatars import (
    AVATAR_CATALOG, is_valid_avatar, resolve_avatar, get_avatar_meta
)
from app.api.deps import get_current_student
from app.engines.policy_engine import AttendancePolicyEngine, get_active_policy
from app.services.face_pose_service import FacePoseService
from app.engines.recognition.factory import RecognitionEngineFactory
from app.services.recognition_index import recognition_index

router = APIRouter(prefix="/student", tags=["Student Portal"])



# ─────────────────────────────────────────────────────────────────────────────
# /student/me — Profile + Overall Attendance Summary
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/me", response_model=StudentMeOut)
def get_student_profile(
    student: Student = Depends(get_current_student),
    db: Session = Depends(get_db)
):
    """
    Returns the authenticated student's profile and overall attendance summary.
    Student identity is fully derived from the session — no bypass possible.
    """
    engine = AttendancePolicyEngine(db)
    summary = engine.calculate_student_attendance(student.id)

    class_name = student.class_section.name if student.class_section else None

    return StudentMeOut(
        student_id=student.id,
        user_id=student.user_id,
        full_name=student.full_name,
        register_number=student.roll_number,
        email=student.email,
        phone=student.phone,
        class_name=class_name,
        class_id=student.class_id,
        semester=student.semester,
        department=student.department,
        is_active=student.is_active,
        avatar_id=resolve_avatar(student.avatar_id, student.roll_number or student.id),
        total=summary["total"],
        present=summary["present"],
        absent=summary["absent"],
        od=summary["od"],
        half_day_present=summary.get("half_day_present", 0),
        half_day_absent=summary.get("half_day_absent", 0),
        percentage=summary["percentage"],
        calculation_mode=summary["calculation_mode"],
        attendance_status=summary["status"],
        minimum_required=summary["minimum_required"],
        below_minimum=summary["below_minimum"],
        alert_message=summary["alert_message"],
        required_future_classes=summary["required_future_classes"],
        estimated_working_days=summary["estimated_working_days"],
        missable_future_classes=summary["missable_future_classes"],
    )


# ─────────────────────────────────────────────────────────────────────────────
# /student/attendance — Full Attendance Report
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/attendance", response_model=StudentAttendanceReport)
def get_student_attendance_report(
    student: Student = Depends(get_current_student),
    db: Session = Depends(get_db)
):
    """
    Full attendance report: semester summary + period-wise + subject-wise + date-wise.
    """
    engine = AttendancePolicyEngine(db)

    # Overall summary
    overall = engine.calculate_student_attendance(student.id)

    # Period-wise summary
    period_raw = engine.calculate_period_attendance(student.id)
    period_summary = [
        {
            "period_number": p["period_number"],
            "period_name": p["period_name"],
            "total": p["total"],
            "present": p["present"],
            "absent": p["absent"],
            "od": p["od"],
            "percentage": p["percentage"],
        }
        for p in period_raw
    ]

    # Subject-wise
    subjects_raw = engine.calculate_all_subjects_attendance(student.id)
    subjects = [
        SubjectAttendanceRow(
            subject_id=s["subject_id"],
            subject_code=s["subject_code"],
            subject_name=s["subject_name"],
            total=s["total"],
            present=s["present"],
            absent=s["absent"],
            od=s["od"],
            percentage=s["percentage"],
        )
        for s in subjects_raw
    ]

    # Date-wise
    date_wise_raw = engine.get_date_wise_attendance(student.id)
    date_wise = [
        DateWiseEntry(
            date=d["date"],
            morning_status=d.get("morning_status"),
            morning_summary=d.get("morning", {}).get("summary_text") if isinstance(d.get("morning"), dict) else None,
            afternoon_status=d.get("afternoon_status"),
            afternoon_summary=d.get("afternoon", {}).get("summary_text") if isinstance(d.get("afternoon"), dict) else None,
            daily_result=d.get("daily_result"),
            lunch_interval=d.get("lunch_interval", "12:50 PM - 01:40 PM (Not Counted)"),
            periods=[
                PeriodEntry(
                    period_number=p.get("period_number"),
                    period_name=p.get("period_name"),
                    subject_code=p.get("subject_code"),
                    subject_name=p.get("subject_name"),
                    status=p["status"],
                    od_reason=p.get("od_reason"),
                    session_id=p.get("session_id"),
                )
                for p in d["periods"]
            ]
        )
        for d in date_wise_raw
    ]

    class_name = student.class_section.name if student.class_section else None

    return StudentAttendanceReport(
        student_id=student.id,
        full_name=student.full_name,
        register_number=student.roll_number,
        class_name=class_name,
        semester=student.semester,
        total=overall["total"],
        present=overall["present"],
        absent=overall["absent"],
        od=overall["od"],
        half_day_present=overall.get("half_day_present", 0),
        half_day_absent=overall.get("half_day_absent", 0),
        percentage=overall["percentage"],
        calculation_mode=overall["calculation_mode"],
        status=overall["status"],
        minimum_required=overall["minimum_required"],
        below_minimum=overall["below_minimum"],
        alert_message=overall["alert_message"],
        required_future_classes=overall["required_future_classes"],
        estimated_working_days=overall["estimated_working_days"],
        missable_future_classes=overall["missable_future_classes"],
        period_summary=period_summary,
        subjects=subjects,
        date_wise=date_wise,
    )


# ─────────────────────────────────────────────────────────────────────────────
# /student/attendance/subjects — Subject-wise Summary
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/attendance/subjects", response_model=List[SubjectAttendanceRow])
def get_student_subject_attendance(
    student: Student = Depends(get_current_student),
    db: Session = Depends(get_db)
):
    """Returns subject-wise attendance breakdown for the authenticated student."""
    engine = AttendancePolicyEngine(db)
    subjects_raw = engine.calculate_all_subjects_attendance(student.id)
    return [
        SubjectAttendanceRow(
            subject_id=s["subject_id"],
            subject_code=s["subject_code"],
            subject_name=s["subject_name"],
            total=s["total"],
            present=s["present"],
            absent=s["absent"],
            od=s["od"],
            percentage=s["percentage"],
        )
        for s in subjects_raw
    ]


# ─────────────────────────────────────────────────────────────────────────────
# /student/attendance/subjects/{subject_id} — Single Subject Detail
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/attendance/subjects/{subject_id}", response_model=SubjectAttendanceDetail)
def get_student_single_subject_attendance(
    subject_id: int,
    student: Student = Depends(get_current_student),
    db: Session = Depends(get_db)
):
    """
    Detailed attendance for one subject — for the authenticated student only.
    Includes all records with date and period info.
    """
    from app.models.attendance import AttendanceRecord, ClassSession
    from app.models.academic import TimetableEntry, FacultyAssignment

    subject = db.query(Subject).filter(Subject.id == subject_id).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")

    engine = AttendancePolicyEngine(db)
    summary = engine.calculate_subject_attendance(student.id, subject_id)

    # Build detailed record list
    records_raw = (
        db.query(AttendanceRecord)
        .join(ClassSession, AttendanceRecord.session_id == ClassSession.id)
        .join(TimetableEntry, ClassSession.timetable_entry_id == TimetableEntry.id)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .filter(
            AttendanceRecord.student_id == student.id,
            FacultyAssignment.subject_id == subject_id,
        )
        .order_by(ClassSession.date.asc())
        .all()
    )

    records_list = []
    for rec in records_raw:
        session = rec.session
        tt = session.timetable_entry if session else None
        period = tt.period if tt else None
        records_list.append({
            "date": session.date if session else None,
            "period_number": period.period_number if period else None,
            "period_name": period.name if period else None,
            "status": rec.status.value,
            "od_reason": rec.od_reason,
            "session_id": session.id if session else None,
            "marked_at": rec.marked_at.isoformat() if rec.marked_at else None,
        })

    return SubjectAttendanceDetail(
        subject_id=subject_id,
        subject_code=subject.code,
        subject_name=subject.name,
        total=summary["total"],
        present=summary["present"],
        absent=summary["absent"],
        od=summary["od"],
        uncertain=summary["uncertain"],
        not_entered=summary["not_entered"],
        excluded=summary["excluded"],
        percentage=summary["percentage"],
        records=records_list,
    )


# ─────────────────────────────────────────────────────────────────────────────
# /student/timetable — Student's Class Timetable
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/timetable")
def get_student_timetable(
    student: Student = Depends(get_current_student),
    db: Session = Depends(get_db)
):
    """
    Returns the timetable for the student's class/section.
    Derived from the DB timetable — no hard-coding.
    """
    if not student.class_id:
        return {"class_name": None, "timetable": []}

    class_section = student.class_section
    entries = (
        db.query(TimetableEntry)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .join(Period, TimetableEntry.period_id == Period.id)
        .filter(FacultyAssignment.class_id == student.class_id)
        .order_by(TimetableEntry.day_of_week, Period.period_number)
        .all()
    )

    timetable = []
    for e in entries:
        assign = e.assignment
        period = e.period
        fac_name = assign.faculty.full_name if (assign and assign.faculty) else "Faculty assignment pending"
        timetable.append({
            "day_of_week": e.day_of_week,
            "period_number": period.period_number if period else None,
            "period_name": period.name if period else None,
            "start_time": period.start_time if period else None,
            "end_time": period.end_time if period else None,
            "subject_code": assign.subject.code if assign and assign.subject else None,
            "subject_name": assign.subject.name if assign and assign.subject else None,
            "faculty_name": fac_name,
            "room": e.room,
        })

    return {
        "class_name": class_section.name if class_section else None,
        "semester": student.semester,
        "department": student.department,
        "timetable": timetable,
    }


# ─────────────────────────────────────────────────────────────────────────────
# /student/profile — Update own profile (limited fields)
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/profile")
def get_student_profile_detail(
    student: Student = Depends(get_current_student),
    db: Session = Depends(get_db)
):
    """Returns full student profile including resolved avatar."""
    return {
        "student_id": student.id,
        "full_name": student.full_name,
        "register_number": student.roll_number,
        "email": student.email,
        "phone": student.phone,
        "class_name": student.class_section.name if student.class_section else None,
        "semester": student.semester,
        "department": student.department,
        "is_active": student.is_active,
        "avatar_id": resolve_avatar(student.avatar_id, student.roll_number or student.id),
    }


@router.get("/avatars", response_model=List[AvatarCatalogItem])
def list_student_avatars(
    category: Optional[str] = None,
    student: Student = Depends(get_current_student),
):
    """
    Returns available avatar collection.
    Supports filtering by category: 'masculine', 'feminine', 'neutral', or 'all'.
    """
    if not category or category.lower() == "all":
        return AVATAR_CATALOG
    cat = category.strip().lower()
    if cat == "neutral":
        return [a for a in AVATAR_CATALOG if a.get("is_neutral", False)]
    return [a for a in AVATAR_CATALOG if a.get("category") == cat]


@router.put("/avatar")
@router.patch("/avatar")
def update_student_avatar(
    body: AvatarUpdateIn,
    student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Updates the authenticated student's profile avatar.
    Rejects invalid avatar IDs.
    """
    if not is_valid_avatar(body.avatar_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid avatar ID '{body.avatar_id}'. Must be one of approved avatar catalog IDs.",
        )

    student.avatar_id = body.avatar_id
    if student.user:
        student.user.avatar_id = body.avatar_id

    db.commit()
    db.refresh(student)

    # Audit logging
    try:
        audit = AuditLog(
            action="UPDATE_STUDENT_AVATAR",
            user_id=student.user_id,
            target=f"student:{student.id}",
            details=json.dumps({"student_id": student.id, "avatar_id": body.avatar_id}),
        )
        db.add(audit)
        db.commit()
    except Exception:
        pass

    return {
        "success": True,
        "avatar_id": student.avatar_id,
        "message": "Avatar updated successfully",
    }


@router.patch("/profile")
@router.put("/profile")
def update_student_profile(
    body: Dict[str, Any],
    student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Allows authenticated student to update editable profile fields:
    full_name, email, phone, avatar_id.
    Persists changes to the SQLite database and syncs associated User record.
    """
    if "full_name" in body and body["full_name"] is not None:
        name_str = str(body["full_name"]).strip()
        if name_str:
            student.full_name = name_str

    if "avatar_id" in body:
        new_av = body["avatar_id"]
        if new_av and not is_valid_avatar(new_av):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid avatar ID '{new_av}'. Must be one of approved avatar catalog IDs.",
            )
        student.avatar_id = new_av
        if student.user:
            student.user.avatar_id = new_av

    if "email" in body:
        raw_email = str(body["email"]).strip() if body["email"] is not None else ""
        clean_email = raw_email if raw_email else None
        if clean_email and student.user:
            conflict = db.query(User).filter(User.email == clean_email, User.id != student.user_id).first()
            if conflict:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Email address '{clean_email}' is already in use by another account.",
                )
            student.user.email = clean_email
        elif student.user and clean_email is None:
            # If removing email, avoid setting empty string to prevent unique constraint collision
            pass
        student.email = clean_email

    if "phone" in body:
        raw_phone = str(body["phone"]).strip() if body["phone"] is not None else ""
        student.phone = raw_phone if raw_phone else None

    db.commit()
    db.refresh(student)

    # Audit logging
    try:
        audit = AuditLog(
            action="UPDATE_STUDENT_PROFILE",
            user_id=student.user_id,
            target=f"student:{student.id}",
            details=json.dumps({
                "student_id": student.id,
                "full_name": student.full_name,
                "email": student.email,
                "phone": student.phone,
                "avatar_id": student.avatar_id,
            }),
        )
        db.add(audit)
        db.commit()
    except Exception:
        pass

    return {
        "success": True,
        "student_id": student.id,
        "full_name": student.full_name,
        "register_number": student.roll_number,
        "email": student.email,
        "phone": student.phone,
        "avatar_id": resolve_avatar(student.avatar_id, student.roll_number or student.id),
        "message": "Profile updated successfully",
    }


# ─────────────────────────────────────────────────────────────────────────────
# Biometric Enrollment Endpoints (Strict 3-Angle Capture Protocol)
# ─────────────────────────────────────────────────────────────────────────────

MAX_CAPTURE_SIZE_MB = 10
ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp", "image/jpg"]
SEQUENCE_STEPS = ["FRONTAL", "LEFT_15", "RIGHT_15"]


def _is_valid_image_file(file: UploadFile) -> bool:
    """Checks if uploaded file matches allowed image types or extensions."""
    if file.content_type in ALLOWED_IMAGE_TYPES:
        return True
    if file.content_type in ["application/octet-stream", None, ""]:
        if file.filename:
            ext = file.filename.lower().split('.')[-1]
            if ext in ["jpg", "jpeg", "png", "webp"]:
                return True
    return False



@router.get("/enrollment-status")
def get_enrollment_status(
    student: Student = Depends(get_current_student),
    db: Session = Depends(get_db)
):
    """
    Returns biometric enrollment status for authenticated student for the active engine.
    A student is fully enrolled ONLY when 3/3 templates are accepted for the active engine.
    """
    engine = RecognitionEngineFactory.get_engine()
    embeddings = db.query(FaceEmbedding).filter(
        FaceEmbedding.student_id == student.id,
        FaceEmbedding.model_name == engine.model_name,
        FaceEmbedding.dimension == engine.embedding_dimension
    ).order_by(FaceEmbedding.created_at.asc()).all()

    legacy_count = db.query(FaceEmbedding).filter(
        FaceEmbedding.student_id == student.id,
        FaceEmbedding.model_name != engine.model_name
    ).count()

    count = len(embeddings)
    completed_steps = []
    for idx in range(min(count, 3)):
        completed_steps.append(SEQUENCE_STEPS[idx])

    if count >= 3:
        status_str = "ENROLLED"
        next_step = None
        message = "Face enrollment complete — 3 of 3 captures accepted."
    else:
        status_str = "ENROLLMENT_INCOMPLETE"
        next_step = SEQUENCE_STEPS[count]
        message = f"Enrollment incomplete: {count} of 3 captures accepted."

    return {
        "status": status_str,
        "templates_count": count,
        "required_templates": 3,
        "completed_steps": completed_steps,
        "next_step": next_step,
        "message": message,
        "student_id": student.id,
        "register_number": student.roll_number,
        "full_name": student.full_name,
        "model_name": engine.model_name,
        "dimension": engine.embedding_dimension,
        "has_legacy_templates": legacy_count > 0
    }


@router.post("/enroll-face/validate-pose")
async def student_validate_pose(
    file: UploadFile = File(...),
    step: str = Form("FRONTAL"),
    mirrored: bool = Form(False),
    student: Student = Depends(get_current_student)
):
    """
    In-memory live capture assistance and pose estimation.
    Does NOT store the image or modify database state.
    """
    if not _is_valid_image_file(file):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported image file type. Please upload JPEG or PNG."
        )

    image_bytes = await file.read()
    if len(image_bytes) > MAX_CAPTURE_SIZE_MB * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Image file size exceeds maximum limit of {MAX_CAPTURE_SIZE_MB}MB."
        )

    service = FacePoseService()
    try:
        engine = RecognitionEngineFactory.get_engine("scrfd_arcface")
    except Exception:
        engine = RecognitionEngineFactory.get_engine()

    result = service.validate_image_and_pose(image_bytes, step, engine, mirrored=mirrored)
    return result


@router.post("/enroll-face/capture")
async def student_capture_template(
    file: UploadFile = File(...),
    step: str = Form(...),
    mirrored: bool = Form(False),
    student: Student = Depends(get_current_student),
    db: Session = Depends(get_db)
):
    """
    Validates and persists one of the 3 required face enrollment templates.
    Image is processed strictly in-memory and discarded. Vector is NOT exposed to student.
    """
    step_clean = step.upper().strip()
    if step_clean not in SEQUENCE_STEPS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid capture step '{step}'. Expected one of: {SEQUENCE_STEPS}"
        )

    engine = RecognitionEngineFactory.get_engine()

    # 1. Verify step sequence for active engine
    existing_embs = db.query(FaceEmbedding).filter(
        FaceEmbedding.student_id == student.id,
        FaceEmbedding.model_name == engine.model_name,
        FaceEmbedding.dimension == engine.embedding_dimension
    ).all()
    count = len(existing_embs)

    if count >= 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Face enrollment complete (3/3 templates accepted). Reset enrollment first if you wish to re-enroll."
        )

    expected_step = SEQUENCE_STEPS[count]
    if step_clean != expected_step:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid capture step order. Expected Step {count + 1} ({expected_step}), but received '{step_clean}'."
        )

    # 2. Validate file
    if not _is_valid_image_file(file):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported image file type. Please upload JPEG or PNG."
        )

    image_bytes = await file.read()
    if len(image_bytes) > MAX_CAPTURE_SIZE_MB * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Image file size exceeds maximum limit of {MAX_CAPTURE_SIZE_MB}MB."
        )

    # 3. Quality & Pose Validation
    service = FacePoseService()
    val_res = service.validate_image_and_pose(image_bytes, step_clean, engine, mirrored=mirrored)
    if not val_res.get("valid", False):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=val_res.get("message", "Face capture failed validation.")
        )

    # 4. Generate normalized embedding in-memory
    face_box = val_res["face_box"]
    face_loc = (face_box["top"], face_box["right"], face_box["bottom"], face_box["left"])
    img = FacePoseService.decode_and_orient(image_bytes, mirrored=mirrored)
    embeddings = engine.generate_embeddings(img if img is not None else image_bytes, [face_loc])
    if not embeddings:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to extract facial vector features."
        )

    emb_vec = embeddings[0]
    import numpy as np
    if len(emb_vec) != engine.embedding_dimension or not np.all(np.isfinite(emb_vec)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Extracted facial vector contains invalid or non-finite values."
        )
    norm = float(np.linalg.norm(emb_vec))
    if norm < 1e-6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Extracted facial vector has degenerate zero norm."
        )
    if engine.distance_metric == "cosine" and not np.isclose(norm, 1.0, atol=1e-3):
        emb_vec = emb_vec / norm

    emb_json = json.dumps(emb_vec.tolist())

    # 5. Persist FaceEmbedding row (Privacy rule: no raw image stored)
    face_emb = FaceEmbedding(
        student_id=student.id,
        embedding_json=emb_json,
        image_path=f"memory:capture_{step_clean.lower()}",
        model_name=engine.model_name,
        model_version=engine.model_version,
        dimension=engine.embedding_dimension,
        detector_name=engine.detector_name,
        distance_metric=engine.distance_metric,
        quality_score=val_res.get("quality_score")
    )
    db.add(face_emb)

    # 6. Audit Logging
    audit = AuditLog(
        user_id=student.user_id,
        action="STUDENT_FACE_ENROLLMENT",
        details=(
            f"Enrolled template {count + 1}/3 ({step_clean}) for Student #{student.id} "
            f"('{student.full_name}', Roll: {student.roll_number}). Pose: {val_res.get('pose')}"
        )
    )
    db.add(audit)

    db.commit()
    db.refresh(face_emb)
    recognition_index.invalidate(student.class_id)

    new_count = count + 1
    is_complete = new_count >= 3
    enrollment_msg = (
        "Face enrollment complete — 3 of 3 captures accepted."
        if is_complete
        else f"Enrollment incomplete: {new_count} of 3 captures accepted."
    )

    return {
        "message": f"Capture accepted for Step {new_count} ({step_clean}).",
        "step": step_clean,
        "templates_count": new_count,
        "required_templates": 3,
        "status": "ENROLLED" if is_complete else "ENROLLMENT_INCOMPLETE",
        "next_step": None if is_complete else SEQUENCE_STEPS[new_count],
        "enrollment_message": enrollment_msg,
        "pose": val_res.get("pose"),
        "quality_score": val_res.get("quality_score")
    }


@router.post("/enroll-face/reset")
def student_reset_enrollment(
    student: Student = Depends(get_current_student),
    db: Session = Depends(get_db)
):
    """
    Deletes all enrolled biometric templates for the authenticated student,
    allowing a fresh 3-step capture restart.
    """
    deleted = db.query(FaceEmbedding).filter(
        FaceEmbedding.student_id == student.id
    ).delete(synchronize_session=False)

    audit = AuditLog(
        user_id=student.user_id,
        action="STUDENT_FACE_ENROLLMENT_RESET",
        details=f"Reset biometric enrollment for Student #{student.id} ('{student.full_name}', Roll: {student.roll_number}). Deleted {deleted} templates."
    )
    db.add(audit)
    db.commit()
    recognition_index.invalidate(student.class_id)

    return {
        "message": "Biometric face enrollment reset successfully.",
        "deleted_templates": deleted,
        "status": "ENROLLMENT_INCOMPLETE",
        "templates_count": 0,
        "required_templates": 3,
        "next_step": "FRONTAL"
    }

