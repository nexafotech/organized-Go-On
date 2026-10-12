"""
scripts/cleanup_legacy_demo_assignments.py
Safely archives / cleans up verified legacy demo assignments (IDs 1-9) for CSE-3A and CSE-3B.
Preserves:
- All 30 official college assignments (Class 1 & Class 2)
- All official college timetable slots (84 slots)
- All students (119 students)
- All academic subjects (36 subjects)
- Zero exposure of passwords or biometric data.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal
from app.models.academic import FacultyAssignment, TimetableEntry, ClassSection, Subject
from app.models.attendance import ClassSession, AttendanceRecord
from app.models.student import Student
from app.models.user import Faculty

def cleanup():
    db = SessionLocal()
    try:
        print("=" * 60)
        print("AUDITING AND CLEANING UP VERIFIED LEGACY DEMO ASSIGNMENTS")
        print("=" * 60)

        # 1. Identify legacy classes
        legacy_classes = db.query(ClassSection).filter(
            ClassSection.name.in_(["CSE-3A", "CSE-3B", "TEST-CLASS-101"])
        ).all()
        legacy_class_ids = [c.id for c in legacy_classes]
        print(f"Legacy class IDs identified: {legacy_class_ids}")

        # 2. Identify assignments belonging to legacy classes
        legacy_assignments = db.query(FacultyAssignment).filter(
            FacultyAssignment.class_id.in_(legacy_class_ids)
        ).all()
        legacy_fa_ids = [a.id for a in legacy_assignments]
        print(f"Legacy assignment IDs identified ({len(legacy_fa_ids)}): {legacy_fa_ids}")

        # 3. Referential integrity checks before any deletion
        for a in legacy_assignments:
            # Check students in this class
            student_count = db.query(Student).filter(Student.class_id == a.class_id).count()
            assert student_count == 0, f"Safety abort: Class ID {a.class_id} has {student_count} enrolled students!"

            # Check dependent sessions
            sess_count = db.query(ClassSession).join(TimetableEntry).filter(
                TimetableEntry.assignment_id == a.id
            ).count()
            assert sess_count == 0, f"Safety abort: Assignment ID {a.id} has {sess_count} dependent class sessions!"

            # Check dependent attendance
            att_count = db.query(AttendanceRecord).join(ClassSession).join(TimetableEntry).filter(
                TimetableEntry.assignment_id == a.id
            ).count()
            assert att_count == 0, f"Safety abort: Assignment ID {a.id} has {att_count} dependent attendance records!"

        print("Referential integrity verified: 0 students, 0 sessions, 0 attendance records depend on these rows.")

        # 4. Safely remove timetable entries for these legacy assignments
        tt_deleted = db.query(TimetableEntry).filter(
            TimetableEntry.assignment_id.in_(legacy_fa_ids)
        ).delete(synchronize_session=False)
        print(f"Removed {tt_deleted} legacy timetable entries.")

        # 5. Remove the legacy assignments
        fa_deleted = db.query(FacultyAssignment).filter(
            FacultyAssignment.id.in_(legacy_fa_ids)
        ).delete(synchronize_session=False)
        print(f"Removed {fa_deleted} legacy faculty assignments.")

        db.commit()

        # 6. Verify remaining valid academic assignments
        remaining_assignments = db.query(FacultyAssignment).all()
        print(f"\nRemaining official assignments count: {len(remaining_assignments)}")
        for a in remaining_assignments:
            print(f"  ID {a.id:2d} | Class: {a.class_section.name} | Subj: {a.subject.code:8s} | Faculty: {a.display_faculty_name}")

        assert len(remaining_assignments) == 30, f"Expected 30 remaining official assignments, found {len(remaining_assignments)}"

        # Verify timetable entries count for Class 1 and Class 2
        remaining_tt = db.query(TimetableEntry).count()
        print(f"Remaining official timetable slots: {remaining_tt} (expected 84)")
        assert remaining_tt == 84, f"Expected 84 remaining timetable slots, found {remaining_tt}"

        print("\nCleanup completed successfully and verified!")

    except Exception as e:
        db.rollback()
        print(f"Cleanup failed with error: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    cleanup()
