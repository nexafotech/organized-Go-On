import os
import json
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool

from app.main import app
from app.core.database import Base, get_db
from app.core.config import settings
from app.core.security import get_password_hash, create_access_token, verify_password
from app.models.user import User, UserRole, Faculty
from app.models.student import Student
from app.models.academic import ClassSection
from app.models.audit import AuditLog
from app.services.class1_onboarding_service import (
    onboard_class1_students,
    generate_secure_temporary_password,
    generate_credential_docx,
    EXPECTED_STUDENT_COUNT,
    EXPECTED_CLASS_NAME,
    MAX_SYSTEM_STUDENTS,
    DEFAULT_ROSTER_PATH
)
from app.services.college_importer import ImportValidationError

test_engine = create_engine(
    "sqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=test_engine)
    session = TestingSessionLocal()

    def override_get_db():
        try:
            yield session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db

    # Seed required class sections
    c1 = ClassSection(name="II Year CSE Cyber Security - Class 1", grade_level="II Year", academic_year="2026-2027")
    c2 = ClassSection(name="III Year CSE Cyber Security - Class 2", grade_level="III Year", academic_year="2026-2027")
    session.add_all([c1, c2])

    # Seed admin
    admin = User(
        username="admin_onboard_test",
        email="admin_onboard@test.com",
        hashed_password=get_password_hash("admin123"),
        role=UserRole.ADMIN,
        is_active=True
    )
    session.add(admin)

    # Seed demo students to verify they are preserved
    demo_u1 = User(
        username="DEV_DEMO_23CY001",
        email="demo001@college.edu",
        hashed_password=get_password_hash("student123"),
        role=UserRole.STUDENT,
        is_active=True,
        login_identifier="DEV_DEMO_23CY001"
    )
    demo_u2 = User(
        username="DEV_DEMO_23CY002",
        email="demo002@college.edu",
        hashed_password=get_password_hash("student123"),
        role=UserRole.STUDENT,
        is_active=True,
        login_identifier="DEV_DEMO_23CY002"
    )
    demo_u3 = User(
        username="DEV_DEMO_23CY003",
        email="demo003@college.edu",
        hashed_password=get_password_hash("student123"),
        role=UserRole.STUDENT,
        is_active=True,
        login_identifier="DEV_DEMO_23CY003"
    )
    session.add_all([demo_u1, demo_u2, demo_u3])
    session.flush()

    demo_s1 = Student(user_id=demo_u1.id, roll_number="DEV_DEMO_23CY001", full_name="Demo Student 001", class_id=c1.id, is_active=True)
    demo_s2 = Student(user_id=demo_u2.id, roll_number="DEV_DEMO_23CY002", full_name="Demo Student 002", class_id=c1.id, is_active=True)
    demo_s3 = Student(user_id=demo_u3.id, roll_number="DEV_DEMO_23CY003", full_name="Demo Student 003", class_id=c2.id, is_active=True)
    session.add_all([demo_s1, demo_s2, demo_s3])

    session.commit()

    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=test_engine)
        app.dependency_overrides.clear()


def get_admin_headers(db: Session):
    admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
    token = create_access_token(admin.id, role="admin")
    return {"Authorization": f"Bearer {token}"}


# ----------------------------------------------------------------------
# 1. Successful Onboarding of 64 Class 1 Students
# ----------------------------------------------------------------------
def test_onboard_class1_students_success(setup_db: Session, tmp_path):
    db = setup_db
    docx_path = str(tmp_path / "CLASS1_CREDENTIALS.docx")

    initial_student_count = db.query(Student).count()
    assert initial_student_count == 3  # 3 demo students

    result = onboard_class1_students(db, admin_user_id=1, docx_output_path=docx_path)

    assert result["status"] == "SUCCESS"
    assert result["created"] == 64
    assert result["attempted"] == 64
    assert result["capacity_used"] == 67  # 3 demo + 64 new

    # 1. Total counts
    all_students = db.query(Student).all()
    assert len(all_students) == 67
    class1_students = db.query(Student).join(ClassSection).filter(ClassSection.name == EXPECTED_CLASS_NAME).all()
    # 2 demo in Class 1 + 64 new = 66
    assert len(class1_students) == 66

    # 2. Verify all 64 new users have STUDENT role, active=True, force_password_change=True
    with open(DEFAULT_ROSTER_PATH, "r", encoding="utf-8") as f:
        roster = json.load(f)

    for item in roster:
        roll = item["roll_number"]
        st = db.query(Student).filter(Student.roll_number == roll).first()
        assert st is not None, f"Student {roll} not found"
        assert st.full_name == item["full_name"]
        assert st.is_active is True

        user = db.query(User).filter(User.username == roll).first()
        assert user is not None, f"User {roll} not found"
        assert user.role == UserRole.STUDENT
        assert user.is_active is True
        assert user.force_password_change is True
        assert user.login_identifier == roll

        # 10. Passwords are stored as bcrypt hashes, not plaintext
        assert user.hashed_password is not None
        assert user.hashed_password.startswith("$2b$") or user.hashed_password.startswith("$2a$")
        assert not user.hashed_password.startswith("student")
        assert not user.hashed_password.startswith("Temp")

    # 6 & 7. Verify Akhil
    akhil = db.query(Student).filter(Student.roll_number == "301").first()
    assert akhil is not None
    assert akhil.full_name == "Akhil"
    assert akhil.roll_number == "301"
    assert akhil.roll_number != "64"

    # 9. Existing DEV_DEMO_* records remain intact
    for demo_roll in ["DEV_DEMO_23CY001", "DEV_DEMO_23CY002", "DEV_DEMO_23CY003"]:
        d_st = db.query(Student).filter(Student.roll_number == demo_roll).first()
        assert d_st is not None, f"Demo student {demo_roll} was lost!"

    # 14. Confidential DOCX output generated
    assert os.path.exists(docx_path)
    assert os.path.getsize(docx_path) > 1000

    # Audit log recorded
    audit = db.query(AuditLog).filter(AuditLog.action == "ONBOARD_CLASS1_STUDENTS").first()
    assert audit is not None
    assert "64" in audit.details
    assert "password" not in audit.details.lower() or "forced" in audit.details.lower()
    assert "$2b$" not in audit.details


# ----------------------------------------------------------------------
# 2. Passwords are NEVER returned in normal GET endpoints
# ----------------------------------------------------------------------
def test_normal_get_endpoints_never_expose_passwords(setup_db: Session, tmp_path):
    db = setup_db
    docx_path = str(tmp_path / "CLASS1_CREDENTIALS.docx")
    onboard_class1_students(db, admin_user_id=1, docx_output_path=docx_path)

    headers = get_admin_headers(db)

    # 1. Admin list students
    res = client.get("/api/v1/admin/students", headers=headers)
    assert res.status_code == 200
    students_list = res.json()
    assert len(students_list) >= 64
    for st in students_list:
        assert "password" not in st
        assert "hashed_password" not in st
        assert st.get("temporary_password") is None

    # 2. Public / auth student endpoints
    # Attempting to login with wrong password fails
    login_res = client.post("/api/v1/auth/student/login", json={"identifier": "721025149001", "password": "wrongpassword"})
    assert login_res.status_code in (400, 401)


# ----------------------------------------------------------------------
# 3. Duplicate Roll Numbers Rejection & Idempotency Check
# ----------------------------------------------------------------------
def test_duplicate_roll_numbers_rejected_and_no_overwrite(setup_db: Session, tmp_path):
    db = setup_db
    docx_path = str(tmp_path / "CLASS1_CREDENTIALS.docx")

    # First onboarding succeeds
    onboard_class1_students(db, admin_user_id=1, docx_output_path=docx_path)

    # Second onboarding attempt fails because accounts already exist (no silent overwrite)
    with pytest.raises(ImportValidationError) as exc:
        onboard_class1_students(db, admin_user_id=1, docx_output_path=docx_path)
    assert "already exists in database" in str(exc.value.errors)


# ----------------------------------------------------------------------
# 4. Capacity Limit Enforcement (MAX_STUDENTS = 130)
# ----------------------------------------------------------------------
def test_capacity_limit_enforced_abort_and_rollback(setup_db: Session, tmp_path):
    db = setup_db
    c1 = db.query(ClassSection).filter(ClassSection.name == EXPECTED_CLASS_NAME).first()

    # Artificially create 70 dummy students to exceed capacity (70 + 3 demo = 73; 73 + 64 = 137 > 130)
    for i in range(70):
        dummy_u = User(
            username=f"DUMMY_{i:04d}",
            email=f"dummy_{i:04d}@test.com",
            hashed_password=get_password_hash("pass"),
            role=UserRole.STUDENT,
            is_active=True
        )
        db.add(dummy_u)
        db.flush()
        dummy_st = Student(user_id=dummy_u.id, roll_number=f"DUMMY_{i:04d}", full_name=f"Dummy {i}", class_id=c1.id, is_active=True)
        db.add(dummy_st)
    db.commit()

    current_count = db.query(Student).count()
    assert current_count == 73

    docx_path = str(tmp_path / "SHOULD_NOT_BE_CREATED.docx")

    with pytest.raises(ImportValidationError) as exc:
        onboard_class1_students(db, admin_user_id=1, docx_output_path=docx_path)

    assert "capacity limit exceeded" in str(exc.value.message).lower()
    # Rollback verification: no new students from the 64 roster were created
    assert db.query(Student).count() == 73
    assert db.query(Student).filter(Student.roll_number == "721025149001").first() is None
    # DOCX should not exist because transaction aborted before commit
    assert not os.path.exists(docx_path)


# ----------------------------------------------------------------------
# 5. Full Rollback on Invariant Failure
# ----------------------------------------------------------------------
def test_complete_rollback_on_failure(setup_db: Session, tmp_path):
    db = setup_db
    initial_count = db.query(Student).count()

    # Create a corrupted roster file missing a student
    corrupted_data = [
        {"roll_number": "721025149001", "student_id": None, "full_name": "Test", "class_name": EXPECTED_CLASS_NAME, "entry_type": "REGULAR"}
    ]
    corrupted_file = tmp_path / "corrupted_roster.json"
    corrupted_file.write_text(json.dumps(corrupted_data), encoding="utf-8")

    with pytest.raises(ImportValidationError) as exc:
        onboard_class1_students(db, admin_user_id=1, roster_path=str(corrupted_file))

    assert "expected 64 students" in str(exc.value.errors).lower()
    # Ensure no database changes
    assert db.query(Student).count() == initial_count


# ----------------------------------------------------------------------
# 6. Admin API Endpoint POST /admin/onboard/class1-students
# ----------------------------------------------------------------------
def test_admin_onboard_api_endpoint(setup_db: Session, tmp_path):
    db = setup_db
    headers = get_admin_headers(db)

    # Dry-run
    res_dry = client.post("/api/v1/admin/onboard/class1-students?dry_run=true", headers=headers)
    assert res_dry.status_code == 200
    body_dry = res_dry.json()
    assert body_dry["status"] == "DRY_RUN_SUCCESS"
    assert body_dry["attempted"] == 64
    assert body_dry["created"] == 0

    # Non-admin forbidden
    student_token = create_access_token(subject=2, role="student")
    res_forbidden = client.post("/api/v1/admin/onboard/class1-students", headers={"Authorization": f"Bearer {student_token}"})
    assert res_forbidden.status_code == 403

    # Actual onboarding via Admin API
    res = client.post("/api/v1/admin/onboard/class1-students", headers=headers)
    assert res.status_code == 200
    body = res.json()
    assert body["status"] == "SUCCESS"
    assert body["created"] == 64
    assert body["capacity_used"] == 67
