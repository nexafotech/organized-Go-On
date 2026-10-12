import os
import json
import pytest
from scripts.validate_class1_student_roster import (
    Class1RosterValidator,
    EXPECTED_TOTAL_STUDENTS,
    EXPECTED_REGULAR_STUDENTS,
    EXPECTED_LATERAL_STUDENTS,
    EXPECTED_CLASS_NAME,
    LEVEL_FAIL,
    LEVEL_WARN,
    LEVEL_PASS
)

ROSTER_PATH = os.path.abspath("college_seed/students_class1_development.json")


@pytest.fixture
def roster_data():
    assert os.path.exists(ROSTER_PATH), f"Roster file not found at {ROSTER_PATH}"
    with open(ROSTER_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


# ----------------------------------------------------
# 1. Expected Counts (64 Total, 63 Regular, 1 Lateral)
# ----------------------------------------------------
def test_roster_total_count(roster_data):
    assert len(roster_data) == EXPECTED_TOTAL_STUDENTS
    assert len(roster_data) == 64


def test_roster_regular_and_lateral_counts(roster_data):
    regular = [s for s in roster_data if s.get("entry_type") == "REGULAR"]
    lateral = [s for s in roster_data if s.get("entry_type") == "LATERAL_ENTRY"]

    assert len(regular) == EXPECTED_REGULAR_STUDENTS
    assert len(regular) == 63

    assert len(lateral) == EXPECTED_LATERAL_STUDENTS
    assert len(lateral) == 1


# ----------------------------------------------------
# 2. Lateral Entry Student Invariants (Akhil -> 301, No Student ID)
# ----------------------------------------------------
def test_lateral_entry_student_akhil(roster_data):
    lateral = [s for s in roster_data if s.get("entry_type") == "LATERAL_ENTRY"]
    assert len(lateral) == 1
    akhil = lateral[0]

    assert akhil["full_name"] == "Akhil"
    assert akhil["roll_number"] == "301"
    assert akhil["roll_number"] != "64"
    assert akhil["student_id"] is None
    assert akhil["class_name"] == EXPECTED_CLASS_NAME
    assert akhil["is_active"] is True


# ----------------------------------------------------
# 3. Register Number Uniqueness & Formatting
# ----------------------------------------------------
def test_register_numbers_are_unique(roster_data):
    seen = set()
    for s in roster_data:
        roll = s.get("roll_number")
        assert roll is not None and str(roll).strip() != ""
        assert roll not in seen, f"Duplicate roll_number detected: {roll}"
        seen.add(roll)
    assert len(seen) == 64


def test_regular_students_register_numbers_range(roster_data):
    regular = [s for s in roster_data if s.get("entry_type") == "REGULAR"]
    expected_rolls = [f"721025149{i:03d}" for i in range(1, 64)]
    actual_rolls = [s["roll_number"] for s in regular]
    assert actual_rolls == expected_rolls


# ----------------------------------------------------
# 4. Class Section Conformance
# ----------------------------------------------------
def test_class_name_conformance(roster_data):
    for s in roster_data:
        assert s.get("class_name") == EXPECTED_CLASS_NAME


# ----------------------------------------------------
# 5. Entry Types Conformance
# ----------------------------------------------------
def test_valid_entry_types(roster_data):
    valid_types = {"REGULAR", "LATERAL_ENTRY"}
    for s in roster_data:
        assert s.get("entry_type") in valid_types


# ----------------------------------------------------
# 6. Validator Engine Integrity Tests
# ----------------------------------------------------
def test_validator_script_official_roster():
    validator = Class1RosterValidator(ROSTER_PATH)
    code, findings = validator.validate()
    # Should be 0 (full pass) or 1 (warnings only for unassigned student_id), no FAIL (2)
    assert code in (0, 1)
    fail_findings = [f for f in findings if f.level == LEVEL_FAIL]
    assert len(fail_findings) == 0


def test_validator_detects_duplicate_roll_number(tmp_path):
    bad_data = [
        {"roll_number": "721025149001", "student_id": None, "full_name": "Student A", "class_name": EXPECTED_CLASS_NAME, "entry_type": "REGULAR"},
        {"roll_number": "721025149001", "student_id": None, "full_name": "Student B", "class_name": EXPECTED_CLASS_NAME, "entry_type": "REGULAR"},
    ]
    bad_file = tmp_path / "bad_roster.json"
    bad_file.write_text(json.dumps(bad_data), encoding="utf-8")

    validator = Class1RosterValidator(str(bad_file))
    code, findings = validator.validate()
    assert code == 2
    assert any("duplicate register number" in f.problem.lower() for f in findings)


def test_validator_detects_invalid_lateral_roll(tmp_path):
    bad_data = [
        {"roll_number": "64", "student_id": None, "full_name": "Akhil", "class_name": EXPECTED_CLASS_NAME, "entry_type": "LATERAL_ENTRY"}
    ]
    bad_file = tmp_path / "bad_lateral.json"
    bad_file.write_text(json.dumps(bad_data), encoding="utf-8")

    validator = Class1RosterValidator(str(bad_file))
    code, findings = validator.validate()
    assert code == 2
    assert any("must be '301'" in f.problem.lower() for f in findings)


def test_validator_detects_malformed_record(tmp_path):
    bad_data = [
        {"roll_number": "", "student_id": None, "full_name": "", "class_name": "Invalid Class", "entry_type": "UNKNOWN"}
    ]
    bad_file = tmp_path / "malformed.json"
    bad_file.write_text(json.dumps(bad_data), encoding="utf-8")

    validator = Class1RosterValidator(str(bad_file))
    code, findings = validator.validate()
    assert code == 2
    fail_fields = [f.field for f in findings if f.level == LEVEL_FAIL]
    assert any("full_name" in ff for ff in fail_fields)
    assert any("roll_number" in ff for ff in fail_fields)
