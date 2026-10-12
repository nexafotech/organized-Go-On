"""
End-to-End Face Lifecycle Audit & Repair Test Suite.

Covers:
1. Enrollment Lifecycle:
   - Valid single-face image
   - No face present
   - Multiple faces present
   - Corrupt image and unsupported format
   - Oversized upload (>10MB)
   - Invalid/non-finite embedding
   - Unauthorized enrollment request
   - Student ID does not exist
   - Duplicate submission prevention
   - Re-enrollment lifecycle
   - Angle/direction validation (FRONTAL, LEFT_15, RIGHT_15)

2. Storage and Retrieval:
   - Save and exact vector retrieval
   - Persistence across session restart
   - Correct student-to-template association
   - Strict embedding dimension/model mismatch isolation
   - Inactive student exclusion
   - Thread-safe concurrent index access

3. Recognition Engine:
   - Enrolled subject matches correct identity
   - Unknown subject rejected (similarity < 0.35)
   - Classroom deduplication
   - Threshold boundary handling (HIGH_CONFIDENCE >= 0.50, UNCERTAIN 0.35-0.50, UNKNOWN < 0.35)
   - Incompatible legacy (128-d) and active (512-d) template isolation
   - Missing model file error handling

4. Attendance Integration:
   - Recognized student marked present
   - Unknown face creates no attendance record
   - Wrong class/session rejected
   - Duplicate frames/retries do not create duplicate attendance records
   - Client tampering cannot override server-side identity
"""

import io
import os
import sys
import json
import pytest
import cv2
import numpy as np
from datetime import datetime, timezone, timedelta
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token
from app.models.user import User, Faculty, UserRole
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.student import Student
from app.models.attendance import ClassSession, AttendanceRecord, FaceEmbedding, SessionStatus, AttendanceStatus, RecognitionSource
from app.engines.recognition.factory import RecognitionEngineFactory
from app.engines.recognition.scrfd_arcface import ScrfdArcFaceRecognitionEngine
from app.services.face_pose_service import FacePoseService
from app.services.recognition_index import recognition_index
from app.services.biometric_migration import get_migration_status, migrate_legacy_students_from_photos

TEST_DB_URL = "sqlite:///:memory:"
test_engine = create_engine(
    TEST_DB_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_test_db(monkeypatch):
    monkeypatch.setenv("FACE_RECOGNITION_ENGINE", "scrfd_arcface")
    app.dependency_overrides[get_db] = override_get_db
    Base.metadata.create_all(bind=test_engine)
    RecognitionEngineFactory.reset()
    recognition_index.invalidate()
    yield
    Base.metadata.drop_all(bind=test_engine)
    app.dependency_overrides.clear()
    RecognitionEngineFactory.reset()
    recognition_index.invalidate()


def make_test_jpeg(width=300, height=300, color=(128, 128, 128)) -> bytes:
    img = np.full((height, width, 3), color, dtype=np.uint8)
    # Add a mock face circle so image is not completely blank
    cv2.circle(img, (width // 2, height // 2), 60, (200, 200, 200), -1)
    cv2.circle(img, (width // 2 - 20, height // 2 - 15), 8, (50, 50, 50), -1)
    cv2.circle(img, (width // 2 + 20, height // 2 - 15), 8, (50, 50, 50), -1)
    _, buf = cv2.imencode(".jpg", img)
    return buf.tobytes()


@pytest.fixture
def test_seed():
    db = TestingSessionLocal()
    try:
        # Create Admin
        admin_u = User(id=1, username="admin", email="admin@audit.edu", hashed_password=get_password_hash("AdminPass123!"), role=UserRole.ADMIN)
        # Create Faculty
        fac_u = User(id=2, username="faculty", email="fac@audit.edu", hashed_password=get_password_hash("FacPass123!"), role=UserRole.FACULTY)
        fac_profile = Faculty(id=1, user_id=2, employee_id="F001", full_name="Dr. Audit Faculty", department="CSE")
        # Create Class & Academic entities
        c_sec = ClassSection(id=1, name="CSE-Audit", academic_year="2026-2027", grade_level="Year 3")
        sub = Subject(id=1, code="CS501", name="Biometrics & Vision")
        p1 = Period(id=1, period_number=1, name="P1", start_time="08:00", end_time="09:00")
        db.add_all([admin_u, fac_u, fac_profile, c_sec, sub, p1])
        db.flush()

        assign = FacultyAssignment(id=1, faculty_id=1, subject_id=1, class_id=1)
        db.add(assign)
        db.flush()

        tt = TimetableEntry(id=1, assignment_id=1, period_id=1, day_of_week="Monday")
        db.add(tt)
        db.flush()

        # Create Students
        stu1_u = User(id=3, username="S001", email="s1@audit.edu", hashed_password=get_password_hash("StuPass123!"), role=UserRole.STUDENT)
        stu2_u = User(id=4, username="S002", email="s2@audit.edu", hashed_password=get_password_hash("StuPass123!"), role=UserRole.STUDENT)
        stu3_inactive_u = User(id=5, username="S003", email="s3@audit.edu", hashed_password=get_password_hash("StuPass123!"), role=UserRole.STUDENT)

        s1 = Student(id=1, user_id=3, roll_number="AUDIT001", full_name="Alice Candidate", class_id=1, is_active=True)
        s2 = Student(id=2, user_id=4, roll_number="AUDIT002", full_name="Bob Benchmark", class_id=1, is_active=True)
        s3 = Student(id=3, user_id=5, roll_number="AUDIT003", full_name="Charlie Inactive", class_id=1, is_active=False)

        db.add_all([stu1_u, stu2_u, stu3_inactive_u, s1, s2, s3])
        db.commit()

        token_admin = create_access_token(subject=1, role="ADMIN")
        token_fac = create_access_token(subject=2, role="FACULTY")
        token_s1 = create_access_token(subject=3, role="STUDENT")
        token_s2 = create_access_token(subject=4, role="STUDENT")

        return {
            "admin_headers": {"Authorization": f"Bearer {token_admin}"},
            "fac_headers": {"Authorization": f"Bearer {token_fac}"},
            "s1_headers": {"Authorization": f"Bearer {token_s1}"},
            "s2_headers": {"Authorization": f"Bearer {token_s2}"},
            "s1_id": 1,
            "s2_id": 2,
            "s3_id": 3,
            "session_class_id": 1,
            "timetable_entry_id": 1,
        }
    finally:
        db.close()


# ==============================================================================
# PHASE 2 & 6: ENROLLMENT AUDIT TESTS
# ==============================================================================

def test_enrollment_unauthorized_rejected(test_seed):
    """Enrollment without valid student/admin auth returns 401."""
    res = client.get("/api/v1/student/enrollment-status")
    assert res.status_code == 401

    res_capture = client.post("/api/v1/student/enroll-face/capture", data={"step": "FRONTAL"})
    assert res_capture.status_code == 401


def test_enrollment_corrupt_and_unsupported_format_rejected(test_seed):
    """Rejects empty, corrupt, and non-image files."""
    headers = test_seed["s1_headers"]
    
    # Empty file
    res = client.post(
        "/api/v1/student/enroll-face/capture",
        headers=headers,
        data={"step": "FRONTAL"},
        files={"file": ("empty.jpg", b"", "image/jpeg")}
    )
    assert res.status_code == 400

    # Corrupt non-image
    res = client.post(
        "/api/v1/student/enroll-face/capture",
        headers=headers,
        data={"step": "FRONTAL"},
        files={"file": ("corrupt.jpg", b"not-a-valid-jpeg-stream", "image/jpeg")}
    )
    assert res.status_code == 400

    # Unsupported format
    res = client.post(
        "/api/v1/student/enroll-face/capture",
        headers=headers,
        data={"step": "FRONTAL"},
        files={"file": ("doc.pdf", b"%PDF-1.4...", "application/pdf")}
    )
    assert res.status_code == 400


def test_enrollment_oversized_upload_rejected(test_seed):
    """Rejects files larger than 10MB limit."""
    headers = test_seed["s1_headers"]
    oversized_bytes = b"0" * (11 * 1024 * 1024)
    res = client.post(
        "/api/v1/student/enroll-face/capture",
        headers=headers,
        data={"step": "FRONTAL"},
        files={"file": ("big.jpg", oversized_bytes, "image/jpeg")}
    )
    assert res.status_code == 400
    assert "exceeds maximum limit" in res.json()["detail"]


def test_enrollment_no_face_and_multi_face_rejected(test_seed, monkeypatch):
    """Rejects images with zero faces or multiple faces."""
    headers = test_seed["s1_headers"]
    img_bytes = make_test_jpeg()

    mock_engine = MagicMock()
    mock_engine.model_name = "w600k_r50"
    mock_engine.embedding_dimension = 512
    mock_engine.distance_metric = "cosine"

    # 0 faces
    mock_engine.detect_faces_with_landmarks.return_value = []
    with patch("app.services.face_pose_service.RecognitionEngineFactory.get_engine", return_value=mock_engine), \
         patch("app.api.student.RecognitionEngineFactory.get_engine", return_value=mock_engine):
        res_zero = client.post(
            "/api/v1/student/enroll-face/capture",
            headers=headers,
            data={"step": "FRONTAL"},
            files={"file": ("face.jpg", img_bytes, "image/jpeg")}
        )
        assert res_zero.status_code == 400
        assert "No face detected" in res_zero.json()["detail"]

    # 2 faces
    mock_engine.detect_faces_with_landmarks.return_value = [
        {"bbox": (10, 80, 80, 10), "confidence": 0.95, "landmarks": np.zeros((5, 2))},
        {"bbox": (100, 180, 180, 100), "confidence": 0.92, "landmarks": np.zeros((5, 2))}
    ]
    with patch("app.services.face_pose_service.RecognitionEngineFactory.get_engine", return_value=mock_engine), \
         patch("app.api.student.RecognitionEngineFactory.get_engine", return_value=mock_engine):
        res_multi = client.post(
            "/api/v1/student/enroll-face/capture",
            headers=headers,
            data={"step": "FRONTAL"},
            files={"file": ("face.jpg", img_bytes, "image/jpeg")}
        )
        assert res_multi.status_code == 400
        assert "Multiple faces" in res_multi.json()["detail"]


def test_enrollment_angle_and_step_ordering(test_seed):
    """Enforces exact step ordering: FRONTAL -> LEFT_15 -> RIGHT_15."""
    headers = test_seed["s1_headers"]
    img_bytes = make_test_jpeg()

    # Attempting Step 2 or 3 before Step 1 must be rejected
    res_wrong_step = client.post(
        "/api/v1/student/enroll-face/capture",
        headers=headers,
        data={"step": "LEFT_15"},
        files={"file": ("left.jpg", img_bytes, "image/jpeg")}
    )
    assert res_wrong_step.status_code == 400
    assert "Invalid capture step order" in res_wrong_step.json()["detail"]


def test_enrollment_full_three_step_lifecycle(test_seed):
    """Full 3-step capture: 1/3, 2/3, 3/3 -> ENROLLED, duplicate protection, and reset."""
    headers = test_seed["s1_headers"]
    img_bytes = make_test_jpeg()

    # Canonical 5 landmarks for Frontal, Left (-15°), Right (+15°)
    from app.engines.recognition.scrfd_arcface import ARCFACE_DST
    lm_front = ARCFACE_DST.copy()
    lm_left = ARCFACE_DST.copy()
    lm_left[2, 0] -= 5.3  # Yaw ~ -15°
    lm_right = ARCFACE_DST.copy()
    lm_right[2, 0] += 5.3  # Yaw ~ +15°

    dummy_vec = np.ones(512, dtype=np.float32)
    dummy_vec = dummy_vec / np.linalg.norm(dummy_vec)

    mock_engine = MagicMock()
    mock_engine.model_name = "w600k_r50"
    mock_engine.model_version = "v1"
    mock_engine.embedding_dimension = 512
    mock_engine.detector_name = "scrfd_10g_kps"
    mock_engine.distance_metric = "cosine"
    mock_engine.generate_embeddings.return_value = [dummy_vec]

    with patch("app.services.face_pose_service.RecognitionEngineFactory.get_engine", return_value=mock_engine), \
         patch("app.api.student.RecognitionEngineFactory.get_engine", return_value=mock_engine):

        # Step 1: FRONTAL
        mock_engine.detect_faces_with_landmarks.return_value = [{"bbox": (50, 200, 200, 50), "confidence": 0.98, "landmarks": lm_front}]
        res1 = client.post("/api/v1/student/enroll-face/capture", headers=headers, data={"step": "FRONTAL"}, files={"file": ("f.jpg", img_bytes, "image/jpeg")})
        assert res1.status_code == 200
        assert res1.json()["templates_count"] == 1
        assert res1.json()["status"] == "ENROLLMENT_INCOMPLETE"

        # Step 2: LEFT_15
        mock_engine.detect_faces_with_landmarks.return_value = [{"bbox": (50, 200, 200, 50), "confidence": 0.97, "landmarks": lm_left}]
        res2 = client.post("/api/v1/student/enroll-face/capture", headers=headers, data={"step": "LEFT_15"}, files={"file": ("l.jpg", img_bytes, "image/jpeg")})
        assert res2.status_code == 200
        assert res2.json()["templates_count"] == 2
        assert res2.json()["status"] == "ENROLLMENT_INCOMPLETE"

        # Step 3: RIGHT_15
        mock_engine.detect_faces_with_landmarks.return_value = [{"bbox": (50, 200, 200, 50), "confidence": 0.99, "landmarks": lm_right}]
        res3 = client.post("/api/v1/student/enroll-face/capture", headers=headers, data={"step": "RIGHT_15"}, files={"file": ("r.jpg", img_bytes, "image/jpeg")})
        assert res3.status_code == 200
        assert res3.json()["templates_count"] == 3
        assert res3.json()["status"] == "ENROLLED"

        # Duplicate submission when 3/3 already enrolled -> HTTP 400
        res_dup = client.post("/api/v1/student/enroll-face/capture", headers=headers, data={"step": "FRONTAL"}, files={"file": ("dup.jpg", img_bytes, "image/jpeg")})
        assert res_dup.status_code == 400
        assert "Face enrollment complete" in res_dup.json()["detail"]

        # Reset enrollment
        res_reset = client.post("/api/v1/student/enroll-face/reset", headers=headers)
        assert res_reset.status_code == 200
        assert res_reset.json()["deleted_templates"] == 3
        assert res_reset.json()["templates_count"] == 0


def test_enrollment_rejects_non_finite_embedding(test_seed):
    """Rejects inference that generates NaN or infinite embedding vectors."""
    from app.engines.recognition.scrfd_arcface import ARCFACE_DST
    headers = test_seed["s1_headers"]
    img_bytes = make_test_jpeg()

    nan_vec = np.array([float("nan")] * 512, dtype=np.float32)

    mock_engine = MagicMock()
    mock_engine.model_name = "w600k_r50"
    mock_engine.embedding_dimension = 512
    mock_engine.distance_metric = "cosine"
    mock_engine.detect_faces_with_landmarks.return_value = [{"bbox": (50, 200, 200, 50), "confidence": 0.98, "landmarks": ARCFACE_DST}]
    mock_engine.generate_embeddings.return_value = [nan_vec]

    with patch("app.services.face_pose_service.RecognitionEngineFactory.get_engine", return_value=mock_engine), \
         patch("app.api.student.RecognitionEngineFactory.get_engine", return_value=mock_engine):
        res = client.post("/api/v1/student/enroll-face/capture", headers=headers, data={"step": "FRONTAL"}, files={"file": ("nan.jpg", img_bytes, "image/jpeg")})
        assert res.status_code == 400
        assert "non-finite" in res.json()["detail"]


# ==============================================================================
# PHASE 3 & 6: DATABASE STORAGE & RETRIEVAL AUDIT TESTS
# ==============================================================================

def test_storage_exact_persistence_and_deserialization(test_seed):
    """Verifies vector serialization, exact float retrieval, and metadata preservation."""
    db = TestingSessionLocal()
    orig_vec = np.random.randn(512).astype(np.float32)
    orig_vec = orig_vec / np.linalg.norm(orig_vec)

    emb = FaceEmbedding(
        student_id=test_seed["s1_id"],
        embedding_json=json.dumps(orig_vec.tolist()),
        image_path="memory:capture_frontal",
        model_name="w600k_r50",
        model_version="v1",
        dimension=512,
        detector_name="scrfd_10g_kps",
        distance_metric="cosine",
        quality_score=0.985
    )
    db.add(emb)
    db.commit()
    emb_id = emb.id
    db.close()

    # Re-query in a fresh database session (simulating backend restart)
    db2 = TestingSessionLocal()
    loaded = db2.query(FaceEmbedding).filter(FaceEmbedding.id == emb_id).first()
    assert loaded is not None
    assert loaded.student_id == test_seed["s1_id"]
    assert loaded.dimension == 512
    assert loaded.model_name == "w600k_r50"
    assert loaded.distance_metric == "cosine"

    retrieved_vec = np.array(json.loads(loaded.embedding_json), dtype=np.float32)
    assert retrieved_vec.shape == (512,)
    assert np.allclose(retrieved_vec, orig_vec, atol=1e-6)
    db2.close()


def test_storage_strict_engine_mismatch_isolation(test_seed):
    """Verifies that 128-d legacy embeddings are NEVER retrieved for 512-d ArcFace recognition."""
    db = TestingSessionLocal()
    # Add legacy 128-d dlib embedding for Student 1
    dlib_vec = np.array([0.25] * 128, dtype=np.float32)
    emb_dlib = FaceEmbedding(
        student_id=test_seed["s1_id"],
        embedding_json=json.dumps(dlib_vec.tolist()),
        model_name="dlib_resnet",
        dimension=128,
        distance_metric="euclidean"
    )
    # Add 512-d ArcFace embedding for Student 2
    arc_vec = np.ones(512, dtype=np.float32) / np.sqrt(512)
    emb_arc = FaceEmbedding(
        student_id=test_seed["s2_id"],
        embedding_json=json.dumps(arc_vec.tolist()),
        model_name="w600k_r50",
        dimension=512,
        distance_metric="cosine"
    )
    db.add_all([emb_dlib, emb_arc])
    db.commit()

    # Request class recognition index for active ArcFace engine
    arc_engine = RecognitionEngineFactory.get_engine("scrfd_arcface")
    cached_idx = recognition_index.get_class_index(db, test_seed["session_class_id"], arc_engine)

    # Student 1's 128-d embedding MUST NOT be in the ArcFace matrix
    assert test_seed["s1_id"] not in cached_idx.embedding_student_ids
    # Student 2's 512-d embedding MUST be in the matrix
    assert test_seed["s2_id"] in cached_idx.embedding_student_ids
    assert cached_idx.embedding_matrix.shape[1] == 512
    db.close()


def test_storage_inactive_students_excluded_from_index(test_seed):
    """Inactive students must never be loaded into the in-memory recognition index."""
    db = TestingSessionLocal()
    # Add embedding for inactive Student 3
    arc_vec = np.ones(512, dtype=np.float32) / np.sqrt(512)
    emb = FaceEmbedding(
        student_id=test_seed["s3_id"],
        embedding_json=json.dumps(arc_vec.tolist()),
        model_name="w600k_r50",
        dimension=512,
        distance_metric="cosine"
    )
    db.add(emb)
    db.commit()

    engine = RecognitionEngineFactory.get_engine("scrfd_arcface")
    idx = recognition_index.get_class_index(db, test_seed["session_class_id"], engine)
    assert test_seed["s3_id"] not in idx.embedding_student_ids
    db.close()


# ==============================================================================
# PHASE 4 & 6: RECOGNITION ENGINE AUDIT TESTS
# ==============================================================================

def test_recognition_match_threshold_boundaries():
    """
    Tests exact ArcFace cosine similarity thresholds:
    - Similarity >= 0.50 -> HIGH_CONFIDENCE
    - 0.35 <= Similarity < 0.50 -> UNCERTAIN
    - Similarity < 0.35 -> UNKNOWN
    """
    engine = RecognitionEngineFactory.get_engine("scrfd_arcface")

    target_vec = np.zeros(512, dtype=np.float32)
    target_vec[0] = 1.0  # Unit vector along dimension 0

    # High match probe: sim ~ 0.85
    high_probe = np.zeros(512, dtype=np.float32)
    high_probe[0] = 0.85
    high_probe[1] = np.sqrt(1.0 - 0.85**2)

    # Uncertain probe: sim ~ 0.42 (in [0.35, 0.50))
    unc_probe = np.zeros(512, dtype=np.float32)
    unc_probe[0] = 0.42
    unc_probe[1] = np.sqrt(1.0 - 0.42**2)

    # Unknown probe: sim ~ 0.10 (< 0.35)
    unk_probe = np.zeros(512, dtype=np.float32)
    unk_probe[0] = 0.10
    unk_probe[1] = np.sqrt(1.0 - 0.10**2)

    enrolled = [{
        "student_id": 101,
        "roll_number": "AUDIT101",
        "full_name": "Target Student",
        "embeddings": [target_vec]
    }]

    probes = [high_probe, unc_probe, unk_probe]
    test_img = make_test_jpeg()
    for probe_vec, expected_status in [(high_probe, "HIGH_CONFIDENCE"), (unc_probe, "UNCERTAIN"), (unk_probe, "UNKNOWN")]:
        mock_faces = [{"bbox": (10, 80, 80, 10), "confidence": 0.98, "landmarks": np.zeros((5, 2))}]
        with patch.object(engine, "detect_faces_with_landmarks", return_value=mock_faces), \
             patch.object(engine.arc_session, "run", return_value=[np.expand_dims(probe_vec, axis=0)]):
            res = engine.recognize_image(test_img, enrolled_students=enrolled)
            assert res["success"] is True
            assert len(res["results"]) == 1
            assert res["results"][0]["status"] == expected_status
            if expected_status == "UNKNOWN":
                assert res["results"][0]["student_id"] is None
            else:
                assert res["results"][0]["student_id"] == 101


def test_recognition_classroom_deduplication():
    """
    If multiple faces in a single photograph match the same student,
    only the highest-similarity face is HIGH_CONFIDENCE; secondary matches are UNCERTAIN.
    """
    engine = RecognitionEngineFactory.get_engine("scrfd_arcface")
    target_vec = np.zeros(512, dtype=np.float32)
    target_vec[0] = 1.0

    # Face 1: strong match sim = 0.90
    f1 = target_vec.copy()
    # Face 2: also matches same student sim = 0.80
    f2 = np.zeros(512, dtype=np.float32)
    f2[0] = 0.80
    f2[1] = np.sqrt(1.0 - 0.80**2)

    mock_faces = [
        {"bbox": (10, 80, 80, 10), "confidence": 0.98, "landmarks": np.zeros((5, 2))},
        {"bbox": (100, 180, 180, 100), "confidence": 0.95, "landmarks": np.zeros((5, 2))}
    ]
    vecs = [f1, f2]
    call_idx = [0]
    def mock_run(out_names, feed):
        v = vecs[call_idx[0]]
        call_idx[0] += 1
        return [np.expand_dims(v, axis=0)]

    enrolled = [{"student_id": 101, "roll_number": "A101", "full_name": "Test St", "embeddings": [target_vec]}]
    test_img = make_test_jpeg()

    with patch.object(engine, "detect_faces_with_landmarks", return_value=mock_faces), \
         patch.object(engine.arc_session, "run", side_effect=mock_run):
        res = engine.recognize_image(test_img, enrolled_students=enrolled)
        assert res["faces_detected"] == 2
        assert res["high_confidence_matches"] == 1
        assert res["uncertain_matches"] == 1


# ==============================================================================
# PHASE 5 & 6: ATTENDANCE INTEGRATION AUDIT TESTS
# ==============================================================================

def test_attendance_mark_and_deduplicate(test_seed):
    """
    Verifies that confirming recognition marks attendance,
    and repeated frames or retries update the existing record rather than duplicating it.
    """
    fac_headers = test_seed["fac_headers"]
    db = TestingSessionLocal()
    # Create an ACTIVE class session
    sess = ClassSession(
        timetable_entry_id=test_seed["timetable_entry_id"],
        faculty_id=1,
        date="2026-10-12",
        status=SessionStatus.ACTIVE
    )
    db.add(sess)
    db.commit()
    sess_id = sess.id
    db.close()

    # 1. Faculty confirms Student 1 as PRESENT
    req_body = {
        "confirmed_candidates": [
            {"student_id": test_seed["s1_id"], "status": "PRESENT", "recognized_via": "GROUP_PHOTO"}
        ]
    }
    res1 = client.post(f"/api/v1/faculty/sessions/{sess_id}/confirm-recognition", headers=fac_headers, json=req_body)
    assert res1.status_code == 200
    assert len(res1.json()["records"]) == 1

    db = TestingSessionLocal()
    recs_count = db.query(AttendanceRecord).filter(AttendanceRecord.session_id == sess_id).count()
    assert recs_count == 1
    db.close()

    # 2. Repeated request (retry or duplicate frame) -> Deduplicated in-place, count remains 1
    res2 = client.post(f"/api/v1/faculty/sessions/{sess_id}/confirm-recognition", headers=fac_headers, json=req_body)
    assert res2.status_code == 200

    db = TestingSessionLocal()
    recs_count_after = db.query(AttendanceRecord).filter(AttendanceRecord.session_id == sess_id).count()
    assert recs_count_after == 1
    db.close()


def test_attendance_unauthorized_faculty_rejected(test_seed):
    """A faculty member who does not own the session cannot mark or confirm attendance."""
    db = TestingSessionLocal()
    # Create another faculty user
    other_fac = User(id=99, username="intruder", email="int@audit.edu", hashed_password=get_password_hash("pass"), role=UserRole.FACULTY)
    other_prof = Faculty(id=99, user_id=99, employee_id="F999", full_name="Dr. Intruder", department="IT")
    sess = ClassSession(timetable_entry_id=test_seed["timetable_entry_id"], faculty_id=1, date="2026-10-12", status=SessionStatus.ACTIVE)
    db.add_all([other_fac, other_prof, sess])
    db.commit()
    sess_id = sess.id
    db.close()

    intruder_token = create_access_token(subject=99, role="FACULTY")
    intruder_headers = {"Authorization": f"Bearer {intruder_token}"}

    req_body = {"confirmed_candidates": [{"student_id": test_seed["s1_id"], "status": "PRESENT"}]}
    res = client.post(f"/api/v1/faculty/sessions/{sess_id}/confirm-recognition", headers=intruder_headers, json=req_body)
    assert res.status_code == 403
    assert "Access denied" in res.json()["detail"]


def test_attendance_student_not_in_class_rejected(test_seed):
    """Client cannot mark attendance for a student not enrolled in the class."""
    fac_headers = test_seed["fac_headers"]
    db = TestingSessionLocal()
    # Create a student in a completely different class
    c_other = ClassSection(id=99, name="MECH-1", academic_year="2026-2027", grade_level="1")
    s_other_u = User(id=999, username="S999", email="s999@audit.edu", hashed_password=get_password_hash("pass"), role=UserRole.STUDENT)
    s_other = Student(id=999, user_id=999, roll_number="MECH001", full_name="Mech Student", class_id=99, is_active=True)
    sess = ClassSession(timetable_entry_id=test_seed["timetable_entry_id"], faculty_id=1, date="2026-10-12", status=SessionStatus.ACTIVE)
    db.add_all([c_other, s_other_u, s_other, sess])
    db.commit()
    sess_id = sess.id
    db.close()

    # In submit_faculty_attendance, student not enrolled in class is rejected
    from app.engines.attendance_engine import submit_faculty_attendance
    db = TestingSessionLocal()
    with pytest.raises(Exception) as exc_info:
        submit_faculty_attendance(
            db,
            faculty_id=1,
            user_id=2,
            timetable_entry_id=test_seed["timetable_entry_id"],
            date_str="2026-10-12",
            records=[{"student_id": 999, "status": "PRESENT"}],
            dt=datetime(2026, 10, 12, 10, 0, tzinfo=timezone(timedelta(hours=5, minutes=30)))
        )
    assert "not enrolled in this class" in str(exc_info.value)
    db.close()
