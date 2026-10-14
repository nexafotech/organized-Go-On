from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, HTTPException, status, Response, Request
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import or_, func
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import verify_password, create_access_token, get_password_hash
from app.core.datetime_utils import normalize_utc_datetime
from app.core.config import settings
from app.models.user import User, Faculty, UserRole
from app.models.student import Student
from app.models.academic import ClassSection
from app.models.policy import SystemSetting
from app.schemas.auth import (
    LoginRequest, Token, UserOut, ChangePasswordRequest,
    ValidateIdentifierRequest, ValidateIdentifierResponse
)
from app.schemas.student_auth import StudentLoginRequest, StudentToken
from app.api.deps import get_current_user

router = APIRouter(prefix="/auth", tags=["Authentication"])

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _get_setting(db: Session, key: str, default: str) -> str:
    s = db.query(SystemSetting).filter(SystemSetting.key == key).first()
    return s.value if s else default

def _handle_failed_login(user: User, db: Session, max_attempts: int, lock_minutes: int):
    """Increment failed attempts and lock if threshold reached."""
    user.failed_login_attempts = (user.failed_login_attempts or 0) + 1
    if max_attempts > 0 and user.failed_login_attempts >= max_attempts:
        user.locked_until = datetime.now(timezone.utc) + timedelta(minutes=lock_minutes)
    db.commit()

def _reset_failed_login(user: User, db: Session):
    """Reset failed attempts and lock on successful login."""
    user.failed_login_attempts = 0
    user.locked_until = None


# ─────────────────────────────────────────────────────────────────────────────
# Faculty / Admin Login
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/login", response_model=Token)
def login(
    login_data: LoginRequest,
    response: Response,
    db: Session = Depends(get_db)
):
    """Login for ADMIN and FACULTY roles."""
    max_attempts = int(_get_setting(db, "auth.max_failed_attempts", "5"))
    lock_minutes = int(_get_setting(db, "auth.lock_duration_minutes", "30"))
    faculty_login_method = _get_setting(db, "auth.faculty_login_method", "USERNAME")

    # Resolve user based on configured login method
    user = None
    identifier = login_data.username_or_email.strip()

    if faculty_login_method == "EMAIL":
        user = db.query(User).filter(
            func.lower(User.email) == identifier.lower(),
            User.role.in_([UserRole.ADMIN, UserRole.FACULTY])
        ).first()
    elif faculty_login_method == "FACULTY_ID":
        # Look up via Faculty.employee_id → User
        faculty = db.query(Faculty).filter(func.lower(Faculty.employee_id) == identifier.lower()).first()
        if faculty:
            user = db.query(User).filter(
                User.id == faculty.user_id,
                User.role.in_([UserRole.ADMIN, UserRole.FACULTY])
            ).first()
    else:  # USERNAME (default) — also allow email and employee_id fallback
        user = db.query(User).filter(
            (func.lower(User.username) == identifier.lower()) | (func.lower(User.email) == identifier.lower()),
            User.role.in_([UserRole.ADMIN, UserRole.FACULTY])
        ).first()
        if not user:
            faculty = db.query(Faculty).filter(func.lower(Faculty.employee_id) == identifier.lower()).first()
            if faculty:
                user = db.query(User).filter(
                    User.id == faculty.user_id,
                    User.role.in_([UserRole.ADMIN, UserRole.FACULTY])
                ).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is disabled. Contact system administrator.",
        )

    # Check account lock BEFORE password verification
    locked_until = normalize_utc_datetime(user.locked_until)
    if locked_until and locked_until > datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Account is locked until {locked_until.isoformat()}.",
        )

    if not verify_password(login_data.password, user.hashed_password):
        _handle_failed_login(user, db, max_attempts, lock_minutes)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    _reset_failed_login(user, db)

    session_days = int(_get_setting(db, "auth.session_days", "7"))
    access_token = create_access_token(
        subject=user.id,
        role=user.role.value,
        expires_delta=timedelta(days=session_days)
    )

    user.session_token = access_token
    db.commit()

    response.set_cookie(
        key=settings.COOKIE_NAME,
        value=access_token,
        max_age=session_days * 86400,
        httponly=settings.COOKIE_HTTPONLY,
        secure=settings.COOKIE_SECURE,
        samesite=settings.COOKIE_SAMESITE,
        path="/"
    )

    return Token(
        access_token=access_token,
        token_type="bearer",
        force_password_change=user.force_password_change or False,
    )
 
 
# ─────────────────────────────────────────────────────────────────────────────
# Live Identifier Validation (pre-submit UX assistance)
# ─────────────────────────────────────────────────────────────────────────────
 
@router.post("/validate-identifier", response_model=ValidateIdentifierResponse)
def validate_identifier(
    data: ValidateIdentifierRequest,
    db: Session = Depends(get_db)
):
    """
    Live validation of login identifiers before submitting credentials.
    Returns whether the identifier belongs to a valid account of the specified role.
    Role-aware: Students/non-faculty accounts will NOT be accepted as FACULTY.
    No sensitive data, passwords, or tokens are exposed.
    """
    clean_id = data.identifier.strip()
    if not clean_id:
        return ValidateIdentifierResponse(
            valid=False,
            role=data.role,
            message="Identifier cannot be empty"
        )

    target_role = data.role.upper()
    if target_role == "FACULTY":
        user = db.query(User).outerjoin(Faculty, Faculty.user_id == User.id).filter(
            User.role.in_([UserRole.FACULTY, UserRole.ADMIN]),
            User.is_active == True,
            or_(
                func.lower(User.username) == clean_id.lower(),
                func.lower(User.email) == clean_id.lower(),
                func.lower(Faculty.employee_id) == clean_id.lower()
            )
        ).first()

        if user:
            role_label = "Administrator" if user.role == UserRole.ADMIN else "Faculty"
            return ValidateIdentifierResponse(
                valid=True,
                role=user.role.value,
                message=f"{role_label} account recognized"
            )
        else:
            return ValidateIdentifierResponse(
                valid=False,
                role="FACULTY",
                message="Invalid faculty or staff username"
            )
    elif target_role == "STUDENT":
        user = db.query(User).outerjoin(Student, Student.user_id == User.id).filter(
            User.role == UserRole.STUDENT,
            User.is_active == True,
            or_(
                func.lower(User.username) == clean_id.lower(),
                func.lower(User.email) == clean_id.lower(),
                func.lower(User.login_identifier) == clean_id.lower(),
                func.lower(Student.roll_number) == clean_id.lower()
            )
        ).first()

        if user:
            return ValidateIdentifierResponse(
                valid=True,
                role="STUDENT",
                message="Student account recognized"
            )
        else:
            return ValidateIdentifierResponse(
                valid=False,
                role="STUDENT",
                message="Invalid student identifier"
            )

    return ValidateIdentifierResponse(
        valid=False,
        role=data.role,
        message="Unsupported role for validation"
    )



# ─────────────────────────────────────────────────────────────────────────────
# Student Login
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/student/login", response_model=StudentToken)
def student_login(
    login_data: StudentLoginRequest,
    response: Response,
    db: Session = Depends(get_db)
):
    """
    Login for STUDENT role.
    Uses admin-configured student_login_method to look up the student.
    Default: REGISTER_NUMBER
    """
    max_attempts = int(_get_setting(db, "auth.max_failed_attempts", "5"))
    lock_minutes = int(_get_setting(db, "auth.lock_duration_minutes", "30"))
    student_login_method = _get_setting(db, "auth.student_login_method", "REGISTER_NUMBER")

    clean_id = login_data.identifier.strip()
    user = None

    # 1. Resolve student user using configured method (case-insensitive)
    if student_login_method == "EMAIL":
        user = db.query(User).filter(
            func.lower(User.email) == clean_id.lower(),
            User.role == UserRole.STUDENT
        ).first()
    elif student_login_method == "USERNAME":
        user = db.query(User).filter(
            func.lower(User.username) == clean_id.lower(),
            User.role == UserRole.STUDENT
        ).first()
    else:  # REGISTER_NUMBER (default)
        user = db.query(User).filter(
            func.lower(User.login_identifier) == clean_id.lower(),
            User.role == UserRole.STUDENT
        ).first()

    # 2. Resilient fallback across all student identifiers (login_identifier, username, email, roll_number)
    if not user:
        user = db.query(User).outerjoin(Student, Student.user_id == User.id).filter(
            User.role == UserRole.STUDENT,
            or_(
                func.lower(User.login_identifier) == clean_id.lower(),
                func.lower(User.username) == clean_id.lower(),
                func.lower(User.email) == clean_id.lower(),
                func.lower(Student.roll_number) == clean_id.lower()
            )
        ).first()

    # 3. Numeric Student ID fallback (in case user enters numeric primary key ID)
    if not user and clean_id.isdigit():
        user = db.query(User).join(Student, Student.user_id == User.id).filter(
            User.role == UserRole.STUDENT,
            Student.id == int(clean_id)
        ).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is disabled. Contact administrator.",
        )

    # Check account lock BEFORE password verification
    locked_until = normalize_utc_datetime(user.locked_until)
    if locked_until and locked_until > datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Account is locked until {locked_until.isoformat()}.",
        )

    if not verify_password(login_data.password, user.hashed_password):
        _handle_failed_login(user, db, max_attempts, lock_minutes)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Get student profile (derived from session — cannot be tampered)
    student = db.query(Student).filter(Student.user_id == user.id).first()
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student profile not linked to this account.",
        )
    if not student.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is disabled. Contact administrator.",
        )

    _reset_failed_login(user, db)

    session_days = int(_get_setting(db, "auth.session_days", "7"))
    access_token = create_access_token(
        subject=user.id,
        role=user.role.value,
        expires_delta=timedelta(days=session_days)
    )

    user.session_token = access_token
    db.commit()

    response.set_cookie(
        key=settings.COOKIE_NAME,
        value=access_token,
        max_age=session_days * 86400,
        httponly=settings.COOKIE_HTTPONLY,
        secure=settings.COOKIE_SECURE,
        samesite=settings.COOKIE_SAMESITE,
        path="/"
    )

    return StudentToken(
        access_token=access_token,
        token_type="bearer",
        student_id=student.id,
        full_name=student.full_name,
        register_number=student.roll_number,
        force_password_change=user.force_password_change or False,
    )


# ─────────────────────────────────────────────────────────────────────────────
# Student Logout
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/student/logout")
def student_logout(
    response: Response,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    current_user.session_token = "REVOKED"
    db.commit()
    response.delete_cookie(key=settings.COOKIE_NAME, path="/")
    return {"message": "Successfully logged out"}


# ─────────────────────────────────────────────────────────────────────────────
# /auth/me — works for all roles
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/me", response_model=UserOut)
def get_current_user_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    faculty_profile_id = None
    full_name = current_user.username
    is_class_advisor = False
    advised_class_id = None
    advised_class_name = None

    if current_user.role == UserRole.FACULTY and current_user.faculty_profile:
        faculty_profile_id = current_user.faculty_profile.id
        full_name = current_user.faculty_profile.full_name
        cs = db.query(ClassSection).filter(ClassSection.class_advisor_id == faculty_profile_id).first()
        if cs:
            is_class_advisor = True
            advised_class_id = cs.id
            advised_class_name = cs.name
    elif current_user.role == UserRole.ADMIN:
        full_name = "Administrator"
    elif current_user.role == UserRole.STUDENT and current_user.student_profile:
        full_name = current_user.student_profile.full_name

    return UserOut(
        id=current_user.id,
        username=current_user.username,
        email=current_user.email or "",
        role=current_user.role.value,
        is_active=current_user.is_active,
        faculty_profile_id=faculty_profile_id,
        full_name=full_name,
        is_class_advisor=is_class_advisor,
        advised_class_id=advised_class_id,
        advised_class_name=advised_class_name,
        force_password_change=current_user.force_password_change or False,
    )


# ─────────────────────────────────────────────────────────────────────────────
# Logout (faculty/admin)
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/logout")
def logout(
    response: Response,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    current_user.session_token = "REVOKED"
    db.commit()
    response.delete_cookie(key=settings.COOKIE_NAME, path="/")
    return {"message": "Successfully logged out"}


# ─────────────────────────────────────────────────────────────────────────────
# Change Password (all authenticated roles)
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/change-password")
def change_password(
    data: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if not verify_password(data.current_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect."
        )
    if len(data.new_password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be at least 8 characters long."
        )
    if data.confirm_password is not None and data.confirm_password != data.new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password and confirmation do not match."
        )
    if data.current_password == data.new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password cannot be the same as the current password."
        )

    current_user.hashed_password = get_password_hash(data.new_password)
    current_user.force_password_change = False
    current_user.password_changed_at = datetime.now(timezone.utc)
    db.commit()
    return {"message": "Password changed successfully", "force_password_change": False}

