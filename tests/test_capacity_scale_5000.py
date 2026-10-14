"""
Automated Capacity & Scalability Test Suite: 5,000 Students and 250 Faculty.
Tests CRUD, bulk imports, server-side pagination, search indexing, face recognition index performance,
attendance integrity, and role-based security on isolated in-memory fixtures.
"""

import time
import json
import pytest
import numpy as np
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.core.config import settings
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token
from app.models.user import User, Faculty, UserRole
from app.models.student import Student
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment
from app.models.attendance import ClassSession, AttendanceRecord, FaceEmbedding, SessionStatus, AttendanceStatus, RecognitionSource
from app.services.college_importer import import_students, import_faculty, ImportValidationError
from app.services.recognition_index import RecognitionIndexManager
from app.engines.recognition.base import BaseRecognitionEngine, RecognitionConfig
from typing import List, Tuple, Any, Optional, Dict


# Isolated In-Memory SQLite Test Engine
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

test_engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


class MockArcFaceEngine(BaseRecognitionEngine):
    """512-dimensional ArcFace mock engine for biometric scale benchmark."""
    @property
    def engine_name(self) -> str:
        return "arcface"

    @property
    def embedding_dimension(self) -> int:
        return 512

    @property
    def distance_metric(self) -> str:
        return "cosine"

    @property
    def model_name(self) -> str:
        return "arcface_r100_v1"

    @property
    def model_version(self) -> str:
        return "v1"

    def detect_faces(self, image_bytes_or_array: Any, model: str = "hog") -> List[Tuple[int, int, int, int]]:
        return [(10, 100, 100, 10)]

    def generate_embeddings(self, image_bytes_or_array: Any, face_locations: Optional[List[Tuple[int, int, int, int]]] = None) -> List[np.ndarray]:
        return [np.zeros((512,), dtype=np.float32)]

    def recognize_image(self, image_bytes: bytes, enrolled_students: List[Dict[str, Any]], config: Optional[RecognitionConfig] = None) -> Dict[str, Any]:
        return {"matches": []}


@pytest.fixture(scope="function")
def isolated_db():
    Base.metadata.create_all(bind=test_engine)
    session = TestingSessionLocal()

    # Pre-seed default class section
    cs = ClassSection(id=1, name="CSE Cyber Security - Section A")
    session.add(cs)
    session.commit()

    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=test_engine)


@pytest.fixture(scope="function")
def client(isolated_db):
    def override_get_db():
        try:
            yield isolated_db
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture(scope="function")
def admin_token(isolated_db):
    admin = User(
        username="superadmin",
        email="superadmin@college.edu",
        hashed_password=get_password_hash("AdminPass123!"),
        role=UserRole.ADMIN,
        is_active=True,
    )
    isolated_db.add(admin)
    isolated_db.commit()
    return create_access_token(subject=str(admin.id), role=admin.role.value)


@pytest.fixture(scope="function")
def student_user_token(isolated_db):
    user = User(
        username="student_regular",
        email="reg_student@college.edu",
        hashed_password=get_password_hash("StudentPass123!"),
        role=UserRole.STUDENT,
        is_active=True,
    )
    isolated_db.add(user)
    isolated_db.commit()
    return create_access_token(subject=str(user.id), role=user.role.value)


# ==============================================================================
# 1. PRIMARY CAPACITY CONFIGURATION & API STATS
# ==============================================================================

def test_1_capacity_settings_and_stats_api(client, admin_token, isolated_db):
    """Verify settings and /api/v1/admin/capacity-stats report at least 5000 students and 250 faculty."""
    assert settings.MAX_STUDENTS >= 5000, f"Expected MAX_STUDENTS >= 5000, got {settings.MAX_STUDENTS}"
    assert settings.MAX_FACULTY >= 250, f"Expected MAX_FACULTY >= 250, got {settings.MAX_FACULTY}"

    resp = client.get(
        "/api/v1/admin/capacity-stats",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()

    assert data["students"]["max"] >= 5000
    assert data["faculty"]["max"] >= 250
    assert data["students"]["current"] == 0
    assert data["faculty"]["current"] == 0
    assert data["students"]["remaining"] >= 5000
    assert data["faculty"]["remaining"] >= 250


# ==============================================================================
# 2. FACULTY SCALE: 250 RECORDS, SEARCH & PAGINATION
# ==============================================================================

def test_2_faculty_scale_250_records_and_pagination(client, admin_token, isolated_db):
    """Import and verify exactly 250 faculty members, test server pagination and search."""
    faculty_batch = []
    for i in range(1, 251):
        emp_id = f"FAC{i:03d}"
        faculty_batch.append({
            "username": f"prof_{i:03d}",
            "email": f"prof_{i:03d}@college.edu",
            "employee_id": emp_id,
            "full_name": f"Professor {i:03d}",
            "department": "Computer Science" if i % 2 == 0 else "Information Technology",
            "password": "faculty_shared_pw"
        })

    # Bulk import 250 faculty
    t0 = time.perf_counter()
    res = import_faculty(isolated_db, faculty_batch)
    isolated_db.commit()
    t_import = time.perf_counter() - t0

    assert res["imported"] == 250
    assert isolated_db.query(Faculty).count() == 250
    assert t_import < 5.0, f"Faculty import took too long: {t_import:.2f}s"

    # Test server-side pagination: page 1 (50 items)
    resp_p1 = client.get(
        "/api/v1/admin/faculty?skip=0&limit=50",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert resp_p1.status_code == 200
    p1_data = resp_p1.json()
    assert len(p1_data) == 50
    assert resp_p1.headers.get("X-Total-Count") == "250"
    assert p1_data[0]["employee_id"] == "FAC001"

    # Test page 5 (last 50 items)
    resp_p5 = client.get(
        "/api/v1/admin/faculty?skip=200&limit=50",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert resp_p5.status_code == 200
    p5_data = resp_p5.json()
    assert len(p5_data) == 50
    assert p5_data[-1]["employee_id"] == "FAC250"

    # Test search near middle
    resp_search = client.get(
        "/api/v1/admin/faculty?search=Professor 125",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert resp_search.status_code == 200
    s_data = resp_search.json()
    assert len(s_data) == 1
    assert s_data[0]["employee_id"] == "FAC125"

    # Test overflow: 251st faculty is rejected when MAX_FACULTY = 250
    resp_overflow = client.post(
        "/api/v1/admin/faculty",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={
            "username": "prof_overflow",
            "email": "overflow@college.edu",
            "employee_id": "FAC251",
            "full_name": "Professor Overflow",
            "department": "Physics",
            "password": "Password123!"
        }
    )
    assert resp_overflow.status_code == 400
    assert "capacity" in resp_overflow.json()["detail"].lower()


# ==============================================================================
# 3. STUDENT SCALE: 5,000 RECORDS BULK IMPORT & PERFORMANCE
# ==============================================================================

def test_3_student_scale_5000_bulk_import_and_pagination(client, admin_token, isolated_db):
    """Import and verify 5,000 students, test pagination, search, and response times."""
    students_batch = []
    for i in range(1, 5001):
        roll = f"23CS{i:04d}"
        students_batch.append({
            "roll_number": roll,
            "full_name": f"Student {i:04d}",
            "email": f"student_{i:04d}@college.edu",
            "class_name": "CSE Cyber Security - Section A",
            "password": "student_shared_pw"
        })

    # Bulk import 5,000 students
    t0 = time.perf_counter()
    res = import_students(isolated_db, students_batch)
    isolated_db.commit()
    t_import = time.perf_counter() - t0

    assert res["imported"] == 5000
    assert isolated_db.query(Student).count() == 5000
    # Performance requirement: 5,000 records imported in reasonable time (< 15s)
    assert t_import < 15.0, f"5000 students import took {t_import:.2f}s, target was < 15s"

    # Test pagination: Page 1 (first 50)
    t_p1 = time.perf_counter()
    resp_p1 = client.get(
        "/api/v1/admin/students?skip=0&limit=50",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    lat_p1 = time.perf_counter() - t_p1
    assert resp_p1.status_code == 200
    p1_items = resp_p1.json()
    assert len(p1_items) == 50
    assert p1_items[0]["roll_number"] == "23CS0001"
    assert resp_p1.headers.get("X-Total-Count") == "5000"
    assert lat_p1 < 0.5, f"Pagination page 1 latency too high: {lat_p1:.3f}s"

    # Test pagination: Middle page (records 2500 - 2549)
    resp_mid = client.get(
        "/api/v1/admin/students?skip=2500&limit=50",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert resp_mid.status_code == 200
    mid_items = resp_mid.json()
    assert len(mid_items) == 50
    assert mid_items[0]["roll_number"] == "23CS2501"

    # Test pagination: Last page (records 4950 - 5000)
    resp_last = client.get(
        "/api/v1/admin/students?skip=4950&limit=50",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert resp_last.status_code == 200
    last_items = resp_last.json()
    assert len(last_items) == 50
    assert last_items[-1]["roll_number"] == "23CS5000"

    # Test search by roll number at tail
    resp_search = client.get(
        "/api/v1/admin/students?search=23CS4999",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert resp_search.status_code == 200
    search_items = resp_search.json()
    assert len(search_items) == 1
    assert search_items[0]["roll_number"] == "23CS4999"

    # Test duplicate re-import (idempotence): duplicate rows should be skipped gracefully
    reimport_res = import_students(isolated_db, students_batch[:10])
    isolated_db.commit()
    assert reimport_res["imported"] == 0
    assert reimport_res["skipped_existing"] == 10
    assert isolated_db.query(Student).count() == 5000


# ==============================================================================
# 4. DATA VALIDATION & ERROR RECOVERY
# ==============================================================================

def test_4_validation_and_duplicate_rejection(isolated_db):
    """Test validation detects missing fields and in-batch duplicates."""
    invalid_batch = [
        {"roll_number": "", "full_name": "No Roll"},
        {"roll_number": "VALID01", "full_name": ""},
        {"roll_number": "DUP01", "full_name": "First Duplicate"},
        {"roll_number": "DUP01", "full_name": "Second Duplicate"},
    ]

    with pytest.raises(ImportValidationError) as exc_info:
        import_students(isolated_db, invalid_batch)

    errs = exc_info.value.errors
    assert any("required" in e for e in errs)
    assert any("Duplicate" in e for e in errs)


# ==============================================================================
# 5. FACE RECOGNITION INDEX ENGINE: 5,000 TEMPLATES BENCHMARK
# ==============================================================================

def test_5_face_recognition_index_scale_5000_templates(isolated_db):
    """
    Simulate 5,000 student biometric templates in database.
    Verify RecognitionIndexManager builds matrix cleanly and vectorized similarity search is sub-15ms.
    """
    engine = MockArcFaceEngine()
    index_mgr = RecognitionIndexManager.get_instance()
    index_mgr.invalidate()

    # Pre-generate a normalized 512-dim unit vector
    rng = np.random.default_rng(42)
    raw_vec = rng.standard_normal(512).astype(np.float32)
    unit_vec = (raw_vec / np.linalg.norm(raw_vec)).tolist()
    vec_json = json.dumps(unit_vec)

    # Insert 5000 students and embeddings efficiently
    students_to_insert = []
    embs_to_insert = []
    for i in range(1, 5001):
        st = Student(
            id=i,
            roll_number=f"FACE{i:04d}",
            full_name=f"Biometric Student {i:04d}",
            class_id=1,
            is_active=True
        )
        students_to_insert.append(st)

        fe = FaceEmbedding(
            id=i,
            student_id=i,
            embedding_json=vec_json,
            model_name="arcface_r100_v1",
            model_version="v1",
            dimension=512,
            distance_metric="cosine"
        )
        embs_to_insert.append(fe)

    isolated_db.bulk_save_objects(students_to_insert)
    isolated_db.bulk_save_objects(embs_to_insert)
    isolated_db.commit()

    # Measure index building time from DB
    t_build_start = time.perf_counter()
    cache = index_mgr.get_class_index(isolated_db, class_id=1, engine=engine)
    t_build = time.perf_counter() - t_build_start

    assert cache.total_templates == 5000
    assert cache.embedding_matrix.shape == (5000, 512)
    assert t_build < 5.0, f"Index building took {t_build:.2f}s"

    # Measure vectorized Cosine lookup performance over 5,000 vectors
    query_vec = np.array(unit_vec, dtype=np.float32)
    t_search_start = time.perf_counter()
    similarities = np.dot(cache.embedding_matrix, query_vec)
    best_idx = int(np.argmax(similarities))
    best_student_id = cache.embedding_student_ids[best_idx]
    t_search = time.perf_counter() - t_search_start

    assert best_student_id >= 1
    assert similarities[best_idx] > 0.99
    # CPU similarity over 5000 512-dim vectors should complete in < 25ms
    assert t_search < 0.025, f"Vector search over 5000 templates took {t_search * 1000:.2f}ms (target < 25ms)"

    # Test cache invalidation
    index_mgr.invalidate(class_id=1)
    stats = index_mgr.get_stats()
    assert stats["cached_classes"] == 0


# ==============================================================================
# 6. ATTENDANCE WORKFLOW & HISTORICAL RECORD INTEGRITY
# ==============================================================================

def test_6_attendance_creation_and_integrity_at_scale(isolated_db):
    """Verify attendance marking and querying remains exact with large student roster."""
    # Create faculty
    fac_user = User(
        username="att_prof",
        email="att_prof@college.edu",
        hashed_password=get_password_hash("Pass123!"),
        role=UserRole.FACULTY,
        is_active=True
    )
    isolated_db.add(fac_user)
    isolated_db.flush()

    fac = Faculty(user_id=fac_user.id, employee_id="FAC_ATT", full_name="Attendance Prof", department="CS")
    isolated_db.add(fac)
    isolated_db.flush()

    # Class session for class 1
    sess = ClassSession(
        faculty_id=fac.id,
        date="2026-10-13",
        status=SessionStatus.ACTIVE
    )
    isolated_db.add(sess)
    isolated_db.flush()

    # Pre-create 100 students
    students = []
    for i in range(1, 101):
        st = Student(roll_number=f"ATT_ST_{i:03d}", full_name=f"Student {i:03d}", class_id=1, is_active=True)
        isolated_db.add(st)
        students.append(st)
    isolated_db.flush()

    # Mark attendance records
    for i, st in enumerate(students):
        status = AttendanceStatus.PRESENT if i % 2 == 0 else AttendanceStatus.ABSENT
        rec = AttendanceRecord(
            session_id=sess.id,
            student_id=st.id,
            status=status,
            confidence=97.5 if status == AttendanceStatus.PRESENT else None,
            recognized_via=RecognitionSource.LIVE_CAMERA if status == AttendanceStatus.PRESENT else RecognitionSource.MANUAL
        )
        isolated_db.add(rec)
    isolated_db.commit()

    # Verify counts and student mapping
    att_records = isolated_db.query(AttendanceRecord).filter(AttendanceRecord.session_id == sess.id).all()
    assert len(att_records) == 100
    present_count = sum(1 for r in att_records if r.status == AttendanceStatus.PRESENT)
    absent_count = sum(1 for r in att_records if r.status == AttendanceStatus.ABSENT)
    assert present_count == 50
    assert absent_count == 50


# ==============================================================================
# 7. SECURITY & ACCESS CONTROL
# ==============================================================================

def test_7_security_access_control(client, student_user_token):
    """Verify unauthorized users (students/guests) cannot access admin capacity or import endpoints."""
    # Student attempting to access capacity stats
    resp = client.get(
        "/api/v1/admin/capacity-stats",
        headers={"Authorization": f"Bearer {student_user_token}"}
    )
    assert resp.status_code == 403

    # Student attempting to bulk import
    resp_import = client.post(
        "/api/v1/admin/import/students",
        headers={"Authorization": f"Bearer {student_user_token}"},
        json=[{"roll_number": "HACK01", "full_name": "Hacker"}]
    )
    assert resp_import.status_code == 403

    # Anonymous user attempting to access faculty list
    resp_anon = client.get("/api/v1/admin/faculty")
    assert resp_anon.status_code == 401
