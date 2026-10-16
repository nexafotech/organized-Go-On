import io
import json
import pytest
import cv2
import numpy as np
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import SessionLocal
from app.models.user import User, UserRole
from app.models.student import Student
from app.models.academic import ClassSection
from app.models.attendance import FaceEmbedding
from app.core.security import get_password_hash, create_access_token
from app.services.face_pose_service import FacePoseService, estimate_head_pose, PoseThresholds

client = TestClient(app)

# Canonical 5-point landmark template (from ARCFACE_DST)
# [left_eye, right_eye, nose_tip, left_mouth, right_mouth]
CANONICAL_FRONTAL = np.array([
    [38.2946, 51.6963],
    [73.5318, 51.5014],
    [56.0252, 71.7366],
    [41.5493, 92.3655],
    [70.7299, 92.2041]
], dtype=np.float32)


def make_test_image(width=400, height=400, brightness=128):
    """Generates an in-memory JPEG test image with specified dimensions and brightness."""
    img = np.full((height, width, 3), brightness, dtype=np.uint8)
    # Draw simple facial feature placeholders to give non-zero laplacian variance
    cv2.circle(img, (width // 2, height // 2), 60, (200, 200, 200), -1)
    cv2.circle(img, (width // 2 - 30, height // 2 - 20), 10, (50, 50, 50), -1)
    cv2.circle(img, (width // 2 + 30, height // 2 - 20), 10, (50, 50, 50), -1)
    cv2.circle(img, (width // 2, height // 2 + 10), 8, (80, 80, 80), -1)
    cv2.line(img, (width // 2 - 25, height // 2 + 40), (width // 2 + 25, height // 2 + 40), (40, 40, 40), 4)

    _, encoded = cv2.imencode(".jpg", img)
    return encoded.tobytes()


# ==============================================================================
# 1. UNIT TESTS: POSE ESTIMATION & ANGLE THRESHOLD CHECKS
# ==============================================================================

def test_1_frontal_pose_inside_range_accepted():
    """Frontal pose within yaw [-5, 5], pitch [-5, 5], roll [-5, 5] is accepted as READY."""
    service = FacePoseService()
    img_bytes = make_test_image()

    mock_engine = MagicMock()
    mock_engine.detect_faces_with_landmarks.return_value = [{
        "bbox": (100, 300, 300, 100),
        "confidence": 0.98,
        "landmarks": CANONICAL_FRONTAL.copy()
    }]

    res = service.validate_image_and_pose(img_bytes, "FRONTAL", engine=mock_engine)
    assert res["valid"] is True
    assert res["status"] == "READY"
    assert -5.0 <= res["pose"]["yaw"] <= 5.0
    assert -5.0 <= res["pose"]["pitch"] <= 5.0
    assert -5.0 <= res["pose"]["roll"] <= 5.0


def test_2_frontal_pose_outside_yaw_range_rejected():
    """Frontal pose with yaw outside [-5, 5] (e.g. turned right yaw=+10°) is rejected."""
    service = FacePoseService()
    img_bytes = make_test_image()

    # Shift nose right to create yaw = +10°
    lm = CANONICAL_FRONTAL.copy()
    lm[2, 0] += 3.5  # shift nose towards right eye

    mock_engine = MagicMock()
    mock_engine.detect_faces_with_landmarks.return_value = [{
        "bbox": (100, 300, 300, 100),
        "confidence": 0.98,
        "landmarks": lm
    }]

    res = service.validate_image_and_pose(img_bytes, "FRONTAL", engine=mock_engine)
    assert res["valid"] is False
    assert res["status"] == "POSE_TOO_RIGHT"
    assert "LEFT" in res["message"]


def test_3_left_15_pose_inside_range_accepted():
    """Left turn pose within yaw [-20, -10], pitch [-7, 7], roll [-5, 5] is accepted as READY."""
    service = FacePoseService()
    img_bytes = make_test_image()

    # Shift nose left by ~5.3 px to produce yaw ~ -15°
    lm = CANONICAL_FRONTAL.copy()
    lm[2, 0] -= 5.3

    mock_engine = MagicMock()
    mock_engine.detect_faces_with_landmarks.return_value = [{
        "bbox": (100, 300, 300, 100),
        "confidence": 0.97,
        "landmarks": lm
    }]

    res = service.validate_image_and_pose(img_bytes, "LEFT_15", engine=mock_engine)
    assert res["valid"] is True
    assert res["status"] == "READY"
    assert -20.0 <= res["pose"]["yaw"] <= -10.0


def test_4_left_pose_in_wrong_direction_rejected():
    """When step requires LEFT_15 but head is turned to the RIGHT (yaw > 0), reject with POSE_WRONG_DIRECTION."""
    service = FacePoseService()
    img_bytes = make_test_image()

    # Shift nose right (yaw ~ +15°)
    lm = CANONICAL_FRONTAL.copy()
    lm[2, 0] += 5.3

    mock_engine = MagicMock()
    mock_engine.detect_faces_with_landmarks.return_value = [{
        "bbox": (100, 300, 300, 100),
        "confidence": 0.98,
        "landmarks": lm
    }]

    res = service.validate_image_and_pose(img_bytes, "LEFT_15", engine=mock_engine)
    assert res["valid"] is False
    assert res["status"] == "POSE_WRONG_DIRECTION"
    assert "Turn your head to the LEFT" in res["message"]


def test_5_right_15_pose_inside_range_accepted():
    """Right turn pose within yaw [+10, +20], pitch [-7, 7], roll [-5, 5] is accepted as READY."""
    service = FacePoseService()
    img_bytes = make_test_image()

    # Shift nose right by ~5.3 px to produce yaw ~ +15°
    lm = CANONICAL_FRONTAL.copy()
    lm[2, 0] += 5.3

    mock_engine = MagicMock()
    mock_engine.detect_faces_with_landmarks.return_value = [{
        "bbox": (100, 300, 300, 100),
        "confidence": 0.98,
        "landmarks": lm
    }]

    res = service.validate_image_and_pose(img_bytes, "RIGHT_15", engine=mock_engine)
    assert res["valid"] is True
    assert res["status"] == "READY"
    assert 10.0 <= res["pose"]["yaw"] <= 20.0


def test_6_right_pose_in_wrong_direction_rejected():
    """When step requires RIGHT_15 but head is turned to the LEFT (yaw < 0), reject with POSE_WRONG_DIRECTION."""
    service = FacePoseService()
    img_bytes = make_test_image()

    # Shift nose left (yaw ~ -15°)
    lm = CANONICAL_FRONTAL.copy()
    lm[2, 0] -= 5.3

    mock_engine = MagicMock()
    mock_engine.detect_faces_with_landmarks.return_value = [{
        "bbox": (100, 300, 300, 100),
        "confidence": 0.97,
        "landmarks": lm
    }]

    res = service.validate_image_and_pose(img_bytes, "RIGHT_15", engine=mock_engine)
    assert res["valid"] is False
    assert res["status"] == "POSE_WRONG_DIRECTION"
    assert "Turn your head to the RIGHT" in res["message"]


def test_7_excessive_pitch_rejected():
    """Head tilted up or down beyond pitch limits is rejected."""
    service = FacePoseService()
    img_bytes = make_test_image()

    # Shift nose upward relative to mouth to produce excessive positive pitch
    lm = CANONICAL_FRONTAL.copy()
    lm[2, 1] -= 8.0  # nose up

    mock_engine = MagicMock()
    mock_engine.detect_faces_with_landmarks.return_value = [{
        "bbox": (100, 300, 300, 100),
        "confidence": 0.98,
        "landmarks": lm
    }]

    res = service.validate_image_and_pose(img_bytes, "FRONTAL", engine=mock_engine)
    assert res["valid"] is False
    assert res["status"] in ["HEAD_TOO_HIGH", "HEAD_TOO_LOW"]


def test_8_excessive_roll_rejected():
    """Head tilted sideways beyond roll limits (±5°) is rejected with HEAD_TILTED."""
    service = FacePoseService()
    img_bytes = make_test_image()

    # Rotate landmarks by 10 degrees to simulate roll
    theta = np.radians(10.0)
    rot = np.array([[np.cos(theta), -np.sin(theta)], [np.sin(theta), np.cos(theta)]])
    center = np.mean(CANONICAL_FRONTAL, axis=0)
    lm = np.dot(CANONICAL_FRONTAL - center, rot.T) + center

    mock_engine = MagicMock()
    mock_engine.detect_faces_with_landmarks.return_value = [{
        "bbox": (100, 300, 300, 100),
        "confidence": 0.98,
        "landmarks": lm
    }]

    res = service.validate_image_and_pose(img_bytes, "FRONTAL", engine=mock_engine)
    assert res["valid"] is False
    assert res["status"] == "HEAD_TILTED"
    assert "level" in res["message"]


def test_9_face_not_centered_rejected():
    """Face located far off-center in the camera frame is rejected with FACE_NOT_CENTERED."""
    service = FacePoseService()
    img_bytes = make_test_image(width=640, height=480)

    # Place bbox at extreme top-left corner
    mock_engine = MagicMock()
    mock_engine.detect_faces_with_landmarks.return_value = [{
        "bbox": (10, 120, 130, 10),  # top, right, bottom, left
        "confidence": 0.98,
        "landmarks": CANONICAL_FRONTAL.copy()
    }]

    res = service.validate_image_and_pose(img_bytes, "FRONTAL", engine=mock_engine)
    assert res["valid"] is False
    assert res["status"] == "FACE_NOT_CENTERED"


def test_10_multiple_faces_rejected():
    """Images containing multiple faces are rejected with MULTIPLE_FACES."""
    service = FacePoseService()
    img_bytes = make_test_image()

    mock_engine = MagicMock()
    mock_engine.detect_faces_with_landmarks.return_value = [
        {"bbox": (100, 200, 200, 100), "confidence": 0.95, "landmarks": CANONICAL_FRONTAL},
        {"bbox": (100, 380, 200, 280), "confidence": 0.92, "landmarks": CANONICAL_FRONTAL},
    ]

    res = service.validate_image_and_pose(img_bytes, "FRONTAL", engine=mock_engine)
    assert res["valid"] is False
    assert res["status"] == "MULTIPLE_FACES"


def test_11_no_face_rejected():
    """Images with zero detected faces are rejected with NO_FACE."""
    service = FacePoseService()
    img_bytes = make_test_image()

    mock_engine = MagicMock()
    mock_engine.detect_faces_with_landmarks.return_value = []

    res = service.validate_image_and_pose(img_bytes, "FRONTAL", engine=mock_engine)
    assert res["valid"] is False
    assert res["status"] == "NO_FACE"


def test_12_poor_quality_image_rejected():
    """Image with low SCRFD detection confidence (<0.80) or dark lighting is rejected."""
    service = FacePoseService()
    img_bytes = make_test_image(brightness=10)  # extremely dark image

    mock_engine = MagicMock()
    mock_engine.detect_faces_with_landmarks.return_value = [{
        "bbox": (100, 300, 300, 100),
        "confidence": 0.65,  # below 0.80 threshold
        "landmarks": CANONICAL_FRONTAL.copy()
    }]

    res = service.validate_image_and_pose(img_bytes, "FRONTAL", engine=mock_engine)
    assert res["valid"] is False
    assert res["status"] in ["IMAGE_QUALITY_LOW", "POOR_LIGHTING"]


# ==============================================================================
# 2. END-TO-END WORKFLOW & ENROLLMENT COMPLETION TESTS
# ==============================================================================

def test_13_and_14_and_15_three_step_enrollment_lifecycle():
    """
    Validates:
    - Step 1: Incomplete (1/3)
    - Step 2: Incomplete (2/3)
    - Step 3: Complete (3/3)
    - All embeddings belong to authenticated student.
    - Zero image files leaked to disk.
    - Cleanup in finally block.
    """
    db = SessionLocal()
    # Authenticate as student AKASH A (721024149001)
    student = db.query(Student).filter(Student.roll_number == "721024149001").first()
    student_id = student.id
    user = student.user
    user.locked_until = None
    user.failed_login_attempts = 0
    db.commit()
    token = create_access_token(subject=str(user.id), role=user.role.value)
    headers = {"Authorization": f"Bearer {token}"}
    db.close()

    # Pre-clean any prior embeddings for this student
    client.post("/api/v1/student/enroll-face/reset", headers=headers)

    img_bytes = make_test_image()

    # Mock engine to return valid poses for each step
    lm_frontal = CANONICAL_FRONTAL.copy()
    lm_left = CANONICAL_FRONTAL.copy()
    lm_left[2, 0] -= 5.3  # yaw ~ -15°
    lm_right = CANONICAL_FRONTAL.copy()
    lm_right[2, 0] += 5.3  # yaw ~ +15°

    dummy_512_emb = np.array([0.044] * 512, dtype=np.float32)
    dummy_512_emb = dummy_512_emb / np.linalg.norm(dummy_512_emb)

    mock_engine = MagicMock()
    mock_engine.model_name = "w600k_r50"
    mock_engine.model_version = "v1"
    mock_engine.embedding_dimension = 512
    mock_engine.detector_name = "scrfd_10g_kps"
    mock_engine.distance_metric = "cosine"
    mock_engine.generate_embeddings.return_value = [dummy_512_emb]

    try:
        # Step 0: Check initial enrollment status -> 0/3 INCOMPLETE
        status_0 = client.get("/api/v1/student/enrollment-status", headers=headers).json()
        assert status_0["status"] == "ENROLLMENT_INCOMPLETE"
        assert status_0["templates_count"] == 0
        assert status_0["next_step"] == "FRONTAL"

        with patch("app.services.face_pose_service.RecognitionEngineFactory.get_engine", return_value=mock_engine), \
             patch("app.api.student.RecognitionEngineFactory.get_engine", return_value=mock_engine):

            # --- CAPTURE 1: FRONTAL ---
            mock_engine.detect_faces_with_landmarks.return_value = [{
                "bbox": (100, 300, 300, 100),
                "confidence": 0.98,
                "landmarks": lm_frontal
            }]

            res_1 = client.post(
                "/api/v1/student/enroll-face/capture",
                data={"step": "FRONTAL"},
                files={"file": ("capture1.jpg", img_bytes, "image/jpeg")},
                headers=headers
            )
            assert res_1.status_code == 200, res_1.text
            d1 = res_1.json()
            assert d1["templates_count"] == 1
            assert d1["status"] == "ENROLLMENT_INCOMPLETE"  # Requirement 14: 1-2 templates -> incomplete
            assert d1["next_step"] == "LEFT_15"

            # Check status endpoint
            status_1 = client.get("/api/v1/student/enrollment-status", headers=headers).json()
            assert status_1["status"] == "ENROLLMENT_INCOMPLETE"
            assert status_1["templates_count"] == 1
            assert status_1["completed_steps"] == ["FRONTAL"]

            # --- CAPTURE 2: LEFT 15° ---
            mock_engine.detect_faces_with_landmarks.return_value = [{
                "bbox": (100, 300, 300, 100),
                "confidence": 0.97,
                "landmarks": lm_left
            }]

            res_2 = client.post(
                "/api/v1/student/enroll-face/capture",
                data={"step": "LEFT_15"},
                files={"file": ("capture2.jpg", img_bytes, "image/jpeg")},
                headers=headers
            )
            assert res_2.status_code == 200, res_2.text
            d2 = res_2.json()
            assert d2["templates_count"] == 2
            assert d2["status"] == "ENROLLMENT_INCOMPLETE"  # Requirement 14: 1-2 templates -> incomplete
            assert d2["next_step"] == "RIGHT_15"

            # --- CAPTURE 3: RIGHT 15° ---
            mock_engine.detect_faces_with_landmarks.return_value = [{
                "bbox": (100, 300, 300, 100),
                "confidence": 0.99,
                "landmarks": lm_right
            }]

            res_3 = client.post(
                "/api/v1/student/enroll-face/capture",
                data={"step": "RIGHT_15"},
                files={"file": ("capture3.jpg", img_bytes, "image/jpeg")},
                headers=headers
            )
            assert res_3.status_code == 200, res_3.text
            d3 = res_3.json()
            assert d3["templates_count"] == 3
            assert d3["status"] == "ENROLLED"  # Requirement 13: 3 templates -> complete
            assert d3["next_step"] is None
            assert "Face enrollment complete — 3 of 3 captures accepted." in d3["enrollment_message"]

            # Check status endpoint -> ENROLLED
            status_final = client.get("/api/v1/student/enrollment-status", headers=headers).json()
            assert status_final["status"] == "ENROLLED"
            assert status_final["templates_count"] == 3
            assert status_final["completed_steps"] == ["FRONTAL", "LEFT_15", "RIGHT_15"]
            assert "Face enrollment complete — 3 of 3 captures accepted." in status_final["message"]

        # --- Requirement 15: All stored embeddings belong to authenticated student ---
        db = SessionLocal()
        student_embs = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == student_id).all()
        assert len(student_embs) == 3

        # Verify metadata
        for emb in student_embs:
            assert emb.student_id == student_id
            assert emb.dimension == 512
            assert emb.model_name == "w600k_r50"
            assert emb.detector_name == "scrfd_10g_kps"
            assert emb.distance_metric == "cosine"
            assert emb.image_path.startswith("memory:capture_")
            vec = json.loads(emb.embedding_json)
            assert len(vec) == 512
            assert np.isclose(np.linalg.norm(vec), 1.0, atol=1e-3)
        db.close()

    finally:
        # Reset and clean up to maintain student database invariant
        client.post("/api/v1/student/enroll-face/reset", headers=headers)
        db = SessionLocal()
        final_student_count = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == student_id).count()
        db.close()
        assert final_student_count == 0, f"Cleanup failed: {final_student_count} student embeddings remaining!"
