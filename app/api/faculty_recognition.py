import time
import json
import logging
import cv2
import numpy as np
from datetime import datetime
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.user import User, UserRole, Faculty
from app.models.student import Student
from app.models.academic import TimetableEntry, FacultyAssignment, ClassSection
from app.models.attendance import ClassSession, FaceEmbedding, SessionStatus, AttendanceStatus, RecognitionSource, ReviewStatus
from app.models.audit import AuditLog
from app.api.deps import require_faculty
from app.engines.recognition.factory import RecognitionEngineFactory
from app.services.recognition_index import recognition_index
from app.engines.attendance_engine import record_manual_attendance, get_ist_now
from app.schemas.faculty_attendance import (
    BatchRecognitionResponse,
    BatchRecognizedStudent,
    BatchPhotoSummary,
)

logger = logging.getLogger(__name__)


router = APIRouter(prefix="/faculty/sessions", tags=["Faculty Face Recognition & Group Photo"], dependencies=[Depends(require_faculty)])
batch_router = APIRouter(prefix="/faculty/attendance", tags=["Faculty Batch Photo Attendance"], dependencies=[Depends(require_faculty)])


MAX_GROUP_PHOTO_SIZE_MB = 10

class ConfirmedCandidateItem(BaseModel):
    student_id: int
    status: AttendanceStatus = AttendanceStatus.PRESENT
    recognized_via: Optional[RecognitionSource] = RecognitionSource.GROUP_PHOTO

class ConfirmRecognitionRequest(BaseModel):
    confirmed_candidates: List[ConfirmedCandidateItem]

@router.post("/{session_id}/recognize-image")
async def faculty_recognize_image(
    session_id: int,
    file: UploadFile = File(...),
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Processes single/multi-face group photograph for an active class session.
    Matches faces independently against enrolled student embeddings for the class section.
    """
    if not current_user.faculty_profile:
        raise HTTPException(status_code=400, detail="Faculty profile not linked")

    faculty_id = current_user.faculty_profile.id

    # 1. Verify session exists and is owned by faculty
    session = db.query(ClassSession).filter(ClassSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    if session.faculty_id != faculty_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied: You do not own this class session")

    if session.status != SessionStatus.ACTIVE:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot process recognition: Session is not ACTIVE")

    # 2. Validate image upload
    if file.content_type not in ["image/jpeg", "image/png", "image/webp", "image/jpg"]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unsupported file format. Upload JPEG or PNG.")

    image_bytes = await file.read()
    if len(image_bytes) > MAX_GROUP_PHOTO_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Image size exceeds limit of {MAX_GROUP_PHOTO_SIZE_MB}MB")

    # 3. Resolve target class section and enrolled student embeddings
    tt_entry = session.timetable_entry
    assignment = tt_entry.assignment if tt_entry else None
    class_id = assignment.class_id if assignment else None

    if not class_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Session is not associated with a valid class section")

    t_start = time.perf_counter()

    # Load active recognition engine
    engine = RecognitionEngineFactory.get_engine()

    # Retrieve pre-cached in-memory recognition index (0ms on cache hit)
    t_idx0 = time.perf_counter()
    class_idx = recognition_index.get_class_index(db, class_id, engine)
    enrolled_students = class_idx.enrolled_students_list
    t_idx1 = time.perf_counter()

    # Decode image once
    t_dec0 = time.perf_counter()
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    t_dec1 = time.perf_counter()

    # 4. Run Multi-Face Recognition Engine
    t_rec0 = time.perf_counter()
    recognition_output = engine.recognize_image(img, enrolled_students=enrolled_students)
    t_rec1 = time.perf_counter()
    recognition_output["session_id"] = session_id

    total_latency_ms = (time.perf_counter() - t_start) * 1000
    logger.info(
        f"[PERF_TIMING] Session #{session_id} single photo recognition: "
        f"template_index_ms={(t_idx1 - t_idx0)*1000:.2f}, "
        f"image_decode_ms={(t_dec1 - t_dec0)*1000:.2f}, "
        f"engine_rec_ms={(t_rec1 - t_rec0)*1000:.2f}, "
        f"total_backend_ms={total_latency_ms:.2f}, "
        f"faces_detected={recognition_output.get('faces_detected', 0)}"
    )


    # Normalize response format for API clients:
    # If the engine returned integer counts for matches,
    # construct structured candidate lists from recognition_output["results"].
    raw_results = recognition_output.get("results") or []

    if not isinstance(recognition_output.get("high_confidence_matches"), list):
        high_matches = []
        for r in raw_results:
            if r.get("status") == "HIGH_CONFIDENCE":
                high_matches.append({
                    "student_id": r.get("student_id"),
                    "roll_number": r.get("roll_number"),
                    "full_name": r.get("name") or r.get("full_name") or "",
                    "name": r.get("name") or r.get("full_name") or "",
                    "distance": r.get("distance"),
                    "confidence": r.get("derived_score", 0.0),
                    "derived_score": r.get("derived_score", 0.0)
                })
        recognition_output["high_confidence_matches"] = high_matches

    if not isinstance(recognition_output.get("uncertain_matches"), list):
        uncertain_matches = []
        for r in raw_results:
            if r.get("status") == "UNCERTAIN":
                cands = [
                    {
                        "student_id": c.get("student_id"),
                        "roll_number": c.get("roll_number"),
                        "full_name": c.get("name") or c.get("full_name") or "",
                        "name": c.get("name") or c.get("full_name") or "",
                        "distance": c.get("distance"),
                        "confidence": c.get("derived_score", 0.0),
                        "derived_score": c.get("derived_score", 0.0)
                    }
                    for c in r.get("candidates", [])
                ]
                uncertain_matches.append({
                    "face_index": r.get("face_index", 0),
                    "candidates": cands
                })
        recognition_output["uncertain_matches"] = uncertain_matches

    if not isinstance(recognition_output.get("unknown_faces"), list):
        unknown_faces = [
            {"face_index": r.get("face_index", 0)}
            for r in raw_results
            if r.get("status") == "UNKNOWN"
        ]
        recognition_output["unknown_faces"] = unknown_faces

    return recognition_output

@router.post("/{session_id}/confirm-recognition")
def faculty_confirm_recognition(
    session_id: int,
    data: ConfirmRecognitionRequest,
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Submits faculty-confirmed recognition candidates to the Attendance Engine.
    Only confirmed items are recorded as AttendanceRecords in the session.
    """
    if not current_user.faculty_profile:
        raise HTTPException(status_code=400, detail="Faculty profile not linked")

    faculty_id = current_user.faculty_profile.id

    session = db.query(ClassSession).filter(ClassSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    if session.faculty_id != faculty_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied: You do not own this class session")

    if session.status != SessionStatus.ACTIVE:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot confirm attendance: Session is not ACTIVE")

    marked_records = []
    for item in data.confirmed_candidates:
        rec = record_manual_attendance(
            db,
            session_id=session_id,
            student_id=item.student_id,
            status_val=item.status,
            faculty_id=faculty_id
        )
        rec.recognized_via = item.recognized_via or RecognitionSource.GROUP_PHOTO
        db.commit()
        db.refresh(rec)
        marked_records.append({
            "record_id": rec.id,
            "student_id": rec.student_id,
            "status": rec.status.value,
            "recognized_via": rec.recognized_via.value
        })

    # Log to AuditLog
    audit = AuditLog(
        user_id=current_user.id,
        action="CONFIRM_FACIAL_RECOGNITION",
        details=f"Faculty confirmed {len(marked_records)} biometric attendance records for Session #{session_id}"
    )
    db.add(audit)
    db.commit()

    return {
        "message": f"Successfully recorded attendance for {len(marked_records)} confirmed students",
        "session_id": session_id,
        "records": marked_records
    }


def _resolve_faculty_id(current_user: User, db: Session) -> int:
    if current_user.role == UserRole.ADMIN and not current_user.faculty_profile:
        faculties = db.query(Faculty).all()
        if not faculties:
            raise HTTPException(status_code=400, detail="No faculty profiles exist")
        return faculties[0].id
    if not current_user.faculty_profile:
        raise HTTPException(status_code=400, detail="Faculty profile not linked to user account")
    return current_user.faculty_profile.id


@batch_router.post("/batch-recognize", response_model=BatchRecognitionResponse)
async def batch_recognize_attendance_photos(
    timetable_entry_id: int = Form(...),
    date: str = Form(...),
    files: List[UploadFile] = File(...),
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db)
):
    """
    Processes multiple group photos in a single batch for attendance marking.
    - Runs face detection and ArcFace/SCRFD recognition across all photos.
    - Merges and deduplicates recognized students across the batch.
    - Retains recognition evidence (best confidence, count of photos recognized in).
    - Tolerates partial photo failures gracefully without aborting the batch.
    - Supports both Faculty and Class Advisor authorization.
    """
    faculty_id = _resolve_faculty_id(current_user, db)

    # 1. Validate date
    dt_now = get_ist_now()
    today_date = dt_now.date()
    try:
        req_date = datetime.strptime(date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid date format. Expected YYYY-MM-DD."
        )

    if req_date > today_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot process recognition for future dates."
        )

    # 2. Validate timetable entry
    entry = db.query(TimetableEntry).filter(TimetableEntry.id == timetable_entry_id).first()
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Timetable slot not found."
        )

    req_day_name = req_date.strftime("%A")
    if entry.day_of_week.lower() != req_day_name.lower():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Timetable slot #{timetable_entry_id} is scheduled for {entry.day_of_week}, which does not match date {date} ({req_day_name})."
        )

    # 3. RBAC: Faculty must be authorized for assignment OR be Class Advisor for the class section
    assignment = entry.assignment
    if not assignment:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No assignment associated with timetable slot."
        )

    is_authorized_faculty = assignment.is_faculty_authorized(faculty_id)
    is_class_advisor = (
        assignment.class_section is not None
        and assignment.class_section.class_advisor_id == faculty_id
    )
    is_admin = (current_user.role == UserRole.ADMIN)

    if not (is_authorized_faculty or is_class_advisor or is_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not authorized to mark or process attendance for this class."
        )

    # 4. Validate batch size
    if not files or len(files) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one photo must be uploaded."
        )

    if len(files) > 15:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Batch size exceeds maximum limit of 15 photos."
        )

    t_batch_start = time.perf_counter()

    # 5. Resolve enrolled students and embeddings from in-memory index
    class_id = assignment.class_id
    engine = RecognitionEngineFactory.get_engine()

    t_idx0 = time.perf_counter()
    class_idx = recognition_index.get_class_index(db, class_id, engine)
    enrolled_students = class_idx.enrolled_students_list
    t_idx1 = time.perf_counter()

    # 6. Process each photo in batch
    photo_summaries: List[BatchPhotoSummary] = []
    merged_students: Dict[int, Dict[str, Any]] = {}
    total_faces_detected = 0
    photos_processed = 0
    photos_failed = 0

    for idx, file in enumerate(files, start=1):
        fname = file.filename or f"photo_{idx}.jpg"
        try:
            image_bytes = await file.read()
            if len(image_bytes) == 0:
                photo_summaries.append(BatchPhotoSummary(
                    filename=fname,
                    faces_detected=0,
                    recognized_count=0,
                    status="ERROR",
                    error_detail="Empty file received."
                ))
                photos_failed += 1
                continue

            if len(image_bytes) > MAX_GROUP_PHOTO_SIZE_MB * 1024 * 1024:
                photo_summaries.append(BatchPhotoSummary(
                    filename=fname,
                    faces_detected=0,
                    recognized_count=0,
                    status="ERROR",
                    error_detail=f"Image size exceeds limit of {MAX_GROUP_PHOTO_SIZE_MB}MB."
                ))
                photos_failed += 1
                continue

            t_dec0 = time.perf_counter()
            nparr = np.frombuffer(image_bytes, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            t_dec1 = time.perf_counter()

            if img is None:
                photo_summaries.append(BatchPhotoSummary(
                    filename=fname,
                    faces_detected=0,
                    recognized_count=0,
                    status="ERROR",
                    error_detail="Invalid or unreadable image file format."
                ))
                photos_failed += 1
                continue

            t_rec0 = time.perf_counter()
            recognition_output = engine.recognize_image(img, enrolled_students=enrolled_students)
            t_rec1 = time.perf_counter()

            logger.info(
                f"[PERF_TIMING] Batch item #{idx} ({fname}): "
                f"decode_ms={(t_dec1 - t_dec0)*1000:.2f}, "
                f"rec_ms={(t_rec1 - t_rec0)*1000:.2f}, "
                f"faces={recognition_output.get('faces_detected', 0)}"
            )

            faces_in_photo = recognition_output.get("faces_detected", 0)
            total_faces_detected += faces_in_photo

            raw_results = recognition_output.get("results") or []
            recognized_in_this_photo = 0

            for r in raw_results:
                if r.get("status") == "HIGH_CONFIDENCE":
                    sid = r.get("student_id")
                    if not sid:
                        continue
                    recognized_in_this_photo += 1
                    r_dist = float(r.get("distance", 0.0))
                    r_conf = float(r.get("derived_score", 0.0))
                    r_name = r.get("name") or r.get("full_name") or ""
                    r_roll = r.get("roll_number") or ""


                    if sid not in merged_students:
                        merged_students[sid] = {
                            "student_id": sid,
                            "roll_number": r_roll,
                            "name": r_name,
                            "best_distance": r_dist,
                            "best_confidence": r_conf,
                            "recognized_in_photos_count": 1,
                            "source_photos": [fname]
                        }
                    else:
                        merged_students[sid]["recognized_in_photos_count"] += 1
                        if fname not in merged_students[sid]["source_photos"]:
                            merged_students[sid]["source_photos"].append(fname)
                        if r_dist < merged_students[sid]["best_distance"]:
                            merged_students[sid]["best_distance"] = r_dist
                            merged_students[sid]["best_confidence"] = r_conf

            photo_status = "SUCCESS" if faces_in_photo > 0 else "NO_FACES"
            photo_summaries.append(BatchPhotoSummary(
                filename=fname,
                faces_detected=faces_in_photo,
                recognized_count=recognized_in_this_photo,
                status=photo_status,
                error_detail="No faces detected in this photograph." if faces_in_photo == 0 else None
            ))
            photos_processed += 1

        except Exception as e:
            logger.exception(f"Error processing batch photo {fname}: {e}")
            photo_summaries.append(BatchPhotoSummary(
                filename=fname,
                faces_detected=0,
                recognized_count=0,
                status="ERROR",
                error_detail=f"Recognition failed: {str(e)}"
            ))
            photos_failed += 1

    # 7. Construct response
    recognized_list = [
        BatchRecognizedStudent(
            student_id=data["student_id"],
            roll_number=data["roll_number"],
            name=data["name"],
            best_distance=round(data["best_distance"], 4),
            best_confidence=round(data["best_confidence"], 2),
            recognized_in_photos_count=data["recognized_in_photos_count"],
            source_photos=data["source_photos"]
        )
        for data in merged_students.values()
    ]
    # Sort by roll_number
    recognized_list.sort(key=lambda s: s.roll_number)

    # 8. Audit log
    audit = AuditLog(
        user_id=current_user.id,
        action="BATCH_PHOTO_RECOGNITION",
        details=(
            f"User #{current_user.id} processed batch of {len(files)} photos for TT #{timetable_entry_id} on {date}. "
            f"Successfully processed {photos_processed} ({photos_failed} failed). "
            f"Detected {total_faces_detected} faces; recognized {len(recognized_list)} unique students."
        )
    )
    db.add(audit)
    db.commit()

    total_batch_duration_ms = (time.perf_counter() - t_batch_start) * 1000
    logger.info(
        f"[PERF_TIMING] Batch recognition summary: "
        f"total_batch_ms={total_batch_duration_ms:.2f}, "
        f"template_index_ms={(t_idx1 - t_idx0)*1000:.2f}, "
        f"photos_processed={photos_processed}, "
        f"photos_failed={photos_failed}, "
        f"total_faces_detected={total_faces_detected}, "
        f"unique_recognized={len(recognized_list)}, "
        f"templates_in_index={class_idx.total_templates}"
    )

    return BatchRecognitionResponse(
        total_photos=len(files),
        photos_processed=photos_processed,
        photos_failed=photos_failed,
        total_faces_detected=total_faces_detected,
        unique_recognized_count=len(recognized_list),
        recognized_students=recognized_list,
        photo_summaries=photo_summaries
    )


