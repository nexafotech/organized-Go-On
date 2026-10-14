from pydantic import BaseModel
from typing import Optional, List, Dict, Any

# ─────────────────────────────────────────────────────────────────────────────
# Student Login
# ─────────────────────────────────────────────────────────────────────────────

class StudentLoginRequest(BaseModel):
    """
    Student login uses the configured login identifier method.
    Default: register_number. Also supports username or email.
    """
    identifier: str    # register_number, username, or email depending on config
    password: str

class StudentToken(BaseModel):
    access_token: str
    token_type: str = "bearer"
    student_id: int
    full_name: str
    register_number: str
    force_password_change: bool = False


# ─────────────────────────────────────────────────────────────────────────────
# Student Profile (Me endpoint)
# ─────────────────────────────────────────────────────────────────────────────

class PeriodAttendanceRow(BaseModel):
    period_number: int
    period_name: str
    total: int
    present: int
    absent: int
    od: int
    percentage: float

class StudentMeOut(BaseModel):
    student_id: int
    user_id: Optional[int] = None
    full_name: str
    register_number: str
    email: Optional[str] = None
    phone: Optional[str] = None
    class_name: Optional[str] = None
    class_id: Optional[int] = None
    semester: Optional[str] = None
    department: Optional[str] = None
    is_active: bool
    avatar_id: Optional[str] = None
    # Overall attendance summary
    total: int = 0
    present: int = 0
    absent: int = 0
    od: int = 0
    half_day_present: int = 0
    half_day_absent: int = 0
    percentage: float = 0.0
    calculation_mode: str = "RECORD_BASED"
    attendance_status: str = "NO_DATA"   # CRITICAL | WARNING | OK | NO_DATA
    minimum_required: float = 75.0
    below_minimum: bool = False
    alert_message: Optional[str] = None
    required_future_classes: int = 0
    estimated_working_days: int = 0
    missable_future_classes: int = 0

    class Config:
        from_attributes = True

class AvatarCatalogItem(BaseModel):
    id: str
    name: str
    category: str
    gender_presentation: str
    is_neutral: bool
    tags: List[str]
    asset: str
    url: str

class AvatarUpdateIn(BaseModel):
    avatar_id: str
    preference: Optional[str] = None



# ─────────────────────────────────────────────────────────────────────────────
# Subject-wise Attendance
# ─────────────────────────────────────────────────────────────────────────────

class SubjectAttendanceRow(BaseModel):
    subject_id: int
    subject_code: str
    subject_name: str
    total: int
    present: int
    absent: int
    od: int
    percentage: float

class SubjectAttendanceDetail(BaseModel):
    subject_id: int
    subject_code: str
    subject_name: str
    total: int
    present: int
    absent: int
    od: int
    uncertain: int
    not_entered: int
    excluded: int
    percentage: float
    records: List[Dict[str, Any]] = []    # date + period level records


# ─────────────────────────────────────────────────────────────────────────────
# Period-wise entry in date-wise report
# ─────────────────────────────────────────────────────────────────────────────

class PeriodEntry(BaseModel):
    period_number: Optional[int] = None
    period_name: Optional[str] = None
    subject_code: Optional[str] = None
    subject_name: Optional[str] = None
    status: str
    od_reason: Optional[str] = None
    session_id: Optional[int] = None

class DateWiseEntry(BaseModel):
    date: str
    periods: List[PeriodEntry]
    morning_status: Optional[str] = None
    morning_summary: Optional[str] = None
    afternoon_status: Optional[str] = None
    afternoon_summary: Optional[str] = None
    daily_result: Optional[str] = None
    lunch_interval: Optional[str] = "12:50 PM - 01:40 PM (Not Counted)"


# ─────────────────────────────────────────────────────────────────────────────
# Full Attendance Report
# ─────────────────────────────────────────────────────────────────────────────

class StudentAttendanceReport(BaseModel):
    student_id: int
    full_name: str
    register_number: str
    class_name: Optional[str] = None
    semester: Optional[str] = None
    # Semester summary
    total: int
    present: int
    absent: int
    od: int
    half_day_present: int = 0
    half_day_absent: int = 0
    percentage: float
    calculation_mode: str = "RECORD_BASED"
    status: str
    minimum_required: float
    below_minimum: bool = False
    alert_message: Optional[str] = None
    required_future_classes: int = 0
    estimated_working_days: int = 0
    missable_future_classes: int = 0
    # Period-wise summary
    period_summary: List[PeriodAttendanceRow] = []
    # Subject-wise
    subjects: List[SubjectAttendanceRow]
    # Date-wise
    date_wise: List[DateWiseEntry]


# ─────────────────────────────────────────────────────────────────────────────
# OD Marking Schemas
# ─────────────────────────────────────────────────────────────────────────────

class ODMarkRequest(BaseModel):
    student_id: int
    od_reason: Optional[str] = None

class BulkODRequest(BaseModel):
    student_ids: List[int]
    od_reason: Optional[str] = None
