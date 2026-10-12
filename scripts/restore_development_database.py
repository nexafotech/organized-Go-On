"""
Restore development database state for Attendance Marker.
Restores:
- Class Sections (Class 1 and Class 2)
- Subjects & Periods
- Faculty (FAC01-FAC08) & Faculty Assignments & Timetable
- Class 1 Students (64) with matching passwords from CLASS1_STUDENT_CREDENTIALS.docx
- Class 2 Students (55) with matching passwords from CLASS2_STUDENT_CREDENTIALS.docx
- Admin account
- Zero face embeddings, zero attendance records, zero class sessions.
"""

import os
import sys
import zipfile
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal, Base, engine
from app.core.security import get_password_hash
from app.models.user import User, UserRole
from app.models.student import Student
from app.models.academic import ClassSection
from app.models.attendance import AttendanceRecord, ClassSession, FaceEmbedding
from app.services.college_importer import seed_temporary_dev_timetable

DOCX_CLASS1 = r"C:\Users\Abishek\Documents\Attendance_Marker\CLASS1_STUDENT_CREDENTIALS.docx"
DOCX_CLASS2 = r"C:\Users\Abishek\Documents\Attendance_Marker\CLASS2_STUDENT_CREDENTIALS.docx"

def parse_docx(path):
    with zipfile.ZipFile(path, 'r') as z:
        root = ET.fromstring(z.read('word/document.xml'))
    rows = root.findall('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}tr')
    students = []
    for r in rows[1:]:
        cells = r.findall('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}tc')
        cell_texts = [''.join(c.itertext()).strip() for c in cells]
        roll = cell_texts[1]
        name = cell_texts[2]
        temp_pwd = cell_texts[6]
        force_change = cell_texts[7].lower() == 'true'
        students.append({
            'roll': roll,
            'name': name,
            'temp_pwd': temp_pwd,
            'force_change': force_change
        })
    return students

def restore():
    print("=" * 60)
    print("RESTORING DEVELOPMENT DATABASE STATE")
    print("=" * 60)

    db = SessionLocal()

    from app.models.academic import TimetableEntry, FacultyAssignment, Period, Subject, ClassSection
    from app.models.user import Faculty
    from sqlalchemy import text

    # Clear face embeddings, attendance, sessions, students, users (keep academic configuration intact)
    db.query(AttendanceRecord).delete()
    db.query(ClassSession).delete()
    db.query(FaceEmbedding).delete()
    db.query(Student).delete()
    db.query(User).filter(User.role == UserRole.STUDENT).delete()
    db.commit()

    # Re-seed dev timetable if needed
    res = seed_temporary_dev_timetable(db, class_name="all", force_reset=False)
    print("Academic Configuration check:", res)

    # Ensure AttendancePolicy exists and has valid calculation_mode
    from app.engines.policy_engine import get_active_policy
    pol = get_active_policy(db)
    if pol.calculation_mode not in ("RECORD_BASED", "IMPACT_BASED"):
        pol.calculation_mode = "RECORD_BASED"
        db.commit()
    print("Attendance Policy check:", pol.calculation_mode)

    # Ensure Period 6 timing is authoritative (14:30 - 15:20)
    p6 = db.query(Period).filter(Period.period_number == 6).first()
    if p6 and (p6.start_time != "14:30" or p6.end_time != "15:20"):
        p6.start_time = "14:30"
        p6.end_time = "15:20"
        db.commit()
    print("Period 6 timing check:", f"{p6.start_time} - {p6.end_time}" if p6 else "missing")

    # Clean up any legacy demo assignments, classes, test faculty, test subjects, and test periods
    legacy_cs = db.query(ClassSection).filter(ClassSection.name.in_(["CSE-3A", "CSE-3B", "TEST-CLASS-101"])).all()
    if legacy_cs:
        legacy_cs_ids = [c.id for c in legacy_cs]
        legacy_fa = db.query(FacultyAssignment).filter(FacultyAssignment.class_id.in_(legacy_cs_ids)).all()
        if legacy_fa:
            legacy_fa_ids = [a.id for a in legacy_fa]
            db.query(TimetableEntry).filter(TimetableEntry.assignment_id.in_(legacy_fa_ids)).delete(synchronize_session=False)
            db.query(FacultyAssignment).filter(FacultyAssignment.id.in_(legacy_fa_ids)).delete(synchronize_session=False)
        for lc in legacy_cs:
            db.delete(lc)
        db.commit()

    # Clean up test faculty & users (EMP-101, EMP-102)
    test_faculty = db.query(Faculty).filter(Faculty.employee_id.in_(["EMP-101", "EMP-102"])).all()
    for tf in test_faculty:
        uid = tf.user_id
        db.delete(tf)
        if uid:
            u = db.query(User).filter(User.id == uid).first()
            if u:
                db.delete(u)
    db.commit()

    # Clean up test subjects
    test_subs = db.query(Subject).filter(Subject.code.in_(["PTS", "TT", "CET-II", "EC", "PPP", "BEEE", "EG-LAB", "PE-LAB", "SUB-999"])).all()
    for ts in test_subs:
        db.delete(ts)
    db.commit()

    # Clean up test periods
    test_periods = db.query(Period).filter(Period.period_number.in_([88, 99])).all()
    for tp in test_periods:
        db.delete(tp)
    db.commit()

    # Fetch Class Sections
    cs1 = db.query(ClassSection).filter(ClassSection.name == "II Year CSE Cyber Security - Class 1").first()
    cs2 = db.query(ClassSection).filter(ClassSection.name == "III Year CSE Cyber Security - Class 2").first()
    assert cs1 is not None and cs2 is not None, "Class sections missing"

    # Insert Class 1 students
    c1_students = parse_docx(DOCX_CLASS1)
    print(f"Loading {len(c1_students)} Class 1 students from DOCX...")
    for s in c1_students:
        user = User(
            username=s['roll'],
            email=f"{s['roll'].lower()}@dev.college.local",
            hashed_password=get_password_hash(s['temp_pwd']),
            role=UserRole.STUDENT,
            is_active=True,
            force_password_change=s['force_change'],
            login_identifier=s['roll']
        )
        db.add(user)
        db.flush()

        student = Student(
            user_id=user.id,
            roll_number=s['roll'],
            full_name=s['name'],
            class_id=cs1.id,
            department="CSE Cyber Security",
            semester="3",
            is_active=True
        )
        db.add(student)
        db.flush()

    # Insert Class 2 students
    c2_students = parse_docx(DOCX_CLASS2)
    print(f"Loading {len(c2_students)} Class 2 students from DOCX...")
    for s in c2_students:
        user = User(
            username=s['roll'],
            email=f"{s['roll'].lower()}@dev.college.local",
            hashed_password=get_password_hash(s['temp_pwd']),
            role=UserRole.STUDENT,
            is_active=True,
            force_password_change=s['force_change'],
            login_identifier=s['roll']
        )
        db.add(user)
        db.flush()

        student = Student(
            user_id=user.id,
            roll_number=s['roll'],
            full_name=s['name'],
            class_id=cs2.id,
            department="CSE Cyber Security",
            semester="5",
            is_active=True
        )
        db.add(student)
        db.flush()

    db.commit()

    # Verify counts
    st_count = db.query(Student).count()
    usr_count = db.query(User).count()
    c1_count = db.query(Student).filter(Student.class_id == cs1.id).count()
    c2_count = db.query(Student).filter(Student.class_id == cs2.id).count()
    emb_count = db.query(FaceEmbedding).count()
    att_count = db.query(AttendanceRecord).count()
    cs_count = db.query(ClassSession).count()

    print(f"Restoration Complete:")
    print(f"  Total Students: {st_count} (Class 1: {c1_count}, Class 2: {c2_count})")
    print(f"  Total Users: {usr_count}")
    print(f"  Face Embeddings: {emb_count}")
    print(f"  Attendance Records: {att_count}")
    print(f"  Class Sessions: {cs_count}")

    assert st_count == 119
    assert c1_count == 64
    assert c2_count == 55
    assert emb_count == 0
    assert att_count == 0
    assert cs_count == 0

    db.close()
    print("Database successfully restored and verified!")

if __name__ == "__main__":
    restore()
