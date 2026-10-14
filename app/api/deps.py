from typing import Optional
from datetime import datetime, timezone, timedelta
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.config import settings
from app.core.security import decode_access_token
from app.core.datetime_utils import normalize_utc_datetime
from app.models.user import User, UserRole, Faculty
from app.models.student import Student

oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_STR}/auth/login", auto_error=False)

def get_current_user(
    request: Request,
    token_header: Optional[str] = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
) -> User:
    token = None
    # 1. Check Bearer Header
    if token_header:
        token = token_header
    # 2. Check Cookie if header is missing
    elif settings.COOKIE_NAME in request.cookies:
        token = request.cookies.get(settings.COOKIE_NAME)

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication credentials were not provided",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = decode_access_token(token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired session token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id_str: str = payload.get("sub")
    if user_id_str is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
        )

    try:
        user_id = int(user_id_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user identification payload",
        )

    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is disabled",
        )

    # Check session revocation / active session validity
    if user.session_token == "REVOKED":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session has been revoked or logged out",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Check password invalidation window: tokens issued prior to password change are invalidated,
    # unless it is the active user.session_token that was retained during password change.
    if user.password_changed_at and user.session_token != token:
        iat = payload.get("iat")
        if iat is not None:
            if isinstance(iat, (int, float)):
                token_issued_at = datetime.fromtimestamp(iat, tz=timezone.utc)
            elif isinstance(iat, datetime):
                token_issued_at = normalize_utc_datetime(iat)
            else:
                token_issued_at = None

            pwd_changed = normalize_utc_datetime(user.password_changed_at)
            # If token was issued before the password change, invalidate it
            if token_issued_at and pwd_changed and token_issued_at <= pwd_changed:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Password was changed; please log in again",
                    headers={"WWW-Authenticate": "Bearer"},
                )

    # M4: Check account lock
    locked_until = normalize_utc_datetime(user.locked_until)
    if locked_until and locked_until > datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Account is locked until {locked_until.isoformat()}. Contact administrator.",
        )

    return user


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: Admin privilege required",
        )
    return current_user


def require_faculty(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role not in [UserRole.FACULTY, UserRole.ADMIN]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: Faculty privilege required",
        )
    return current_user


def require_student(current_user: User = Depends(get_current_user)) -> User:
    """Dependency: requires STUDENT role."""
    if current_user.role != UserRole.STUDENT:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: Student access required",
        )
    return current_user


def get_current_student(
    current_user: User = Depends(require_student),
    db: Session = Depends(get_db)
) -> Student:
    """
    Dependency: returns the Student profile for the authenticated student user.
    Derives identity entirely from the authenticated session — no parameter bypass.
    """
    student = db.query(Student).filter(Student.user_id == current_user.id).first()
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student profile not linked to this account. Contact administrator.",
        )
    if not student.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Student account is not active",
        )
    return student
