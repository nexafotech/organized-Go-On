from pydantic import BaseModel, EmailStr
from typing import Optional

class LoginRequest(BaseModel):
    username_or_email: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    force_password_change: bool = False

class UserOut(BaseModel):
    id: int
    username: str
    email: str
    role: str
    is_active: bool
    faculty_profile_id: Optional[int] = None
    full_name: Optional[str] = None
    is_class_advisor: bool = False
    advised_class_id: Optional[int] = None
    advised_class_name: Optional[str] = None
    force_password_change: bool = False

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str
    confirm_password: Optional[str] = None

class ValidateIdentifierRequest(BaseModel):
    identifier: str
    role: str = "FACULTY"

class ValidateIdentifierResponse(BaseModel):
    valid: bool
    role: str
    message: Optional[str] = None
