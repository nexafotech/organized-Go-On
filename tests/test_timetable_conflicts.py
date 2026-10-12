"""
tests/test_timetable_conflicts.py
Comprehensive test suite for Milestone 10C.13.2 — Timetable & Faculty Conflict Detection:
1. Same class/day/period rejected (Class Slot Conflict).
2. Same faculty/same day/same period rejected across Class 1 & Class 2 (Faculty Double-Booking).
3. Same faculty overlapping periods rejected.
4. Different classes + different faculty + same period allowed (Valid parallel classes).
5. Pending faculty does not cause conflict.
6. Conflict on POST create timetable rejected.
7. Conflict on PUT update timetable rejected.
8. Conflict on POST move timetable rejected.
9. Conflict on POST duplicate timetable rejected.
10. Valid move accepted.
11. Valid duplicate accepted.
12. Database remains unchanged after rejected operation.
13. Class 1 and Class 2 conflict checks work together.
14. Audit behavior remains correct.
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
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.audit import AuditLog
from app.services.college_importer import seed_temporary_dev_timetable

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
def test_data(db_session):
    # Seed both Class 1 and Class 2 temporary dev timetable (84 entries total)
    seed_result = seed_temporary_dev_timetable(db_session, class_name="all", force_reset=True)

    # 1. Admin User
    admin = User(
        username="admin_conflict_tester",
        email="admin_conflict@college.edu",
        hashed_password=get_password_hash("AdminPass123!"),
        role=UserRole.ADMIN,
        is_active=True
    )
    db_session.add(admin)

    # 2. Get Class Sections
    cs1 = db_session.query(ClassSection).filter(ClassSection.name == "II Year CSE Cyber Security - Class 1").first()
    cs2 = db_session.query(ClassSection).filter(ClassSection.name == "III Year CSE Cyber Security - Class 2").first()

    # 3. Student & Faculty Users for RBAC tests
    student_user = User(
        username="stu_conflict_001",
        email="stu_conflict@college.edu",
        hashed_password=get_password_hash("StudentPass123!"),
        role=UserRole.STUDENT,
        is_active=True
    )
    db_session.add(student_user)

    db_session.commit()
    db_session.refresh(admin)
    db_session.refresh(student_user)

    admin_token = create_access_token(subject=str(admin.id), role="ADMIN")
    student_token = create_access_token(subject=str(student_user.id), role="STUDENT")

    # Faculty objects
    fac01 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC01").first()
    fac02 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC02").first()
    fac03 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC03").first()
    fac04 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC04").first()
    fac05 = db_session.query(Faculty).filter(Faculty.employee_id == "FAC05").first()

    # Periods
    p1 = db_session.query(Period).filter(Period.period_number == 1).first()
    p2 = db_session.query(Period).filter(Period.period_number == 2).first()
    p3 = db_session.query(Period).filter(Period.period_number == 3).first()
    p4 = db_session.query(Period).filter(Period.period_number == 4).first()
    p5 = db_session.query(Period).filter(Period.period_number == 5).first()
    p6 = db_session.query(Period).filter(Period.period_number == 6).first()
    p7 = db_session.query(Period).filter(Period.period_number == 7).first()

    # Subjects
    sub_dmc = db_session.query(Subject).filter(Subject.code == "DMC").first()
    sub_ds = db_session.query(Subject).filter(Subject.code == "DS").first()
    sub_oops = db_session.query(Subject).filter(Subject.code == "OOPS").first()
    sub_cf = db_session.query(Subject).filter(Subject.code == "CF").first()
    sub_aiml = db_session.query(Subject).filter(Subject.code == "AIML").first()
    sub_twm = db_session.query(Subject).filter(Subject.code == "TWM").first()

    return {
        "admin": admin,
        "admin_headers": {"Authorization": f"Bearer {admin_token}"},
        "student_headers": {"Authorization": f"Bearer {student_token}"},
        "cs1": cs1,
        "cs2": cs2,
        "fac01": fac01,
        "fac02": fac02,
        "fac03": fac03,
        "fac04": fac04,
        "fac05": fac05,
        "p1": p1,
        "p2": p2,
        "p3": p3,
        "p4": p4,
        "p5": p5,
        "p6": p6,
        "p7": p7,
        "sub_dmc": sub_dmc,
        "sub_ds": sub_ds,
        "sub_oops": sub_oops,
        "sub_cf": sub_cf,
        "sub_aiml": sub_aiml,
        "sub_twm": sub_twm,
    }


def test_1_same_class_day_period_rejected(client, test_data, db_session):
    """1. Class Slot Conflict: same class + same day + same period rejected."""
    headers = test_data["admin_headers"]
    cs1 = test_data["cs1"]
    p1 = test_data["p1"]
    sub_oops = test_data["sub_oops"]

    # Class 1 on Monday P1 is already occupied by DMC
    res = client.post("/api/v1/admin/timetable", json={
        "class_id": cs1.id,
        "subject_id": sub_oops.id,
        "day_of_week": "Monday",
        "period_id": p1.id
    }, headers=headers)

    assert res.status_code == 400
    detail = res.json()["detail"]
    assert "already occupied" in detail.lower() or "class slot conflict" in detail.lower()
    assert "Monday" in detail
    assert "Class 1" in detail


def test_2_same_faculty_same_day_same_period_rejected(client, test_data, db_session):
    """2. Faculty Double-Booking: same faculty + same day + same period across classes rejected."""
    headers = test_data["admin_headers"]
    cs2 = test_data["cs2"]
    p1 = test_data["p1"]
    fac05 = test_data["fac05"]  # FAC05 teaches Class 1 on Monday P1 (FDS)
    sub_cf = test_data["sub_cf"]

    # Attempt to assign FAC05 to Class 2 on Monday P1
    # First, let's delete Class 2 Monday P1 so class slot is free
    entry_c2_p1 = (
        db_session.query(TimetableEntry)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .filter(FacultyAssignment.class_id == cs2.id, TimetableEntry.day_of_week == "Monday", TimetableEntry.period_id == p1.id)
        .first()
    )
    db_session.delete(entry_c2_p1)
    db_session.commit()

    # Now attempt to book FAC05 on Class 2 Monday P1
    res = client.post("/api/v1/admin/timetable", json={
        "class_id": cs2.id,
        "subject_id": sub_cf.id,
        "faculty_id": fac05.id,
        "day_of_week": "Monday",
        "period_id": p1.id
    }, headers=headers)

    assert res.status_code == 400
    detail = res.json()["detail"]
    assert "already assigned" in detail.lower() or "timetable conflict" in detail.lower()
    assert fac05.full_name in detail
    assert "Monday" in detail


def test_3_same_faculty_overlapping_periods_rejected(client, test_data, db_session):
    """3. Faculty Overlapping Timing: same faculty + same day + overlapping timing rejected."""
    headers = test_data["admin_headers"]
    fac05 = test_data["fac05"]  # Teaches Class 1 on Monday P1 (09:10-10:00)

    # Create Class 3 section without any entries
    cs3 = ClassSection(name="IV Year CSE - Class 3 Overlap Test", grade_level="IV Year", academic_year="2026-2027")
    sub_test = Subject(code="TEST_SUB", name="Test Subject")
    # Create a custom overlapping Period P88 (09:30-10:20)
    overlap_period = Period(
        period_number=88,
        name="P88 Overlap",
        start_time="09:30",
        end_time="10:20"
    )
    db_session.add_all([cs3, sub_test, overlap_period])
    db_session.commit()
    db_session.refresh(cs3)
    db_session.refresh(sub_test)
    db_session.refresh(overlap_period)

    # Attempt to assign FAC05 to Class 3 on Monday during Period 88 (overlaps Class 1 Monday P1 09:10-10:00)
    res = client.post("/api/v1/admin/timetable", json={
        "class_id": cs3.id,
        "subject_id": sub_test.id,
        "faculty_id": fac05.id,
        "day_of_week": "Monday",
        "period_id": overlap_period.id
    }, headers=headers)

    assert res.status_code == 400
    detail = res.json()["detail"]
    assert "already assigned" in detail.lower() or "timetable conflict" in detail.lower()
    assert fac05.full_name in detail


def test_4_different_classes_different_faculty_same_period_allowed(client, test_data, db_session):
    """4. Valid Parallel Classes: Class 1 + Class 2 on same day/period with different faculty allowed."""
    headers = test_data["admin_headers"]
    cs1 = test_data["cs1"]
    cs2 = test_data["cs2"]
    p1 = test_data["p1"]

    # Query Class 1 Monday P1 (FDS -> FAC05 Santhiya)
    res1 = client.get(f"/api/v1/admin/timetable?class_id={cs1.id}&day_of_week=Monday&period_id={p1.id}", headers=headers)
    assert res1.status_code == 200
    c1_slots = res1.json()
    assert len(c1_slots) == 1
    assert c1_slots[0]["faculty_name"] == "Santhiya"

    # Query Class 2 Monday P1 (AIML -> FAC04 Shankar)
    res2 = client.get(f"/api/v1/admin/timetable?class_id={cs2.id}&day_of_week=Monday&period_id={p1.id}", headers=headers)
    assert res2.status_code == 200
    c2_slots = res2.json()
    assert len(c2_slots) == 1
    assert c2_slots[0]["faculty_name"] == "Shankar"


def test_5_pending_faculty_does_not_cause_conflict(client, test_data, db_session):
    """5. Pending Faculty: Unassigned slots do not cause faculty conflicts across classes."""
    headers = test_data["admin_headers"]
    cs1 = test_data["cs1"]
    cs2 = test_data["cs2"]
    p5 = test_data["p5"]

    # In baseline seed, Saturday P5 is ASSOC in Class 1 (Pending faculty)
    # Let's verify multiple pending slots at same day/period in different classes can co-exist
    # Create Class 3 section
    cs3 = ClassSection(name="IV Year CSE - Class 3", grade_level="IV Year", academic_year="2026-2027")
    sub_proj = Subject(code="PROJ", name="Project Work")
    db_session.add_all([cs3, sub_proj])
    db_session.commit()
    db_session.refresh(cs3)
    db_session.refresh(sub_proj)

    # Add unassigned / pending slot in Class 3 on Saturday P5
    res = client.post("/api/v1/admin/timetable", json={
        "class_id": cs3.id,
        "subject_id": sub_proj.id,
        "faculty_id": None,
        "day_of_week": "Saturday",
        "period_id": p5.id
    }, headers=headers)

    assert res.status_code == 201
    assert res.json()["faculty_name"] == "Faculty assignment pending"


def test_6_conflict_on_create_rejected(client, test_data):
    """6. Conflict on POST create timetable returns 400 Bad Request."""
    headers = test_data["admin_headers"]
    cs1 = test_data["cs1"]
    p2 = test_data["p2"]
    sub_ds = test_data["sub_ds"]

    # Class 1 on Monday P2 is already DS
    res = client.post("/api/v1/admin/timetable", json={
        "class_id": cs1.id,
        "subject_id": sub_ds.id,
        "day_of_week": "Monday",
        "period_id": p2.id
    }, headers=headers)

    assert res.status_code == 400
    assert "already occupied" in res.json()["detail"].lower()


def test_7_conflict_on_update_rejected(client, test_data, db_session):
    """7. Conflict on PUT update timetable returns 400 Bad Request."""
    headers = test_data["admin_headers"]
    cs1 = test_data["cs1"]
    p1 = test_data["p1"]
    p2 = test_data["p2"]

    # Get Monday P2 entry for Class 1
    entry_p2 = (
        db_session.query(TimetableEntry)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .filter(FacultyAssignment.class_id == cs1.id, TimetableEntry.day_of_week == "Monday", TimetableEntry.period_id == p2.id)
        .first()
    )
    assert entry_p2 is not None

    # Try updating entry_p2 to target Monday P1 (which is already occupied by Monday P1 DMC)
    res = client.put(f"/api/v1/admin/timetable/{entry_p2.id}", json={
        "day_of_week": "Monday",
        "period_id": p1.id
    }, headers=headers)

    assert res.status_code == 400
    assert "already occupied" in res.json()["detail"].lower()


def test_8_conflict_on_move_rejected(client, test_data, db_session):
    """8. Conflict on POST move timetable returns 400 Bad Request."""
    headers = test_data["admin_headers"]
    cs1 = test_data["cs1"]
    p1 = test_data["p1"]
    p2 = test_data["p2"]

    # Get Monday P2 entry
    entry_p2 = (
        db_session.query(TimetableEntry)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .filter(FacultyAssignment.class_id == cs1.id, TimetableEntry.day_of_week == "Monday", TimetableEntry.period_id == p2.id)
        .first()
    )

    # Attempt to move Monday P2 to Monday P1
    res = client.post(f"/api/v1/admin/timetable/{entry_p2.id}/move", json={
        "target_day_of_week": "Monday",
        "target_period_id": p1.id
    }, headers=headers)

    assert res.status_code == 400
    assert "already occupied" in res.json()["detail"].lower()


def test_9_conflict_on_duplicate_rejected(client, test_data, db_session):
    """9. Conflict on POST duplicate timetable returns 400 Bad Request."""
    headers = test_data["admin_headers"]
    cs1 = test_data["cs1"]
    p1 = test_data["p1"]
    p2 = test_data["p2"]

    # Get Monday P2 entry
    entry_p2 = (
        db_session.query(TimetableEntry)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .filter(FacultyAssignment.class_id == cs1.id, TimetableEntry.day_of_week == "Monday", TimetableEntry.period_id == p2.id)
        .first()
    )

    # Attempt to duplicate into Monday P1
    res = client.post(f"/api/v1/admin/timetable/{entry_p2.id}/duplicate", json={
        "target_day_of_week": "Monday",
        "target_period_id": p1.id
    }, headers=headers)

    assert res.status_code == 400
    assert "already occupied" in res.json()["detail"].lower()


def test_10_valid_move_accepted(client, test_data, db_session):
    """10. Valid move into an unoccupied slot is accepted (200 OK) with audit log."""
    headers = test_data["admin_headers"]
    cs1 = test_data["cs1"]
    p1 = test_data["p1"]
    p2 = test_data["p2"]

    # Clear Sunday P1 (which is empty)
    entry_p2 = (
        db_session.query(TimetableEntry)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .filter(FacultyAssignment.class_id == cs1.id, TimetableEntry.day_of_week == "Monday", TimetableEntry.period_id == p2.id)
        .first()
    )
    entry_id = entry_p2.id

    # Move Monday P2 to Sunday P1
    res = client.post(f"/api/v1/admin/timetable/{entry_id}/move", json={
        "target_day_of_week": "Sunday",
        "target_period_id": p1.id
    }, headers=headers)

    assert res.status_code == 200
    data = res.json()
    assert data["day_of_week"] == "Sunday"
    assert data["period_id"] == p1.id

    # Verify audit log
    audit = db_session.query(AuditLog).filter(AuditLog.action == "MOVE_TIMETABLE_ENTRY").order_by(AuditLog.id.desc()).first()
    assert audit is not None
    assert f"#{entry_id}" in audit.details
    assert "Sunday" in audit.details


def test_11_valid_duplicate_accepted(client, test_data, db_session):
    """11. Valid duplicate into an unoccupied slot is accepted (201 Created) with audit log."""
    headers = test_data["admin_headers"]
    cs1 = test_data["cs1"]
    p1 = test_data["p1"]
    p2 = test_data["p2"]

    entry_p1 = (
        db_session.query(TimetableEntry)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .filter(FacultyAssignment.class_id == cs1.id, TimetableEntry.day_of_week == "Monday", TimetableEntry.period_id == p1.id)
        .first()
    )

    # Duplicate Monday P1 to Sunday P2
    res = client.post(f"/api/v1/admin/timetable/{entry_p1.id}/duplicate", json={
        "target_day_of_week": "Sunday",
        "target_period_id": p2.id
    }, headers=headers)

    assert res.status_code == 201
    dup_data = res.json()
    assert dup_data["id"] != entry_p1.id
    assert dup_data["day_of_week"] == "Sunday"
    assert dup_data["period_id"] == p2.id
    assert dup_data["subject_code"] == entry_p1.assignment.subject.code

    # Verify audit log
    audit = db_session.query(AuditLog).filter(AuditLog.action == "DUPLICATE_TIMETABLE_ENTRY").order_by(AuditLog.id.desc()).first()
    assert audit is not None
    assert f"#{entry_p1.id}" in audit.details
    assert f"#{dup_data['id']}" in audit.details


def test_12_database_remains_unchanged_after_rejected_operation(client, test_data, db_session):
    """12. DB Isolation: Database remains completely unchanged after rejected operations."""
    headers = test_data["admin_headers"]
    cs1 = test_data["cs1"]
    p1 = test_data["p1"]
    p2 = test_data["p2"]
    sub_ds = test_data["sub_ds"]

    count_before = db_session.query(TimetableEntry).count()

    # Capture snapshot of Monday P2
    entry_p2_before = (
        db_session.query(TimetableEntry)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .filter(FacultyAssignment.class_id == cs1.id, TimetableEntry.day_of_week == "Monday", TimetableEntry.period_id == p2.id)
        .first()
    )
    p2_id = entry_p2_before.id
    p2_day = entry_p2_before.day_of_week
    p2_period_id = entry_p2_before.period_id

    # 1. Rejected Create
    res_create = client.post("/api/v1/admin/timetable", json={
        "class_id": cs1.id, "subject_id": sub_ds.id, "day_of_week": "Monday", "period_id": p1.id
    }, headers=headers)
    assert res_create.status_code == 400

    # 2. Rejected Update
    res_update = client.put(f"/api/v1/admin/timetable/{p2_id}", json={
        "day_of_week": "Monday", "period_id": p1.id
    }, headers=headers)
    assert res_update.status_code == 400

    # 3. Rejected Move
    res_move = client.post(f"/api/v1/admin/timetable/{p2_id}/move", json={
        "target_day_of_week": "Monday", "target_period_id": p1.id
    }, headers=headers)
    assert res_move.status_code == 400

    # 4. Rejected Duplicate
    res_dup = client.post(f"/api/v1/admin/timetable/{p2_id}/duplicate", json={
        "target_day_of_week": "Monday", "target_period_id": p1.id
    }, headers=headers)
    assert res_dup.status_code == 400

    # Verify DB state is pristine
    db_session.expire_all()
    count_after = db_session.query(TimetableEntry).count()
    assert count_after == count_before

    entry_p2_after = db_session.query(TimetableEntry).filter(TimetableEntry.id == p2_id).first()
    assert entry_p2_after.day_of_week == p2_day
    assert entry_p2_after.period_id == p2_period_id


def test_13_class1_and_class2_conflict_checks_work_together(client, test_data, db_session):
    """13. Class 1 & Class 2 Conflict Detection: Cross-class faculty double-booking validation."""
    headers = test_data["admin_headers"]
    cs1 = test_data["cs1"]
    cs2 = test_data["cs2"]
    p1 = test_data["p1"]
    fac05 = test_data["fac05"]  # Santhiya (Class 1 Monday P1)
    fac01 = test_data["fac01"]  # Mathu Metlda (Free on Monday P1)

    # Class 2 Monday P1 entry (AIML -> FAC04)
    entry_c2_p1 = (
        db_session.query(TimetableEntry)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .filter(FacultyAssignment.class_id == cs2.id, TimetableEntry.day_of_week == "Monday", TimetableEntry.period_id == p1.id)
        .first()
    )

    # Attempt to change Class 2 Monday P1 faculty to FAC05 (Conflict with Class 1 Monday P1!)
    res_conflict = client.put(f"/api/v1/admin/timetable/{entry_c2_p1.id}", json={
        "faculty_id": fac05.id
    }, headers=headers)
    assert res_conflict.status_code == 400
    assert "already assigned" in res_conflict.json()["detail"].lower() or "timetable conflict" in res_conflict.json()["detail"].lower()

    # Change Class 2 Monday P1 faculty to FAC01 (Available on Monday P1! Success)
    res_valid = client.put(f"/api/v1/admin/timetable/{entry_c2_p1.id}", json={
        "faculty_id": fac01.id
    }, headers=headers)
    assert res_valid.status_code == 200
    assert res_valid.json()["faculty_name"] == "Mathu Metlda"


def test_14_audit_behavior_on_conflicts(client, test_data, db_session):
    """14. Audit Integrity: Successful operations logged cleanly, no credentials or tokens in details."""
    headers = test_data["admin_headers"]
    cs1 = test_data["cs1"]
    p1 = test_data["p1"]
    sub_ds = test_data["sub_ds"]

    # Trigger a conflict
    res = client.post("/api/v1/admin/timetable", json={
        "class_id": cs1.id, "subject_id": sub_ds.id, "day_of_week": "Monday", "period_id": p1.id
    }, headers=headers)
    assert res.status_code == 400

    # Ensure no passwords or raw auth tokens exist in any audit logs
    all_logs = db_session.query(AuditLog).all()
    for log in all_logs:
        details_lower = (log.details or "").lower()
        assert "password" not in details_lower or "forced" in details_lower
        assert "bearer" not in details_lower
        assert "$2b$" not in details_lower
