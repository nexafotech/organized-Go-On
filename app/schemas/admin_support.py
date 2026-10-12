from pydantic import BaseModel, Field
from typing import Optional, Any, Dict, List
from datetime import datetime

class SupportSessionStartRequest(BaseModel):
    admin_password: str = Field(..., min_length=1, description="Current admin password for re-authentication")
    target_user_id: Optional[int] = None
    target_student_id: Optional[int] = None
    target_faculty_id: Optional[int] = None
    reason: Optional[str] = Field(None, max_length=255)
    duration_minutes: int = Field(15, ge=1, le=60)
    read_only: bool = True

class SupportSessionOut(BaseModel):
    session_id: str
    admin_user_id: int
    target_user_id: int
    target_role: str
    target_name: str
    target_identifier: str
    read_only: bool
    reason: Optional[str] = None
    created_at: datetime
    expires_at: datetime
    is_active: bool
    seconds_remaining: int

    class Config:
        from_attributes = True

class SupportSessionEndResponse(BaseModel):
    message: str
    session_id: str
    is_active: bool

class SupportSessionActionRequest(BaseModel):
    action: str
    reason: str
    payload: Optional[Dict[str, Any]] = None
