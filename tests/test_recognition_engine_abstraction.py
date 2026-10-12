import os
import sys
import json
import pytest
import numpy as np
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

# Ensure app path is in pythonpath
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token
from app.models.user import User, Faculty, UserRole
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.student import Student
from app.models.attendance import ClassSession, FaceEmbedding, SessionStatus, AttendanceStatus, RecognitionSource
from app.engines.recognition.base import BaseRecognitionEngine, RecognitionConfig
from app.engines.recognition.local_dlib import DlibFaceRecognitionEngine
from app.engines.recognition.factory import RecognitionEngineFactory

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
def setup_test_db():
    app.dependency_overrides[get_db] = override_get_db
    Base.metadata.create_all(bind=test_engine)
    RecognitionEngineFactory.reset()
    yield
    Base.metadata.drop_all(bind=test_engine)
    app.dependency_overrides.clear()
    RecognitionEngineFactory.reset()


def get_auth_headers(user_id: int, role: str = "ADMIN") -> dict:
    token = create_access_token(subject=user_id, role=role)
    return {"Authorization": f"Bearer {token}"}


# =========================================================
# 1. Factory & Abstraction Unit Tests
# =========================================================

def test_factory_default_returns_scrfd_arcface():
    RecognitionEngineFactory.reset()
    engine = RecognitionEngineFactory.get_engine()
    assert isinstance(engine, BaseRecognitionEngine)
    assert engine.engine_name == "scrfd_arcface"
    assert engine.embedding_dimension == 512



def test_factory_get_dlib_explicit_and_case_insensitive():
    for name in ["dlib", "DLIB", "  dlib  "]:
        RecognitionEngineFactory.reset()
        engine = RecognitionEngineFactory.get_engine(name)
        assert isinstance(engine, DlibFaceRecognitionEngine)
        assert engine.engine_name == "dlib"


def test_factory_caching_returns_same_instance():
    RecognitionEngineFactory.reset()
    engine1 = RecognitionEngineFactory.get_engine("dlib")
    engine2 = RecognitionEngineFactory.get_engine("dlib")
    assert engine1 is engine2


def test_factory_reset_clears_cache():
    RecognitionEngineFactory.reset()
    engine1 = RecognitionEngineFactory.get_engine("dlib")
    RecognitionEngineFactory.reset()
    engine2 = RecognitionEngineFactory.get_engine("dlib")
    assert engine1 is not engine2


def test_factory_env_var_override(monkeypatch):
    monkeypatch.setenv("FACE_RECOGNITION_ENGINE", "dlib")
    RecognitionEngineFactory.reset()
    engine = RecognitionEngineFactory.get_engine()
    assert isinstance(engine, DlibFaceRecognitionEngine)


def test_factory_scrfd_arcface_returns_engine():
    from app.engines.recognition.scrfd_arcface import ScrfdArcFaceRecognitionEngine
    RecognitionEngineFactory.reset()
    engine = RecognitionEngineFactory.get_engine("scrfd_arcface")
    assert isinstance(engine, ScrfdArcFaceRecognitionEngine)
    assert engine.engine_name == "scrfd_arcface"
    assert engine.embedding_dimension == 512
    assert engine.distance_metric == "cosine"


def test_factory_unknown_engine_raises_value_error():
    RecognitionEngineFactory.reset()
    with pytest.raises(ValueError) as exc_info:
        RecognitionEngineFactory.get_engine("non_existent_vision_engine")
    assert "Unsupported face recognition engine" in str(exc_info.value)


# =========================================================
# 2. Engine Metadata & Invariant Tests
# =========================================================

def test_dlib_engine_metadata_properties():
    engine = RecognitionEngineFactory.get_engine("dlib")
    assert engine.engine_name == "dlib"
    assert engine.embedding_dimension == 128
    assert engine.distance_metric == "euclidean"
    assert engine.model_name == "dlib_resnet"
    assert engine.model_version == "v1"
    assert engine.detector_name == "dlib_hog"


def test_recognition_config_threshold_invariants():
    config = RecognitionConfig()
    assert config.distance_threshold == 0.45
    assert config.uncertain_threshold == 0.60
    assert config.min_face_size == 20
    assert config.max_upload_size_mb == 10
    assert config.detection_model == "hog"


# =========================================================
# 3. FaceEmbedding Model Metadata Tests
# =========================================================

def test_face_embedding_model_metadata_defaults():
    db = TestingSessionLocal()
    # Create class & student
    c = ClassSection(name="CSE-3A")
    db.add(c)
    db.commit()
    st = Student(roll_number="CS001", full_name="Alice Smith", class_id=c.id)
    db.add(st)
    db.commit()

    # Create FaceEmbedding without explicit metadata to test defaults
    emb = FaceEmbedding(
        student_id=st.id,
        embedding_json=json.dumps([0.1] * 128),
        image_path="upload:test.jpg"
    )
    db.add(emb)
    db.commit()
    db.refresh(emb)

    assert emb.model_name == "dlib_resnet"
    assert emb.model_version == "v1"
    assert emb.dimension == 128
    assert emb.detector_name == "dlib_hog"
    assert emb.distance_metric == "euclidean"
    assert emb.quality_score is None
    db.close()


# =========================================================
# 4. Admin Enrollment API Integration Tests
# =========================================================

def test_admin_face_enrollment_stores_engine_metadata(monkeypatch):
    monkeypatch.setenv("FACE_RECOGNITION_ENGINE", "dlib")
    RecognitionEngineFactory.reset()
    db = TestingSessionLocal()
    admin_user = User(username="admin_user", email="admin@test.com", hashed_password=get_password_hash("pass123"), role=UserRole.ADMIN)
    db.add(admin_user)
    c = ClassSection(name="CSE-3A")
    db.add(c)
    db.commit()
    st = Student(roll_number="CS002", full_name="Bob Jones", class_id=c.id)
    db.add(st)
    db.commit()
    admin_id = admin_user.id
    student_id = st.id
    db.close()

    headers = get_auth_headers(admin_id, role="ADMIN")

    dummy_image_bytes = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb\x00C\x00" + b"\x00" * 100

    # Mock engine detection & embedding generation
    engine = RecognitionEngineFactory.get_engine("dlib")
    with patch.object(engine, "detect_faces", return_value=[(10, 80, 80, 10)]), \
         patch.object(engine, "generate_embeddings", return_value=[np.array([0.05] * 128)]):

        response = client.post(
            f"/api/v1/admin/students/{student_id}/enroll-face",
            files={"file": ("bob.jpg", dummy_image_bytes, "image/jpeg")},
            headers=headers
        )

        assert response.status_code == 200
        data = response.json()
        assert data["student_id"] == student_id
        assert "Successfully enrolled" in data["message"]

        # Verify DB record has all metadata populated
        db = TestingSessionLocal()
        saved_emb = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == student_id).first()
        assert saved_emb is not None
        assert saved_emb.model_name == "dlib_resnet"
        assert saved_emb.model_version == "v1"
        assert saved_emb.dimension == 128
        assert saved_emb.detector_name == "dlib_hog"
        assert saved_emb.distance_metric == "euclidean"
        db.close()


# =========================================================
# 5. Faculty Recognition API Compatibility Filtering Tests
# =========================================================

def test_faculty_recognition_filters_incompatible_embeddings(monkeypatch):
    monkeypatch.setenv("FACE_RECOGNITION_ENGINE", "dlib")
    RecognitionEngineFactory.reset()
    db = TestingSessionLocal()

    # Create faculty user
    fac_user = User(username="fac_user", email="faculty@test.com", hashed_password=get_password_hash("pass123"), role=UserRole.FACULTY)
    db.add(fac_user)
    db.commit()
    fac_profile = Faculty(user_id=fac_user.id, employee_id="FAC999", full_name="Prof. Tester", department="CSE")
    db.add(fac_profile)
    db.commit()

    # Create Class, Subject, Period, TimetableEntry, Session
    c = ClassSection(name="CSE-3A")
    db.add(c)
    sub = Subject(code="CS101", name="Intro to CS")
    db.add(sub)
    p = Period(period_number=1, name="Period 1", start_time="09:10", end_time="10:00")
    db.add(p)
    db.commit()

    assign = FacultyAssignment(faculty_id=fac_profile.id, subject_id=sub.id, class_id=c.id)
    db.add(assign)
    db.commit()

    tt = TimetableEntry(day_of_week="MONDAY", period_id=p.id, assignment_id=assign.id)
    db.add(tt)
    db.commit()

    session = ClassSession(
        timetable_entry_id=tt.id,
        faculty_id=fac_profile.id,
        date="2026-09-25",
        status=SessionStatus.ACTIVE
    )
    db.add(session)
    db.commit()

    # Create student
    st = Student(roll_number="CS003", full_name="Charlie Brown", class_id=c.id, is_active=True)
    db.add(st)
    db.commit()

    # Add 1 compatible Dlib embedding (128-d, dlib_resnet, euclidean)
    emb_dlib = FaceEmbedding(
        student_id=st.id,
        embedding_json=json.dumps([0.12] * 128),
        model_name="dlib_resnet",
        model_version="v1",
        dimension=128,
        detector_name="dlib_hog",
        distance_metric="euclidean"
    )
    # Add 1 incompatible future ArcFace embedding (512-d, arcface_r50, cosine)
    emb_arcface = FaceEmbedding(
        student_id=st.id,
        embedding_json=json.dumps([0.34] * 512),
        model_name="arcface_r50",
        model_version="v1",
        dimension=512,
        detector_name="scrfd",
        distance_metric="cosine"
    )
    db.add_all([emb_dlib, emb_arcface])
    db.commit()

    session_id = session.id
    fac_user_id = fac_user.id
    target_student_id = st.id
    db.close()

    headers = get_auth_headers(fac_user_id, role="FACULTY")

    # Intercept recognize_image to inspect enrolled_students passed to active engine
    captured_enrolled = []
    mock_recognition_result = {
        "processed_faces": 1,
        "high_confidence_matches": [],
        "uncertain_matches": [],
        "unknown_faces": []
    }

    def mock_recognize(image_bytes, enrolled_students=None, config=None):
        captured_enrolled.extend(enrolled_students or [])
        return mock_recognition_result

    engine = RecognitionEngineFactory.get_engine("dlib")
    dummy_image_bytes = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb\x00C\x00" + b"\x00" * 100

    with patch.object(engine, "recognize_image", side_effect=mock_recognize):
        response = client.post(
            f"/api/v1/faculty/sessions/{session_id}/recognize-image",
            files={"file": ("photo.jpg", dummy_image_bytes, "image/jpeg")},
            headers=headers
        )

        assert response.status_code == 200

        # Assert only the 128-d compatible Dlib embedding was passed to the engine!
        assert len(captured_enrolled) == 1
        st_data = captured_enrolled[0]
        assert st_data["student_id"] == target_student_id
        assert len(st_data["embeddings"]) == 1
        assert len(st_data["embeddings"][0]) == 128
        # The 512-d ArcFace vector was NOT loaded into Dlib!
