import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token
from app.models.user import User, UserRole
from app.models.student import Student
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment
from app.services.college_importer import (
    import_class_sections, import_periods, import_subjects,
    import_students, import_faculty_assignments, import_timetable,
    import_college_seed_bundle, reset_demo_academic_configuration,
    ImportValidationError
)

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
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=test_engine)
        app.dependency_overrides.clear()

def get_admin_token_headers(db: Session):
    admin = db.query(User).filter(User.username == "admin_import_test").first()
    if not admin:
        admin = User(
            username="admin_import_test",
            email="admin_import_unique@test.com",
            hashed_password=get_password_hash("admin123"),
            role=UserRole.ADMIN,
            is_active=True
        )
        db.add(admin)
        db.commit()
    token = create_access_token(admin.id, role="admin")
    return {"Authorization": f"Bearer {token}"}

def get_student_token_headers(db: Session):
    student_user = db.query(User).filter(User.username == "STU_IMP_001").first()
    if not student_user:
        student_user = User(
            username="STU_IMP_001",
            email="student_import_unique@test.com",
            hashed_password=get_password_hash("student123"),
            role=UserRole.STUDENT,
            is_active=True,
            login_identifier="STU_IMP_001"
        )
        db.add(student_user)
        db.flush()

        st_profile = Student(
            user_id=student_user.id,
            roll_number="STU_IMP_001",
            full_name="Student Import Test",
            is_active=True
        )
        db.add(st_profile)
        db.commit()

    token = create_access_token(student_user.id, role="student")
    return {"Authorization": f"Bearer {token}"}



class TestCollegeSeedAndImports:

    def test_clean_database_official_seed_success(self, setup_db: Session):
        """Test A: Clean database + official seed -> SUCCESS"""
        db = setup_db
        results = import_college_seed_bundle(db, seed_dir="college_seed")
        assert "class_sections" in results
        assert "periods" in results
        assert "subjects" in results
        assert "timetable_entries" in results

        assert results["class_sections"]["imported"] > 0
        assert results["periods"]["imported"] > 0
        assert results["subjects"]["imported"] > 0

        # Verify Class 1 & Class 2 exist with academic year 2026-2027
        c1 = db.query(ClassSection).filter(ClassSection.name == "II Year CSE Cyber Security - Class 1").first()
        assert c1 is not None and c1.academic_year == "2026-2027"

        c2 = db.query(ClassSection).filter(ClassSection.name == "III Year CSE Cyber Security - Class 2").first()
        assert c2 is not None and c2.academic_year == "2026-2027"

        # Verify confirmed subject FDS exists
        fds = db.query(Subject).filter(Subject.code == "FDS").first()
        assert fds is not None

    def test_same_seed_second_time_idempotent(self, setup_db: Session):
        """Test B: Running exact same seed a second time -> SUCCESS (skipped_existing > 0, imported == 0)"""
        db = setup_db
        import_college_seed_bundle(db, seed_dir="college_seed")

        results2 = import_college_seed_bundle(db, seed_dir="college_seed")
        assert results2["class_sections"]["imported"] == 0
        assert results2["class_sections"]["skipped_existing"] > 0
        assert results2["periods"]["imported"] == 0
        assert results2["periods"]["skipped_existing"] > 0
        assert results2["subjects"]["imported"] == 0
        assert results2["subjects"]["skipped_existing"] > 0

    def test_unassigned_faculty_mapping_is_skipped(self, setup_db: Session):
        """Test C: Seed containing unassigned faculty mapping is skipped without IntegrityError"""
        db = setup_db
        import_class_sections(db, [{"name": "ClassUnassignedTest", "grade_level": "II Year", "academic_year": "2026-2027"}])
        import_subjects(db, [{"code": "UNASSIGN_SUBJ", "name": "Unassigned Subject"}])
        db.commit()

        unassigned_items = [{
            "class_name": "ClassUnassignedTest",
            "subject_code": "UNASSIGN_SUBJ",
            "faculty_username": None
        }]

        res = import_faculty_assignments(db, unassigned_items)
        db.commit()

        assert res["imported"] == 0
        assert res["skipped_unassigned"] == 1

        null_fa = db.query(FacultyAssignment).filter(FacultyAssignment.faculty_id.is_(None)).first()
        assert null_fa is None

    def test_conflicting_period_timing_rejected(self, setup_db: Session):
        """Test D: Conflicting period timing -> REJECTED"""
        db = setup_db
        import_periods(db, [{"period_number": 4, "name": "Period 4", "start_time": "12:00", "end_time": "12:50"}])
        db.commit()

        conflicting = [{"period_number": 4, "name": "Period 4", "start_time": "12:50", "end_time": "13:40"}]
        with pytest.raises(ImportValidationError) as exc:
            import_periods(db, conflicting)
        assert "already exists" in str(exc.value.errors) or "conflict" in str(exc.value.errors)

    def test_duplicate_period_inside_input_rejected(self, setup_db: Session):
        """Test E: Duplicate period inside same input array -> REJECTED"""
        db = setup_db
        duplicate_input = [
            {"period_number": 99, "name": "Period 99A", "start_time": "17:00", "end_time": "17:50"},
            {"period_number": 99, "name": "Period 99B", "start_time": "17:00", "end_time": "17:50"}
        ]
        with pytest.raises(ImportValidationError) as exc:
            import_periods(db, duplicate_input)
        assert "Duplicate period_number 99 in input batch" in str(exc.value.errors)

    def test_duplicate_class_section_rejection(self, setup_db: Session):
        db = setup_db
        items = [{"name": "UniqueClass1", "grade_level": "II Year", "academic_year": "2026-2027"}]
        import_class_sections(db, items)
        db.commit()

        conflict_items = [{"name": "UniqueClass1", "grade_level": "II Year", "academic_year": "2029-2030"}]
        with pytest.raises(ImportValidationError) as exc:
            import_class_sections(db, conflict_items)
        assert "already exists" in str(exc.value.errors)

    def test_duplicate_subject_rejection(self, setup_db: Session):
        db = setup_db
        items = [{"code": "TEST_SUBJ", "name": "Test Subject"}]
        import_subjects(db, items)
        db.commit()

        conflict_items = [{"code": "TEST_SUBJ", "name": "Conflicting Name"}]
        with pytest.raises(ImportValidationError) as exc:
            import_subjects(db, conflict_items)
        assert "already exists" in str(exc.value.errors)

    def test_duplicate_student_roll_number_rejection(self, setup_db: Session):
        db = setup_db
        items = [{
            "roll_number": "ROLL_DUP_001",
            "full_name": "Test Dup Student",
            "email": "dup@test.com",
            "password": "pass"
        }]
        import_students(db, items)
        db.commit()

        conflict_items = [{
            "roll_number": "ROLL_DUP_001",
            "full_name": "Different Student Name",
            "email": "dup2@test.com",
            "password": "pass"
        }]
        with pytest.raises(ImportValidationError) as exc:
            import_students(db, conflict_items)
        assert "already exists" in str(exc.value.errors)

    def test_admin_import_api_authorization(self, setup_db: Session):
        student_headers = get_student_token_headers(setup_db)
        res = client.post("/api/v1/admin/import/classes", json=[{"name": "FailClass"}], headers=student_headers)
        assert res.status_code == 403

    def test_admin_import_api_success(self, setup_db: Session):
        admin_headers = get_admin_token_headers(setup_db)
        items = [{"name": "AdminImportClass1", "grade_level": "I Year", "academic_year": "2026-2027"}]
        res = client.post("/api/v1/admin/import/classes", json=items, headers=admin_headers)
        assert res.status_code == 200
        body = res.json()
        assert body["imported"] == 1 or body["skipped_existing"] == 1
        assert body["conflicts"] == 0
        assert body["errors"] == []
