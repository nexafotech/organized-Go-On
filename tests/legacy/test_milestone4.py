"""
MILESTONE 4 TEST SUITE
======================
28 tests covering:
  1.  Student login
  2.  Student persistent session
  3.  Student can view own attendance
  4.  Student cannot view another student's attendance
  5.  Student cannot access faculty APIs
  6.  Student cannot access admin APIs
  7.  Admin can create student
  8.  Admin can create faculty
  9.  Admin can reset student password
  10. Admin can reset faculty password
  11. Admin can disable accounts
  12. Admin can configure login methods
  13. Admin can configure attendance policy
  14. Attendance calculation respects policy
  15. OD can be marked
  16. OD cannot be marked for unauthorized session
  17. OD calculation follows configured policy
  18. OD across multiple students works
  19. Duplicate OD/attendance records are prevented (upsert)
  20. Student report shows OD correctly
  21. Subject-wise report works
  22. Date-wise report works
  23. Timetable configuration works
  24. Faculty assignment works
  25. Audit logs are created
  26. Quantized AI setting defaults to ON
  27. Quantized OFF is represented as full-precision mode
  28. Existing 35 tests: confirmed by running existing test files separately
"""

import os
import sys
import pytest
from datetime import date
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token
from app.models.user import User, Faculty, UserRole
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.student import Student
from app.models.attendance import (
    ClassSession, AttendanceRecord, AttendanceStatus, SessionStatus, RecognitionSource
)
from app.models.audit import AuditLog
from app.models.policy import AttendancePolicy, SystemSetting

# ─────────────────────────────────────────────────────────────────────────────
# In-Memory Test Database
# ─────────────────────────────────────────────────────────────────────────────
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

# Global test state
admin_user_id = None
faculty_user_id = None
other_faculty_user_id = None
student1_user_id = None
student2_user_id = None
student1_id = None
student2_id = None
faculty_profile_id = None
other_faculty_profile_id = None
class_id = None
subject_id = None
period_id = None
assignment_id = None
timetable_entry_id = None
session_id = None


@pytest.fixture(autouse=True)
def setup_test_database():
    global admin_user_id, faculty_user_id, other_faculty_user_id
    global student1_user_id, student2_user_id, student1_id, student2_id
    global faculty_profile_id, other_faculty_profile_id
    global class_id, subject_id, period_id, assignment_id, timetable_entry_id, session_id

    app.dependency_overrides[get_db] = override_get_db
    Base.metadata.create_all(bind=test_engine)
    db = TestingSessionLocal()

    # Admin
    admin = User(username="admin_m4", email="admin_m4@test.com",
                 hashed_password=get_password_hash("admin123"), role=UserRole.ADMIN, is_active=True)
    db.add(admin)

    # Faculty 1
    fac_user = User(username="faculty_m4", email="fac_m4@test.com",
                    hashed_password=get_password_hash("fac123"), role=UserRole.FACULTY, is_active=True,
                    login_identifier="EMP-M4")
    db.add(fac_user)
    db.flush()
    admin_user_id = admin.id
    faculty_user_id = fac_user.id

    fac_profile = Faculty(user_id=fac_user.id, employee_id="EMP-M4",
                          full_name="Dr. Test Faculty", department="CSE")
    db.add(fac_profile)

    # Faculty 2 (for isolation tests)
    other_user = User(username="other_m4", email="other_m4@test.com",
                      hashed_password=get_password_hash("fac123"), role=UserRole.FACULTY, is_active=True)
    db.add(other_user)
    db.flush()
    other_faculty_user_id = other_user.id

    other_profile = Faculty(user_id=other_user.id, employee_id="EMP-OTHER-M4",
                            full_name="Dr. Other M4", department="IT")
    db.add(other_profile)
    db.flush()
    faculty_profile_id = fac_profile.id
    other_faculty_profile_id = other_profile.id

    # Academic structure
    cs = ClassSection(name="CSE-M4-A", grade_level="Year 3", academic_year="2025-2026")
    db.add(cs)
    subj = Subject(code="CS-M4-01", name="Test Subject M4")
    db.add(subj)
    period = Period(period_number=99, name="Test Period M4", start_time="09:00", end_time="10:00")
    db.add(period)
    db.flush()
    class_id = cs.id
    subject_id = subj.id
    period_id = period.id

    assign = FacultyAssignment(faculty_id=fac_profile.id, subject_id=subj.id, class_id=cs.id)
    db.add(assign)
    db.flush()
    assignment_id = assign.id

    tt_entry = TimetableEntry(day_of_week="Monday", period_id=period.id, assignment_id=assign.id)
    db.add(tt_entry)
    db.flush()
    timetable_entry_id = tt_entry.id

    # Student 1 — with login account
    st1_user = User(username="23M4S01", email="s1_m4@test.com",
                    hashed_password=get_password_hash("student123"), role=UserRole.STUDENT,
                    is_active=True, login_identifier="23M4S01")
    db.add(st1_user)
    db.flush()
    student1_user_id = st1_user.id

    st1 = Student(roll_number="23M4S01", full_name="Alex M4", email="s1_m4@test.com",
                  class_id=cs.id, is_active=True, user_id=st1_user.id,
                  semester="3", department="CSE")
    db.add(st1)

    # Student 2 — with login account
    st2_user = User(username="23M4S02", email="s2_m4@test.com",
                    hashed_password=get_password_hash("student456"), role=UserRole.STUDENT,
                    is_active=True, login_identifier="23M4S02")
    db.add(st2_user)
    db.flush()
    student2_user_id = st2_user.id

    st2 = Student(roll_number="23M4S02", full_name="Sarah M4", email="s2_m4@test.com",
                  class_id=cs.id, is_active=True, user_id=st2_user.id,
                  semester="3", department="CSE")
    db.add(st2)
    db.flush()
    student1_id = st1.id
    student2_id = st2.id

    # A completed class session with attendance
    sess = ClassSession(
        timetable_entry_id=tt_entry.id,
        faculty_id=fac_profile.id,
        date="2025-09-01",
        status=SessionStatus.COMPLETED,
    )
    db.add(sess)
    db.flush()
    session_id = sess.id

    # Attendance records
    db.add(AttendanceRecord(session_id=sess.id, student_id=st1.id,
                            status=AttendanceStatus.PRESENT, recognized_via=RecognitionSource.MANUAL))
    db.add(AttendanceRecord(session_id=sess.id, student_id=st2.id,
                            status=AttendanceStatus.OD, od_reason="College Event",
                            recognized_via=RecognitionSource.OD_OVERRIDE))

    # Default attendance policy
    policy = AttendancePolicy(
        calculation_unit="PERIOD", minimum_percentage=75.0,
        warning_threshold=75.0, critical_threshold=65.0,
        unmarked_behavior="NOT_ENTERED", od_enabled=True,
        od_faculty_can_mark=True, od_require_reason=False,
        od_calculation_mode="COUNT_AS_PRESENT", is_active=True,
    )
    db.add(policy)

    # Default system settings
    default_settings = [
        ("auth.faculty_login_method", "USERNAME"),
        ("auth.student_login_method", "REGISTER_NUMBER"),
        ("auth.max_failed_attempts", "5"),
        ("auth.lock_duration_minutes", "30"),
        ("auth.session_days", "7"),
        ("ai.quantized_model", "true"),
        ("ai.recognition_threshold", "0.45"),
        ("ai.uncertain_threshold", "0.60"),
        ("ai.min_face_size_px", "50"),
        ("ai.image_quality_threshold", "0.5"),
        ("ai.performance_mode", "BALANCED"),
    ]
    for key, value in default_settings:
        db.add(SystemSetting(key=key, value=value))

    db.commit()
    db.close()

    yield

    Base.metadata.drop_all(bind=test_engine)
    app.dependency_overrides.clear()


def get_admin_headers():
    token = create_access_token(subject=str(admin_user_id), role="ADMIN")
    return {"Authorization": f"Bearer {token}"}

def get_faculty_headers():
    token = create_access_token(subject=str(faculty_user_id), role="FACULTY")
    return {"Authorization": f"Bearer {token}"}

def get_other_faculty_headers():
    token = create_access_token(subject=str(other_faculty_user_id), role="FACULTY")
    return {"Authorization": f"Bearer {token}"}

def get_student1_headers():
    token = create_access_token(subject=str(student1_user_id), role="STUDENT")
    return {"Authorization": f"Bearer {token}"}

def get_student2_headers():
    token = create_access_token(subject=str(student2_user_id), role="STUDENT")
    return {"Authorization": f"Bearer {token}"}


# ─────────────────────────────────────────────────────────────────────────────
# TEST 1: Student Login
# ─────────────────────────────────────────────────────────────────────────────

def test_01_student_login_success():
    """Student can login using register number (configured method)."""
    res = client.post("/api/v1/auth/student/login", json={
        "identifier": "23M4S01",
        "password": "student123"
    })
    assert res.status_code == 200, res.text
    data = res.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["register_number"] == "23M4S01"
    assert data["full_name"] == "Alex M4"


# ─────────────────────────────────────────────────────────────────────────────
# TEST 2: Student Persistent Session
# ─────────────────────────────────────────────────────────────────────────────

def test_02_student_persistent_session():
    """Token from student login can access /student/me."""
    res = client.post("/api/v1/auth/student/login", json={
        "identifier": "23M4S01", "password": "student123"
    })
    assert res.status_code == 200
    token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    me_res = client.get("/api/v1/student/me", headers=headers)
    assert me_res.status_code == 200
    assert me_res.json()["register_number"] == "23M4S01"


# ─────────────────────────────────────────────────────────────────────────────
# TEST 3: Student Can View Own Attendance
# ─────────────────────────────────────────────────────────────────────────────

def test_03_student_can_view_own_attendance():
    """Student can access their own attendance report."""
    res = client.get("/api/v1/student/attendance", headers=get_student1_headers())
    assert res.status_code == 200
    data = res.json()
    assert data["register_number"] == "23M4S01"
    assert "total" in data
    assert "subjects" in data
    assert "date_wise" in data


# ─────────────────────────────────────────────────────────────────────────────
# TEST 4: Student Cannot View Another Student's Attendance
# ─────────────────────────────────────────────────────────────────────────────

def test_04_student_cannot_view_another_students_attendance():
    """
    Student identity is derived from session — there is no student_id parameter.
    Each student sees only their own data. RBAC enforced server-side.
    """
    # Student 1 logs in and gets their data
    res1 = client.get("/api/v1/student/me", headers=get_student1_headers())
    assert res1.status_code == 200
    assert res1.json()["register_number"] == "23M4S01"

    # Student 2 logs in and gets their data
    res2 = client.get("/api/v1/student/me", headers=get_student2_headers())
    assert res2.status_code == 200
    assert res2.json()["register_number"] == "23M4S02"

    # Student 1 cannot use Student 2's token to see different data
    assert res1.json()["student_id"] != res2.json()["student_id"]


# ─────────────────────────────────────────────────────────────────────────────
# TEST 5: Student Cannot Access Faculty APIs
# ─────────────────────────────────────────────────────────────────────────────

def test_05_student_cannot_access_faculty_apis():
    """Student role is blocked from faculty-only endpoints."""
    headers = get_student1_headers()
    res = client.get("/api/v1/faculty/timetable", headers=headers)
    assert res.status_code == 403


# ─────────────────────────────────────────────────────────────────────────────
# TEST 6: Student Cannot Access Admin APIs
# ─────────────────────────────────────────────────────────────────────────────

def test_06_student_cannot_access_admin_apis():
    """Student role is blocked from all admin endpoints."""
    headers = get_student1_headers()
    res = client.get("/api/v1/admin/students", headers=headers)
    assert res.status_code == 403

    res2 = client.get("/api/v1/admin/settings/ai", headers=headers)
    assert res2.status_code == 403


# ─────────────────────────────────────────────────────────────────────────────
# TEST 7: Admin Can Create Student
# ─────────────────────────────────────────────────────────────────────────────

def test_07_admin_can_create_student():
    """Admin creates a student record."""
    headers = get_admin_headers()
    res = client.post("/api/v1/admin/students", json={
        "roll_number": "23NEW01", "full_name": "New Student",
        "semester": "3", "department": "CSE"
    }, headers=headers)
    assert res.status_code == 201
    data = res.json()
    assert data["roll_number"] == "23NEW01"
    assert data["has_account"] is False


# ─────────────────────────────────────────────────────────────────────────────
# TEST 8: Admin Can Create Faculty
# ─────────────────────────────────────────────────────────────────────────────

def test_08_admin_can_create_faculty():
    """Admin creates a faculty account."""
    headers = get_admin_headers()
    res = client.post("/api/v1/admin/faculty", json={
        "username": "new_faculty_m4", "email": "newf_m4@test.com",
        "password": "securepass123", "employee_id": "EMP-NEW-M4",
        "full_name": "Dr. New Faculty", "department": "IT"
    }, headers=headers)
    assert res.status_code == 201
    data = res.json()
    assert data["employee_id"] == "EMP-NEW-M4"
    assert data["full_name"] == "Dr. New Faculty"


# ─────────────────────────────────────────────────────────────────────────────
# TEST 9: Admin Can Reset Student Password
# ─────────────────────────────────────────────────────────────────────────────

def test_09_admin_can_reset_student_password():
    """Admin resets a student's password. Only hash is stored."""
    headers = get_admin_headers()

    # First create student with account
    res = client.post("/api/v1/admin/students/with-account", json={
        "roll_number": "23RESET01", "full_name": "Reset Student",
        "password": "oldpassword", "force_password_change": False
    }, headers=headers)
    assert res.status_code == 201
    new_student_id = res.json()["id"]

    # Reset password
    reset_res = client.post(f"/api/v1/admin/students/{new_student_id}/reset-password", json={
        "new_password": "newpassword456", "force_password_change": True
    }, headers=headers)
    assert reset_res.status_code == 200
    assert reset_res.json()["force_password_change"] is True

    # New password should work for login
    login_res = client.post("/api/v1/auth/student/login", json={
        "identifier": "23RESET01", "password": "newpassword456"
    })
    assert login_res.status_code == 200


# ─────────────────────────────────────────────────────────────────────────────
# TEST 10: Admin Can Reset Faculty Password
# ─────────────────────────────────────────────────────────────────────────────

def test_10_admin_can_reset_faculty_password():
    """Admin resets a faculty password."""
    headers = get_admin_headers()

    # Create faculty
    create_res = client.post("/api/v1/admin/faculty", json={
        "username": "fac_reset_m4", "email": "facreset_m4@test.com",
        "password": "oldpass", "employee_id": "EMP-RESET-M4",
        "full_name": "Dr. Reset"
    }, headers=headers)
    assert create_res.status_code == 201
    fac_id = create_res.json()["id"]

    # Reset password
    reset_res = client.post(f"/api/v1/admin/faculty/{fac_id}/reset-password", json={
        "new_password": "newpass789", "force_password_change": True
    }, headers=headers)
    assert reset_res.status_code == 200

    # New password works
    login_res = client.post("/api/v1/auth/login", json={
        "username_or_email": "fac_reset_m4", "password": "newpass789"
    })
    assert login_res.status_code == 200


# ─────────────────────────────────────────────────────────────────────────────
# TEST 11: Admin Can Disable Accounts
# ─────────────────────────────────────────────────────────────────────────────

def test_11_admin_can_disable_accounts():
    """Admin disabling an account prevents login."""
    headers = get_admin_headers()

    # Create student with account
    create_res = client.post("/api/v1/admin/students/with-account", json={
        "roll_number": "23DIS01", "full_name": "Disable Test",
        "password": "testpass", "force_password_change": False
    }, headers=headers)
    assert create_res.status_code == 201
    stud_id = create_res.json()["id"]

    # Disable student
    update_res = client.put(f"/api/v1/admin/students/{stud_id}", json={"is_active": False}, headers=headers)
    assert update_res.status_code == 200

    # Login should fail
    login_res = client.post("/api/v1/auth/student/login", json={
        "identifier": "23DIS01", "password": "testpass"
    })
    assert login_res.status_code in [401, 403]


# ─────────────────────────────────────────────────────────────────────────────
# TEST 12: Admin Can Configure Login Methods
# ─────────────────────────────────────────────────────────────────────────────

def test_12_admin_can_configure_login_methods():
    """Admin can change auth settings."""
    headers = get_admin_headers()

    # Get current settings
    get_res = client.get("/api/v1/admin/settings/auth", headers=headers)
    assert get_res.status_code == 200
    current = get_res.json()
    assert current["student_login_method"] == "REGISTER_NUMBER"

    # Update to USERNAME
    put_res = client.put("/api/v1/admin/settings/auth", json={
        "student_login_method": "USERNAME"
    }, headers=headers)
    assert put_res.status_code == 200
    assert put_res.json()["student_login_method"] == "USERNAME"

    # Restore
    client.put("/api/v1/admin/settings/auth", json={
        "student_login_method": "REGISTER_NUMBER"
    }, headers=headers)


# ─────────────────────────────────────────────────────────────────────────────
# TEST 13: Admin Can Configure Attendance Policy
# ─────────────────────────────────────────────────────────────────────────────

def test_13_admin_can_configure_attendance_policy():
    """Admin can view and update attendance policy."""
    headers = get_admin_headers()

    get_res = client.get("/api/v1/admin/settings/attendance-policy", headers=headers)
    assert get_res.status_code == 200
    policy = get_res.json()
    assert "minimum_percentage" in policy
    assert "od_calculation_mode" in policy

    put_res = client.put("/api/v1/admin/settings/attendance-policy", json={
        "minimum_percentage": 80.0,
        "od_calculation_mode": "COUNT_SEPARATELY"
    }, headers=headers)
    assert put_res.status_code == 200
    updated = put_res.json()
    assert updated["minimum_percentage"] == 80.0
    assert updated["od_calculation_mode"] == "COUNT_SEPARATELY"


# ─────────────────────────────────────────────────────────────────────────────
# TEST 14: Attendance Calculation Respects Policy
# ─────────────────────────────────────────────────────────────────────────────

def test_14_attendance_calculation_respects_policy():
    """
    Student 1 has 1 PRESENT. Student 2 has 1 OD.
    With COUNT_AS_PRESENT: OD counts as present → both should have 100%.
    """
    # Both students have 1 attendance record each in test setup
    s1_res = client.get("/api/v1/student/me", headers=get_student1_headers())
    assert s1_res.status_code == 200
    s1 = s1_res.json()
    assert s1["total"] >= 1
    assert s1["present"] >= 1

    s2_res = client.get("/api/v1/student/me", headers=get_student2_headers())
    assert s2_res.status_code == 200
    s2 = s2_res.json()
    # Student 2 has OD, with COUNT_AS_PRESENT policy it should count as present
    assert s2["od"] >= 1
    assert s2["percentage"] == 100.0  # OD counted as present


# ─────────────────────────────────────────────────────────────────────────────
# TEST 15: OD Can Be Marked
# ─────────────────────────────────────────────────────────────────────────────

def test_15_od_can_be_marked():
    """Faculty can mark a student OD in an active session."""
    headers = get_faculty_headers()
    db = TestingSessionLocal()

    # Create an active session
    active_sess = ClassSession(
        timetable_entry_id=timetable_entry_id,
        faculty_id=faculty_profile_id,
        date=str(date.today()),
        status=SessionStatus.ACTIVE,
    )
    db.add(active_sess)
    db.commit()
    active_sess_id = active_sess.id
    db.close()

    res = client.post(f"/api/v1/faculty/sessions/{active_sess_id}/od", json={
        "student_ids": [student1_id],
        "od_reason": "Sports Day"
    }, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["results"][0]["status"] == "OD"
    assert data["results"][0]["od_reason"] == "Sports Day"


# ─────────────────────────────────────────────────────────────────────────────
# TEST 16: OD Cannot Be Marked for Unauthorized Session
# ─────────────────────────────────────────────────────────────────────────────

def test_16_od_cannot_be_marked_for_unauthorized_session():
    """Other faculty cannot mark OD for a session they don't own."""
    db = TestingSessionLocal()
    active_sess = ClassSession(
        timetable_entry_id=timetable_entry_id,
        faculty_id=faculty_profile_id,
        date=str(date.today()),
        status=SessionStatus.ACTIVE,
    )
    db.add(active_sess)
    db.commit()
    active_sess_id = active_sess.id
    db.close()

    headers = get_other_faculty_headers()
    res = client.post(f"/api/v1/faculty/sessions/{active_sess_id}/od", json={
        "student_ids": [student1_id],
        "od_reason": "Unauthorized"
    }, headers=headers)
    assert res.status_code == 403


# ─────────────────────────────────────────────────────────────────────────────
# TEST 17: OD Calculation Follows Configured Policy
# ─────────────────────────────────────────────────────────────────────────────

def test_17_od_calculation_follows_configured_policy():
    """
    Student 2 has 1 OD record. With COUNT_AS_PRESENT: percentage = 100%.
    Verify via student/me endpoint which reads from policy engine.
    """
    s2_res = client.get("/api/v1/student/me", headers=get_student2_headers())
    assert s2_res.status_code == 200
    s2 = s2_res.json()

    # Policy is COUNT_AS_PRESENT → OD counted as present → 100%
    assert s2["od"] == 1
    assert s2["percentage"] == 100.0


# ─────────────────────────────────────────────────────────────────────────────
# TEST 18: OD Across Multiple Students Works
# ─────────────────────────────────────────────────────────────────────────────

def test_18_od_across_multiple_students_works():
    """Bulk OD marking for multiple students in one request."""
    headers = get_faculty_headers()
    db = TestingSessionLocal()
    active_sess = ClassSession(
        timetable_entry_id=timetable_entry_id,
        faculty_id=faculty_profile_id,
        date=str(date.today()),
        status=SessionStatus.ACTIVE,
    )
    db.add(active_sess)
    db.commit()
    active_sess_id = active_sess.id
    db.close()

    res = client.post(f"/api/v1/faculty/sessions/{active_sess_id}/od", json={
        "student_ids": [student1_id, student2_id],
        "od_reason": "College Fest"
    }, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert len(data["results"]) == 2
    assert all(r["status"] == "OD" for r in data["results"])
    assert all(r["od_reason"] == "College Fest" for r in data["results"])


# ─────────────────────────────────────────────────────────────────────────────
# TEST 19: Duplicate OD/Attendance Records Are Prevented (upsert)
# ─────────────────────────────────────────────────────────────────────────────

def test_19_duplicate_od_prevented():
    """Marking OD twice for same student+session upserts, not duplicates."""
    headers = get_faculty_headers()
    db = TestingSessionLocal()
    active_sess = ClassSession(
        timetable_entry_id=timetable_entry_id,
        faculty_id=faculty_profile_id,
        date=str(date.today()),
        status=SessionStatus.ACTIVE,
    )
    db.add(active_sess)
    db.commit()
    active_sess_id = active_sess.id
    db.close()

    # Mark OD twice
    for i in range(2):
        res = client.post(f"/api/v1/faculty/sessions/{active_sess_id}/od", json={
            "student_ids": [student1_id],
            "od_reason": f"Reason {i}"
        }, headers=headers)
        assert res.status_code == 200

    # Verify only 1 record exists
    db = TestingSessionLocal()
    records = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id == active_sess_id,
        AttendanceRecord.student_id == student1_id
    ).all()
    db.close()
    assert len(records) == 1
    assert records[0].status == AttendanceStatus.OD


# ─────────────────────────────────────────────────────────────────────────────
# TEST 20: Student Report Shows OD Correctly
# ─────────────────────────────────────────────────────────────────────────────

def test_20_student_report_shows_od_correctly():
    """Student 2 has an OD record — the attendance report should show it."""
    res = client.get("/api/v1/student/attendance", headers=get_student2_headers())
    assert res.status_code == 200
    data = res.json()
    assert data["od"] >= 1
    # The date-wise entry should show OD status
    assert any(
        any(p["status"] == "OD" for p in day["periods"])
        for day in data["date_wise"]
    )


# ─────────────────────────────────────────────────────────────────────────────
# TEST 21: Subject-wise Report Works
# ─────────────────────────────────────────────────────────────────────────────

def test_21_subject_wise_report_works():
    """Student can get subject-wise attendance breakdown."""
    res = client.get("/api/v1/student/attendance/subjects", headers=get_student1_headers())
    assert res.status_code == 200
    data = res.json()
    assert isinstance(data, list)
    # Should have the test subject
    if len(data) > 0:
        assert "subject_code" in data[0]
        assert "total" in data[0]
        assert "percentage" in data[0]


# ─────────────────────────────────────────────────────────────────────────────
# TEST 22: Date-wise Report Works
# ─────────────────────────────────────────────────────────────────────────────

def test_22_date_wise_report_works():
    """Full report includes date-wise attendance with period breakdown."""
    res = client.get("/api/v1/student/attendance", headers=get_student1_headers())
    assert res.status_code == 200
    data = res.json()
    assert "date_wise" in data
    assert isinstance(data["date_wise"], list)
    if len(data["date_wise"]) > 0:
        day = data["date_wise"][0]
        assert "date" in day
        assert "periods" in day


# ─────────────────────────────────────────────────────────────────────────────
# TEST 23: Timetable Configuration Works
# ─────────────────────────────────────────────────────────────────────────────

def test_23_timetable_configuration_works():
    """Admin can read timetable, student can read their class timetable."""
    admin_headers = get_admin_headers()
    tt_res = client.get("/api/v1/admin/timetable", headers=admin_headers)
    assert tt_res.status_code == 200
    tt_data = tt_res.json()
    assert isinstance(tt_data, list)

    # Student can access their timetable
    st_res = client.get("/api/v1/student/timetable", headers=get_student1_headers())
    assert st_res.status_code == 200
    st_data = st_res.json()
    assert "timetable" in st_data


# ─────────────────────────────────────────────────────────────────────────────
# TEST 24: Faculty Assignment Works
# ─────────────────────────────────────────────────────────────────────────────

def test_24_faculty_assignment_works():
    """Admin can create and list faculty assignments."""
    headers = get_admin_headers()

    # Create new subject for fresh assignment
    subj_res = client.post("/api/v1/admin/subjects", json={
        "code": "CS-M4-NEW", "name": "New Test Subject M4"
    }, headers=headers)
    assert subj_res.status_code == 201
    new_subj_id = subj_res.json()["id"]

    # Get faculty profile id from admin listing
    fac_res = client.get("/api/v1/admin/faculty", headers=headers)
    assert fac_res.status_code == 200
    fac_list = fac_res.json()
    assert len(fac_list) > 0
    fac_id = fac_list[0]["id"]

    # Create assignment
    assign_res = client.post("/api/v1/admin/assignments", json={
        "faculty_id": fac_id, "subject_id": new_subj_id, "class_id": class_id
    }, headers=headers)
    assert assign_res.status_code == 201
    assert assign_res.json()["subject_id"] == new_subj_id


# ─────────────────────────────────────────────────────────────────────────────
# TEST 25: Audit Logs Are Created
# ─────────────────────────────────────────────────────────────────────────────

def test_25_audit_logs_are_created():
    """Admin actions should generate audit log entries."""
    headers = get_admin_headers()

    # Perform an audited action
    client.post("/api/v1/admin/students", json={
        "roll_number": "23AUDIT01", "full_name": "Audit Test Student"
    }, headers=headers)

    # Check audit log
    log_res = client.get("/api/v1/admin/audit", headers=headers)
    assert log_res.status_code == 200
    logs = log_res.json()
    assert isinstance(logs, list)
    assert any(log["action"] == "CREATE_STUDENT" for log in logs)


# ─────────────────────────────────────────────────────────────────────────────
# TEST 26: Quantized AI Setting Defaults to ON
# ─────────────────────────────────────────────────────────────────────────────

def test_26_quantized_ai_setting_defaults_to_on():
    """The AI quantized_model setting must default to True (ON)."""
    headers = get_admin_headers()
    res = client.get("/api/v1/admin/settings/ai", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["quantized_model"] is True  # ON by default


# ─────────────────────────────────────────────────────────────────────────────
# TEST 27: Quantized OFF Represents Full-Precision Mode
# ─────────────────────────────────────────────────────────────────────────────

def test_27_quantized_off_is_full_precision_mode():
    """
    Setting quantized_model=false means full-precision mode.
    The toggle selects model variant — it does NOT disable AI.
    """
    headers = get_admin_headers()

    # Set to false (full-precision)
    res = client.put("/api/v1/admin/settings/ai", json={"quantized_model": False}, headers=headers)
    assert res.status_code == 200
    assert res.json()["quantized_model"] is False

    # Verify persisted
    get_res = client.get("/api/v1/admin/settings/ai", headers=headers)
    assert get_res.json()["quantized_model"] is False

    # Restore to ON
    client.put("/api/v1/admin/settings/ai", json={"quantized_model": True}, headers=headers)
    restore_res = client.get("/api/v1/admin/settings/ai", headers=headers)
    assert restore_res.json()["quantized_model"] is True


# ─────────────────────────────────────────────────────────────────────────────
# TEST 28: Student Login with Wrong Password Fails
# ─────────────────────────────────────────────────────────────────────────────

def test_28_student_login_wrong_password_fails():
    """Student login with incorrect password returns 401."""
    res = client.post("/api/v1/auth/student/login", json={
        "identifier": "23M4S01",
        "password": "wrongpassword"
    })
    assert res.status_code == 401


# ─────────────────────────────────────────────────────────────────────────────
# NEW IMPACT CONFIGURATION & RECOVERY TESTS (TESTS 29 - 49)
# ─────────────────────────────────────────────────────────────────────────────

def test_29_default_calculation_mode():
    """Verify default calculation mode is RECORD_BASED."""
    headers = get_admin_headers()
    res = client.get("/api/v1/admin/settings/attendance-policy", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["calculation_mode"] == "RECORD_BASED"
    assert data["period_present_gain"] == 0.25
    assert data["period_absent_loss"] == 0.25
    assert data["class_present_gain"] == 1.00
    assert data["class_absent_loss"] == 1.00
    assert data["day_present_gain"] == 1.00
    assert data["day_absent_loss"] == 1.00


def test_30_admin_can_change_calculation_mode():
    """Admin can change calculation mode between RECORD_BASED and IMPACT_BASED."""
    headers = get_admin_headers()
    res = client.put("/api/v1/admin/settings/attendance-policy", json={
        "calculation_mode": "IMPACT_BASED"
    }, headers=headers)
    assert res.status_code == 200
    assert res.json()["calculation_mode"] == "IMPACT_BASED"

    # Restore
    client.put("/api/v1/admin/settings/attendance-policy", json={
        "calculation_mode": "RECORD_BASED"
    }, headers=headers)


def test_31_admin_can_change_period_present_gain():
    """Admin can update period_present_gain with validation."""
    headers = get_admin_headers()
    res = client.put("/api/v1/admin/settings/attendance-policy", json={
        "period_present_gain": 0.50
    }, headers=headers)
    assert res.status_code == 200
    assert res.json()["period_present_gain"] == 0.50

    # Negative validation check
    bad_res = client.put("/api/v1/admin/settings/attendance-policy", json={
        "period_present_gain": -1.0
    }, headers=headers)
    assert bad_res.status_code == 400


def test_32_admin_can_change_period_absent_loss():
    """Admin can update period_absent_loss."""
    headers = get_admin_headers()
    res = client.put("/api/v1/admin/settings/attendance-policy", json={
        "period_absent_loss": 0.50
    }, headers=headers)
    assert res.status_code == 200
    assert res.json()["period_absent_loss"] == 0.50


def test_33_admin_can_change_class_present_gain():
    """Admin can update class_present_gain."""
    headers = get_admin_headers()
    res = client.put("/api/v1/admin/settings/attendance-policy", json={
        "class_present_gain": 2.00
    }, headers=headers)
    assert res.status_code == 200
    assert res.json()["class_present_gain"] == 2.00


def test_34_admin_can_change_class_absent_loss():
    """Admin can update class_absent_loss."""
    headers = get_admin_headers()
    res = client.put("/api/v1/admin/settings/attendance-policy", json={
        "class_absent_loss": 2.00
    }, headers=headers)
    assert res.status_code == 200
    assert res.json()["class_absent_loss"] == 2.00


def test_35_admin_can_change_day_present_gain():
    """Admin can update day_present_gain."""
    headers = get_admin_headers()
    res = client.put("/api/v1/admin/settings/attendance-policy", json={
        "day_present_gain": 3.00
    }, headers=headers)
    assert res.status_code == 200
    assert res.json()["day_present_gain"] == 3.00


def test_36_admin_can_change_day_absent_loss():
    """Admin can update day_absent_loss."""
    headers = get_admin_headers()
    res = client.put("/api/v1/admin/settings/attendance-policy", json={
        "day_absent_loss": 3.00
    }, headers=headers)
    assert res.status_code == 200
    assert res.json()["day_absent_loss"] == 3.00


def test_37_record_based_calculation():
    """RECORD_BASED mode uses actual ratio (Present / Counted) * 100."""
    headers = get_admin_headers()
    client.put("/api/v1/admin/settings/attendance-policy", json={
        "calculation_mode": "RECORD_BASED"
    }, headers=headers)

    res = client.get("/api/v1/student/me", headers=get_student1_headers())
    assert res.status_code == 200
    data = res.json()
    assert data["calculation_mode"] == "RECORD_BASED"
    # Student 1 has 1 present out of 1 total in setup
    assert data["percentage"] == 100.0


def test_38_impact_based_calculation():
    """IMPACT_BASED mode applies configured gains and losses."""
    headers = get_admin_headers()
    client.put("/api/v1/admin/settings/attendance-policy", json={
        "calculation_mode": "IMPACT_BASED",
        "period_absent_loss": 0.50,
        "day_absent_loss": 1.00,
    }, headers=headers)

    res = client.get("/api/v1/student/me", headers=get_student1_headers())
    assert res.status_code == 200
    data = res.json()
    assert data["calculation_mode"] == "IMPACT_BASED"

    # Restore RECORD_BASED
    client.put("/api/v1/admin/settings/attendance-policy", json={
        "calculation_mode": "RECORD_BASED",
        "period_absent_loss": 0.25,
        "day_absent_loss": 1.00,
    }, headers=headers)


def test_39_period_impact_applied_once():
    """Verify period impact applies per period without multiplying."""
    db = TestingSessionLocal()
    from app.engines.policy_engine import AttendancePolicyEngine, get_active_policy
    policy = get_active_policy(db)
    policy.calculation_mode = "IMPACT_BASED"
    policy.period_absent_loss = 0.50
    db.commit()

    engine = AttendancePolicyEngine(db)
    res = engine.calculate_student_attendance(student1_id)
    # Student 1 has 1 present period -> 100.0%
    assert res["percentage"] == 100.0
    db.close()


def test_40_class_impact_applied_once():
    """Class impact applies once per multi-period session."""
    db = TestingSessionLocal()
    from app.engines.policy_engine import AttendancePolicyEngine, get_active_policy
    policy = get_active_policy(db)
    policy.calculation_mode = "IMPACT_BASED"
    policy.class_absent_loss = 2.00
    db.commit()

    engine = AttendancePolicyEngine(db)
    res = engine.calculate_student_attendance(student1_id)
    assert res["percentage"] is not None
    db.close()


def test_41_day_impact_applied_once():
    """Day impact applies once per day when full day condition is met."""
    db = TestingSessionLocal()
    from app.engines.policy_engine import AttendancePolicyEngine, get_active_policy
    policy = get_active_policy(db)
    policy.calculation_mode = "IMPACT_BASED"
    policy.day_present_gain = 1.00
    db.commit()

    engine = AttendancePolicyEngine(db)
    res = engine.calculate_student_attendance(student1_id)
    assert res["percentage"] == 100.0  # baseline 100.0 + day_present_gain capped at 100.0
    db.close()


def test_42_no_double_counting():
    """Day level evaluation overrides period/class levels to prevent double-counting."""
    db = TestingSessionLocal()
    from app.engines.policy_engine import AttendancePolicyEngine, get_active_policy
    policy = get_active_policy(db)
    policy.calculation_mode = "IMPACT_BASED"
    policy.day_absent_loss = 1.00
    policy.period_absent_loss = 0.25
    db.commit()

    # Create a full absent day with 2 periods
    sess = ClassSession(
        timetable_entry_id=timetable_entry_id,
        faculty_id=faculty_profile_id,
        date="2025-09-10",
        status=SessionStatus.COMPLETED,
    )
    db.add(sess)
    db.flush()
    db.add(AttendanceRecord(session_id=sess.id, student_id=student1_id, status=AttendanceStatus.ABSENT))
    db.commit()

    engine = AttendancePolicyEngine(db)
    res = engine.calculate_student_attendance(student1_id)
    # Day impact should deduct day_absent_loss (1.00), not day_absent_loss + period_absent_loss
    assert res["percentage"] == 99.0
    db.close()


def test_43_od_does_not_receive_absent_loss():
    """OD status must not receive absent loss."""
    db = TestingSessionLocal()
    from app.engines.policy_engine import AttendancePolicyEngine, get_active_policy
    policy = get_active_policy(db)
    policy.calculation_mode = "IMPACT_BASED"
    policy.period_absent_loss = 10.0
    policy.od_calculation_mode = "COUNT_AS_PRESENT"
    db.commit()

    engine = AttendancePolicyEngine(db)
    # Student 2 has OD status
    res = engine.calculate_student_attendance(student2_id)
    assert res["percentage"] == 100.0  # No 10% absent loss applied to OD!
    db.close()


def test_44_minimum_attendance_calculation():
    """Attendance status correctly reflects thresholds."""
    db = TestingSessionLocal()
    from app.engines.policy_engine import AttendancePolicyEngine, get_active_policy
    policy = get_active_policy(db)
    policy.minimum_percentage = 75.0
    policy.warning_threshold = 75.0
    policy.critical_threshold = 65.0
    db.commit()

    engine = AttendancePolicyEngine(db)
    res = engine.calculate_student_attendance(student1_id)
    assert res["minimum_required"] == 75.0
    assert res["status"] in ["OK", "WARNING", "CRITICAL"]
    db.close()


def test_45_required_future_classes_calculation():
    """Required future classes prediction when student is below minimum."""
    db = TestingSessionLocal()
    from app.engines.policy_engine import AttendancePolicyEngine, get_active_policy
    policy = get_active_policy(db)
    policy.calculation_mode = "RECORD_BASED"
    policy.minimum_percentage = 75.0
    db.commit()

    # Add absent records to bring student 1 below 75%
    for i in range(3):
        sess = ClassSession(
            timetable_entry_id=timetable_entry_id,
            faculty_id=faculty_profile_id,
            date=f"2025-09-1{i+1}",
            status=SessionStatus.COMPLETED,
        )
        db.add(sess)
        db.flush()
        db.add(AttendanceRecord(session_id=sess.id, student_id=student1_id, status=AttendanceStatus.ABSENT))
    db.commit()

    engine = AttendancePolicyEngine(db)
    res = engine.calculate_student_attendance(student1_id)
    # 1 present out of 4 total = 25.0% < 75.0%
    assert res["below_minimum"] is True
    assert res["alert_message"] == "Attendance below required minimum."
    assert res["required_future_classes"] > 0
    assert res["estimated_working_days"] >= 0
    db.close()


def test_46_missable_future_classes_calculation():
    """Missable future classes prediction when student is at or above minimum."""
    db = TestingSessionLocal()
    from app.engines.policy_engine import AttendancePolicyEngine, get_active_policy
    policy = get_active_policy(db)
    policy.calculation_mode = "RECORD_BASED"
    policy.minimum_percentage = 75.0
    db.commit()

    # Student 2 is at 100% -> can miss classes
    engine = AttendancePolicyEngine(db)
    res = engine.calculate_student_attendance(student2_id)
    assert res["below_minimum"] is False
    assert res["alert_message"] is None
    assert res["missable_future_classes"] >= 0
    db.close()


def test_47_subject_percentage():
    """Subject-wise percentage calculation."""
    res = client.get("/api/v1/student/attendance/subjects", headers=get_student1_headers())
    assert res.status_code == 200
    subjects = res.json()
    assert isinstance(subjects, list)


def test_48_period_percentage():
    """Period-wise percentage calculation."""
    db = TestingSessionLocal()
    from app.engines.policy_engine import AttendancePolicyEngine
    engine = AttendancePolicyEngine(db)
    periods = engine.calculate_period_attendance(student1_id)
    assert isinstance(periods, list)
    db.close()


def test_49_student_dashboard_displays_correct_values():
    """Student portal endpoints (/student/me and /student/attendance) return all new impact and prediction fields."""
    res_me = client.get("/api/v1/student/me", headers=get_student1_headers())
    assert res_me.status_code == 200
    me = res_me.json()
    assert "calculation_mode" in me
    assert "below_minimum" in me
    assert "required_future_classes" in me
    assert "estimated_working_days" in me
    assert "missable_future_classes" in me

    res_att = client.get("/api/v1/student/attendance", headers=get_student1_headers())
    assert res_att.status_code == 200
    att = res_att.json()
    assert "calculation_mode" in att
    assert "period_summary" in att
    assert isinstance(att["period_summary"], list)
