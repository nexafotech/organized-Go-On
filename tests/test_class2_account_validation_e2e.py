import os
import zipfile
import xml.etree.ElementTree as ET
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import SessionLocal
from app.models.user import User, UserRole
from app.models.student import Student
from app.models.academic import ClassSection, TimetableEntry
from app.models.attendance import AttendanceRecord, ClassSession, FaceEmbedding
from app.core.security import get_password_hash

client = TestClient(app)

DOCX_PATH = r"C:\Users\Abishek\Documents\Attendance_Marker\CLASS2_STUDENT_CREDENTIALS.docx"


def load_class2_credentials_from_docx():
    """
    Loads student credentials from the confidential DOCX without exposing them.
    Returns dict mapping roll_number -> {'name': ..., 'temp_pwd': ..., 'force_change': ...}
    """
    assert os.path.exists(DOCX_PATH), f"Confidential DOCX does not exist at {DOCX_PATH}"
    with zipfile.ZipFile(DOCX_PATH, "r") as z:
        xml_content = z.read("word/document.xml")

    root = ET.fromstring(xml_content)
    namespaces = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
    rows = root.findall(".//w:tr", namespaces)
    assert len(rows) == 56, f"Expected 56 rows (1 header + 55 students), got {len(rows)}"

    creds = {}
    for r in rows[1:]:
        cells = r.findall(".//w:tc", namespaces)
        cell_texts = ["".join(c.itertext()).strip() for c in cells]
        roll = cell_texts[1]
        name = cell_texts[2]
        temp_pwd = cell_texts[6]
        force_change = cell_texts[7].lower() == "true"
        creds[roll] = {
            "name": name,
            "temp_pwd": temp_pwd,
            "force_change": force_change
        }
    return creds


# ==============================================================================
# 1. AUDIT ALL 55 CLASS 2 ACCOUNTS IN DATABASE
# ==============================================================================

def test_1_audit_all_55_class2_accounts_in_db():
    """Verify all 55 Class 2 student records and their linked user accounts in DB."""
    db = SessionLocal()
    try:
        c2_sec = db.query(ClassSection).filter(ClassSection.name == "III Year CSE Cyber Security - Class 2").first()
        assert c2_sec is not None, "Class 2 section missing"
        assert c2_sec.id is not None  # ID is 5 after legacy test classes were purged (was 2 before cleanup)

        c2_students = db.query(Student).filter(Student.class_id == c2_sec.id).all()
        assert len(c2_students) == 55, f"Expected 55 Class 2 students, found {len(c2_students)}"

        rolls = [s.roll_number for s in c2_students]
        assert len(rolls) == len(set(rolls)), "Duplicate roll numbers found in Class 2"

        # Check known gaps are not in DB
        known_gaps = ["721024149003", "721024149009", "721024149028", "721024149048"]
        for g in known_gaps:
            assert g not in rolls, f"Gap {g} was fabricated in DB!"

        for st in c2_students:
            assert st.roll_number.startswith("721024149")
            assert len(st.full_name.strip()) > 0
            assert st.department == "CSE Cyber Security"
            assert st.semester == "5"
            assert st.is_active is True

            # Linked user account
            assert st.user_id is not None
            user = db.query(User).filter(User.id == st.user_id).first()
            assert user is not None
            assert user.role == UserRole.STUDENT
            assert user.is_active is True
            assert user.username == st.roll_number
            assert user.login_identifier == st.roll_number
            assert user.force_password_change is True
            assert user.email == f"{st.roll_number.lower()}@dev.college.local"
    finally:
        db.close()


# ==============================================================================
# 2. LOGIN TESTS: VALID AND INVALID CREDENTIALS
# ==============================================================================

def test_2_login_representative_class2_accounts():
    """Test login with temporary credentials for representative accounts (start, middle, end)."""
    creds = load_class2_credentials_from_docx()

    # Pick 3 representative accounts
    rep_rolls = ["721024149001", "721024149030", "721024149059"]

    for roll in rep_rolls:
        info = creds[roll]
        res = client.post(
            "/api/v1/auth/student/login",
            json={"identifier": roll, "password": info["temp_pwd"]}
        )
        assert res.status_code == 200, f"Login failed for {roll}: {res.text}"
        data = res.json()
        assert data["token_type"] == "bearer"
        assert len(data["access_token"]) > 20
        assert data["register_number"] == roll
        assert data["full_name"] == info["name"]
        assert data["force_password_change"] is True


def test_3_login_rejected_for_invalid_credentials():
    """Verify invalid password and invalid roll number are rejected with 401."""
    # Wrong password
    res = client.post(
        "/api/v1/auth/student/login",
        json={"identifier": "721024149001", "password": "WrongPassword999!"}
    )
    assert res.status_code == 401
    assert "Incorrect credentials" in res.json()["detail"]

    # Nonexistent student
    res = client.post(
        "/api/v1/auth/student/login",
        json={"identifier": "721024149999", "password": "AnyPassword123!"}
    )
    assert res.status_code == 401
    assert "Incorrect credentials" in res.json()["detail"]


# ==============================================================================
# 3. RBAC RESTRICTIONS: STUDENT CANNOT ACCESS ADMIN OR FACULTY ENDPOINTS
# ==============================================================================

def test_4_student_cannot_access_admin_or_faculty_endpoints():
    """Verify student bearer token receives HTTP 403 on admin and faculty APIs."""
    creds = load_class2_credentials_from_docx()
    roll = "721024149001"
    info = creds[roll]

    # Authenticate
    res_login = client.post(
        "/api/v1/auth/student/login",
        json={"identifier": roll, "password": info["temp_pwd"]}
    )
    token = res_login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Admin endpoints
    res_admin1 = client.get("/api/v1/admin/students", headers=headers)
    assert res_admin1.status_code == 403

    res_admin2 = client.get("/api/v1/admin/classes", headers=headers)
    assert res_admin2.status_code == 403

    res_admin3 = client.get("/api/v1/admin/timetable", headers=headers)
    assert res_admin3.status_code == 403

    # Faculty endpoints
    res_fac1 = client.get("/api/v1/faculty/timetable", headers=headers)
    assert res_fac1.status_code == 403

    res_fac2 = client.post(
        "/api/v1/faculty/sessions/start",
        json={"timetable_entry_id": 1},
        headers=headers
    )
    assert res_fac2.status_code == 403


# ==============================================================================
# 4. FORCED PASSWORD CHANGE LIFECYCLE
# ==============================================================================

def test_5_forced_password_change_lifecycle_and_revert():
    """
    Test full forced password change lifecycle on representative account:
    1. Authenticate with temp password (force_password_change = True).
    2. Change password via /auth/change-password.
    3. Verify old temp password fails.
    4. Verify new password succeeds with force_password_change = False.
    5. Revert back to temp password to keep DB in pristine state.
    """
    creds = load_class2_credentials_from_docx()
    roll = "721024149002"  # Representative account 2
    temp_pwd = creds[roll]["temp_pwd"]
    new_pwd = "NewClass2SecurePass!2026"

    # Step 1: Login with temp credential
    res_login = client.post(
        "/api/v1/auth/student/login",
        json={"identifier": roll, "password": temp_pwd}
    )
    assert res_login.status_code == 200
    assert res_login.json()["force_password_change"] is True
    token = res_login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    try:
        # Step 2: Change password
        res_change = client.post(
            "/api/v1/auth/change-password",
            json={
                "current_password": temp_pwd,
                "new_password": new_pwd,
                "confirm_password": new_pwd
            },
            headers=headers
        )
        assert res_change.status_code == 200
        assert res_change.json()["force_password_change"] is False

        # Step 3: Old temp password no longer authenticates
        res_old = client.post(
            "/api/v1/auth/student/login",
            json={"identifier": roll, "password": temp_pwd}
        )
        assert res_old.status_code == 401

        # Step 4: New password authenticates successfully
        res_new = client.post(
            "/api/v1/auth/student/login",
            json={"identifier": roll, "password": new_pwd}
        )
        assert res_new.status_code == 200
        assert res_new.json()["force_password_change"] is False

    finally:
        # Revert back to temporary password so all 55 accounts remain aligned with DOCX
        db = SessionLocal()
        u = db.query(User).filter(User.username == roll).first()
        if u:
            u.hashed_password = get_password_hash(temp_pwd)
            u.force_password_change = True
            db.commit()
        db.close()

    # Confirm revert was successful
    res_reverted = client.post(
        "/api/v1/auth/student/login",
        json={"identifier": roll, "password": temp_pwd}
    )
    assert res_reverted.status_code == 200
    assert res_reverted.json()["force_password_change"] is True


# ==============================================================================
# 5. STUDENT ACCESS & ACCOUNT ISOLATION
# ==============================================================================

def test_6_student_access_and_account_isolation():
    """Verify Student A can only view Student A's data, and Student B views Student B's data."""
    creds = load_class2_credentials_from_docx()
    roll_a = "721024149001"
    roll_b = "721024149059"

    # Authenticate Student A
    res_a = client.post(
        "/api/v1/auth/student/login",
        json={"identifier": roll_a, "password": creds[roll_a]["temp_pwd"]}
    )
    token_a = res_a.json()["access_token"]
    headers_a = {"Authorization": f"Bearer {token_a}"}

    # Authenticate Student B
    res_b = client.post(
        "/api/v1/auth/student/login",
        json={"identifier": roll_b, "password": creds[roll_b]["temp_pwd"]}
    )
    token_b = res_b.json()["access_token"]
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # Student A profile
    profile_a = client.get("/api/v1/student/me", headers=headers_a).json()
    assert profile_a["register_number"] == roll_a
    assert profile_a["full_name"] == creds[roll_a]["name"]
    assert profile_a["class_name"] == "III Year CSE Cyber Security - Class 2"
    assert profile_a["semester"] == "5"

    # Student B profile
    profile_b = client.get("/api/v1/student/me", headers=headers_b).json()
    assert profile_b["register_number"] == roll_b
    assert profile_b["full_name"] == creds[roll_b]["name"]
    assert profile_b["class_name"] == "III Year CSE Cyber Security - Class 2"
    assert profile_b["semester"] == "5"

    # Isolation checks: Student A's response contains zero Student B data
    assert profile_a["register_number"] != profile_b["register_number"]
    assert profile_a["student_id"] != profile_b["student_id"]
    assert profile_a["user_id"] != profile_b["user_id"]

    # Student timetable access
    tt_a = client.get("/api/v1/student/timetable", headers=headers_a)
    assert tt_a.status_code == 200
    assert "timetable" in tt_a.json()
    assert len(tt_a.json()["timetable"]) == 42  # Class 2 timetable has 42 slots


# ==============================================================================
# 6. FINAL DATABASE INTEGRITY CHECKS
# ==============================================================================

def test_7_database_integrity_invariants():
    """Verify all global counts and invariants remain strictly intact."""
    db = SessionLocal()
    try:
        c1_sec = db.query(ClassSection).filter(ClassSection.name == "II Year CSE Cyber Security - Class 1").first()
        c2_sec = db.query(ClassSection).filter(ClassSection.name == "III Year CSE Cyber Security - Class 2").first()

        c1_count = db.query(Student).filter(Student.class_id == c1_sec.id).count()
        c2_count = db.query(Student).filter(Student.class_id == c2_sec.id).count()
        total_students = db.query(Student).count()
        total_student_users = db.query(User).filter(User.role == UserRole.STUDENT).count()

        assert c1_count == 64
        assert c2_count == 55
        assert total_students == 119
        assert total_student_users == 119

        face_embs = db.query(FaceEmbedding).count()
        assert face_embs == 0

        att_recs = db.query(AttendanceRecord).count()
        assert att_recs == 0

        sessions = db.query(ClassSession).count()
        assert sessions == 0

        tt1 = db.query(TimetableEntry).filter(TimetableEntry.assignment.has(class_id=c1_sec.id)).count()
        tt2 = db.query(TimetableEntry).filter(TimetableEntry.assignment.has(class_id=c2_sec.id)).count()
        tt_total = db.query(TimetableEntry).count()

        assert tt1 == 42
        assert tt2 == 42
        assert tt_total == 84
    finally:
        db.close()
