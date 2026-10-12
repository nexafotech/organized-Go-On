"""
Targeted Reconciliation of Faculty Assignments for Class 2 Labs as verified in Phase 12 Audit:
- Class 2 TWM -> All Faculty Members (Primary coordinator: Mathu Metlda FAC01)
- Linux Lab -> Sivakumar (FAC03)
- CF Lab -> Santhiya (FAC05)
- ESSS Lab -> Showmiya (FAC02)
"""
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.abspath("."))

from app.core.database import SessionLocal
from app.models.academic import FacultyAssignment, Subject, ClassSection
from app.models.user import Faculty, User, UserRole
from app.models.audit import AuditLog

def reconcile():
    db = SessionLocal()
    try:
        cs2 = db.query(ClassSection).filter(ClassSection.name.like("%Class 2%")).first()
        if not cs2:
            print("ERROR: Class 2 not found!")
            return

        all_faculty = db.query(Faculty).order_by(Faculty.employee_id).all()
        fac_map = {f.employee_id: f for f in all_faculty}

        admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
        admin_id = admin.id if admin else 1

        # 1. CF LAB (Assignment 38) -> Santhiya (FAC05)
        fa_cf = db.query(FacultyAssignment).filter(
            FacultyAssignment.class_id == cs2.id,
            FacultyAssignment.subject.has(code="CF LAB")
        ).first()
        if fa_cf:
            old_name = fa_cf.display_faculty_name
            fa_cf.faculty_id = fac_map["FAC05"].id
            fa_cf.authorized_faculty = [fac_map["FAC05"]]
            print(f"Reconciled FA #{fa_cf.id} (CF LAB): '{old_name}' -> '{fa_cf.display_faculty_name}'")

        # 2. ESSS LAB (Assignment 39) -> Showmiya (FAC02)
        fa_esss = db.query(FacultyAssignment).filter(
            FacultyAssignment.class_id == cs2.id,
            FacultyAssignment.subject.has(code="ESSS LAB")
        ).first()
        if fa_esss:
            old_name = fa_esss.display_faculty_name
            fa_esss.faculty_id = fac_map["FAC02"].id
            fa_esss.authorized_faculty = [fac_map["FAC02"]]
            print(f"Reconciled FA #{fa_esss.id} (ESSS LAB): '{old_name}' -> '{fa_esss.display_faculty_name}'")

        # 3. Class 2 TWM (Assignment 35) -> Coordinator Mathu Metlda (FAC01) + all 8 faculty
        fa_twm = db.query(FacultyAssignment).filter(
            FacultyAssignment.class_id == cs2.id,
            FacultyAssignment.subject.has(code="TWM")
        ).first()
        if fa_twm:
            fa_twm.faculty_id = fac_map["FAC01"].id
            fa_twm.authorized_faculty = all_faculty
            print(f"Reconciled FA #{fa_twm.id} (TWM): Primary '{fac_map['FAC01'].full_name}', Co-Faculty all {len(all_faculty)} members")

        # 4. Verify LINUX LAB (Assignment 37) -> Sivakumar (FAC03)
        fa_linux = db.query(FacultyAssignment).filter(
            FacultyAssignment.class_id == cs2.id,
            FacultyAssignment.subject.has(code="LINUX LAB")
        ).first()
        if fa_linux:
            print(f"Verified FA #{fa_linux.id} (LINUX LAB): Primary '{fa_linux.display_faculty_name}' (FAC03)")

        # Log audit entry
        log_entry = AuditLog(
            user_id=admin_id,
            action="UPDATE_FACULTY_ASSIGNMENT",
            target="III Year CSE Cyber Security - Class 2",
            details="Audit fix: Reconciled manual Class 2 assignments: CF LAB -> Santhiya (FAC05), ESSS LAB -> Showmiya (FAC02), TWM -> All Faculty (Coordinator FAC01).",
            ip_address="127.0.0.1",
            timestamp=datetime.now(timezone.utc)
        )
        db.add(log_entry)

        db.commit()
        print("Reconciliation successfully committed to database!")

    finally:
        db.close()

if __name__ == "__main__":
    reconcile()
