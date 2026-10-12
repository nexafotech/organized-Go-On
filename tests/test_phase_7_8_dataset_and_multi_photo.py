import io
import os
import json
import pytest
import numpy as np
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.core.config import settings
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token
from app.models.user import User, Faculty, UserRole
from app.models.academic import ClassSection
from app.models.student import Student
from app.models.attendance import FaceEmbedding
from app.engines.recognition.factory import RecognitionEngineFactory
from app.services.face_dataset_service import (
    ensure_dataset_root,
    sanitize_roll_number,
    get_student_dir,
    save_student_face_image,
    delete_student_photo_file,
    clear_student_photos_dir,
    check_duplicate_photo,
)

# Isolated In-Memory Test Database
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
def setup_test_db(tmp_path, monkeypatch):
    # Route dataset directory to isolated tmp_path
    monkeypatch.setattr(settings, "STUDENT_FACE_DATASET_DIR", str(tmp_path / "student_faces"))
    app.dependency_overrides[get_db] = override_get_db
    Base.metadata.create_all(bind=test_engine)
    RecognitionEngineFactory.reset()
    yield
    Base.metadata.drop_all(bind=test_engine)
    app.dependency_overrides.clear()
    RecognitionEngineFactory.reset()


def create_mock_jpeg():
    return b"\xff\xd8\xff\xe0\x00\x10JFIF" + b"\x00" * 200 + b"\xff\xd9"


@pytest.fixture
def seed_data():
    db = TestingSessionLocal()
    try:
        # Create Admin
        admin = User(
            id=1,
            username="admin_p78",
            hashed_password=get_password_hash("AdminPass123!"),
            role=UserRole.ADMIN,
            is_active=True,
            force_password_change=False
        )
        # Create Student User & Profile
        stu_user = User(
            id=2,
            username="721025149046",
            hashed_password=get_password_hash("StudentPass123!"),
            role=UserRole.STUDENT,
            is_active=True,
            force_password_change=False
        )
        cls = ClassSection(id=1, name="CSE-A", academic_year="2026-2027", grade_level="Year 3")
        student = Student(
            id=46,
            user_id=2,
            roll_number="721025149046",
            full_name="Rethish S",
            class_id=1,
            is_active=True
        )
        db.add_all([admin, stu_user, cls, student])
        db.commit()

        admin_token = create_access_token(subject=str(admin.id), role="admin")
        student_token = create_access_token(subject=str(stu_user.id), role="student")

        return {
            "admin_headers": {"Authorization": f"Bearer {admin_token}"},
            "student_headers": {"Authorization": f"Bearer {student_token}"},
            "student_id": 46,
            "roll_number": "721025149046"
        }
    finally:
        db.close()


def test_canonical_dataset_directory_creation():
    """Dataset root and student directories are created automatically and safely."""
    root = ensure_dataset_root()
    assert os.path.exists(root)
    assert os.path.isdir(root)

    stu_dir = get_student_dir("721025149046", create=True)
    assert os.path.exists(stu_dir)
    assert "721025149046" in stu_dir

    # Path traversal protection
    with pytest.raises(ValueError):
        sanitize_roll_number("../../../etc/passwd")

    with pytest.raises(ValueError):
        sanitize_roll_number("..\\windows\\system32")


def test_multi_photo_enrollment_partial_success(seed_data):
    """
    Admin uploads multiple photos:
    - photo1: 1 face -> SUCCESS
    - photo2: 0 faces -> REJECTED_NO_FACE
    - photo3: 2 faces -> REJECTED_MULTI_FACE
    - photo4: text file -> SKIPPED_NOT_AN_IMAGE
    - photo5: 1 face -> SUCCESS
    Result: 2 valid enrolled, 3 rejected/skipped (partial success).
    """
    headers = seed_data["admin_headers"]
    sid = seed_data["student_id"]

    mock_engine = MagicMock()
    mock_engine.model_name = "dlib_resnet"
    mock_engine.model_version = "v1"
    mock_engine.embedding_dimension = 128
    mock_engine.detector_name = "dlib_hog"
    mock_engine.distance_metric = "euclidean"

    # Behavior for 4 image files
    def detect_side_effect(img_bytes):
        if b"ONE_FACE_A" in img_bytes:
            return [(50, 150, 150, 50)]
        elif b"ZERO_FACES" in img_bytes:
            return []
        elif b"MULTI_FACES" in img_bytes:
            return [(10, 40, 40, 10), (60, 90, 90, 60)]
        elif b"ONE_FACE_B" in img_bytes:
            return [(30, 130, 130, 30)]
        return [(50, 150, 150, 50)]

    mock_engine.detect_faces.side_effect = detect_side_effect
    mock_engine.generate_embeddings.side_effect = lambda b, locs: [np.random.rand(128)]

    with patch("app.engines.recognition.factory.RecognitionEngineFactory.get_engine", return_value=mock_engine):
        files = [
            ("files", ("photo1.jpg", create_mock_jpeg() + b"ONE_FACE_A", "image/jpeg")),
            ("files", ("photo2.jpg", create_mock_jpeg() + b"ZERO_FACES", "image/jpeg")),
            ("files", ("photo3.jpg", create_mock_jpeg() + b"MULTI_FACES", "image/jpeg")),
            ("files", ("doc.txt", b"plain text", "text/plain")),
            ("files", ("photo5.png", create_mock_jpeg() + b"ONE_FACE_B", "image/png")),
        ]
        res = client.post(
            f"/api/v1/admin/students/{sid}/enroll-photos",
            headers=headers,
            files=files,
            data={"replace": "false"}
        )

        assert res.status_code == 200
        data = res.json()
        assert data["student_id"] == sid
        assert data["roll_number"] == "721025149046"
        assert data["total_files"] == 5
        assert data["valid_enrolled"] == 2
        assert data["rejected"] == 3

        # Verify DB records
        db = TestingSessionLocal()
        embs = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == sid).all()
        assert len(embs) == 2
        assert all("data/student_faces/721025149046/" in e.image_path for e in embs)
        db.close()


def test_add_photos_later_preserves_existing(seed_data):
    """
    Adding photos to an already enrolled student appends templates without wiping existing ones.
    """
    headers = seed_data["admin_headers"]
    sid = seed_data["student_id"]

    mock_engine = MagicMock()
    mock_engine.model_name = "dlib_resnet"
    mock_engine.model_version = "v1"
    mock_engine.embedding_dimension = 128
    mock_engine.detector_name = "dlib_hog"
    mock_engine.distance_metric = "euclidean"
    mock_engine.detect_faces.return_value = [(50, 150, 150, 50)]
    mock_engine.generate_embeddings.side_effect = lambda b, locs: [np.random.rand(128)]

    with patch("app.engines.recognition.factory.RecognitionEngineFactory.get_engine", return_value=mock_engine):
        # Batch 1: 2 photos
        files1 = [
            ("files", ("p1.jpg", create_mock_jpeg() + b"_BATCH1_1", "image/jpeg")),
            ("files", ("p2.jpg", create_mock_jpeg() + b"_BATCH1_2", "image/jpeg")),
        ]
        res1 = client.post(f"/api/v1/admin/students/{sid}/enroll-photos", headers=headers, files=files1)
        assert res1.status_code == 200
        assert res1.json()["valid_enrolled"] == 2

        # Batch 2: 1 more photo later
        files2 = [
            ("files", ("p3.jpg", create_mock_jpeg() + b"_BATCH2_1", "image/jpeg")),
        ]
        res2 = client.post(f"/api/v1/admin/students/{sid}/enroll-photos", headers=headers, files=files2)
        assert res2.status_code == 200
        assert res2.json()["valid_enrolled"] == 1

        # Verify total in DB is 3
        db = TestingSessionLocal()
        embs = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == sid).all()
        assert len(embs) == 3
        db.close()


def test_replace_face_dataset_flow(seed_data):
    """
    Replace Face Dataset explicitly purges old files and templates and replaces with new ones.
    """
    headers = seed_data["admin_headers"]
    sid = seed_data["student_id"]

    mock_engine = MagicMock()
    mock_engine.model_name = "dlib_resnet"
    mock_engine.model_version = "v1"
    mock_engine.embedding_dimension = 128
    mock_engine.detector_name = "dlib_hog"
    mock_engine.distance_metric = "euclidean"
    mock_engine.detect_faces.return_value = [(50, 150, 150, 50)]
    mock_engine.generate_embeddings.side_effect = lambda b, locs: [np.random.rand(128)]

    with patch("app.engines.recognition.factory.RecognitionEngineFactory.get_engine", return_value=mock_engine):
        # Initial: 3 photos
        files_init = [
            ("files", ("old1.jpg", create_mock_jpeg() + b"_OLD1", "image/jpeg")),
            ("files", ("old2.jpg", create_mock_jpeg() + b"_OLD2", "image/jpeg")),
            ("files", ("old3.jpg", create_mock_jpeg() + b"_OLD3", "image/jpeg")),
        ]
        client.post(f"/api/v1/admin/students/{sid}/enroll-photos", headers=headers, files=files_init)

        db = TestingSessionLocal()
        assert db.query(FaceEmbedding).filter(FaceEmbedding.student_id == sid).count() == 3
        db.close()

        # Replace with 2 new photos
        files_rep = [
            ("files", ("new1.jpg", create_mock_jpeg() + b"_NEW1", "image/jpeg")),
            ("files", ("new2.jpg", create_mock_jpeg() + b"_NEW2", "image/jpeg")),
        ]
        res = client.post(
            f"/api/v1/admin/students/{sid}/replace-dataset",
            headers=headers,
            files=files_rep
        )
        assert res.status_code == 200
        data = res.json()
        assert data["replaced_old_count"] == 3
        assert data["valid_enrolled"] == 2

        db = TestingSessionLocal()
        embs = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == sid).all()
        assert len(embs) == 2
        db.close()


def test_delete_individual_photo_preserves_others(seed_data):
    """
    Deleting a single photo removes only that template and physical file.
    """
    headers = seed_data["admin_headers"]
    sid = seed_data["student_id"]

    mock_engine = MagicMock()
    mock_engine.model_name = "dlib_resnet"
    mock_engine.model_version = "v1"
    mock_engine.embedding_dimension = 128
    mock_engine.detector_name = "dlib_hog"
    mock_engine.distance_metric = "euclidean"
    mock_engine.detect_faces.return_value = [(50, 150, 150, 50)]
    mock_engine.generate_embeddings.side_effect = lambda b, locs: [np.random.rand(128)]

    with patch("app.engines.recognition.factory.RecognitionEngineFactory.get_engine", return_value=mock_engine):
        files = [
            ("files", ("stay.jpg", create_mock_jpeg() + b"_STAY", "image/jpeg")),
            ("files", ("remove.jpg", create_mock_jpeg() + b"_REMOVE", "image/jpeg")),
        ]
        res = client.post(f"/api/v1/admin/students/{sid}/enroll-photos", headers=headers, files=files)
        items = res.json()["items"]
        delete_emb_id = items[1]["embedding_id"]

        # Delete the second photo
        del_res = client.delete(
            f"/api/v1/admin/students/{sid}/photos/{delete_emb_id}",
            headers=headers
        )
        assert del_res.status_code == 200
        assert del_res.json()["remaining_templates"] == 1

        db = TestingSessionLocal()
        embs = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == sid).all()
        assert len(embs) == 1
        assert embs[0].id == items[0]["embedding_id"]
        db.close()


def test_view_dataset_and_authenticated_image_serving(seed_data):
    """
    Dataset view exposes photo count, template count, and authenticated photo download.
    Unauthenticated or unauthorized access is denied.
    """
    headers = seed_data["admin_headers"]
    stu_headers = seed_data["student_headers"]
    sid = seed_data["student_id"]

    mock_engine = MagicMock()
    mock_engine.model_name = "dlib_resnet"
    mock_engine.model_version = "v1"
    mock_engine.embedding_dimension = 128
    mock_engine.detector_name = "dlib_hog"
    mock_engine.distance_metric = "euclidean"
    mock_engine.detect_faces.return_value = [(50, 150, 150, 50)]
    mock_engine.generate_embeddings.side_effect = lambda b, locs: [np.random.rand(128)]

    with patch("app.engines.recognition.factory.RecognitionEngineFactory.get_engine", return_value=mock_engine):
        files = [("files", ("sample.jpg", create_mock_jpeg() + b"_SAMPLE", "image/jpeg"))]
        client.post(f"/api/v1/admin/students/{sid}/enroll-photos", headers=headers, files=files)

        # 1. View dataset
        view_res = client.get(f"/api/v1/admin/students/{sid}/photos", headers=headers)
        assert view_res.status_code == 200
        data = view_res.json()
        assert data["student_id"] == sid
        assert data["photo_count"] == 1
        assert data["template_count"] == 1
        assert len(data["photos"]) == 1

        emb_id = data["photos"][0]["embedding_id"]

        # 2. Authenticated Admin image fetch
        img_res = client.get(f"/api/v1/admin/students/{sid}/photos/{emb_id}/image", headers=headers)
        assert img_res.status_code == 200
        assert img_res.headers["content-type"] == "image/jpeg"

        # 3. Student/non-admin is forbidden (403)
        stu_res = client.get(f"/api/v1/admin/students/{sid}/photos", headers=stu_headers)
        assert stu_res.status_code == 403

        stu_img_res = client.get(f"/api/v1/admin/students/{sid}/photos/{emb_id}/image", headers=stu_headers)
        assert stu_img_res.status_code == 403
