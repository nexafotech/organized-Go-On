import os
import sys
import json
import unittest
import tempfile
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Ensure project root is in sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import Base
from app.models.academic import ClassSection, Period, Subject, FacultyAssignment, TimetableEntry
from app.models.user import User, Faculty, UserRole
from app.models.student import Student
from scripts.validate_production_college_data import ProductionCollegeDataValidator
from scripts.import_production_college_data import ControlledProductionImporter


def create_valid_test_bundle(tmpdir: str) -> None:
    """Helper to create a fully valid, non-placeholder, non-demo college dataset bundle."""
    # 1. Class Sections
    with open(os.path.join(tmpdir, "class_sections.json"), "w", encoding="utf-8") as f:
        json.dump([
            {"name": "II Year CSE Cyber Security - Class 1", "grade_level": "II Year", "academic_year": "2026-2027"},
            {"name": "III Year CSE Cyber Security - Class 2", "grade_level": "III Year", "academic_year": "2026-2027"}
        ], f)

    # 2. Periods
    with open(os.path.join(tmpdir, "periods.json"), "w", encoding="utf-8") as f:
        json.dump([
            {"period_number": 1, "name": "Period 1", "start_time": "09:10", "end_time": "10:00"},
            {"period_number": 2, "name": "Period 2", "start_time": "10:00", "end_time": "10:50"}
        ], f)

    # 3. Subjects
    with open(os.path.join(tmpdir, "subjects.json"), "w", encoding="utf-8") as f:
        json.dump([
            {"code": "FDS", "name": "Foundations of Data Science"},
            {"code": "DMC", "name": "Discrete Mathematics"}
        ], f)

    # 4. Faculty (Production, non-placeholder, zero-credential compliant)
    with open(os.path.join(tmpdir, "faculty.json"), "w", encoding="utf-8") as f:
        json.dump([
            {
                "username": "prof_alice",
                "email": "alice@college.edu",
                "employee_id": "EMP_OFFICIAL_101",
                "full_name": "Prof. Alice Walker",
                "department": "Cyber Security",
                "is_active": True
            }
        ], f)

    # 5. Faculty Assignments (Non-null, valid links)
    with open(os.path.join(tmpdir, "faculty_assignments.json"), "w", encoding="utf-8") as f:
        json.dump([
            {
                "class_name": "II Year CSE Cyber Security - Class 1",
                "subject_code": "FDS",
                "faculty_username": "prof_alice"
            }
        ], f)

    # 6. Timetable
    with open(os.path.join(tmpdir, "timetable_class1.json"), "w", encoding="utf-8") as f:
        json.dump([
            {
                "class_name": "II Year CSE Cyber Security - Class 1",
                "day_of_week": "Monday",
                "period_number": 1,
                "subject_code": "FDS"
            }
        ], f)

    with open(os.path.join(tmpdir, "timetable_class2.json"), "w", encoding="utf-8") as f:
        json.dump([], f)

    # 7. Students (Production, non-placeholder, non-demo password)
    with open(os.path.join(tmpdir, "students.json"), "w", encoding="utf-8") as f:
        json.dump([
            {
                "roll_number": "23CY999",
                "full_name": "Authentic Student Name",
                "email": "23cy999@student.college.edu",
                "class_name": "II Year CSE Cyber Security - Class 1",
                "semester": "Semester 4",
                "department": "Cyber Security",
                "is_active": True
            }
        ], f)


class TestProductionImportWorkflow(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(bind=self.engine)
        Session = sessionmaker(bind=self.engine)
        self.db = Session()

    def tearDown(self):
        self.db.close()
        Base.metadata.drop_all(bind=self.engine)

    def test_1_fail_blocks_import(self):
        """Test that a dataset with FAIL validation errors is strictly blocked from importing."""
        with tempfile.TemporaryDirectory() as tmpdir:
            create_valid_test_bundle(tmpdir)
            # Introduce a corrupt subject code in timetable (triggers validation FAIL)
            with open(os.path.join(tmpdir, "timetable_class1.json"), "w", encoding="utf-8") as f:
                json.dump([
                    {
                        "class_name": "II Year CSE Cyber Security - Class 1",
                        "day_of_week": "Monday",
                        "period_number": 1,
                        "subject_code": "INVALID_SUBJECT_CODE_XYZ"
                    }
                ], f)

            report_p = os.path.join(tmpdir, "report.md")
            importer = ControlledProductionImporter(
                base_dir=tmpdir,
                report_path=report_p,
                dry_run=False,
                db_session=self.db
            )

            exit_code = importer.run()
            self.assertNotEqual(exit_code, 0)
            self.assertEqual(importer.status, "BLOCKED_GATED")
            self.assertEqual(self.db.query(ClassSection).count(), 0)

    def test_2_missing_blocks_import(self):
        """Test that missing required production datasets blocks import."""
        with tempfile.TemporaryDirectory() as tmpdir:
            create_valid_test_bundle(tmpdir)
            # Remove students.json
            os.remove(os.path.join(tmpdir, "students.json"))

            report_p = os.path.join(tmpdir, "report.md")
            importer = ControlledProductionImporter(
                base_dir=tmpdir,
                report_path=report_p,
                dry_run=False,
                db_session=self.db
            )

            exit_code = importer.run()
            self.assertNotEqual(exit_code, 0)
            self.assertEqual(importer.status, "BLOCKED_GATED")
            self.assertEqual(self.db.query(ClassSection).count(), 0)

    def test_3_demo_credentials_block_import(self):
        """Test that demo passwords like 'faculty123' or 'student123' block production import."""
        with tempfile.TemporaryDirectory() as tmpdir:
            create_valid_test_bundle(tmpdir)
            # Introduce demo password
            with open(os.path.join(tmpdir, "faculty.json"), "w", encoding="utf-8") as f:
                json.dump([
                    {
                        "username": "prof_alice",
                        "email": "alice@college.edu",
                        "employee_id": "EMP_OFFICIAL_101",
                        "full_name": "Prof. Alice Walker",
                        "department": "Cyber Security",
                        "password": "faculty123",  # Demo password
                        "is_active": True
                    }
                ], f)

            report_p = os.path.join(tmpdir, "report.md")
            importer = ControlledProductionImporter(
                base_dir=tmpdir,
                report_path=report_p,
                dry_run=False,
                db_session=self.db
            )

            exit_code = importer.run()
            self.assertNotEqual(exit_code, 0)
            self.assertEqual(importer.status, "BLOCKED_GATED")
            self.assertTrue(any("demo" in err.lower() for err in importer.gating_errors))

    def test_4_placeholder_identities_block_import(self):
        """Test that placeholder identities like 'FACULTY_PLACEHOLDER_001' block production import."""
        with tempfile.TemporaryDirectory() as tmpdir:
            create_valid_test_bundle(tmpdir)
            # Introduce placeholder faculty
            with open(os.path.join(tmpdir, "faculty.json"), "w", encoding="utf-8") as f:
                json.dump([
                    {
                        "username": "FACULTY_PLACEHOLDER_001",
                        "email": "placeholder@college.edu",
                        "employee_id": "EMP_PLACEHOLDER_001",
                        "full_name": "Faculty Member Placeholder",
                        "department": "Cyber Security",
                        "password": "RandomSecurePass99!",
                        "is_active": True
                    }
                ], f)

            report_p = os.path.join(tmpdir, "report.md")
            importer = ControlledProductionImporter(
                base_dir=tmpdir,
                report_path=report_p,
                dry_run=False,
                db_session=self.db
            )

            exit_code = importer.run()
            self.assertNotEqual(exit_code, 0)
            self.assertEqual(importer.status, "BLOCKED_GATED")
            self.assertTrue(any("placeholder" in err.lower() for err in importer.gating_errors))

    def test_5_dry_run_makes_no_db_changes(self):
        """Test that --dry-run performs all validations and dependency imports in transaction but commits zero writes."""
        with tempfile.TemporaryDirectory() as tmpdir:
            create_valid_test_bundle(tmpdir)
            report_p = os.path.join(tmpdir, "report.md")

            importer = ControlledProductionImporter(
                base_dir=tmpdir,
                report_path=report_p,
                dry_run=True,
                db_session=self.db
            )

            exit_code = importer.run()
            self.assertEqual(exit_code, 0)
            self.assertEqual(importer.status, "DRY_RUN_SUCCESS")

            # Assert zero rows persisted to database
            self.assertEqual(self.db.query(ClassSection).count(), 0)
            self.assertEqual(self.db.query(User).count(), 0)
            self.assertEqual(self.db.query(Student).count(), 0)
            self.assertEqual(self.db.query(Subject).count(), 0)

    def test_6_valid_dataset_proceeds_through_dependency_checks(self):
        """Test that a clean, valid dataset passes all gating rules and commits across all 7 stages."""
        with tempfile.TemporaryDirectory() as tmpdir:
            create_valid_test_bundle(tmpdir)
            report_p = os.path.join(tmpdir, "report.md")

            importer = ControlledProductionImporter(
                base_dir=tmpdir,
                report_path=report_p,
                dry_run=False,
                db_session=self.db
            )

            exit_code = importer.run()
            self.assertEqual(exit_code, 0)
            self.assertEqual(importer.status, "IMPORT_COMMITTED")

            # Assert all tables populated correctly
            self.assertEqual(self.db.query(ClassSection).count(), 2)
            self.assertEqual(self.db.query(Period).count(), 2)
            self.assertEqual(self.db.query(Subject).count(), 2)
            self.assertEqual(self.db.query(Faculty).count(), 1)
            self.assertEqual(self.db.query(FacultyAssignment).count(), 1)
            self.assertEqual(self.db.query(TimetableEntry).count(), 1)
            self.assertEqual(self.db.query(Student).count(), 1)

    def test_7_duplicate_data_is_rejected_or_skipped(self):
        """Test that duplicate student roll_number in input batch is rejected."""
        with tempfile.TemporaryDirectory() as tmpdir:
            create_valid_test_bundle(tmpdir)
            # Introduce duplicate student roll_number in students.json
            with open(os.path.join(tmpdir, "students.json"), "w", encoding="utf-8") as f:
                json.dump([
                    {
                        "roll_number": "23CY999",
                        "full_name": "Student Name A",
                        "class_name": "II Year CSE Cyber Security - Class 1"
                    },
                    {
                        "roll_number": "23CY999",
                        "full_name": "Student Name B",
                        "class_name": "II Year CSE Cyber Security - Class 1"
                    }
                ], f)

            report_p = os.path.join(tmpdir, "report.md")
            importer = ControlledProductionImporter(
                base_dir=tmpdir,
                report_path=report_p,
                dry_run=False,
                db_session=self.db
            )

            exit_code = importer.run()
            self.assertNotEqual(exit_code, 0)
            self.assertEqual(importer.status, "BLOCKED_GATED")

    def test_8_invalid_timetable_is_rejected(self):
        """Test that an invalid timetable with out-of-range period or day is rejected."""
        with tempfile.TemporaryDirectory() as tmpdir:
            create_valid_test_bundle(tmpdir)
            # Introduce invalid period number 99
            with open(os.path.join(tmpdir, "timetable_class1.json"), "w", encoding="utf-8") as f:
                json.dump([
                    {
                        "class_name": "II Year CSE Cyber Security - Class 1",
                        "day_of_week": "Monday",
                        "period_number": 99,
                        "subject_code": "FDS"
                    }
                ], f)

            report_p = os.path.join(tmpdir, "report.md")
            importer = ControlledProductionImporter(
                base_dir=tmpdir,
                report_path=report_p,
                dry_run=False,
                db_session=self.db
            )

            exit_code = importer.run()
            self.assertNotEqual(exit_code, 0)
            self.assertEqual(importer.status, "BLOCKED_GATED")


if __name__ == "__main__":
    unittest.main()
