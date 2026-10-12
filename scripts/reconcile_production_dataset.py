"""
scripts/reconcile_production_dataset.py
Performs complete, safe, and audited production dataset reconciliation:
1. Removes confirmed test classes (CSE-3A, CSE-3B, TEST-CLASS-101)
2. Removes confirmed test faculty (EMP-101 Dr. Alan Turing, EMP-102 Dr. Grace Hopper) & linked users
3. Removes confirmed test subjects (PTS, TT, CET-II, EC, PPP, BEEE, EG-LAB, PE-LAB, SUB-999)
4. Removes confirmed test periods (Period 88, Period 99)
5. Reconciles Class 2 manual assignments:
   - TWM -> Primary FAC01, authorized co-faculty FAC01..FAC08
   - LINUX LAB -> FAC03 (Sivakumar)
   - CF LAB -> FAC05 (Santhiya)
   - ESSS LAB -> FAC02 (Showmiya)
6. Records reconciliation in AuditLog
7. Asserts final entity counts match authoritative college specifications.
"""

import sys
import os
import sqlite3
import datetime

# Ensure project root is in sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal
from app.models.user import User, Faculty, UserRole
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.student import Student
from app.models.attendance import ClassSession, AttendanceRecord, FaceEmbedding
from app.models.audit import AuditLog

def reconcile():
    print("=" * 60)
    print("STARTING AUTHORITATIVE PRODUCTION RECONCILIATION")
    print("=" * 60)

    db = SessionLocal()

    try:
        admin_user = db.query(User).filter(User.role == UserRole.ADMIN).first()
        admin_id = admin_user.id if admin_user else 1

        # -------------------------------------------------------------
        # 1. PURGE CONFIRMED TEST CLASSES (CSE-3A, CSE-3B, TEST-CLASS-101)
        # -------------------------------------------------------------
        test_class_names = ["CSE-3A", "CSE-3B", "TEST-CLASS-101"]
        test_classes = db.query(ClassSection).filter(ClassSection.name.in_(test_class_names)).all()
        print(f"\n[1/5] Checking Test Classes ({len(test_classes)} found):")
        for tc in test_classes:
            st_cnt = db.query(Student).filter(Student.class_id == tc.id).count()
            fa_cnt = db.query(FacultyAssignment).filter(FacultyAssignment.class_id == tc.id).count()
            if st_cnt == 0 and fa_cnt == 0:
                print(f"  Deleting unreferenced test class: '{tc.name}' (ID {tc.id})")
                db.delete(tc)
            else:
                print(f"  WARNING: Cannot delete class '{tc.name}' (has {st_cnt} students, {fa_cnt} assignments)")
        db.flush()

        # -------------------------------------------------------------
        # 2. PURGE CONFIRMED TEST FACULTY (EMP-101, EMP-102) & USERS
        # -------------------------------------------------------------
        test_emp_ids = ["EMP-101", "EMP-102"]
        test_faculty = db.query(Faculty).filter(Faculty.employee_id.in_(test_emp_ids)).all()
        print(f"\n[2/5] Checking Test Faculty ({len(test_faculty)} found):")
        for tf in test_faculty:
            fa_cnt = db.query(FacultyAssignment).filter(FacultyAssignment.faculty_id == tf.id).count()
            sess_cnt = db.query(ClassSession).filter(ClassSession.faculty_id == tf.id).count()
            if fa_cnt == 0 and sess_cnt == 0:
                uid = tf.user_id
                print(f"  Deleting test faculty: [{tf.employee_id}] '{tf.full_name}' (ID {tf.id}) and user ID {uid}")
                db.delete(tf)
                db.flush()
                if uid:
                    user = db.query(User).filter(User.id == uid).first()
                    if user:
                        db.delete(user)
                        db.flush()
            else:
                print(f"  WARNING: Cannot delete faculty '{tf.full_name}' (has {fa_cnt} assignments, {sess_cnt} sessions)")
        db.flush()

        # -------------------------------------------------------------
        # 3. PURGE CONFIRMED TEST SUBJECTS (PTS, TT, CET-II, EC, PPP, BEEE, EG-LAB, PE-LAB, SUB-999)
        # -------------------------------------------------------------
        test_subject_codes = ["PTS", "TT", "CET-II", "EC", "PPP", "BEEE", "EG-LAB", "PE-LAB", "SUB-999"]
        test_subjects = db.query(Subject).filter(Subject.code.in_(test_subject_codes)).all()
        print(f"\n[3/5] Checking Test Subjects ({len(test_subjects)} found):")
        for ts in test_subjects:
            fa_cnt = db.query(FacultyAssignment).filter(FacultyAssignment.subject_id == ts.id).count()
            sess_cnt = db.query(ClassSession).join(TimetableEntry).join(FacultyAssignment).filter(FacultyAssignment.subject_id == ts.id).count()
            if fa_cnt == 0 and sess_cnt == 0:
                print(f"  Deleting unreferenced test subject: [{ts.code}] '{ts.name}' (ID {ts.id})")
                db.delete(ts)
            else:
                print(f"  WARNING: Cannot delete subject '{ts.code}' (has {fa_cnt} assignments, {sess_cnt} sessions)")
        db.flush()

        # -------------------------------------------------------------
        # 4. PURGE CONFIRMED TEST PERIODS (Period 88, Period 99)
        # -------------------------------------------------------------
        test_period_numbers = [88, 99]
        test_periods = db.query(Period).filter(Period.period_number.in_(test_period_numbers)).all()
        print(f"\n[4/5] Checking Test Periods ({len(test_periods)} found):")
        for tp in test_periods:
            tt_cnt = db.query(TimetableEntry).filter(TimetableEntry.period_id == tp.id).count()
            sess_cnt = db.query(ClassSession).join(TimetableEntry).filter(TimetableEntry.period_id == tp.id).count()
            if tt_cnt == 0 and sess_cnt == 0:
                print(f"  Deleting unreferenced test period: P{tp.period_number} '{tp.name}' (ID {tp.id})")
                db.delete(tp)
            else:
                print(f"  WARNING: Cannot delete period P{tp.period_number} (has {tt_cnt} timetable refs, {sess_cnt} sessions)")
        db.flush()

        # -------------------------------------------------------------
        # 5. RECONCILE CLASS 2 MANUAL ASSIGNMENTS
        # -------------------------------------------------------------
        print("\n[5/5] Reconciling Class 2 Manual Assignments:")
        cs2 = db.query(ClassSection).filter(ClassSection.name == "III Year CSE Cyber Security - Class 2").first()
        if not cs2:
            raise RuntimeError("Class 2 section not found in database!")

        all_official_faculty = db.query(Faculty).order_by(Faculty.employee_id.asc()).all()
        fac_map = {f.employee_id: f for f in all_official_faculty}

        # Sub 1: TWM -> All Faculty Members
        twm_sub = db.query(Subject).filter(Subject.code == "TWM").first()
        if twm_sub:
            fa_twm = db.query(FacultyAssignment).filter(
                FacultyAssignment.class_id == cs2.id,
                FacultyAssignment.subject_id == twm_sub.id
            ).first()
            if fa_twm:
                fa_twm.faculty_id = fac_map["FAC01"].id  # Primary coordinator
                fa_twm.authorized_faculty = all_official_faculty  # All 8 faculty
                print(f"  Class 2 TWM -> Assigned primary {fac_map['FAC01'].full_name}, co-faculty all 8 members")

        # Sub 2: LINUX LAB -> Sivakumar (FAC03)
        linux_lab_sub = db.query(Subject).filter(Subject.code == "LINUX LAB").first()
        if linux_lab_sub:
            fa_linux = db.query(FacultyAssignment).filter(
                FacultyAssignment.class_id == cs2.id,
                FacultyAssignment.subject_id == linux_lab_sub.id
            ).first()
            if fa_linux:
                fa_linux.faculty_id = fac_map["FAC03"].id
                print(f"  Class 2 LINUX LAB -> Assigned {fac_map['FAC03'].full_name} ({fac_map['FAC03'].employee_id})")

        # Sub 3: CF LAB -> Santhiya (FAC05)
        cf_lab_sub = db.query(Subject).filter(Subject.code == "CF LAB").first()
        if cf_lab_sub:
            fa_cf = db.query(FacultyAssignment).filter(
                FacultyAssignment.class_id == cs2.id,
                FacultyAssignment.subject_id == cf_lab_sub.id
            ).first()
            if fa_cf:
                fa_cf.faculty_id = fac_map["FAC05"].id
                print(f"  Class 2 CF LAB -> Assigned {fac_map['FAC05'].full_name} ({fac_map['FAC05'].employee_id})")

        # Sub 4: ESSS LAB -> Showmiya (FAC02)
        esss_lab_sub = db.query(Subject).filter(Subject.code == "ESSS LAB").first()
        if esss_lab_sub:
            fa_esss = db.query(FacultyAssignment).filter(
                FacultyAssignment.class_id == cs2.id,
                FacultyAssignment.subject_id == esss_lab_sub.id
            ).first()
            if fa_esss:
                fa_esss.faculty_id = fac_map["FAC02"].id
                print(f"  Class 2 ESSS LAB -> Assigned {fac_map['FAC02'].full_name} ({fac_map['FAC02'].employee_id})")

        # -------------------------------------------------------------
        # 6. LOG AUDIT EVENT & COMMIT
        # -------------------------------------------------------------
        audit_entry = AuditLog(
            user_id=admin_id,
            action="PRODUCTION_DATA_RECONCILIATION",
            details="Purged test classes (CSE-3A, CSE-3B, TEST-CLASS-101), test faculty (EMP-101, EMP-102), test subjects (9), test periods (P88, P99). Reconciled Class 2 manual assignments.",
            ip_address="127.0.0.1",
            timestamp=datetime.datetime.now(datetime.timezone.utc)
        )
        db.add(audit_entry)
        db.commit()

        print("\n" + "=" * 60)
        print("POST-RECONCILIATION DATABASE STATE VERIFICATION")
        print("=" * 60)

        c_cnt = db.query(ClassSection).count()
        f_cnt = db.query(Faculty).count()
        s_cnt = db.query(Student).count()
        sub_cnt = db.query(Subject).count()
        p_cnt = db.query(Period).count()
        fa_cnt = db.query(FacultyAssignment).count()
        tt_cnt = db.query(TimetableEntry).count()
        u_cnt = db.query(User).count()

        print(f"Classes:            {c_cnt} (Expected: 2)")
        print(f"Faculty:            {f_cnt} (Expected: 8)")
        print(f"Students:           {s_cnt} (Expected: 119)")
        print(f"Subjects:           {sub_cnt} (Expected: 27)")
        print(f"Periods:            {p_cnt} (Expected: 7)")
        print(f"Assignments:        {fa_cnt} (Expected: 30)")
        print(f"Timetable Slots:    {tt_cnt} (Expected: 84)")
        print(f"Users:              {u_cnt} (Expected: 128)")

        assert c_cnt == 2, f"Expected 2 classes, got {c_cnt}"
        assert f_cnt == 8, f"Expected 8 faculty, got {f_cnt}"
        assert s_cnt == 119, f"Expected 119 students, got {s_cnt}"
        assert sub_cnt == 27, f"Expected 27 subjects, got {sub_cnt}"
        assert p_cnt == 7, f"Expected 7 periods, got {p_cnt}"
        assert fa_cnt == 30, f"Expected 30 assignments, got {fa_cnt}"
        assert tt_cnt == 84, f"Expected 84 timetable slots, got {tt_cnt}"
        assert u_cnt == 128, f"Expected 128 users, got {u_cnt}"

        print("\nALL RECONCILIATION ASSERTIONS PASSED WITH 100% SUCCESS!")

    except Exception as e:
        db.rollback()
        print(f"\n[ERROR] Reconciliation failed: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    reconcile()
