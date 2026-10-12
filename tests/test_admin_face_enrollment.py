import io
import json
import pytest
import numpy as np
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token
from app.models.user import User, Faculty, UserRole
from app.models.academic import ClassSection
from app.models.student import Student
from app.models.attendance import FaceEmbedding
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
def setup_test_db(monkeypatch):
    monkeypatch.setenv("FACE_RECOGNITION_ENGINE", "dlib")
    app.dependency_overrides[get_db] = override_get_db
    Base.metadata.create_all(bind=test_engine)
    RecognitionEngineFactory.reset()
    yield
    Base.metadata.drop_all(bind=test_engine)
    app.dependency_overrides.clear()
    RecognitionEngineFactory.reset()


def create_mock_jpeg():
    # Return 100 bytes of dummy JPEG header bytes
    return b"\xff\xd8\xff\xe0\x00\x10JFIF" + b"\x00" * 200 + b"\xff\xd9"


@pytest.fixture
def seed_data():
    db = TestingSessionLocal()
    try:
        # Create Admin user
        admin = User(
            id=1,
            username="admin",
            email="admin@test.edu",
            hashed_password=get_password_hash("AdminPass123!"),
            role=UserRole.ADMIN,
            is_active=True
        )
        # Create Faculty user
        fac_user = User(
            id=2,
            username="faculty1",
            email="faculty1@test.edu",
            hashed_password=get_password_hash("FacultyPass123!"),
            role=UserRole.FACULTY,
            is_active=True
        )
        faculty = Faculty(
            id=1,
            user_id=2,
            employee_id="FAC001",
            full_name="Prof. Raman",
            department="CSE"
        )
        # Create Student user
        stu_user = User(
            id=3,
            username="721025149001",
            email="student1@test.edu",
            hashed_password=get_password_hash("StudentPass123!"),
            role=UserRole.STUDENT,
            is_active=True
        )
        section = ClassSection(
            id=1,
            name="II CSE A",
            academic_year="2026-2027",
            grade_level="Year 2"
        )
        db.add_all([admin, fac_user, faculty, stu_user, section])
        db.flush()

        student1 = Student(
            id=1,
            roll_number="721025149001",
            full_name="ABINAYA B",
            class_id=section.id,
            user_id=stu_user.id,
            is_active=True
        )
        student2 = Student(
            id=2,
            roll_number="721025149002",
            full_name="ABISHEK A",
            class_id=section.id,
            is_active=True
        )
        db.add_all([student1, student2])
        db.commit()

        admin_token = create_access_token(subject=1, role="ADMIN")
        fac_token = create_access_token(subject=2, role="FACULTY")
        stu_token = create_access_token(subject=3, role="STUDENT")

        return {
            "admin_headers": {"Authorization": f"Bearer {admin_token}"},
            "fac_headers": {"Authorization": f"Bearer {fac_token}"},
            "stu_headers": {"Authorization": f"Bearer {stu_token}"},
            "student1_id": 1,
            "student2_id": 2,
        }
    finally:
        db.close()


def test_admin_biometrics_summary_initial(seed_data):
    """TEST 1: Admin fetches initial biometrics summary."""
    headers = seed_data["admin_headers"]
    res = client.get("/api/v1/admin/biometrics/summary", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["total_students"] == 2
    assert data["enrolled_count"] == 0
    assert data["pending_count"] == 2
    assert data["model_name"] is not None
    assert data["dimension"] == 128


def test_admin_list_students_and_search(seed_data):
    """TEST 2 & 3: List students, search by roll number and name."""
    headers = seed_data["admin_headers"]
    # List all
    res = client.get("/api/v1/admin/biometrics/students", headers=headers)
    assert res.status_code == 200
    items = res.json()
    assert len(items) == 2
    assert items[0]["enrolled"] is False

    # Search by roll number
    res_search = client.get("/api/v1/admin/biometrics/students?search=721025149001", headers=headers)
    assert res_search.status_code == 200
    items_search = res_search.json()
    assert len(items_search) == 1
    assert items_search[0]["full_name"] == "ABINAYA B"

    # Filter by enrolled_only=True (initially 0)
    res_enrolled = client.get("/api/v1/admin/biometrics/students?enrolled_only=true", headers=headers)
    assert res_enrolled.status_code == 200
    assert len(res_enrolled.json()) == 0


def test_admin_get_student_biometrics_detail(seed_data):
    """TEST 4: View single student biometrics status and metadata."""
    headers = seed_data["admin_headers"]
    sid = seed_data["student1_id"]
    res = client.get(f"/api/v1/admin/students/{sid}/biometrics", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["student_id"] == sid
    assert data["full_name"] == "ABINAYA B"
    assert data["enrolled"] is False
    assert data["template_count"] == 0
    assert data["templates"] == []


def test_face_validation_rejections(seed_data):
    """TEST 5-7: Face validation errors (no face, multiple faces, small face)."""
    headers = seed_data["admin_headers"]
    sid = seed_data["student1_id"]
    fake_img = create_mock_jpeg()

    mock_engine = MagicMock()
    mock_engine.model_name = "dlib_resnet"
    mock_engine.model_version = "v1"
    mock_engine.embedding_dimension = 128
    mock_engine.detector_name = "dlib_hog"
    mock_engine.distance_metric = "euclidean"

    with patch.object(RecognitionEngineFactory, "get_engine", return_value=mock_engine):
        # Case 1: No face detected
        mock_engine.detect_faces.return_value = []
        res = client.post(
            f"/api/v1/admin/students/{sid}/enroll-face",
            headers=headers,
            files={"file": ("test.jpg", fake_img, "image/jpeg")}
        )
        assert res.status_code == 400
        assert "No face detected" in res.json()["detail"]

        # Case 2: Multiple faces detected
        mock_engine.detect_faces.return_value = [(10, 100, 100, 10), (120, 200, 200, 120)]
        res = client.post(
            f"/api/v1/admin/students/{sid}/enroll-face",
            headers=headers,
            files={"file": ("test.jpg", fake_img, "image/jpeg")}
        )
        assert res.status_code == 400
        assert "Multiple faces" in res.json()["detail"]

        # Case 3: Face too small (<20px)
        mock_engine.detect_faces.return_value = [(10, 25, 25, 10)]  # 15x15 px
        res = client.post(
            f"/api/v1/admin/students/{sid}/enroll-face",
            headers=headers,
            files={"file": ("test.jpg", fake_img, "image/jpeg")}
        )
        assert res.status_code == 400
        assert "too small" in res.json()["detail"]


def test_successful_enrollment_and_status_update(seed_data):
    """TEST 8-13: Successful face enrollment, status change, and persistence."""
    headers = seed_data["admin_headers"]
    sid = seed_data["student1_id"]
    fake_img = create_mock_jpeg()

    dummy_vector = np.full((128,), 0.05, dtype=np.float64)

    mock_engine = MagicMock()
    mock_engine.model_name = "dlib_resnet"
    mock_engine.model_version = "v1"
    mock_engine.embedding_dimension = 128
    mock_engine.detector_name = "dlib_hog"
    mock_engine.distance_metric = "euclidean"
    mock_engine.detect_faces.return_value = [(50, 150, 150, 50)]  # 100x100 face
    mock_engine.generate_embeddings.return_value = [dummy_vector]

    with patch.object(RecognitionEngineFactory, "get_engine", return_value=mock_engine):
        res = client.post(
            f"/api/v1/admin/students/{sid}/enroll-face",
            headers=headers,
            files={"file": ("photo.jpg", fake_img, "image/jpeg")}
        )
        assert res.status_code == 200
        data = res.json()
        assert data["enrolled"] is True
        assert data["template_count"] == 1
        assert data["student_id"] == sid

    # Verify student status is now ENROLLED
    res_status = client.get(f"/api/v1/admin/students/{sid}/biometrics", headers=headers)
    assert res_status.status_code == 200
    st_data = res_status.json()
    assert st_data["enrolled"] is True
    assert st_data["template_count"] == 1
    assert len(st_data["templates"]) == 1

    # Verify summary count incremented
    res_summary = client.get("/api/v1/admin/biometrics/summary", headers=headers)
    assert res_summary.status_code == 200
    sum_data = res_summary.json()
    assert sum_data["enrolled_count"] == 1
    assert sum_data["pending_count"] == 1


def test_protection_against_silent_overwrite_and_replace(seed_data):
    """TEST 14-16: Overwrite protection and safe replace with replace=True."""
    headers = seed_data["admin_headers"]
    sid = seed_data["student1_id"]
    fake_img = create_mock_jpeg()

    dummy_vector1 = np.full((128,), 0.05, dtype=np.float64)
    dummy_vector2 = np.full((128,), 0.08, dtype=np.float64)

    mock_engine = MagicMock()
    mock_engine.model_name = "dlib_resnet"
    mock_engine.model_version = "v1"
    mock_engine.embedding_dimension = 128
    mock_engine.detector_name = "dlib_hog"
    mock_engine.distance_metric = "euclidean"
    mock_engine.detect_faces.return_value = [(50, 150, 150, 50)]
    mock_engine.generate_embeddings.return_value = [dummy_vector1]

    with patch.object(RecognitionEngineFactory, "get_engine", return_value=mock_engine):
        # 1. First enrollment
        res1 = client.post(
            f"/api/v1/admin/students/{sid}/enroll-face",
            headers=headers,
            files={"file": ("first.jpg", fake_img, "image/jpeg")}
        )
        assert res1.status_code == 200

        # 2. Attempt second enrollment without replace=True -> Must be rejected!
        res2 = client.post(
            f"/api/v1/admin/students/{sid}/enroll-face",
            headers=headers,
            files={"file": ("second.jpg", fake_img, "image/jpeg")}
        )
        assert res2.status_code == 400
        assert "already has an enrolled face" in res2.json()["detail"]

        # 3. Attempt replacement with replace=True
        mock_engine.generate_embeddings.return_value = [dummy_vector2]
        res3 = client.post(
            f"/api/v1/admin/students/{sid}/enroll-face?replace=true",
            headers=headers,
            files={"file": ("second.jpg", fake_img, "image/jpeg")}
        )
        assert res3.status_code == 200
        assert res3.json()["enrolled"] is True

    # Check that template count is still exactly 1 (old template deleted)
    res_status = client.get(f"/api/v1/admin/students/{sid}/biometrics", headers=headers)
    assert res_status.status_code == 200
    st_data = res_status.json()
    assert st_data["template_count"] == 1


def test_remove_and_reset_face(seed_data):
    """TEST 17: Admin removes/resets biometric face enrollment."""
    headers = seed_data["admin_headers"]
    sid = seed_data["student1_id"]
    fake_img = create_mock_jpeg()

    dummy_vector = np.full((128,), 0.05, dtype=np.float64)
    mock_engine = MagicMock()
    mock_engine.model_name = "dlib_resnet"
    mock_engine.model_version = "v1"
    mock_engine.embedding_dimension = 128
    mock_engine.detector_name = "dlib_hog"
    mock_engine.distance_metric = "euclidean"
    mock_engine.detect_faces.return_value = [(50, 150, 150, 50)]
    mock_engine.generate_embeddings.return_value = [dummy_vector]

    with patch.object(RecognitionEngineFactory, "get_engine", return_value=mock_engine):
        res = client.post(
            f"/api/v1/admin/students/{sid}/enroll-face",
            headers=headers,
            files={"file": ("photo.jpg", fake_img, "image/jpeg")}
        )
        assert res.status_code == 200

    # Reset face
    res_reset = client.post(f"/api/v1/admin/students/{sid}/reset-face", headers=headers)
    assert res_reset.status_code == 200
    assert res_reset.json()["deleted_templates"] == 1

    # Verify status reverted to not enrolled
    res_status = client.get(f"/api/v1/admin/students/{sid}/biometrics", headers=headers)
    assert res_status.status_code == 200
    assert res_status.json()["enrolled"] is False
    assert res_status.json()["template_count"] == 0

    # Verify summary reverted
    res_summary = client.get("/api/v1/admin/biometrics/summary", headers=headers)
    assert res_summary.json()["enrolled_count"] == 0


def test_unauthorized_access_rejected(seed_data):
    """TEST 18: Non-admin users are strictly rejected with 401 or 403."""
    sid = seed_data["student1_id"]
    fake_img = create_mock_jpeg()

    # 1. No token -> 401
    res_no_auth = client.get("/api/v1/admin/biometrics/summary")
    assert res_no_auth.status_code == 401

    res_no_auth_enroll = client.post(
        f"/api/v1/admin/students/{sid}/enroll-face",
        files={"file": ("photo.jpg", fake_img, "image/jpeg")}
    )
    assert res_no_auth_enroll.status_code == 401

    # 2. Faculty token -> 403 Forbidden
    res_fac = client.get("/api/v1/admin/biometrics/summary", headers=seed_data["fac_headers"])
    assert res_fac.status_code == 403

    res_fac_enroll = client.post(
        f"/api/v1/admin/students/{sid}/enroll-face",
        headers=seed_data["fac_headers"],
        files={"file": ("photo.jpg", fake_img, "image/jpeg")}
    )
    assert res_fac_enroll.status_code == 403

    # 3. Student token -> 403 Forbidden
    res_stu = client.get("/api/v1/admin/biometrics/summary", headers=seed_data["stu_headers"])
    assert res_stu.status_code == 403

    res_stu_enroll = client.post(
        f"/api/v1/admin/students/{sid}/enroll-face",
        headers=seed_data["stu_headers"],
        files={"file": ("photo.jpg", fake_img, "image/jpeg")}
    )
    assert res_stu_enroll.status_code == 403


def test_recognition_workflow_with_admin_enrolled_face(seed_data):
    """TEST 19 (STEP 23): Verify admin-enrolled student embedding integrates into faculty recognition."""
    from app.models.academic import Subject, Period, FacultyAssignment, TimetableEntry
    from app.models.attendance import ClassSession, SessionStatus

    admin_headers = seed_data["admin_headers"]
    fac_headers = seed_data["fac_headers"]
    sid = seed_data["student1_id"]
    fake_img = create_mock_jpeg()

    # 1. Admin enrolls student 1
    dummy_vector = np.full((128,), 0.07, dtype=np.float64)
    mock_engine = MagicMock()
    mock_engine.model_name = "dlib_resnet"
    mock_engine.model_version = "v1"
    mock_engine.embedding_dimension = 128
    mock_engine.detector_name = "dlib_hog"
    mock_engine.distance_metric = "euclidean"
    mock_engine.detect_faces.return_value = [(50, 150, 150, 50)]
    mock_engine.generate_embeddings.return_value = [dummy_vector]

    with patch.object(RecognitionEngineFactory, "get_engine", return_value=mock_engine):
        res_enroll = client.post(
            f"/api/v1/admin/students/{sid}/enroll-face",
            headers=admin_headers,
            files={"file": ("admin_captured.jpg", fake_img, "image/jpeg")}
        )
        assert res_enroll.status_code == 200

    # 2. Setup academic session for faculty
    db = TestingSessionLocal()
    sub = Subject(code="CS201", name="Data Structures")
    p = Period(period_number=1, name="Period 1", start_time="09:10", end_time="10:00")
    db.add_all([sub, p])
    db.commit()

    assign = FacultyAssignment(faculty_id=1, subject_id=sub.id, class_id=1)
    db.add(assign)
    db.commit()

    tt = TimetableEntry(day_of_week="MONDAY", period_id=p.id, assignment_id=assign.id)
    db.add(tt)
    db.commit()

    session = ClassSession(
        timetable_entry_id=tt.id,
        faculty_id=1,
        date="2026-10-05",
        status=SessionStatus.ACTIVE
    )
    db.add(session)
    db.commit()
    session_id = session.id
    db.close()

    # 3. Faculty calls recognize-image on active session
    captured_enrolled = []
    mock_result = {
        "processed_faces": 1,
        "high_confidence_matches": [{"student_id": sid, "confidence": 0.94}],
        "uncertain_matches": [],
        "unknown_faces": []
    }

    def mock_recognize(image_bytes, enrolled_students=None, config=None):
        captured_enrolled.extend(enrolled_students or [])
        return mock_result

    engine = RecognitionEngineFactory.get_engine("dlib")
    with patch.object(engine, "recognize_image", side_effect=mock_recognize):
        res_rec = client.post(
            f"/api/v1/faculty/sessions/{session_id}/recognize-image",
            files={"file": ("class_photo.jpg", fake_img, "image/jpeg")},
            headers=fac_headers
        )
        assert res_rec.status_code == 200

    # 4. Verify that student 1's admin-enrolled embedding was passed to the recognition engine!
    matching_students = [s for s in captured_enrolled if s["student_id"] == sid]
    assert len(matching_students) == 1
    assert len(matching_students[0]["embeddings"]) == 1
    np.testing.assert_allclose(matching_students[0]["embeddings"][0], dummy_vector)


# =========================================================================
# PHASE 7.7 FOLDER-BASED STUDENT FACE ENROLLMENT TESTS
# =========================================================================

def test_folder_enrollment_identity_is_folder_name_and_filenames_irrelevant(seed_data):
    """
    CORE REQUIREMENT:
    IDENTITY = FOLDER NAME (REGISTER NUMBER)
    PHOTO FILENAME = IRRELEVANT TO IDENTITY
    All images inside '721025149001/' must belong to student '721025149001'.
    """
    headers = seed_data["admin_headers"]
    fake_img = create_mock_jpeg()

    # Create two images with completely arbitrary, unrelated filenames
    files = [
        ("files", ("irrelevant_holiday_shot.jpg", io.BytesIO(fake_img), "image/jpeg")),
        ("files", ("dog_photo_9999.jpeg", io.BytesIO(fake_img), "image/jpeg")),
    ]
    # Paths specify the folder as the student register number '721025149001'
    paths = [
        "721025149001/irrelevant_holiday_shot.jpg",
        "721025149001/dog_photo_9999.jpeg",
    ]

    engine = RecognitionEngineFactory.get_engine("dlib")
    dummy_vec = np.ones(128, dtype=np.float64) * 0.42

    with patch.object(engine, "detect_faces", return_value=[(10, 100, 100, 10)]), \
         patch.object(engine, "generate_embeddings", return_value=[dummy_vec, dummy_vec]):
        res = client.post(
            "/api/v1/admin/enroll-folder",
            headers=headers,
            files=files,
            data={"paths_json": json.dumps(paths), "replace": "true"}
        )

    assert res.status_code == 200
    data = res.json()
    assert data["total_folders"] == 1
    assert data["successful_students"] == 1
    assert data["total_embeddings_created"] == 2

    student_res = data["students"][0]
    # Verify authoritative identity is strictly the folder name
    assert student_res["roll_number"] == "721025149001"
    assert student_res["student_id"] == 1
    assert student_res["full_name"] == "ABINAYA B"
    assert student_res["status"] == "SUCCESS"
    assert student_res["valid_enrolled"] == 2

    # Verify embeddings are in database under Student 1
    db = TestingSessionLocal()
    embs = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == 1).all()
    assert len(embs) == 2
    assert all("721025149001" in e.image_path for e in embs)
    db.close()


def test_folder_enrollment_unknown_student_handled_gracefully(seed_data):
    """
    Folder name with unknown register number returns STUDENT_NOT_FOUND without crashing batch.
    """
    headers = seed_data["admin_headers"]
    fake_img = create_mock_jpeg()

    files = [
        ("files", ("photo.jpg", io.BytesIO(fake_img), "image/jpeg")),
    ]
    paths = ["999999999999/photo.jpg"]

    res = client.post(
        "/api/v1/admin/enroll-folder",
        headers=headers,
        files=files,
        data={"paths_json": json.dumps(paths)}
    )

    assert res.status_code == 200
    data = res.json()
    assert data["successful_students"] == 0
    assert data["failed_students"] == 1
    student_res = data["students"][0]
    assert student_res["roll_number"] == "999999999999"
    assert student_res["status"] == "STUDENT_NOT_FOUND"
    assert student_res["student_id"] is None
    assert "not found" in student_res["message"].lower()


def test_folder_enrollment_non_image_filtering(seed_data):
    """
    Non-image files inside student folder (.txt, .pdf) are skipped safely.
    """
    headers = seed_data["admin_headers"]
    fake_img = create_mock_jpeg()

    files = [
        ("files", ("notes.txt", io.BytesIO(b"lecture notes"), "text/plain")),
        ("files", ("doc.pdf", io.BytesIO(b"%PDF-1.4 header"), "application/pdf")),
        ("files", ("face.jpg", io.BytesIO(fake_img), "image/jpeg")),
    ]
    paths = [
        "721025149001/notes.txt",
        "721025149001/doc.pdf",
        "721025149001/face.jpg",
    ]

    engine = RecognitionEngineFactory.get_engine("dlib")
    dummy_vec = np.ones(128, dtype=np.float64) * 0.15

    with patch.object(engine, "detect_faces", return_value=[(10, 80, 80, 10)]), \
         patch.object(engine, "generate_embeddings", return_value=[dummy_vec]):
        res = client.post(
            "/api/v1/admin/enroll-folder",
            headers=headers,
            files=files,
            data={"paths_json": json.dumps(paths), "replace": "true"}
        )

    assert res.status_code == 200
    data = res.json()
    assert data["total_embeddings_created"] == 1
    student_res = data["students"][0]
    assert student_res["valid_enrolled"] == 1
    assert student_res["rejected"] == 2

    # Check item details
    statuses = {item["filename"]: item["status"] for item in student_res["items"]}
    assert statuses["notes.txt"] == "SKIPPED_NOT_AN_IMAGE"
    assert statuses["doc.pdf"] == "SKIPPED_NOT_AN_IMAGE"
    assert statuses["face.jpg"] == "ENROLLED"


def test_folder_enrollment_partial_failure_handling(seed_data):
    """
    Partial failure: If one image has multiple faces and one has no face,
    the valid image is still enrolled and full failure breakdown is returned.
    """
    headers = seed_data["admin_headers"]
    fake_img = create_mock_jpeg()

    files = [
        ("files", ("img_single.jpg", io.BytesIO(fake_img), "image/jpeg")),
        ("files", ("img_multi.jpg", io.BytesIO(fake_img), "image/jpeg")),
        ("files", ("img_empty.jpg", io.BytesIO(fake_img), "image/jpeg")),
    ]
    paths = [
        "721025149001/img_single.jpg",
        "721025149001/img_multi.jpg",
        "721025149001/img_empty.jpg",
    ]

    engine = RecognitionEngineFactory.get_engine("dlib")

    def mock_detect(image_bytes):
        if not hasattr(mock_detect, "counter"):
            mock_detect.counter = 0
        mock_detect.counter += 1
        if mock_detect.counter == 1:
            return [(10, 80, 80, 10)]  # 1 face
        elif mock_detect.counter == 2:
            return [(10, 80, 80, 10), (100, 180, 180, 100)]  # 2 faces
        else:
            return []  # 0 faces

    dummy_vec = np.ones(128, dtype=np.float64) * 0.25

    with patch.object(engine, "detect_faces", side_effect=mock_detect), \
         patch.object(engine, "generate_embeddings", return_value=[dummy_vec]):
        res = client.post(
            "/api/v1/admin/enroll-folder",
            headers=headers,
            files=files,
            data={"paths_json": json.dumps(paths), "replace": "true"}
        )

    assert res.status_code == 200
    data = res.json()
    assert data["successful_students"] == 1
    assert data["total_embeddings_created"] == 1

    student_res = data["students"][0]
    assert student_res["status"] == "PARTIAL_SUCCESS"
    assert student_res["valid_enrolled"] == 1
    assert student_res["rejected"] == 2

    items = {item["filename"]: item for item in student_res["items"]}
    assert items["img_single.jpg"]["status"] == "ENROLLED"
    assert items["img_multi.jpg"]["status"] == "REJECTED_MULTI_FACE"
    assert items["img_empty.jpg"]["status"] == "REJECTED_NO_FACE"


def test_folder_enrollment_duplicate_protection_and_replace(seed_data):
    """
    Verifies duplicate protection when replace=False, and clean replacement when replace=True.
    """
    headers = seed_data["admin_headers"]
    fake_img = create_mock_jpeg()

    files = [("files", ("shot1.jpg", io.BytesIO(fake_img), "image/jpeg"))]
    paths = ["721025149001/shot1.jpg"]

    engine = RecognitionEngineFactory.get_engine("dlib")
    dummy_vec = np.ones(128, dtype=np.float64) * 0.33

    # 1. Initial enrollment
    with patch.object(engine, "detect_faces", return_value=[(10, 80, 80, 10)]), \
         patch.object(engine, "generate_embeddings", return_value=[dummy_vec]):
        res1 = client.post(
            "/api/v1/admin/enroll-folder",
            headers=headers,
            files=files,
            data={"paths_json": json.dumps(paths), "replace": "false"}
        )
    assert res1.status_code == 200
    assert res1.json()["total_embeddings_created"] == 1

    # 2. Re-upload without replace=true -> must be protected against accidental overwrite
    files2 = [("files", ("shot2.jpg", io.BytesIO(fake_img), "image/jpeg"))]
    paths2 = ["721025149001/shot2.jpg"]
    res2 = client.post(
        "/api/v1/admin/enroll-folder",
        headers=headers,
        files=files2,
        data={"paths_json": json.dumps(paths2), "replace": "false"}
    )
    assert res2.status_code == 200
    assert res2.json()["students"][0]["status"] == "SKIPPED_ALREADY_ENROLLED"
    assert res2.json()["total_embeddings_created"] == 0

    # 3. Re-upload with replace=true -> purges old template and enrolls new
    files3 = [("files", ("shot3.jpg", io.BytesIO(fake_img), "image/jpeg"))]
    paths3 = ["721025149001/shot3.jpg"]
    with patch.object(engine, "detect_faces", return_value=[(10, 80, 80, 10)]), \
         patch.object(engine, "generate_embeddings", return_value=[dummy_vec]):
        res3 = client.post(
            "/api/v1/admin/enroll-folder",
            headers=headers,
            files=files3,
            data={"paths_json": json.dumps(paths3), "replace": "true"}
        )
    assert res3.status_code == 200
    st_res = res3.json()["students"][0]
    assert st_res["status"] == "SUCCESS"
    assert st_res["replaced_old_count"] == 1
    assert st_res["valid_enrolled"] == 1


def test_folder_path_preview_and_enroll(seed_data, tmp_path):
    """
    Tests /api/v1/admin/preview-folder-path and /api/v1/admin/enroll-folder-path with local directories.
    """
    headers = seed_data["admin_headers"]
    fake_img = create_mock_jpeg()

    # Create directory structure in tmp_path:
    # tmp_path / "721025149001" / "face1.jpg"
    # tmp_path / "721025149001" / "readme.txt"
    stu_dir = tmp_path / "721025149001"
    stu_dir.mkdir()
    (stu_dir / "face1.jpg").write_bytes(fake_img)
    (stu_dir / "readme.txt").write_text("info")

    # 1. Preview folder path
    res_prev = client.post(
        "/api/v1/admin/preview-folder-path",
        headers=headers,
        json={"folder_path": str(tmp_path)}
    )
    assert res_prev.status_code == 200
    prev_data = res_prev.json()
    assert prev_data["total_folders"] == 1
    assert prev_data["total_image_files"] == 1
    assert prev_data["ignored_non_image_files"] == 1
    assert prev_data["students_found_in_db"] == 1
    assert prev_data["students"][0]["roll_number"] == "721025149001"
    assert prev_data["students"][0]["exists_in_db"] is True

    # 2. Enroll folder path
    engine = RecognitionEngineFactory.get_engine("dlib")
    dummy_vec = np.ones(128, dtype=np.float64) * 0.77

    with patch.object(engine, "detect_faces", return_value=[(10, 80, 80, 10)]), \
         patch.object(engine, "generate_embeddings", return_value=[dummy_vec]):
        res_enroll = client.post(
            "/api/v1/admin/enroll-folder-path",
            headers=headers,
            json={"folder_path": str(tmp_path), "replace": True}
        )
    assert res_enroll.status_code == 200
    enroll_data = res_enroll.json()
    assert enroll_data["successful_students"] == 1
    assert enroll_data["total_embeddings_created"] == 1
    assert enroll_data["students"][0]["roll_number"] == "721025149001"
    assert enroll_data["students"][0]["status"] == "PARTIAL_SUCCESS"
    assert enroll_data["students"][0]["valid_enrolled"] == 1
    assert enroll_data["students"][0]["rejected"] == 1


def test_folder_enrollment_unauthorized_access(seed_data):
    """
    Non-admin callers must be rejected with 401 or 403.
    """
    # 1. Anonymous
    res1 = client.post("/api/v1/admin/enroll-folder", files={"files": ("f.jpg", b"123", "image/jpeg")})
    assert res1.status_code in [401, 403]

    # 2. Student role
    res2 = client.post(
        "/api/v1/admin/enroll-folder",
        headers=seed_data["stu_headers"],
        files={"files": ("f.jpg", b"123", "image/jpeg")}
    )
    assert res2.status_code == 403


def test_recognition_with_folder_enrolled_faces(seed_data):
    """
    Verifies that embeddings enrolled via folder upload are immediately recognized
    by the faculty recognition pipeline.
    """
    headers = seed_data["admin_headers"]
    fac_headers = seed_data["fac_headers"]
    fake_img = create_mock_jpeg()

    # 1. Enroll face for student 1 (721025149001) via folder upload
    files = [("files", ("face.jpg", io.BytesIO(fake_img), "image/jpeg"))]
    paths = ["721025149001/face.jpg"]

    engine = RecognitionEngineFactory.get_engine("dlib")
    folder_vec = np.array([0.123] * 128, dtype=np.float64)

    with patch.object(engine, "detect_faces", return_value=[(10, 80, 80, 10)]), \
         patch.object(engine, "generate_embeddings", return_value=[folder_vec]):
        res_enroll = client.post(
            "/api/v1/admin/enroll-folder",
            headers=headers,
            files=files,
            data={"paths_json": json.dumps(paths), "replace": "true"}
        )
    assert res_enroll.status_code == 200

    # 2. Setup an active session for faculty
    from app.models.academic import Subject, Period, FacultyAssignment, TimetableEntry
    from app.models.attendance import ClassSession, SessionStatus

    db = TestingSessionLocal()
    subj = Subject(id=2, name="Cyber Threat Intelligence", code="CS802")
    period = Period(id=2, period_number=2, name="Period 2", start_time="10:00", end_time="11:00")
    db.add_all([subj, period])
    db.flush()

    assign = FacultyAssignment(id=2, faculty_id=1, subject_id=subj.id, class_id=1)
    db.add(assign)
    db.flush()

    tt = TimetableEntry(id=2, assignment_id=assign.id, period_id=period.id, day_of_week="Monday")
    db.add(tt)
    db.flush()

    session = ClassSession(
        id=2,
        timetable_entry_id=tt.id,
        faculty_id=1,
        date="2026-10-05",
        status=SessionStatus.ACTIVE
    )
    db.add(session)
    db.commit()
    session_id = session.id
    db.close()

    # 3. Faculty calls recognize-image
    captured_enrolled = []
    mock_result = {
        "processed_faces": 1,
        "high_confidence_matches": [{"student_id": 1, "confidence": 0.98}],
        "uncertain_matches": [],
        "unknown_faces": []
    }

    def mock_recognize(image_bytes, enrolled_students=None, config=None):
        captured_enrolled.extend(enrolled_students or [])
        return mock_result

    with patch.object(engine, "recognize_image", side_effect=mock_recognize):
        res_rec = client.post(
            f"/api/v1/faculty/sessions/{session_id}/recognize-image",
            files={"file": ("group_shot.jpg", fake_img, "image/jpeg")},
            headers=fac_headers
        )
        assert res_rec.status_code == 200

    # 4. Verify that Student 1's folder-enrolled template was delivered to the recognizer
    stu1_match = [s for s in captured_enrolled if s["student_id"] == 1]
    assert len(stu1_match) == 1
    assert len(stu1_match[0]["embeddings"]) == 1
    np.testing.assert_allclose(stu1_match[0]["embeddings"][0], folder_vec)



