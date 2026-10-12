from pydantic import BaseModel, Field
from typing import Optional, List, Union, Any
from datetime import datetime
from app.models.user import PasswordChangeScope

class PasswordChangeWindowCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=100)
    scope: PasswordChangeScope = PasswordChangeScope.ALL_USERS
    target_ids: Optional[Union[List[int], str]] = None
    start_at: Optional[datetime] = None
    end_at: Optional[datetime] = None
    is_active: bool = True

class PasswordChangeWindowUpdate(BaseModel):
    title: Optional[str] = None
    scope: Optional[PasswordChangeScope] = None
    target_ids: Optional[Union[List[int], str]] = None
    start_at: Optional[datetime] = None
    end_at: Optional[datetime] = None
    is_active: Optional[bool] = None

class PasswordChangeWindowOut(BaseModel):
    id: int
    title: str
    scope: PasswordChangeScope
    target_ids: Optional[str] = None
    start_at: Optional[datetime] = None
    end_at: Optional[datetime] = None
    is_active: bool
    created_by: Optional[int] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    affected_users_count: Optional[int] = 0

    class Config:
        from_attributes = True

class PasswordControlStatsOut(BaseModel):
    students_requiring_change: int
    faculty_requiring_change: int
    total_requiring_change: int
    active_windows_count: int
    total_windows_count: int
