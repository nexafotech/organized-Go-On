"""
scripts/update_class1_faculty_assignments.py
Safely applies Milestone 10C.15.4 updates:
- Creates assignment_authorized_faculty table if not present
- Ensures 3 new development faculty (FAC06 Lakshmi Narayanan, FAC07 Princy, FAC08 Gowri Manohari)
- Updates DMC subject full name to "Discrete Mathematics for Computing"
- Updates TWM subject full name to "Tutor Ward Meeting"
- Updates Class 1 assignments:
  - DPCO -> LAKSHMI NARAYANAN
  - DMC -> PRINCY
  - ACE-I -> GOWRI MANOHARI (authorized: GOWRI MANOHARI, SHANKAR)
  - TWM -> MATHU (authorized: MATHU, SHOWMIYA, SHANKAR, SIVAKUMAR, SANTHIYA)
  - ASSOC -> SANTHIYA (authorized: SANTHIYA)
- Preserves 64 Class 1 students, 0 Class 2 students, 42 Class 1 timetable slots, 42 Class 2 timetable slots (84 total).
"""

import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.core.database import SessionLocal, engine, Base
from app.core.security import get_password_hash
from app.models.user import User, Faculty, UserRole
from app.models.academic import ClassSection, Subject, FacultyAssignment, TimetableEntry, assignment_authorized_faculty
from app.models.student import Student

def run_update():
    # 1. Ensure table created
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        print("=== Step 1: Checking Initial Database State ===")
        cs1 = db.query(ClassSection).filter(ClassSection.name == "II Year CSE Cyber Security - Class 1").first()
        cs2 = db.query(ClassSection).filter(ClassSection.name == "III Year CSE Cyber Security - Class 2").first()
        assert cs1 is not None, "Class 1 not found"
        assert cs2 is not None, "Class 2 not found"

        initial_students = db.query(Student).count()
        initial_faculty = db.query(Faculty).count()
        initial_tt_cs1 = (
            db.query(TimetableEntry)
            .join(FacultyAssignment)
            .filter(FacultyAssignment.class_id == cs1.id)
            .count()
        )
        initial_tt_cs2 = (
            db.query(TimetableEntry)
            .join(FacultyAssignment)
            .filter(FacultyAssignment.class_id == cs2.id)
            .count()
        )
        print(f"Students total: {initial_students}")
        print(f"Faculty total: {initial_faculty}")
        print(f"Class 1 timetable entries: {initial_tt_cs1}")
        print(f"Class 2 timetable entries: {initial_tt_cs2}")

        # 2. Ensure 3 new development faculty
        print("\n=== Step 2: Ensuring New Development Faculty ===")
        new_fac_specs = [
            ("FAC06", "Lakshmi Narayanan", "fac06", "fac06@college.edu"),
            ("FAC07", "Princy", "fac07", "fac07@college.edu"),
            ("FAC08", "Gowri Manohari", "fac08", "fac08@college.edu"),
        ]
        faculty_map = {}
        # Fetch all existing faculty
        for fac in db.query(Faculty).all():
            faculty_map[fac.employee_id] = fac

        for emp_id, full_name, username, email in new_fac_specs:
            if emp_id not in faculty_map:
                existing_user = db.query(User).filter(User.username == username).first()
                if not existing_user:
                    user = User(
                        username=username,
                        email=email,
                        hashed_password=get_password_hash("faculty123"),
                        role=UserRole.FACULTY,
                        is_active=True,
                        login_identifier=emp_id
                    )
                    db.add(user)
                    db.flush()
                else:
                    user = existing_user

                fac = db.query(Faculty).filter(Faculty.user_id == user.id).first()
                if not fac:
                    fac = Faculty(
                        user_id=user.id,
                        employee_id=emp_id,
                        full_name=full_name,
                        department="CSE Cyber Security"
                    )
                    db.add(fac)
                    db.flush()
                faculty_map[emp_id] = fac
                print(f"Created/Linked Faculty: {emp_id} - {full_name}")
            else:
                print(f"Existing Faculty: {emp_id} - {faculty_map[emp_id].full_name}")

        # 3. Update Subject names
        print("\n=== Step 3: Updating Subject Full Names ===")
        sub_dmc = db.query(Subject).filter(Subject.code == "DMC").first()
        if sub_dmc:
            sub_dmc.name = "Discrete Mathematics for Computing"
            print("Updated DMC name to 'Discrete Mathematics for Computing'")

        sub_twm = db.query(Subject).filter(Subject.code == "TWM").first()
        if sub_twm:
            sub_twm.name = "Tutor Ward Meeting"
            print("Updated TWM name to 'Tutor Ward Meeting'")

        db.flush()

        # 4. Update Class 1 Faculty Assignments
        print("\n=== Step 4: Updating Class 1 Faculty Assignments ===")
        # Fetch key faculty objects
        fac01 = faculty_map["FAC01"]  # Mathu
        fac02 = faculty_map["FAC02"]  # Showmiya
        fac03 = faculty_map["FAC03"]  # Sivakumar
        fac04 = faculty_map["FAC04"]  # Shankar
        fac05 = faculty_map["FAC05"]  # Santhiya
        fac06 = faculty_map["FAC06"]  # Lakshmi Narayanan
        fac07 = faculty_map["FAC07"]  # Princy
        fac08 = faculty_map["FAC08"]  # Gowri Manohari

        def update_assignment_record(code: str, primary_fac: Faculty, auth_facs: list):
            sub = db.query(Subject).filter(Subject.code == code).first()
            assert sub is not None, f"Subject {code} not found"
            fa = db.query(FacultyAssignment).filter(
                FacultyAssignment.class_id == cs1.id,
                FacultyAssignment.subject_id == sub.id
            ).first()
            if not fa:
                fa = FacultyAssignment(
                    class_id=cs1.id,
                    subject_id=sub.id,
                    faculty_id=primary_fac.id if primary_fac else None
                )
                db.add(fa)
                db.flush()
            else:
                fa.faculty_id = primary_fac.id if primary_fac else None

            fa.authorized_faculty = auth_facs
            db.flush()
            print(f"Assignment [{code}] -> Primary: {primary_fac.full_name if primary_fac else 'None'} | Authorized: {[f.full_name for f in auth_facs]}")

        # A. DPCO -> LAKSHMI NARAYANAN
        update_assignment_record("DPCO", fac06, [fac06])

        # B. DMC -> PRINCY
        update_assignment_record("DMC", fac07, [fac07])

        # C. ACE-I -> GOWRI MANOHARI & SHANKAR
        update_assignment_record("ACE-I", fac08, [fac08, fac04])

        # D. TWM -> MATHU, SHOWMIYA, SHANKAR, SIVAKUMAR, SANTHIYA
        update_assignment_record("TWM", fac01, [fac01, fac02, fac04, fac03, fac05])

        # E. ASSOC -> SANTHIYA
        update_assignment_record("ASSOC", fac05, [fac05])

        db.commit()
        print("\n=== Step 5: Validating Post-Update State ===")
        final_students = db.query(Student).count()
        final_faculty = db.query(Faculty).count()
        final_tt_cs1 = (
            db.query(TimetableEntry)
            .join(FacultyAssignment)
            .filter(FacultyAssignment.class_id == cs1.id)
            .count()
        )
        final_tt_cs2 = (
            db.query(TimetableEntry)
            .join(FacultyAssignment)
            .filter(FacultyAssignment.class_id == cs2.id)
            .count()
        )
        print(f"Final Students: {final_students} (Expected: 64)")
        print(f"Final Faculty: {final_faculty} (Expected: 8)")
        print(f"Final Class 1 Timetable: {final_tt_cs1} (Expected: 42)")
        print(f"Final Class 2 Timetable: {final_tt_cs2} (Expected: 42)")
        print(f"Total Timetable: {final_tt_cs1 + final_tt_cs2} (Expected: 84)")

        assert final_students == 64, f"Student count changed! {final_students}"
        assert final_faculty == 8, f"Faculty count incorrect! {final_faculty}"
        assert final_tt_cs1 == 42, f"Class 1 timetable changed! {final_tt_cs1}"
        assert final_tt_cs2 == 42, f"Class 2 timetable changed! {final_tt_cs2}"

        print("\nSUCCESS: All Milestone 10C.15.4 database updates applied cleanly!")

    except Exception as e:
        db.rollback()
        print(f"ERROR: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    run_update()
