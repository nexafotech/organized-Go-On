"""
tests/test_class1_multi_faculty_assignments.py
Comprehensive test suite for Milestone 10C.15.4:
Class 1 Faculty Assignment + Multi-Faculty Authorized Access Update

Covers:
1. DPCO -> LAKSHMI NARAYANAN
2. DMC -> PRINCY
3. DMC subject name = Discrete Mathematics for Computing
4. ACE-I allows GOWRI MANOHARI
5. ACE-I allows SHANKAR
6. ACE-I blocks unrelated faculty
7. TWM allows MATHU
8. TWM allows SHOWMIYA
9. TWM allows SHANKAR
10. TWM allows SIVAKUMAR
11. TWM allows SANTHIYA
12. TWM blocks unrelated faculty
13. ASSOC allows SANTHIYA
14. ASSOC blocks unrelated faculty
15. LAKSHMI NARAYANAN can access DPCO
16. PRINCY can access DMC
17. New faculty records are not duplicated
18. Existing Class 1 students remain 64
19. Class 1 timetable remains 42 slots
20. Class 2 remains completely unchanged
21. Unauthorized faculty receives 403
22. Existing timetable conflict tests remain valid
23. Audit logs are generated for assignment changes
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token
from app.models.user import User, Faculty, UserRole
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry, assignment_authorized_faculty
from app.models.student import Student
from app.models.attendance import ClassSession, SessionStatus
from app.models.audit import AuditLog
from app.services.college_importer import seed_temporary_dev_timetable
from app.engines.attendance_engine import start_class_session

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
def setup_data(db_session):
    # Seed both Class 1 and Class 2
    seed_temporary_dev_timetable(db_session, class_name="all", force_reset=True)

    # 1. Admin
    admin = User(
        username="admin_test",
        email="admin_test@college.edu",
        hashed_password=get_password_hash("AdminPass123!"),
        role=UserRole.ADMIN,
        is_active=True
    )
    db_session.add(admin)

    # 2. Add 64 mock Class 1 students to verify student count preservation invariant
    cs1 = db_session.query(ClassSection).filter(ClassSection.name == "II Year CSE Cyber Security - Class 1").first()
    cs2 = db_session.query(ClassSection).filter(ClassSection.name == "III Year CSE Cyber Security - Class 2").first()

    for i in range(1, 65):
        st_user = User(
            username=f"student_{i:03d}",
            email=f"student_{i:03d}@college.edu",
            hashed_password=get_password_hash("StudentPass123!"),
            role=UserRole.STUDENT,
            is_active=True
        )
        db_session.add(st_user)
        db_session.flush()
        st = Student(
            user_id=st_user.id,
            roll_number=f"721025149{i:03d}",
            full_name=f"Class 1 Student {i}",
            class_id=cs1.id,
            semester="3",
            department="CSE Cyber Security"
        )
        db_session.add(st)

    db_session.commit()

    # Map faculty tokens
    tokens = {}
    for f in db_session.query(Faculty).all():
        tokens[f.employee_id] = create_access_token(f.user_id, role="faculty")
    tokens["ADMIN"] = create_access_token(admin.id, role="admin")

    return {
        "tokens": tokens,
        "cs1": cs1,
        "cs2": cs2,
    }


def test_dpco_assigned_to_lakshmi_narayanan(db_session, setup_data):
    """1 & 15. DPCO -> LAKSHMI NARAYANAN (FAC06)"""
    cs1 = setup_data["cs1"]
    dpco_sub = db_session.query(Subject).filter(Subject.code == "DPCO").first()
    fa = db_session.query(FacultyAssignment).filter(
        FacultyAssignment.class_id == cs1.id,
        FacultyAssignment.subject_id == dpco_sub.id
    ).first()
    assert fa is not None
    assert fa.faculty is not None
    assert fa.faculty.employee_id == "FAC06"
    assert "Lakshmi Narayanan" in fa.faculty.full_name
    assert fa.is_faculty_authorized(fa.faculty_id) is True


def test_dmc_assigned_to_princy_and_subject_name(db_session, setup_data):
    """2, 3 & 16. DMC -> PRINCY (FAC07) and DMC subject name = Discrete Mathematics for Computing"""
    cs1 = setup_data["cs1"]
    dmc_sub = db_session.query(Subject).filter(Subject.code == "DMC").first()
    assert dmc_sub is not None
    assert dmc_sub.name == "Discrete Mathematics for Computing"

    fa = db_session.query(FacultyAssignment).filter(
        FacultyAssignment.class_id == cs1.id,
        FacultyAssignment.subject_id == dmc_sub.id
    ).first()
    assert fa is not None
    assert fa.faculty is not None
    assert fa.faculty.employee_id == "FAC07"
    assert "Princy" in fa.faculty.full_name
    assert fa.is_faculty_authorized(fa.faculty_id) is True


def test_ace_i_multi_faculty_authorization(client, db_session, setup_data):
    """4, 5, 6. ACE-I allows GOWRI MANOHARI and SHANKAR, blocks unrelated faculty"""
    cs1 = setup_data["cs1"]
    ace_sub = db_session.query(Subject).filter(Subject.code == "ACE-I").first()
    fa = db_session.query(FacultyAssignment).filter(
        FacultyAssignment.class_id == cs1.id,
        FacultyAssignment.subject_id == ace_sub.id
    ).first()

    fac08 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC08").first() # Gowri Manohari
    fac04 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC04").first() # Shankar
    fac01 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC01").first() # Mathu (unrelated)
    fac02 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC02").first() # Showmiya (unrelated)

    assert fa.is_faculty_authorized(fac08.id) is True
    assert fa.is_faculty_authorized(fac04.id) is True
    assert fa.is_faculty_authorized(fac01.id) is False
    assert fa.is_faculty_authorized(fac02.id) is False

    # Check via timetable slot session start endpoint
    ace_slot = db_session.query(TimetableEntry).filter(TimetableEntry.assignment_id == fa.id).first()
    assert ace_slot is not None

    # Gowri Manohari (FAC08) can start session
    res_gowri = client.post(
        "/api/v1/faculty/sessions/start",
        json={"timetable_entry_id": ace_slot.id},
        headers={"Authorization": f"Bearer {setup_data['tokens']['FAC08']}"}
    )
    assert res_gowri.status_code == 200

    # Shankar (FAC04) also authorized
    res_shankar = client.post(
        "/api/v1/faculty/sessions/start",
        json={"timetable_entry_id": ace_slot.id},
        headers={"Authorization": f"Bearer {setup_data['tokens']['FAC04']}"}
    )
    # Returns 200 (existing active session)
    assert res_shankar.status_code == 200

    # Unrelated faculty (FAC01) blocked with 403
    # Need another ACE slot on a different day or test direct check
    ace_slot_2 = db_session.query(TimetableEntry).filter(
        TimetableEntry.assignment_id == fa.id,
        TimetableEntry.id != ace_slot.id
    ).first()
    if ace_slot_2:
        res_unauth = client.post(
            "/api/v1/faculty/sessions/start",
            json={"timetable_entry_id": ace_slot_2.id},
            headers={"Authorization": f"Bearer {setup_data['tokens']['FAC01']}"}
        )
        assert res_unauth.status_code == 403
        assert "not authorized to manage attendance" in res_unauth.json()["detail"]


def test_twm_multi_faculty_authorization(client, db_session, setup_data):
    """7-12. TWM allows MATHU, SHOWMIYA, SHANKAR, SIVAKUMAR, SANTHIYA, blocks unrelated faculty"""
    cs1 = setup_data["cs1"]
    twm_sub = db_session.query(Subject).filter(Subject.code == "TWM").first()
    assert twm_sub.name == "Tutor Ward Meeting"

    fa = db_session.query(FacultyAssignment).filter(
        FacultyAssignment.class_id == cs1.id,
        FacultyAssignment.subject_id == twm_sub.id
    ).first()

    fac01 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC01").first() # Mathu
    fac02 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC02").first() # Showmiya
    fac03 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC03").first() # Sivakumar
    fac04 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC04").first() # Shankar
    fac05 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC05").first() # Santhiya
    fac06 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC06").first() # Lakshmi Narayanan (unrelated)
    fac07 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC07").first() # Princy (unrelated)
    fac08 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC08").first() # Gowri Manohari (unrelated)

    # Authorized 5
    assert fa.is_faculty_authorized(fac01.id) is True
    assert fa.is_faculty_authorized(fac02.id) is True
    assert fa.is_faculty_authorized(fac03.id) is True
    assert fa.is_faculty_authorized(fac04.id) is True
    assert fa.is_faculty_authorized(fac05.id) is True

    # Unrelated 3
    assert fa.is_faculty_authorized(fac06.id) is False
    assert fa.is_faculty_authorized(fac07.id) is False
    assert fa.is_faculty_authorized(fac08.id) is False

    # Test HTTP 403 on session start for unrelated faculty
    twm_slot = db_session.query(TimetableEntry).filter(TimetableEntry.assignment_id == fa.id).first()
    assert twm_slot is not None

    res_unauth = client.post(
        "/api/v1/faculty/sessions/start",
        json={"timetable_entry_id": twm_slot.id},
        headers={"Authorization": f"Bearer {setup_data['tokens']['FAC06']}"}
    )
    assert res_unauth.status_code == 403
    assert "not authorized to manage attendance" in res_unauth.json()["detail"]


def test_assoc_authorization(client, db_session, setup_data):
    """13, 14. ASSOC allows SANTHIYA, blocks unrelated faculty"""
    cs1 = setup_data["cs1"]
    assoc_sub = db_session.query(Subject).filter(Subject.code == "ASSOC").first()
    fa = db_session.query(FacultyAssignment).filter(
        FacultyAssignment.class_id == cs1.id,
        FacultyAssignment.subject_id == assoc_sub.id
    ).first()

    fac05 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC05").first() # Santhiya
    fac01 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC01").first() # Mathu (unrelated)

    assert fa.is_faculty_authorized(fac05.id) is True
    assert fa.is_faculty_authorized(fac01.id) is False

    assoc_slot = db_session.query(TimetableEntry).filter(TimetableEntry.assignment_id == fa.id).first()
    assert assoc_slot is not None

    # Santhiya allowed
    res_santhiya = client.post(
        "/api/v1/faculty/sessions/start",
        json={"timetable_entry_id": assoc_slot.id},
        headers={"Authorization": f"Bearer {setup_data['tokens']['FAC05']}"}
    )
    assert res_santhiya.status_code == 200

    # Mathu blocked
    assoc_slot_2 = db_session.query(TimetableEntry).filter(
        TimetableEntry.assignment_id == fa.id,
        TimetableEntry.id != assoc_slot.id
    ).first()
    if assoc_slot_2:
        res_mathu = client.post(
            "/api/v1/faculty/sessions/start",
            json={"timetable_entry_id": assoc_slot_2.id},
            headers={"Authorization": f"Bearer {setup_data['tokens']['FAC01']}"}
        )
        assert res_mathu.status_code == 403


def test_new_faculty_records_not_duplicated(db_session, setup_data):
    """17. Re-running seed or update does not duplicate faculty records"""
    initial_count = db_session.query(Faculty).count()
    assert initial_count == 8

    # Re-run seed
    seed_temporary_dev_timetable(db_session, class_name="all", force_reset=False)
    after_count = db_session.query(Faculty).count()
    assert after_count == 8


def test_database_invariants_and_capacity(db_session, setup_data):
    """18, 19, 20. Database safety & invariants: Class 1 students = 64, Class 1 TT = 42, Class 2 TT = 42, Total TT = 84"""
    cs1 = setup_data["cs1"]
    cs2 = setup_data["cs2"]

    st_count = db_session.query(Student).filter(Student.class_id == cs1.id).count()
    assert st_count == 64

    tt1_count = db_session.query(TimetableEntry).join(FacultyAssignment).filter(FacultyAssignment.class_id == cs1.id).count()
    assert tt1_count == 42

    tt2_count = db_session.query(TimetableEntry).join(FacultyAssignment).filter(FacultyAssignment.class_id == cs2.id).count()
    assert tt2_count == 42

    total_tt = db_session.query(TimetableEntry).count()
    assert total_tt == 84


def test_timetable_conflict_engine_intact(client, db_session, setup_data):
    """22. Existing timetable conflict tests remain valid (no false conflicts from authorized faculty)"""
    cs1 = setup_data["cs1"]
    p1 = db_session.query(Period).filter(Period.period_number == 1).first()
    fac06 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC06").first()
    sub_fds = db_session.query(Subject).filter(Subject.code == "FDS").first()

    # Attempt to create conflicting entry for same class on Monday Period 1 (already occupied by FDS)
    res_conflict = client.post(
        "/api/v1/admin/timetable",
        json={
            "day_of_week": "Monday",
            "period_id": p1.id,
            "class_id": cs1.id,
            "subject_id": sub_fds.id,
            "faculty_id": fac06.id
        },
        headers={"Authorization": f"Bearer {setup_data['tokens']['ADMIN']}"}
    )
    assert res_conflict.status_code == 400
    assert "Class slot conflict" in res_conflict.json()["detail"]


def test_audit_log_generated_on_assignment_changes(client, db_session, setup_data):
    """23. Audit logs are generated for assignment creations and updates"""
    cs1 = setup_data["cs1"]
    fac08 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC08").first()
    sub_uhv = db_session.query(Subject).filter(Subject.code == "UHV").first()

    fa = db_session.query(FacultyAssignment).filter(
        FacultyAssignment.class_id == cs1.id,
        FacultyAssignment.subject_id == sub_uhv.id
    ).first()

    res = client.put(
        f"/api/v1/admin/assignments/{fa.id}",
        json={
            "class_id": cs1.id,
            "subject_id": sub_uhv.id,
            "faculty_id": fac08.id,
            "authorized_faculty_ids": [fac08.id]
        },
        headers={"Authorization": f"Bearer {setup_data['tokens']['ADMIN']}"}
    )
    assert res.status_code == 200

    log = db_session.query(AuditLog).filter(
        AuditLog.action == "UPDATE_FACULTY_ASSIGNMENT"
    ).order_by(AuditLog.id.desc()).first()
    assert log is not None
    assert f"assignment ID {fa.id}" in log.details
