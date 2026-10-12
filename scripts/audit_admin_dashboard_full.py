"""
Comprehensive Read-Only Audit Script for Admin Dashboard Data & Logic.
Executes Phase 1 through Phase 16 with zero side effects.
"""
import os
import sys
import json
from datetime import datetime, timezone
import zoneinfo

# Set current working directory
sys.path.insert(0, os.path.abspath("."))

from sqlalchemy import func, text
from app.core.config import settings
from app.core.database import SessionLocal, engine
from app.models.academic import ClassSection, Subject, Period, TimetableEntry, FacultyAssignment
from app.models.user import User, Faculty, UserRole
from app.models.student import Student
from app.models.attendance import ClassSession, AttendanceRecord, AttendanceStatus, SessionStatus, FaceEmbedding
from app.models.audit import AuditLog
from app.engines.policy_engine import get_active_policy

def run_audit():
    db = SessionLocal()
    report = {}

    print("=" * 70)
    print("PHASE 1: DATABASE IDENTIFICATION & ENVIRONMENT")
    print("=" * 70)
    db_file = os.path.abspath(engine.url.database) if engine.url.database else "N/A"
    print(f"DATABASE_URL: {settings.DATABASE_URL}")
    print(f"Engine URL: {engine.url}")
    print(f"Absolute DB file path: {db_file}")
    print(f"Database file exists: {os.path.exists(db_file)}")
    if os.path.exists(db_file):
        print(f"Database file size: {os.path.getsize(db_file)} bytes")
        print(f"Database file last modified: {datetime.fromtimestamp(os.path.getmtime(db_file))}")

    # Check for other .db files
    db_candidates = []
    for root, dirs, files in os.walk("."):
        if ".venv" in root or ".git" in root or ".dart_tool" in root:
            continue
        for f in files:
            if f.endswith(".db"):
                p = os.path.join(root, f)
                db_candidates.append((p, os.path.getsize(p)))
    print("Database files in project tree:")
    for p, sz in db_candidates:
        print(f"  - {p} ({sz} bytes)")

    print("\n" + "=" * 70)
    print("PHASE 2: MASTER COUNTS")
    print("=" * 70)
    total_students = db.query(Student).count()
    total_faculty = db.query(Faculty).count()
    total_classes = db.query(ClassSection).count()
    total_subjects = db.query(Subject).count()
    total_timetable_slots = db.query(TimetableEntry).count()

    print(f"Students: Admin=119 | DB={total_students} | Match={total_students == 119}")
    print(f"Faculty: Admin=8 | DB={total_faculty} | Match={total_faculty == 8}")
    print(f"Classes: Admin=2 | DB={total_classes} | Match={total_classes == 2}")
    print(f"Subjects: Admin=27 | DB={total_subjects} | Match={total_subjects == 27}")
    print(f"Timetable Slots: Admin=84 | DB={total_timetable_slots} | Match={total_timetable_slots == 84}")

    print("\n" + "=" * 70)
    print("PHASE 3: SESSIONS & ATTENDANCE (TODAY VS ALL)")
    print("=" * 70)
    # Check timezones
    utc_now = datetime.now(timezone.utc)
    ist_tz = zoneinfo.ZoneInfo("Asia/Kolkata")
    ist_now = datetime.now(ist_tz)
    utc_today = utc_now.strftime("%Y-%m-%d")
    ist_today = ist_now.strftime("%Y-%m-%d")
    print(f"Current UTC timestamp: {utc_now.isoformat()} -> Date: {utc_today}")
    print(f"Current IST timestamp: {ist_now.isoformat()} -> Date: {ist_today}")

    # Inspect ClassSession records
    all_sessions = db.query(ClassSession).all()
    print(f"Total ClassSession records in DB: {len(all_sessions)}")
    session_dates = {}
    for s in all_sessions:
        session_dates[s.date] = session_dates.get(s.date, 0) + 1
    print("ClassSession records by date:")
    for dt, cnt in sorted(session_dates.items()):
        print(f"  Date: {dt} -> {cnt} sessions")

    active_sessions = db.query(ClassSession).filter(ClassSession.status == SessionStatus.ACTIVE).count()
    today_sessions_utc = db.query(ClassSession).filter(ClassSession.date == utc_today).count()
    today_sessions_ist = db.query(ClassSession).filter(ClassSession.date == ist_today).count()
    print(f"Active sessions count: {active_sessions}")
    print(f"Sessions on UTC today ({utc_today}): {today_sessions_utc}")
    print(f"Sessions on IST today ({ist_today}): {today_sessions_ist}")

    # Inspect AttendanceRecord
    total_records = db.query(AttendanceRecord).count()
    today_att_utc = db.query(AttendanceRecord).join(ClassSession).filter(ClassSession.date == utc_today).count()
    today_att_ist = db.query(AttendanceRecord).join(ClassSession).filter(ClassSession.date == ist_today).count()
    print(f"Total AttendanceRecord count: {total_records}")
    print(f"Attendance records on UTC today ({utc_today}): {today_att_utc}")
    print(f"Attendance records on IST today ({ist_today}): {today_att_ist}")

    # What dates have attendance records?
    att_by_date = db.query(ClassSession.date, func.count(AttendanceRecord.id)).join(AttendanceRecord).group_by(ClassSession.date).all()
    print("Attendance records by date:")
    for dt, cnt in att_by_date:
        print(f"  Date: {dt} -> {cnt} attendance records")

    print("\n" + "=" * 70)
    print("PHASE 4: BIOMETRICS ENROLLMENT")
    print("=" * 70)
    total_embeddings = db.query(FaceEmbedding).count()
    distinct_students_with_embeddings = db.query(FaceEmbedding.student_id).distinct().count()
    # Dashboard query:
    subq = db.query(FaceEmbedding.student_id).group_by(FaceEmbedding.student_id).having(func.count(FaceEmbedding.id) >= 3).subquery()
    biometric_enrolled_dashboard = db.query(subq).count()

    print(f"Total FaceEmbedding rows: {total_embeddings}")
    print(f"Distinct students with any embedding: {distinct_students_with_embeddings}")
    print(f"Students with >= 3 embeddings (Dashboard query): {biometric_enrolled_dashboard}")

    # Breakdown of embeddings per student
    student_emb_counts = db.query(FaceEmbedding.student_id, func.count(FaceEmbedding.id)).group_by(FaceEmbedding.student_id).all()
    print("Student embedding counts distribution:")
    if student_emb_counts:
        for sid, c in student_emb_counts:
            print(f"  Student ID {sid}: {c} embeddings")
    else:
        print("  NO FaceEmbedding rows found in the database! Total = 0.")

    print("\n" + "=" * 70)
    print("PHASE 5: PRESENT / ABSENT / OD RECORDS")
    print("=" * 70)
    present_count = db.query(AttendanceRecord).filter(AttendanceRecord.status == AttendanceStatus.PRESENT).count()
    absent_count = db.query(AttendanceRecord).filter(AttendanceRecord.status == AttendanceStatus.ABSENT).count()
    od_count = db.query(AttendanceRecord).filter(AttendanceRecord.status == AttendanceStatus.OD).count()
    print(f"Present count: {present_count} (Admin dashboard displays: 22)")
    print(f"Absent count: {absent_count} (Admin dashboard displays: 21)")
    print(f"OD count: {od_count} (Admin dashboard displays: 21)")
    print(f"Sum of Present + Absent + OD = {present_count + absent_count + od_count} (Total records: {total_records})")

    # Detail of existing attendance records
    rec_details = db.query(AttendanceRecord.status, ClassSession.date, ClassSection.name, Subject.name, func.count(AttendanceRecord.id))\
        .join(ClassSession, AttendanceRecord.session_id == ClassSession.id)\
        .outerjoin(TimetableEntry, ClassSession.timetable_entry_id == TimetableEntry.id)\
        .outerjoin(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)\
        .outerjoin(ClassSection, FacultyAssignment.class_id == ClassSection.id)\
        .outerjoin(Subject, FacultyAssignment.subject_id == Subject.id)\
        .group_by(AttendanceRecord.status, ClassSession.date, ClassSection.name, Subject.name)\
        .all()
    print("Attendance records breakdown (status, date, class, subject, count):")
    for row in rec_details:
        print(f"  Status: {row[0].value if hasattr(row[0], 'value') else row[0]} | Date: {row[1]} | Class: {row[2]} | Subject: {row[3]} | Count: {row[4]}")

    print("\n" + "=" * 70)
    print("PHASE 6: OVERALL RATE CALCULATION")
    print("=" * 70)
    policy = get_active_policy(db)
    print(f"Active policy: {policy}")
    if policy:
        print(f"  Calculation mode: {policy.calculation_mode}")
        print(f"  Minimum percentage: {policy.minimum_percentage}")
        print(f"  OD calculation mode: {getattr(policy, 'od_calculation_mode', 'N/A')}")
        print(f"  Exclude lunch break: {getattr(policy, 'exclude_lunch_break', 'N/A')}")
    od_as_present = (getattr(policy, 'od_calculation_mode', 'COUNT_AS_PRESENT') == 'COUNT_AS_PRESENT') if policy else True
    numerator = present_count + (od_count if od_as_present else 0)
    denominator = total_records
    calc_rate = round((numerator / denominator) * 100, 2) if denominator > 0 else 0.0
    print(f"Numerator: {numerator} (present: {present_count} + od: {od_count if od_as_present else 0})")
    print(f"Denominator: {denominator}")
    print(f"Calculated Rate: {calc_rate}% (Admin dashboard displays: 67.19%)")
    print(f"Exact match: {calc_rate == 67.19}")

    print("\n" + "=" * 70)
    print("PHASE 7: FACULTY TABLE")
    print("=" * 70)
    faculties = db.query(Faculty).join(User, Faculty.user_id == User.id).order_by(Faculty.employee_id).all()
    print(f"Total faculty count: {len(faculties)}")
    for f in faculties:
        print(f"  ID: {f.id} | Emp ID: {f.employee_id} | Name: {f.full_name} | Dept: {f.department} | User: {f.user.username} | Role: {f.user.role} | Active: {f.user.is_active}")

    print("\n" + "=" * 70)
    print("PHASE 8: CLASSES")
    print("=" * 70)
    classes = db.query(ClassSection).order_by(ClassSection.id).all()
    print(f"Total class sections: {len(classes)}")
    for c in classes:
        st_count = db.query(Student).filter(Student.class_id == c.id).count()
        advisor_name = "None"
        if c.class_advisor_id:
            adv = db.query(Faculty).filter(Faculty.id == c.class_advisor_id).first()
            advisor_name = f"{adv.full_name} ({adv.employee_id})" if adv else f"ID {c.class_advisor_id}"
        print(f"  ID: {c.id} | Name: '{c.name}' | Grade: {c.grade_level} | Year: {c.academic_year} | Advisor: {advisor_name} | Students: {st_count}")

    print("\n" + "=" * 70)
    print("PHASE 9: STUDENTS")
    print("=" * 70)
    st_by_class = db.query(ClassSection.name, func.count(Student.id)).join(Student, Student.class_id == ClassSection.id).group_by(ClassSection.name).all()
    for cname, cnt in st_by_class:
        print(f"  Class: {cname} -> {cnt} students")
    # Check for orphan students (no class_id or invalid class_id)
    orphans = db.query(Student).filter(Student.class_id == None).count()
    print(f"Orphan students (no class_id): {orphans}")
    # Check inactive students
    inactive_st = db.query(Student).join(User, Student.user_id == User.id).filter(User.is_active == False).count()
    print(f"Inactive students: {inactive_st}")
    # Duplicate roll numbers
    dup_rolls = db.query(Student.roll_number, func.count(Student.id)).group_by(Student.roll_number).having(func.count(Student.id) > 1).all()
    print(f"Duplicate roll numbers: {len(dup_rolls)}")

    print("\n" + "=" * 70)
    print("PHASE 10: SUBJECT CATALOG (27)")
    print("=" * 70)
    subjects = db.query(Subject).order_by(Subject.code).all()
    print(f"Total subjects: {len(subjects)}")
    for s in subjects:
        print(f"  ID: {s.id:2d} | Code: {s.code:15s} | Name: {s.name}")

    print("\n" + "=" * 70)
    print("PHASE 11: TIMETABLE & PERIODS")
    print("=" * 70)
    periods = db.query(Period).order_by(Period.period_number).all()
    print(f"Total periods: {len(periods)}")
    for p in periods:
        st = p.start_time.strftime('%H:%M') if hasattr(p.start_time, 'strftime') else str(p.start_time)
        et = p.end_time.strftime('%H:%M') if hasattr(p.end_time, 'strftime') else str(p.end_time)
        print(f"  P{p.period_number}: {st} - {et}")
    print(f"Total timetable entries: {total_timetable_slots}")
    tt_by_day = db.query(TimetableEntry.day_of_week, func.count(TimetableEntry.id)).group_by(TimetableEntry.day_of_week).all()
    for day, cnt in tt_by_day:
        print(f"  {day}: {cnt} slots")

    print("\n" + "=" * 70)
    print("PHASE 12: FACULTY ASSIGNMENTS")
    print("=" * 70)
    assignments = db.query(FacultyAssignment).all()
    print(f"Total faculty assignments: {len(assignments)}")
    for fa in assignments:
        fac = db.query(Faculty).filter(Faculty.id == fa.faculty_id).first()
        subj = db.query(Subject).filter(Subject.id == fa.subject_id).first()
        cls = db.query(ClassSection).filter(ClassSection.id == fa.class_id).first()
        f_name = f"{fac.full_name} ({fac.employee_id})" if fac else "UNKNOWN"
        s_name = f"{subj.code} - {subj.name}" if subj else "UNKNOWN"
        c_name = cls.name if cls else "UNKNOWN"
        print(f"  Assignment {fa.id}: Faculty: {f_name:25s} | Class: {c_name:30s} | Subject: {s_name}")

    print("\n" + "=" * 70)
    print("PHASE 13: CLASS ADVISORS")
    print("=" * 70)
    for c in classes:
        if c.class_advisor_id:
            adv = db.query(Faculty).filter(Faculty.id == c.class_advisor_id).first()
            print(f"  Class: '{c.name}' (ID {c.id}) -> Advisor: {adv.full_name} ({adv.employee_id}), Faculty ID: {c.class_advisor_id}")
        else:
            print(f"  Class: '{c.name}' (ID {c.id}) -> Advisor: NONE")

    print("\n" + "=" * 70)
    print("PHASE 14: RECENT AUDIT EVENTS")
    print("=" * 70)
    logs = db.query(AuditLog).order_by(AuditLog.timestamp.desc()).limit(10).all()
    print(f"Total AuditLog count in DB: {db.query(AuditLog).count()}")
    for l in logs:
        print(f"  [{l.timestamp}] Action: {l.action} | Target: {l.target} | UserID: {l.user_id} | Details: {l.details}")

    print("\n" + "=" * 70)
    print("PHASE 15: LEGACY / DEMO DATA CHECK")
    print("=" * 70)
    # Check users with demo/test prefixes
    demo_users = db.query(User).filter(
        (User.username.ilike("%demo%")) | 
        (User.username.ilike("%test%")) |
        (User.email.ilike("%demo%")) |
        (User.email.ilike("%test%"))
    ).all()
    print(f"Users matching 'demo' or 'test': {len(demo_users)}")
    for u in demo_users:
        print(f"  User {u.id}: {u.username} ({u.role}) - {u.email}")

    # Check classes with demo/test
    demo_classes = db.query(ClassSection).filter(
        (ClassSection.name.ilike("%demo%")) | 
        (ClassSection.name.ilike("%test%"))
    ).all()
    print(f"Classes matching 'demo' or 'test': {len(demo_classes)}")

    # Check subjects with demo/test
    demo_subj = db.query(Subject).filter(
        (Subject.name.ilike("%demo%")) | 
        (Subject.name.ilike("%test%")) |
        (Subject.code.ilike("%demo%")) |
        (Subject.code.ilike("%test%"))
    ).all()
    print(f"Subjects matching 'demo' or 'test': {len(demo_subj)}")

    print("\n" + "=" * 70)
    print("PHASE 16: DIRECT TEST OF GET_DASHBOARD_STATS ENDPOINT")
    print("=" * 70)
    # Call the actual endpoint function from app.api.admin
    from app.api.admin import get_dashboard_stats
    admin_user = db.query(User).filter(User.role == UserRole.ADMIN).first()
    stats_out = get_dashboard_stats(current_user=admin_user, db=db)
    print("Endpoint get_dashboard_stats output:")
    print(json.dumps(stats_out, indent=2, default=str))

    db.close()

if __name__ == "__main__":
    run_audit()
