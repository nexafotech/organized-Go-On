from pydantic import BaseModel, EmailStr
from typing import Optional

class FacultyCreate(BaseModel):
    username: str
    email: EmailStr
    employee_id: str
    full_name: str
    password: Optional[str] = None
    generate_temporary: bool = False
    force_password_change: bool = True
    department: Optional[str] = None
    phone: Optional[str] = None
    is_active: bool = True

class FacultyUpdate(BaseModel):
    employee_id: Optional[str] = None
    username: Optional[str] = None
    full_name: Optional[str] = None
    department: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    password: Optional[str] = None
    new_password: Optional[str] = None
    is_active: Optional[bool] = None
    force_password_change: Optional[bool] = None
    role: Optional[str] = None

class FacultyAdminUpdate(BaseModel):
    """Admin-only update with account management fields."""
    employee_id: Optional[str] = None
    username: Optional[str] = None
    full_name: Optional[str] = None
    department: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    new_password: Optional[str] = None
    force_password_change: Optional[bool] = None
    is_active: Optional[bool] = None
    role: Optional[str] = None

class UserAdminOut(BaseModel):
    id: int
    username: str
    email: Optional[str] = None
    role: str
    is_active: bool
    force_password_change: bool = False
    failed_login_attempts: int = 0
    locked_until: Optional[str] = None
    password_changed_at: Optional[str] = None
    login_identifier: Optional[str] = None
    created_at: Optional[str] = None

    class Config:
        from_attributes = True

class UserAdminUpdate(BaseModel):
    username: Optional[str] = None
    email: Optional[EmailStr] = None
    role: Optional[str] = None
    is_active: Optional[bool] = None
    force_password_change: Optional[bool] = None
    unlock: Optional[bool] = None
    new_password: Optional[str] = None

class FacultyOut(BaseModel):
    id: int
    user_id: int
    employee_id: str
    full_name: str
    department: Optional[str] = None
    phone: Optional[str] = None
    username: str
    email: Optional[str] = None
    is_active: bool
    force_password_change: bool = False
    is_locked: bool = False
    is_dev_account: bool = False
    password_changed_at: Optional[str] = None
    temporary_password: Optional[str] = None  # Populated ONLY on creation if temporary password was generated

    class Config:
        from_attributes = True

class PasswordResetRequest(BaseModel):
    new_password: Optional[str] = None
    generate_temporary: bool = False
    force_password_change: bool = True

class PasswordResetResponse(BaseModel):
    message: str
    temporary_password: Optional[str] = None
    force_password_change: bool = True

class CapacityItem(BaseModel):
    current: int
    max: int
    remaining: int

class CapacityStatsOut(BaseModel):
    students: CapacityItem
    faculty: CapacityItem

