import os
import json
from typing import List, Optional, Dict, Tuple
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Body
from fastapi.responses import FileResponse
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.user import User
from app.models.student import Student
from app.models.academic import ClassSection
from app.models.attendance import FaceEmbedding
from app.models.audit import AuditLog
from app.api.deps import require_admin
from app.engines.recognition.factory import RecognitionEngineFactory
from app.schemas.academic import (
    BiometricOverviewOut,
    BiometricStudentSummaryOut,
    FolderEnrollmentResultItem,
    FolderStudentEnrollmentResult,
    FolderEnrollmentBatchResponse,
    FolderManifestStudentItem,
    FolderManifestResponse,
    FolderPathEnrollmentRequest,
    StudentPhotoItemOut,
    StudentDatasetViewOut,
    MultiPhotoEnrollmentResultItem,
    MultiPhotoEnrollmentResponse,
)
from app.services.face_dataset_service import (
    save_student_face_image,
    get_student_dir,
    resolve_photo_path,
    delete_student_photo_file,
    clear_student_photos_dir,
    check_duplicate_photo,
    sanitize_roll_number,
)
from app.services.recognition_index import recognition_index
from app.services.biometric_migration import get_migration_status, migrate_legacy_students_from_photos

router = APIRouter(prefix="/admin", tags=["Admin Student Face Enrollment & Biometrics"], dependencies=[Depends(require_admin)])


MAX_ENROLLMENT_SIZE_MB = 10
SUPPORTED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}

def is_path_enrolled_marker(path: Optional[str]) -> bool:
    if not path:
        return False
    return path.startswith((
        "upload:", "admin:", "folder:", "admin_folder:",
        "data/student_faces/", "student_faces/"
    ))


# ==========================================
# BIOMETRICS OVERVIEW & CONTROLS
# ==========================================

@router.get("/biometrics/summary", response_model=BiometricOverviewOut)
def admin_get_biometrics_summary(db: Session = Depends(get_db)):
    """
    Returns high-level biometric engine configuration and enrollment statistics.
    Exposes only safe system metadata and student counts; zero raw embeddings.
    """
    engine = RecognitionEngineFactory.get_engine()
    total_students = db.query(Student).count()

    all_embs = db.query(FaceEmbedding.student_id, FaceEmbedding.image_path).all()
    student_templates = {}
    for sid, ip in all_embs:
        student_templates.setdefault(sid, []).append(ip or "")
    enrolled_count = sum(
        1 for paths in student_templates.values()
        if len(paths) >= 3 or any(is_path_enrolled_marker(p) for p in paths)
    )
    pending_count = max(0, total_students - enrolled_count)

    return BiometricOverviewOut(
        total_students=total_students,
        enrolled_count=enrolled_count,
        pending_count=pending_count,
        model_name=engine.model_name,
        model_version=engine.model_version,
        dimension=engine.embedding_dimension,
        detector_name=engine.detector_name,
        distance_metric=engine.distance_metric,
    )


@router.get("/biometrics/migration/status")
def admin_get_migration_status(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Returns diagnostic breakdown of students enrolled in the active engine vs. legacy engines,
    and identifies students eligible for automated photo-based template migration.
    """
    return get_migration_status(db)


@router.post("/biometrics/migration/run")
def admin_run_biometric_migration(
    dry_run: bool = False,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Executes audited biometric migration from dataset photos to the active ArcFace engine.
    Never reinterprets 128-d vectors and preserves all student/attendance records intact.
    """
    return migrate_legacy_students_from_photos(db, user_id=current_user.id, dry_run=dry_run)


@router.get("/biometrics/students", response_model=List[BiometricStudentSummaryOut])
def admin_list_biometric_students(
    search: Optional[str] = None,
    enrolled_only: Optional[bool] = None,
    class_id: Optional[int] = None,
    db: Session = Depends(get_db)
):
    """
    Lists students with their biometric enrollment status, template count, and engine metadata.
    STRICT PRIVACY: Never returns raw embeddings or image data.
    """
    query = db.query(Student)

    if search:
        s = f"%{search.strip()}%"
        query = query.filter((Student.full_name.ilike(s)) | (Student.roll_number.ilike(s)))
    if class_id is not None:
        query = query.filter(Student.class_id == class_id)

    students = query.order_by(Student.roll_number.asc()).all()
    result = []
    for st in students:
        embs = st.face_embeddings or []
        t_count = len(embs)
        is_enrolled = t_count >= 3 or any(is_path_enrolled_marker(e.image_path) for e in embs)

        if enrolled_only is True and not is_enrolled:
            continue
        if enrolled_only is False and is_enrolled:
            continue

        latest_emb = max(embs, key=lambda e: e.created_at) if embs else None
        last_enrolled = latest_emb.created_at.isoformat() if (latest_emb and latest_emb.created_at) else None

        result.append(BiometricStudentSummaryOut(
            student_id=st.id,
            roll_number=st.roll_number,
            full_name=st.full_name,
            class_name=st.class_section.name if st.class_section else None,
            enrolled=is_enrolled,
            template_count=t_count,
            model_name=latest_emb.model_name if latest_emb else "dlib_resnet",
            model_version=latest_emb.model_version if latest_emb else "v1",
            dimension=latest_emb.dimension if latest_emb else 128,
            detector_name=latest_emb.detector_name if latest_emb else "dlib_hog",
            distance_metric=latest_emb.distance_metric if latest_emb else "euclidean",
            quality_score=latest_emb.quality_score if latest_emb else None,
            last_enrollment_at=last_enrolled,
        ))
    return result


@router.post("/biometrics/{student_id}/reset")
def admin_reset_student_biometrics(
    student_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Admin resets/revokes biometric face enrollment for a student.
    Permanently deletes all biometric templates for this student so they can be re-enrolled cleanly.
    """
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    deleted_count = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == student_id).delete()
    deleted_files_count = clear_student_photos_dir(student.roll_number)

    audit = AuditLog(
        user_id=current_user.id,
        action="BIOMETRIC_RESET",
        target=student.roll_number,
        details=f"Admin revoked and deleted {deleted_count} biometric template(s) and {deleted_files_count} dataset photo(s) for student #{student.id} ({student.full_name}, Roll: {student.roll_number})"
    )
    db.add(audit)
    db.commit()
    recognition_index.invalidate(student.class_id)

    return {
        "message": f"Biometric enrollment reset successfully for {student.full_name}",
        "student_id": student.id,
        "roll_number": student.roll_number,
        "deleted_templates": deleted_count,
        "deleted_photos": deleted_files_count,
    }


# ==========================================
# INDIVIDUAL STUDENT FACE ENROLLMENT
# ==========================================

@router.post("/students/{student_id}/enroll-face")
async def admin_enroll_student_face(
    student_id: int,
    file: UploadFile = File(...),
    replace: bool = False,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Enrolls a new face embedding for a student from an uploaded photo.
    Validates exactly ONE clear face is present in the image.
    Supports safe replacement when replace=True.
    """
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    existing_embs = student.face_embeddings or []
    if len(existing_embs) > 0 and not replace:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Student already has an enrolled face profile. Confirm replacement to re-enroll."
        )

    # Validate file content type
    if file.content_type not in ["image/jpeg", "image/png", "image/webp", "image/jpg"]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unsupported image file type. Upload JPEG or PNG.")

    image_bytes = await file.read()
    if len(image_bytes) > MAX_ENROLLMENT_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Image file size exceeds maximum limit of {MAX_ENROLLMENT_SIZE_MB}MB.")

    engine = RecognitionEngineFactory.get_engine()

    # Detect faces in image
    locations = engine.detect_faces(image_bytes)

    if len(locations) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No face detected in enrollment image. Ensure good lighting and clear face visibility."
        )

    if len(locations) > 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Multiple faces ({len(locations)}) detected. Enrollment image must contain exactly ONE student face."
        )

    top, right, bottom, left = locations[0]
    face_w = right - left
    face_h = bottom - top
    if face_w < 20 or face_h < 20:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Detected face is too small or low resolution for reliable biometric enrollment."
        )

    # Extract vector embedding
    encodings = engine.generate_embeddings(image_bytes, locations)
    if not encodings:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Failed to extract facial vector features.")

    emb_vec = encodings[0]
    import numpy as np
    if len(emb_vec) != engine.embedding_dimension or not np.all(np.isfinite(emb_vec)):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Extracted facial vector contains invalid or non-finite values.")
    norm = float(np.linalg.norm(emb_vec))
    if norm < 1e-6:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Extracted facial vector has degenerate zero norm.")
    if engine.distance_metric == "cosine" and not np.isclose(norm, 1.0, atol=1e-3):
        emb_vec = emb_vec / norm

    # If replacing existing enrollment, purge previous templates and clean dataset folder
    deleted_old = 0
    if len(existing_embs) > 0 and replace:
        deleted_old = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == student.id).delete()
        clear_student_photos_dir(student.roll_number)

    # Persist photo into canonical student face dataset folder
    rel_path, abs_path = save_student_face_image(student.roll_number, image_bytes, file.filename)

    emb_json = json.dumps(emb_vec.tolist())

    face_emb = FaceEmbedding(
        student_id=student.id,
        embedding_json=emb_json,
        image_path=rel_path,
        model_name=engine.model_name,
        model_version=engine.model_version,
        dimension=engine.embedding_dimension,
        detector_name=engine.detector_name,
        distance_metric=engine.distance_metric,
        quality_score=None
    )
    db.add(face_emb)

    # Audit log entry
    audit_action = "FACE_REPLACEMENT" if (replace and deleted_old > 0) else "FACE_ENROLLMENT"
    audit_detail = (
        f"Replaced {deleted_old} old template(s) with new face profile for Student #{student.id} ('{student.full_name}', Roll: {student.roll_number})"
        if audit_action == "FACE_REPLACEMENT"
        else f"Enrolled face profile embedding for Student #{student.id} ('{student.full_name}', Roll: {student.roll_number})"
    )
    audit = AuditLog(
        user_id=current_user.id,
        action=audit_action,
        target=student.roll_number,
        details=audit_detail
    )
    db.add(audit)

    db.commit()
    db.refresh(face_emb)
    recognition_index.invalidate(student.class_id)

    return {
        "message": f"Successfully enrolled face profile for {student.full_name}",
        "embedding_id": face_emb.id,
        "student_id": student.id,
        "roll_number": student.roll_number,
        "full_name": student.full_name,
        "enrolled": True,
        "template_count": 1
    }


@router.post("/students/{student_id}/reset-face")
@router.delete("/students/{student_id}/biometrics")
def admin_remove_student_face(
    student_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Convenience alias to revoke/delete student biometric templates.
    """
    return admin_reset_student_biometrics(student_id=student_id, current_user=current_user, db=db)


@router.get("/students/{student_id}/biometrics")
def admin_get_student_biometrics_status(
    student_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Safely retrieves a student's biometric enrollment status and safe metadata for the Admin Portal.
    Strict privacy rule: Returns NO raw embedding vectors and NO raw biometric photos.
    """
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    embs = student.face_embeddings or []
    count = len(embs)
    is_enrolled = count >= 3 or any(is_path_enrolled_marker(e.image_path) for e in embs)
    last_enrolled = max([e.created_at for e in embs if e.created_at]).isoformat() if embs and any(e.created_at for e in embs) else None

    templates = [
        {
            "id": e.id,
            "dimension": e.dimension,
            "model_name": e.model_name,
            "detector_name": e.detector_name,
            "distance_metric": e.distance_metric,
            "quality_score": e.quality_score,
            "created_at": e.created_at.isoformat() if e.created_at else None,
        }
        for e in embs
    ]

    return {
        "student_id": student.id,
        "full_name": student.full_name,
        "roll_number": student.roll_number,
        "class_name": student.class_section.name if student.class_section else None,
        "enrolled": is_enrolled,
        "template_count": count,
        "required_templates": 1 if any(is_path_enrolled_marker(e.image_path) for e in embs) else 3,
        "last_enrollment_time": last_enrolled,
        "templates": templates
    }


# ==========================================
# PHASE 7.7: FOLDER-BASED STUDENT FACE ENROLLMENT
# ==========================================

def extract_register_number_from_path(
    file_path: str,
    known_roll_numbers: Optional[set] = None
) -> Optional[str]:
    """
    Authoritative extraction: IDENTITY = FOLDER NAME.
    File names, timestamps, and image metadata are completely irrelevant and ignored.
    Supports:
    1. Single student folder: e.g. '721025149001/face1.jpg' -> '721025149001'
    2. Bulk dataset folder: e.g. 'dataset/721025149001/face1.jpg' -> '721025149001'
    3. Nested variants: e.g. 'faces/2026/721025149001/front.png' -> '721025149001'
    """
    clean_p = file_path.replace("\\", "/").strip("/")
    parts = [p for p in clean_p.split("/") if p]
    if len(parts) < 2:
        return None

    dir_parts = parts[:-1]

    # If known roll numbers exist, check from deepest folder upward
    if known_roll_numbers:
        for part in reversed(dir_parts):
            if part in known_roll_numbers:
                return part

    # Otherwise fallback to the deepest directory component containing the file
    candidate = dir_parts[-1]
    if candidate and not candidate.startswith(".") and len(candidate) >= 3:
        return candidate

    return None


def validate_and_embed_face(
    image_bytes: bytes,
    filename: str,
    student_id: int,
    roll_number: str,
    engine
) -> Tuple[FolderEnrollmentResultItem, Optional[FaceEmbedding]]:
    """
    Validates a single image file through the existing biometric pipeline:
    - Checks size <= 10MB
    - Detects faces: exactly 1 required
    - Checks face resolution >= 20px
    - Generates 128-d Euclidean embedding with existing engine
    """
    if len(image_bytes) > MAX_ENROLLMENT_SIZE_MB * 1024 * 1024:
        return (
            FolderEnrollmentResultItem(
                filename=filename,
                status="REJECTED_SIZE",
                reason=f"Image size exceeds limit of {MAX_ENROLLMENT_SIZE_MB}MB",
                faces_detected=0
            ),
            None
        )

    try:
        locations = engine.detect_faces(image_bytes)
    except Exception as e:
        return (
            FolderEnrollmentResultItem(
                filename=filename,
                status="ERROR",
                reason=f"Failed to decode image: {str(e)}",
                faces_detected=0
            ),
            None
        )

    if len(locations) == 0:
        return (
            FolderEnrollmentResultItem(
                filename=filename,
                status="REJECTED_NO_FACE",
                reason="No face detected in photo. Ensure clear lighting and front-facing visibility.",
                faces_detected=0
            ),
            None
        )

    if len(locations) > 1:
        return (
            FolderEnrollmentResultItem(
                filename=filename,
                status="REJECTED_MULTI_FACE",
                reason=f"Multiple faces ({len(locations)}) detected. Exactly ONE face required.",
                faces_detected=len(locations)
            ),
            None
        )

    top, right, bottom, left = locations[0]
    face_w = right - left
    face_h = bottom - top
    if face_w < 20 or face_h < 20:
        return (
            FolderEnrollmentResultItem(
                filename=filename,
                status="REJECTED_LOW_RES",
                reason="Detected face resolution is too small (<20px) for reliable enrollment.",
                faces_detected=1
            ),
            None
        )

    try:
        encodings = engine.generate_embeddings(image_bytes, locations)
        if not encodings or len(encodings) == 0:
            return (
                FolderEnrollmentResultItem(
                    filename=filename,
                    status="ERROR",
                    reason="Failed to extract facial vector features.",
                    faces_detected=1
                ),
                None
            )
    except Exception as e:
        return (
            FolderEnrollmentResultItem(
                filename=filename,
                status="ERROR",
                reason=f"Error generating embedding: {str(e)}",
                faces_detected=1
            ),
            None
        )

    rel_path, abs_path = save_student_face_image(roll_number, image_bytes, filename)

    emb_vec = encodings[0]
    import numpy as np
    if len(emb_vec) != engine.embedding_dimension or not np.all(np.isfinite(emb_vec)):
        return (
            FolderEnrollmentResultItem(
                filename=filename,
                status="ERROR",
                reason="Generated vector contains invalid or non-finite values.",
                faces_detected=1
            ),
            None
        )
    norm = float(np.linalg.norm(emb_vec))
    if norm < 1e-6:
        return (
            FolderEnrollmentResultItem(
                filename=filename,
                status="ERROR",
                reason="Generated vector has degenerate zero norm.",
                faces_detected=1
            ),
            None
        )
    if engine.distance_metric == "cosine" and not np.isclose(norm, 1.0, atol=1e-3):
        emb_vec = emb_vec / norm

    emb_json = json.dumps(emb_vec.tolist())

    face_emb = FaceEmbedding(
        student_id=student_id,
        embedding_json=emb_json,
        image_path=rel_path,
        model_name=engine.model_name,
        model_version=engine.model_version,
        dimension=engine.embedding_dimension,
        detector_name=engine.detector_name,
        distance_metric=engine.distance_metric,
        quality_score=None
    )

    return (
        FolderEnrollmentResultItem(
            filename=filename,
            status="ENROLLED",
            faces_detected=1
        ),
        face_emb
    )


def process_folder_enrollment_batch(
    student_files_map: Dict[str, List[Tuple[str, bytes]]],
    replace: bool,
    append: bool,
    dry_run: bool,
    current_user: User,
    db: Session
) -> FolderEnrollmentBatchResponse:
    """
    Executes biometric validation and template registration for all student folders in a batch.
    IDENTITY is strictly determined by student register number (folder name).
    Photo filenames are completely irrelevant to student identity.
    """
    engine = RecognitionEngineFactory.get_engine()
    roll_numbers = list(student_files_map.keys())

    students = db.query(Student).filter(Student.roll_number.in_(roll_numbers)).all() if roll_numbers else []
    student_lookup = {s.roll_number: s for s in students}

    total_folders = len(student_files_map)
    total_files_processed = sum(len(fl) for fl in student_files_map.values())
    successful_students = 0
    failed_students = 0
    total_embeddings_created = 0
    student_results: List[FolderStudentEnrollmentResult] = []

    for reg_no, files_list in student_files_map.items():
        student = student_lookup.get(reg_no)

        if not student:
            failed_students += 1
            items = [
                FolderEnrollmentResultItem(
                    filename=fname,
                    status="STUDENT_NOT_FOUND",
                    reason=f"Register number '{reg_no}' does not match any registered student in database.",
                    faces_detected=0
                )
                for fname, _ in files_list
            ]
            student_results.append(FolderStudentEnrollmentResult(
                roll_number=reg_no,
                student_id=None,
                full_name=None,
                class_name=None,
                status="STUDENT_NOT_FOUND",
                total_files=len(files_list),
                valid_enrolled=0,
                rejected=len(files_list),
                replaced_old_count=0,
                message=f"Student register number '{reg_no}' was not found in the database. Ensure student is added to roster first.",
                items=items
            ))
            continue

        existing_embs = student.face_embeddings or []
        if len(existing_embs) > 0 and not replace and not append:
            items = [
                FolderEnrollmentResultItem(
                    filename=fname,
                    status="SKIPPED_ALREADY_ENROLLED",
                    reason=f"Student already has {len(existing_embs)} enrolled template(s). Replacement was not requested.",
                    faces_detected=0
                )
                for fname, _ in files_list
            ]
            student_results.append(FolderStudentEnrollmentResult(
                roll_number=student.roll_number,
                student_id=student.id,
                full_name=student.full_name,
                class_name=student.class_section.name if student.class_section else None,
                status="SKIPPED_ALREADY_ENROLLED",
                total_files=len(files_list),
                valid_enrolled=0,
                rejected=0,
                replaced_old_count=0,
                message=f"Student already has {len(existing_embs)} enrolled template(s). Select 'Replace' to overwrite.",
                items=items
            ))
            continue

        if dry_run:
            student_results.append(FolderStudentEnrollmentResult(
                roll_number=student.roll_number,
                student_id=student.id,
                full_name=student.full_name,
                class_name=student.class_section.name if student.class_section else None,
                status="DRY_RUN_READY",
                total_files=len(files_list),
                valid_enrolled=0,
                rejected=0,
                replaced_old_count=len(existing_embs) if replace else 0,
                message=f"Ready for enrollment. Found {len(files_list)} photo(s).",
                items=[]
            ))
            continue

        # Purge existing templates and dataset photos if replacing
        deleted_old = 0
        if replace and len(existing_embs) > 0:
            deleted_old = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == student.id).delete()
            clear_student_photos_dir(student.roll_number)

        items: List[FolderEnrollmentResultItem] = []
        valid_count = 0
        rejected_count = 0

        for fname, img_bytes in files_list:
            ext = os.path.splitext(fname)[1].lower()
            if ext not in SUPPORTED_IMAGE_EXTENSIONS:
                items.append(FolderEnrollmentResultItem(
                    filename=fname,
                    status="SKIPPED_NOT_AN_IMAGE",
                    reason=f"Unsupported file format '{ext}'. Only JPEG, PNG, and WebP are accepted.",
                    faces_detected=0
                ))
                rejected_count += 1
                continue

            item, face_emb = validate_and_embed_face(
                image_bytes=img_bytes,
                filename=fname,
                student_id=student.id,
                roll_number=student.roll_number,
                engine=engine
            )

            if face_emb is not None:
                db.add(face_emb)
                db.flush()
                item.embedding_id = face_emb.id
                valid_count += 1
            else:
                rejected_count += 1

            items.append(item)

        if valid_count > 0:
            status_str = "SUCCESS" if rejected_count == 0 else "PARTIAL_SUCCESS"
            successful_students += 1
            total_embeddings_created += valid_count

            audit_action = "ADMIN_FOLDER_FACE_REPLACEMENT" if (replace and deleted_old > 0) else "ADMIN_FOLDER_FACE_ENROLLMENT"
            audit_detail = (
                f"Replaced {deleted_old} old template(s) with {valid_count} new face sample(s) from folder for Student #{student.id} ('{student.full_name}', Roll: {student.roll_number})"
                if audit_action == "ADMIN_FOLDER_FACE_REPLACEMENT"
                else f"Enrolled {valid_count} face template(s) from folder for Student #{student.id} ('{student.full_name}', Roll: {student.roll_number})"
            )
            audit = AuditLog(
                user_id=current_user.id,
                action=audit_action,
                target=student.roll_number,
                details=audit_detail
            )
            db.add(audit)
        else:
            status_str = "NO_VALID_IMAGES"
            failed_students += 1

        msg_parts = [f"Enrolled {valid_count} template(s)"]
        if deleted_old > 0:
            msg_parts.append(f"replaced {deleted_old} old template(s)")
        if rejected_count > 0:
            msg_parts.append(f"{rejected_count} sample(s) rejected")

        student_results.append(FolderStudentEnrollmentResult(
            roll_number=student.roll_number,
            student_id=student.id,
            full_name=student.full_name,
            class_name=student.class_section.name if student.class_section else None,
            status=status_str,
            total_files=len(files_list),
            valid_enrolled=valid_count,
            rejected=rejected_count,
            replaced_old_count=deleted_old,
            message=", ".join(msg_parts),
            items=items
        ))

    if not dry_run:
        db.commit()
        recognition_index.invalidate()


    return FolderEnrollmentBatchResponse(
        total_folders=total_folders,
        total_files_processed=total_files_processed,
        successful_students=successful_students,
        failed_students=failed_students,
        total_embeddings_created=total_embeddings_created,
        message=f"Folder face enrollment completed: {successful_students} student(s) enrolled, {total_embeddings_created} template(s) saved.",
        students=student_results
    )


@router.post("/preview-folder-path", response_model=FolderManifestResponse)
def admin_preview_folder_path(
    req: FolderPathEnrollmentRequest,
    db: Session = Depends(get_db)
):
    """
    Pre-flight inspection for a server-side folder directory.
    Scans files, extracts register numbers, resolves student identities in the database,
    and returns a full manifest before committing any changes.
    """
    folder_path = os.path.normpath(req.folder_path.strip('"\''))
    if not os.path.exists(folder_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Specified folder path does not exist on server: {folder_path}"
        )
    if not os.path.isdir(folder_path):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Specified path is a file, not a directory: {folder_path}"
        )

    all_students = db.query(Student).all()
    known_rolls = {s.roll_number for s in all_students}
    student_lookup = {s.roll_number: s for s in all_students}

    folder_files_map: Dict[str, List[str]] = {}
    ignored_non_images = 0

    # Scan directory recursively
    for root, _, files in os.walk(folder_path):
        for fname in files:
            full_p = os.path.join(root, fname)
            rel_p = os.path.relpath(full_p, folder_path).replace("\\", "/")

            reg_no: Optional[str] = None
            if "/" in rel_p:
                reg_no = extract_register_number_from_path(rel_p, known_rolls)
            else:
                # File is directly in root of folder_path
                base_name = os.path.basename(folder_path)
                reg_no = base_name if base_name in known_rolls else None

            if not reg_no:
                ignored_non_images += 1
                continue

            ext = os.path.splitext(fname)[1].lower()
            if ext in SUPPORTED_IMAGE_EXTENSIONS:
                folder_files_map.setdefault(reg_no, []).append(fname)
            else:
                ignored_non_images += 1

    students_manifest: List[FolderManifestStudentItem] = []
    found_count = 0
    missing_count = 0
    total_images = sum(len(fl) for fl in folder_files_map.values())

    for reg_no, fl in folder_files_map.items():
        st = student_lookup.get(reg_no)
        if st:
            found_count += 1
            t_count = len(st.face_embeddings or [])
            students_manifest.append(FolderManifestStudentItem(
                roll_number=st.roll_number,
                student_id=st.id,
                full_name=st.full_name,
                class_name=st.class_section.name if st.class_section else None,
                exists_in_db=True,
                current_template_count=t_count,
                image_files_count=len(fl),
                files=fl[:10]  # sample first 10
            ))
        else:
            missing_count += 1
            students_manifest.append(FolderManifestStudentItem(
                roll_number=reg_no,
                student_id=None,
                full_name=None,
                class_name=None,
                exists_in_db=False,
                current_template_count=0,
                image_files_count=len(fl),
                files=fl[:10]
            ))

    # Sort students by roll number
    students_manifest.sort(key=lambda s: s.roll_number)

    return FolderManifestResponse(
        folder_path=folder_path,
        total_folders=len(folder_files_map),
        total_image_files=total_images,
        ignored_non_image_files=ignored_non_images,
        students_found_in_db=found_count,
        students_missing_in_db=missing_count,
        students=students_manifest
    )


@router.post("/enroll-folder-path", response_model=FolderEnrollmentBatchResponse)
def admin_enroll_folder_path(
    req: FolderPathEnrollmentRequest,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Enrolls student face photos directly from a local filesystem path on the host.
    IDENTITY = FOLDER NAME.
    Supports single student folder (e.g. dataset/721025149001) or parent dataset containing multiple student folders.
    """
    folder_path = os.path.normpath(req.folder_path.strip('"\''))
    if not os.path.exists(folder_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Specified folder path does not exist on server: {folder_path}"
        )
    if not os.path.isdir(folder_path):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Specified path is not a directory: {folder_path}"
        )

    all_students = db.query(Student).all()
    known_rolls = {s.roll_number for s in all_students}

    student_files_map: Dict[str, List[Tuple[str, bytes]]] = {}

    for root, _, files in os.walk(folder_path):
        for fname in sorted(files):
            full_p = os.path.join(root, fname)
            rel_p = os.path.relpath(full_p, folder_path).replace("\\", "/")

            reg_no: Optional[str] = None
            if "/" in rel_p:
                reg_no = extract_register_number_from_path(rel_p, known_rolls)
            else:
                base_name = os.path.basename(folder_path)
                reg_no = base_name if base_name in known_rolls else None

            if not reg_no:
                continue

            try:
                with open(full_p, "rb") as fp:
                    data = fp.read()
                student_files_map.setdefault(reg_no, []).append((fname, data))
            except Exception as e:
                pass

    if not student_files_map:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No student folders or image files found in specified directory."
        )

    return process_folder_enrollment_batch(
        student_files_map=student_files_map,
        replace=req.replace,
        append=req.append,
        dry_run=req.dry_run,
        current_user=current_user,
        db=db
    )


@router.post("/enroll-folder", response_model=FolderEnrollmentBatchResponse)
async def admin_enroll_folder(
    files: List[UploadFile] = File(...),
    paths: Optional[List[str]] = Form(None),
    paths_json: Optional[str] = Form(None),
    replace: bool = Form(False),
    append: bool = Form(False),
    dry_run: bool = Form(False),
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Enrolls student face photos uploaded as a complete folder via multipart form-data.
    Folder name MUST be the student's register number.
    All photos inside the folder are associated with that register number.
    Photo filenames and metadata are completely irrelevant to identity.
    """
    if not files:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No files uploaded.")

    # Parse relative paths
    relative_paths: List[str] = []
    if paths_json:
        try:
            relative_paths = json.loads(paths_json)
        except Exception:
            relative_paths = []
    elif paths:
        relative_paths = paths

    all_students = db.query(Student).all()
    known_rolls = {s.roll_number for s in all_students}

    student_files_map: Dict[str, List[Tuple[str, bytes]]] = {}

    for i, file_obj in enumerate(files):
        rel_path = relative_paths[i] if i < len(relative_paths) else file_obj.filename

        reg_no = extract_register_number_from_path(rel_path, known_rolls)
        if not reg_no:
            # Check if filename itself contains directory prefix (e.g. "721025149001/face.jpg")
            reg_no = extract_register_number_from_path(file_obj.filename, known_rolls)

        if not reg_no:
            continue

        data = await file_obj.read()
        clean_fname = os.path.basename(file_obj.filename)
        student_files_map.setdefault(reg_no, []).append((clean_fname, data))

    if not student_files_map:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not determine student register numbers from uploaded folder structure. Ensure folder is named after the student's register number (e.g. '721025149001/photo.jpg')."
        )

    return process_folder_enrollment_batch(
        student_files_map=student_files_map,
        replace=replace,
        append=append,
        dry_run=dry_run,
        current_user=current_user,
        db=db
    )


@router.post("/inspect-folder-manifest", response_model=FolderManifestResponse)
def admin_inspect_folder_manifest(
    paths: List[str] = Body(...),
    db: Session = Depends(get_db)
):
    """
    Inspects a list of relative file paths from an in-browser folder selection.
    Extracts register numbers and checks whether students exist in the database.
    """
    all_students = db.query(Student).all()
    known_rolls = {s.roll_number for s in all_students}
    student_lookup = {s.roll_number: s for s in all_students}

    folder_files_map: Dict[str, List[str]] = {}
    ignored_count = 0

    for p in paths:
        reg_no = extract_register_number_from_path(p, known_rolls)
        if not reg_no:
            ignored_count += 1
            continue

        fname = os.path.basename(p)
        ext = os.path.splitext(fname)[1].lower()
        if ext in SUPPORTED_IMAGE_EXTENSIONS:
            folder_files_map.setdefault(reg_no, []).append(fname)
        else:
            ignored_count += 1

    students_manifest: List[FolderManifestStudentItem] = []
    found_count = 0
    missing_count = 0
    total_images = sum(len(fl) for fl in folder_files_map.values())

    for reg_no, fl in folder_files_map.items():
        st = student_lookup.get(reg_no)
        if st:
            found_count += 1
            t_count = len(st.face_embeddings or [])
            students_manifest.append(FolderManifestStudentItem(
                roll_number=st.roll_number,
                student_id=st.id,
                full_name=st.full_name,
                class_name=st.class_section.name if st.class_section else None,
                exists_in_db=True,
                current_template_count=t_count,
                image_files_count=len(fl),
                files=fl[:10]
            ))
        else:
            missing_count += 1
            students_manifest.append(FolderManifestStudentItem(
                roll_number=reg_no,
                student_id=None,
                full_name=None,
                class_name=None,
                exists_in_db=False,
                current_template_count=0,
                image_files_count=len(fl),
                files=fl[:10]
            ))

    students_manifest.sort(key=lambda s: s.roll_number)

    return FolderManifestResponse(
        total_folders=len(folder_files_map),
        total_image_files=total_images,
        ignored_non_image_files=ignored_count,
        students_found_in_db=found_count,
        students_missing_in_db=missing_count,
        students=students_manifest
    )


# ==========================================
# PHASE 7.8: CANONICAL STUDENT FACE DATASET & MULTI-PHOTO ENROLLMENT
# ==========================================

@router.post("/students/{student_id}/enroll-photos", response_model=MultiPhotoEnrollmentResponse)
async def admin_enroll_student_photos(
    student_id: int,
    files: List[UploadFile] = File(...),
    replace: bool = Form(False),
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Enrolls multiple face photos for a student.
    - Persists valid photos under canonical directory: data/student_faces/<register_number>/<filename>
    - Extracts 128-d Euclidean embeddings with existing recognition engine
    - Registers FaceEmbedding database records
    - Supports partial success: per-photo reporting of accepted, rejected, and skipped
    - Supports duplicate protection
    - Supports replace=True (destructive replacement requiring explicit admin confirmation)
    """
    if not files:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No files uploaded.")

    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    if not student.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot enroll biometrics for inactive student.")

    engine = RecognitionEngineFactory.get_engine()
    existing_embs = student.face_embeddings or []

    # If replacing existing enrollment, purge previous templates and clean dataset directory
    deleted_old = 0
    if len(existing_embs) > 0 and replace:
        deleted_old = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == student.id).delete()
        clear_student_photos_dir(student.roll_number)
        db.flush()
        existing_vecs = []
    else:
        existing_vecs = []
        for e in existing_embs:
            try:
                v = json.loads(e.embedding_json)
                if len(v) == engine.embedding_dimension:
                    existing_vecs.append(np.array(v, dtype=np.float64))
            except Exception:
                pass

    items: List[MultiPhotoEnrollmentResultItem] = []
    valid_count = 0
    rejected_count = 0

    for file_obj in files:
        fname = os.path.basename(file_obj.filename)
        ext = os.path.splitext(fname)[1].lower()

        if ext not in SUPPORTED_IMAGE_EXTENSIONS:
            items.append(MultiPhotoEnrollmentResultItem(
                filename=fname,
                status="SKIPPED_NOT_AN_IMAGE",
                reason=f"Unsupported file format '{ext}'. Only JPEG, PNG, and WebP are accepted.",
                faces_detected=0
            ))
            rejected_count += 1
            continue

        img_bytes = await file_obj.read()
        if len(img_bytes) > MAX_ENROLLMENT_SIZE_MB * 1024 * 1024:
            items.append(MultiPhotoEnrollmentResultItem(
                filename=fname,
                status="REJECTED_SIZE",
                reason=f"Image size exceeds limit of {MAX_ENROLLMENT_SIZE_MB}MB",
                faces_detected=0
            ))
            rejected_count += 1
            continue

        try:
            locations = engine.detect_faces(img_bytes)
        except Exception as e:
            items.append(MultiPhotoEnrollmentResultItem(
                filename=fname,
                status="ERROR",
                reason=f"Failed to decode image: {str(e)}",
                faces_detected=0
            ))
            rejected_count += 1
            continue

        if len(locations) == 0:
            items.append(MultiPhotoEnrollmentResultItem(
                filename=fname,
                status="REJECTED_NO_FACE",
                reason="No face detected in photo. Ensure clear lighting and front-facing visibility.",
                faces_detected=0
            ))
            rejected_count += 1
            continue

        if len(locations) > 1:
            items.append(MultiPhotoEnrollmentResultItem(
                filename=fname,
                status="REJECTED_MULTI_FACE",
                reason=f"Multiple faces ({len(locations)}) detected. Exactly ONE face required.",
                faces_detected=len(locations)
            ))
            rejected_count += 1
            continue

        top, right, bottom, left = locations[0]
        face_w = right - left
        face_h = bottom - top
        if face_w < 20 or face_h < 20:
            items.append(MultiPhotoEnrollmentResultItem(
                filename=fname,
                status="REJECTED_LOW_RES",
                reason="Detected face resolution is too small (<20px) for reliable enrollment.",
                faces_detected=1
            ))
            rejected_count += 1
            continue

        try:
            encodings = engine.generate_embeddings(img_bytes, locations)
            if not encodings or len(encodings) == 0:
                items.append(MultiPhotoEnrollmentResultItem(
                    filename=fname,
                    status="ERROR",
                    reason="Failed to extract facial vector features.",
                    faces_detected=1
                ))
                rejected_count += 1
                continue
        except Exception as e:
            items.append(MultiPhotoEnrollmentResultItem(
                filename=fname,
                status="ERROR",
                reason=f"Error generating embedding: {str(e)}",
                faces_detected=1
            ))
            rejected_count += 1
            continue

        new_vec = encodings[0]

        # Duplicate protection check
        is_dup, dup_reason = check_duplicate_photo(
            roll_number=student.roll_number,
            image_bytes=img_bytes,
            new_embedding=new_vec,
            existing_embeddings=existing_vecs
        )
        if is_dup:
            items.append(MultiPhotoEnrollmentResultItem(
                filename=fname,
                status="SKIPPED_DUPLICATE",
                reason=dup_reason,
                faces_detected=1
            ))
            rejected_count += 1
            continue

        # Save photo into canonical student face dataset folder: data/student_faces/<roll_number>/<filename>
        rel_path, abs_path = save_student_face_image(student.roll_number, img_bytes, fname)

        emb_json = json.dumps(new_vec.tolist())
        face_emb = FaceEmbedding(
            student_id=student.id,
            embedding_json=emb_json,
            image_path=rel_path,
            model_name=engine.model_name,
            model_version=engine.model_version,
            dimension=engine.embedding_dimension,
            detector_name=engine.detector_name,
            distance_metric=engine.distance_metric,
            quality_score=None
        )
        db.add(face_emb)
        db.flush()

        existing_vecs.append(new_vec)
        valid_count += 1

        items.append(MultiPhotoEnrollmentResultItem(
            filename=fname,
            status="ENROLLED",
            faces_detected=1,
            embedding_id=face_emb.id,
            saved_path=rel_path
        ))

    if valid_count > 0:
        audit_action = "ADMIN_REPLACE_FACE_DATASET" if (replace and deleted_old > 0) else "ADMIN_MULTI_PHOTO_ENROLLMENT"
        audit_detail = (
            f"Replaced {deleted_old} old template(s) with {valid_count} new face sample(s) for Student #{student.id} ('{student.full_name}', Roll: {student.roll_number})"
            if audit_action == "ADMIN_REPLACE_FACE_DATASET"
            else f"Enrolled {valid_count} face photo(s) into dataset for Student #{student.id} ('{student.full_name}', Roll: {student.roll_number})"
        )
        audit = AuditLog(
            user_id=current_user.id,
            action=audit_action,
            target=student.roll_number,
            details=audit_detail
        )
        db.add(audit)

    db.commit()
    recognition_index.invalidate(student.class_id)

    msg = f"Enrolled {valid_count} photo(s)"

    if deleted_old > 0:
        msg += f" (replaced {deleted_old} old template(s))"
    if rejected_count > 0:
        msg += f", {rejected_count} photo(s) rejected/skipped"

    return MultiPhotoEnrollmentResponse(
        student_id=student.id,
        roll_number=student.roll_number,
        full_name=student.full_name,
        total_files=len(files),
        valid_enrolled=valid_count,
        rejected=rejected_count,
        replaced_old_count=deleted_old,
        message=msg,
        items=items
    )


@router.get("/students/{student_id}/photos", response_model=StudentDatasetViewOut)
def admin_get_student_photos(
    student_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Returns list of enrolled photos and metadata for a student.
    Strict privacy: Exposes ZERO raw embedding vectors or biometric distance data.
    """
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    embs = student.face_embeddings or []
    photos_out = []
    for e in embs:
        p_name = os.path.basename(e.image_path) if e.image_path else f"template_{e.id}.jpg"
        if p_name.startswith("upload:"):
            p_name = p_name[len("upload:"):]
        elif p_name.startswith("folder:"):
            p_name = p_name[len("folder:"):]
        photos_out.append(StudentPhotoItemOut(
            embedding_id=e.id,
            filename=p_name,
            image_path=e.image_path or "",
            created_at=e.created_at.isoformat() if e.created_at else None,
            quality_score=e.quality_score
        ))

    student_dir = get_student_dir(student.roll_number, create=False)
    physical_count = len([f for f in os.listdir(student_dir) if os.path.isfile(os.path.join(student_dir, f))]) if os.path.exists(student_dir) else len(photos_out)

    return StudentDatasetViewOut(
        student_id=student.id,
        roll_number=student.roll_number,
        full_name=student.full_name,
        class_name=student.class_section.name if student.class_section else None,
        enrolled=len(embs) > 0,
        photo_count=physical_count,
        template_count=len(embs),
        photos=photos_out
    )


@router.get("/students/{student_id}/photos/{embedding_id}/image")
def admin_get_student_photo_image(
    student_id: int,
    embedding_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Securely serves a student's enrolled face photo to an authorized administrator.
    Strict security:
    - Admin authorization required
    - Validates student ownership of embedding
    - Validates file path strictly inside data/student_faces/<roll_number>/
    - Prevents directory traversal
    """
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    emb = db.query(FaceEmbedding).filter(
        FaceEmbedding.id == embedding_id,
        FaceEmbedding.student_id == student_id
    ).first()
    if not emb or not emb.image_path:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Photo embedding not found")

    abs_path = resolve_photo_path(emb.image_path, student.roll_number)
    if not abs_path or not os.path.exists(abs_path):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Physical photo file not found in dataset")

    ext = os.path.splitext(abs_path)[1].lower()
    media_type = "image/jpeg" if ext in [".jpg", ".jpeg"] else ("image/png" if ext == ".png" else "image/webp")

    return FileResponse(abs_path, media_type=media_type)


@router.delete("/students/{student_id}/photos/{embedding_id}")
def admin_delete_student_photo(
    student_id: int,
    embedding_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Deletes an individual face photo and its corresponding FaceEmbedding template.
    Does NOT delete the student's entire biometric enrollment or other valid templates.
    """
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    emb = db.query(FaceEmbedding).filter(
        FaceEmbedding.id == embedding_id,
        FaceEmbedding.student_id == student_id
    ).first()
    if not emb:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Photo template not found")

    if emb.image_path:
        delete_student_photo_file(emb.image_path, student.roll_number)

    db.delete(emb)
    audit = AuditLog(
        user_id=current_user.id,
        action="ADMIN_DELETE_STUDENT_PHOTO",
        target=student.roll_number,
        details=f"Deleted template #{embedding_id} and corresponding photo file for Student #{student.id} ({student.full_name}, Roll: {student.roll_number})"
    )
    db.add(audit)
    db.commit()
    recognition_index.invalidate(student.class_id)

    remaining_count = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == student_id).count()


    return {
        "message": f"Successfully deleted photo and template #{embedding_id}",
        "embedding_id": embedding_id,
        "student_id": student_id,
        "roll_number": student.roll_number,
        "remaining_templates": remaining_count
    }


@router.post("/students/{student_id}/replace-dataset", response_model=MultiPhotoEnrollmentResponse)
async def admin_replace_student_dataset(
    student_id: int,
    files: List[UploadFile] = File(...),
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Explicit endpoint for replacing a student's face dataset.
    Purges existing photo files and templates, then enrolls the new set.
    """
    return await admin_enroll_student_photos(
        student_id=student_id,
        files=files,
        replace=True,
        current_user=current_user,
        db=db
    )


