#!/usr/bin/env python3
"""
================================================================================
CLASS 1 STUDENT ROSTER VALIDATOR — DEVELOPMENT ONBOARDING DATA
================================================================================
Validates the structural integrity, capacity, uniqueness, and fields of the
Class 1 student onboarding dataset (college_seed/students_class1_development.json).

Exit Codes:
  0 = Validation Passes (PASS)
  1 = Warnings Only (WARN)
  2 = Blocking Validation Errors (FAIL)
================================================================================
"""

import os
import sys
import json
from typing import List, Dict, Any, Tuple

# Configuration Constants
EXPECTED_CLASS_NAME = "II Year CSE Cyber Security - Class 1"
EXPECTED_TOTAL_STUDENTS = 64
EXPECTED_REGULAR_STUDENTS = 63
EXPECTED_LATERAL_STUDENTS = 1
MAX_SYSTEM_STUDENT_CAPACITY = 130
VALID_ENTRY_TYPES = {"REGULAR", "LATERAL_ENTRY"}

LEVEL_PASS = "PASS"
LEVEL_WARN = "WARN"
LEVEL_FAIL = "FAIL"


class Finding:
    def __init__(self, level: str, target: str, field: str, problem: str, recommendation: str = ""):
        self.level = level
        self.target = target
        self.field = field
        self.problem = problem
        self.recommendation = recommendation

    def __repr__(self):
        return f"[{self.level}] {self.target} -> {self.field}: {self.problem}"


class Class1RosterValidator:
    def __init__(self, filepath: str = "college_seed/students_class1_development.json"):
        self.filepath = os.path.abspath(filepath)
        self.findings: List[Finding] = []
        self.stats = {
            "total": 0,
            "regular": 0,
            "lateral": 0,
            "missing_student_id": 0,
            "duplicate_rolls": 0,
            "duplicate_student_ids": 0,
            "duplicate_names": 0,
            "invalid_classes": 0,
            "invalid_entry_types": 0,
        }

    def add_finding(self, level: str, field: str, problem: str, recommendation: str = ""):
        self.findings.append(Finding(level, os.path.basename(self.filepath), field, problem, recommendation))

    def validate(self) -> Tuple[int, List[Finding]]:
        self.findings = []
        self.stats = {
            "total": 0,
            "regular": 0,
            "lateral": 0,
            "missing_student_id": 0,
            "duplicate_rolls": 0,
            "duplicate_student_ids": 0,
            "duplicate_names": 0,
            "invalid_classes": 0,
            "invalid_entry_types": 0,
        }

        # 1. File existence and JSON syntax check
        if not os.path.exists(self.filepath):
            self.add_finding(
                LEVEL_FAIL, "file",
                f"File not found at '{self.filepath}'.",
                "Ensure college_seed/students_class1_development.json exists."
            )
            return 2, self.findings

        try:
            with open(self.filepath, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            self.add_finding(
                LEVEL_FAIL, "json_syntax",
                f"Failed to parse JSON: {str(e)}",
                "Fix JSON syntax formatting errors."
            )
            return 2, self.findings

        if not isinstance(data, list):
            self.add_finding(
                LEVEL_FAIL, "schema",
                f"Expected top-level JSON array, got {type(data).__name__}.",
                "Format dataset as an array of student objects."
            )
            return 2, self.findings

        self.stats["total"] = len(data)

        # 2. Capacity & Roster Size Checks
        if len(data) > MAX_SYSTEM_STUDENT_CAPACITY:
            self.add_finding(
                LEVEL_FAIL, "capacity",
                f"Class 1 count ({len(data)}) exceeds system capacity limit of {MAX_SYSTEM_STUDENT_CAPACITY}.",
                f"Limit student count to at most {MAX_SYSTEM_STUDENT_CAPACITY}."
            )

        if len(data) != EXPECTED_TOTAL_STUDENTS:
            self.add_finding(
                LEVEL_FAIL, "total_count",
                f"Expected {EXPECTED_TOTAL_STUDENTS} students (63 regular + 1 lateral), found {len(data)}.",
                f"Ensure exact 64 students are listed in the onboarding dataset."
            )

        seen_rolls = {}
        seen_student_ids = {}
        seen_names = {}
        lateral_students = []

        # 3. Individual Record Validation
        for idx, item in enumerate(data):
            row_prefix = f"Row {idx+1}"
            if not isinstance(item, dict):
                self.add_finding(
                    LEVEL_FAIL, row_prefix,
                    f"Item is not a JSON object: {item}",
                    "Ensure every entry is a student object."
                )
                continue

            roll_no = str(item.get("roll_number", "")).strip()
            student_id = item.get("student_id")
            if student_id is not None:
                student_id = str(student_id).strip()
            full_name = str(item.get("full_name", "")).strip()
            class_name = str(item.get("class_name", "")).strip()
            entry_type = str(item.get("entry_type", "REGULAR")).strip().upper()
            is_active = item.get("is_active", True)

            # Name Validation
            if not full_name:
                self.add_finding(
                    LEVEL_FAIL, f"{row_prefix}.full_name",
                    "Student full_name is empty or missing.",
                    "Provide non-empty student full name."
                )
            else:
                if full_name in seen_names:
                    self.stats["duplicate_names"] += 1
                    self.add_finding(
                        LEVEL_WARN, f"{row_prefix}.full_name",
                        f"Duplicate full_name '{full_name}' (first seen in Row {seen_names[full_name]}).",
                        "Verify whether two students share the same name (permitted if roll numbers differ)."
                    )
                else:
                    seen_names[full_name] = idx + 1

            # Register Number / Roll Number Validation
            if not roll_no:
                self.add_finding(
                    LEVEL_FAIL, f"{row_prefix}.roll_number",
                    "Student roll_number (register number) is empty or missing.",
                    "Provide valid unique register number."
                )
            else:
                if roll_no in seen_rolls:
                    self.stats["duplicate_rolls"] += 1
                    self.add_finding(
                        LEVEL_FAIL, f"{row_prefix}.roll_number",
                        f"Duplicate register number / roll_number '{roll_no}' (collides with Row {seen_rolls[roll_no]}).",
                        "Ensure all student register numbers are unique."
                    )
                else:
                    seen_rolls[roll_no] = idx + 1

            # Class Section Validation
            if class_name != EXPECTED_CLASS_NAME:
                self.stats["invalid_classes"] += 1
                self.add_finding(
                    LEVEL_FAIL, f"{row_prefix}.class_name",
                    f"Invalid class_name '{class_name}' (expected '{EXPECTED_CLASS_NAME}').",
                    f"Set class_name to '{EXPECTED_CLASS_NAME}'."
                )

            # Entry Type Validation
            if entry_type not in VALID_ENTRY_TYPES:
                self.stats["invalid_entry_types"] += 1
                self.add_finding(
                    LEVEL_FAIL, f"{row_prefix}.entry_type",
                    f"Invalid entry_type '{entry_type}'. Must be REGULAR or LATERAL_ENTRY.",
                    "Set entry_type to 'REGULAR' or 'LATERAL_ENTRY'."
                )
            elif entry_type == "LATERAL_ENTRY":
                self.stats["lateral"] += 1
                lateral_students.append((idx + 1, roll_no, full_name, student_id))
            else:
                self.stats["regular"] += 1

            # Student ID Validation
            if student_id:
                if student_id in seen_student_ids:
                    self.stats["duplicate_student_ids"] += 1
                    self.add_finding(
                        LEVEL_FAIL, f"{row_prefix}.student_id",
                        f"Duplicate Student ID '{student_id}' (collides with Row {seen_student_ids[student_id]}).",
                        "Ensure Student IDs are unique."
                    )
                else:
                    seen_student_ids[student_id] = idx + 1
            else:
                self.stats["missing_student_id"] += 1
                if entry_type == "REGULAR":
                    self.add_finding(
                        LEVEL_WARN, f"{row_prefix}.student_id",
                        f"Regular student '{full_name}' ({roll_no}) has unassigned/null Student ID.",
                        "Preserve source Student ID or allocate when college assigns permanent IDs."
                    )

        # 4. Lateral Entry Specific Invariants (Akhil)
        if len(lateral_students) != EXPECTED_LATERAL_STUDENTS:
            self.add_finding(
                LEVEL_FAIL, "lateral_entry_count",
                f"Expected exactly {EXPECTED_LATERAL_STUDENTS} lateral entry student, found {len(lateral_students)}.",
                "Ensure exactly one lateral entry student (Akhil) is recorded."
            )
        else:
            lat_row, lat_roll, lat_name, lat_sid = lateral_students[0]
            if lat_roll != "301":
                self.add_finding(
                    LEVEL_FAIL, f"Row {lat_row}.lateral_entry_roll",
                    f"Lateral entry student '{lat_name}' has register number '{lat_roll}' (MUST be '301').",
                    "Assign roll_number = '301' to lateral entry student Akhil."
                )
            if lat_sid is not None and lat_sid != "":
                self.add_finding(
                    LEVEL_FAIL, f"Row {lat_row}.lateral_entry_student_id",
                    f"Lateral entry student '{lat_name}' has Student ID '{lat_sid}' (MUST be null/unassigned).",
                    "Leave student_id as null for lateral entry student Akhil."
                )
            if "akhil" not in lat_name.lower():
                self.add_finding(
                    LEVEL_WARN, f"Row {lat_row}.lateral_entry_name",
                    f"Lateral entry student name is '{lat_name}' (expected 'Akhil').",
                    "Verify lateral entry student identity."
                )

        # 5. Regular Student Count Check
        if self.stats["regular"] != EXPECTED_REGULAR_STUDENTS:
            self.add_finding(
                LEVEL_FAIL, "regular_count",
                f"Expected {EXPECTED_REGULAR_STUDENTS} regular students, found {self.stats['regular']}.",
                f"Verify regular student roster count."
            )

        # Determine overall exit code
        has_fail = any(f.level == LEVEL_FAIL for f in self.findings)
        has_warn = any(f.level == LEVEL_WARN for f in self.findings)

        if has_fail:
            return 2, self.findings
        elif has_warn:
            return 1, self.findings
        else:
            self.add_finding(
                LEVEL_PASS, "validation",
                f"All {self.stats['total']} student records (63 regular + 1 lateral) passed validation successfully.",
                "Ready for credential preparation phase."
            )
            return 0, self.findings

    def print_report(self):
        code, findings = self.validate()

        print("=" * 80)
        print("CLASS 1 STUDENT ROSTER VALIDATION REPORT (DEVELOPMENT ONBOARDING)")
        print("=" * 80)
        print(f"File Path:         {self.filepath}")
        print(f"Total Records:     {self.stats['total']} (Expected: {EXPECTED_TOTAL_STUDENTS})")
        print(f"Regular Students:  {self.stats['regular']} (Expected: {EXPECTED_REGULAR_STUDENTS})")
        print(f"Lateral Entry:     {self.stats['lateral']} (Expected: {EXPECTED_LATERAL_STUDENTS})")
        print(f"Capacity Limit:    {self.stats['total']} / {MAX_SYSTEM_STUDENT_CAPACITY} (Within Limit: {self.stats['total'] <= MAX_SYSTEM_STUDENT_CAPACITY})")
        print("-" * 80)

        pass_count = sum(1 for f in findings if f.level == LEVEL_PASS)
        warn_count = sum(1 for f in findings if f.level == LEVEL_WARN)
        fail_count = sum(1 for f in findings if f.level == LEVEL_FAIL)

        for f in findings:
            prefix = f"[{f.level}]".ljust(8)
            print(f"{prefix} {f.field}: {f.problem}")
            if f.recommendation:
                print(f"         Recommendation: {f.recommendation}")

        print("-" * 80)
        print(f"SUMMARY: PASS={pass_count}, WARN={warn_count}, FAIL={fail_count}")
        if code == 0:
            print("OVERALL STATUS: SUCCESS (0) — Dataset structurally valid.")
        elif code == 1:
            print("OVERALL STATUS: WARNING (1) — Dataset valid with informational warnings.")
        else:
            print("OVERALL STATUS: FAILURE (2) — Blocking validation errors detected.")
        print("=" * 80)
        return code


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "college_seed/students_class1_development.json"
    validator = Class1RosterValidator(target)
    sys.exit(validator.print_report())
