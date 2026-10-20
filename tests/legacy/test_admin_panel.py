import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy import create_engine
from sqlalchemy.pool import StaticPool

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash
from app.models.user import User, Faculty, UserRole
from app.models.student import Student
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment
from app.models.audit import AuditLog
from app.services.college_importer import reset_demo_academic_configuration

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
    def _override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()
    app.dependency_overrides[get_db] = _override_get_db

    db = TestingSessionLocal()
    try:
        reset_demo_academic_configuration(db)
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()

    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.rollback()
        session.close()
        Base.metadata.drop_all(bind=test_engine)
        app.dependency_overrides.pop(get_db, None)


def get_admin_headers():
    db = TestingSessionLocal()
    try:
        admin = db.query(User).filter(User.username == "admin_panel_test").first()
        if not admin:
            admin = User(
                username="admin_panel_test",
                email="admin_panel_test@college.edu",
                hashed_password=get_password_hash("admin123"),
                role=UserRole.ADMIN,
                is_active=True
            )
            db.add(admin)
            db.commit()
    finally:
        db.close()

    res = client.post("/api/v1/auth/login", json={"username_or_email": "admin_panel_test", "password": "admin123"})
    assert res.status_code == 200
    token = res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def get_student_headers():
    db = TestingSessionLocal()
    try:
        student_user = db.query(User).filter(User.username == "STU_PANEL_001").first()
        if not student_user:
            student_user = User(
                username="STU_PANEL_001",
                email="stu_panel_001@college.edu",
                hashed_password=get_password_hash("student123"),
                role=UserRole.STUDENT,
                is_active=True,
                login_identifier="STU_PANEL_001"
            )
            db.add(student_user)
            db.flush()

        st_profile = db.query(Student).filter(Student.user_id == student_user.id).first()
        if not st_profile:
            st_profile = Student(
                user_id=student_user.id,
                roll_number="STU_PANEL_001",
                full_name="Student Panel Test",
                is_active=True
            )
            db.add(st_profile)
        db.commit()
    finally:
        db.close()

    res = client.post("/api/v1/auth/student/login", json={"identifier": "STU_PANEL_001", "password": "student123"})
    assert res.status_code == 200
    token = res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


class TestAdminPanelAPI:

    def test_dashboard_stats_admin_authorized(self, setup_db: Session):
        headers = get_admin_headers()
        res = client.get("/api/v1/admin/dashboard-stats", headers=headers)
        assert res.status_code == 200
        data = res.json()
        assert "total_students" in data
        assert "total_faculty" in data
        assert "total_classes" in data
        assert "active_sessions" in data
        assert "attendance_stats" in data
        assert "recent_audit" in data

    def test_dashboard_stats_student_forbidden(self):
        headers = get_student_headers()
        res = client.get("/api/v1/admin/dashboard-stats", headers=headers)
        assert res.status_code == 403

    def test_update_class_section(self, setup_db: Session):
        headers = get_admin_headers()
        # Create class
        res = client.post("/api/v1/admin/classes", json={"name": "ClassUpdateTest", "grade_level": "I Year", "academic_year": "2026-2027"}, headers=headers)
        assert res.status_code == 201
        cls_id = res.json()["id"]

        # Update class
        update_res = client.put(f"/api/v1/admin/classes/{cls_id}", json={"name": "ClassUpdateTestRenamed", "grade_level": "II Year", "academic_year": "2026-2027"}, headers=headers)
        assert update_res.status_code == 200
        assert update_res.json()["name"] == "ClassUpdateTestRenamed"
        assert update_res.json()["grade_level"] == "II Year"

    def test_update_subject(self, setup_db: Session):
        headers = get_admin_headers()
        res = client.post("/api/v1/admin/subjects", json={"code": "SUBJ_UP", "name": "Subject Update Test"}, headers=headers)
        assert res.status_code == 201
        sub_id = res.json()["id"]

        update_res = client.put(f"/api/v1/admin/subjects/{sub_id}", json={"code": "SUBJ_UP_RENAMED", "name": "Subject Updated Name", "description": "New syllabus"}, headers=headers)
        assert update_res.status_code == 200
        assert update_res.json()["code"] == "SUBJ_UP_RENAMED"

    def test_period_creation_and_overlap_rejection(self, setup_db: Session):
        headers = get_admin_headers()
        # Period 81: 05:00-05:50
        res1 = client.post("/api/v1/admin/periods", json={"period_number": 81, "name": "P81", "start_time": "05:00", "end_time": "05:50"}, headers=headers)
        assert res1.status_code == 201

        # Period 82: 05:50-06:40 is NOT overlapping (05:00-05:50 vs 05:50-06:40)
        res2 = client.post("/api/v1/admin/periods", json={"period_number": 82, "name": "P82", "start_time": "05:50", "end_time": "06:40"}, headers=headers)
        assert res2.status_code == 201

        # Overlapping period: 05:30-06:20 (overlaps P81 and P82) -> REJECTED 400
        res_overlap = client.post("/api/v1/admin/periods", json={"period_number": 83, "name": "P83", "start_time": "05:30", "end_time": "06:20"}, headers=headers)
        assert res_overlap.status_code == 400
        assert "overlap" in res_overlap.json()["detail"]

    def test_toggle_faculty_active_and_force_pw_change(self, setup_db: Session):
        headers = get_admin_headers()
        # Clean up any leftover test data
        setup_db.query(Faculty).filter(Faculty.employee_id == "FAC_PANEL_001").delete()
        setup_db.query(User).filter(User.username == "fac_panel_001").delete()
        setup_db.commit()

        # Create faculty
        fac_res = client.post("/api/v1/admin/faculty", json={
            "employee_id": "FAC_PANEL_001",
            "full_name": "Panel Faculty",
            "department": "CSE",
            "username": "fac_panel_001",
            "email": "fac_panel_001@college.edu",
            "password": "faculty123"
        }, headers=headers)
        assert fac_res.status_code == 201
        fac_id = fac_res.json()["id"]

        # Toggle active
        toggle_res = client.post(f"/api/v1/admin/faculty/{fac_id}/toggle-active", headers=headers)
        assert toggle_res.status_code == 200
        assert toggle_res.json()["is_active"] is False

        # Toggle force password change
        force_res = client.post(f"/api/v1/admin/faculty/{fac_id}/force-password-change", headers=headers)
        assert force_res.status_code == 200
        assert force_res.json()["force_password_change"] is True

    def test_toggle_student_active_and_force_pw_change(self, setup_db: Session):
        headers = get_admin_headers()
        # Clean up any leftover test data
        setup_db.query(Student).filter(Student.roll_number == "STU_TOGGLE_001").delete()
        setup_db.query(User).filter(User.username.in_(["STU_TOGGLE_001", "stu_toggle_001"])).delete()
        setup_db.commit()

        stu_res = client.post("/api/v1/admin/students/with-account", json={
            "roll_number": "STU_TOGGLE_001",
            "full_name": "Toggle Student",
            "email": "stu_toggle_001@college.edu",
            "password": "student123"
        }, headers=headers)
        assert stu_res.status_code == 201
        stu_id = stu_res.json()["id"]

        toggle_res = client.post(f"/api/v1/admin/students/{stu_id}/toggle-active", headers=headers)
        assert toggle_res.status_code == 200
        assert toggle_res.json()["is_active"] is False

        force_res = client.post(f"/api/v1/admin/students/{stu_id}/force-password-change", headers=headers)
        assert force_res.status_code == 200
        assert force_res.json()["force_password_change"] is True

    def test_list_unassigned_assignments(self, setup_db: Session):
        headers = get_admin_headers()
        # Create a class and subject
        c_res = client.post("/api/v1/admin/classes", json={"name": "UnassignedClassTest", "grade_level": "I Year", "academic_year": "2026-2027"}, headers=headers)
        s_res = client.post("/api/v1/admin/subjects", json={"code": "UNAS_CODE", "name": "Unassigned Subject Name"}, headers=headers)
        assert c_res.status_code == 201
        assert s_res.status_code == 201

        # Create unassigned assignment
        a_res = client.post("/api/v1/admin/assignments", json={"class_id": c_res.json()["id"], "subject_id": s_res.json()["id"], "faculty_id": None}, headers=headers)
        assert a_res.status_code == 201

        res = client.get("/api/v1/admin/assignments/unassigned", headers=headers)
        assert res.status_code == 200
        unassigned_list = res.json()
        match = [u for u in unassigned_list if u["subject_code"] == "UNAS_CODE" and u["class_name"] == "UnassignedClassTest"]
        assert len(match) == 1

    def test_admin_web_page_redirect_unauthorized(self):
        # GET /admin serves the Admin Management Console directly with in-place auth
        res = client.get("/admin", follow_redirects=False)
        assert res.status_code == 200
        assert "Admin Management Console" in res.text
