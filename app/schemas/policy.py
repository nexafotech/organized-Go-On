from pydantic import BaseModel
from typing import Optional, List, Dict, Any

# ─────────────────────────────────────────────────────────────────────────────
# Attendance Policy Schemas
# ─────────────────────────────────────────────────────────────────────────────

class AttendancePolicyOut(BaseModel):
    id: int
    calculation_unit: str
    minimum_percentage: float
    warning_threshold: float
    critical_threshold: float
    unmarked_behavior: str
    exclude_no_class: bool
    exclude_suspended: bool
    exclude_timetable_not_set: bool
    od_enabled: bool
    od_faculty_can_mark: bool
    od_require_reason: bool
    od_require_approval: bool
    od_allow_retroactive: bool
    od_allow_multiple_periods: bool
    od_calculation_mode: str
    leave_calculation_mode: str
    calculation_mode: str = "RECORD_BASED"
    period_present_gain: float = 0.25
    period_absent_loss: float = 0.25
    class_present_gain: float = 1.00
    class_absent_loss: float = 1.00
    day_present_gain: float = 1.00
    day_absent_loss: float = 1.00
    description: Optional[str] = None
    is_active: bool

    class Config:
        from_attributes = True

class AttendancePolicyUpdate(BaseModel):
    calculation_unit: Optional[str] = None
    minimum_percentage: Optional[float] = None
    warning_threshold: Optional[float] = None
    critical_threshold: Optional[float] = None
    unmarked_behavior: Optional[str] = None
    exclude_no_class: Optional[bool] = None
    exclude_suspended: Optional[bool] = None
    exclude_timetable_not_set: Optional[bool] = None
    od_enabled: Optional[bool] = None
    od_faculty_can_mark: Optional[bool] = None
    od_require_reason: Optional[bool] = None
    od_require_approval: Optional[bool] = None
    od_allow_retroactive: Optional[bool] = None
    od_allow_multiple_periods: Optional[bool] = None
    od_calculation_mode: Optional[str] = None
    leave_calculation_mode: Optional[str] = None
    calculation_mode: Optional[str] = None
    period_present_gain: Optional[float] = None
    period_absent_loss: Optional[float] = None
    class_present_gain: Optional[float] = None
    class_absent_loss: Optional[float] = None
    day_present_gain: Optional[float] = None
    day_absent_loss: Optional[float] = None
    description: Optional[str] = None


# ─────────────────────────────────────────────────────────────────────────────
# Auth Settings Schemas
# ─────────────────────────────────────────────────────────────────────────────

class AuthSettingsOut(BaseModel):
    faculty_login_method: str          # FACULTY_ID | USERNAME | EMAIL
    student_login_method: str          # REGISTER_NUMBER | USERNAME | EMAIL
    min_password_length: int
    require_uppercase: bool
    require_digit: bool
    require_special: bool
    max_failed_attempts: int
    lock_duration_minutes: int
    session_days: int
    force_change_on_reset: bool
    password_expiry_days: int          # 0 = disabled

class AuthSettingsUpdate(BaseModel):
    faculty_login_method: Optional[str] = None
    student_login_method: Optional[str] = None
    min_password_length: Optional[int] = None
    require_uppercase: Optional[bool] = None
    require_digit: Optional[bool] = None
    require_special: Optional[bool] = None
    max_failed_attempts: Optional[int] = None
    lock_duration_minutes: Optional[int] = None
    session_days: Optional[int] = None
    force_change_on_reset: Optional[bool] = None
    password_expiry_days: Optional[int] = None


# ─────────────────────────────────────────────────────────────────────────────
# AI / Recognition Settings Schemas
# ─────────────────────────────────────────────────────────────────────────────

class AISettingsOut(BaseModel):
    quantized_model: bool              # ON by default — selects quantized vs full-precision
    recognition_threshold: float       # e.g. 0.45 — confident match distance
    uncertain_threshold: float         # e.g. 0.60 — uncertain match distance
    min_face_size_px: int              # minimum face bounding box size
    image_quality_threshold: float     # minimum quality score 0.0-1.0
    performance_mode: str              # BALANCED | ACCURACY | SPEED

class AISettingsUpdate(BaseModel):
    quantized_model: Optional[bool] = None
    recognition_threshold: Optional[float] = None
    uncertain_threshold: Optional[float] = None
    min_face_size_px: Optional[int] = None
    image_quality_threshold: Optional[float] = None
    performance_mode: Optional[str] = None


# ─────────────────────────────────────────────────────────────────────────────
# System Setting (raw key-value)
# ─────────────────────────────────────────────────────────────────────────────

class SystemSettingOut(BaseModel):
    key: str
    value: str
    description: Optional[str] = None

    class Config:
        from_attributes = True

class SystemSettingUpdate(BaseModel):
    value: str
    description: Optional[str] = None


# ─────────────────────────────────────────────────────────────────────────────
# Audit Log Schemas
# ─────────────────────────────────────────────────────────────────────────────

class AuditLogOut(BaseModel):
    id: int
    actor: Optional[str] = None          # username of actor
    action: str
    target: Optional[str] = None         # description of what was affected
    details: Optional[str] = None
    ip_address: Optional[str] = None
    timestamp: str

    class Config:
        from_attributes = True
