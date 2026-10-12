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
from app.services.class2_onboarding_service import (
    onboard_class2_students,
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

    # Seed existing 64 Class 1 students to test capacity check (64 + 55 = 119 <= 130)
    for i in range(1, 65):
        u = User(
            username=f"c1_user_{i:03d}",
            email=f"c1_{i:03d}@test.local",
            hashed_password="mock_hashed_password",
            role=UserRole.STUDENT,
            is_active=True
        )
        session.add(u)
        session.flush()
        st = Student(
            user_id=u.id,
            roll_number=f"721025149{i:03d}",
            full_name=f"Class 1 Student {i}",
            class_id=c1.id,
            department="CSE Cyber Security",
            semester="3",
            is_active=True
        )
        session.add(st)

    session.commit()
    session.close()

    yield

    Base.metadata.drop_all(bind=test_engine)
    app.dependency_overrides.clear()


def test_1_temporary_password_generator_strength():
    """Verify cryptographically secure password properties (length, symbol, digit, upper, lower)."""
    for length in [5, 8, 12]:
        pwd = generate_secure_temporary_password(length)
        assert len(pwd) == length
        assert any(c.isupper() for c in pwd)
        assert any(c.islower() for c in pwd)
        assert any(c.isdigit() for c in pwd)
        assert any(c in "!@#$%^&*" for c in pwd)


def test_2_dry_run_validation_does_not_modify_database():
    """Dry run verifies all 55 records and capacity without committing rows."""
    session = TestingSessionLocal()
    admin = session.query(User).filter(User.role == UserRole.ADMIN).first()

    initial_students = session.query(Student).count()
    initial_users = session.query(User).count()
    assert initial_students == 64

    res = onboard_class2_students(db=session, admin_user_id=admin.id, dry_run=True)
    assert res["status"] == "DRY_RUN_SUCCESS"
    assert res["attempted"] == 55
    assert res["created"] == 55
    assert res["existing_skipped"] == 0
    assert res["capacity_current"] == 64
    assert res["capacity_projected"] == 119

    # Confirm 0 rows written
    assert session.query(Student).count() == initial_students
    assert session.query(User).count() == initial_users
    session.close()


def test_3_successful_onboarding_and_database_invariants(tmp_path):
    """Full execution creates exactly 55 Class 2 students with accounts, DOCX, and audit log."""
    session = TestingSessionLocal()
    admin = session.query(User).filter(User.role == UserRole.ADMIN).first()
    docx_file = str(tmp_path / "CLASS2_TEST_CREDENTIALS.docx")

    res = onboard_class2_students(
        db=session,
        admin_user_id=admin.id,
        docx_output_path=docx_file,
        dry_run=False
    )

    assert res["status"] == "SUCCESS"
    assert res["created"] == 55
    assert res["capacity_used"] == 119
    assert res["capacity_remaining"] == 11

    # Database counts
    c2_sec = session.query(ClassSection).filter(ClassSection.name == EXPECTED_CLASS_NAME).first()
    c1_sec = session.query(ClassSection).filter(ClassSection.name == "II Year CSE Cyber Security - Class 1").first()

    c2_students = session.query(Student).filter(Student.class_id == c2_sec.id).all()
    c1_students = session.query(Student).filter(Student.class_id == c1_sec.id).all()
    all_students = session.query(Student).all()
    all_users = session.query(User).all()

    assert len(c2_students) == 55
    assert len(c1_students) == 64
    assert len(all_students) == 119

    # Student accounts
    student_users = [u for u in all_users if u.role == UserRole.STUDENT]
    assert len(student_users) == 119

    # Verify Class 2 specific attributes
    for st in c2_students:
        assert st.department == "CSE Cyber Security"
        assert st.semester == "5"
        assert st.is_active is True
        assert st.user is not None
        assert st.user.role == UserRole.STUDENT
        assert st.user.username == st.roll_number
        assert st.user.login_identifier == st.roll_number
        assert st.user.force_password_change is True
        assert st.user.is_active is True

    # Audit log check
    audit = session.query(AuditLog).filter(AuditLog.action == "ONBOARD_CLASS2_STUDENTS").first()
    assert audit is not None
    assert "55 student accounts" in audit.details

    # DOCX file created
    assert os.path.exists(docx_file)
    assert os.path.getsize(docx_file) > 1000

    session.close()


def test_4_idempotent_reconciliation_skips_duplicates():
    """Re-running onboarding on an already onboarded database skips duplicates and verifies records."""
    session = TestingSessionLocal()
    admin = session.query(User).filter(User.role == UserRole.ADMIN).first()

    # First run
    res1 = onboard_class2_students(db=session, admin_user_id=admin.id, docx_output_path=None, dry_run=False)
    assert res1["created"] == 55

    # Second run
    res2 = onboard_class2_students(db=session, admin_user_id=admin.id, docx_output_path=None, dry_run=False)
    assert res2["status"] == "SUCCESS"
    assert res2["created"] == 0
    assert res2["existing_skipped"] == 55
    assert session.query(Student).count() == 119

    session.close()


def test_5_capacity_overflow_rejected():
    """Attempting to onboard beyond MAX_SYSTEM_STUDENTS (130) raises ImportValidationError."""
    session = TestingSessionLocal()
    admin = session.query(User).filter(User.role == UserRole.ADMIN).first()
    c1_sec = session.query(ClassSection).filter(ClassSection.name == "II Year CSE Cyber Security - Class 1").first()

    # Add 20 more dummy students so count becomes 84 (84 + 55 = 139 > 130)
    for i in range(100, 120):
        u = User(username=f"extra_{i}", email=f"extra_{i}@test.local", hashed_password="pw", role=UserRole.STUDENT)
        session.add(u)
        session.flush()
        st = Student(user_id=u.id, roll_number=f"extra_{i}", full_name=f"Extra {i}", class_id=c1_sec.id)
        session.add(st)
    session.commit()

    with pytest.raises(ImportValidationError) as exc_info:
        onboard_class2_students(db=session, admin_user_id=admin.id, dry_run=False)
    assert "capacity limit exceeded" in str(exc_info.value.message).lower()

    session.close()
