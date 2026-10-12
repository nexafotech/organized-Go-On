"""
Biometric Template Migration Service.

Provides safe, audited migration from legacy embeddings (e.g. dlib 128-d)
to next-generation SCRFD + ArcFace 512-d embeddings using stored dataset photos.

Rules:
1. NEVER reinterprets 128-d vectors as 512-d vectors (latent spaces are mathematically incompatible).
2. NEVER deletes existing student records or attendance history.
3. Preserves legacy embedding rows for historical auditability while adding active ArcFace templates.
4. Validates each photo strictly: exactly 1 face, finite vector, unit L2 norm.
5. Flags students without valid photos for re-enrollment.
"""

import os
import json
import logging
from typing import Dict, Any, List, Optional
import numpy as np
from sqlalchemy.orm import Session

from app.models.student import Student
from app.models.attendance import FaceEmbedding
from app.models.audit import AuditLog
from app.engines.recognition.factory import RecognitionEngineFactory
from app.services.face_dataset_service import get_student_dir
from app.services.recognition_index import recognition_index

logger = logging.getLogger("biometrics.migration")


def get_migration_status(db: Session) -> Dict[str, Any]:
    """
    Analyzes the current database and dataset files to report migration status across all students.
    """
    engine = RecognitionEngineFactory.get_engine("scrfd_arcface")
    students = db.query(Student).filter(Student.is_active == True).order_by(Student.roll_number.asc()).all()

    total_students = len(students)
    active_engine_enrolled = []
    legacy_only_students = []
    unenrolled_students = []

    for s in students:
        embs = s.face_embeddings or []
        active_embs = [e for e in embs if e.model_name == engine.model_name and e.dimension == engine.embedding_dimension]
        legacy_embs = [e for e in embs if e.model_name != engine.model_name]

        stu_dir = get_student_dir(s.roll_number, create=False)
        photo_count = len([f for f in os.listdir(stu_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))]) if os.path.exists(stu_dir) else 0

        info = {
            "student_id": s.id,
            "roll_number": s.roll_number,
            "full_name": s.full_name,
            "class_id": s.class_id,
            "active_template_count": len(active_embs),
            "legacy_template_count": len(legacy_embs),
            "stored_photos_count": photo_count,
        }

        if len(active_embs) >= 1:
            active_engine_enrolled.append(info)
        elif len(legacy_embs) >= 1:
            info["can_auto_migrate"] = photo_count > 0
            legacy_only_students.append(info)
        else:
            unenrolled_students.append(info)

    return {
        "active_engine": engine.engine_name,
        "model_name": engine.model_name,
        "dimension": engine.embedding_dimension,
        "total_active_students": total_students,
        "active_enrolled_count": len(active_engine_enrolled),
        "legacy_only_count": len(legacy_only_students),
        "unenrolled_count": len(unenrolled_students),
        "legacy_only_students": legacy_only_students,
        "active_enrolled_students": active_engine_enrolled,
        "unenrolled_students": unenrolled_students,
    }


def migrate_legacy_students_from_photos(
    db: Session,
    user_id: Optional[int] = None,
    dry_run: bool = False
) -> Dict[str, Any]:
    """
    Safely generates 512-d ArcFace embeddings from reference dataset photos for students
    who currently only have legacy embeddings or missing active templates.
    """
    engine = RecognitionEngineFactory.get_engine("scrfd_arcface")
    students = db.query(Student).filter(Student.is_active == True).all()

    migrated_students = []
    skipped_students = []
    failed_students = []
    total_new_embeddings = 0

    for s in students:
        embs = s.face_embeddings or []
        active_embs = [e for e in embs if e.model_name == engine.model_name and e.dimension == engine.embedding_dimension]

        # Only process students who have 0 active ArcFace embeddings
        if len(active_embs) > 0:
            continue

        stu_dir = get_student_dir(s.roll_number, create=False)
        if not os.path.exists(stu_dir):
            skipped_students.append({
                "student_id": s.id,
                "roll_number": s.roll_number,
                "reason": "No dataset directory or photos found on disk."
            })
            continue

        photo_files = [
            f for f in sorted(os.listdir(stu_dir))
            if f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))
        ]
        if not photo_files:
            skipped_students.append({
                "student_id": s.id,
                "roll_number": s.roll_number,
                "reason": "No valid photo files in student dataset folder."
            })
            continue

        valid_templates_for_student = 0
        photo_results = []

        for pf in photo_files:
            fpath = os.path.join(stu_dir, pf)
            try:
                with open(fpath, "rb") as fp:
                    image_bytes = fp.read()

                if len(image_bytes) < 1000:
                    photo_results.append({"file": pf, "status": "REJECTED_CORRUPT", "reason": f"File too small ({len(image_bytes)} bytes)"})
                    continue

                faces = engine.detect_faces_with_landmarks(image_bytes)
                if len(faces) != 1:
                    photo_results.append({
                        "file": pf,
                        "status": "REJECTED_FACE_COUNT",
                        "reason": f"Expected 1 face, found {len(faces)}"
                    })
                    continue

                face_info = faces[0]
                top, right, bottom, left = face_info["bbox"]
                if (right - left) < 20 or (bottom - top) < 20:
                    photo_results.append({"file": pf, "status": "REJECTED_LOW_RES", "reason": "Face too small"})
                    continue

                encodings = engine.generate_embeddings(image_bytes, [face_info["bbox"]])
                if not encodings:
                    photo_results.append({"file": pf, "status": "ERROR", "reason": "Failed to extract ArcFace vector"})
                    continue

                vec = encodings[0].astype(np.float32)
                if not np.all(np.isfinite(vec)):
                    photo_results.append({"file": pf, "status": "ERROR", "reason": "Non-finite vector"})
                    continue

                norm = float(np.linalg.norm(vec))
                if norm < 1e-6:
                    photo_results.append({"file": pf, "status": "ERROR", "reason": "Zero norm vector"})
                    continue

                vec = vec / norm
                rel_path = f"data/student_faces/{s.roll_number}/{pf}"

                if not dry_run:
                    new_emb = FaceEmbedding(
                        student_id=s.id,
                        embedding_json=json.dumps(vec.tolist()),
                        image_path=rel_path,
                        model_name=engine.model_name,
                        model_version=engine.model_version,
                        dimension=engine.embedding_dimension,
                        detector_name=engine.detector_name,
                        distance_metric=engine.distance_metric,
                        quality_score=round(face_info.get("confidence", 1.0), 3)
                    )
                    db.add(new_emb)

                valid_templates_for_student += 1
                photo_results.append({"file": pf, "status": "MIGRATED", "confidence": face_info.get("confidence")})

            except Exception as e:
                photo_results.append({"file": pf, "status": "ERROR", "reason": str(e)})

        if valid_templates_for_student > 0:
            total_new_embeddings += valid_templates_for_student
            migrated_students.append({
                "student_id": s.id,
                "roll_number": s.roll_number,
                "full_name": s.full_name,
                "new_templates_created": valid_templates_for_student,
                "photos_processed": photo_results
            })
            if not dry_run and s.class_id:
                recognition_index.invalidate(s.class_id)
        else:
            failed_students.append({
                "student_id": s.id,
                "roll_number": s.roll_number,
                "full_name": s.full_name,
                "reason": "None of the stored photos passed single-face biometric validation.",
                "details": photo_results
            })

    if not dry_run and total_new_embeddings > 0:
        audit = AuditLog(
            user_id=user_id,
            action="BIOMETRIC_ENGINE_MIGRATION",
            details=(
                f"Migrated {len(migrated_students)} students to ArcFace (w600k_r50, 512-d). "
                f"Created {total_new_embeddings} new templates. "
                f"Failed: {len(failed_students)}, Skipped: {len(skipped_students)}."
            )
        )
        db.add(audit)
        db.commit()

    return {
        "dry_run": dry_run,
        "migrated_students_count": len(migrated_students),
        "total_new_templates_created": total_new_embeddings,
        "failed_students_count": len(failed_students),
        "skipped_students_count": len(skipped_students),
        "migrated_students": migrated_students,
        "failed_students": failed_students,
        "skipped_students": skipped_students,
    }
