#!/usr/bin/env python3
"""
================================================================================
CLASS 2 STUDENT ROSTER VALIDATOR — DEVELOPMENT ONBOARDING DATA
================================================================================
Validates the structural integrity, capacity, uniqueness, and fields of the
Class 2 student onboarding dataset (college_seed/students_class2_development.json).

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
EXPECTED_CLASS_NAME = "III Year CSE Cyber Security - Class 2"
EXPECTED_TOTAL_STUDENTS = 55
EXPECTED_REGULAR_STUDENTS = 55
EXPECTED_LATERAL_STUDENTS = 0
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


class Class2RosterValidator:
    def __init__(self, filepath: str = "college_seed/students_class2_development.json"):
        self.filepath = os.path.abspath(filepath)
        self.findings: List[Finding] = []
        self.stats = {
            "total": 0,
            "regular": 0,
            "lateral": 0,
            "student_ids_supplied": 0,
            "duplicate_rolls": 0,
            "duplicate_names": 0,
            "invalid_classes": 0,
            "invalid_entry_types": 0,
            "non_contiguous_gaps": [],
        }

    def add_finding(self, level: str, field: str, problem: str, recommendation: str = ""):
        self.findings.append(Finding(level, os.path.basename(self.filepath), field, problem, recommendation))

    def validate(self) -> Tuple[int, List[Finding]]:
        self.findings = []
        self.stats = {
            "total": 0,
            "regular": 0,
            "lateral": 0,
            "student_ids_supplied": 0,
            "duplicate_rolls": 0,
            "duplicate_names": 0,
            "invalid_classes": 0,
            "invalid_entry_types": 0,
            "non_contiguous_gaps": [],
        }

        # 1. File existence and JSON syntax check
        if not os.path.exists(self.filepath):
            self.add_finding(
                LEVEL_FAIL,
                "file",
                f"File not found at {self.filepath}",
                "Create college_seed/students_class2_development.json"
            )
            return 2, self.findings

        try:
            with open(self.filepath, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            self.add_finding(
                LEVEL_FAIL,
                "json_syntax",
                f"JSON syntax error: {str(e)}",
                "Ensure valid JSON formatting"
            )
            return 2, self.findings

        if not isinstance(data, list):
            self.add_finding(
                LEVEL_FAIL,
                "structure",
                "Roster root element must be a JSON list of objects",
                "Wrap records in a top-level JSON array [...]"
            )
            return 2, self.findings

        self.stats["total"] = len(data)

        # 2. Record count validation
        if len(data) != EXPECTED_TOTAL_STUDENTS:
            self.add_finding(
                LEVEL_FAIL,
                "record_count",
                f"Expected exactly {EXPECTED_TOTAL_STUDENTS} students from official roster, found {len(data)}",
                "Match the 55 visible records from the official source photographs"
            )
        else:
            self.add_finding(
                LEVEL_PASS,
                "record_count",
                f"Roster count matches official source ({EXPECTED_TOTAL_STUDENTS} students)"
            )

        # 3. Per-record schema, type, and value validation
        seen_rolls = set()
        duplicate_rolls = set()
        seen_names = set()
        duplicate_names = set()
        reg_numbers = []

        required_keys = {"roll_number", "student_id", "full_name", "class_name", "entry_type", "is_active"}

        for idx, student in enumerate(data):
            pos = f"Record #{idx+1}"

            if not isinstance(student, dict):
                self.add_finding(
                    LEVEL_FAIL,
                    f"{pos}",
                    "Student entry must be a JSON dictionary",
                    "Fix entry structure"
                )
                continue

            missing_keys = required_keys - set(student.keys())
            if missing_keys:
                self.add_finding(
                    LEVEL_FAIL,
                    f"{pos}",
                    f"Missing required fields: {', '.join(missing_keys)}",
                    "Add all required fields to each record"
                )

            # Roll Number
            roll = student.get("roll_number")
            if not roll or not isinstance(roll, str) or not roll.strip():
                self.add_finding(
                    LEVEL_FAIL,
                    f"{pos}.roll_number",
                    "Missing or empty register number",
                    "Provide exact register number"
                )
            else:
                roll_str = roll.strip()
                reg_numbers.append(roll_str)
                if roll_str in seen_rolls:
                    duplicate_rolls.add(roll_str)
                seen_rolls.add(roll_str)

            # Student ID (Must be null)
            student_id = student.get("student_id")
            if student_id is not None:
                self.stats["student_ids_supplied"] += 1
                self.add_finding(
                    LEVEL_FAIL,
                    f"{pos}.student_id",
                    f"Student ID must be null since source photographs do not provide Student IDs (found: {student_id})",
                    "Set student_id to null"
                )

            # Full Name
            name = student.get("full_name")
            if not name or not isinstance(name, str) or not name.strip():
                self.add_finding(
                    LEVEL_FAIL,
                    f"{pos}.full_name",
                    "Missing or empty student full name",
                    "Provide official student name"
                )
            else:
                name_clean = name.strip()
                if name_clean in seen_names:
                    duplicate_names.add(name_clean)
                seen_names.add(name_clean)

            # Class Name
            class_name = student.get("class_name")
            if class_name != EXPECTED_CLASS_NAME:
                self.stats["invalid_classes"] += 1
                self.add_finding(
                    LEVEL_FAIL,
                    f"{pos}.class_name",
                    f"Invalid class name '{class_name}'. Expected '{EXPECTED_CLASS_NAME}'",
                    f"Set class_name to '{EXPECTED_CLASS_NAME}'"
                )

            # Entry Type
            entry_type = student.get("entry_type")
            if entry_type not in VALID_ENTRY_TYPES:
                self.stats["invalid_entry_types"] += 1
                self.add_finding(
                    LEVEL_FAIL,
                    f"{pos}.entry_type",
                    f"Invalid entry_type '{entry_type}'. Must be one of {VALID_ENTRY_TYPES}",
                    "Set entry_type to 'REGULAR'"
                )
            else:
                if entry_type == "REGULAR":
                    self.stats["regular"] += 1
                elif entry_type == "LATERAL_ENTRY":
                    self.stats["lateral"] += 1

            # Is Active
            is_active = student.get("is_active")
            if not isinstance(is_active, bool):
                self.add_finding(
                    LEVEL_FAIL,
                    f"{pos}.is_active",
                    f"is_active must be a boolean (true/false), got {type(is_active).__name__}",
                    "Set is_active to true"
                )

        # 4. Duplicate checks
        self.stats["duplicate_rolls"] = len(duplicate_rolls)
        if duplicate_rolls:
            self.add_finding(
                LEVEL_FAIL,
                "uniqueness",
                f"Found {len(duplicate_rolls)} duplicate register numbers: {', '.join(sorted(duplicate_rolls))}",
                "Ensure each register number is unique"
            )
        else:
            self.add_finding(
                LEVEL_PASS,
                "uniqueness",
                "All register numbers are 100% unique"
            )

        self.stats["duplicate_names"] = len(duplicate_names)
        if duplicate_names:
            self.add_finding(
                LEVEL_WARN,
                "names",
                f"Identified shared student names in roster: {', '.join(sorted(duplicate_names))}"
            )

        # 5. Non-contiguous sequence audit (Informational warning only)
        if len(reg_numbers) > 1:
            try:
                nums = [int(r) for r in reg_numbers]
                min_n = min(nums)
                max_n = max(nums)
                full_range = set(range(min_n, max_n + 1))
                missing_in_range = sorted(list(full_range - set(nums)))
                if missing_in_range:
                    missing_strs = [str(m) for m in missing_in_range]
                    self.stats["non_contiguous_gaps"] = missing_strs
                    self.add_finding(
                        LEVEL_WARN,
                        "sequence_continuity",
                        f"Preserved official non-contiguous register numbers in range [{min_n}..{max_n}]. "
                        f"Visible source gaps: {', '.join(missing_strs)} (do not fabricate missing records)."
                    )
            except ValueError:
                pass

        # 6. Lateral entry audit
        if self.stats["lateral"] != EXPECTED_LATERAL_STUDENTS:
            self.add_finding(
                LEVEL_WARN,
                "entry_type",
                f"Lateral entry count is {self.stats['lateral']} (expected {EXPECTED_LATERAL_STUDENTS})"
            )

        # 7. Capacity validation (64 existing + 55 Class 2 = 119 / 130)
        existing_class1_count = 64
        projected_total = existing_class1_count + self.stats["total"]
        remaining_capacity = MAX_SYSTEM_STUDENT_CAPACITY - projected_total

        if projected_total > MAX_SYSTEM_STUDENT_CAPACITY:
            self.add_finding(
                LEVEL_FAIL,
                "capacity",
                f"Projected total {projected_total} exceeds MAX_CAPACITY {MAX_SYSTEM_STUDENT_CAPACITY}",
                "Reduce roster size or adjust capacity configuration"
            )
        else:
            self.add_finding(
                LEVEL_PASS,
                "capacity",
                f"Capacity Check PASS: Current: {existing_class1_count} + Class 2: {self.stats['total']} = "
                f"{projected_total} / {MAX_SYSTEM_STUDENT_CAPACITY} (Remaining capacity: {remaining_capacity})"
            )

        # Determine overall exit code
        has_fail = any(f.level == LEVEL_FAIL for f in self.findings)
        has_warn = any(f.level == LEVEL_WARN for f in self.findings)

        if has_fail:
            return 2, self.findings
        elif has_warn:
            return 1, self.findings
        return 0, self.findings


def main():
    filepath = sys.argv[1] if len(sys.argv) > 1 else "college_seed/students_class2_development.json"
    validator = Class2RosterValidator(filepath)
    exit_code, findings = validator.validate()

    print("=" * 80)
    print("CLASS 2 STUDENT ROSTER VALIDATION REPORT")
    print("=" * 80)
    print(f"Target File:        {validator.filepath}")
    print(f"Total Records:      {validator.stats['total']}")
    print(f"Regular Students:   {validator.stats['regular']}")
    print(f"Lateral Entry:      {validator.stats['lateral']}")
    print(f"Student IDs:        {validator.stats['student_ids_supplied']} supplied (0 expected)")
    print(f"Duplicates:         {validator.stats['duplicate_rolls']}")
    if validator.stats['non_contiguous_gaps']:
        print(f"Source Gaps:        {', '.join(validator.stats['non_contiguous_gaps'])}")
    print(f"Projected Capacity: 64 + {validator.stats['total']} = {64 + validator.stats['total']} / {MAX_SYSTEM_STUDENT_CAPACITY}")
    print(f"Remaining Capacity: {MAX_SYSTEM_STUDENT_CAPACITY - (64 + validator.stats['total'])}")
    print("-" * 80)

    pass_count = sum(1 for f in findings if f.level == LEVEL_PASS)
    warn_count = sum(1 for f in findings if f.level == LEVEL_WARN)
    fail_count = sum(1 for f in findings if f.level == LEVEL_FAIL)

    for f in findings:
        prefix = f"[{f.level}]"
        print(f"{prefix:<8} {f.field:<22} : {f.problem}")
        if f.recommendation:
            print(f"         {'-> Recommendation':<22} : {f.recommendation}")

    print("=" * 80)
    print(f"SUMMARY: PASS={pass_count}, WARN={warn_count}, FAIL={fail_count}")

    if exit_code == 0 or exit_code == 1:
        print("RESULT: VALIDATION PASSED (Roster is compliant with official source)")
        sys.exit(0)
    else:
        print("RESULT: VALIDATION FAILED")
        sys.exit(2)


if __name__ == "__main__":
    main()
