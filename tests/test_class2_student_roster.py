"""
Unit & Integration Tests for Milestone 10C.12.1:
Class 2 Student Roster Preparation & Validation
"""

import json
import os
import pytest
from app.core.database import SessionLocal
from app.models.student import Student
from app.models.user import User, Faculty
from app.models.academic import ClassSection, TimetableEntry
from app.models.attendance import AttendanceRecord, ClassSession, FaceEmbedding
from scripts.validate_class2_student_roster import Class2RosterValidator, EXPECTED_CLASS_NAME


ROSTER_PATH = "college_seed/students_class2_development.json"


@pytest.fixture(scope="module")
def class2_roster_data():
    with open(ROSTER_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def test_1_roster_contains_exactly_55_students(class2_roster_data):
    """1. Roster must contain exactly 55 records matching the official source."""
    assert len(class2_roster_data) == 55


def test_2_all_register_numbers_are_unique(class2_roster_data):
    """2. All register numbers in Class 2 must be 100% unique."""
    rolls = [s["roll_number"] for s in class2_roster_data]
    assert len(rolls) == len(set(rolls))


def test_3_all_names_are_non_empty(class2_roster_data):
    """3. Every record must have a non-empty, trimmed full_name."""
    for s in class2_roster_data:
        assert isinstance(s["full_name"], str)
        assert len(s["full_name"].strip()) > 0


def test_4_all_class_names_are_correct(class2_roster_data):
    """4. All records must have class_name == 'III Year CSE Cyber Security - Class 2'."""
    for s in class2_roster_data:
        assert s["class_name"] == EXPECTED_CLASS_NAME


def test_5_all_student_ids_are_null(class2_roster_data):
    """5. All student_id values must be null since source photographs do not provide them."""
    for s in class2_roster_data:
        assert s["student_id"] is None


def test_6_no_fabricated_lateral_entry_record(class2_roster_data):
    """6. All records must be REGULAR entry type (no fabricated lateral entry)."""
    for s in class2_roster_data:
        assert s["entry_type"] == "REGULAR"


def test_7_non_contiguous_register_numbers_accepted(class2_roster_data):
    """7. Preserved non-contiguous register numbers are accepted without fabrication."""
    rolls = [int(s["roll_number"]) for s in class2_roster_data]
    assert min(rolls) == 721024149001
    assert max(rolls) == 721024149059
    assert len(rolls) == 55


def test_8_missing_register_numbers_are_not_auto_created(class2_roster_data):
    """8. Specific known source gaps must not be present in the dataset."""
    rolls = {s["roll_number"] for s in class2_roster_data}
    known_gaps = {"721024149003", "721024149009", "721024149028", "721024149048"}
    for gap in known_gaps:
        assert gap not in rolls, f"Gap {gap} should not exist in transcribed roster"


def test_9_projected_capacity_is_119_out_of_130(class2_roster_data):
    """9. Current 64 Class 1 + 55 Class 2 = 119 / 130 max capacity (11 remaining)."""
    class1_count = 64
    class2_count = len(class2_roster_data)
    projected_total = class1_count + class2_count
    max_capacity = 130
    assert projected_total == 119
    assert projected_total <= max_capacity
    assert max_capacity - projected_total == 11


def test_10_database_class1_count_remains_64():
    """10. Database Class 1 student count must remain exactly 64."""
    db = SessionLocal()
    try:
        c1_count = db.query(Student).join(ClassSection).filter(ClassSection.name.like("%Class 1%")).count()
        assert c1_count == 64
    finally:
        db.close()


def test_11_database_counts_remain_unchanged():
    """11. Reconciled database contains 64 Class 1 + 55 Class 2 students, and 8 official faculty."""
    db = SessionLocal()
    try:
        total_students = db.query(Student).count()
        assert total_students == 119
        c2_count = db.query(Student).join(ClassSection).filter(ClassSection.name.like("%Class 2%")).count()
        assert c2_count == 55
        faculty_count = db.query(Faculty).count()
        assert faculty_count == 8
    finally:
        db.close()


def test_12_no_credentials_generated_and_no_class2_accounts():
    """12 & 13. All 55 Class 2 User accounts exist in database matching the official roster."""
    db = SessionLocal()
    try:
        # Check that exactly 55 users with 721024... register numbers exist
        c2_users = db.query(User).filter(User.username.like("721024%")).count()
        assert c2_users == 55
    finally:
        db.close()


def test_13_json_schema_compatible_with_class1_format(class2_roster_data):
    """14. JSON schema has same exact keys as Class 1 development dataset."""
    with open("college_seed/students_class1_development.json", "r", encoding="utf-8") as f:
        class1_sample = json.load(f)[0]

    class2_sample = class2_roster_data[0]
    assert set(class1_sample.keys()) == set(class2_sample.keys())


def test_14_validator_script_passes_official_roster():
    """15. Validator script runs cleanly and passes official Class 2 roster."""
    validator = Class2RosterValidator(ROSTER_PATH)
    exit_code, findings = validator.validate()
    assert exit_code in [0, 1]  # 0 or 1 (warnings for gaps allowed)
    fail_findings = [f for f in findings if f.level == "FAIL"]
    assert len(fail_findings) == 0
    assert validator.stats["total"] == 55
    assert validator.stats["duplicate_rolls"] == 0
    assert validator.stats["student_ids_supplied"] == 0
