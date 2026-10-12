import os
import sys
import json
import pytest
import cv2
import numpy as np
from datetime import date
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool

# Ensure app path in pythonpath
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token
from app.models.user import User, Faculty, UserRole
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.student import Student
from app.models.attendance import ClassSession, FaceEmbedding, SessionStatus, AttendanceRecord, AttendanceStatus, RecognitionSource
from app.models.audit import AuditLog
from app.engines.recognition.base import RecognitionConfig
from app.engines.recognition.local_dlib import DlibFaceRecognitionEngine

# Isolated In-Memory Test Database setup for Milestone 3
TEST_SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
test_engine = create_engine(
    TEST_SQLALCHEMY_DATABASE_URL,
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

# Global test references
admin_id = None
fac_id = None
other_fac_id = None

@pytest.fixture(autouse=True)
def setup_test_database():
    global admin_id, fac_id, other_fac_id

    app.dependency_overrides[get_db] = override_get_db
    Base.metadata.create_all(bind=test_engine)
    db = TestingSessionLocal()

    # Seed Admin
    admin_user = User(username="admin_m3", email="admin_m3@test.com", hashed_password=get_password_hash("admin123"), role=UserRole.ADMIN)
    db.add(admin_user)

    # Seed Faculty
    fac_user = User(username="faculty_m3", email="faculty_m3@test.com", hashed_password=get_password_hash("fac123"), role=UserRole.FACULTY)
    db.add(fac_user)
    db.flush()

    admin_id = admin_user.id
    fac_id = fac_user.id

    faculty_profile = Faculty(user_id=fac_user.id, employee_id="EMP-M3", full_name="Dr. Test Faculty", department="CSE")
    db.add(faculty_profile)

    # Other Faculty (for session ownership isolation testing)
    other_user = User(username="other_fac", email="other@test.com", hashed_password=get_password_hash("fac123"), role=UserRole.FACULTY)
    db.add(other_user)
    db.flush()

    other_fac_id = other_user.id
    other_profile = Faculty(user_id=other_user.id, employee_id="EMP-OTHER", full_name="Dr. Other Faculty", department="IT")
    db.add(other_profile)

    # Academic Structure
    class_sec = ClassSection(name="CSE-3A", grade_level="Year 3", academic_year="2025-2026")
    db.add(class_sec)
    subj = Subject(code="CS301", name="Computer Networks")
    db.add(subj)
    period = Period(period_number=1, name="Period 1", start_time="09:00", end_time="10:00")
    db.add(period)
    db.flush()

    assignment = FacultyAssignment(faculty_id=faculty_profile.id, subject_id=subj.id, class_id=class_sec.id)
    db.add(assignment)
    db.flush()

    tt_entry = TimetableEntry(day_of_week="Monday", period_id=period.id, assignment_id=assignment.id)
    db.add(tt_entry)

    # Students
    st1 = Student(roll_number="101", full_name="Alex Johnson", class_id=class_sec.id, is_active=True)
    st2 = Student(roll_number="102", full_name="Sarah Williams", class_id=class_sec.id, is_active=True)
    st3 = Student(roll_number="103", full_name="Pugazh Arasu", class_id=class_sec.id, is_active=True)
    db.add_all([st1, st2, st3])
    db.flush()

    # Synthetic 128-d embeddings for students
    vec1 = np.ones(128, dtype=np.float64) * 0.1
    vec2 = np.ones(128, dtype=np.float64) * 0.5
    db.add(FaceEmbedding(student_id=st1.id, embedding_json=json.dumps(vec1.tolist()), image_path="test1.jpg"))
    db.add(FaceEmbedding(student_id=st2.id, embedding_json=json.dumps(vec2.tolist()), image_path="test2.jpg"))

    db.commit()
    db.close()

    yield

    Base.metadata.drop_all(bind=test_engine)
    app.dependency_overrides.clear()

def get_auth_headers(user_id_val: int, role: str = "FACULTY"):
    token = create_access_token(subject=str(user_id_val), role=role)
    return {"Authorization": f"Bearer {token}"}

# Helper to generate a dummy JPEG image buffer
def create_dummy_jpeg(width=200, height=200):
    img = np.zeros((height, width, 3), dtype=np.uint8)
    cv2.rectangle(img, (50, 50), (150, 150), (255, 255, 255), -1)
    _, buffer = cv2.imencode('.jpg', img)
    return buffer.tobytes()


# =========================================================
# 1. UNIT TESTS: Base & Dlib Recognition Engine Logic
# =========================================================

def test_recognition_engine_threshold_and_scoring():
    engine_inst = DlibFaceRecognitionEngine()
    config = RecognitionConfig(distance_threshold=0.45, uncertain_threshold=0.60)

    query_vec = np.ones(128, dtype=np.float64) * 0.1
    st1_vec = np.ones(128, dtype=np.float64) * 0.105 # Very close

    enrolled = [{
        "student_id": 1,
        "roll_number": "101",
        "full_name": "Alex",
        "embeddings": [st1_vec]
    }]

    dist = np.linalg.norm(query_vec - st1_vec)
    assert dist <= config.distance_threshold

def test_candidate_deduplication_in_engine():
    engine_inst = DlibFaceRecognitionEngine()
    vec1 = np.ones(128, dtype=np.float64) * 0.1
    enrolled = [{
        "student_id": 101,
        "roll_number": "101",
        "full_name": "Alex",
        "embeddings": [vec1]
    }]

    assert enrolled[0]["student_id"] == 101


# =========================================================
# 2. API TESTS: Admin Student Face Enrollment
# =========================================================

def test_admin_face_enrollment_rejects_non_admin():
    headers = get_auth_headers(fac_id, role="FACULTY")
    jpeg_bytes = create_dummy_jpeg()
    response = client.post(
        "/api/v1/admin/students/1/enroll-face",
        files={"file": ("test.jpg", jpeg_bytes, "image/jpeg")},
        headers=headers
    )
    assert response.status_code == 403 # Forbidden for non-admin

def test_admin_face_enrollment_invalid_file_type():
    headers = get_auth_headers(admin_id, role="ADMIN")
    response = client.post(
        "/api/v1/admin/students/1/enroll-face",
        files={"file": ("test.txt", b"not an image", "text/plain")},
        headers=headers
    )
    assert response.status_code == 400
    assert "Unsupported image file type" in response.json()["detail"]

def test_admin_face_enrollment_no_face_detected():
    headers = get_auth_headers(admin_id, role="ADMIN")
    # Black image has 0 faces
    img = np.zeros((100, 100, 3), dtype=np.uint8)
    _, buffer = cv2.imencode('.jpg', img)

    response = client.post(
        "/api/v1/admin/students/1/enroll-face",
        files={"file": ("test.jpg", buffer.tobytes(), "image/jpeg")},
        headers=headers
    )
    assert response.status_code == 400
    assert "No face detected" in response.json()["detail"]


# =========================================================
# 3. API TESTS: Faculty Group Photo & Live Camera Recognition
# =========================================================

def test_recognize_image_rejects_inactive_session():
    headers = get_auth_headers(fac_id, role="FACULTY")
    db = TestingSessionLocal()
    session = ClassSession(timetable_entry_id=1, faculty_id=1, date=date.today(), status=SessionStatus.SCHEDULED)
    db.add(session)
    db.commit()
    session_id = session.id
    db.close()

    jpeg_bytes = create_dummy_jpeg()
    response = client.post(
        f"/api/v1/faculty/sessions/{session_id}/recognize-image",
        files={"file": ("photo.jpg", jpeg_bytes, "image/jpeg")},
        headers=headers
    )
    assert response.status_code == 400
    assert "Session is not ACTIVE" in response.json()["detail"]

def test_recognize_image_session_ownership_isolation():
    headers_other = get_auth_headers(other_fac_id, role="FACULTY")
    db = TestingSessionLocal()
    session = ClassSession(timetable_entry_id=1, faculty_id=1, date=date.today(), status=SessionStatus.ACTIVE)
    db.add(session)
    db.commit()
    session_id = session.id
    db.close()

    jpeg_bytes = create_dummy_jpeg()
    response = client.post(
        f"/api/v1/faculty/sessions/{session_id}/recognize-image",
        files={"file": ("photo.jpg", jpeg_bytes, "image/jpeg")},
        headers=headers_other
    )
    assert response.status_code == 403
    assert "You do not own this class session" in response.json()["detail"]

def test_recognize_image_active_session_processing():
    headers = get_auth_headers(fac_id, role="FACULTY")
    db = TestingSessionLocal()
    session = ClassSession(timetable_entry_id=1, faculty_id=1, date=date.today(), status=SessionStatus.ACTIVE)
    db.add(session)
    db.commit()
    session_id = session.id
    db.close()

    jpeg_bytes = create_dummy_jpeg()
    response = client.post(
        f"/api/v1/faculty/sessions/{session_id}/recognize-image",
        files={"file": ("photo.jpg", jpeg_bytes, "image/jpeg")},
        headers=headers
    )
    assert response.status_code == 200
    res_data = response.json()
    assert res_data["success"] is True
    assert "faces_detected" in res_data
    assert "high_confidence_matches" in res_data
    assert "uncertain_matches" in res_data
    assert "unknown_faces" in res_data
    assert "results" in res_data


# =========================================================
# 4. API TESTS: Recognition Confirmation & Attendance Engine Integration
# =========================================================

def test_confirm_recognition_writes_attendance_records():
    headers = get_auth_headers(fac_id, role="FACULTY")
    db = TestingSessionLocal()
    session = ClassSession(timetable_entry_id=1, faculty_id=1, date=date.today(), status=SessionStatus.ACTIVE)
    db.add(session)
    db.commit()
    session_id = session.id
    db.close()

    payload = {
        "confirmed_candidates": [
            {"student_id": 1, "status": "PRESENT", "recognized_via": "GROUP_PHOTO"},
            {"student_id": 2, "status": "PRESENT", "recognized_via": "LIVE_CAMERA"}
        ]
    }

    response = client.post(
        f"/api/v1/faculty/sessions/{session_id}/confirm-recognition",
        json=payload,
        headers=headers
    )
    assert response.status_code == 200
    res_data = response.json()
    assert res_data["session_id"] == session_id
    assert len(res_data["records"]) == 2

    # Verify AttendanceRecord written to DB with correct recognized_via source
    db = TestingSessionLocal()
    records = db.query(AttendanceRecord).filter(AttendanceRecord.session_id == session_id).all()
    assert len(records) == 2
    rec1 = next(r for r in records if r.student_id == 1)
    assert rec1.status == AttendanceStatus.PRESENT
    assert rec1.recognized_via == RecognitionSource.GROUP_PHOTO

    # Verify AuditLog recorded for confirmation action
    audits = db.query(AuditLog).filter(AuditLog.action == "CONFIRM_FACIAL_RECOGNITION").all()
    assert len(audits) >= 1
    db.close()

def test_confirm_recognition_prevents_duplicate_records():
    headers = get_auth_headers(fac_id, role="FACULTY")
    db = TestingSessionLocal()
    session = ClassSession(timetable_entry_id=1, faculty_id=1, date=date.today(), status=SessionStatus.ACTIVE)
    db.add(session)
    db.commit()
    session_id = session.id
    db.close()

    payload = {
        "confirmed_candidates": [
            {"student_id": 1, "status": "PRESENT", "recognized_via": "GROUP_PHOTO"},
            {"student_id": 1, "status": "PRESENT", "recognized_via": "GROUP_PHOTO"}
        ]
    }

    response = client.post(
        f"/api/v1/faculty/sessions/{session_id}/confirm-recognition",
        json=payload,
        headers=headers
    )
    assert response.status_code == 200

    # Ensure DB deduplicates per session
    db = TestingSessionLocal()
    records = db.query(AttendanceRecord).filter(AttendanceRecord.session_id == session_id, AttendanceRecord.student_id == 1).all()
    assert len(records) == 1
    db.close()
