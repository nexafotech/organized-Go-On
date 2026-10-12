import os
import json
import csv
from datetime import time, datetime
from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import get_password_hash
from app.models.user import User, Faculty, UserRole
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.student import Student


class ImportValidationError(Exception):
    def __init__(self, message: str, errors: Optional[List[str]] = None):
        super().__init__(message)
        self.message = message
        self.errors = errors or []

def normalize_time_value(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, time):
        return value.strftime("%H:%M")
    if isinstance(value, datetime):
        return value.time().strftime("%H:%M")
    val_str = str(value).strip()
    parts = val_str.split(":")
    if len(parts) >= 2:
        hh = parts[0].zfill(2)
        mm = parts[1].zfill(2)
        return f"{hh}:{mm}"
    return val_str

def reset_demo_academic_configuration(db: Session) -> Dict[str, int]:
    """
    Development/Test helper to reset unreferenced academic configuration state
    (TimetableEntry, FacultyAssignment, Period, Subject, ClassSection) before official college seed import.
    Does NOT touch users, student profiles, faculty profiles, attendance records,
    class sessions, audit logs, or face embeddings.
    Uses explicit SQL queries against actual foreign key relationships.
    """
    from app.models.attendance import ClassSession

    removed_tt = 0
    removed_fa = 0
    removed_p = 0
    removed_sub = 0
    removed_cs = 0

    try:
        # 1. Timetable Entries (delete if not referenced by ClassSession)
        all_tt = db.query(TimetableEntry).all()
        for tt in all_tt:
            sess_ref = db.query(ClassSession).filter(ClassSession.timetable_entry_id == tt.id).first()
            if not sess_ref:
                db.delete(tt)
                removed_tt += 1
        db.flush()

        # 2. Faculty Assignments (delete if not referenced by TimetableEntry)
        all_fa = db.query(FacultyAssignment).all()
        for fa in all_fa:
            tt_ref = db.query(TimetableEntry).filter(TimetableEntry.assignment_id == fa.id).first()
            if not tt_ref:
                db.delete(fa)
                removed_fa += 1
        db.flush()

        # 3. Periods (delete if not referenced by TimetableEntry)
        all_p = db.query(Period).all()
        for p in all_p:
            tt_ref = db.query(TimetableEntry).filter(TimetableEntry.period_id == p.id).first()
            if not tt_ref:
                db.delete(p)
                removed_p += 1
        db.flush()

        # 4. Subjects (delete if not referenced by FacultyAssignment)
        all_sub = db.query(Subject).all()
        for sub in all_sub:
            fa_ref = db.query(FacultyAssignment).filter(FacultyAssignment.subject_id == sub.id).first()
            if not fa_ref:
                db.delete(sub)
                removed_sub += 1
        db.flush()

        # 5. Class Sections (delete if not referenced by Student or FacultyAssignment)
        all_cs = db.query(ClassSection).all()
        for cs in all_cs:
            st_ref = db.query(Student).filter(Student.class_id == cs.id).first()
            fa_ref = db.query(FacultyAssignment).filter(FacultyAssignment.class_id == cs.id).first()
            if not st_ref and not fa_ref:
                db.delete(cs)
                removed_cs += 1
        db.flush()

    except Exception:
        db.rollback()
        raise

    return {
        "removed_timetable": removed_tt,
        "removed_assignments": removed_fa,
        "removed_periods": removed_p,
        "removed_subjects": removed_sub,
        "removed_classes": removed_cs
    }

def import_class_sections(db: Session, items: List[Dict[str, Any]]) -> Dict[str, Any]:
    errors = []
    created = []
    skipped = []
    seen_in_batch = set()

    for idx, item in enumerate(items):
        name = item.get("name", "").strip()
        grade_level = item.get("grade_level", "").strip() or "Default"
        academic_year = item.get("academic_year", "").strip() or "2026-2027"

        if not name:
            errors.append(f"Row {idx+1}: Class section name is required")
            continue

        if name in seen_in_batch:
            errors.append(f"Row {idx+1}: Duplicate class section name '{name}' in input batch")
            continue
        seen_in_batch.add(name)

        existing = db.query(ClassSection).filter(ClassSection.name == name).first()
        if existing:
            if existing.grade_level == grade_level and existing.academic_year == academic_year:
                skipped.append(existing)
                continue
            else:
                errors.append(f"Row {idx+1}: Class section '{name}' already exists with conflicting details (existing: {existing.grade_level}/{existing.academic_year}, input: {grade_level}/{academic_year})")
                continue

        cs = ClassSection(
            name=name,
            grade_level=grade_level,
            academic_year=academic_year
        )
        db.add(cs)
        created.append(cs)

    if errors:
        db.rollback()
        raise ImportValidationError("Class sections import failed validation", errors)

    db.flush()
    return {
        "imported": len(created),
        "skipped_existing": len(skipped),
        "created": created,
        "skipped": skipped
    }

def import_periods(db: Session, items: List[Dict[str, Any]]) -> Dict[str, Any]:
    errors = []
    created = []
    skipped = []
    seen_in_batch = set()

    for idx, item in enumerate(items):
        period_number = item.get("period_number")
        name = item.get("name", "").strip()
        start_time = item.get("start_time", "").strip()
        end_time = item.get("end_time", "").strip()

        if period_number is None:
            errors.append(f"Row {idx+1}: period_number is required")
            continue

        if period_number in seen_in_batch:
            errors.append(f"Row {idx+1}: Duplicate period_number {period_number} in input batch")
            continue
        seen_in_batch.add(period_number)

        existing = db.query(Period).filter(Period.period_number == period_number).first()
        if existing:
            existing_start_norm = normalize_time_value(existing.start_time)
            input_start_norm = normalize_time_value(start_time)
            existing_end_norm = normalize_time_value(existing.end_time)
            input_end_norm = normalize_time_value(end_time)

            same_start = existing_start_norm == input_start_norm
            same_end = existing_end_norm == input_end_norm
            same_name = not name or existing.name == name

            if same_start and same_end and same_name:
                skipped.append(existing)
                continue
            else:
                errors.append(
                    f"Row {idx+1}: Period {period_number} conflict:\n"
                    f" existing: name='{existing.name}', start_time='{existing.start_time}', end_time='{existing.end_time}' (normalized: '{existing_start_norm}'-'{existing_end_norm}')\n"
                    f" incoming: name='{name}', start_time='{start_time}', end_time='{end_time}' (normalized: '{input_start_norm}'-'{input_end_norm}')"
                )
                continue

        p = Period(
            period_number=period_number,
            name=name or f"Period {period_number}",
            start_time=start_time,
            end_time=end_time
        )
        db.add(p)
        created.append(p)

    if errors:
        db.rollback()
        raise ImportValidationError("Periods import failed validation", errors)

    db.flush()
    return {
        "imported": len(created),
        "skipped_existing": len(skipped),
        "created": created,
        "skipped": skipped
    }

def import_subjects(db: Session, items: List[Dict[str, Any]]) -> Dict[str, Any]:
    errors = []
    created = []
    skipped = []
    seen_in_batch = set()

    for idx, item in enumerate(items):
        code = item.get("code", "").strip()
        name = item.get("name", "").strip()

        if not code or not name:
            errors.append(f"Row {idx+1}: Both code and name are required for subject")
            continue

        if code in seen_in_batch:
            errors.append(f"Row {idx+1}: Duplicate subject code '{code}' in input batch")
            continue
        seen_in_batch.add(code)

        existing = db.query(Subject).filter(Subject.code == code).first()
        if existing:
            if existing.name == name:
                skipped.append(existing)
                continue
            else:
                errors.append(f"Row {idx+1}: Subject code '{code}' already exists with conflicting name ('{existing.name}' vs '{name}')")
                continue

        s = Subject(code=code, name=name)
        db.add(s)
        created.append(s)

    if errors:
        db.rollback()
        raise ImportValidationError("Subjects import failed validation", errors)

    db.flush()
    return {
        "imported": len(created),
        "skipped_existing": len(skipped),
        "created": created,
        "skipped": skipped
    }

def import_faculty(db: Session, items: List[Dict[str, Any]]) -> Dict[str, Any]:
    errors = []
    created = []
    skipped = []
    seen_in_batch = set()
    current_faculty_count = db.query(Faculty).count()

    for idx, item in enumerate(items):
        username = item.get("username", "").strip()
        email = item.get("email", "").strip()
        employee_id = item.get("employee_id", "").strip()
        full_name = item.get("full_name", "").strip()
        department = item.get("department", "").strip()
        password = item.get("password", "faculty123")

        if not username or not email or not employee_id:
            errors.append(f"Row {idx+1}: username, email, and employee_id are required")
            continue

        if username in seen_in_batch or employee_id in seen_in_batch:
            errors.append(f"Row {idx+1}: Duplicate username/employee_id in input batch")
            continue
        seen_in_batch.add(username)
        seen_in_batch.add(employee_id)

        existing_user = db.query(User).filter(User.username == username).first()
        existing_fac = db.query(Faculty).filter(Faculty.employee_id == employee_id).first()

        if existing_user or existing_fac:
            if existing_user and existing_fac and existing_user.id == existing_fac.user_id:
                if existing_user.email == email and existing_fac.full_name == (full_name or username):
                    skipped.append(existing_fac)
                    continue
            errors.append(f"Row {idx+1}: Faculty '{username}' / '{employee_id}' already exists with conflicting details")
            continue

        if current_faculty_count + len(created) + 1 > settings.MAX_FACULTY:
            errors.append(f"Maximum faculty capacity of {settings.MAX_FACULTY} has been reached.")
            break

        user = User(
            username=username,
            email=email,
            hashed_password=get_password_hash(password),
            role=UserRole.FACULTY,
            is_active=True,
            login_identifier=employee_id
        )
        db.add(user)
        db.flush()

        fac = Faculty(
            user_id=user.id,
            employee_id=employee_id,
            full_name=full_name or username,
            department=department or "General"
        )
        db.add(fac)
        created.append(fac)

    if errors:
        db.rollback()
        raise ImportValidationError("Faculty import failed validation", errors)

    db.flush()
    return {
        "imported": len(created),
        "skipped_existing": len(skipped),
        "created": created,
        "skipped": skipped
    }

def import_faculty_assignments(db: Session, items: List[Dict[str, Any]]) -> Dict[str, Any]:
    errors = []
    created = []
    skipped = []
    skipped_unassigned = []

    for idx, item in enumerate(items):
        class_name = item.get("class_name", "").strip()
        subject_code = item.get("subject_code", "").strip()
        faculty_username = item.get("faculty_username")

        cs = db.query(ClassSection).filter(ClassSection.name == class_name).first()
        if not cs:
            errors.append(f"Row {idx+1}: Class Section '{class_name}' not found")
            continue

        sub = db.query(Subject).filter(Subject.code == subject_code).first()
        if not sub:
            errors.append(f"Row {idx+1}: Subject '{subject_code}' not found")
            continue

        fac = None
        if faculty_username:
            user = db.query(User).filter(User.username == faculty_username).first()
            if user:
                fac = db.query(Faculty).filter(Faculty.user_id == user.id).first()

            if not fac:
                errors.append(f"Row {idx+1}: Faculty '{faculty_username}' not found")
                continue

        existing = db.query(FacultyAssignment).filter(
            FacultyAssignment.class_id == cs.id,
            FacultyAssignment.subject_id == sub.id,
            FacultyAssignment.faculty_id == (fac.id if fac else None)
        ).first()

        if existing:
            skipped.append(existing)
            continue

        if fac is None:
            # Unassigned mapping skipped gracefully in official seed
            skipped_unassigned.append({"class_name": class_name, "subject_code": subject_code})
            continue

        fa = FacultyAssignment(class_id=cs.id, subject_id=sub.id, faculty_id=fac.id)
        db.add(fa)
        created.append(fa)

    if errors:
        db.rollback()
        raise ImportValidationError("Faculty assignments import failed validation", errors)

    db.flush()
    return {
        "imported": len(created),
        "skipped_existing": len(skipped),
        "skipped_unassigned": len(skipped_unassigned),
        "created": created,
        "skipped": skipped
    }

def import_students(db: Session, items: List[Dict[str, Any]]) -> Dict[str, Any]:
    errors = []
    created = []
    skipped = []
    seen_in_batch = set()
    current_student_count = db.query(Student).count()

    for idx, item in enumerate(items):
        roll_number = item.get("roll_number", "").strip()
        full_name = item.get("full_name", "").strip()
        email = item.get("email", "").strip()
        class_name = item.get("class_name", "").strip()
        password = item.get("password", "student123")

        if not roll_number or not full_name:
            errors.append(f"Row {idx+1}: roll_number and full_name are required")
            continue

        if roll_number in seen_in_batch:
            errors.append(f"Row {idx+1}: Duplicate roll_number '{roll_number}' in input batch")
            continue
        seen_in_batch.add(roll_number)

        cs_id = None
        if class_name:
            cs = db.query(ClassSection).filter(ClassSection.name == class_name).first()
            if not cs:
                errors.append(f"Row {idx+1}: Class section '{class_name}' not found")
                continue
            cs_id = cs.id

        existing_st = db.query(Student).filter(Student.roll_number == roll_number).first()
        existing_usr = db.query(User).filter(User.username == roll_number).first()

        if existing_st or existing_usr:
            if existing_st and existing_usr and existing_st.user_id == existing_usr.id:
                if existing_st.full_name == full_name:
                    skipped.append(existing_st)
                    continue
            errors.append(f"Row {idx+1}: Student roll_number '{roll_number}' already exists")
            continue

        if email and db.query(User).filter(User.email == email).first():
            errors.append(f"Row {idx+1}: User email '{email}' already exists")
            continue

        if current_student_count + len(created) + 1 > settings.MAX_STUDENTS:
            errors.append(f"Maximum student capacity of {settings.MAX_STUDENTS} has been reached.")
            break

        user = User(
            username=roll_number,
            email=email or f"{roll_number.lower()}@student.college.edu",
            hashed_password=get_password_hash(password),
            role=UserRole.STUDENT,
            is_active=True,
            login_identifier=roll_number
        )
        db.add(user)
        db.flush()

        st = Student(
            user_id=user.id,
            roll_number=roll_number,
            full_name=full_name,
            class_id=cs_id,
            is_active=True
        )
        db.add(st)
        created.append(st)

    if errors:
        db.rollback()
        raise ImportValidationError("Student import failed validation", errors)

    db.flush()
    return {
        "imported": len(created),
        "skipped_existing": len(skipped),
        "created": created,
        "skipped": skipped
    }

def import_timetable(db: Session, items: List[Dict[str, Any]]) -> Dict[str, Any]:
    errors = []
    created = []
    skipped = []
    skipped_unassigned = []

    for idx, item in enumerate(items):
        class_name = item.get("class_name", "").strip()
        day_of_week = item.get("day_of_week", "").strip()
        period_number = item.get("period_number")
        subject_code = item.get("subject_code", "").strip()

        cs = db.query(ClassSection).filter(ClassSection.name == class_name).first()
        if not cs:
            errors.append(f"Row {idx+1}: Class section '{class_name}' not found")
            continue

        p = db.query(Period).filter(Period.period_number == period_number).first()
        if not p:
            errors.append(f"Row {idx+1}: Period number {period_number} not found")
            continue

        sub = db.query(Subject).filter(Subject.code == subject_code).first()
        if not sub:
            errors.append(f"Row {idx+1}: Subject code '{subject_code}' not found")
            continue

        fa = db.query(FacultyAssignment).filter(
            FacultyAssignment.class_id == cs.id,
            FacultyAssignment.subject_id == sub.id
        ).first()

        if not fa:
            # FacultyAssignment does not exist because faculty is unassigned.
            # Do NOT create a FacultyAssignment with NULL faculty_id.
            skipped_unassigned.append({
                "class_name": class_name,
                "day_of_week": day_of_week,
                "period_number": period_number,
                "subject_code": subject_code
            })
            continue

        existing = db.query(TimetableEntry).filter(
            TimetableEntry.assignment_id == fa.id,
            TimetableEntry.period_id == p.id,
            TimetableEntry.day_of_week == day_of_week
        ).first()

        if existing:
            skipped.append(existing)
            continue

        tt = TimetableEntry(
            assignment_id=fa.id,
            period_id=p.id,
            day_of_week=day_of_week
        )
        db.add(tt)
        created.append(tt)

    if errors:
        db.rollback()
        raise ImportValidationError("Timetable import failed validation", errors)

    db.flush()
    return {
        "imported": len(created),
        "skipped_existing": len(skipped),
        "skipped_unassigned": len(skipped_unassigned),
        "created": created,
        "skipped": skipped
    }

def import_college_seed_bundle(db: Session, seed_dir: str = "college_seed") -> Dict[str, Any]:
    base_path = os.path.abspath(seed_dir)
    results = {}

    # 1. Class Sections
    cs_path = os.path.join(base_path, "class_sections.json")
    if os.path.exists(cs_path):
        with open(cs_path, "r", encoding="utf-8") as f:
            items = json.load(f)
            res = import_class_sections(db, items)
            results["class_sections"] = {"imported": res["imported"], "skipped_existing": res["skipped_existing"]}

    # 2. Periods
    p_path = os.path.join(base_path, "periods.json")
    if os.path.exists(p_path):
        with open(p_path, "r", encoding="utf-8") as f:
            items = json.load(f)
            res = import_periods(db, items)
            results["periods"] = {"imported": res["imported"], "skipped_existing": res["skipped_existing"]}

    # 3. Subjects
    sub_path = os.path.join(base_path, "subjects.json")
    if os.path.exists(sub_path):
        with open(sub_path, "r", encoding="utf-8") as f:
            items = json.load(f)
            res = import_subjects(db, items)
            results["subjects"] = {"imported": res["imported"], "skipped_existing": res["skipped_existing"]}

    # 4. Faculty (optional)
    fac_path = os.path.join(base_path, "faculty.json")
    if os.path.exists(fac_path):
        with open(fac_path, "r", encoding="utf-8") as f:
            items = json.load(f)
            res = import_faculty(db, items)
            results["faculty"] = {"imported": res["imported"], "skipped_existing": res["skipped_existing"]}

    # 5. Faculty Assignments
    fa_path = os.path.join(base_path, "faculty_assignments.json")
    if os.path.exists(fa_path):
        with open(fa_path, "r", encoding="utf-8") as f:
            items = json.load(f)
            res = import_faculty_assignments(db, items)
            results["faculty_assignments"] = {
                "imported": res["imported"],
                "skipped_existing": res["skipped_existing"],
                "skipped_unassigned": res.get("skipped_unassigned", 0)
            }

    # 6. Class 1 Timetable
    tt_path = os.path.join(base_path, "timetable_class1.json")
    if os.path.exists(tt_path):
        with open(tt_path, "r", encoding="utf-8") as f:
            items = json.load(f)
            res = import_timetable(db, items)
            results["timetable_entries"] = {
                "imported": res["imported"],
                "skipped_existing": res["skipped_existing"],
                "skipped_unassigned": res.get("skipped_unassigned", 0)
            }

    db.commit()
    return results


def seed_temporary_dev_timetable(db: Session, class_name: Optional[str] = None, force_reset: bool = True) -> Dict[str, Any]:
    """
    Seeds the TEMPORARY DEVELOPMENT TIMETABLE for Class 1 and/or Class 2.
    This dataset is strictly for development and local testing.
    Ensures temporary faculty (FAC01-FAC05), subjects, periods, assignments, and 42 period slots per class (Mon-Sat P1-P7).
    """
    from app.models.attendance import ClassSession

    # 1. Ensure Periods (1..7)
    periods_data = [
        (1, "Period 1", "09:10", "10:00"),
        (2, "Period 2", "10:00", "10:50"),
        (3, "Period 3", "11:10", "12:00"),
        (4, "Period 4", "12:00", "12:50"),
        (5, "Period 5", "13:40", "14:30"),
        (6, "Period 6", "14:30", "15:20"),
        (7, "Period 7", "15:20", "16:10"),
    ]
    periods_map = {}
    for pnum, pname, pstart, pend in periods_data:
        p = db.query(Period).filter(Period.period_number == pnum).first()
        if not p:
            p = Period(period_number=pnum, name=pname, start_time=pstart, end_time=pend)
            db.add(p)
            db.flush()
        elif pnum == 6:
            p.start_time = pstart
            p.end_time = pend
            db.flush()
        periods_map[pnum] = p

    # 2. Ensure Class Sections
    cs1_name = "II Year CSE Cyber Security - Class 1"
    cs2_name = "III Year CSE Cyber Security - Class 2"

    cs1 = db.query(ClassSection).filter(ClassSection.name == cs1_name).first()
    if not cs1:
        cs1 = ClassSection(name=cs1_name, grade_level="II Year", academic_year="2026-2027")
        db.add(cs1)
        db.flush()

    cs2 = db.query(ClassSection).filter(ClassSection.name == cs2_name).first()
    if not cs2:
        cs2 = ClassSection(name=cs2_name, grade_level="III Year", academic_year="2026-2027")
        db.add(cs2)
        db.flush()

    # 3. Ensure Subjects (Combined Class 1 + Class 2)
    subjects_data = [
        ("FDS", "Foundations of Data Science"),
        ("DMC", "Discrete Mathematics for Computing"),
        ("FDS LAB", "Foundations of Data Science Laboratory"),
        ("DPCO", "Digital Principles & Computer Organization"),
        ("OOPS", "Object Oriented Programming Systems"),
        ("DS", "Data Structures"),
        ("ACE-I", "Aptitude & Communication Enhancement I"),
        ("UHV", "Universal Human Values"),
        ("IKS", "Indian Knowledge System"),
        ("DS LAB", "Data Structures Laboratory"),
        ("IIC", "Innovation & Incubation Cell"),
        ("JAVA LAB", "Java Programming Laboratory"),
        ("TWM", "Tutor Ward Meeting"),
        ("LIB", "Library Hour"),
        ("ASSOC", "Department Association Hour"),
        ("AIML", "Artificial Intelligence & Machine Learning"),
        ("LP", "Linux Programming"),
        ("SDBMS", "Secure Database Management Systems"),
        ("ESSS", "Engineering Secure Software Systems"),
        ("SDBMS LAB", "Secure Database Management Systems Lab"),
        ("CC", "Cloud Computing"),
        ("E&I", "Entrepreneurship and Innovation"),
        ("CC-I", "Campus to Corporate-I"),
        ("LINUX LAB", "Linux Laboratory"),
        ("ESSS LAB", "Engineering Secure Software Systems Laboratory"),
        ("CF", "Cyber Forensics"),
        ("CF LAB", "Cyber Forensics Laboratory"),
    ]
    subjects_map = {}
    for code, name in subjects_data:
        s = db.query(Subject).filter(Subject.code == code).first()
        if not s:
            s = Subject(code=code, name=name)
            db.add(s)
            db.flush()
        else:
            if s.name != name:
                s.name = name
                db.flush()
        subjects_map[code] = s

    # Ensure any already created subjects in DB (e.g. IKS) are included in subjects_map
    for s in db.query(Subject).all():
        if s.code not in subjects_map:
            subjects_map[s.code] = s

    # 4. Ensure Temporary Faculty
    dev_faculty_data = [
        ("FAC01", "Mathu Metlda", "fac01", "fac01@college.edu"),
        ("FAC02", "Showmiya", "fac02", "fac02@college.edu"),
        ("FAC03", "Sivakumar", "fac03", "fac03@college.edu"),
        ("FAC04", "Shankar", "fac04", "fac04@college.edu"),
        ("FAC05", "Santhiya", "fac05", "fac05@college.edu"),
        ("FAC06", "Lakshmi Narayanan", "fac06", "fac06@college.edu"),
        ("FAC07", "Princy", "fac07", "fac07@college.edu"),
        ("FAC08", "Gowri Manohari", "fac08", "fac08@college.edu"),
    ]
    faculty_map = {}
    for emp_id, full_name, username, email in dev_faculty_data:
        fac = db.query(Faculty).filter(Faculty.employee_id == emp_id).first()
        if not fac:
            user = db.query(User).filter(User.username == username).first()
            if not user:
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
            fac = Faculty(
                user_id=user.id,
                employee_id=emp_id,
                full_name=full_name,
                department="CSE Cyber Security"
            )
            db.add(fac)
            db.flush()
        faculty_map[emp_id] = fac

    # Determine which classes to seed
    classes_to_seed = []
    if class_name == "all":
        classes_to_seed = [(cs1, "Class 1"), (cs2, "Class 2")]
    elif class_name:
        if "Class 2" in class_name or class_name == cs2_name:
            classes_to_seed.append((cs2, "Class 2"))
        elif "Class 1" in class_name or class_name == cs1_name:
            classes_to_seed.append((cs1, "Class 1"))
        else:
            found_cs = db.query(ClassSection).filter(ClassSection.name == class_name).first()
            if found_cs and (found_cs.id == cs2.id or found_cs.name == cs2_name):
                classes_to_seed.append((cs2, "Class 2"))
            elif found_cs:
                classes_to_seed.append((found_cs, found_cs.name))
            else:
                classes_to_seed.append((cs1, "Class 1"))
    else:
        # Default: Class 1 (preserves exact backward compatibility for existing Class 1 workflows)
        classes_to_seed = [(cs1, "Class 1")]


    # 5. Class 1 Assignments & Schedule Specification
    class1_assignments_spec = {
        "DMC": "FAC07",
        "DS": "FAC02",
        "OOPS": "FAC03",
        "DPCO": "FAC06",
        "FDS": "FAC05",
        "DS LAB": "FAC02",
        "JAVA LAB": "FAC03",
        "ACE-I": "FAC08",
        "UHV": "FAC05",
        "LIB": "FAC05",
        "IIC": "FAC05",
        "TWM": "FAC01",
        "ASSOC": "FAC05",
        "FDS LAB": "FAC05",
    }

    has_iks = "IKS" in subjects_map
    if has_iks:
        class1_assignments_spec["IKS"] = "FAC05"

    class1_authorized_faculty_spec = {
        "ACE-I": ["FAC08", "FAC04"],
        "TWM": ["FAC01", "FAC02", "FAC04", "FAC03", "FAC05"],
        "ASSOC": ["FAC05"],
        "DPCO": ["FAC06"],
        "DMC": ["FAC07"],
    }

    class1_schedule = [
        # Monday
        ("Monday", 1, "FDS"),
        ("Monday", 2, "DMC"),
        ("Monday", 3, "FDS LAB"),
        ("Monday", 4, "FDS LAB"),
        ("Monday", 5, "DPCO"),
        ("Monday", 6, "OOPS"),
        ("Monday", 7, "DS"),
        # Tuesday
        ("Tuesday", 1, "DMC"),
        ("Tuesday", 2, "FDS"),
        ("Tuesday", 3, "DPCO"),
        ("Tuesday", 4, "DMC"),
        ("Tuesday", 5, "OOPS"),
        ("Tuesday", 6, "LIB"),
        ("Tuesday", 7, "DPCO"),
        # Wednesday
        ("Wednesday", 1, "OOPS"),
        ("Wednesday", 2, "DMC"),
        ("Wednesday", 3, "DPCO"),
        ("Wednesday", 4, "DS"),
        ("Wednesday", 5, "ACE-I"),
        ("Wednesday", 6, "ACE-I"),
        ("Wednesday", 7, "ACE-I"),
        # Thursday
        ("Thursday", 1, "DPCO"),
        ("Thursday", 2, "IKS" if has_iks else "UHV"),
        ("Thursday", 3, "DS LAB"),
        ("Thursday", 4, "DS LAB"),
        ("Thursday", 5, "IIC"),
        ("Thursday", 6, "DS"),
        ("Thursday", 7, "FDS"),
        # Friday
        ("Friday", 1, "DS"),
        ("Friday", 2, "FDS"),
        ("Friday", 3, "JAVA LAB"),
        ("Friday", 4, "JAVA LAB"),
        ("Friday", 5, "TWM"),
        ("Friday", 6, "DMC"),
        ("Friday", 7, "OOPS"),
        # Saturday
        ("Saturday", 1, "IKS" if has_iks else "UHV"),
        ("Saturday", 2, "OOPS"),
        ("Saturday", 3, "DMC"),
        ("Saturday", 4, "DS"),
        ("Saturday", 5, "ASSOC"),
        ("Saturday", 6, "ASSOC"),
        ("Saturday", 7, "ASSOC"),
    ]

    # 6. Class 2 Assignments & Schedule Specification
    class2_assignments_spec = {
        "CF": "FAC05",       # Mrs. R. Sandhiya (POP) mapped explicitly to dev faculty FAC05
        "SDBMS": "FAC04",    # Mr. D. Shankar
        "CC": "FAC01",       # Dr. T. Mathu
        "LP": "FAC03",       # Dr. K. Sivakumar
        "AIML": "FAC04",     # Mr. D. Shankar
        "ESSS": "FAC02",     # Mrs. P. Showmiya
        "SDBMS LAB": "FAC04",# Mr. D. Shankar
        "CC-I": "FAC03",     # Dr. K. Sivakumar
        "E&I": "FAC02",      # Mrs. P. Showmiya
        "LIB": "FAC02",      # Mrs. P. Showmiya
        "TWM": None,         # All Faculty Members (Pending)
        "IIC": "FAC02",      # Mrs. P. Showmiya
        "LINUX LAB": None,   # Unassigned (Pending)
        "CF LAB": None,      # Unassigned (Pending)
        "ESSS LAB": None,    # Unassigned (Pending)
    }

    class2_schedule = [
        # Monday
        ("Monday", 1, "AIML"),
        ("Monday", 2, "LP"),
        ("Monday", 3, "SDBMS"),
        ("Monday", 4, "LP"),
        ("Monday", 5, "ESSS"),
        ("Monday", 6, "SDBMS LAB"),
        ("Monday", 7, "SDBMS LAB"),
        # Tuesday
        ("Tuesday", 1, "ESSS"),
        ("Tuesday", 2, "AIML"),
        ("Tuesday", 3, "CC"),
        ("Tuesday", 4, "ESSS"),
        ("Tuesday", 5, "SDBMS"),
        ("Tuesday", 6, "LP"),
        ("Tuesday", 7, "E&I"),
        # Wednesday
        ("Wednesday", 1, "SDBMS"),
        ("Wednesday", 2, "ESSS"),
        ("Wednesday", 3, "CC-I"),
        ("Wednesday", 4, "CC-I"),
        ("Wednesday", 5, "CC-I"),
        ("Wednesday", 6, "LIB"),
        ("Wednesday", 7, "CC"),
        # Thursday
        ("Thursday", 1, "CC"),
        ("Thursday", 2, "AIML"),
        ("Thursday", 3, "E&I"),
        ("Thursday", 4, "SDBMS"),
        ("Thursday", 5, "IIC"),
        ("Thursday", 6, "LINUX LAB"),
        ("Thursday", 7, "LINUX LAB"),
        # Friday
        ("Friday", 1, "LP"),
        ("Friday", 2, "SDBMS"),
        ("Friday", 3, "CC"),
        ("Friday", 4, "ESSS"),
        ("Friday", 5, "TWM"),
        ("Friday", 6, "ESSS LAB"),
        ("Friday", 7, "ESSS LAB"),
        # Saturday
        ("Saturday", 1, "CF"),
        ("Saturday", 2, "AIML"),
        ("Saturday", 3, "CF LAB"),
        ("Saturday", 4, "CF LAB"),
        ("Saturday", 5, "CF"),
        ("Saturday", 6, "CF"),
        ("Saturday", 7, "CF"),
    ]

    total_created = 0
    total_skipped = 0
    seeded_class_names = []

    for target_cs, label in classes_to_seed:
        is_class2 = (target_cs.id == cs2.id or target_cs.name == cs2_name)
        spec = class2_assignments_spec if is_class2 else class1_assignments_spec
        sched = class2_schedule if is_class2 else class1_schedule

        # Ensure faculty assignments
        assignments_map = {}
        for sub_code, fac_emp in spec.items():
            sub = subjects_map[sub_code]
            fac_id = faculty_map[fac_emp].id if fac_emp else None
            fa = db.query(FacultyAssignment).filter(
                FacultyAssignment.class_id == target_cs.id,
                FacultyAssignment.subject_id == sub.id,
            ).first()
            if not fa:
                fa = FacultyAssignment(
                    class_id=target_cs.id,
                    subject_id=sub.id,
                    faculty_id=fac_id
                )
                db.add(fa)
                db.flush()
            else:
                fa.faculty_id = fac_id

            if not is_class2 and sub_code in class1_authorized_faculty_spec:
                auth_emps = class1_authorized_faculty_spec[sub_code]
                fa.authorized_faculty = [faculty_map[emp] for emp in auth_emps if emp in faculty_map]

            assignments_map[sub_code] = fa

        # If force_reset, remove existing TimetableEntry for this class if not linked to ClassSession
        if force_reset:
            existing_entries = (
                db.query(TimetableEntry)
                .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
                .filter(FacultyAssignment.class_id == target_cs.id)
                .all()
            )
            for ent in existing_entries:
                has_sess = db.query(ClassSession).filter(ClassSession.timetable_entry_id == ent.id).first()
                if not has_sess:
                    db.delete(ent)
            db.flush()

        for day, pnum, sub_code in sched:
            p = periods_map[pnum]
            fa = assignments_map[sub_code]

            existing = db.query(TimetableEntry).filter(
                TimetableEntry.day_of_week == day,
                TimetableEntry.period_id == p.id,
                TimetableEntry.assignment_id == fa.id
            ).first()

            if existing:
                total_skipped += 1
            else:
                tt = TimetableEntry(
                    day_of_week=day,
                    period_id=p.id,
                    assignment_id=fa.id
                )
                db.add(tt)
                total_created += 1

        seeded_class_names.append(target_cs.name)

    db.commit()
    return {
        "status": "success",
        "message": f"Temporary development timetable initialized for {', '.join(seeded_class_names)}",
        "created_slots": total_created,
        "skipped_existing": total_skipped,
        "total_slots": len(classes_to_seed) * 42,
        "classes": seeded_class_names,
        "is_temporary_dev": True
    }

