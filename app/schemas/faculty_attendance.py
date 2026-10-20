from pydantic import BaseModel, Field
from typing import Optional, List
from app.models.attendance import AttendanceStatus

class AvailablePeriodItem(BaseModel):
    timetable_entry_id: int
    period_id: int
    period_number: int
    period_name: str
    start_time: str
    end_time: str
    subject_code: str
    subject_name: str
    class_id: int
    class_name: str
    date: str  # YYYY-MM-DD
    day_of_week: str
    faculty_name: str
    status: str  # "AVAILABLE", "ALREADY_MARKED", "LOCKED"
    can_mark: bool
    lock_reason: Optional[str] = None
    session_id: Optional[int] = None

class AvailablePeriodsResponse(BaseModel):
    today_date: str
    today_day: str
    yesterday_date: str
    yesterday_day: str
    current_time: str
    today_periods: List[AvailablePeriodItem]
    yesterday_periods: List[AvailablePeriodItem]

class StudentRosterItem(BaseModel):
    student_id: int
    roll_number: str
    full_name: str
    email: Optional[str] = None
    attendance_status: str  # "PRESENT", "ABSENT", "OD", "UNMARKED"
    od_reason: Optional[str] = None

class FacultyAttendanceRosterResponse(BaseModel):
    timetable_entry_id: int
    date: str
    day_of_week: str
    period_id: int
    period_number: int
    period_name: str
    start_time: str
    end_time: str
    subject_code: str
    subject_name: str
    class_id: int
    class_name: str
    faculty_name: str
    status: str
    can_mark: bool
    lock_reason: Optional[str] = None
    session_id: Optional[int] = None
    already_marked: bool
    roster: List[StudentRosterItem]

class AttendanceStudentSubmission(BaseModel):
    student_id: int
    status: AttendanceStatus
    od_reason: Optional[str] = None

class FacultyAttendanceSubmitRequest(BaseModel):
    timetable_entry_id: int
    date: str  # YYYY-MM-DD
    records: List[AttendanceStudentSubmission]

class FacultyAttendanceSubmitResponse(BaseModel):
    message: str
    session_id: int
    date: str
    period_number: int
    records_count: int
    status: str

# ─────────────────────────────────────────────────────────────
# Class Advisor Schemas
# ─────────────────────────────────────────────────────────────

class LunchBreakInfo(BaseModel):
    start_time: str = "12:50"
    end_time: str = "13:40"
    label: str = "Lunch Break (12:50 PM - 01:40 PM)"
    note: str = "Institutional break — strictly excluded from attendance marking and calculations."
    is_attendance_period: bool = False

class AdvisedClassInfo(BaseModel):
    id: int
    name: str
    class_id: Optional[int] = None
    class_name: Optional[str] = None
    academic_year: Optional[str] = None
    grade_level: Optional[str] = None

class ClassAdvisorPeriodItem(BaseModel):
    timetable_entry_id: int
    period_id: int
    period_number: int
    period_name: str
    start_time: str
    end_time: str
    session_type: str  # "MORNING" or "AFTERNOON"
    subject_code: str
    subject_name: str
    class_id: int
    class_name: str
    date: str
    day_of_week: str
    subject_faculty_name: str
    status: str
    can_mark: bool
    lock_reason: Optional[str] = None
    session_id: Optional[int] = None
    record_count: Optional[int] = 0

class ClassAdvisorAvailablePeriodsResponse(BaseModel):
    is_class_advisor: bool
    advised_class: Optional[AdvisedClassInfo] = None
    today_date: str
    today_day: str
    yesterday_date: str
    yesterday_day: str
    current_time: str
    day_end_time: str = "16:10"
    today_periods: List[ClassAdvisorPeriodItem] = []
    yesterday_periods: List[ClassAdvisorPeriodItem] = []
    lunch_break: LunchBreakInfo = LunchBreakInfo()

class ClassAdvisorAttendanceRosterResponse(BaseModel):
    timetable_entry_id: int
    date: str
    day_of_week: str
    period_id: int
    period_number: int
    period_name: str
    start_time: str
    end_time: str
    subject_code: str
    subject_name: str
    class_id: int
    class_name: str
    subject_faculty_name: str
    status: str
    can_mark: bool
    session_id: Optional[int] = None
    already_marked: bool
    last_updated_at: Optional[str] = None
    roster: List[StudentRosterItem]

class ClassAdvisorAttendanceSubmitRequest(BaseModel):
    timetable_entry_id: int
    date: str  # YYYY-MM-DD
    records: List[AttendanceStudentSubmission]
    expected_last_updated: Optional[str] = None

class ClassDailyStudentSummary(BaseModel):
    student_id: int
    roll_number: str
    full_name: str
    morning_status: str
    morning_text: str
    afternoon_status: str
    afternoon_text: str
    daily_result: str

class ClassDailySummaryResponse(BaseModel):
    class_id: int
    class_name: str
    date: str
    total_students: int
    full_day_present_count: int
    half_day_present_count: int
    full_day_absent_count: int
    od_count: int
    not_entered_count: int
    partial_count: int
    lunch_interval: str = "12:50 PM - 01:40 PM (Not Counted)"
    students: List[ClassDailyStudentSummary] = []

class ClassAdvisorAttendanceSubmitResponse(BaseModel):
    message: str
    session_id: int
    date: str
    period_number: int
    records_count: int
    total_submitted: Optional[int] = None
    updated_at: Optional[str] = None
    status: str
    daily_summary: Optional[ClassDailySummaryResponse] = None


# ─────────────────────────────────────────────────────────────
# Faculty Attendance View & Report Schemas
# ─────────────────────────────────────────────────────────────

class AuthorizedSubjectOption(BaseModel):
    id: int
    code: str
    name: str
    is_teaching: bool = True

class AuthorizedClassOption(BaseModel):
    id: int
    name: str
    grade_level: Optional[str] = None
    academic_year: Optional[str] = None
    is_advisor_for_class: bool = False
    subjects: List[AuthorizedSubjectOption] = []

class FacultyAuthorizedReportOptionsResponse(BaseModel):
    faculty_id: int
    faculty_name: str
    is_class_advisor: bool = False
    advised_class: Optional[AdvisedClassInfo] = None
    classes: List[AuthorizedClassOption] = []
    current_date: Optional[str] = None
    attendance_start_date: Optional[str] = None

class FacultyStudentAttendanceRow(BaseModel):
    student_id: int
    roll_number: str
    full_name: str
    total: int
    present: int
    pure_present: int = 0
    absent: int
    od: int
    percentage: float

class FacultyClassSummaryResponse(BaseModel):
    class_id: int
    class_name: str
    subject_id: Optional[int] = None
    subject_code: Optional[str] = None
    subject_name: Optional[str] = None
    is_class_advisor_scope: bool = False
    total_periods: int
    total_students: int = 0
    present: int
    pure_present: int = 0
    absent: int
    od: int
    total_marks: int = 0
    percentage: float
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    date_range_display: Optional[str] = None
    is_sunday: bool = False
    has_scheduled_classes: bool = True
    no_class_message: Optional[str] = None
    students: List[FacultyStudentAttendanceRow] = []

class FacultyStudentReportPeriodItem(BaseModel):
    period_number: int
    period_name: str
    subject_code: Optional[str] = None
    subject_name: Optional[str] = None
    faculty_name: Optional[str] = None
    status: str
    od_reason: Optional[str] = None

class FacultyStudentReportDateEntry(BaseModel):
    date: str
    morning_status: Optional[str] = None
    morning_summary: Optional[str] = None
    afternoon_status: Optional[str] = None
    afternoon_summary: Optional[str] = None
    daily_result: Optional[str] = None
    lunch_interval: str = "12:50 PM - 01:40 PM (Not Counted)"
    periods: List[FacultyStudentReportPeriodItem] = []

class FacultyStudentDetailResponse(BaseModel):
    student_id: int
    roll_number: str
    full_name: str
    class_id: int
    class_name: str
    subject_id: Optional[int] = None
    subject_code: Optional[str] = None
    subject_name: Optional[str] = None
    total: int
    present: int
    absent: int
    od: int
    percentage: float
    date_wise: List[FacultyStudentReportDateEntry] = []

class DateMatrixPeriodHeader(BaseModel):
    period_number: int
    period_name: str
    start_time: str
    end_time: str
    subject_code: Optional[str] = None
    subject_name: Optional[str] = None
    faculty_name: Optional[str] = None
    status: str
    present_count: int = 0
    absent_count: int = 0
    od_count: int = 0
    total_marked: int = 0

class DateMatrixStudentRow(BaseModel):
    student_id: int
    roll_number: str
    full_name: str
    period_statuses: dict = {}
    morning_status: str
    afternoon_status: str
    daily_result: str

class FacultyDateMatrixResponse(BaseModel):
    class_id: int
    class_name: str
    subject_id: Optional[int] = None
    subject_code: Optional[str] = None
    subject_name: Optional[str] = None
    is_class_advisor_scope: bool = False
    date: str
    day_of_week: str
    periods: List[DateMatrixPeriodHeader] = []
    lunch_break: LunchBreakInfo = LunchBreakInfo()
    students: List[DateMatrixStudentRow] = []

class HistoricalMatrixDateEntry(BaseModel):
    date: str
    day_of_week: str
    periods: List[DateMatrixPeriodHeader] = []
    lunch_break: LunchBreakInfo = LunchBreakInfo()
    students: List[DateMatrixStudentRow] = []
    has_scheduled_classes: bool = True

class FacultyHistoricalMatrixResponse(BaseModel):
    class_id: int
    class_name: str
    subject_id: Optional[int] = None
    subject_code: Optional[str] = None
    subject_name: Optional[str] = None
    is_class_advisor_scope: bool = False
    attendance_start_date: str
    current_date: str
    start_date: str
    end_date: str
    total_dates: int
    dates: List[HistoricalMatrixDateEntry] = []
    students: List[FacultyStudentAttendanceRow] = []

class FacultyPeriodsForDateResponse(BaseModel):
    date: str
    day_of_week: str
    is_today: bool
    periods: List[AvailablePeriodItem] = []

class ClassAdvisorPeriodsForDateResponse(BaseModel):
    is_class_advisor: bool
    advised_class: Optional[AdvisedClassInfo] = None
    date: str
    day_of_week: str
    is_today: bool
    periods: List[ClassAdvisorPeriodItem] = []
    lunch_break: LunchBreakInfo = LunchBreakInfo()

class BatchRecognizedStudent(BaseModel):
    student_id: int
    roll_number: str
    name: str
    best_distance: float
    best_confidence: float
    recognized_in_photos_count: int
    source_photos: List[str] = []

class BatchPhotoSummary(BaseModel):
    filename: str
    faces_detected: int
    recognized_count: int
    status: str  # "SUCCESS", "NO_FACES", "ERROR"
    error_detail: Optional[str] = None

class BatchRecognitionResponse(BaseModel):
    total_photos: int
    photos_processed: int
    photos_failed: int
    total_faces_detected: int
    unique_recognized_count: int
    recognized_students: List[BatchRecognizedStudent] = []
    photo_summaries: List[BatchPhotoSummary] = []
