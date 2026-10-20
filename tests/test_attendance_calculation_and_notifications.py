import json
import pytest
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import SessionLocal, init_db, engine
from app.models.user import User, UserRole, Faculty
from app.models.student import Student
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.attendance import ClassSession, AttendanceRecord, SessionStatus, AttendanceStatus
from app.models.notification import NotificationLog, NotificationType, NotificationChannel
from app.models.policy import AttendancePolicy, SystemSetting
from app.engines.policy_engine import _status_counts, AttendancePolicyEngine
from app.services.notification_service import NotificationService
from app.engines.attendance_engine import submit_faculty_attendance, submit_class_advisor_attendance

client = TestClient(app)


@pytest.fixture(scope="module")
def db():
    init_db(engine)
    session = SessionLocal()
    yield session
    session.close()


def test_policy_engine_pure_present_avoid_double_counting(db: Session):
    """
    Verify that _status_counts returns pure_present under COUNT_AS_PRESENT mode.
    Pure Present + Absent + OD must equal Total.
    The mutually exclusive breakdown percentages must sum to 100.0%.
    """
    policy = AttendancePolicy(
        description="Standard Test Policy",
        od_calculation_mode="COUNT_AS_PRESENT",
        minimum_percentage=75.0,
        warning_threshold=80.0,
        critical_threshold=65.0,
    )

    # 13 classes: 9 Present, 1 OD, 3 Absent (exact match to user's bug screenshot)
    records = []
    for _ in range(9):
        records.append(AttendanceRecord(status=AttendanceStatus.PRESENT))
    for _ in range(1):
        records.append(AttendanceRecord(status=AttendanceStatus.OD, od_reason="Sports"))
    for _ in range(3):
        records.append(AttendanceRecord(status=AttendanceStatus.ABSENT))

    counts = _status_counts(records, policy)

    assert counts["total"] == 13
    assert counts["present"] == 10  # 9 pure present + 1 OD credit
    assert counts["pure_present"] == 9  # mutually exclusive
    assert counts["absent"] == 3
    assert counts["od"] == 1

    # Mutually exclusive verification
    assert counts["pure_present"] + counts["absent"] + counts["od"] == counts["total"]

    # Percentage breakdown verification
    total = counts["total"]
    pure_present_pct = (counts["pure_present"] / total) * 100.0
    absent_pct = (counts["absent"] / total) * 100.0
    od_pct = (counts["od"] / total) * 100.0

    breakdown_sum = pure_present_pct + absent_pct + od_pct
    assert abs(breakdown_sum - 100.0) < 0.0001
    assert breakdown_sum <= 100.0

    # Official academic percentage
    overall_pct = (counts["present"] / total) * 100.0
    assert round(overall_pct, 1) == 76.9


def test_send_attendance_marking_notifications(db: Session):
    """
    Verify that send_attendance_marking_notifications creates NotificationLog
    records with GO_ON_ATTENDANCE channel for marked students, and updates idempotently.
    """
    # Find or verify active student
    student = db.query(Student).join(User, Student.user_id == User.id).filter(User.is_active == True).first()
    assert student is not None, "Test requires at least one active student"

    # Find a class session
    session = db.query(ClassSession).first()
    assert session is not None, "Test requires at least one class session"

    # 1. Dispatch PRESENT notification
    res = NotificationService.send_attendance_marking_notifications(
        db=db,
        session_id=session.id,
        records_data=[{
            "student_id": student.id,
            "status": "PRESENT",
            "od_reason": None,
        }],
    )
    assert res["sent"] >= 1

    log = (
        db.query(NotificationLog)
        .filter(
            NotificationLog.user_id == student.user_id,
            NotificationLog.notification_type == NotificationType.ATTENDANCE.value,
            NotificationLog.reference_date == session.date,
        )
        .first()
    )
    assert log is not None
    assert log.channel_id == NotificationChannel.GO_ON_ATTENDANCE.value
    assert "Present" in log.title
    assert "Present" in log.body
    assert log.is_read is False

    payload = json.loads(log.data_payload)
    assert payload["route"] == "student_attendance"
    assert payload["status"] == "PRESENT"

    # 2. Re-mark as OD (updating idempotently)
    res2 = NotificationService.send_attendance_marking_notifications(
        db=db,
        session_id=session.id,
        records_data=[{
            "student_id": student.id,
            "status": "OD",
            "od_reason": "Hackathon participation",
        }],
    )
    assert res2["sent"] >= 1

    # Verify log was updated rather than duplicated
    logs = (
        db.query(NotificationLog)
        .filter(
            NotificationLog.user_id == student.user_id,
            NotificationLog.notification_type == NotificationType.ATTENDANCE.value,
            NotificationLog.reference_date == session.date,
            NotificationLog.timetable_entry_id == session.timetable_entry_id,
        )
        .all()
    )
    assert len(logs) == 1
    updated_log = logs[0]
    assert "On-Duty" in updated_log.title
    assert "Hackathon participation" in updated_log.body
    assert updated_log.is_read is False

    # 3. Re-mark as ABSENT (updating idempotently)
    res3 = NotificationService.send_attendance_marking_notifications(
        db=db,
        session_id=session.id,
        records_data=[{
            "student_id": student.id,
            "status": "ABSENT",
            "od_reason": None,
        }],
    )
    assert res3["sent"] >= 1

    db.refresh(updated_log)
    assert "Absent" in updated_log.title
    assert "Absent" in updated_log.body
    assert updated_log.is_read is False
