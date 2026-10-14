import os
import secrets
import string
import uuid
import json
from typing import List, Optional
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload, selectinload
from app.core.config import settings
from app.core.database import get_db
from app.core.security import get_password_hash, verify_password
from app.core.datetime_utils import normalize_utc_datetime
from app.models.user import User, Faculty, UserRole, PasswordChangeScope, PasswordChangeWindow, AdminSupportSession
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry, assignment_authorized_faculty
from app.models.student import Student
from app.models.attendance import ClassSession, AttendanceRecord, FaceEmbedding
from app.models.audit import AuditLog
from app.schemas.user import (
    FacultyCreate, FacultyUpdate, FacultyOut, FacultyAdminUpdate,
    PasswordResetRequest, PasswordResetResponse,
    CapacityStatsOut, CapacityItem,
    UserAdminOut, UserAdminUpdate
)
from app.schemas.student import (
    StudentCreate, StudentCreateWithAuth, StudentUpdate, StudentAdminUpdate,
    StudentOut, StudentPasswordResetRequest, StudentPasswordResetResponse
)
from app.schemas.academic import (
    ClassSectionCreate, ClassSectionUpdate, ClassSectionOut, ClassAdvisorAssignRequest,
    SubjectCreate, SubjectUpdate, SubjectOut,
    PeriodCreate, PeriodOut,
    FacultyAssignmentCreate, FacultyAssignmentUpdate, FacultyAssignmentOut,
    TimetableEntryCreate, TimetableEntryUpdate,
    TimetableMoveRequest, TimetableDuplicateRequest,
    TimetableEntryOut
)
from app.schemas.password_control import (
    PasswordChangeWindowCreate, PasswordChangeWindowUpdate,
    PasswordChangeWindowOut, PasswordControlStatsOut
)
from app.schemas.admin_support import (
    SupportSessionStartRequest, SupportSessionOut,
    SupportSessionEndResponse, SupportSessionActionRequest
)
from app.api.deps import require_admin
from app.services.college_importer import seed_temporary_dev_timetable

router = APIRouter(prefix="/admin", tags=["Admin Operations"], dependencies=[Depends(require_admin)])

def _is_dev_faculty_account(emp_id: Optional[str], username: Optional[str] = None) -> bool:
    """
    Evaluates whether a faculty account is an isolated test/development account.
    Official college faculty (FAC01-FAC08) are authoritative official faculty and return False.
    Only returns True if explicitly configured via DEV_FACULTY_EMP_IDS env var
    or having explicit test prefixes (DEV-, TEST-).
    """
    env_ids = set(filter(None, [x.strip() for x in os.getenv("DEV_FACULTY_EMP_IDS", "").split(",")]))
    if emp_id and emp_id in env_ids:
        return True
    if username and username in env_ids:
        return True
    emp_upper = (emp_id or "").upper()
    user_upper = (username or "").upper()
    return emp_upper.startswith("DEV-") or emp_upper.startswith("TEST-") or user_upper.startswith("DEV_") or user_upper.startswith("TEST_")



def _generate_temporary_password(length: int = 8) -> str:
    """Generates a cryptographically secure random temporary password of exactly `length` chars (default 8).
    Guarantees at least 1 uppercase, 1 lowercase, 1 digit, and 1 safe symbol.
    """
    safe_symbols = "!@#$%^&*"
    chars = string.ascii_letters + string.digits + safe_symbols
    pwd = [
        secrets.choice(string.ascii_uppercase),
        secrets.choice(string.ascii_lowercase),
        secrets.choice(string.digits),
        secrets.choice(safe_symbols)
    ]
    if length > 4:
        pwd += [secrets.choice(chars) for _ in range(length - 4)]
    elif length < 4:
        pwd = pwd[:length]
    secrets.SystemRandom().shuffle(pwd)
    return "".join(pwd[:length])


def _add_audit(db: Session, actor_user_id: int, action: str, details: str, target: Optional[str] = None):
    log = AuditLog(user_id=actor_user_id, action=action, target=target, details=details)
    db.add(log)


# ==========================================
# CAPACITY & STATS
# ==========================================

@router.get("/capacity-stats", response_model=CapacityStatsOut)
def get_capacity_stats(db: Session = Depends(get_db)):
    """Returns real-time capacity statistics for Students and Faculty."""
    student_count = db.query(Student).count()
    faculty_count = db.query(Faculty).count()
    return CapacityStatsOut(
        students=CapacityItem(
            current=student_count,
            max=settings.MAX_STUDENTS,
            remaining=max(0, settings.MAX_STUDENTS - student_count)
        ),
        faculty=CapacityItem(
            current=faculty_count,
            max=settings.MAX_FACULTY,
            remaining=max(0, settings.MAX_FACULTY - faculty_count)
        )
    )


# ==========================================
# FACULTY MANAGEMENT
# ==========================================

@router.get("/faculty", response_model=List[FacultyOut])
def list_faculty(
    response: Response,
    search: Optional[str] = None,
    department: Optional[str] = None,
    is_active: Optional[bool] = None,
    skip: int = Query(0, ge=0),
    limit: Optional[int] = Query(None, ge=1, le=10000),
    db: Session = Depends(get_db)
):
    query = db.query(Faculty).join(User, Faculty.user_id == User.id).options(
        joinedload(Faculty.user)
    )
    
    if search:
        s = f"%{search.strip()}%"
        query = query.filter(
            (Faculty.full_name.ilike(s)) |
            (Faculty.employee_id.ilike(s)) |
            (User.username.ilike(s)) |
            (User.email.ilike(s))
        )
    if department:
        query = query.filter(Faculty.department == department)
    if is_active is not None:
        query = query.filter(User.is_active == is_active)

    total_count = query.count()
    if response:
        response.headers["X-Total-Count"] = str(total_count)
    if skip > 0:
        query = query.offset(skip)
    if limit is not None:
        query = query.limit(limit)

    faculties = query.all()
    result = []
    for f in faculties:
        locked_until = normalize_utc_datetime(f.user.locked_until)
        is_locked = bool(
            locked_until and locked_until > datetime.now(timezone.utc)
        )
        is_dev = _is_dev_faculty_account(f.employee_id, f.user.username if f.user else None)
        result.append(FacultyOut(
            id=f.id,
            user_id=f.user_id,
            employee_id=f.employee_id,
            full_name=f.full_name,
            department=f.department,
            phone=f.phone,
            username=f.user.username,
            email=f.user.email,
            is_active=f.user.is_active,
            force_password_change=f.user.force_password_change or False,
            is_locked=is_locked,
            is_dev_account=is_dev,
            password_changed_at=f.user.password_changed_at.isoformat() if f.user and f.user.password_changed_at else None,
        ))
    return result


@router.post("/faculty", response_model=FacultyOut, status_code=status.HTTP_201_CREATED)
def create_faculty(
    data: FacultyCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    # 1. Capacity check: MAX_FACULTY = 15
    current_faculty_count = db.query(Faculty).count()
    if current_faculty_count >= settings.MAX_FACULTY:
        raise HTTPException(
            status_code=400,
            detail=f"Maximum faculty capacity of {settings.MAX_FACULTY} has been reached."
        )

    # 2. Uniqueness checks
    if db.query(User).filter(User.username == data.username).first():
        raise HTTPException(status_code=400, detail="Username already exists")
    if data.email and db.query(User).filter(User.email == data.email).first():
        raise HTTPException(status_code=400, detail="Email already exists")
    if db.query(Faculty).filter(Faculty.employee_id == data.employee_id).first():
        raise HTTPException(status_code=400, detail="Employee ID already exists")

    # 3. Password handling
    raw_pw = data.password
    temp_pw_returned = None
    force_pw = data.force_password_change
    if not raw_pw or data.generate_temporary:
        raw_pw = _generate_temporary_password()
        temp_pw_returned = raw_pw
        force_pw = True

    hashed_pw = get_password_hash(raw_pw)
    user = User(
        username=data.username,
        email=data.email,
        hashed_password=hashed_pw,
        role=UserRole.FACULTY,
        is_active=data.is_active,
        force_password_change=force_pw,
        login_identifier=data.employee_id,
    )
    db.add(user)
    db.flush()

    faculty = Faculty(
        user_id=user.id,
        employee_id=data.employee_id,
        full_name=data.full_name,
        department=data.department,
        phone=data.phone,
    )
    db.add(faculty)
    db.flush()

    _add_audit(db, current_user.id, "CREATE_FACULTY",
               f"Created faculty: {data.full_name} (employee_id={data.employee_id}, username={data.username})")
    db.commit()
    db.refresh(faculty)

    is_dev = _is_dev_faculty_account(faculty.employee_id, user.username)
    return FacultyOut(
        id=faculty.id,
        user_id=faculty.user_id,
        employee_id=faculty.employee_id,
        full_name=faculty.full_name,
        department=faculty.department,
        phone=faculty.phone,
        username=user.username,
        email=user.email,
        is_active=user.is_active,
        force_password_change=user.force_password_change or False,
        is_locked=False,
        is_dev_account=is_dev,
        password_changed_at=user.password_changed_at.isoformat() if user.password_changed_at else None,
        temporary_password=temp_pw_returned
    )


@router.put("/faculty/{faculty_id}", response_model=FacultyOut)
def update_faculty(
    faculty_id: int,
    data: FacultyUpdate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    faculty = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")
    user = db.query(User).filter(User.id == faculty.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Faculty user account not found")

    changes = []

    # 1. Employee ID update with duplicate validation
    if data.employee_id and data.employee_id.strip() != faculty.employee_id:
        new_emp_id = data.employee_id.strip()
        existing_emp = db.query(Faculty).filter(func.lower(Faculty.employee_id) == new_emp_id.lower(), Faculty.id != faculty_id).first()
        if existing_emp:
            raise HTTPException(status_code=400, detail=f"Faculty ID / Employee ID '{new_emp_id}' already exists")
        changes.append(f"employee_id: {faculty.employee_id} -> {new_emp_id}")
        faculty.employee_id = new_emp_id
        user.login_identifier = new_emp_id

    # 2. Username update with duplicate validation
    if data.username and data.username.strip() != user.username:
        new_user = data.username.strip()
        existing_user = db.query(User).filter(func.lower(User.username) == new_user.lower(), User.id != user.id).first()
        if existing_user:
            raise HTTPException(status_code=400, detail=f"Username '{new_user}' already exists")
        changes.append(f"username: {user.username} -> {new_user}")
        user.username = new_user

    # 3. Email update with duplicate validation
    if data.email is not None and data.email != user.email:
        existing = db.query(User).filter(User.email == data.email, User.id != user.id).first()
        if existing:
            raise HTTPException(status_code=400, detail="Email already exists")
        changes.append(f"email: {user.email} -> {data.email}")
        user.email = data.email

    # 4. Profile fields
    if data.full_name is not None and data.full_name != faculty.full_name:
        changes.append(f"name: {faculty.full_name} -> {data.full_name}")
        faculty.full_name = data.full_name
    if data.department is not None and data.department != faculty.department:
        changes.append(f"department: {faculty.department} -> {data.department}")
        faculty.department = data.department
    if data.phone is not None:
        faculty.phone = data.phone

    # 5. Role
    if data.role and data.role != user.role.value:
        try:
            user.role = UserRole(data.role.upper())
            changes.append(f"role -> {user.role.value}")
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid role '{data.role}'")

    # 6. Password reset / update
    pw_to_set = data.new_password or data.password
    if pw_to_set:
        user.hashed_password = get_password_hash(pw_to_set)
        user.session_token = None
        user.failed_login_attempts = 0
        user.locked_until = None
        changes.append("password_reset")

    # 7. Force password change
    if data.force_password_change is not None and data.force_password_change != user.force_password_change:
        user.force_password_change = data.force_password_change
        changes.append(f"force_password_change -> {data.force_password_change}")

    # 8. Account Active status
    if data.is_active is not None and data.is_active != user.is_active:
        user.is_active = data.is_active
        if not data.is_active:
            user.session_token = None
        action = "ENABLE_FACULTY" if data.is_active else "DISABLE_FACULTY"
        _add_audit(db, current_user.id, action, f"Faculty ID {faculty_id} ({faculty.full_name})", target=faculty.employee_id)
        changes.append(f"is_active -> {data.is_active}")

    _add_audit(
        db, current_user.id, "FACULTY_UPDATED",
        f"Updated faculty #{faculty.id} ({faculty.full_name}): {', '.join(changes) if changes else 'no changes'}",
        target=f"Faculty {faculty.employee_id}"
    )
    db.commit()
    db.refresh(faculty)
    db.refresh(user)

    locked_until = normalize_utc_datetime(user.locked_until)
    is_locked = bool(
        locked_until and locked_until > datetime.now(timezone.utc)
    )
    is_dev = _is_dev_faculty_account(faculty.employee_id, user.username)
    return FacultyOut(
        id=faculty.id,
        user_id=faculty.user_id,
        employee_id=faculty.employee_id,
        full_name=faculty.full_name,
        department=faculty.department,
        phone=faculty.phone,
        username=user.username,
        email=user.email,
        is_active=user.is_active,
        force_password_change=user.force_password_change or False,
        is_locked=is_locked,
        is_dev_account=is_dev,
        password_changed_at=user.password_changed_at.isoformat() if user.password_changed_at else None,
    )


@router.post("/faculty/{faculty_id}/disable")
def disable_faculty(
    faculty_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    faculty = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")
    user = db.query(User).filter(User.id == faculty.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Faculty user account not found")

    user.is_active = False
    user.session_token = None
    _add_audit(db, current_user.id, "DISABLE_FACULTY", f"Disabled faculty: {faculty.full_name} (ID {faculty_id})")
    db.commit()
    return {"message": f"Faculty {faculty.full_name} disabled successfully", "faculty_id": faculty_id, "is_active": False}


@router.post("/faculty/{faculty_id}/enable")
def enable_faculty(
    faculty_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    faculty = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")
    user = db.query(User).filter(User.id == faculty.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Faculty user account not found")

    user.is_active = True
    _add_audit(db, current_user.id, "ENABLE_FACULTY", f"Enabled faculty: {faculty.full_name} (ID {faculty_id})")
    db.commit()
    return {"message": f"Faculty {faculty.full_name} enabled successfully", "faculty_id": faculty_id, "is_active": True}


@router.post("/faculty/{faculty_id}/toggle-active")
def toggle_faculty_active(
    faculty_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    faculty = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")
    user = db.query(User).filter(User.id == faculty.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Faculty user account not found")

    user.is_active = not user.is_active
    if not user.is_active:
        user.session_token = None
    action = "ENABLE_FACULTY" if user.is_active else "DISABLE_FACULTY"
    _add_audit(db, current_user.id, action, f"Faculty ID {faculty_id} ({faculty.full_name}) active status set to {user.is_active}")
    db.commit()
    return {"message": f"Faculty {'enabled' if user.is_active else 'disabled'} successfully", "faculty_id": faculty_id, "is_active": user.is_active}


@router.post("/faculty/{faculty_id}/reset-password", response_model=PasswordResetResponse)
def reset_faculty_password(
    faculty_id: int,
    data: PasswordResetRequest,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Admin resets a faculty member's password. Generates temporary password or uses provided."""
    faculty = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")
    user = db.query(User).filter(User.id == faculty.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Faculty user account not found")

    raw_pw = data.new_password
    temp_pw_returned = None
    force_pw = data.force_password_change

    if not raw_pw or data.generate_temporary:
        raw_pw = _generate_temporary_password()
        temp_pw_returned = raw_pw
        force_pw = True

    user.hashed_password = get_password_hash(raw_pw)
    user.force_password_change = force_pw
    user.failed_login_attempts = 0
    user.locked_until = None
    user.session_token = None  # Invalidate active sessions
    user.password_changed_at = datetime.now(timezone.utc)

    _add_audit(db, current_user.id, "RESET_FACULTY_PASSWORD",
               f"Password reset for faculty ID {faculty_id} ({faculty.full_name})")
    db.commit()
    return PasswordResetResponse(
        message="Faculty password reset successfully",
        temporary_password=temp_pw_returned,
        force_password_change=force_pw
    )


@router.post("/faculty/{faculty_id}/force-password-change")
def force_faculty_password_change(
    faculty_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    faculty = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")
    user = db.query(User).filter(User.id == faculty.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Faculty user account not found")

    user.force_password_change = True
    _add_audit(db, current_user.id, "FORCE_PASSWORD_CHANGE_FACULTY", f"Forced password change for faculty {faculty.full_name} (ID {faculty_id})")
    db.commit()
    return {"message": "Force password change flag set for faculty", "faculty_id": faculty_id, "force_password_change": True}


@router.post("/faculty/{faculty_id}/toggle-lock")
def toggle_faculty_lock(
    faculty_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Admin locks or unlocks a faculty account."""
    faculty = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")
    user = db.query(User).filter(User.id == faculty.user_id).first()

    locked_until = normalize_utc_datetime(user.locked_until)
    is_currently_locked = bool(
        locked_until and locked_until > datetime.now(timezone.utc)
    )

    if is_currently_locked:
        user.locked_until = None
        user.failed_login_attempts = 0
        action_msg = "unlocked"
    else:
        user.locked_until = datetime(9999, 12, 31, tzinfo=timezone.utc)
        action_msg = "locked"

    _add_audit(db, current_user.id, f"{'LOCK' if action_msg == 'locked' else 'UNLOCK'}_FACULTY",
               f"Faculty {faculty.full_name} (ID {faculty_id}) account {action_msg}")
    db.commit()
    return {"message": f"Faculty account {action_msg}", "faculty_id": faculty_id}


@router.delete("/faculty/{faculty_id}")
def delete_faculty(
    faculty_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    faculty = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")

    # Referential integrity check
    sess_count = db.query(ClassSession).filter(ClassSession.faculty_id == faculty_id).count()
    if sess_count > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete faculty '{faculty.full_name}' because they are referenced by {sess_count} class session(s). Deactivate the account instead to preserve academic records."
        )

    as_count = db.query(FacultyAssignment).filter(FacultyAssignment.faculty_id == faculty_id).count()
    if as_count > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete faculty '{faculty.full_name}' because they have {as_count} active course assignment(s). Reassign or remove their course assignments first."
        )

    user = db.query(User).filter(User.id == faculty.user_id).first()
    _add_audit(db, current_user.id, "DELETE_FACULTY",
               f"Deleted faculty: {faculty.full_name} (ID {faculty_id}, Employee ID {faculty.employee_id})",
               target=faculty.employee_id)
    if user:
        db.delete(user)
    else:
        db.delete(faculty)
    db.commit()
    return {"message": "Faculty deleted successfully", "faculty_id": faculty_id}


# ==========================================
# STUDENT MANAGEMENT
# ==========================================

@router.get("/students", response_model=List[StudentOut])
def list_students(
    response: Response,
    search: Optional[str] = None,
    class_id: Optional[int] = None,
    is_active: Optional[bool] = None,
    skip: int = Query(0, ge=0),
    limit: Optional[int] = Query(None, ge=1, le=10000),
    db: Session = Depends(get_db)
):
    query = db.query(Student).options(
        joinedload(Student.user),
        joinedload(Student.class_section),
        selectinload(Student.face_embeddings)
    )

    if search:
        s = f"%{search.strip()}%"
        query = query.filter(
            (Student.full_name.ilike(s)) |
            (Student.roll_number.ilike(s)) |
            (Student.email.ilike(s))
        )
    if class_id is not None:
        query = query.filter(Student.class_id == class_id)
    if is_active is not None:
        query = query.filter(Student.is_active == is_active)

    total_count = query.count()
    if response:
        response.headers["X-Total-Count"] = str(total_count)
    if skip > 0:
        query = query.offset(skip)
    if limit is not None:
        query = query.limit(limit)

    students = query.all()
    result = []
    for s in students:
        class_name = s.class_section.name if s.class_section else None
        force_pw = False
        is_locked = False
        if s.user:
            force_pw = s.user.force_password_change or False
            locked_until = normalize_utc_datetime(s.user.locked_until)
            is_locked = bool(
                locked_until and locked_until > datetime.now(timezone.utc)
            )

        embs = s.face_embeddings or []
        t_count = len(embs)
        is_enrolled = t_count >= 3
        last_enrolled = max([e.created_at for e in embs if e.created_at]).isoformat() if embs and any(e.created_at for e in embs) else None

        result.append(StudentOut(
            id=s.id,
            roll_number=s.roll_number,
            username=s.user.username if s.user else None,
            login_identifier=s.user.login_identifier if s.user else None,
            full_name=s.full_name,
            email=s.email,
            phone=s.phone,
            class_id=s.class_id,
            class_name=class_name,
            semester=s.semester,
            department=s.department,
            is_active=s.is_active,
            user_id=s.user_id,
            has_account=s.user_id is not None,
            force_password_change=force_pw,
            is_locked=is_locked,
            password_changed_at=s.user.password_changed_at.isoformat() if s.user and s.user.password_changed_at else None,
            is_enrolled=is_enrolled,
            template_count=t_count,
            last_enrollment_at=last_enrolled,
        ))
    return result


@router.post("/students", response_model=StudentOut, status_code=status.HTTP_201_CREATED)
def create_student(
    data: StudentCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Creates a student record with server-side capacity check (MAX_STUDENTS=130)."""
    # 1. Capacity check: MAX_STUDENTS = 130
    current_student_count = db.query(Student).count()
    if current_student_count >= settings.MAX_STUDENTS:
        raise HTTPException(
            status_code=400,
            detail=f"Maximum student capacity of {settings.MAX_STUDENTS} has been reached."
        )

    # 2. Uniqueness checks
    if db.query(Student).filter(Student.roll_number == data.roll_number).first():
        raise HTTPException(status_code=400, detail="Roll number already exists")
    if db.query(User).filter(User.username == data.roll_number).first():
        raise HTTPException(status_code=400, detail="Username (roll number) already exists as user account")
    if data.email and db.query(User).filter(User.email == data.email).first():
        raise HTTPException(status_code=400, detail="Email already exists")

    # 3. Class validation
    if data.class_id:
        cs = db.query(ClassSection).filter(ClassSection.id == data.class_id).first()
        if not cs:
            raise HTTPException(status_code=400, detail=f"Class section ID {data.class_id} does not exist")

    # 4. Password handling & user account creation
    raw_pw = data.password
    temp_pw_returned = None
    force_pw = data.force_password_change

    if not raw_pw or data.generate_temporary:
        raw_pw = _generate_temporary_password()
        temp_pw_returned = raw_pw
        force_pw = True

    hashed_pw = get_password_hash(raw_pw)
    user = User(
        username=data.roll_number,
        email=data.email,
        hashed_password=hashed_pw,
        role=UserRole.STUDENT,
        is_active=data.is_active,
        force_password_change=force_pw,
        login_identifier=data.roll_number,
    )
    db.add(user)
    db.flush()

    student = Student(
        user_id=user.id,
        roll_number=data.roll_number,
        full_name=data.full_name,
        email=data.email,
        phone=data.phone,
        class_id=data.class_id,
        semester=data.semester,
        department=data.department,
        is_active=data.is_active,
    )
    db.add(student)
    db.flush()

    _add_audit(db, current_user.id, "CREATE_STUDENT",
               f"Created student: {data.full_name} (roll={data.roll_number})")
    db.commit()
    db.refresh(student)

    class_name = student.class_section.name if student.class_section else None
    return StudentOut(
        id=student.id,
        roll_number=student.roll_number,
        full_name=student.full_name,
        email=student.email,
        phone=student.phone,
        class_id=student.class_id,
        class_name=class_name,
        semester=student.semester,
        department=student.department,
        is_active=student.is_active,
        user_id=user.id,
        has_account=True,
        force_password_change=user.force_password_change,
        is_locked=False,
        password_changed_at=user.password_changed_at.isoformat() if user.password_changed_at else None,
        temporary_password=temp_pw_returned
    )


@router.post("/students/with-account", response_model=StudentOut, status_code=status.HTTP_201_CREATED)
def create_student_with_account(
    data: StudentCreateWithAuth,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Creates a student record AND a linked login account (enforcing MAX_STUDENTS=130)."""
    # Reuse single-creation flow with capacity check
    return create_student(
        StudentCreate(
            roll_number=data.roll_number,
            full_name=data.full_name,
            email=data.email,
            phone=data.phone,
            class_id=data.class_id,
            semester=data.semester,
            department=data.department,
            password=data.password,
            generate_temporary=data.generate_temporary,
            force_password_change=data.force_password_change,
            is_active=data.is_active
        ),
        current_user=current_user,
        db=db
    )


@router.put("/students/{student_id}", response_model=StudentOut)
def update_student(
    student_id: int,
    data: StudentAdminUpdate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    user = None
    if student.user_id:
        user = db.query(User).filter(User.id == student.user_id).first()

    changes = []

    # 1. Roll number update with duplicate validation
    if data.roll_number and data.roll_number.strip() != student.roll_number:
        new_roll = data.roll_number.strip()
        existing_st = db.query(Student).filter(
            func.lower(Student.roll_number) == new_roll.lower(),
            Student.id != student_id
        ).first()
        if existing_st:
            raise HTTPException(status_code=400, detail=f"Roll number '{new_roll}' already exists")
        changes.append(f"roll_number: {student.roll_number} -> {new_roll}")
        student.roll_number = new_roll
        if user:
            user.login_identifier = new_roll

    # 2. Username update with duplicate validation
    if data.username and user and data.username.strip() != user.username:
        new_u = data.username.strip()
        existing_u = db.query(User).filter(
            func.lower(User.username) == new_u.lower(),
            User.id != user.id
        ).first()
        if existing_u:
            raise HTTPException(status_code=400, detail=f"Username '{new_u}' already exists")
        changes.append(f"username: {user.username} -> {new_u}")
        user.username = new_u

    # 3. Email update with duplicate validation
    if data.email is not None and data.email != student.email:
        if user:
            existing = db.query(User).filter(User.email == data.email, User.id != user.id).first()
            if existing:
                raise HTTPException(status_code=400, detail="Email already exists")
            user.email = data.email
        changes.append(f"email: {student.email} -> {data.email}")
        student.email = data.email

    # 4. Class Section update
    if data.class_id is not None and data.class_id != student.class_id:
        cs = db.query(ClassSection).filter(ClassSection.id == data.class_id).first()
        if not cs:
            raise HTTPException(status_code=400, detail=f"Class section ID {data.class_id} does not exist")
        changes.append(f"class_id: {student.class_id} -> {data.class_id} ({cs.name})")
        student.class_id = data.class_id
        _add_audit(db, current_user.id, "CHANGE_STUDENT_CLASS",
                   f"Student {student.full_name} moved to class_id={data.class_id} ({cs.name})",
                   target=student.roll_number)

    # 5. Profile fields
    if data.full_name is not None and data.full_name != student.full_name:
        changes.append(f"name: {student.full_name} -> {data.full_name}")
        student.full_name = data.full_name
    if data.phone is not None:
        student.phone = data.phone
    if data.semester is not None and data.semester != student.semester:
        changes.append(f"semester: {student.semester} -> {data.semester}")
        student.semester = data.semester
    if data.department is not None and data.department != student.department:
        changes.append(f"department: {student.department} -> {data.department}")
        student.department = data.department

    # 6. Password reset / update
    if data.new_password and user:
        user.hashed_password = get_password_hash(data.new_password)
        user.session_token = None
        user.failed_login_attempts = 0
        user.locked_until = None
        user.password_changed_at = datetime.now(timezone.utc)
        changes.append("password_reset")

    # 7. Force password change
    if data.force_password_change is not None and user and data.force_password_change != user.force_password_change:
        user.force_password_change = data.force_password_change
        changes.append(f"force_password_change -> {data.force_password_change}")

    # 8. Active status
    if data.is_active is not None and data.is_active != student.is_active:
        student.is_active = data.is_active
        if user:
            user.is_active = data.is_active
            if not data.is_active:
                user.session_token = None
        action = "ENABLE_STUDENT" if data.is_active else "DISABLE_STUDENT"
        _add_audit(db, current_user.id, action, f"Student ID {student_id} ({student.full_name})", target=student.roll_number)
        changes.append(f"is_active -> {data.is_active}")

    _add_audit(
        db, current_user.id, "UPDATE_STUDENT",
        f"Updated student #{student.id} ({student.full_name}): {', '.join(changes) if changes else 'no changes'}",
        target=student.roll_number
    )
    db.commit()
    db.refresh(student)
    if user:
        db.refresh(user)

    class_name = student.class_section.name if student.class_section else None
    force_pw = False
    is_locked = False
    if user:
        force_pw = user.force_password_change or False
        locked_until = normalize_utc_datetime(user.locked_until)
        is_locked = bool(
            locked_until and locked_until > datetime.now(timezone.utc)
        )

    embs = student.face_embeddings or []
    t_count = len(embs)
    is_enrolled = t_count >= 3
    last_enrolled = max([e.created_at for e in embs if e.created_at]).isoformat() if embs and any(e.created_at for e in embs) else None

    return StudentOut(
        id=student.id,
        roll_number=student.roll_number,
        username=user.username if user else None,
        login_identifier=user.login_identifier if user else None,
        full_name=student.full_name,
        email=student.email,
        phone=student.phone,
        class_id=student.class_id,
        class_name=class_name,
        semester=student.semester,
        department=student.department,
        is_active=student.is_active,
        user_id=student.user_id,
        has_account=student.user_id is not None,
        force_password_change=force_pw,
        is_locked=is_locked,
        password_changed_at=user.password_changed_at.isoformat() if user and user.password_changed_at else None,
        is_enrolled=is_enrolled,
        template_count=t_count,
        last_enrollment_at=last_enrolled,
    )


@router.post("/students/{student_id}/disable")
def disable_student(
    student_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    student.is_active = False
    if student.user_id:
        user = db.query(User).filter(User.id == student.user_id).first()
        if user:
            user.is_active = False
            user.session_token = None

    _add_audit(db, current_user.id, "DISABLE_STUDENT", f"Disabled student: {student.full_name} (ID {student_id})")
    db.commit()
    return {"message": f"Student {student.full_name} disabled successfully", "student_id": student_id, "is_active": False}


@router.post("/students/{student_id}/enable")
def enable_student(
    student_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    student.is_active = True
    if student.user_id:
        user = db.query(User).filter(User.id == student.user_id).first()
        if user:
            user.is_active = True

    _add_audit(db, current_user.id, "ENABLE_STUDENT", f"Enabled student: {student.full_name} (ID {student_id})")
    db.commit()
    return {"message": f"Student {student.full_name} enabled successfully", "student_id": student_id, "is_active": True}


@router.post("/students/{student_id}/toggle-active")
def toggle_student_active(
    student_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    student.is_active = not student.is_active
    if student.user_id:
        user = db.query(User).filter(User.id == student.user_id).first()
        if user:
            user.is_active = student.is_active
            if not student.is_active:
                user.session_token = None

    action = "ENABLE_STUDENT" if student.is_active else "DISABLE_STUDENT"
    _add_audit(db, current_user.id, action, f"Student ID {student_id} ({student.full_name}) active status set to {student.is_active}")
    db.commit()
    return {"message": f"Student {'enabled' if student.is_active else 'disabled'} successfully", "student_id": student_id, "is_active": student.is_active}


@router.post("/students/{student_id}/reset-password", response_model=StudentPasswordResetResponse)
def reset_student_password(
    student_id: int,
    data: StudentPasswordResetRequest,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Admin resets a student's password. Password stored as bcrypt hash only."""
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    if not student.user_id:
        raise HTTPException(status_code=400, detail="Student has no login account. Create account first.")

    user = db.query(User).filter(User.id == student.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Student user account not found")

    raw_pw = data.new_password
    temp_pw_returned = None
    force_pw = data.force_password_change

    if not raw_pw or data.generate_temporary:
        raw_pw = _generate_temporary_password()
        temp_pw_returned = raw_pw
        force_pw = True

    user.hashed_password = get_password_hash(raw_pw)
    user.force_password_change = force_pw
    user.failed_login_attempts = 0
    user.locked_until = None
    user.session_token = None  # Invalidate active sessions
    user.password_changed_at = datetime.now(timezone.utc)

    _add_audit(db, current_user.id, "RESET_STUDENT_PASSWORD",
               f"Password reset for student {student.full_name} (ID {student_id})")
    db.commit()
    return StudentPasswordResetResponse(
        message="Student password reset successfully",
        temporary_password=temp_pw_returned,
        force_password_change=force_pw
    )


@router.post("/students/{student_id}/force-password-change")
def force_student_password_change(
    student_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    if not student.user_id:
        raise HTTPException(status_code=400, detail="Student has no login account")

    user = db.query(User).filter(User.id == student.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Student user account not found")

    user.force_password_change = True
    _add_audit(db, current_user.id, "FORCE_PASSWORD_CHANGE_STUDENT", f"Forced password change for student {student.full_name} (ID {student_id})")
    db.commit()
    return {"message": "Force password change flag set for student", "student_id": student_id, "force_password_change": True}


@router.post("/students/{student_id}/toggle-lock")
def toggle_student_lock(
    student_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Admin locks or unlocks a student account."""
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    if not student.user_id:
        raise HTTPException(status_code=400, detail="Student has no login account")

    user = db.query(User).filter(User.id == student.user_id).first()
    locked_until = normalize_utc_datetime(user.locked_until)
    is_currently_locked = bool(
        locked_until and locked_until > datetime.now(timezone.utc)
    )

    if is_currently_locked:
        user.locked_until = None
        user.failed_login_attempts = 0
        action_msg = "unlocked"
    else:
        user.locked_until = datetime(9999, 12, 31, tzinfo=timezone.utc)
        action_msg = "locked"

    _add_audit(db, current_user.id, f"{'LOCK' if action_msg == 'locked' else 'UNLOCK'}_STUDENT",
               f"Student {student.full_name} (ID {student_id}) account {action_msg}")
    db.commit()
    return {"message": f"Student account {action_msg}", "student_id": student_id}


@router.delete("/students/{student_id}")
def delete_student(
    student_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    # Referential integrity check: Attendance records
    att_count = db.query(AttendanceRecord).filter(AttendanceRecord.student_id == student_id).count()
    if att_count > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete student '{student.full_name}' ({student.roll_number}) because they have {att_count} active attendance record(s). Deactivate the student account instead to preserve academic records."
        )

    user = None
    if student.user_id:
        user = db.query(User).filter(User.id == student.user_id).first()

    _add_audit(db, current_user.id, "DELETE_STUDENT",
               f"Deleted student: {student.full_name} (ID {student_id}, Roll {student.roll_number})",
               target=student.roll_number)

    if user:
        db.delete(user)
    else:
        db.delete(student)
    db.commit()
    return {"message": "Student deleted successfully", "student_id": student_id}



# ==========================================
# CLASS/SECTION MANAGEMENT
# ==========================================

@router.get("/classes", response_model=List[ClassSectionOut])
def list_classes(db: Session = Depends(get_db)):
    classes = db.query(ClassSection).all()
    result = []
    for cs in classes:
        cnt = db.query(Student).filter(Student.class_id == cs.id).count()
        advisor_name = cs.class_advisor.full_name if cs.class_advisor else None
        advisor_emp_id = cs.class_advisor.employee_id if cs.class_advisor else None
        result.append(ClassSectionOut(
            id=cs.id,
            name=cs.name,
            grade_level=cs.grade_level,
            academic_year=cs.academic_year,
            student_count=cnt,
            class_advisor_id=cs.class_advisor_id,
            class_advisor_name=advisor_name,
            class_advisor_employee_id=advisor_emp_id,
        ))
    return result

@router.post("/classes", response_model=ClassSectionOut, status_code=status.HTTP_201_CREATED)
def create_class(
    data: ClassSectionCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    if db.query(ClassSection).filter(ClassSection.name == data.name).first():
        raise HTTPException(status_code=400, detail="Class name already exists")
    cs = ClassSection(name=data.name, grade_level=data.grade_level, academic_year=data.academic_year)
    db.add(cs)
    _add_audit(db, current_user.id, "CREATE_CLASS", f"Created class: {data.name}")
    db.commit()
    db.refresh(cs)
    return ClassSectionOut(
        id=cs.id,
        name=cs.name,
        grade_level=cs.grade_level,
        academic_year=cs.academic_year,
        student_count=0,
        class_advisor_id=None,
        class_advisor_name=None,
        class_advisor_employee_id=None,
    )

@router.post("/classes/{class_id}/advisor", response_model=ClassSectionOut)
def assign_class_advisor(
    class_id: int,
    data: ClassAdvisorAssignRequest,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    cs = db.query(ClassSection).filter(ClassSection.id == class_id).first()
    if not cs:
        raise HTTPException(status_code=404, detail="Class section not found")

    faculty = db.query(Faculty).filter(Faculty.id == data.faculty_id).first()
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty member not found")

    if not faculty.user or not faculty.user.is_active:
        raise HTTPException(status_code=400, detail="Cannot assign inactive faculty as Class Advisor")

    old_advisor_name = cs.class_advisor.full_name if cs.class_advisor else "None"
    cs.class_advisor_id = faculty.id

    _add_audit(
        db, current_user.id, "ASSIGN_CLASS_ADVISOR",
        f"Assigned faculty #{faculty.id} ({faculty.full_name}, {faculty.employee_id}) as Class Advisor for class '{cs.name}' (previous: {old_advisor_name})",
        target=cs.name
    )
    db.commit()
    db.refresh(cs)

    cnt = db.query(Student).filter(Student.class_id == cs.id).count()
    return ClassSectionOut(
        id=cs.id,
        name=cs.name,
        grade_level=cs.grade_level,
        academic_year=cs.academic_year,
        student_count=cnt,
        class_advisor_id=cs.class_advisor_id,
        class_advisor_name=faculty.full_name,
        class_advisor_employee_id=faculty.employee_id,
    )

@router.delete("/classes/{class_id}/advisor")
def remove_class_advisor(
    class_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    cs = db.query(ClassSection).filter(ClassSection.id == class_id).first()
    if not cs:
        raise HTTPException(status_code=404, detail="Class section not found")

    if not cs.class_advisor_id:
        return {"message": "No class advisor assigned to this class", "class_id": class_id}

    old_advisor_name = cs.class_advisor.full_name if cs.class_advisor else str(cs.class_advisor_id)
    cs.class_advisor_id = None

    _add_audit(
        db, current_user.id, "REMOVE_CLASS_ADVISOR",
        f"Removed Class Advisor ({old_advisor_name}) from class '{cs.name}'",
        target=cs.name
    )
    db.commit()
    return {"message": f"Class advisor removed from {cs.name} successfully", "class_id": class_id}

@router.delete("/classes/{class_id}")
def delete_class(
    class_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    cs = db.query(ClassSection).filter(ClassSection.id == class_id).first()
    if not cs:
        raise HTTPException(status_code=404, detail="Class not found")

    st_count = db.query(Student).filter(Student.class_id == class_id).count()
    if st_count > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete class '{cs.name}' because it contains {st_count} enrolled student(s). Reassign or remove students before deleting."
        )

    as_count = db.query(FacultyAssignment).filter(FacultyAssignment.class_id == class_id).count()
    if as_count > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete class '{cs.name}' because it has {as_count} course assignment(s). Remove assignments before deleting."
        )

    _add_audit(db, current_user.id, "DELETE_CLASS", f"Deleted class: {cs.name} (ID {class_id})", target=cs.name)
    db.delete(cs)
    db.commit()
    return {"message": "Class deleted successfully", "class_id": class_id}


# ==========================================
# SUBJECT MANAGEMENT
# ==========================================

@router.get("/subjects", response_model=List[SubjectOut])
def list_subjects(db: Session = Depends(get_db)):
    return db.query(Subject).all()

@router.post("/subjects", response_model=SubjectOut, status_code=status.HTTP_201_CREATED)
def create_subject(
    data: SubjectCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    code = data.code.strip() if data.code else ""
    name = data.name.strip() if data.name else ""
    description = data.description.strip() if (data.description and data.description.strip()) else None

    if not code:
        raise HTTPException(status_code=400, detail="Subject code cannot be empty")
    if not name:
        raise HTTPException(status_code=400, detail="Subject name cannot be empty")

    if db.query(Subject).filter(func.lower(Subject.code) == code.lower()).first():
        raise HTTPException(status_code=400, detail=f"Subject code '{code}' already exists")

    if db.query(Subject).filter(func.lower(Subject.name) == name.lower()).first():
        raise HTTPException(status_code=400, detail=f"Subject name '{name}' already exists")

    sub = Subject(code=code, name=name, description=description)
    db.add(sub)
    _add_audit(db, current_user.id, "CREATE_SUBJECT", f"Created subject: {code} - {name}")
    db.commit()
    db.refresh(sub)
    return sub

@router.delete("/subjects/{subject_id}")
def delete_subject(
    subject_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    sub = db.query(Subject).filter(Subject.id == subject_id).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subject not found")

    as_count = db.query(FacultyAssignment).filter(FacultyAssignment.subject_id == subject_id).count()
    if as_count > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete subject '{sub.name}' ({sub.code}) because it has {as_count} course assignment(s). Remove assignments before deleting."
        )

    _add_audit(db, current_user.id, "DELETE_SUBJECT", f"Deleted subject: {sub.code} ({sub.name})", target=sub.code)
    db.delete(sub)
    db.commit()
    return {"message": "Subject deleted successfully", "subject_id": subject_id}


# ==========================================
# PERIOD TIMINGS CONFIGURATION
# ==========================================

@router.get("/periods", response_model=List[PeriodOut])
def list_periods(db: Session = Depends(get_db)):
    return db.query(Period).order_by(Period.period_number.asc()).all()

@router.post("/periods", response_model=PeriodOut, status_code=status.HTTP_201_CREATED)
def create_period(
    data: PeriodCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    if db.query(Period).filter(Period.period_number == data.period_number).first():
        raise HTTPException(status_code=400, detail=f"Period number {data.period_number} already exists")
    if check_period_overlap(db, data.start_time, data.end_time):
        raise HTTPException(status_code=400, detail="Period timings overlap with an existing period")
    period = Period(period_number=data.period_number, name=data.name,
                    start_time=data.start_time, end_time=data.end_time)
    db.add(period)
    _add_audit(db, current_user.id, "CREATE_PERIOD", f"Created period {data.period_number}: {data.start_time}-{data.end_time}")
    db.commit()
    db.refresh(period)
    return period

@router.delete("/periods/{period_id}")
def delete_period(period_id: int, db: Session = Depends(get_db)):
    p = db.query(Period).filter(Period.id == period_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="Period not found")
    db.delete(p)
    db.commit()
    return {"message": "Period deleted successfully"}


# ==========================================
# FACULTY ASSIGNMENTS
# ==========================================

@router.get("/assignments", response_model=List[FacultyAssignmentOut])
def list_assignments(
    class_id: Optional[int] = None,
    subject_id: Optional[int] = None,
    faculty_id: Optional[int] = None,
    assigned: Optional[bool] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db)
):
    query = db.query(FacultyAssignment).join(
        ClassSection, FacultyAssignment.class_id == ClassSection.id
    ).join(
        Subject, FacultyAssignment.subject_id == Subject.id
    )

    if class_id is not None:
        query = query.filter(FacultyAssignment.class_id == class_id)
    if subject_id is not None:
        query = query.filter(FacultyAssignment.subject_id == subject_id)
    if faculty_id is not None:
        query = query.filter(
            (FacultyAssignment.faculty_id == faculty_id) |
            (FacultyAssignment.id.in_(
                db.query(assignment_authorized_faculty.c.assignment_id).filter(
                    assignment_authorized_faculty.c.faculty_id == faculty_id
                )
            ))
        )
    if assigned is not None:
        if assigned:
            query = query.filter(
                (FacultyAssignment.faculty_id != None) |
                (FacultyAssignment.id.in_(
                    db.query(assignment_authorized_faculty.c.assignment_id)
                ))
            )
        else:
            query = query.filter(
                (FacultyAssignment.faculty_id == None) &
                (~FacultyAssignment.id.in_(
                    db.query(assignment_authorized_faculty.c.assignment_id)
                ))
            )

    assignments = query.order_by(ClassSection.name.asc(), Subject.code.asc()).all()
    result = []
    search_lower = search.strip().lower() if search else None

    for a in assignments:
        auth_names = [f.full_name for f in a.all_authorized_faculty]
        auth_ids = [f.id for f in a.all_authorized_faculty]
        is_assn = bool(a.faculty_id is not None or (a.authorized_faculty and len(a.authorized_faculty) > 0))
        tt_count = len(a.timetable_entries)

        c_name = a.class_section.name if a.class_section else None
        s_code = a.subject.code if a.subject else None
        s_name = a.subject.name if a.subject else None
        f_name = a.display_faculty_name
        p_name = a.faculty.full_name if a.faculty else None

        if search_lower:
            text_corpus = f"{c_name or ''} {s_code or ''} {s_name or ''} {f_name or ''} {' '.join(auth_names)}".lower()
            if search_lower not in text_corpus:
                continue

        result.append(FacultyAssignmentOut(
            id=a.id,
            faculty_id=a.faculty_id,
            faculty_name=f_name,
            primary_faculty_name=p_name,
            authorized_faculty_names=auth_names,
            authorized_faculty_ids=auth_ids,
            subject_id=a.subject_id,
            subject_code=s_code,
            subject_name=s_name,
            class_id=a.class_id,
            class_name=c_name,
            is_assigned=is_assn,
            timetable_count=tt_count
        ))
    return result

@router.post("/assignments", response_model=FacultyAssignmentOut, status_code=status.HTTP_201_CREATED)
def create_assignment(
    data: FacultyAssignmentCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    # 1. Validate Class Section exists
    cs = db.query(ClassSection).filter(ClassSection.id == data.class_id).first()
    if not cs:
        raise HTTPException(status_code=404, detail=f"Class section ID {data.class_id} not found")

    # 2. Validate Subject exists
    sub = db.query(Subject).filter(Subject.id == data.subject_id).first()
    if not sub:
        raise HTTPException(status_code=404, detail=f"Subject ID {data.subject_id} not found")

    # 3. Validate Faculty if provided
    fac = None
    if data.faculty_id is not None:
        fac = db.query(Faculty).filter(Faculty.id == data.faculty_id).first()
        if not fac:
            raise HTTPException(status_code=404, detail=f"Faculty ID {data.faculty_id} not found")
        if fac.user and not fac.user.is_active:
            raise HTTPException(status_code=400, detail=f"Cannot assign inactive faculty member '{fac.full_name}'")

    # 4. Check for duplicate assignment (exact match on class, subject, faculty)
    exact_duplicate = db.query(FacultyAssignment).filter(
        FacultyAssignment.class_id == data.class_id,
        FacultyAssignment.subject_id == data.subject_id,
        FacultyAssignment.faculty_id == data.faculty_id
    ).first()

    if exact_duplicate:
        raise HTTPException(status_code=400, detail="Assignment already exists")

    # If there is an existing pending unassigned assignment for this class & subject, fill it
    unassigned_existing = db.query(FacultyAssignment).filter(
        FacultyAssignment.class_id == data.class_id,
        FacultyAssignment.subject_id == data.subject_id,
        FacultyAssignment.faculty_id == None
    ).first()

    if unassigned_existing:
        unassigned_existing.faculty_id = data.faculty_id
        if data.authorized_faculty_ids is not None:
            unassigned_existing.authorized_faculty = db.query(Faculty).filter(Faculty.id.in_(data.authorized_faculty_ids)).all()
        db.flush()
        _add_audit(db, current_user.id, "CREATE_FACULTY_ASSIGNMENT",
                   f"Assigned faculty {data.faculty_id} to subject {sub.code} for class {cs.name}")
        db.commit()
        db.refresh(unassigned_existing)
        assignment = unassigned_existing
    else:
        assignment = FacultyAssignment(
            faculty_id=data.faculty_id, subject_id=data.subject_id, class_id=data.class_id
        )
        if data.authorized_faculty_ids:
            auth_facs = db.query(Faculty).filter(Faculty.id.in_(data.authorized_faculty_ids)).all()
            assignment.authorized_faculty = auth_facs

        db.add(assignment)
        db.flush()
        _add_audit(db, current_user.id, "CREATE_FACULTY_ASSIGNMENT",
                   f"Assigned faculty {data.faculty_id} to subject {sub.code} for class {cs.name}")
        db.commit()
        db.refresh(assignment)

    auth_names = [f.full_name for f in assignment.all_authorized_faculty]
    auth_ids = [f.id for f in assignment.all_authorized_faculty]
    is_assn = bool(assignment.faculty_id is not None or (assignment.authorized_faculty and len(assignment.authorized_faculty) > 0))

    return FacultyAssignmentOut(
        id=assignment.id,
        faculty_id=assignment.faculty_id,
        faculty_name=assignment.display_faculty_name,
        primary_faculty_name=assignment.faculty.full_name if assignment.faculty else None,
        authorized_faculty_names=auth_names,
        authorized_faculty_ids=auth_ids,
        subject_id=assignment.subject_id,
        subject_code=assignment.subject.code if assignment.subject else None,
        subject_name=assignment.subject.name if assignment.subject else None,
        class_id=assignment.class_id,
        class_name=assignment.class_section.name if assignment.class_section else None,
        is_assigned=is_assn,
        timetable_count=len(assignment.timetable_entries)
    )

@router.put("/assignments/{assignment_id}", response_model=FacultyAssignmentOut)
def update_assignment(
    assignment_id: int,
    data: FacultyAssignmentCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    a = db.query(FacultyAssignment).filter(FacultyAssignment.id == assignment_id).first()
    if not a:
        raise HTTPException(status_code=404, detail="Assignment not found")

    # Validate Class Section
    cs = db.query(ClassSection).filter(ClassSection.id == data.class_id).first()
    if not cs:
        raise HTTPException(status_code=404, detail=f"Class section ID {data.class_id} not found")

    # Validate Subject
    sub = db.query(Subject).filter(Subject.id == data.subject_id).first()
    if not sub:
        raise HTTPException(status_code=404, detail=f"Subject ID {data.subject_id} not found")

    # Validate Faculty if provided
    fac = None
    if data.faculty_id is not None:
        fac = db.query(Faculty).filter(Faculty.id == data.faculty_id).first()
        if not fac:
            raise HTTPException(status_code=404, detail=f"Faculty ID {data.faculty_id} not found")
        if fac.user and not fac.user.is_active:
            raise HTTPException(status_code=400, detail=f"Cannot assign inactive faculty member '{fac.full_name}'")

    # Check for Duplicate with other records
    existing = db.query(FacultyAssignment).filter(
        FacultyAssignment.id != assignment_id,
        FacultyAssignment.faculty_id == data.faculty_id,
        FacultyAssignment.subject_id == data.subject_id,
        FacultyAssignment.class_id == data.class_id
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Another assignment with these exact parameters already exists")

    old_fac = a.display_faculty_name
    a.faculty_id = data.faculty_id
    a.subject_id = data.subject_id
    a.class_id = data.class_id
    if data.authorized_faculty_ids is not None:
        auth_facs = db.query(Faculty).filter(Faculty.id.in_(data.authorized_faculty_ids)).all()
        a.authorized_faculty = auth_facs

    db.flush()
    new_fac = a.display_faculty_name
    _add_audit(db, current_user.id, "UPDATE_FACULTY_ASSIGNMENT",
               f"Reassigned assignment ID {assignment_id} ({sub.code} in {cs.name}) from '{old_fac}' to '{new_fac}'")
    db.commit()
    db.refresh(a)

    auth_names = [f.full_name for f in a.all_authorized_faculty]
    auth_ids = [f.id for f in a.all_authorized_faculty]
    is_assn = bool(a.faculty_id is not None or (a.authorized_faculty and len(a.authorized_faculty) > 0))

    return FacultyAssignmentOut(
        id=a.id,
        faculty_id=a.faculty_id,
        faculty_name=a.display_faculty_name,
        primary_faculty_name=a.faculty.full_name if a.faculty else None,
        authorized_faculty_names=auth_names,
        authorized_faculty_ids=auth_ids,
        subject_id=a.subject_id,
        subject_code=a.subject.code if a.subject else None,
        subject_name=a.subject.name if a.subject else None,
        class_id=a.class_id,
        class_name=a.class_section.name if a.class_section else None,
        is_assigned=is_assn,
        timetable_count=len(a.timetable_entries)
    )

@router.delete("/assignments/{assignment_id}")
def delete_assignment(
    assignment_id: int,
    cascade: bool = Query(False),
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    a = db.query(FacultyAssignment).filter(FacultyAssignment.id == assignment_id).first()
    if not a:
        raise HTTPException(status_code=404, detail="Assignment not found")

    # Referential integrity safety check
    tt_entries = db.query(TimetableEntry).filter(TimetableEntry.assignment_id == assignment_id).all()
    if tt_entries:
        tt_ids = [tt.id for tt in tt_entries]
        sessions = db.query(ClassSession).filter(ClassSession.timetable_entry_id.in_(tt_ids)).all()
        if sessions:
            sess_ids = [s.id for s in sessions]
            att_count = db.query(AttendanceRecord).filter(AttendanceRecord.session_id.in_(sess_ids)).count()
            raise HTTPException(
                status_code=400,
                detail=f"Cannot delete assignment: {len(tt_entries)} timetable slot(s) and {len(sessions)} class session(s) ({att_count} attendance records) depend on it. Referential integrity prevents deleting active academic history. Please reassign faculty instead."
            )
        if not cascade:
            raise HTTPException(
                status_code=400,
                detail=f"Cannot delete assignment: {len(tt_entries)} timetable slot(s) depend on it. Set cascade=true to remove unreferenced timetable slots or reassign faculty instead."
            )
        # Cascade delete unreferenced timetable entries
        db.query(TimetableEntry).filter(TimetableEntry.assignment_id == assignment_id).delete(synchronize_session=False)

    cls_name = a.class_section.name if a.class_section else f"Class #{a.class_id}"
    sub_code = a.subject.code if a.subject else f"Sub #{a.subject_id}"
    _add_audit(db, current_user.id, "DELETE_FACULTY_ASSIGNMENT",
               f"Deleted assignment ID {assignment_id} ({sub_code} for {cls_name})")
    db.delete(a)
    db.commit()
    return {"message": "Assignment deleted successfully"}


# ==========================================
# TIMETABLE CONFIGURATION
# ==========================================

VALID_WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

def normalize_time_str(t_str: str) -> str:
    parts = t_str.strip().split(":")
    h = int(parts[0])
    m = int(parts[1]) if len(parts) > 1 else 0
    return f"{h:02d}:{m:02d}"

def do_periods_overlap(p1: Period, p2: Period) -> bool:
    if p1.id == p2.id or p1.period_number == p2.period_number:
        return True
    try:
        s1 = normalize_time_str(p1.start_time)
        e1 = normalize_time_str(p1.end_time)
        s2 = normalize_time_str(p2.start_time)
        e2 = normalize_time_str(p2.end_time)
        return max(s1, s2) < min(e1, e2)
    except Exception:
        return False

def check_timetable_conflicts(
    db: Session,
    day_of_week: str,
    period_id: int,
    class_id: int,
    faculty_id: Optional[int] = None,
    exclude_entry_id: Optional[int] = None
) -> None:
    """
    Validates timetable constraints before persisting changes:
    1. Period timing validity (start_time < end_time)
    2. Class slot collision (same class + same day + same or overlapping period)
    3. Faculty double-booking (same faculty + same day + same or overlapping period across any class section)
    """
    period = db.query(Period).filter(Period.id == period_id).first()
    if not period:
        raise HTTPException(status_code=404, detail=f"Period ID {period_id} not found")

    try:
        start_norm = normalize_time_str(period.start_time)
        end_norm = normalize_time_str(period.end_time)
        if start_norm >= end_norm:
            raise HTTPException(status_code=400, detail=f"Invalid period timing: start_time ({period.start_time}) must be before end_time ({period.end_time})")
    except HTTPException:
        raise
    except Exception:
        pass

    # 1. Class Slot Conflict: Same Class + Same Day + Same/Overlapping Period
    class_entries = (
        db.query(TimetableEntry)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
        .join(Period, TimetableEntry.period_id == Period.id)
        .filter(
            FacultyAssignment.class_id == class_id,
            TimetableEntry.day_of_week == day_of_week,
        )
    )
    if exclude_entry_id:
        class_entries = class_entries.filter(TimetableEntry.id != exclude_entry_id)

    for existing in class_entries.all():
        if existing.period_id == period_id or do_periods_overlap(period, existing.period):
            cs = existing.assignment.class_section if existing.assignment else None
            sub = existing.assignment.subject if existing.assignment else None
            c_name = cs.name if cs else f"Class #{class_id}"
            s_code = sub.code if sub else "Unknown Subject"
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Class slot conflict: '{c_name}' already has a timetable entry on {day_of_week} "
                    f"during Period {existing.period.period_number} ({existing.period.start_time}–{existing.period.end_time}) "
                    f"with subject '{s_code}'. Slot already occupied on {day_of_week} {period.name}."
                )
            )

    # 2. Faculty Double-Booking Conflict: Same Faculty + Same Day + Same/Overlapping Period across any class
    if faculty_id is not None:
        faculty_entries = (
            db.query(TimetableEntry)
            .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
            .join(Period, TimetableEntry.period_id == Period.id)
            .filter(
                FacultyAssignment.faculty_id == faculty_id,
                TimetableEntry.day_of_week == day_of_week,
            )
        )
        if exclude_entry_id:
            faculty_entries = faculty_entries.filter(TimetableEntry.id != exclude_entry_id)

        for existing in faculty_entries.all():
            if existing.period_id == period_id or do_periods_overlap(period, existing.period):
                fac = existing.assignment.faculty if existing.assignment else None
                fac_name = fac.full_name if fac else f"Faculty #{faculty_id}"
                emp_str = f" ({fac.employee_id})" if (fac and fac.employee_id) else ""
                cs = existing.assignment.class_section if existing.assignment else None
                c_name = cs.name if cs else f"Class #{existing.assignment.class_id}"
                sub = existing.assignment.subject if existing.assignment else None
                s_code = sub.code if sub else "Unknown Subject"
                raise HTTPException(
                    status_code=400,
                    detail=(
                        f"Timetable conflict: {fac_name}{emp_str} is already assigned to '{c_name}' "
                        f"({s_code}) on {day_of_week} during Period {existing.period.period_number} "
                        f"({existing.period.start_time}–{existing.period.end_time})."
                    )
                )

def _build_timetable_out(e: TimetableEntry) -> TimetableEntryOut:
    assign = e.assignment
    period = e.period
    fac_name = assign.display_faculty_name if assign else "Faculty assignment pending"
    auth_names = [f.full_name for f in assign.all_authorized_faculty] if assign else []

    return TimetableEntryOut(
        id=e.id,
        day_of_week=e.day_of_week,
        period_id=e.period_id,
        period_number=period.period_number if period else None,
        period_name=period.name if period else None,
        start_time=period.start_time if period else None,
        end_time=period.end_time if period else None,
        assignment_id=e.assignment_id,
        class_id=assign.class_id if assign else None,
        class_name=assign.class_section.name if assign and assign.class_section else None,
        subject_id=assign.subject_id if assign else None,
        subject_code=assign.subject.code if assign and assign.subject else None,
        subject_name=assign.subject.name if assign and assign.subject else None,
        faculty_id=assign.faculty_id if assign else None,
        faculty_name=fac_name,
        authorized_faculty_names=auth_names,
        room=e.room,
    )


@router.get("/timetable", response_model=List[TimetableEntryOut])
def list_timetable(
    class_id: Optional[int] = None,
    day_of_week: Optional[str] = None,
    period_id: Optional[int] = None,
    db: Session = Depends(get_db)
):
    query = (
        db.query(TimetableEntry)
        .join(Period, TimetableEntry.period_id == Period.id)
        .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
    )
    if class_id is not None:
        query = query.filter(FacultyAssignment.class_id == class_id)
    if day_of_week:
        query = query.filter(TimetableEntry.day_of_week.ilike(day_of_week.strip()))
    if period_id is not None:
        query = query.filter(TimetableEntry.period_id == period_id)

    entries = query.order_by(Period.period_number.asc()).all()
    return [_build_timetable_out(e) for e in entries]


@router.post("/timetable", response_model=TimetableEntryOut, status_code=status.HTTP_201_CREATED)
def create_timetable_entry(
    data: TimetableEntryCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    # 1. Validate Day of Week
    day = data.day_of_week.strip().capitalize()
    if day not in VALID_WEEKDAYS:
        raise HTTPException(status_code=400, detail=f"Invalid day of week '{data.day_of_week}'. Must be one of {VALID_WEEKDAYS}")

    # 2. Validate Period
    period = db.query(Period).filter(Period.id == data.period_id).first()
    if not period:
        raise HTTPException(status_code=404, detail=f"Period ID {data.period_id} not found")

    # 3. Resolve FacultyAssignment & Class
    if data.assignment_id:
        fa = db.query(FacultyAssignment).filter(FacultyAssignment.id == data.assignment_id).first()
        if not fa:
            raise HTTPException(status_code=404, detail=f"Faculty Assignment ID {data.assignment_id} not found")
        class_id = fa.class_id
    elif data.class_id and data.subject_id:
        cs = db.query(ClassSection).filter(ClassSection.id == data.class_id).first()
        if not cs:
            raise HTTPException(status_code=404, detail=f"Class section ID {data.class_id} not found")

        sub = db.query(Subject).filter(Subject.id == data.subject_id).first()
        if not sub:
            raise HTTPException(status_code=404, detail=f"Subject ID {data.subject_id} not found")

        fac_id = data.faculty_id
        if fac_id:
            fac = db.query(Faculty).filter(Faculty.id == fac_id).first()
            if not fac:
                raise HTTPException(status_code=404, detail=f"Faculty ID {fac_id} not found")
            if fac.user and not fac.user.is_active:
                raise HTTPException(status_code=400, detail=f"Cannot assign inactive faculty member '{fac.full_name}'")

        fa = db.query(FacultyAssignment).filter(
            FacultyAssignment.class_id == data.class_id,
            FacultyAssignment.subject_id == data.subject_id,
            FacultyAssignment.faculty_id == fac_id
        ).first()
        if not fa:
            fa = FacultyAssignment(
                class_id=data.class_id,
                subject_id=data.subject_id,
                faculty_id=fac_id
            )
            db.add(fa)
            db.flush()
        class_id = data.class_id
    else:
        raise HTTPException(status_code=400, detail="Either assignment_id or both class_id and subject_id must be provided")

    # 4. Check for Class and Faculty Conflicts
    check_timetable_conflicts(
        db=db,
        day_of_week=day,
        period_id=data.period_id,
        class_id=class_id,
        faculty_id=fa.faculty_id,
        exclude_entry_id=None
    )

    entry = TimetableEntry(
        day_of_week=day,
        period_id=data.period_id,
        assignment_id=fa.id,
        room=data.room
    )
    db.add(entry)
    db.flush()

    _add_audit(
        db, current_user.id, "CREATE_TIMETABLE_ENTRY",
        f"Created timetable entry #{entry.id}: class_id={class_id} ({fa.class_section.name if fa.class_section else ''}), "
        f"day={day}, period_id={data.period_id} (P{period.period_number}), subject={fa.subject.code if fa.subject else ''}, "
        f"faculty_id={fa.faculty_id}"
    )
    db.commit()
    db.refresh(entry)

    return _build_timetable_out(entry)


@router.put("/timetable/{entry_id}", response_model=TimetableEntryOut)
def update_timetable_entry(
    entry_id: int,
    data: TimetableEntryUpdate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    entry = db.query(TimetableEntry).filter(TimetableEntry.id == entry_id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Timetable entry not found")

    old_snapshot = (
        f"day={entry.day_of_week}, period_id={entry.period_id}, assignment_id={entry.assignment_id}, "
        f"class_id={entry.assignment.class_id if entry.assignment else None}, "
        f"subject_id={entry.assignment.subject_id if entry.assignment else None}, "
        f"faculty_id={entry.assignment.faculty_id if entry.assignment else None}, room={entry.room}"
    )

    # 1. Determine target day & period
    target_day = data.day_of_week.strip().capitalize() if data.day_of_week else entry.day_of_week
    if target_day not in VALID_WEEKDAYS:
        raise HTTPException(status_code=400, detail=f"Invalid day of week '{data.day_of_week}'")

    target_period_id = data.period_id if data.period_id is not None else entry.period_id
    period = db.query(Period).filter(Period.id == target_period_id).first()
    if not period:
        raise HTTPException(status_code=404, detail=f"Period ID {target_period_id} not found")

    # 2. Determine target Assignment
    if data.assignment_id:
        fa = db.query(FacultyAssignment).filter(FacultyAssignment.id == data.assignment_id).first()
        if not fa:
            raise HTTPException(status_code=404, detail=f"Faculty Assignment ID {data.assignment_id} not found")
        target_assignment_id = fa.id
        target_class_id = fa.class_id
        target_faculty_id = fa.faculty_id
    elif data.class_id is not None or data.subject_id is not None or data.faculty_id is not None:
        target_class_id = data.class_id if data.class_id is not None else entry.assignment.class_id
        target_subject_id = data.subject_id if data.subject_id is not None else entry.assignment.subject_id
        target_faculty_id = data.faculty_id if data.faculty_id is not None else entry.assignment.faculty_id

        cs = db.query(ClassSection).filter(ClassSection.id == target_class_id).first()
        if not cs:
            raise HTTPException(status_code=404, detail=f"Class section ID {target_class_id} not found")

        sub = db.query(Subject).filter(Subject.id == target_subject_id).first()
        if not sub:
            raise HTTPException(status_code=404, detail=f"Subject ID {target_subject_id} not found")

        if target_faculty_id:
            fac = db.query(Faculty).filter(Faculty.id == target_faculty_id).first()
            if not fac:
                raise HTTPException(status_code=404, detail=f"Faculty ID {target_faculty_id} not found")
            if fac.user and not fac.user.is_active:
                raise HTTPException(status_code=400, detail=f"Cannot assign inactive faculty member '{fac.full_name}'")

        fa = db.query(FacultyAssignment).filter(
            FacultyAssignment.class_id == target_class_id,
            FacultyAssignment.subject_id == target_subject_id,
            FacultyAssignment.faculty_id == target_faculty_id
        ).first()
        if not fa:
            fa = FacultyAssignment(
                class_id=target_class_id,
                subject_id=target_subject_id,
                faculty_id=target_faculty_id
            )
            db.add(fa)
            db.flush()
        target_assignment_id = fa.id
    else:
        target_assignment_id = entry.assignment_id
        target_class_id = entry.assignment.class_id
        target_faculty_id = entry.assignment.faculty_id

    # 3. Check for Class and Faculty Conflicts
    check_timetable_conflicts(
        db=db,
        day_of_week=target_day,
        period_id=target_period_id,
        class_id=target_class_id,
        faculty_id=target_faculty_id,
        exclude_entry_id=entry.id
    )

    entry.day_of_week = target_day
    entry.period_id = target_period_id
    entry.assignment_id = target_assignment_id
    if data.room is not None:
        entry.room = data.room

    new_snapshot = (
        f"day={entry.day_of_week}, period_id={entry.period_id}, assignment_id={entry.assignment_id}, "
        f"class_id={target_class_id}, room={entry.room}"
    )

    _add_audit(
        db, current_user.id, "UPDATE_TIMETABLE_ENTRY",
        f"Updated timetable entry #{entry_id}: old: [{old_snapshot}] -> new: [{new_snapshot}]"
    )
    db.commit()
    db.refresh(entry)

    return _build_timetable_out(entry)


@router.delete("/timetable/{entry_id}")
def delete_timetable_entry(
    entry_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    entry = db.query(TimetableEntry).filter(TimetableEntry.id == entry_id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Timetable entry not found")

    assign = entry.assignment
    _add_audit(
        db, current_user.id, "DELETE_TIMETABLE_ENTRY",
        f"Deleted timetable entry #{entry_id}: day={entry.day_of_week}, period_id={entry.period_id}, "
        f"class_name={assign.class_section.name if assign and assign.class_section else ''}, "
        f"subject={assign.subject.code if assign and assign.subject else ''}"
    )
    db.delete(entry)
    db.commit()
    return {"message": "Timetable entry deleted successfully", "deleted_id": entry_id}


@router.post("/timetable/{entry_id}/move", response_model=TimetableEntryOut)
def move_timetable_entry(
    entry_id: int,
    data: TimetableMoveRequest,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    entry = db.query(TimetableEntry).filter(TimetableEntry.id == entry_id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Timetable entry not found")

    target_day = data.target_day_of_week.strip().capitalize()
    if target_day not in VALID_WEEKDAYS:
        raise HTTPException(status_code=400, detail=f"Invalid target day of week '{data.target_day_of_week}'")

    period = db.query(Period).filter(Period.id == data.target_period_id).first()
    if not period:
        raise HTTPException(status_code=404, detail=f"Target period ID {data.target_period_id} not found")

    class_id = entry.assignment.class_id if entry.assignment else None
    faculty_id = entry.assignment.faculty_id if entry.assignment else None

    # Check Conflicts
    check_timetable_conflicts(
        db=db,
        day_of_week=target_day,
        period_id=data.target_period_id,
        class_id=class_id,
        faculty_id=faculty_id,
        exclude_entry_id=entry.id
    )

    old_slot = f"{entry.day_of_week} Period {entry.period_id}"
    entry.day_of_week = target_day
    entry.period_id = data.target_period_id

    _add_audit(
        db, current_user.id, "MOVE_TIMETABLE_ENTRY",
        f"Moved timetable entry #{entry_id} from [{old_slot}] to [{target_day} Period {data.target_period_id}]"
    )
    db.commit()
    db.refresh(entry)

    return _build_timetable_out(entry)


@router.post("/timetable/{entry_id}/duplicate", response_model=TimetableEntryOut, status_code=status.HTTP_201_CREATED)
def duplicate_timetable_entry(
    entry_id: int,
    data: TimetableDuplicateRequest,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    entry = db.query(TimetableEntry).filter(TimetableEntry.id == entry_id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Timetable entry not found")

    target_day = data.target_day_of_week.strip().capitalize()
    if target_day not in VALID_WEEKDAYS:
        raise HTTPException(status_code=400, detail=f"Invalid target day of week '{data.target_day_of_week}'")

    period = db.query(Period).filter(Period.id == data.target_period_id).first()
    if not period:
        raise HTTPException(status_code=404, detail=f"Target period ID {data.target_period_id} not found")

    class_id = entry.assignment.class_id if entry.assignment else None
    faculty_id = entry.assignment.faculty_id if entry.assignment else None

    # Check Conflicts
    check_timetable_conflicts(
        db=db,
        day_of_week=target_day,
        period_id=data.target_period_id,
        class_id=class_id,
        faculty_id=faculty_id,
        exclude_entry_id=None
    )

    new_entry = TimetableEntry(
        day_of_week=target_day,
        period_id=data.target_period_id,
        assignment_id=entry.assignment_id,
        room=entry.room
    )
    db.add(new_entry)
    db.flush()

    _add_audit(
        db, current_user.id, "DUPLICATE_TIMETABLE_ENTRY",
        f"Duplicated timetable entry #{entry_id} to new entry #{new_entry.id} on [{target_day} Period {data.target_period_id}]"
    )
    db.commit()
    db.refresh(new_entry)

    return _build_timetable_out(new_entry)


@router.post("/timetable/reset-dev")
def reset_dev_timetable(
    class_id: Optional[int] = None,
    class_name: Optional[str] = None,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Resets the timetable to the temporary development schedule dataset for Class 1, Class 2, or both.
    Logs audit event and ensures non-production status is preserved.
    """
    target_class_name = class_name
    if class_id is not None:
        cs = db.query(ClassSection).filter(ClassSection.id == class_id).first()
        if cs:
            target_class_name = cs.name

    res = seed_temporary_dev_timetable(db, class_name=target_class_name, force_reset=True)
    target_label = target_class_name if target_class_name else "all development classes"
    _add_audit(
        db, current_user.id, "RESET_DEV_TIMETABLE",
        f"Reset temporary development timetable for {target_label} (Created: {res['created_slots']}, Skipped: {res['skipped_existing']})"
    )
    db.commit()
    return res



# ==========================================
# ADMIN BULK IMPORT ENDPOINTS
# ==========================================

from app.services.college_importer import (
    import_students, import_faculty, import_subjects,
    import_class_sections, import_timetable, import_college_seed_bundle,
    ImportValidationError
)

@router.post("/import/students")
def admin_import_students(
    items: List[dict],
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    try:
        res = import_students(db, items)
        db.commit()
        _add_audit(db, current_user.id, "IMPORT_STUDENTS", f"Imported {res['imported']} students, skipped {res['skipped_existing']}")
        return {
            "message": f"Import complete: {res['imported']} imported, {res['skipped_existing']} skipped",
            "imported": res["imported"],
            "skipped_existing": res["skipped_existing"],
            "conflicts": 0,
            "errors": []
        }
    except ImportValidationError as e:
        raise HTTPException(status_code=400, detail={"message": e.message, "errors": e.errors})

@router.post("/import/faculty")
def admin_import_faculty(
    items: List[dict],
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    try:
        res = import_faculty(db, items)
        db.commit()
        _add_audit(db, current_user.id, "IMPORT_FACULTY", f"Imported {res['imported']} faculty, skipped {res['skipped_existing']}")
        return {
            "message": f"Import complete: {res['imported']} imported, {res['skipped_existing']} skipped",
            "imported": res["imported"],
            "skipped_existing": res["skipped_existing"],
            "conflicts": 0,
            "errors": []
        }
    except ImportValidationError as e:
        raise HTTPException(status_code=400, detail={"message": e.message, "errors": e.errors})

@router.post("/import/subjects")
def admin_import_subjects(
    items: List[dict],
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    try:
        res = import_subjects(db, items)
        db.commit()
        _add_audit(db, current_user.id, "IMPORT_SUBJECTS", f"Imported {res['imported']} subjects, skipped {res['skipped_existing']}")
        return {
            "message": f"Import complete: {res['imported']} imported, {res['skipped_existing']} skipped",
            "imported": res["imported"],
            "skipped_existing": res["skipped_existing"],
            "conflicts": 0,
            "errors": []
        }
    except ImportValidationError as e:
        raise HTTPException(status_code=400, detail={"message": e.message, "errors": e.errors})

@router.post("/import/classes")
def admin_import_classes(
    items: List[dict],
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    try:
        res = import_class_sections(db, items)
        db.commit()
        _add_audit(db, current_user.id, "IMPORT_CLASSES", f"Imported {res['imported']} class sections, skipped {res['skipped_existing']}")
        return {
            "message": f"Import complete: {res['imported']} imported, {res['skipped_existing']} skipped",
            "imported": res["imported"],
            "skipped_existing": res["skipped_existing"],
            "conflicts": 0,
            "errors": []
        }
    except ImportValidationError as e:
        raise HTTPException(status_code=400, detail={"message": e.message, "errors": e.errors})

@router.post("/import/timetable")
def admin_import_timetable(
    items: List[dict],
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    try:
        res = import_timetable(db, items)
        db.commit()
        _add_audit(db, current_user.id, "IMPORT_TIMETABLE", f"Imported {res['imported']} timetable entries, skipped {res['skipped_existing']}")
        return {
            "message": f"Import complete: {res['imported']} imported, {res['skipped_existing']} skipped",
            "imported": res["imported"],
            "skipped_existing": res["skipped_existing"],
            "conflicts": 0,
            "errors": []
        }
    except ImportValidationError as e:
        raise HTTPException(status_code=400, detail={"message": e.message, "errors": e.errors})

@router.post("/import/college-seed")
def admin_import_college_seed(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    try:
        results = import_college_seed_bundle(db, seed_dir="college_seed")
        _add_audit(db, current_user.id, "IMPORT_COLLEGE_SEED", f"Imported college seed bundle: {results}")
        return {"message": "Successfully imported college seed bundle", "results": results}
    except ImportValidationError as e:
        raise HTTPException(status_code=400, detail={"message": e.message, "errors": e.errors})


@router.post("/onboard/class1-students")
def admin_onboard_class1_students(
    dry_run: bool = False,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    from app.services.class1_onboarding_service import onboard_class1_students
    try:
        res = onboard_class1_students(db=db, admin_user_id=current_user.id, dry_run=dry_run)
        return res
    except ImportValidationError as e:
        raise HTTPException(status_code=400, detail={"message": e.message, "errors": e.errors})
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))



# ==========================================
# DASHBOARD & EXTENDED ADMIN MANAGEMENT
# ==========================================

from app.models.attendance import ClassSession, AttendanceRecord, AttendanceStatus, SessionStatus
from app.engines.policy_engine import get_active_policy
from app.engines.timetable_engine import get_ist_now
from app.core.datetime_utils import normalize_utc_datetime

@router.get("/dashboard-stats")
def get_dashboard_stats(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    today_str = get_ist_now().strftime("%Y-%m-%d")

    total_students = db.query(Student).count()
    total_faculty = db.query(Faculty).count()
    total_classes = db.query(ClassSection).count()
    total_subjects = db.query(Subject).count()
    total_timetable_entries = db.query(TimetableEntry).count()

    active_sessions = db.query(ClassSession).filter(ClassSession.status == SessionStatus.ACTIVE).count()
    today_sessions = db.query(ClassSession).filter(ClassSession.date == today_str).count()
    today_attendance = db.query(AttendanceRecord).join(ClassSession).filter(ClassSession.date == today_str).count()

    subq = db.query(FaceEmbedding.student_id).group_by(FaceEmbedding.student_id).having(func.count(FaceEmbedding.id) >= 3).subquery()
    biometric_enrolled = db.query(subq).count()

    total_users = db.query(User).count()
    active_users = db.query(User).filter(User.is_active == True).count()

    total_records = db.query(AttendanceRecord).count()
    present_count = db.query(AttendanceRecord).filter(AttendanceRecord.status == AttendanceStatus.PRESENT).count()
    absent_count = db.query(AttendanceRecord).filter(AttendanceRecord.status == AttendanceStatus.ABSENT).count()
    od_count = db.query(AttendanceRecord).filter(AttendanceRecord.status == AttendanceStatus.OD).count()

    # Reuse active AttendancePolicy
    policy = get_active_policy(db)
    overall_percentage = 0.0
    if total_records > 0:
        od_as_present = (getattr(policy, 'od_calculation_mode', 'COUNT_AS_PRESENT') == 'COUNT_AS_PRESENT') if policy else True
        overall_percentage = round(((present_count + (od_count if od_as_present else 0)) / total_records) * 100, 2)

    recent_logs = db.query(AuditLog).order_by(AuditLog.timestamp.desc()).limit(10).all()
    logs_data = [{
        "id": l.id,
        "timestamp": normalize_utc_datetime(l.timestamp).isoformat() if l.timestamp else "",
        "user_id": l.user_id,
        "action": l.action,
        "details": l.details
    } for l in recent_logs]

    return {
        "total_students": total_students,
        "total_faculty": total_faculty,
        "total_classes": total_classes,
        "total_subjects": total_subjects,
        "total_timetable_entries": total_timetable_entries,
        "active_sessions": active_sessions,
        "today_sessions": today_sessions,
        "today_attendance": today_attendance,
        "biometric_enrolled": biometric_enrolled,
        "total_users": total_users,
        "active_users": active_users,
        "attendance_stats": {
            "total_records": total_records,
            "present_count": present_count,
            "absent_count": absent_count,
            "od_count": od_count,
            "overall_percentage": overall_percentage,
            "minimum_required_percentage": policy.minimum_percentage
        },
        "recent_audit": logs_data
    }


@router.put("/classes/{class_id}", response_model=ClassSectionOut)
def update_class(
    class_id: int,
    data: ClassSectionCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    cs = db.query(ClassSection).filter(ClassSection.id == class_id).first()
    if not cs:
        raise HTTPException(status_code=404, detail="Class section not found")

    existing = db.query(ClassSection).filter(ClassSection.name == data.name, ClassSection.id != class_id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Class name already exists")

    cs.name = data.name
    cs.grade_level = data.grade_level
    cs.academic_year = data.academic_year

    _add_audit(db, current_user.id, "UPDATE_CLASS", f"Updated class ID {class_id} to name={data.name}")
    db.commit()
    db.refresh(cs)
    cnt = db.query(Student).filter(Student.class_id == cs.id).count()
    advisor_name = cs.class_advisor.full_name if cs.class_advisor else None
    advisor_emp_id = cs.class_advisor.employee_id if cs.class_advisor else None
    return ClassSectionOut(
        id=cs.id,
        name=cs.name,
        grade_level=cs.grade_level,
        academic_year=cs.academic_year,
        student_count=cnt,
        class_advisor_id=cs.class_advisor_id,
        class_advisor_name=advisor_name,
        class_advisor_employee_id=advisor_emp_id,
    )


@router.put("/subjects/{subject_id}", response_model=SubjectOut)
def update_subject(
    subject_id: int,
    data: SubjectCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    sub = db.query(Subject).filter(Subject.id == subject_id).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subject not found")

    code = data.code.strip() if data.code else ""
    name = data.name.strip() if data.name else ""
    description = data.description.strip() if (data.description and data.description.strip()) else None

    if not code:
        raise HTTPException(status_code=400, detail="Subject code cannot be empty")
    if not name:
        raise HTTPException(status_code=400, detail="Subject name cannot be empty")

    existing_code = db.query(Subject).filter(func.lower(Subject.code) == code.lower(), Subject.id != subject_id).first()
    if existing_code:
        raise HTTPException(status_code=400, detail=f"Subject code '{code}' already exists")

    existing_name = db.query(Subject).filter(func.lower(Subject.name) == name.lower(), Subject.id != subject_id).first()
    if existing_name:
        raise HTTPException(status_code=400, detail=f"Subject name '{name}' already exists")

    sub.code = code
    sub.name = name
    sub.description = description

    _add_audit(db, current_user.id, "UPDATE_SUBJECT", f"Updated subject ID {subject_id} to code={code}")
    db.commit()
    db.refresh(sub)
    return sub


from app.services.college_importer import normalize_time_value

def check_period_overlap(db: Session, start_time: str, end_time: str, exclude_id: Optional[int] = None) -> bool:
    norm_start = normalize_time_value(start_time)
    norm_end = normalize_time_value(end_time)

    query = db.query(Period)
    if exclude_id:
        query = query.filter(Period.id != exclude_id)

    for existing in query.all():
        ex_start = normalize_time_value(existing.start_time)
        ex_end = normalize_time_value(existing.end_time)
        # Overlap condition: max(start1, start2) < min(end1, end2)
        if norm_start < ex_end and ex_start < norm_end:
            return True
    return False


@router.put("/periods/{period_id}", response_model=PeriodOut)
def update_period(
    period_id: int,
    data: PeriodCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    p = db.query(Period).filter(Period.id == period_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="Period not found")

    existing_num = db.query(Period).filter(Period.period_number == data.period_number, Period.id != period_id).first()
    if existing_num:
        raise HTTPException(status_code=400, detail=f"Period number {data.period_number} already exists")

    if check_period_overlap(db, data.start_time, data.end_time, exclude_id=period_id):
        raise HTTPException(status_code=400, detail="Period timings overlap with an existing period")

    p.period_number = data.period_number
    p.name = data.name
    p.start_time = data.start_time
    p.end_time = data.end_time

    _add_audit(db, current_user.id, "UPDATE_PERIOD", f"Updated period {period_id} to number={data.period_number}")
    db.commit()
    db.refresh(p)
    return p


@router.post("/faculty/{faculty_id}/toggle-active")
def toggle_faculty_active(
    faculty_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    fac = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not fac or not fac.user:
        raise HTTPException(status_code=404, detail="Faculty not found")

    fac.user.is_active = not fac.user.is_active
    msg = "activated" if fac.user.is_active else "disabled"
    _add_audit(db, current_user.id, "TOGGLE_FACULTY_ACTIVE", f"{msg.capitalize()} faculty {fac.full_name} (User ID {fac.user_id})")
    db.commit()
    return {"message": f"Faculty account {msg} successfully", "is_active": fac.user.is_active}


@router.post("/faculty/{faculty_id}/force-password-change")
def force_faculty_password_change(
    faculty_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    fac = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not fac or not fac.user:
        raise HTTPException(status_code=404, detail="Faculty not found")

    fac.user.force_password_change = not (fac.user.force_password_change or False)
    msg = "enabled" if fac.user.force_password_change else "disabled"
    _add_audit(db, current_user.id, "FORCE_FACULTY_PASS_CHANGE", f"Force password change {msg} for faculty {fac.full_name}")
    db.commit()
    return {"message": f"Force password change {msg} successfully", "force_password_change": fac.user.force_password_change}


@router.post("/students/{student_id}/toggle-active")
def toggle_student_active(
    student_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    st = db.query(Student).filter(Student.id == student_id).first()
    if not st or not st.user:
        raise HTTPException(status_code=404, detail="Student not found")

    st.user.is_active = not st.user.is_active
    st.is_active = st.user.is_active
    msg = "activated" if st.user.is_active else "disabled"
    _add_audit(db, current_user.id, "TOGGLE_STUDENT_ACTIVE", f"{msg.capitalize()} student {st.full_name} (User ID {st.user_id})")
    db.commit()
    return {"message": f"Student account {msg} successfully", "is_active": st.user.is_active}


@router.post("/students/{student_id}/force-password-change")
def force_student_password_change(
    student_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    st = db.query(Student).filter(Student.id == student_id).first()
    if not st or not st.user:
        raise HTTPException(status_code=404, detail="Student not found")

    st.user.force_password_change = not (st.user.force_password_change or False)
    msg = "enabled" if st.user.force_password_change else "disabled"
    _add_audit(db, current_user.id, "FORCE_STUDENT_PASS_CHANGE", f"Force password change {msg} for student {st.full_name}")
    db.commit()
    return {"message": f"Force password change {msg} successfully", "force_password_change": st.user.force_password_change}


@router.get("/assignments/unassigned")
def list_unassigned_assignments(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    unassigned = db.query(FacultyAssignment).filter(
        FacultyAssignment.faculty_id == None
    ).all()
    # Exclude any with authorized co-faculty
    unassigned = [a for a in unassigned if not a.authorized_faculty]
    return [
        {
            "id": a.id,
            "assignment_id": a.id,
            "class_id": a.class_id,
            "class_name": a.class_section.name if a.class_section else f"Class #{a.class_id}",
            "subject_id": a.subject_id,
            "subject_code": a.subject.code if a.subject else f"Sub #{a.subject_id}",
            "subject_name": a.subject.name if a.subject else "-"
        }
        for a in unassigned
    ]


# ==========================================
# PASSWORD CHANGE CONTROL & WINDOWS
# ==========================================

def _apply_password_change_window(db: Session, window: PasswordChangeWindow):
    """Applies password change requirement to target users based on scope and active status."""
    if not window.is_active:
        return 0

    now = datetime.now(timezone.utc)
    start_at = normalize_utc_datetime(window.start_at)
    end_at = normalize_utc_datetime(window.end_at)
    if start_at and now < start_at:
        return 0
    if end_at and now > end_at:
        return 0

    if window.scope == PasswordChangeScope.ALL_STUDENTS:
        users = db.query(User).filter(User.role == UserRole.STUDENT, User.is_active == True).all()
        for u in users:
            u.force_password_change = True
            u.password_change_window_id = window.id
        return len(users)

    elif window.scope == PasswordChangeScope.ALL_FACULTY:
        users = db.query(User).filter(User.role == UserRole.FACULTY, User.is_active == True).all()
        for u in users:
            u.force_password_change = True
            u.password_change_window_id = window.id
        return len(users)

    elif window.scope == PasswordChangeScope.ALL_USERS:
        users = db.query(User).filter(User.role != UserRole.ADMIN, User.is_active == True).all()
        for u in users:
            u.force_password_change = True
            u.password_change_window_id = window.id
        return len(users)

    elif window.scope in (PasswordChangeScope.SELECTED_STUDENTS, PasswordChangeScope.SELECTED_FACULTY, PasswordChangeScope.SELECTED_ACCOUNTS):
        raw_ids = []
        if window.target_ids:
            try:
                parsed = json.loads(window.target_ids)
                if isinstance(parsed, list):
                    raw_ids = parsed
                else:
                    raw_ids = [parsed]
            except Exception:
                raw_ids = [int(x.strip()) for x in window.target_ids.split(",") if x.strip().isdigit()]

        if window.scope == PasswordChangeScope.SELECTED_STUDENTS:
            students = db.query(Student).filter(Student.id.in_(raw_ids)).all()
            count = 0
            for s in students:
                if s.user:
                    s.user.force_password_change = True
                    s.user.password_change_window_id = window.id
                    count += 1
            return count

        elif window.scope == PasswordChangeScope.SELECTED_FACULTY:
            faculties = db.query(Faculty).filter(Faculty.id.in_(raw_ids)).all()
            count = 0
            for f in faculties:
                if f.user:
                    f.user.force_password_change = True
                    f.user.password_change_window_id = window.id
                    count += 1
            return count

        elif window.scope == PasswordChangeScope.SELECTED_ACCOUNTS:
            users = db.query(User).filter(User.id.in_(raw_ids)).all()
            for u in users:
                u.force_password_change = True
                u.password_change_window_id = window.id
            return len(users)

    return 0


@router.get("/password-control/stats", response_model=PasswordControlStatsOut)
def get_password_control_stats(db: Session = Depends(get_db)):
    """Returns statistics for accounts requiring password change and active windows."""
    st_count = db.query(User).filter(User.role == UserRole.STUDENT, User.force_password_change == True).count()
    fac_count = db.query(User).filter(User.role == UserRole.FACULTY, User.force_password_change == True).count()
    active_win = db.query(PasswordChangeWindow).filter(PasswordChangeWindow.is_active == True).count()
    total_win = db.query(PasswordChangeWindow).count()

    return PasswordControlStatsOut(
        students_requiring_change=st_count,
        faculty_requiring_change=fac_count,
        total_requiring_change=st_count + fac_count,
        active_windows_count=active_win,
        total_windows_count=total_win
    )


@router.post("/password-change-window", response_model=PasswordChangeWindowOut, status_code=status.HTTP_201_CREATED)
def create_password_change_window(
    data: PasswordChangeWindowCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Creates a new password change window and applies forced password change to targeted scope."""
    target_ids_str = None
    if data.target_ids:
        if isinstance(data.target_ids, list):
            target_ids_str = json.dumps(data.target_ids)
        else:
            target_ids_str = str(data.target_ids)

    window = PasswordChangeWindow(
        title=data.title,
        scope=data.scope,
        target_ids=target_ids_str,
        start_at=data.start_at,
        end_at=data.end_at,
        is_active=data.is_active,
        created_by=current_user.id
    )
    db.add(window)
    db.flush()

    affected_count = _apply_password_change_window(db, window)
    action = "ENABLE_PASSWORD_CHANGE_WINDOW" if data.is_active else "CREATE_PASSWORD_CHANGE_WINDOW"
    _add_audit(db, current_user.id, action, f"Password change window created: '{window.title}' (Scope: {window.scope.value}, Affected: {affected_count})")
    db.commit()
    db.refresh(window)

    return PasswordChangeWindowOut(
        id=window.id,
        title=window.title,
        scope=window.scope,
        target_ids=window.target_ids,
        start_at=window.start_at,
        end_at=window.end_at,
        is_active=window.is_active,
        created_by=window.created_by,
        created_at=window.created_at,
        updated_at=window.updated_at,
        affected_users_count=affected_count
    )


@router.get("/password-change-window", response_model=List[PasswordChangeWindowOut])
def list_password_change_windows(db: Session = Depends(get_db)):
    """Lists all configured password change windows."""
    windows = db.query(PasswordChangeWindow).order_by(PasswordChangeWindow.created_at.desc()).all()
    result = []
    for w in windows:
        cnt = db.query(User).filter(User.password_change_window_id == w.id).count()
        result.append(PasswordChangeWindowOut(
            id=w.id,
            title=w.title,
            scope=w.scope,
            target_ids=w.target_ids,
            start_at=w.start_at,
            end_at=w.end_at,
            is_active=w.is_active,
            created_by=w.created_by,
            created_at=w.created_at,
            updated_at=w.updated_at,
            affected_users_count=cnt
        ))
    return result


@router.put("/password-change-window/{window_id}", response_model=PasswordChangeWindowOut)
def update_password_change_window(
    window_id: int,
    data: PasswordChangeWindowUpdate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Updates an existing password change window."""
    window = db.query(PasswordChangeWindow).filter(PasswordChangeWindow.id == window_id).first()
    if not window:
        raise HTTPException(status_code=404, detail="Password change window not found")

    if data.title is not None:
        window.title = data.title
    if data.scope is not None:
        window.scope = data.scope
    if data.target_ids is not None:
        if isinstance(data.target_ids, list):
            window.target_ids = json.dumps(data.target_ids)
        else:
            window.target_ids = str(data.target_ids)
    if data.start_at is not None:
        window.start_at = data.start_at
    if data.end_at is not None:
        window.end_at = data.end_at

    old_active = window.is_active
    if data.is_active is not None:
        window.is_active = data.is_active

    affected_count = _apply_password_change_window(db, window)

    if data.is_active is not None and old_active != data.is_active:
        action = "ENABLE_PASSWORD_CHANGE_WINDOW" if data.is_active else "DISABLE_PASSWORD_CHANGE_WINDOW"
    else:
        action = "ENABLE_PASSWORD_CHANGE_WINDOW" if window.is_active else "DISABLE_PASSWORD_CHANGE_WINDOW"

    _add_audit(db, current_user.id, action, f"Updated window ID {window_id}: '{window.title}' (is_active={window.is_active})")
    db.commit()
    db.refresh(window)

    return PasswordChangeWindowOut(
        id=window.id,
        title=window.title,
        scope=window.scope,
        target_ids=window.target_ids,
        start_at=window.start_at,
        end_at=window.end_at,
        is_active=window.is_active,
        created_by=window.created_by,
        created_at=window.created_at,
        updated_at=window.updated_at,
        affected_users_count=affected_count
    )


@router.delete("/password-change-window/{window_id}")
def delete_password_change_window(
    window_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Deletes a password change window and clears associated window linkages."""
    window = db.query(PasswordChangeWindow).filter(PasswordChangeWindow.id == window_id).first()
    if not window:
        raise HTTPException(status_code=404, detail="Password change window not found")

    db.query(User).filter(User.password_change_window_id == window_id).update({User.password_change_window_id: None})
    _add_audit(db, current_user.id, "DISABLE_PASSWORD_CHANGE_WINDOW", f"Deleted password change window ID {window_id} ('{window.title}')")
    db.delete(window)
    db.commit()
    return {"message": "Password change window deleted successfully"}


# ==========================================
# ADMIN SUPPORT-ACCESS / IMPERSONATION MODE
# ==========================================

@router.post("/support/start", response_model=SupportSessionOut)
def start_support_session(
    data: SupportSessionStartRequest,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Starts an Admin Support session to inspect a Student or Faculty account.
    Requires Admin re-authentication with current password.
    Blocks targeting Admin accounts or disabled accounts.
    """
    # 1. Admin re-authentication
    if not verify_password(data.admin_password, current_user.hashed_password):
        raise HTTPException(
            status_code=400,
            detail="Admin re-authentication failed: incorrect admin password."
        )

    # 2. Resolve target user
    target_user = None
    target_name = ""
    target_identifier = ""

    if data.target_student_id:
        st = db.query(Student).filter(Student.id == data.target_student_id).first()
        if not st or not st.user:
            raise HTTPException(status_code=404, detail="Target student account not found")
        target_user = st.user
        target_name = st.full_name
        target_identifier = st.roll_number

    elif data.target_faculty_id:
        fac = db.query(Faculty).filter(Faculty.id == data.target_faculty_id).first()
        if not fac or not fac.user:
            raise HTTPException(status_code=404, detail="Target faculty account not found")
        target_user = fac.user
        target_name = fac.full_name
        target_identifier = fac.employee_id

    elif data.target_user_id:
        target_user = db.query(User).filter(User.id == data.target_user_id).first()
        if not target_user:
            raise HTTPException(status_code=404, detail="Target user account not found")
        if target_user.role == UserRole.STUDENT and target_user.student_profile:
            target_name = target_user.student_profile.full_name
            target_identifier = target_user.student_profile.roll_number
        elif target_user.role == UserRole.FACULTY and target_user.faculty_profile:
            target_name = target_user.faculty_profile.full_name
            target_identifier = target_user.faculty_profile.employee_id
        else:
            target_name = target_user.username
            target_identifier = target_user.username
    else:
        raise HTTPException(status_code=400, detail="Target account must be specified (student, faculty, or user ID)")

    # 3. Security checks on target
    if target_user.role == UserRole.ADMIN:
        raise HTTPException(status_code=400, detail="Admin accounts cannot be targeted for support mode.")
    if not target_user.is_active:
        raise HTTPException(status_code=400, detail="Cannot start support session for a disabled account.")

    # 4. Session generation (15 minutes default)
    session_uid = f"supp_{uuid.uuid4().hex}"
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=data.duration_minutes or 15)

    support_sess = AdminSupportSession(
        session_id=session_uid,
        admin_user_id=current_user.id,
        target_user_id=target_user.id,
        target_role=target_user.role.value,
        read_only=data.read_only,
        reason=data.reason,
        expires_at=expires_at,
        is_active=True
    )
    db.add(support_sess)
    db.flush()

    _add_audit(
        db,
        current_user.id,
        "START_ADMIN_SUPPORT",
        f"Admin started support session for {target_name} ({target_user.role.value}, User ID {target_user.id}). Reason: {data.reason or 'N/A'}"
    )
    db.commit()
    db.refresh(support_sess)

    secs = max(0, int((expires_at - datetime.now(timezone.utc)).total_seconds()))

    return SupportSessionOut(
        session_id=support_sess.session_id,
        admin_user_id=support_sess.admin_user_id,
        target_user_id=support_sess.target_user_id,
        target_role=support_sess.target_role,
        target_name=target_name,
        target_identifier=target_identifier,
        read_only=support_sess.read_only,
        reason=support_sess.reason,
        created_at=support_sess.created_at,
        expires_at=support_sess.expires_at,
        is_active=support_sess.is_active,
        seconds_remaining=secs
    )


@router.post("/support/{session_id}/end", response_model=SupportSessionEndResponse)
def end_support_session(
    session_id: str,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Explicitly ends an active support session."""
    sess = db.query(AdminSupportSession).filter(AdminSupportSession.session_id == session_id).first()
    if not sess:
        raise HTTPException(status_code=404, detail="Support session not found")

    sess.is_active = False
    sess.ended_at = datetime.now(timezone.utc)
    _add_audit(db, current_user.id, "END_ADMIN_SUPPORT", f"Admin ended support session {session_id} for target User ID {sess.target_user_id}")
    db.commit()
    return SupportSessionEndResponse(
        message="Admin support session ended successfully",
        session_id=session_id,
        is_active=False
    )


@router.get("/support/{session_id}", response_model=SupportSessionOut)
def get_support_session(
    session_id: str,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Retrieves metadata and status of an admin support session."""
    sess = db.query(AdminSupportSession).filter(AdminSupportSession.session_id == session_id).first()
    if not sess:
        raise HTTPException(status_code=404, detail="Support session not found")

    now = datetime.now(timezone.utc)
    target_user = db.query(User).filter(User.id == sess.target_user_id).first()
    target_name = "Unknown"
    target_identifier = "Unknown"
    if target_user:
        if target_user.student_profile:
            target_name = target_user.student_profile.full_name
            target_identifier = target_user.student_profile.roll_number
        elif target_user.faculty_profile:
            target_name = target_user.faculty_profile.full_name
            target_identifier = target_user.faculty_profile.employee_id

    sess_exp = normalize_utc_datetime(sess.expires_at)
    is_expired = bool(sess_exp and now > sess_exp)
    if is_expired and sess.is_active:
        sess.is_active = False
        sess.ended_at = now
        _add_audit(db, current_user.id, "EXPIRE_ADMIN_SUPPORT", f"Support session {session_id} expired")
        db.commit()

    secs = max(0, int((sess_exp - now).total_seconds())) if (sess_exp and not is_expired) else 0

    return SupportSessionOut(
        session_id=sess.session_id,
        admin_user_id=sess.admin_user_id,
        target_user_id=sess.target_user_id,
        target_role=sess.target_role,
        target_name=target_name,
        target_identifier=target_identifier,
        read_only=sess.read_only,
        reason=sess.reason,
        created_at=sess.created_at,
        expires_at=sess.expires_at,
        is_active=sess.is_active and not is_expired,
        seconds_remaining=secs
    )


@router.get("/support/{session_id}/inspect")
def inspect_support_target(
    session_id: str,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Read-only inspection endpoint returning target account profile, timetable, and attendance summaries.
    """
    sess = db.query(AdminSupportSession).filter(AdminSupportSession.session_id == session_id).first()
    if not sess:
        raise HTTPException(status_code=404, detail="Support session not found")

    now = datetime.now(timezone.utc)
    sess_exp = normalize_utc_datetime(sess.expires_at)
    if not sess.is_active or (sess_exp and now > sess_exp):
        raise HTTPException(status_code=400, detail="Support session is expired or inactive")

    target_user = db.query(User).filter(User.id == sess.target_user_id).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found")

    if target_user.role == UserRole.STUDENT and target_user.student_profile:
        st = target_user.student_profile
        class_name = st.class_section.name if st.class_section else None

        timetable = []
        if st.class_id:
            slots = db.query(TimetableEntry).join(FacultyAssignment).filter(FacultyAssignment.class_id == st.class_id).all()
            for sl in slots:
                timetable.append({
                    "day_of_week": sl.day_of_week,
                    "period_id": sl.period_id,
                    "subject": sl.assignment.subject.name if sl.assignment and sl.assignment.subject else "Pending",
                    "faculty": sl.assignment.faculty.full_name if sl.assignment and sl.assignment.faculty else "Pending"
                })

        return {
            "role": "STUDENT",
            "student_id": st.id,
            "roll_number": st.roll_number,
            "full_name": st.full_name,
            "class_name": class_name,
            "email": st.email,
            "phone": st.phone,
            "timetable_count": len(timetable),
            "timetable": timetable,
            "is_active": st.is_active,
            "read_only": sess.read_only
        }

    elif target_user.role == UserRole.FACULTY and target_user.faculty_profile:
        fac = target_user.faculty_profile
        slots = db.query(TimetableEntry).join(FacultyAssignment).filter(FacultyAssignment.faculty_id == fac.id).all()
        timetable = []
        for sl in slots:
            timetable.append({
                "day_of_week": sl.day_of_week,
                "period_id": sl.period_id,
                "subject": sl.assignment.subject.name if sl.assignment and sl.assignment.subject else "Pending",
                "class_name": sl.assignment.class_section.name if sl.assignment and sl.assignment.class_section else "Pending"
            })

        return {
            "role": "FACULTY",
            "faculty_id": fac.id,
            "employee_id": fac.employee_id,
            "full_name": fac.full_name,
            "department": fac.department,
            "email": fac.user.email if fac.user else None,
            "phone": fac.phone,
            "timetable_count": len(timetable),
            "timetable": timetable,
            "is_active": fac.user.is_active if fac.user else True,
            "read_only": sess.read_only
        }

    return {
        "role": target_user.role.value,
        "user_id": target_user.id,
        "username": target_user.username,
        "email": target_user.email,
        "is_active": target_user.is_active,
        "read_only": sess.read_only
    }


@router.post("/support/{session_id}/action")
def perform_support_action(
    session_id: str,
    data: SupportSessionActionRequest,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Explicit write mode action during support session. Requires confirmation reason and audit logging.
    """
    sess = db.query(AdminSupportSession).filter(AdminSupportSession.session_id == session_id).first()
    if not sess:
        raise HTTPException(status_code=404, detail="Support session not found")

    now = datetime.now(timezone.utc)
    sess_exp = normalize_utc_datetime(sess.expires_at)
    if not sess.is_active or (sess_exp and now > sess_exp):
        raise HTTPException(status_code=400, detail="Support session is expired or inactive")

    if not data.reason or len(data.reason.strip()) < 3:
        raise HTTPException(status_code=400, detail="A valid reason must be provided for support mode modifications.")

    _add_audit(
        db,
        current_user.id,
        "ADMIN_SUPPORT_ACTION",
        f"Support action '{data.action}' on Target User ID {sess.target_user_id}. Reason: {data.reason.strip()}"
    )
    db.commit()
    return {"message": f"Support action '{data.action}' recorded successfully", "session_id": session_id}


# ==========================================
# USER ACCOUNT MANAGEMENT
# ==========================================

@router.get("/users", response_model=List[UserAdminOut])
def list_admin_users(
    search: Optional[str] = None,
    role: Optional[str] = None,
    is_active: Optional[bool] = None,
    db: Session = Depends(get_db)
):
    query = db.query(User)
    if search:
        s = f"%{search.strip()}%"
        query = query.filter((User.username.ilike(s)) | (User.email.ilike(s)) | (User.login_identifier.ilike(s)))
    if role:
        try:
            r = UserRole(role.upper())
            query = query.filter(User.role == r)
        except ValueError:
            pass
    if is_active is not None:
        query = query.filter(User.is_active == is_active)

    users = query.order_by(User.id.asc()).all()
    result = []
    for u in users:
        result.append(UserAdminOut(
            id=u.id,
            username=u.username,
            email=u.email,
            role=u.role.value if hasattr(u.role, 'value') else str(u.role),
            is_active=u.is_active,
            force_password_change=u.force_password_change or False,
            failed_login_attempts=u.failed_login_attempts or 0,
            locked_until=u.locked_until.isoformat() if u.locked_until else None,
            password_changed_at=u.password_changed_at.isoformat() if u.password_changed_at else None,
            login_identifier=u.login_identifier,
            created_at=u.created_at.isoformat() if u.created_at else None,
        ))
    return result


@router.get("/users/{user_id}", response_model=UserAdminOut)
def get_admin_user(
    user_id: int,
    db: Session = Depends(get_db)
):
    u = db.query(User).filter(User.id == user_id).first()
    if not u:
        raise HTTPException(status_code=404, detail="User not found")
    return UserAdminOut(
        id=u.id,
        username=u.username,
        email=u.email,
        role=u.role.value if hasattr(u.role, 'value') else str(u.role),
        is_active=u.is_active,
        force_password_change=u.force_password_change or False,
        failed_login_attempts=u.failed_login_attempts or 0,
        locked_until=u.locked_until.isoformat() if u.locked_until else None,
        password_changed_at=u.password_changed_at.isoformat() if u.password_changed_at else None,
        login_identifier=u.login_identifier,
        created_at=u.created_at.isoformat() if u.created_at else None,
    )


@router.put("/users/{user_id}", response_model=UserAdminOut)
def update_admin_user(
    user_id: int,
    data: UserAdminUpdate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    u = db.query(User).filter(User.id == user_id).first()
    if not u:
        raise HTTPException(status_code=404, detail="User not found")

    changes = []
    if data.username and data.username.strip() != u.username:
        new_u = data.username.strip()
        existing = db.query(User).filter(func.lower(User.username) == new_u.lower(), User.id != user_id).first()
        if existing:
            raise HTTPException(status_code=400, detail=f"Username '{new_u}' already exists")
        changes.append(f"username: {u.username} -> {new_u}")
        u.username = new_u

    if data.email is not None and data.email != u.email:
        existing = db.query(User).filter(User.email == data.email, User.id != user_id).first()
        if existing:
            raise HTTPException(status_code=400, detail="Email already exists")
        changes.append(f"email: {u.email} -> {data.email}")
        u.email = data.email

    if data.role and data.role != u.role.value:
        try:
            u.role = UserRole(data.role.upper())
            changes.append(f"role -> {u.role.value}")
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid role '{data.role}'")

    if data.is_active is not None and data.is_active != u.is_active:
        u.is_active = data.is_active
        if not data.is_active:
            u.session_token = "REVOKED"
        changes.append(f"is_active -> {data.is_active}")

    if data.force_password_change is not None and data.force_password_change != u.force_password_change:
        u.force_password_change = data.force_password_change
        changes.append(f"force_password_change -> {data.force_password_change}")

    if data.unlock:
        u.locked_until = None
        u.failed_login_attempts = 0
        changes.append("unlocked")

    if data.new_password:
        u.hashed_password = get_password_hash(data.new_password)
        u.session_token = "REVOKED"
        u.failed_login_attempts = 0
        u.locked_until = None
        u.password_changed_at = datetime.now(timezone.utc)
        changes.append("password_reset")

    _add_audit(db, current_user.id, "USER_UPDATED",
               f"Updated user #{u.id} ({u.username}): {', '.join(changes) if changes else 'no changes'}",
               target=u.username)
    db.commit()
    db.refresh(u)

    return UserAdminOut(
        id=u.id,
        username=u.username,
        email=u.email,
        role=u.role.value if hasattr(u.role, 'value') else str(u.role),
        is_active=u.is_active,
        force_password_change=u.force_password_change or False,
        failed_login_attempts=u.failed_login_attempts or 0,
        locked_until=u.locked_until.isoformat() if u.locked_until else None,
        password_changed_at=u.password_changed_at.isoformat() if u.password_changed_at else None,
        login_identifier=u.login_identifier,
        created_at=u.created_at.isoformat() if u.created_at else None,
    )


@router.post("/users/{user_id}/reset-password", response_model=PasswordResetResponse)
def admin_reset_user_password(
    user_id: int,
    data: PasswordResetRequest,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    u = db.query(User).filter(User.id == user_id).first()
    if not u:
        raise HTTPException(status_code=404, detail="User not found")

    raw_pw = data.new_password
    temp_pw = None
    force_pw = data.force_password_change
    if not raw_pw or data.generate_temporary:
        raw_pw = _generate_temporary_password()
        temp_pw = raw_pw
        force_pw = True

    u.hashed_password = get_password_hash(raw_pw)
    u.force_password_change = force_pw
    u.failed_login_attempts = 0
    u.locked_until = None
    u.session_token = None
    u.password_changed_at = datetime.now(timezone.utc)

    _add_audit(db, current_user.id, "USER_PASSWORD_RESET", f"Reset password for user #{u.id} ({u.username})", target=u.username)
    db.commit()

    return PasswordResetResponse(
        message=f"Password reset for user {u.username} successfully",
        temporary_password=temp_pw,
        force_password_change=force_pw
    )


@router.post("/users/{user_id}/toggle-active")
def admin_toggle_user_active(
    user_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    u = db.query(User).filter(User.id == user_id).first()
    if not u:
        raise HTTPException(status_code=404, detail="User not found")

    if u.id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot deactivate your own admin account")

    u.is_active = not u.is_active
    if not u.is_active:
        u.session_token = "REVOKED"

    # Sync linked student or faculty if any
    if u.student_profile:
        u.student_profile.is_active = u.is_active

    action = "ENABLE_USER" if u.is_active else "DISABLE_USER"
    _add_audit(db, current_user.id, action, f"User #{u.id} ({u.username}) active status set to {u.is_active}", target=u.username)
    db.commit()

    return {
        "message": f"User {'enabled' if u.is_active else 'disabled'} successfully",
        "user_id": u.id,
        "is_active": u.is_active
    }
