import pytest
from datetime import datetime, timezone, date
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token, verify_password
from app.models.user import User, Faculty, UserRole
from app.models.student import Student
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.attendance import ClassSession, AttendanceRecord, AttendanceStatus, SessionStatus, RecognitionSource, ReviewStatus, FaceEmbedding
from app.models.audit import AuditLog

SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture(scope="function")
def console_fixture(db_session):
    # 1. Admin
    admin_user = User(
        username="admin_super",
        email="admin@college.edu",
        hashed_password=get_password_hash("AdminPass123!"),
        role=UserRole.ADMIN,
        is_active=True,
    )
    db_session.add(admin_user)

    # 2. Faculty
    fac_user = User(
        username="fac_smith",
        email="smith@college.edu",
        login_identifier="FAC001",
        hashed_password=get_password_hash("FacultyPass123!"),
        role=UserRole.FACULTY,
        is_active=True,
    )
    db_session.add(fac_user)
    db_session.flush()

    faculty = Faculty(
        user_id=fac_user.id,
        employee_id="FAC001",
        full_name="Dr. John Smith",
        department="Computer Science",
        phone="+91 9999988888"
    )
    db_session.add(faculty)

    # 3. Class section
    cls = ClassSection(
        name="CSE-A 2026",
        grade_level="II Year",
        academic_year="2026-2027"
    )
    db_session.add(cls)
    db_session.flush()

    # 4. Subject
    subj = Subject(
        code="CS301",
        name="Operating Systems",
        description="Core systems course"
    )
    db_session.add(subj)
    db_session.flush()

    # 5. Period
    period = Period(
        period_number=1,
        name="Morning 1",
        start_time="09:00",
        end_time="09:50"
    )
    db_session.add(period)
    db_session.flush()

    # 6. Faculty Assignment
    assignment = FacultyAssignment(
        faculty_id=faculty.id,
        subject_id=subj.id,
        class_id=cls.id
    )
    db_session.add(assignment)
    db_session.flush()

    # 7. Timetable Entry
    tt_entry = TimetableEntry(
        day_of_week="Monday",
        period_id=period.id,
        assignment_id=assignment.id
    )
    db_session.add(tt_entry)
    db_session.flush()

    # 8. Student
    stu_user = User(
        username="23cy001",
        email="alice@college.edu",
        login_identifier="23CY001",
        hashed_password=get_password_hash("StudentPass123!"),
        role=UserRole.STUDENT,
        is_active=True,
    )
    db_session.add(stu_user)
    db_session.flush()

    student = Student(
        user_id=stu_user.id,
        roll_number="23CY001",
        full_name="Alice Walker",
        email="alice@college.edu",
        class_id=cls.id,
        department="Cyber Security",
        semester="3"
    )
    db_session.add(student)
    db_session.commit()

    admin_token = create_access_token(admin_user.id, role=UserRole.ADMIN.value)
    fac_token = create_access_token(fac_user.id, role=UserRole.FACULTY.value)
    stu_token = create_access_token(stu_user.id, role=UserRole.STUDENT.value)

    return {
        "admin_headers": {"Authorization": f"Bearer {admin_token}"},
        "fac_headers": {"Authorization": f"Bearer {fac_token}"},
        "stu_headers": {"Authorization": f"Bearer {stu_token}"},
        "admin_id": admin_user.id,
        "faculty_id": faculty.id,
        "faculty_user_id": fac_user.id,
        "student_id": student.id,
        "student_user_id": stu_user.id,
        "class_id": cls.id,
        "subject_id": subj.id,
        "tt_entry_id": tt_entry.id,
    }


# ========================================================
# 1. STUDENT MANAGEMENT TESTS
# ========================================================

def test_student_full_edit_and_validation(client, console_fixture, db_session):
    headers = console_fixture["admin_headers"]
    st_id = console_fixture["student_id"]

    # 1. Update all fields
    update_payload = {
        "roll_number": "23CY001-MOD",
        "username": "alice_updated",
        "full_name": "Alice Walker-Smith",
        "email": "alice.smith@college.edu",
        "phone": "+91 9123456780",
        "department": "Cyber Security & Forensics",
        "semester": "4",
        "is_active": True,
        "force_password_change": True,
        "new_password": "NewSecretPassword123!"
    }
    r = client.put(f"/api/v1/admin/students/{st_id}", json=update_payload, headers=headers)
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["roll_number"] == "23CY001-MOD"
    assert data["username"] == "alice_updated"
    assert data["full_name"] == "Alice Walker-Smith"
    assert data["email"] == "alice.smith@college.edu"

    # Verify password was updated in DB
    db_user = db_session.query(User).filter(User.id == console_fixture["student_user_id"]).first()
    assert db_user.username == "alice_updated"
    assert db_user.login_identifier == "23CY001-MOD"
    assert verify_password("NewSecretPassword123!", db_user.hashed_password)
    assert db_user.force_password_change is True

    # 2. Duplicate roll number rejection
    # Create another student
    r2 = client.post("/api/v1/admin/students", json={
        "roll_number": "23CY099",
        "full_name": "Bob Miller",
        "generate_temporary": True
    }, headers=headers)
    assert r2.status_code == 201

    dup_r = client.put(f"/api/v1/admin/students/{st_id}", json={"roll_number": "23CY099"}, headers=headers)
    assert dup_r.status_code == 400
    assert "already exists" in dup_r.json()["detail"]


def test_student_delete_referential_integrity(client, console_fixture, db_session):
    headers = console_fixture["admin_headers"]
    st_id = console_fixture["student_id"]

    # Create a class session and an attendance record for this student
    sess = ClassSession(
        timetable_entry_id=console_fixture["tt_entry_id"],
        faculty_id=console_fixture["faculty_id"],
        date="2026-09-27",
        status=SessionStatus.COMPLETED
    )
    db_session.add(sess)
    db_session.flush()

    att = AttendanceRecord(
        session_id=sess.id,
        student_id=st_id,
        status=AttendanceStatus.PRESENT,
        recognized_via=RecognitionSource.LIVE_CAMERA,
        review_status=ReviewStatus.APPROVED,
        confidence=98.5
    )
    db_session.add(att)
    db_session.commit()

    # Attempt to delete student -> must fail with 400
    del_r = client.delete(f"/api/v1/admin/students/{st_id}", headers=headers)
    assert del_r.status_code == 400
    assert "attendance record" in del_r.json()["detail"].lower()
    assert "deactivate" in del_r.json()["detail"].lower()

    # Create a fresh student without attendance -> deletion must succeed
    fresh_r = client.post("/api/v1/admin/students", json={
        "roll_number": "23TEMP01",
        "full_name": "Temporary Student",
        "generate_temporary": True
    }, headers=headers)
    assert fresh_r.status_code == 201
    fresh_id = fresh_r.json()["id"]

    del_success = client.delete(f"/api/v1/admin/students/{fresh_id}", headers=headers)
    assert del_success.status_code == 200
    assert del_success.json()["student_id"] == fresh_id


# ========================================================
# 2. FACULTY MANAGEMENT TESTS
# ========================================================

def test_faculty_full_edit_and_validation(client, console_fixture, db_session):
    headers = console_fixture["admin_headers"]
    fac_id = console_fixture["faculty_id"]

    # 1. Update faculty fields
    update_payload = {
        "employee_id": "FAC001-MOD",
        "username": "dr_smith_mod",
        "full_name": "Prof. John Smith, Ph.D.",
        "department": "Artificial Intelligence",
        "email": "dr.smith@college.edu",
        "phone": "+91 9999977777",
        "role": "FACULTY",
        "is_active": True,
        "force_password_change": True,
        "new_password": "NewFacultyPass123!"
    }
    r = client.put(f"/api/v1/admin/faculty/{fac_id}", json=update_payload, headers=headers)
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["employee_id"] == "FAC001-MOD"
    assert data["username"] == "dr_smith_mod"
    assert data["full_name"] == "Prof. John Smith, Ph.D."
    assert data["email"] == "dr.smith@college.edu"

    # Verify DB user account
    db_user = db_session.query(User).filter(User.id == console_fixture["faculty_user_id"]).first()
    assert db_user.username == "dr_smith_mod"
    assert db_user.login_identifier == "FAC001-MOD"
    assert verify_password("NewFacultyPass123!", db_user.hashed_password)

    # 2. Duplicate employee_id check
    r2 = client.post("/api/v1/admin/faculty", json={
        "employee_id": "FAC999",
        "username": "fac999",
        "full_name": "Faculty 999",
        "email": "fac999@college.edu",
        "generate_temporary": True
    }, headers=headers)
    assert r2.status_code == 201

    dup_r = client.put(f"/api/v1/admin/faculty/{fac_id}", json={"employee_id": "FAC999"}, headers=headers)
    assert dup_r.status_code == 400
    assert "already exists" in dup_r.json()["detail"]


def test_faculty_delete_referential_integrity(client, console_fixture, db_session):
    headers = console_fixture["admin_headers"]
    fac_id = console_fixture["faculty_id"]

    # Faculty is assigned to course -> delete must fail
    del_r = client.delete(f"/api/v1/admin/faculty/{fac_id}", headers=headers)
    assert del_r.status_code == 400
    assert "assignment" in del_r.json()["detail"].lower()

    # Create unassigned faculty -> delete must succeed
    fresh_fac = client.post("/api/v1/admin/faculty", json={
        "employee_id": "FAC_TEMP",
        "username": "fac_temp",
        "full_name": "Temp Faculty",
        "email": "tempfac@college.edu",
        "generate_temporary": True
    }, headers=headers)
    assert fresh_fac.status_code == 201
    f_id = fresh_fac.json()["id"]

    del_ok = client.delete(f"/api/v1/admin/faculty/{f_id}", headers=headers)
    assert del_ok.status_code == 200
    assert del_ok.json()["faculty_id"] == f_id


# ========================================================
# 3. ACADEMIC CLASSES & SUBJECTS MANAGEMENT TESTS
# ========================================================

def test_classes_and_subjects_management(client, console_fixture, db_session):
    headers = console_fixture["admin_headers"]
    cls_id = console_fixture["class_id"]
    sub_id = console_fixture["subject_id"]

    # 1. List classes includes student count
    cls_r = client.get("/api/v1/admin/classes", headers=headers)
    assert cls_r.status_code == 200
    classes = cls_r.json()
    assert len(classes) >= 1
    found_cls = next(c for c in classes if c["id"] == cls_id)
    assert found_cls["student_count"] == 1

    # 2. Update class section
    up_cls = client.put(f"/api/v1/admin/classes/{cls_id}", json={
        "name": "CSE-A 2026 Honors",
        "grade_level": "II Year Honors",
        "academic_year": "2026-2027"
    }, headers=headers)
    assert up_cls.status_code == 200
    assert up_cls.json()["name"] == "CSE-A 2026 Honors"

    # 3. Delete class blocked by enrolled student
    del_cls_r = client.delete(f"/api/v1/admin/classes/{cls_id}", headers=headers)
    assert del_cls_r.status_code == 400
    assert "enrolled student" in del_cls_r.json()["detail"].lower()

    # 4. Update subject
    up_sub = client.put(f"/api/v1/admin/subjects/{sub_id}", json={
        "code": "CS301-MOD",
        "name": "Advanced Operating Systems",
        "description": "Kernel and distributed architecture"
    }, headers=headers)
    assert up_sub.status_code == 200
    assert up_sub.json()["code"] == "CS301-MOD"

    # 5. Delete subject blocked by faculty assignment
    del_sub_r = client.delete(f"/api/v1/admin/subjects/{sub_id}", headers=headers)
    assert del_sub_r.status_code == 400
    assert "assignment" in del_sub_r.json()["detail"].lower()


# ========================================================
# 4. ATTENDANCE RECORDS MANAGEMENT TESTS
# ========================================================

def test_attendance_records_crud_and_corrections(client, console_fixture, db_session):
    headers = console_fixture["admin_headers"]
    st_id = console_fixture["student_id"]

    # 1. Create a session first
    sess = ClassSession(
        timetable_entry_id=console_fixture["tt_entry_id"],
        faculty_id=console_fixture["faculty_id"],
        date="2026-09-27",
        status=SessionStatus.ACTIVE
    )
    db_session.add(sess)
    db_session.commit()

    # 2. Admin manually records attendance
    man_payload = {
        "session_id": sess.id,
        "student_id": st_id,
        "status": "OD",
        "od_reason": "Inter-college Hackathon"
    }
    r = client.post("/api/v1/admin/attendance/manual", json=man_payload, headers=headers)
    assert r.status_code == 201, r.text
    record = r.json()
    assert record["status"] == "OD"
    assert record["od_reason"] == "Inter-college Hackathon"
    assert record["recognized_via"] == "MANUAL"
    record_id = record["id"]

    # Verify audit log created
    audit = db_session.query(AuditLog).filter(AuditLog.action == "ATTENDANCE_MANUAL_ADDED").first()
    assert audit is not None

    # 3. Query attendance records
    list_r = client.get(f"/api/v1/admin/attendance?session_id={sess.id}", headers=headers)
    assert list_r.status_code == 200
    assert len(list_r.json()) == 1

    # 4. Admin updates / corrects attendance record
    corr_payload = {
        "status": "PRESENT",
        "review_status": "APPROVED",
        "od_reason": None
    }
    up_r = client.put(f"/api/v1/admin/attendance/{record_id}", json=corr_payload, headers=headers)
    assert up_r.status_code == 200
    assert up_r.json()["status"] == "PRESENT"

    audit_corr = db_session.query(AuditLog).filter(AuditLog.action == "ATTENDANCE_CORRECTED").first()
    assert audit_corr is not None

    # 5. Delete attendance record
    del_r = client.delete(f"/api/v1/admin/attendance/{record_id}", headers=headers)
    assert del_r.status_code == 200
    assert del_r.json()["record_id"] == record_id

    audit_del = db_session.query(AuditLog).filter(AuditLog.action == "ATTENDANCE_DELETED").first()
    assert audit_del is not None


# ========================================================
# 5. CLASS SESSIONS MANAGEMENT TESTS
# ========================================================

def test_class_sessions_crud_and_roster(client, console_fixture, db_session):
    headers = console_fixture["admin_headers"]
    fac_id = console_fixture["faculty_id"]
    tt_id = console_fixture["tt_entry_id"]

    # 1. Create Class Session
    create_payload = {
        "date": "2026-09-28",
        "faculty_id": fac_id,
        "timetable_entry_id": tt_id,
        "status": "SCHEDULED"
    }
    r = client.post("/api/v1/admin/sessions", json=create_payload, headers=headers)
    assert r.status_code == 201, r.text
    sess_data = r.json()
    session_id = sess_data["id"]
    assert sess_data["status"] == "SCHEDULED"

    # 2. Update Class Session
    up_payload = {
        "date": "2026-09-28",
        "faculty_id": fac_id,
        "status": "ACTIVE"
    }
    up_r = client.put(f"/api/v1/admin/sessions/{session_id}", json=up_payload, headers=headers)
    assert up_r.status_code == 200
    assert up_r.json()["status"] == "ACTIVE"

    roster_r = client.get(f"/api/v1/admin/sessions/{session_id}", headers=headers)
    assert roster_r.status_code == 200
    roster_data = roster_r.json()
    assert "roster" in roster_data
    assert roster_data["summary"]["total_students"] >= 1

    # 4. Attempt non-cascade delete when attendance records exist
    att = AttendanceRecord(
        session_id=session_id,
        student_id=console_fixture["student_id"],
        status=AttendanceStatus.PRESENT,
        recognized_via=RecognitionSource.MANUAL,
        review_status=ReviewStatus.APPROVED
    )
    db_session.add(att)
    db_session.commit()

    del_fail = client.delete(f"/api/v1/admin/sessions/{session_id}", headers=headers)
    assert del_fail.status_code == 400
    assert "cascade=true" in del_fail.json()["detail"]

    # 5. Cascade delete succeeds
    del_ok = client.delete(f"/api/v1/admin/sessions/{session_id}?cascade=true", headers=headers)
    assert del_ok.status_code == 200
    assert del_ok.json()["session_id"] == session_id
    assert del_ok.json()["deleted_records"] == 1


# ========================================================
# 6. BIOMETRIC FACE PROFILES TESTS
# ========================================================

def test_biometric_face_profiles_and_reset(client, console_fixture, db_session):
    headers = console_fixture["admin_headers"]
    st_id = console_fixture["student_id"]

    # Add 3 face templates for student to simulate complete enrollment
    for i in range(3):
        emb = FaceEmbedding(
            student_id=st_id,
            embedding_json="[0.1, 0.2, 0.3]",
            model_name="dlib_resnet",
            model_version="v1",
            dimension=128,
            detector_name="dlib_hog",
            distance_metric="euclidean",
            quality_score=95.0,
            created_at=datetime.now(timezone.utc)
        )
        db_session.add(emb)
    db_session.commit()

    # 1. Summary endpoint
    sum_r = client.get("/api/v1/admin/biometrics/summary", headers=headers)
    assert sum_r.status_code == 200
    summary = sum_r.json()
    assert summary["enrolled_count"] >= 1
    assert summary["dimension"] == 128
    assert "model_name" in summary

    # 2. Students list
    st_r = client.get("/api/v1/admin/biometrics/students", headers=headers)
    assert st_r.status_code == 200
    st_list = st_r.json()
    target = next(s for s in st_list if s["student_id"] == st_id)
    assert target["enrolled"] is True
    assert target["template_count"] == 3
    # Verify strict privacy: zero raw vectors in output
    assert "embedding" not in target
    assert "embedding_json" not in target

    # 3. Reset biometrics
    reset_r = client.post(f"/api/v1/admin/biometrics/{st_id}/reset", headers=headers)
    assert reset_r.status_code == 200
    assert reset_r.json()["deleted_templates"] == 3

    # Templates must now be 0 in DB
    remaining_embs = db_session.query(FaceEmbedding).filter(FaceEmbedding.student_id == st_id).count()
    assert remaining_embs == 0

    # Audit log check
    audit = db_session.query(AuditLog).filter(AuditLog.action == "BIOMETRIC_RESET").first()
    assert audit is not None


# ========================================================
# 7. CENTRAL USER ACCOUNTS MANAGEMENT TESTS
# ========================================================

def test_central_user_accounts_management(client, console_fixture, db_session):
    headers = console_fixture["admin_headers"]
    u_id = console_fixture["student_user_id"]

    # 1. List users
    users_r = client.get("/api/v1/admin/users", headers=headers)
    assert users_r.status_code == 200
    users = users_r.json()
    assert len(users) >= 3

    # 2. Get specific user
    u_r = client.get(f"/api/v1/admin/users/{u_id}", headers=headers)
    assert u_r.status_code == 200
    assert u_r.json()["id"] == u_id

    # 3. Update user account
    up_user = client.put(f"/api/v1/admin/users/{u_id}", json={
        "username": "alice_user_new",
        "email": "alice.new@college.edu",
        "role": "STUDENT",
        "is_active": True,
        "force_password_change": True,
        "new_password": "AliceNewPassword456!"
    }, headers=headers)
    assert up_user.status_code == 200
    assert up_user.json()["username"] == "alice_user_new"

    # 4. Toggle active state
    toggle_r = client.post(f"/api/v1/admin/users/{u_id}/toggle-active", headers=headers)
    assert toggle_r.status_code == 200
    assert toggle_r.json()["is_active"] is False

    # 5. Reset user password
    reset_r = client.post(f"/api/v1/admin/users/{u_id}/reset-password", json={
        "generate_temporary": True,
        "force_password_change": True
    }, headers=headers)
    assert reset_r.status_code == 200
    assert reset_r.json()["temporary_password"] is not None


# ========================================================
# 8. AUTHORIZATION AND SECURITY CONTROLS
# ========================================================

def test_admin_console_authorization_controls(client, console_fixture):
    fac_headers = console_fixture["fac_headers"]
    stu_headers = console_fixture["stu_headers"]

    # 1. Faculty cannot access admin console endpoints (403 Forbidden)
    r1 = client.get("/api/v1/admin/users", headers=fac_headers)
    assert r1.status_code == 403

    r2 = client.post("/api/v1/admin/attendance/manual", json={}, headers=fac_headers)
    assert r2.status_code == 403

    r3 = client.get("/api/v1/admin/biometrics/summary", headers=fac_headers)
    assert r3.status_code == 403

    # 2. Student cannot access admin console endpoints (403 Forbidden)
    r4 = client.get("/api/v1/admin/users", headers=stu_headers)
    assert r4.status_code == 403

    r5 = client.put(f"/api/v1/admin/students/{console_fixture['student_id']}", json={}, headers=stu_headers)
    assert r5.status_code == 403

    # 3. Unauthenticated requests receive 401
    r6 = client.get("/api/v1/admin/users")
    assert r6.status_code == 401
