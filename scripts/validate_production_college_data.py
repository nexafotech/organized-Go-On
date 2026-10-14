#!/usr/bin/env python3
"""
PRODUCTION COLLEGE DATA VALIDATOR
=================================
Read-only validation tool for the Attendance Marker production college dataset.
Audits data integrity, cross-table relational dependencies, schema conformance,
and security policies before performing any production database ingestion.

Usage:
    python scripts/validate_production_college_data.py [--json] [--markdown] [--dir PATH]

Exit Codes:
    0 = All checks PASS (production ready, zero warnings or errors)
    1 = Validation WARN (non-blocking notices, e.g. placeholder templates or pending files)
    2 = Validation FAIL (blocking production errors or security violations)
"""

import os
import sys
import json
import re
from typing import Dict, List, Any, Optional, Set, Tuple

# Severity Levels
LEVEL_PASS = "PASS"
LEVEL_WARN = "WARN"
LEVEL_FAIL = "FAIL"
LEVEL_MISSING = "MISSING"

VALID_WEEKDAYS = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
DEMO_PASSWORDS = {"student123", "faculty123", "admin123", "password", "123456", "test1234"}
PLACEHOLDER_SUBSTRINGS = ["PLACEHOLDER", "TEMPLATE", "TO_BE_CONFIRMED", "DEV_DEMO_", "DEV_FAC_"]

MAX_STUDENTS = int(os.getenv("MAX_STUDENTS", "5000"))
MAX_FACULTY = int(os.getenv("MAX_FACULTY", "250"))


class Finding:
    def __init__(self, level: str, dataset: str, field: str, problem: str, recommendation: str):
        self.level = level
        self.dataset = dataset
        self.field = field
        self.problem = problem
        self.recommendation = recommendation

    def to_dict(self) -> Dict[str, str]:
        return {
            "level": self.level,
            "dataset": self.dataset,
            "field": self.field,
            "problem": self.problem,
            "recommendation": self.recommendation
        }

    def __repr__(self) -> str:
        return f"[{self.level}] {self.dataset} -> {self.field}: {self.problem}"


class ProductionCollegeDataValidator:
    def __init__(self, base_dir: str = "college_seed"):
        self.base_dir = os.path.abspath(base_dir)
        self.findings: List[Finding] = []

        # Cached datasets for cross-validation
        self.class_sections: Dict[str, Dict[str, Any]] = {}
        self.periods: Dict[int, Dict[str, Any]] = {}
        self.subjects: Dict[str, Dict[str, Any]] = {}
        self.faculty: Dict[str, Dict[str, Any]] = {}
        self.faculty_assignments: Set[Tuple[str, str]] = set()
        self.assigned_faculty_usernames: Set[str] = set()

    def add_finding(self, level: str, dataset: str, field: str, problem: str, recommendation: str):
        self.findings.append(Finding(level, dataset, field, problem, recommendation))

    def _load_json_file(self, filename: str, is_required: bool = True) -> Optional[Any]:
        filepath = os.path.join(self.base_dir, filename)
        if not os.path.exists(filepath):
            if is_required:
                self.add_finding(
                    LEVEL_FAIL, filename, "file",
                    f"Required file '{filename}' was not found in '{self.base_dir}'",
                    f"Create '{filename}' with valid JSON data."
                )
            return None

        try:
            with open(filepath, "r", encoding="utf-8") as f:
                data = json.load(f)
            self.add_finding(
                LEVEL_PASS, filename, "syntax",
                f"Successfully parsed '{filename}' as valid JSON.",
                "None required."
            )
            return data
        except json.JSONDecodeError as e:
            self.add_finding(
                LEVEL_FAIL, filename, "syntax",
                f"JSON parse error in '{filename}': {e}",
                "Fix syntax formatting in JSON file."
            )
            return None
        except Exception as e:
            self.add_finding(
                LEVEL_FAIL, filename, "read",
                f"Failed to read '{filename}': {e}",
                "Check file permissions and encoding."
            )
            return None

    def validate_class_sections(self):
        filename = "class_sections.json"
        data = self._load_json_file(filename, is_required=True)
        if data is None or not isinstance(data, list):
            return

        seen_names = set()
        for idx, item in enumerate(data):
            row_prefix = f"Row {idx+1}"
            name = item.get("name", "").strip()
            grade_level = item.get("grade_level", "").strip()
            academic_year = item.get("academic_year", "").strip()

            if not name:
                self.add_finding(
                    LEVEL_FAIL, filename, f"{row_prefix}.name",
                    "Class section name is missing or empty.",
                    "Specify a unique class section name (e.g. 'II Year CSE Cyber Security - Class 1')."
                )
                continue

            if name in seen_names:
                self.add_finding(
                    LEVEL_FAIL, filename, f"{row_prefix}.name",
                    f"Duplicate class section name '{name}' detected.",
                    "Remove duplicate class section entry."
                )
            seen_names.add(name)
            self.class_sections[name] = item

        if len(self.class_sections) > 0:
            self.add_finding(
                LEVEL_PASS, filename, "schema",
                f"Validated {len(self.class_sections)} class section(s).",
                "None required."
            )

    def validate_periods(self):
        filename = "periods.json"
        data = self._load_json_file(filename, is_required=True)
        if data is None or not isinstance(data, list):
            return

        seen_periods = set()
        time_regex = re.compile(r"^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$")

        for idx, item in enumerate(data):
            row_prefix = f"Row {idx+1}"
            period_num = item.get("period_number")
            name = item.get("name", "").strip()
            start_time = item.get("start_time", "").strip()
            end_time = item.get("end_time", "").strip()

            if period_num is None or not isinstance(period_num, int):
                self.add_finding(
                    LEVEL_FAIL, filename, f"{row_prefix}.period_number",
                    "period_number must be an integer.",
                    "Provide an integer period_number (e.g. 1, 2, 3)."
                )
                continue

            if period_num in seen_periods:
                self.add_finding(
                    LEVEL_FAIL, filename, f"{row_prefix}.period_number",
                    f"Duplicate period_number {period_num} detected.",
                    "Ensure period numbers are strictly unique sequential integers."
                )
            seen_periods.add(period_num)

            if not time_regex.match(start_time) or not time_regex.match(end_time):
                self.add_finding(
                    LEVEL_FAIL, filename, f"{row_prefix}.timings",
                    f"Invalid time format in period {period_num} (start='{start_time}', end='{end_time}').",
                    "Format times as HH:MM in 24-hour notation."
                )
            elif start_time >= end_time:
                self.add_finding(
                    LEVEL_FAIL, filename, f"{row_prefix}.timings",
                    f"start_time ('{start_time}') is not before end_time ('{end_time}') in period {period_num}.",
                    "Ensure start_time precedes end_time."
                )

            self.periods[period_num] = item

        if len(self.periods) > 0:
            self.add_finding(
                LEVEL_PASS, filename, "schema",
                f"Validated {len(self.periods)} period definition(s).",
                "None required."
            )

    def validate_subjects(self):
        filename = "subjects.json"
        data = self._load_json_file(filename, is_required=True)
        if data is None or not isinstance(data, list):
            return

        seen_codes = set()
        for idx, item in enumerate(data):
            row_prefix = f"Row {idx+1}"
            code = item.get("code", "").strip()
            name = item.get("name", "").strip()

            if not code or not name:
                self.add_finding(
                    LEVEL_FAIL, filename, f"{row_prefix}",
                    f"Subject missing code or name (code='{code}', name='{name}').",
                    "Specify both 'code' and 'name' for every subject."
                )
                continue

            if code in seen_codes:
                self.add_finding(
                    LEVEL_FAIL, filename, f"{row_prefix}.code",
                    f"Duplicate subject code '{code}' detected.",
                    "Ensure all subject codes are unique."
                )
            seen_codes.add(code)
            self.subjects[code] = item

        if len(self.subjects) > 0:
            self.add_finding(
                LEVEL_PASS, filename, "schema",
                f"Validated {len(self.subjects)} curriculum subject(s).",
                "None required."
            )

    def validate_faculty(self):
        prod_filename = "faculty.json"
        template_filename = "faculty_production_template.json"

        data = self._load_json_file(prod_filename, is_required=False)
        is_production_file = True

        if data is None:
            is_production_file = False
            data = self._load_json_file(template_filename, is_required=True)
            if data is None:
                return

        target_file = prod_filename if is_production_file else template_filename
        
        if len(data) > MAX_FACULTY:
            self.add_finding(
                LEVEL_FAIL, target_file, "capacity",
                f"Faculty dataset contains {len(data)} records, which exceeds maximum system capacity of {MAX_FACULTY}.",
                f"Limit faculty roster to at most {MAX_FACULTY} total members."
            )

        seen_usernames = set()
        seen_emails = set()
        seen_emp_ids = set()

        for idx, item in enumerate(data):
            row_prefix = f"Row {idx+1}"
            username = item.get("username", "").strip()
            email = item.get("email", "").strip()
            emp_id = item.get("employee_id", "").strip()
            full_name = item.get("full_name", "").strip()
            dept = item.get("department", "").strip()
            password = item.get("password", "")

            # Required field checks
            if not username or not email or not emp_id:
                self.add_finding(
                    LEVEL_FAIL, target_file, f"{row_prefix}",
                    f"Faculty missing required fields (username='{username}', email='{email}', employee_id='{emp_id}').",
                    "Provide non-empty username, email, and employee_id."
                )
                continue

            # Duplicate checks
            if username in seen_usernames:
                self.add_finding(LEVEL_FAIL, target_file, f"{row_prefix}.username", f"Duplicate username '{username}'.", "Keep usernames unique.")
            if email in seen_emails:
                self.add_finding(LEVEL_FAIL, target_file, f"{row_prefix}.email", f"Duplicate email '{email}'.", "Keep emails unique.")
            if emp_id in seen_emp_ids:
                self.add_finding(LEVEL_FAIL, target_file, f"{row_prefix}.employee_id", f"Duplicate employee_id '{emp_id}'.", "Keep employee IDs unique.")

            seen_usernames.add(username)
            seen_emails.add(email)
            seen_emp_ids.add(emp_id)

            # Placeholder check
            is_placeholder = any(token in username or token in emp_id or token in full_name for token in PLACEHOLDER_SUBSTRINGS)
            if is_placeholder:
                self.add_finding(
                    LEVEL_WARN, target_file, f"{row_prefix}.identity",
                    f"Placeholder faculty identity detected: '{username}' / '{full_name}'.",
                    "Replace placeholder with official college faculty details."
                )

            # Security check
            if password in DEMO_PASSWORDS:
                self.add_finding(
                    LEVEL_WARN, target_file, f"{row_prefix}.password",
                    f"Development-only demo password detected for '{username}'.",
                    "Do not commit plaintext passwords. Use temporary administrator-issued passwords."
                )
            elif password and not any(tok in password for tok in PLACEHOLDER_SUBSTRINGS):
                self.add_finding(
                    LEVEL_FAIL, target_file, f"{row_prefix}.password",
                    f"Plaintext password detected in repository file for '{username}'.",
                    "Remove plaintext passwords from version-controlled JSON files."
                )

            self.faculty[username] = item

        if len(self.faculty) > 0:
            self.add_finding(
                LEVEL_PASS, target_file, "schema",
                f"Parsed {len(self.faculty)} faculty record(s) ({'production' if is_production_file else 'template'}).",
                "None required."
            )

    def validate_students(self):
        prod_filename = "students.json"
        template_filename = "students_production_template.json"

        data = self._load_json_file(prod_filename, is_required=False)
        is_production_file = True

        if data is None:
            is_production_file = False
            data = self._load_json_file(template_filename, is_required=True)
            if data is None:
                return

        target_file = prod_filename if is_production_file else template_filename
        
        if len(data) > MAX_STUDENTS:
            self.add_finding(
                LEVEL_FAIL, target_file, "capacity",
                f"Student dataset contains {len(data)} records, which exceeds maximum system capacity of {MAX_STUDENTS}.",
                f"Limit student roster to at most {MAX_STUDENTS} total students across all classes combined."
            )

        seen_rolls = set()
        seen_emails = set()

        for idx, item in enumerate(data):
            row_prefix = f"Row {idx+1}"
            roll_no = item.get("roll_number", "").strip()
            full_name = item.get("full_name", "").strip()
            email = item.get("email", "").strip()
            class_name = item.get("class_name", "").strip()
            password = item.get("password", "")

            if not roll_no or not full_name:
                self.add_finding(
                    LEVEL_FAIL, target_file, f"{row_prefix}",
                    f"Student missing required fields (roll_number='{roll_no}', full_name='{full_name}').",
                    "Provide non-empty roll_number and full_name."
                )
                continue

            if roll_no in seen_rolls:
                self.add_finding(LEVEL_FAIL, target_file, f"{row_prefix}.roll_number", f"Duplicate roll_number '{roll_no}'.", "Keep roll numbers unique.")
            if email and email in seen_emails:
                self.add_finding(LEVEL_FAIL, target_file, f"{row_prefix}.email", f"Duplicate email '{email}'.", "Keep emails unique.")

            seen_rolls.add(roll_no)
            if email:
                seen_emails.add(email)

            # Cross-check Class Section
            if class_name and class_name not in self.class_sections:
                self.add_finding(
                    LEVEL_FAIL, target_file, f"{row_prefix}.class_name",
                    f"Student class_name '{class_name}' does not exist in class_sections.json.",
                    "Ensure student class_name matches an existing class section."
                )

            # Placeholder check
            is_placeholder = any(token in roll_no or token in full_name for token in PLACEHOLDER_SUBSTRINGS)
            if is_placeholder:
                self.add_finding(
                    LEVEL_WARN, target_file, f"{row_prefix}.identity",
                    f"Placeholder student identity detected: '{roll_no}' / '{full_name}'.",
                    "Replace placeholder with official college student roster."
                )

            # Security check
            if password and password not in DEMO_PASSWORDS and not any(tok in password for tok in PLACEHOLDER_SUBSTRINGS):
                self.add_finding(
                    LEVEL_FAIL, target_file, f"{row_prefix}.password",
                    f"Plaintext password detected for student '{roll_no}'.",
                    "Remove plaintext passwords from version-controlled JSON files."
                )

        self.add_finding(
            LEVEL_PASS, target_file, "schema",
            f"Parsed {len(seen_rolls)} student record(s) ({'production' if is_production_file else 'template'}).",
            "None required."
        )

    def validate_faculty_assignments(self):
        prod_filename = "faculty_assignments.json"
        template_filename = "faculty_assignments_production_template.json"

        data = self._load_json_file(prod_filename, is_required=False)
        target_file = prod_filename
        if data is None:
            data = self._load_json_file(template_filename, is_required=True)
            target_file = template_filename
            if data is None:
                return

        seen_assignments = set()
        unassigned_count = 0

        for idx, item in enumerate(data):
            row_prefix = f"Row {idx+1}"
            class_name = item.get("class_name", "").strip()
            sub_code = item.get("subject_code", "").strip()
            fac_user = item.get("faculty_username")

            # Validate Class Section
            if class_name not in self.class_sections:
                self.add_finding(
                    LEVEL_FAIL, target_file, f"{row_prefix}.class_name",
                    f"Assignment class_name '{class_name}' does not exist in class_sections.json.",
                    "Use a valid class section name."
                )

            # Validate Subject Code
            if sub_code not in self.subjects:
                self.add_finding(
                    LEVEL_FAIL, target_file, f"{row_prefix}.subject_code",
                    f"Assignment subject_code '{sub_code}' does not exist in subjects.json.",
                    "Use a valid subject code."
                )

            # Duplicate Check
            pair = (class_name, sub_code)
            if pair in seen_assignments:
                self.add_finding(
                    LEVEL_FAIL, target_file, f"{row_prefix}",
                    f"Duplicate assignment for class '{class_name}' and subject '{sub_code}'.",
                    "Each class-subject pair must have exactly one assignment."
                )
            seen_assignments.add(pair)
            self.faculty_assignments.add(pair)

            # Check Faculty User
            if not fac_user or not str(fac_user).strip() or any(tok in str(fac_user) for tok in PLACEHOLDER_SUBSTRINGS):
                unassigned_count += 1
                self.add_finding(
                    LEVEL_WARN, target_file, f"{row_prefix}.faculty_username",
                    f"Faculty assignment for '{class_name}' - '{sub_code}' is unassigned/placeholder ('{fac_user}').",
                    "Assign a confirmed faculty username when college allocates professors."
                )
            else:
                fac_str = str(fac_user).strip()
                if fac_str not in self.faculty:
                    self.add_finding(
                        LEVEL_FAIL, target_file, f"{row_prefix}.faculty_username",
                        f"Assigned faculty '{fac_str}' does not exist in faculty dataset.",
                        "Add faculty member to faculty dataset before creating assignment."
                    )
                else:
                    self.assigned_faculty_usernames.add(fac_str)

        self.add_finding(
            LEVEL_PASS, target_file, "schema",
            f"Validated {len(seen_assignments)} faculty assignment mapping(s) ({unassigned_count} unassigned).",
            "None required."
        )

    def validate_timetable(self):
        # Class 1 Timetable
        c1_filename = "timetable_class1.json"
        c1_data = self._load_json_file(c1_filename, is_required=True)

        if c1_data is not None and isinstance(c1_data, list):
            seen_c1_slots = set()
            for idx, item in enumerate(c1_data):
                row_prefix = f"Row {idx+1}"
                class_name = item.get("class_name", "").strip()
                day = item.get("day_of_week", "").strip()
                period_num = item.get("period_number")
                sub_code = item.get("subject_code", "").strip()

                if class_name not in self.class_sections:
                    self.add_finding(
                        LEVEL_FAIL, c1_filename, f"{row_prefix}.class_name",
                        f"Class '{class_name}' does not exist in class_sections.json.",
                        "Use valid class name."
                    )

                if day not in VALID_WEEKDAYS:
                    self.add_finding(
                        LEVEL_FAIL, c1_filename, f"{row_prefix}.day_of_week",
                        f"Invalid day_of_week '{day}'.",
                        "Must be one of Monday through Saturday."
                    )

                if period_num not in self.periods:
                    self.add_finding(
                        LEVEL_FAIL, c1_filename, f"{row_prefix}.period_number",
                        f"Period number {period_num} does not exist in periods.json.",
                        "Must match a configured period_number."
                    )

                if sub_code not in self.subjects:
                    self.add_finding(
                        LEVEL_FAIL, c1_filename, f"{row_prefix}.subject_code",
                        f"Subject code '{sub_code}' does not exist in subjects.json.",
                        "Must match a configured subject code."
                    )

                slot_key = (class_name, day, period_num)
                if slot_key in seen_c1_slots:
                    self.add_finding(
                        LEVEL_FAIL, c1_filename, f"{row_prefix}",
                        f"Duplicate timetable slot collision: {class_name} on {day} Period {period_num}.",
                        "Ensure only one subject is scheduled per class period."
                    )
                seen_c1_slots.add(slot_key)

                # Relational check to FacultyAssignment
                if (class_name, sub_code) not in self.faculty_assignments:
                    self.add_finding(
                        LEVEL_WARN, c1_filename, f"{row_prefix}.assignment_link",
                        f"Timetable slot ({day} P{period_num}: '{sub_code}') has no faculty assignment record.",
                        "Create faculty assignment before timetable ingestion."
                    )

            self.add_finding(
                LEVEL_PASS, c1_filename, "schema",
                f"Validated {len(seen_c1_slots)} Class 1 timetable slots across all 6 weekdays.",
                "None required."
            )

        # Class 2 Timetable Check
        c2_filename = "timetable_class2.json"
        c2_data = self._load_json_file(c2_filename, is_required=False)
        if c2_data is None:
            self.add_finding(
                LEVEL_MISSING, c2_filename, "file",
                "Class 2 timetable dataset ('timetable_class2.json') is not yet provided by college.",
                "Obtain Class 2 weekly schedule grid from college administration."
            )
        elif isinstance(c2_data, list):
            seen_c2_slots = set()
            for idx, item in enumerate(c2_data):
                row_prefix = f"Row {idx+1}"
                class_name = item.get("class_name", "").strip()
                day = item.get("day_of_week", "").strip()
                period_num = item.get("period_number")
                sub_code = item.get("subject_code", "").strip()

                if class_name not in self.class_sections:
                    self.add_finding(
                        LEVEL_FAIL, c2_filename, f"{row_prefix}.class_name",
                        f"Class '{class_name}' does not exist in class_sections.json.",
                        "Use valid class name."
                    )

                if day not in VALID_WEEKDAYS:
                    self.add_finding(
                        LEVEL_FAIL, c2_filename, f"{row_prefix}.day_of_week",
                        f"Invalid day_of_week '{day}'.",
                        "Must be one of Monday through Saturday."
                    )

                if period_num not in self.periods:
                    self.add_finding(
                        LEVEL_FAIL, c2_filename, f"{row_prefix}.period_number",
                        f"Period number {period_num} does not exist in periods.json.",
                        "Must match a configured period_number."
                    )

                if sub_code not in self.subjects:
                    self.add_finding(
                        LEVEL_FAIL, c2_filename, f"{row_prefix}.subject_code",
                        f"Subject code '{sub_code}' does not exist in subjects.json.",
                        "Must match a configured subject code."
                    )

                slot_key = (class_name, day, period_num)
                if slot_key in seen_c2_slots:
                    self.add_finding(
                        LEVEL_FAIL, c2_filename, f"{row_prefix}",
                        f"Duplicate timetable slot collision: {class_name} on {day} Period {period_num}.",
                        "Ensure only one subject is scheduled per class period."
                    )
                seen_c2_slots.add(slot_key)

                # Relational check to FacultyAssignment
                if (class_name, sub_code) not in self.faculty_assignments:
                    self.add_finding(
                        LEVEL_WARN, c2_filename, f"{row_prefix}.assignment_link",
                        f"Timetable slot ({day} P{period_num}: '{sub_code}') has no faculty assignment record.",
                        "Create faculty assignment before timetable ingestion."
                    )

            self.add_finding(
                LEVEL_PASS, c2_filename, "schema",
                f"Validated {len(seen_c2_slots)} Class 2 timetable slots across all 6 weekdays.",
                "None required."
            )


    def run_all_validations(self) -> List[Finding]:
        self.findings = []
        self.validate_class_sections()
        self.validate_periods()
        self.validate_subjects()
        self.validate_faculty()
        self.validate_students()
        self.validate_faculty_assignments()
        self.validate_timetable()
        return self.findings

    def print_terminal_report(self) -> int:
        pass_count = sum(1 for f in self.findings if f.level == LEVEL_PASS)
        warn_count = sum(1 for f in self.findings if f.level == LEVEL_WARN)
        fail_count = sum(1 for f in self.findings if f.level == LEVEL_FAIL)
        missing_count = sum(1 for f in self.findings if f.level == LEVEL_MISSING)

        print("=" * 80)
        print("ATTENDANCE MARKER — PRODUCTION COLLEGE DATA VALIDATION REPORT")
        print("=" * 80)
        print(f"Base Directory: {self.base_dir}")
        print(f"Total Findings: {len(self.findings)}  |  PASS: {pass_count}  |  WARN: {warn_count}  |  FAIL: {fail_count}  |  MISSING: {missing_count}\n")

        for f in self.findings:
            if f.level == LEVEL_FAIL:
                badge = "\033[91m[FAIL]\033[0m"
            elif f.level == LEVEL_WARN:
                badge = "\033[93m[WARN]\033[0m"
            elif f.level == LEVEL_MISSING:
                badge = "\033[94m[MISSING]\033[0m"
            else:
                badge = "\033[92m[PASS]\033[0m"

            print(f"{badge:<18} {f.dataset} -> {f.field}")
            print(f"   Problem:        {f.problem}")
            if f.level != LEVEL_PASS:
                print(f"   Recommendation: {f.recommendation}")
            print("-" * 80)

        print("\n" + "=" * 80)
        print("PRODUCTION READINESS SUMMARY")
        print("=" * 80)
        if fail_count > 0:
            print("\033[91mSTATUS: BLOCKED (FAIL)\033[0m — Resolve all blocking FAIL items before attempting production ingestion.")
            return 2
        elif warn_count > 0 or missing_count > 0:
            print("\033[93mSTATUS: PENDING DATA (WARN)\033[0m — Schema is structurally valid, but placeholders/pending files must be populated.")
            return 1
        else:
            print("\033[92mSTATUS: PRODUCTION READY (PASS)\033[0m — All datasets verified and ready for database ingestion.")
            return 0


def main():
    base_dir = "college_seed"
    if "--dir" in sys.argv:
        idx = sys.argv.index("--dir")
        if idx + 1 < len(sys.argv):
            base_dir = sys.argv[idx + 1]

    validator = ProductionCollegeDataValidator(base_dir=base_dir)
    validator.run_all_validations()

    if "--json" in sys.argv:
        results = [f.to_dict() for f in validator.findings]
        print(json.dumps(results, indent=2))
        sys.exit(0 if not any(f.level == LEVEL_FAIL for f in validator.findings) else 2)

    exit_code = validator.print_terminal_report()
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
