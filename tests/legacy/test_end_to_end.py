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
    # Minimal 1x1 JPEG byte sequence for image endpoints
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


def get_token_header(username_or_email: str, password: str, is_student: bool = False) -> dict:
    endpoint = "/api/v1/auth/student/login" if is_student else "/api/v1/auth/login"
    payload = {"identifier": username_or_email, "password": password} if is_student else {"username_or_email": username_or_email, "password": password}

    res = client.post(endpoint, json=payload)
    assert res.status_code == 200, f"Login failed for {username_or_email}: {res.text}"
    token = res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


class TestEndToEndAttendanceWorkflow:

    def test_complete_end_to_end_attendance_product_workflow(self, setup_db: Session):
        db = setup_db

        # =========================================================================
        # 1. ADMIN CONFIGURATION
        # =========================================================================

        # Ensure Admin User
        admin_user = db.query(User).filter(User.username == "admin_e2e").first()
        if not admin_user:
            admin_user = User(
                username="admin_e2e",
                email="admin_e2e@college.edu",
                hashed_password=get_password_hash("admin123"),
                role=UserRole.ADMIN,
                is_active=True
            )
            db.add(admin_user)
            db.commit()

        admin_headers = get_token_header("admin_e2e", "admin123")

        # Admin creates Class Section
        res_class = client.post("/api/v1/admin/classes", json={"name": "E2E CSE Class 1", "grade_level": "II Year", "academic_year": "2026-2027"}, headers=admin_headers)
        assert res_class.status_code == 201
        class_id = res_class.json()["id"]

        # Admin creates Subject
        res_sub = client.post("/api/v1/admin/subjects", json={"code": "E2E101", "name": "End To End Testing Subject"}, headers=admin_headers)
        assert res_sub.status_code == 201
        subject_id = res_sub.json()["id"]

        # Admin creates Faculty
        res_fac = client.post("/api/v1/admin/faculty", json={
            "employee_id": "FAC_E2E_001",
            "full_name": "Prof. End To End",
            "department": "Computer Science",
            "username": "fac_e2e_001",
            "email": "fac_e2e_001@college.edu",
            "password": "faculty123"
        }, headers=admin_headers)
        assert res_fac.status_code == 201
        faculty_profile_id = res_fac.json()["id"]

        # Admin creates Period 91 (09:10-10:00)
        res_p = client.post("/api/v1/admin/periods", json={"period_number": 91, "name": "Period 91", "start_time": "09:10", "end_time": "10:00"}, headers=admin_headers)
        assert res_p.status_code == 201
        period_id = res_p.json()["id"]

        # Admin assigns Faculty to Subject & Class
        res_assign = client.post("/api/v1/admin/assignments", json={"class_id": class_id, "subject_id": subject_id, "faculty_id": faculty_profile_id}, headers=admin_headers)
        assert res_assign.status_code == 201
        assignment_id = res_assign.json()["id"]

        # Determine Today's Day of Week
        today_day = datetime.now(timezone.utc).strftime("%A")

        # Admin creates Timetable Entry
        res_tt = client.post("/api/v1/admin/timetable", json={"assignment_id": assignment_id, "period_id": period_id, "day_of_week": today_day}, headers=admin_headers)
        assert res_tt.status_code == 201
        timetable_entry_id = res_tt.json()["id"]

        # Admin creates Student with Account
        res_stu = client.post("/api/v1/admin/students/with-account", json={
            "roll_number": "STU_E2E_001",
            "full_name": "Student E2E Verified",
            "email": "stu_e2e_001@college.edu",
            "class_id": class_id,
            "password": "student123"
        }, headers=admin_headers)
        assert res_stu.status_code == 201
        student_id = res_stu.json()["id"]

        # =========================================================================
        # 2. FACULTY WORKFLOW
        # =========================================================================

        faculty_headers = get_token_header("fac_e2e_001", "faculty123")

        # Faculty checks personalized timetable
        res_fac_tt = client.get("/api/v1/faculty/timetable", headers=faculty_headers)
        assert res_fac_tt.status_code == 200

        # Faculty starts session
        res_start = client.post("/api/v1/faculty/sessions/start", json={"timetable_entry_id": timetable_entry_id}, headers=faculty_headers)
        assert res_start.status_code in [200, 201]
        session_id = res_start.json()["session_id"]
        assert res_start.json()["status"] in ["ACTIVE", "SCHEDULED"]

        # Faculty retrieves class session details and roster
        res_sess_info = client.get(f"/api/v1/faculty/sessions/{session_id}", headers=faculty_headers)
        assert res_sess_info.status_code == 200
        roster = res_sess_info.json().get("roster", [])
        assert any(r["id"] == student_id for r in roster)

        # =========================================================================
        # 3. RECOGNITION WORKFLOW
        # =========================================================================

        jpeg_bytes = create_dummy_jpeg()
        res_recog = client.post(
            f"/api/v1/faculty/sessions/{session_id}/recognize-image",
            files={"file": ("classroom_photo.jpg", jpeg_bytes, "image/jpeg")},
            headers=faculty_headers
        )
        assert res_recog.status_code == 200
        recog_data = res_recog.json()
        assert recog_data["success"] is True
        assert "faces_detected" in recog_data
        assert "high_confidence_matches" in recog_data

        # Confirm Attendance for Student
        confirm_payload = {
            "confirmed_candidates": [
                {"student_id": student_id, "status": "PRESENT", "recognized_via": "GROUP_PHOTO"}
            ]
        }
        res_confirm = client.post(f"/api/v1/faculty/sessions/{session_id}/confirm-recognition", json=confirm_payload, headers=faculty_headers)
        assert res_confirm.status_code == 200
        confirm_data = res_confirm.json()
        assert confirm_data["session_id"] == session_id
        assert len(confirm_data["records"]) == 1

        # =========================================================================
        # 4. ATTENDANCE VERIFICATION & SESSION COMPLETION
        # =========================================================================

        # Verify record in DB
        db_rec = db.query(AttendanceRecord).filter(AttendanceRecord.session_id == session_id, AttendanceRecord.student_id == student_id).first()
        assert db_rec is not None
        assert db_rec.status == AttendanceStatus.PRESENT
        assert db_rec.recognized_via == RecognitionSource.GROUP_PHOTO

        # Verify duplicate confirmation does NOT create duplicate records
        res_confirm_dup = client.post(f"/api/v1/faculty/sessions/{session_id}/confirm-recognition", json=confirm_payload, headers=faculty_headers)
        assert res_confirm_dup.status_code == 200
        total_records_count = db.query(AttendanceRecord).filter(AttendanceRecord.session_id == session_id, AttendanceRecord.student_id == student_id).count()
        assert total_records_count == 1

        # Complete Session
        res_complete = client.post(f"/api/v1/faculty/sessions/{session_id}/complete", headers=faculty_headers)
        assert res_complete.status_code == 200
        assert res_complete.json()["status"] == "COMPLETED"

        # Verify modification after completion is rejected
        res_mod_after_comp = client.post(f"/api/v1/faculty/sessions/{session_id}/confirm-recognition", json=confirm_payload, headers=faculty_headers)
        assert res_mod_after_comp.status_code in [400, 403]

        # =========================================================================
        # 5. STUDENT ATTENDANCE VERIFICATION
        # =========================================================================

        student_headers = get_token_header("STU_E2E_001", "student123", is_student=True)

        # Call /student/me
        res_stu_me = client.get("/api/v1/student/me", headers=student_headers)
        assert res_stu_me.status_code == 200
        stu_me_data = res_stu_me.json()
        assert stu_me_data["roll_number"] == "STU_E2E_001"
        assert "overall_percentage" in stu_me_data

        # Call /student/attendance
        res_stu_att = client.get("/api/v1/student/attendance", headers=student_headers)
        assert res_stu_att.status_code == 200
        stu_att_data = res_stu_att.json()
        assert stu_att_data["student_id"] == student_id
        assert stu_att_data["overall_percentage"] == 100.0
        assert "minimum_required_percentage" in stu_att_data
        assert "required_classes_to_attend" in stu_att_data
        assert "missable_classes" in stu_att_data

        # Call /student/attendance/subjects
        res_stu_sub = client.get("/api/v1/student/attendance/subjects", headers=student_headers)
        assert res_stu_sub.status_code == 200
        sub_list = res_stu_sub.json()
        assert len(sub_list) >= 1
        e2e_sub_row = next((s for s in sub_list if s["subject_code"] == "E2E101"), None)
        assert e2e_sub_row is not None
        assert e2e_sub_row["percentage"] == 100.0

        # =========================================================================
        # 6. SECURITY ISOLATION VERIFICATION
        # =========================================================================

        # Student cannot call Faculty endpoint -> 403
        res_sec1 = client.post("/api/v1/faculty/sessions/start", json={"timetable_entry_id": timetable_entry_id}, headers=student_headers)
        assert res_sec1.status_code == 403

        # Student cannot call Admin endpoint -> 403
        res_sec2 = client.get("/api/v1/admin/dashboard-stats", headers=student_headers)
        assert res_sec2.status_code == 403

        # Faculty cannot access session of another faculty -> 403
        # Create second faculty
        res_fac2 = client.post("/api/v1/admin/faculty", json={
            "employee_id": "FAC_E2E_002",
            "full_name": "Prof. Other",
            "department": "CS",
            "username": "fac_e2e_002",
            "email": "fac_e2e_002@college.edu",
            "password": "faculty123"
        }, headers=admin_headers)
        assert res_fac2.status_code == 201

        fac2_headers = get_token_header("fac_e2e_002", "faculty123")
        res_sec3 = client.get(f"/api/v1/faculty/sessions/{session_id}", headers=fac2_headers)
        assert res_sec3.status_code == 403

        # Unauthorized web request to /admin -> 303 Redirect
        res_sec4 = client.get("/admin", follow_redirects=False)
        assert res_sec4.status_code in [302, 303, 307]
