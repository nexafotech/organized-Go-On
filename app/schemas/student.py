from pydantic import BaseModel, EmailStr
from typing import Optional

class StudentCreate(BaseModel):
    roll_number: str
    full_name: str
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    class_id: Optional[int] = None
    semester: Optional[str] = None
    department: Optional[str] = None
    password: Optional[str] = None
    generate_temporary: bool = False
    force_password_change: bool = True
    is_active: bool = True

class StudentCreateWithAuth(BaseModel):
    """Creates a student AND a linked user account for login."""
    roll_number: str
    full_name: str
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    class_id: Optional[int] = None
    semester: Optional[str] = None
    department: Optional[str] = None
    password: Optional[str] = None        # initial password (will be hashed) or auto-generated
    generate_temporary: bool = False
    force_password_change: bool = True    # require password change on first login
    is_active: bool = True

class StudentUpdate(BaseModel):
    roll_number: Optional[str] = None
    username: Optional[str] = None
    login_identifier: Optional[str] = None
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    class_id: Optional[int] = None
    is_active: Optional[bool] = None
    semester: Optional[str] = None
    department: Optional[str] = None
    force_password_change: Optional[bool] = None
    new_password: Optional[str] = None

class StudentAdminUpdate(BaseModel):
    """Admin-only update — includes password reset and account management."""
    roll_number: Optional[str] = None
    username: Optional[str] = None
    login_identifier: Optional[str] = None
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    class_id: Optional[int] = None
    is_active: Optional[bool] = None
    semester: Optional[str] = None
    department: Optional[str] = None
    new_password: Optional[str] = None
    force_password_change: Optional[bool] = None

class StudentOut(BaseModel):
    id: int
    roll_number: str
    username: Optional[str] = None
    login_identifier: Optional[str] = None
    full_name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    class_id: Optional[int] = None
    class_name: Optional[str] = None
    semester: Optional[str] = None
    department: Optional[str] = None
    is_active: bool
    user_id: Optional[int] = None       # None if no login account yet
    has_account: bool = False           # True if linked user account exists
    force_password_change: bool = False
    is_locked: bool = False
    password_changed_at: Optional[str] = None
    temporary_password: Optional[str] = None  # Populated ONLY on creation if temporary password was generated
    # Biometric enrollment visibility (safe metadata only, zero raw vectors)
    is_enrolled: bool = False
    template_count: int = 0
    last_enrollment_at: Optional[str] = None

    class Config:
        from_attributes = True

class StudentPasswordResetRequest(BaseModel):
    new_password: Optional[str] = None
    generate_temporary: bool = False
    force_password_change: bool = True

class StudentPasswordResetResponse(BaseModel):
    message: str
    temporary_password: Optional[str] = None
    force_password_change: bool = True

