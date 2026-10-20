import pytest
from datetime import date, datetime, timezone
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.core.database import SessionLocal, Base, engine
from app.core.security import get_password_hash
from app.models.user import User, UserRole, Faculty
from app.models.student import Student
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.attendance import ClassSession, AttendanceRecord, SessionStatus, AttendanceStatus, RecognitionSource
from app.services.college_importer import reset_demo_academic_configuration

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        reset_demo_academic_configuration(db)
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()

    session = SessionLocal()
    try:
        yield session
    finally:
        session.rollback()
        session.close()


def create_dummy_jpeg() -> bytes:
    return (
        b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00"
        b"\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t"
        b"\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f"
        b"\x1e\x1d\x1a\x1c\x1c $.' \",#\x1c\x1c(7),01444\x1f'9=82<.342"
        b"\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4"
        b"\x00\x1f\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00"
        b"\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b"
        b"\xff\xda\x00\x08\x01\x01\x00\x00?\x00\xbf\x00\xff\xd9"
    )


def get_token_header(username_or_email: str, password: str) -> dict:
    res = client.post("/api/v1/auth/login", json={"username_or_email": username_or_email, "password": password})
    assert res.status_code == 200
    token = res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


class TestClassroomRecognitionIntegration:

    def test_enrollment_validation_and_invalid_image_rejection(self, setup_db: Session):
        db = setup_db
        # Admin setup
        admin = User(username="admin_class_bench", email="admin_class_bench@test.com", hashed_password=get_password_hash("admin123"), role=UserRole.ADMIN, is_active=True)
        db.add(admin)
        db.commit()

        admin_headers = get_token_header("admin_class_bench", "admin123")

        # Create Student
        stu_res = client.post("/api/v1/admin/students/with-account", json={
            "roll_number": "STU_BENCH_001",
            "full_name": "Bench Student",
            "email": "bench_stu001@test.com",
            "password": "student123"
        }, headers=admin_headers)
        assert stu_res.status_code == 201
        student_id = stu_res.json()["id"]

        # Invalid file type rejection
        res_invalid_type = client.post(
            f"/api/v1/admin/enrollment/student/{student_id}",
            files={"file": ("test.txt", b"not an image file content", "text/plain")},
            headers=admin_headers
        )
        assert res_invalid_type.status_code == 400
        assert "Invalid file type" in res_invalid_type.json()["detail"]

        # Faceless image rejection
        jpeg_bytes = create_dummy_jpeg()
        res_faceless = client.post(
            f"/api/v1/admin/enrollment/student/{student_id}",
            files={"file": ("faceless.jpg", jpeg_bytes, "image/jpeg")},
            headers=admin_headers
        )
        assert res_faceless.status_code == 400
        assert "No face detected" in res_faceless.json()["detail"] or "face" in res_faceless.json()["detail"].lower()

    def test_group_photo_recognition_review_and_attendance_records(self, setup_db: Session):
        db = setup_db

        # Create Admin
        admin = User(username="admin_class_bench2", email="admin_class_bench2@test.com", hashed_password=get_password_hash("admin123"), role=UserRole.ADMIN, is_active=True)
        db.add(admin)
        db.commit()

        admin_headers = get_token_header("admin_class_bench2", "admin123")

        # Create Class, Subject, Faculty, Period, Assignment, Timetable
        c_res = client.post("/api/v1/admin/classes", json={"name": "Bench Class 1", "grade_level": "II Year", "academic_year": "2026-2027"}, headers=admin_headers)
        sub_res = client.post("/api/v1/admin/subjects", json={"code": "BENCH101", "name": "Bench Subject"}, headers=admin_headers)
        fac_res = client.post("/api/v1/admin/faculty", json={
            "employee_id": "FAC_BENCH_001",
            "full_name": "Prof. Bench",
            "username": "fac_bench_001",
            "email": "fac_bench_001@test.com",
            "password": "faculty123"
        }, headers=admin_headers)
        p_res = client.post("/api/v1/admin/periods", json={"period_number": 95, "name": "P95", "start_time": "14:30", "end_time": "15:20"}, headers=admin_headers)

        class_id = c_res.json()["id"]
        sub_id = sub_res.json()["id"]
        fac_profile_id = fac_res.json()["id"]
        p_id = p_res.json()["id"]

        as_res = client.post("/api/v1/admin/assignments", json={"class_id": class_id, "subject_id": sub_id, "faculty_id": fac_profile_id}, headers=admin_headers)
        assign_id = as_res.json()["id"]

        today_day = datetime.now(timezone.utc).strftime("%A")
        tt_res = client.post("/api/v1/admin/timetable", json={"assignment_id": assign_id, "period_id": p_id, "day_of_week": today_day}, headers=admin_headers)
        tt_id = tt_res.json()["id"]

        # Create Student
        stu_res = client.post("/api/v1/admin/students/with-account", json={
            "roll_number": "STU_BENCH_002",
            "full_name": "Bench Student Two",
            "email": "bench_stu002@test.com",
            "class_id": class_id,
            "password": "student123"
        }, headers=admin_headers)
        student_id = stu_res.json()["id"]

        # Faculty workflow
        fac_headers = get_token_header("fac_bench_001", "faculty123")
        start_res = client.post("/api/v1/faculty/sessions/start", json={"timetable_entry_id": tt_id}, headers=fac_headers)
        session_id = start_res.json()["session_id"]

        # Group Photo Recognition
        jpeg_bytes = create_dummy_jpeg()
        recog_res = client.post(
            f"/api/v1/faculty/sessions/{session_id}/recognize-image",
            files={"file": ("group_photo.jpg", jpeg_bytes, "image/jpeg")},
            headers=fac_headers
        )
        assert recog_res.status_code == 200
        recog_data = recog_res.json()
        assert recog_data["success"] is True
        assert "faces_detected" in recog_data

        # Confirm Attendance with GROUP_PHOTO recognition source
        confirm_payload = {
            "confirmed_candidates": [
                {"student_id": student_id, "status": "PRESENT", "recognized_via": "GROUP_PHOTO"}
            ]
        }
        confirm_res = client.post(f"/api/v1/faculty/sessions/{session_id}/confirm-recognition", json=confirm_payload, headers=fac_headers)
        assert confirm_res.status_code == 200

        # Verify Record created in DB
        db_rec = db.query(AttendanceRecord).filter(AttendanceRecord.session_id == session_id, AttendanceRecord.student_id == student_id).first()
        assert db_rec is not None
        assert db_rec.status == AttendanceStatus.PRESENT
        assert db_rec.recognized_via == RecognitionSource.GROUP_PHOTO

        # Duplicate confirmation prevention
        confirm_res_dup = client.post(f"/api/v1/faculty/sessions/{session_id}/confirm-recognition", json=confirm_payload, headers=fac_headers)
        assert confirm_res_dup.status_code == 200
        rec_count = db.query(AttendanceRecord).filter(AttendanceRecord.session_id == session_id, AttendanceRecord.student_id == student_id).count()
        assert rec_count == 1

        # Session completion & modification lockdown
        comp_res = client.post(f"/api/v1/faculty/sessions/{session_id}/complete", headers=fac_headers)
        assert comp_res.status_code == 200

        mod_res = client.post(f"/api/v1/faculty/sessions/{session_id}/confirm-recognition", json=confirm_payload, headers=fac_headers)
        assert mod_res.status_code in [400, 403]
