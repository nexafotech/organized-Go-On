"""
MILESTONE 4 SEED DATA — DEVELOPMENT ONLY
=========================================
Creates safe development/demo seed data for M4 features.

IMPORTANT: These are DEVELOPMENT-ONLY demo credentials.
Do NOT use in production.

Demo Credentials:
  Admin:    admin / admin123
  Faculty:  faculty / faculty123
  Student:  23CS101 / student123 (register number login)
  Student:  23CS102 / student123
  Student:  23CS103 / student123
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy.orm import Session
from app.core.database import SessionLocal, Base, engine
from app.core.security import get_password_hash
from app.models.user import User, Faculty, UserRole
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.student import Student
from app.models.policy import AttendancePolicy, SystemSetting
from app.models.attendance import ClassSession, AttendanceRecord, AttendanceStatus, SessionStatus, RecognitionSource


def get_or_create_setting(db: Session, key: str, value: str, description: str = "") -> SystemSetting:
    s = db.query(SystemSetting).filter(SystemSetting.key == key).first()
    if not s:
        s = SystemSetting(key=key, value=value, description=description)
        db.add(s)
    return s


def seed_m4():
    print("[M4 SEED] Creating/updating database tables...")
    Base.metadata.create_all(bind=engine)
    db: Session = SessionLocal()

    try:
        # ─────────────────────────────────────────────────────────────
        # 1. Seed Admin (if not exists)
        # ─────────────────────────────────────────────────────────────
        admin_user = db.query(User).filter(User.username == "admin").first()
        if not admin_user:
            admin_user = User(
                username="admin", email="admin@classattend.dev",
                hashed_password=get_password_hash("admin123"),
                role=UserRole.ADMIN, is_active=True,
            )
            db.add(admin_user)
            db.flush()
            print("[M4] Created admin user: admin / admin123 [DEMO ONLY]")

        # ─────────────────────────────────────────────────────────────
        # 2. Seed Faculty (if not exists)
        # ─────────────────────────────────────────────────────────────
        faculty_user = db.query(User).filter(User.username == "faculty").first()
        if not faculty_user:
            faculty_user = User(
                username="faculty", email="faculty@classattend.dev",
                hashed_password=get_password_hash("faculty123"),
                role=UserRole.FACULTY, is_active=True,
                login_identifier="EMP-101",
            )
            db.add(faculty_user)
            db.flush()

            faculty_profile = Faculty(
                user_id=faculty_user.id, employee_id="EMP-101",
                full_name="Dr. Alan Turing", department="Computer Science & Engineering"
            )
            db.add(faculty_profile)
            db.flush()
            print("[M4] Created faculty user: faculty / faculty123 [DEMO ONLY]")
        else:
            faculty_profile = db.query(Faculty).filter(Faculty.user_id == faculty_user.id).first()

        # ─────────────────────────────────────────────────────────────
        # 3. Seed Class Sections
        # ─────────────────────────────────────────────────────────────
        c1 = db.query(ClassSection).filter(ClassSection.name == "CSE-3A").first()
        if not c1:
            c1 = ClassSection(name="CSE-3A", grade_level="Year 3", academic_year="2025-2026")
            db.add(c1)
            db.flush()

        # ─────────────────────────────────────────────────────────────
        # 4. Seed Subjects
        # ─────────────────────────────────────────────────────────────
        subjects_data = [
            ("CS301", "Computer Networks"),
            ("CS302", "Data Structures"),
            ("CS303", "Operating Systems"),
        ]
        subjects_dict = {}
        for code, name in subjects_data:
            s = db.query(Subject).filter(Subject.code == code).first()
            if not s:
                s = Subject(code=code, name=name)
                db.add(s)
                db.flush()
            subjects_dict[code] = s

        # ─────────────────────────────────────────────────────────────
        # 5. Seed Periods
        # ─────────────────────────────────────────────────────────────
        periods_data = [
            (1, "Period 1", "09:10", "10:00"),
            (2, "Period 2", "10:00", "10:50"),
            (3, "Period 3", "11:10", "12:00"),
        ]
        periods_dict = {}
        for p_num, p_name, start, end in periods_data:
            p = db.query(Period).filter(Period.period_number == p_num).first()
            if not p:
                p = Period(period_number=p_num, name=p_name, start_time=start, end_time=end)
                db.add(p)
                db.flush()
            periods_dict[p_num] = p

        # ─────────────────────────────────────────────────────────────
        # 6. Seed Faculty Assignments
        # ─────────────────────────────────────────────────────────────
        assignments_dict = {}
        if faculty_profile:
            for code, subj_obj in subjects_dict.items():
                assign = db.query(FacultyAssignment).filter(
                    FacultyAssignment.faculty_id == faculty_profile.id,
                    FacultyAssignment.subject_id == subj_obj.id,
                    FacultyAssignment.class_id == c1.id
                ).first()
                if not assign:
                    assign = FacultyAssignment(
                        faculty_id=faculty_profile.id,
                        subject_id=subj_obj.id,
                        class_id=c1.id
                    )
                    db.add(assign)
                    db.flush()
                assignments_dict[code] = assign

        # ─────────────────────────────────────────────────────────────
        # 7. Seed Timetable
        # ─────────────────────────────────────────────────────────────
        schedule = {
            "Monday": [(1, "CS301"), (2, "CS302"), (3, "CS303")],
            "Tuesday": [(1, "CS302"), (2, "CS303"), (3, "CS301")],
            "Wednesday": [(1, "CS303"), (2, "CS301"), (3, "CS302")],
        }
        for day, slots in schedule.items():
            for p_num, code in slots:
                p_obj = periods_dict.get(p_num)
                assign_obj = assignments_dict.get(code)
                if p_obj and assign_obj:
                    entry = db.query(TimetableEntry).filter(
                        TimetableEntry.day_of_week == day,
                        TimetableEntry.period_id == p_obj.id,
                        TimetableEntry.assignment_id == assign_obj.id
                    ).first()
                    if not entry:
                        entry = TimetableEntry(
                            day_of_week=day, period_id=p_obj.id, assignment_id=assign_obj.id
                        )
                        db.add(entry)

        db.flush()

        # ─────────────────────────────────────────────────────────────
        # 8. Seed Students WITH login accounts (M4)
        # ─────────────────────────────────────────────────────────────
        students_data = [
            ("23CS101", "Alex Johnson", "alex@student.dev"),
            ("23CS102", "Sarah Williams", "sarah@student.dev"),
            ("23CS103", "Pugazh Arasu", "pugazh@student.dev"),
            ("23CS104", "Rahul Kumar", "rahul@student.dev"),
            ("23CS105", "Karthik Rajan", "karthik@student.dev"),
        ]

        student_objects = []
        for roll, name, email in students_data:
            # Create or find the student record
            student = db.query(Student).filter(Student.roll_number == roll).first()
            if not student:
                student = Student(
                    roll_number=roll, full_name=name, email=email,
                    class_id=c1.id, is_active=True,
                    semester="3", department="Computer Science & Engineering",
                )
                db.add(student)
                db.flush()
                print(f"[M4] Created student: {roll} - {name}")
            student_objects.append(student)

            # Create or link login account
            if not student.user_id:
                # Check if user already exists for this roll_number
                existing_user = db.query(User).filter(
                    User.username == roll, User.role == UserRole.STUDENT
                ).first()
                if not existing_user:
                    student_user = User(
                        username=roll, email=email,
                        hashed_password=get_password_hash("student123"),
                        role=UserRole.STUDENT, is_active=True,
                        login_identifier=roll,   # for REGISTER_NUMBER login
                        force_password_change=False,
                    )
                    db.add(student_user)
                    db.flush()
                else:
                    student_user = existing_user

                student.user_id = student_user.id
                db.flush()
                print(f"[M4]   -> Login account: {roll} / student123 [DEMO ONLY]")

        # ─────────────────────────────────────────────────────────────
        # 9. Seed sample attendance records
        # ─────────────────────────────────────────────────────────────
        # Only seed if no sessions exist yet
        existing_sessions = db.query(ClassSession).count()
        if existing_sessions == 0 and faculty_profile:
            # Get a timetable entry
            tt_entry = db.query(TimetableEntry).first()
            if tt_entry:
                # Create a completed session
                session = ClassSession(
                    timetable_entry_id=tt_entry.id,
                    faculty_id=faculty_profile.id,
                    date="2025-09-01",
                    status=SessionStatus.COMPLETED,
                )
                db.add(session)
                db.flush()

                # Mark attendance for all students
                statuses = [
                    AttendanceStatus.PRESENT,
                    AttendanceStatus.PRESENT,
                    AttendanceStatus.OD,      # Student 3 has OD
                    AttendanceStatus.PRESENT,
                    AttendanceStatus.ABSENT,
                ]
                od_reasons = [None, None, "College Symposium", None, None]

                for i, student in enumerate(student_objects[:5]):
                    record = AttendanceRecord(
                        session_id=session.id,
                        student_id=student.id,
                        status=statuses[i],
                        od_reason=od_reasons[i],
                        recognized_via=RecognitionSource.MANUAL if statuses[i] != AttendanceStatus.OD
                        else RecognitionSource.OD_OVERRIDE,
                    )
                    db.add(record)

                print("[M4] Seeded sample attendance session (2025-09-01) with OD example")

        # ─────────────────────────────────────────────────────────────
        # 10. Seed AttendancePolicy (default if not exists)
        # ─────────────────────────────────────────────────────────────
        existing_policy = db.query(AttendancePolicy).filter(AttendancePolicy.is_active == True).first()
        if not existing_policy:
            policy = AttendancePolicy(
                calculation_unit="PERIOD",
                minimum_percentage=75.0,
                warning_threshold=75.0,
                critical_threshold=65.0,
                unmarked_behavior="NOT_ENTERED",
                exclude_no_class=True,
                exclude_suspended=True,
                exclude_timetable_not_set=True,
                od_enabled=True,
                od_faculty_can_mark=True,
                od_require_reason=False,
                od_require_approval=False,
                od_allow_retroactive=False,
                od_allow_multiple_periods=True,
                od_calculation_mode="COUNT_AS_PRESENT",
                leave_calculation_mode="ABSENT",
                calculation_mode="RECORD_BASED",
                period_present_gain=0.25,
                period_absent_loss=0.25,
                class_present_gain=1.00,
                class_absent_loss=1.00,
                day_present_gain=1.00,
                day_absent_loss=1.00,
                description="Default attendance policy — DEVELOPMENT SEED",
                is_active=True,
            )
            db.add(policy)
            print("[M4] Created default attendance policy")

        # ─────────────────────────────────────────────────────────────
        # 11. Seed System Settings (auth + AI defaults)
        # ─────────────────────────────────────────────────────────────
        settings_data = [
            # Auth settings
            ("auth.faculty_login_method", "USERNAME", "Login method for faculty"),
            ("auth.student_login_method", "REGISTER_NUMBER", "Login method for students"),
            ("auth.min_password_length", "8", "Minimum password length"),
            ("auth.require_uppercase", "true", "Require uppercase"),
            ("auth.require_digit", "true", "Require digit"),
            ("auth.require_special", "false", "Require special character"),
            ("auth.max_failed_attempts", "5", "Max failed login attempts"),
            ("auth.lock_duration_minutes", "30", "Lock duration in minutes"),
            ("auth.session_days", "7", "Session lifetime days"),
            ("auth.force_change_on_reset", "true", "Force change on password reset"),
            ("auth.password_expiry_days", "0", "Password expiry days (0=never)"),
            # AI settings (quantized ON by default)
            ("ai.quantized_model", "true", "Use quantized/mobile model — ON by default"),
            ("ai.recognition_threshold", "0.45", "Face match confident threshold"),
            ("ai.uncertain_threshold", "0.60", "Face match uncertain threshold"),
            ("ai.min_face_size_px", "50", "Min face size pixels"),
            ("ai.image_quality_threshold", "0.5", "Min image quality score"),
            ("ai.performance_mode", "BALANCED", "AI performance mode"),
        ]
        for key, value, description in settings_data:
            get_or_create_setting(db, key, value, description)

        db.commit()
        print()
        print("✅ Milestone 4 Seed Completed Successfully!")
        print("═" * 55)
        print("⚠️  DEVELOPMENT CREDENTIALS — DO NOT USE IN PRODUCTION")
        print("═" * 55)
        print("  Admin:          admin / admin123")
        print("  Faculty:        faculty / faculty123")
        print("  Student Login:  23CS101 / student123  (register number)")
        print("  Student Login:  23CS102 / student123")
        print("  Student Login:  23CS103 / student123")
        print("  Student Login:  23CS104 / student123")
        print("  Student Login:  23CS105 / student123")
        print("═" * 55)
        print("  Auth method:    admin → USERNAME, student → REGISTER_NUMBER")
        print("  AI setting:     quantized_model = ON (default)")
        print("  OD policy:      enabled, COUNT_AS_PRESENT")
        print("═" * 55)

    except Exception as e:
        db.rollback()
        print(f"❌ M4 seed error: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_m4()
