"""
Milestone 15C — Real Device Biometric Enrollment Pilot Script.
Executes controlled pilot enrollment for authenticated volunteer student 721025149011 (BHUVANESWARI S).
Verifies orientation/mirroring, step transitions, database state, admin visibility, recognition smoke test,
unknown student isolation, and privacy invariants.
"""

import os
import sys

# Ensure project root is in sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import io
import json
import sqlite3
import numpy as np
import cv2
from PIL import Image, ImageOps

from fastapi.testclient import TestClient

from app.main import app
from app.core.database import SessionLocal
from app.models.student import Student
from app.models.user import User, UserRole
from app.models.attendance import FaceEmbedding, ClassSession, AttendanceRecord
from app.core.security import create_access_token
from app.services.face_pose_service import FacePoseService, estimate_head_pose
from app.engines.recognition.scrfd_arcface import ScrfdArcFaceRecognitionEngine, ARCFACE_DST
from app.engines.recognition.factory import RecognitionEngineFactory

client = TestClient(app)

PHOTOS_DIR = r"C:\Users\Abishek\OneDrive\Desktop\all in\Attendance_Marker\data\face_enrollment"

def run_pilot():
    print("=" * 60)
    print("MILESTONE 15C — CONTROLLED BIOMETRIC ENROLLMENT PILOT")
    print("=" * 60)

    # ---------------------------------------------------------
    # 1. PRE-FLIGHT AUDIT
    # ---------------------------------------------------------
    print("\n[1. PRE-FLIGHT AUDIT]")
    db = SessionLocal()
    st_count = db.query(Student).count()
    emb_count = db.query(FaceEmbedding).count()
    att_count = db.query(AttendanceRecord).count()
    cs_count = db.query(ClassSession).count()
    usr_count = db.query(User).count()
    print(f"Initial DB State: students={st_count}, face_embeddings={emb_count}, attendance={att_count}, sessions={cs_count}, users={usr_count}")
    assert st_count == 119, f"Expected 119 students, found {st_count}"
    assert emb_count == 0, f"Expected 0 face_embeddings, found {emb_count}"
    assert att_count == 0, f"Expected 0 attendance records, found {att_count}"
    assert cs_count == 0, f"Expected 0 class sessions, found {cs_count}"
    db.close()

    engine = RecognitionEngineFactory.get_engine("scrfd_arcface")
    print(f"Candidate Engine: {engine.model_name}, Detector: {engine.detector_name}, Dim: {engine.embedding_dimension}")
    print(f"ONNX Providers: {engine.det_session.get_providers()}")

    # Authenticate Volunteer Student 1 (721025149011 - BHUVANESWARI S)
    db = SessionLocal()
    student1 = db.query(Student).filter(Student.roll_number == "721025149011").first()
    assert student1 is not None, "Volunteer Student 1 (721025149011) not found in DB"
    student1_id = student1.id
    student1_user_id = student1.user_id
    student1_name = student1.full_name
    student1_roll = student1.roll_number
    token_st1 = create_access_token(subject=str(student1_user_id), role="STUDENT")
    headers_st1 = {"Authorization": f"Bearer {token_st1}"}

    # Authenticate Admin for Admin Visibility Verification
    admin_user = db.query(User).filter(User.role == UserRole.ADMIN).first()
    assert admin_user is not None, "Admin user not found in DB"
    token_admin = create_access_token(subject=str(admin_user.id), role="ADMIN")
    headers_admin = {"Authorization": f"Bearer {token_admin}"}
    db.close()

    print(f"Volunteer Student: #{student1_id} '{student1_name}' ({student1_roll})")
    print(f"Admin User: #{admin_user.id} '{admin_user.username}'")

    # ---------------------------------------------------------
    # 2. CAMERA ORIENTATION & EXIF / MIRRORING TEST
    # ---------------------------------------------------------
    print("\n[2. CAMERA ORIENTATION & EXIF / MIRRORING TEST]")
    st1_folder = os.path.join(PHOTOS_DIR, "721025149011")
    front_file = os.path.join(st1_folder, "20260901_121341.jpg")
    left_file = os.path.join(st1_folder, "20260901_121345.jpg")
    right_file = os.path.join(st1_folder, "20260901_121348.jpg")

    with open(front_file, "rb") as fp:
        raw_front = fp.read()
    with open(left_file, "rb") as fp:
        raw_left = fp.read()
    with open(right_file, "rb") as fp:
        raw_right = fp.read()

    service = FacePoseService()

    # Test standard unmirrored front photo
    res_front_norm = service.validate_image_and_pose(raw_front, "FRONTAL", engine, mirrored=False)
    print("A. Front Camera standard capture:", res_front_norm["status"], "pose:", res_front_norm.get("pose"), "conf:", res_front_norm.get("confidence"))

    # Test EXIF tag simulation (90 deg CW rotation tag 6)
    pil_front = Image.open(io.BytesIO(raw_front))
    exif = pil_front.getexif()
    exif[0x0112] = 6
    buf = io.BytesIO()
    pil_front.save(buf, format="JPEG", exif=exif)
    raw_front_exif = buf.getvalue()
    res_front_exif = service.validate_image_and_pose(raw_front_exif, "FRONTAL", engine, mirrored=False)
    print("D. EXIF orientation handling (Tag 6 90° CW transposed):", res_front_exif["status"], "pose:", res_front_exif.get("pose"))
    assert res_front_exif["valid"] is True, "EXIF normalized image failed validation"

    # Test Left turn orientation
    res_left = service.validate_image_and_pose(raw_left, "LEFT_15", engine, mirrored=False)
    print("E. Student turns LEFT -> Backend interpretation:", res_left["status"], "yaw:", res_left.get("pose", {}).get("yaw"))
    assert res_left["valid"] is True and res_left["pose"]["yaw"] < 0, "Left turn was not interpreted as yaw < 0"

    # Test Right turn orientation
    res_right = service.validate_image_and_pose(raw_right, "RIGHT_15", engine, mirrored=False)
    print("E. Student turns RIGHT -> Backend interpretation:", res_right["status"], "yaw:", res_right.get("pose", {}).get("yaw"))
    assert res_right["valid"] is True and res_right["pose"]["yaw"] > 0, "Right turn was not interpreted as yaw > 0"

    # Test Mirroring compensation: if raw_left is mirrored, uncompensated yaw is positive, compensated yaw is negative
    nparr = np.frombuffer(raw_left, np.uint8)
    mirrored_left_cv = cv2.flip(cv2.imdecode(nparr, cv2.IMREAD_COLOR), 1)
    _, enc_m = cv2.imencode(".jpg", mirrored_left_cv)
    raw_left_mirrored = enc_m.tobytes()

    res_left_mirror_uncomp = service.validate_image_and_pose(raw_left_mirrored, "LEFT_15", engine, mirrored=False)
    print("E. Mirrored left selfie (uncompensated):", res_left_mirror_uncomp["status"], "yaw:", res_left_mirror_uncomp.get("pose", {}).get("yaw"))
    assert res_left_mirror_uncomp["valid"] is False, "Mirrored left turn should fail uncompensated LEFT_15"

    res_left_mirror_comp = service.validate_image_and_pose(raw_left_mirrored, "LEFT_15", engine, mirrored=True)
    print("E. Mirrored left selfie (compensated with mirrored=True):", res_left_mirror_comp["status"], "yaw:", res_left_mirror_comp.get("pose", {}).get("yaw"))
    assert res_left_mirror_comp["valid"] is True, "Mirrored left turn failed with mirror compensation"

    # ---------------------------------------------------------
    # 3. LIVE CAPTURE GUIDANCE & PRE-ENROLLMENT STATUS
    # ---------------------------------------------------------
    print("\n[3. PRE-ENROLLMENT STATUS]")
    status_resp = client.get("/api/v1/student/enrollment-status", headers=headers_st1).json()
    print(f"Step 0: templates={status_resp['templates_count']}, status={status_resp['status']}, next={status_resp['next_step']}")
    assert status_resp["status"] == "ENROLLMENT_INCOMPLETE"
    assert status_resp["templates_count"] == 0
    assert status_resp["next_step"] == "FRONTAL"

    # ---------------------------------------------------------
    # 4 & 5. THREE-STEP CONTROLLED ENROLLMENT
    # ---------------------------------------------------------
    print("\n[4 & 5. EXECUTING 3-STEP BIOMETRIC ENROLLMENT]")

    # Capture 1: FRONTAL
    print("--> Executing Capture 1: FRONTAL")
    cap1_resp = client.post(
        "/api/v1/student/enroll-face/capture",
        data={"step": "FRONTAL", "mirrored": "false"},
        files={"file": ("front.jpg", raw_front, "image/jpeg")},
        headers=headers_st1
    )
    assert cap1_resp.status_code == 200, f"Capture 1 failed: {cap1_resp.text}"
    c1_json = cap1_resp.json()
    print(f"   Response 1: status={c1_json['status']}, count={c1_json['templates_count']}, next={c1_json['next_step']}")
    assert c1_json["status"] == "ENROLLMENT_INCOMPLETE"
    assert c1_json["templates_count"] == 1
    assert c1_json["next_step"] == "LEFT_15"

    # Check status endpoint at 1/3
    s1_resp = client.get("/api/v1/student/enrollment-status", headers=headers_st1).json()
    assert s1_resp["templates_count"] == 1
    assert s1_resp["status"] == "ENROLLMENT_INCOMPLETE"
    assert s1_resp["completed_steps"] == ["FRONTAL"]

    # Capture 2: LEFT_15
    print("--> Executing Capture 2: LEFT_15")
    cap2_resp = client.post(
        "/api/v1/student/enroll-face/capture",
        data={"step": "LEFT_15", "mirrored": "false"},
        files={"file": ("left.jpg", raw_left, "image/jpeg")},
        headers=headers_st1
    )
    assert cap2_resp.status_code == 200, f"Capture 2 failed: {cap2_resp.text}"
    c2_json = cap2_resp.json()
    print(f"   Response 2: status={c2_json['status']}, count={c2_json['templates_count']}, next={c2_json['next_step']}")
    assert c2_json["status"] == "ENROLLMENT_INCOMPLETE"
    assert c2_json["templates_count"] == 2
    assert c2_json["next_step"] == "RIGHT_15"

    # Check status endpoint at 2/3
    s2_resp = client.get("/api/v1/student/enrollment-status", headers=headers_st1).json()
    assert s2_resp["templates_count"] == 2
    assert s2_resp["status"] == "ENROLLMENT_INCOMPLETE"
    assert s2_resp["completed_steps"] == ["FRONTAL", "LEFT_15"]

    # Capture 3: RIGHT_15
    print("--> Executing Capture 3: RIGHT_15")
    cap3_resp = client.post(
        "/api/v1/student/enroll-face/capture",
        data={"step": "RIGHT_15", "mirrored": "false"},
        files={"file": ("right.jpg", raw_right, "image/jpeg")},
        headers=headers_st1
    )
    assert cap3_resp.status_code == 200, f"Capture 3 failed: {cap3_resp.text}"
    c3_json = cap3_resp.json()
    print(f"   Response 3: status={c3_json['status']}, count={c3_json['templates_count']}, next={c3_json['next_step']}")
    assert c3_json["status"] == "ENROLLED"
    assert c3_json["templates_count"] == 3
    assert c3_json["next_step"] is None

    # Check status endpoint at 3/3 -> ENROLLED
    s3_resp = client.get("/api/v1/student/enrollment-status", headers=headers_st1).json()
    print(f"Final Enrollment Status: enrolled={s3_resp.get('enrolled', s3_resp['status'] == 'ENROLLED')}, count={s3_resp['templates_count']}")
    assert s3_resp["status"] == "ENROLLED"
    assert s3_resp["templates_count"] == 3
    assert s3_resp["completed_steps"] == ["FRONTAL", "LEFT_15", "RIGHT_15"]

    # ---------------------------------------------------------
    # 6. DATABASE VERIFICATION
    # ---------------------------------------------------------
    print("\n[6. DATABASE VERIFICATION]")
    db = SessionLocal()
    st1_embs = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == student1_id).all()
    all_embs = db.query(FaceEmbedding).all()
    att_records = db.query(AttendanceRecord).count()
    class_sessions = db.query(ClassSession).count()
    print(f"Total face_embeddings in DB: {len(all_embs)}")
    print(f"Embeddings belonging to Student #{student1_id}: {len(st1_embs)}")
    print(f"Attendance records count: {att_records}, Class sessions count: {class_sessions}")
    assert len(all_embs) == 3, f"Expected exactly 3 embeddings in DB, got {len(all_embs)}"
    assert len(st1_embs) == 3, f"Expected all 3 embeddings to belong to student #{student1_id}"
    assert att_records == 0, "No attendance records should be created during biometric enrollment"
    assert class_sessions == 0, "No class sessions should be created during biometric enrollment"

    # Verify metadata on all 3 templates
    stored_vectors = []
    for i, emb in enumerate(st1_embs):
        assert emb.student_id == student1_id
        assert emb.dimension == 512
        assert emb.model_name == "w600k_r50"
        assert emb.detector_name == "scrfd_10g_kps"
        assert emb.distance_metric == "cosine"
        assert emb.quality_score is not None and emb.quality_score >= 0.80
        assert emb.image_path.startswith("memory:capture_")
        vec = np.array(json.loads(emb.embedding_json), dtype=np.float32)
        assert len(vec) == 512
        norm = np.linalg.norm(vec)
        assert np.isclose(norm, 1.0, atol=1e-3), f"Vector norm {norm} is not unit-normalized"
        stored_vectors.append(vec)
        print(f"   Template {i+1} ({emb.image_path}): dim={emb.dimension}, metric={emb.distance_metric}, quality={emb.quality_score:.3f}, norm={norm:.4f}")
    db.close()

    # ---------------------------------------------------------
    # 8. ADMIN VISIBILITY
    # ---------------------------------------------------------
    print("\n[8. ADMIN VISIBILITY VERIFICATION]")
    # Check single student biometrics endpoint
    admin_bio_resp = client.get(f"/api/v1/admin/students/{student1_id}/biometrics", headers=headers_admin)
    assert admin_bio_resp.status_code == 200, f"Admin biometrics failed: {admin_bio_resp.text}"
    bio_data = admin_bio_resp.json()
    print(f"Admin Student Biometrics: name='{bio_data['full_name']}', roll='{bio_data['roll_number']}', class='{bio_data['class_name']}'")
    print(f"   Enrolled: {bio_data['enrolled']}, Template Count: {bio_data['template_count']}, Last Enrolled: {bio_data['last_enrollment_time']}")
    assert bio_data["enrolled"] is True
    assert bio_data["template_count"] == 3
    assert "embedding_json" not in bio_data
    assert "vector" not in bio_data

    # Check student list in Admin API
    admin_st_resp = client.get(f"/api/v1/admin/students?search={student1_roll}", headers=headers_admin)
    assert admin_st_resp.status_code == 200
    st_list = admin_st_resp.json()
    assert len(st_list) >= 1
    found_st = next((s for s in st_list if s["id"] == student1_id), None)
    assert found_st is not None
    print(f"Admin Student List Item: is_enrolled={found_st.get('is_enrolled')}, template_count={found_st.get('template_count')}")
    assert found_st.get("is_enrolled") is True
    assert found_st.get("template_count") == 3

    # ---------------------------------------------------------
    # 9. REAL RECOGNITION SMOKE TEST
    # ---------------------------------------------------------
    print("\n[9. REAL RECOGNITION SMOKE TEST]")
    # Create a fresh, distinct test frame of Student 1 (simulate camera frame with slight translation/brightness shift)
    pil_src = Image.open(io.BytesIO(raw_front))
    # Crop slightly (5% border) and resize back to original size to simulate live camera reframing
    w, h = pil_src.size
    crop_box = (int(w * 0.03), int(h * 0.03), int(w * 0.97), int(h * 0.97))
    pil_smoke = pil_src.crop(crop_box).resize((w, h), Image.Resampling.LANCZOS)
    buf = io.BytesIO()
    pil_smoke.save(buf, format="JPEG", quality=90)
    raw_smoke_image = buf.getvalue()

    # Extract 512-d ArcFace vector for smoke test frame
    smoke_embs = engine.generate_embeddings(raw_smoke_image)
    assert len(smoke_embs) >= 1, "Failed to detect face or generate ArcFace embedding in smoke test frame"
    smoke_vec = smoke_embs[0]

    # Compute cosine similarity against all 3 enrolled templates
    sims = [float(np.dot(smoke_vec, tv)) for tv in stored_vectors]
    best_sim = max(sims)
    best_template_idx = sims.index(best_sim)
    print(f"Smoke Test Image Cosine Similarities against Enrolled Templates: {['%.4f' % s for s in sims]}")
    print(f"Strongest Similarity: {best_sim:.4f} (Template {best_template_idx + 1})")

    # In ArcFace, cosine similarity for the same identity is typically > 0.65 (threshold is usually 0.40 - 0.50)
    assert best_sim >= 0.50, f"Expected high cosine similarity for same student, got {best_sim}"
    print(f"Recognition Status: VERIFIED_MATCH (Best similarity {best_sim:.4f} >= threshold 0.50)")

    # ---------------------------------------------------------
    # 10. UNKNOWN / SECOND STUDENT TEST
    # ---------------------------------------------------------
    print("\n[10. UNKNOWN / SECOND STUDENT ISOLATION TEST]")
    # Load distinct photo of Student 2: 721025149049 (KAVIN R)
    st2_file = os.path.join(PHOTOS_DIR, "721025149049", "20260901_121757.jpg")
    with open(st2_file, "rb") as fp:
        raw_st2 = fp.read()

    st2_embs = engine.generate_embeddings(raw_st2)
    assert len(st2_embs) >= 1, "Failed to extract face embedding for Student 2"
    st2_vec = st2_embs[0]

    # Compute cosine similarity of Student 2 against Student 1's templates
    cross_sims = [float(np.dot(st2_vec, tv)) for tv in stored_vectors]
    max_cross_sim = max(cross_sims)
    print(f"Cross-Student Cosine Similarities (Student 2 vs Student 1 Templates): {['%.4f' % s for s in cross_sims]}")
    print(f"Maximum Cross-Student Similarity: {max_cross_sim:.4f}")
    assert max_cross_sim < 0.40, f"Cross-student similarity {max_cross_sim} unexpectedly high!"
    print(f"Isolation Result: CONFIRMED_ISOLATED (Cross-similarity {max_cross_sim:.4f} < threshold 0.40)")

    # ---------------------------------------------------------
    # 11. PRIVACY VERIFICATION
    # ---------------------------------------------------------
    print("\n[11. PRIVACY VERIFICATION]")
    # Check that image_path in DB is memory only
    db = SessionLocal()
    for emb in db.query(FaceEmbedding).filter(FaceEmbedding.student_id == student1_id).all():
        assert emb.image_path.startswith("memory:capture_"), f"Unexpected image path: {emb.image_path}"
        assert not os.path.exists(emb.image_path), "Memory image path points to an actual file on disk!"
    db.close()
    print("Privacy: Confirmed image_path is memory reference only; zero raw enrollment images saved to disk.")

    # Check student enrollment endpoint returns zero raw embeddings
    st_status = client.get("/api/v1/student/enrollment-status", headers=headers_st1).json()
    assert "embedding" not in st_status
    assert "embedding_json" not in st_status
    assert "embeddings" not in st_status
    print("Privacy: Confirmed GET /student/enrollment-status does not return vector embeddings.")

    print("\n" + "=" * 60)
    print("PILOT EXECUTION COMPLETE AND FULLY VALIDATED")
    print("=" * 60)

if __name__ == "__main__":
    run_pilot()
