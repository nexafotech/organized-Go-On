from pydantic import BaseModel
from typing import Optional, List

# Class Section Schemas
class ClassSectionCreate(BaseModel):
    name: str
    grade_level: Optional[str] = None
    academic_year: Optional[str] = None

class ClassSectionUpdate(BaseModel):
    name: Optional[str] = None
    grade_level: Optional[str] = None
    academic_year: Optional[str] = None

class ClassSectionOut(BaseModel):
    id: int
    name: str
    grade_level: Optional[str] = None
    academic_year: Optional[str] = None
    student_count: Optional[int] = 0
    class_advisor_id: Optional[int] = None
    class_advisor_name: Optional[str] = None
    class_advisor_employee_id: Optional[str] = None

    class Config:
        from_attributes = True

class ClassAdvisorAssignRequest(BaseModel):
    faculty_id: int

# Subject Schemas
class SubjectCreate(BaseModel):
    code: str
    name: str
    description: Optional[str] = None

class SubjectUpdate(BaseModel):
    code: Optional[str] = None
    name: Optional[str] = None
    description: Optional[str] = None

class SubjectOut(BaseModel):
    id: int
    code: str
    name: str
    description: Optional[str] = None

    class Config:
        from_attributes = True

# Period Schemas
class PeriodCreate(BaseModel):
    period_number: int
    name: str
    start_time: str  # "HH:MM"
    end_time: str    # "HH:MM"

class PeriodOut(BaseModel):
    id: int
    period_number: int
    name: str
    start_time: str
    end_time: str

    class Config:
        from_attributes = True

# Faculty Assignment Schemas
class FacultyAssignmentCreate(BaseModel):
    faculty_id: Optional[int] = None
    subject_id: int
    class_id: int
    authorized_faculty_ids: Optional[List[int]] = None

class FacultyAssignmentUpdate(BaseModel):
    faculty_id: Optional[int] = None
    subject_id: Optional[int] = None
    class_id: Optional[int] = None
    authorized_faculty_ids: Optional[List[int]] = None

class FacultyAssignmentOut(BaseModel):
    id: int
    faculty_id: Optional[int] = None
    faculty_name: Optional[str] = None
    primary_faculty_name: Optional[str] = None
    authorized_faculty_names: Optional[List[str]] = None
    authorized_faculty_ids: Optional[List[int]] = None
    subject_id: int
    subject_code: Optional[str] = None
    subject_name: Optional[str] = None
    class_id: int
    class_name: Optional[str] = None
    is_assigned: bool = False
    timetable_count: int = 0

    class Config:
        from_attributes = True

# Timetable Entry Schemas
class TimetableEntryCreate(BaseModel):
    day_of_week: str  # Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday
    period_id: int
    assignment_id: Optional[int] = None
    class_id: Optional[int] = None
    subject_id: Optional[int] = None
    faculty_id: Optional[int] = None
    room: Optional[str] = None

class TimetableEntryUpdate(BaseModel):
    day_of_week: Optional[str] = None
    period_id: Optional[int] = None
    assignment_id: Optional[int] = None
    class_id: Optional[int] = None
    subject_id: Optional[int] = None
    faculty_id: Optional[int] = None
    room: Optional[str] = None

class TimetableMoveRequest(BaseModel):
    target_day_of_week: str
    target_period_id: int

class TimetableDuplicateRequest(BaseModel):
    target_day_of_week: str
    target_period_id: int

class TimetableEntryOut(BaseModel):
    id: int
    day_of_week: str
    period_id: int
    period_number: Optional[int] = None
    period_name: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    assignment_id: Optional[int] = None
    class_id: Optional[int] = None
    class_name: Optional[str] = None
    subject_id: Optional[int] = None
    subject_code: Optional[str] = None
    subject_name: Optional[str] = None
    faculty_id: Optional[int] = None
    faculty_name: Optional[str] = None
    authorized_faculty_names: Optional[List[str]] = None
    room: Optional[str] = None

    class Config:
        from_attributes = True

# Class Session Schemas
class ClassSessionCreate(BaseModel):
    timetable_entry_id: Optional[int] = None
    faculty_id: int
    date: str  # YYYY-MM-DD
    status: Optional[str] = "SCHEDULED"

class ClassSessionUpdate(BaseModel):
    date: Optional[str] = None
    faculty_id: Optional[int] = None
    status: Optional[str] = None

class ClassSessionOut(BaseModel):
    id: int
    timetable_entry_id: Optional[int] = None
    faculty_id: int
    faculty_name: Optional[str] = None
    date: str
    status: str
    subject_code: Optional[str] = None
    subject_name: Optional[str] = None
    class_name: Optional[str] = None
    attendance_count: Optional[int] = 0
    start_timestamp: Optional[str] = None
    end_timestamp: Optional[str] = None

    class Config:
        from_attributes = True

# Attendance Record Schemas
class AttendanceRecordOut(BaseModel):
    id: int
    session_id: int
    student_id: int
    student_roll: Optional[str] = None
    student_name: Optional[str] = None
    class_name: Optional[str] = None
    subject_code: Optional[str] = None
    subject_name: Optional[str] = None
    session_date: Optional[str] = None
    status: str
    confidence: Optional[float] = None
    recognized_via: str
    review_status: str
    od_reason: Optional[str] = None
    marked_by_name: Optional[str] = None
    marked_at: Optional[str] = None

    class Config:
        from_attributes = True

class AttendanceManualCreate(BaseModel):
    session_id: int
    student_id: int
    status: str = "PRESENT"
    od_reason: Optional[str] = None

class AttendanceUpdate(BaseModel):
    status: str
    review_status: Optional[str] = None
    od_reason: Optional[str] = None

# Biometric Management Schemas
class BiometricStudentSummaryOut(BaseModel):
    student_id: int
    roll_number: str
    full_name: str
    class_name: Optional[str] = None
    enrolled: bool
    template_count: int
    model_name: Optional[str] = None
    model_version: Optional[str] = None
    dimension: Optional[int] = None
    detector_name: Optional[str] = None
    distance_metric: Optional[str] = None
    quality_score: Optional[float] = None
    last_enrollment_at: Optional[str] = None

class BiometricOverviewOut(BaseModel):
    total_students: int
    enrolled_count: int
    pending_count: int
    model_name: str
    model_version: str
    dimension: int
    detector_name: str
    distance_metric: str


# Phase 7.7: Folder-Based Face Enrollment Schemas
class FolderEnrollmentResultItem(BaseModel):
    filename: str
    status: str
    reason: Optional[str] = None
    faces_detected: int = 0
    embedding_id: Optional[int] = None

class FolderStudentEnrollmentResult(BaseModel):
    roll_number: str
    student_id: Optional[int] = None
    full_name: Optional[str] = None
    class_name: Optional[str] = None
    status: str
    total_files: int
    valid_enrolled: int
    rejected: int
    replaced_old_count: int = 0
    message: str
    items: List[FolderEnrollmentResultItem] = []

class FolderEnrollmentBatchResponse(BaseModel):
    total_folders: int
    total_files_processed: int
    successful_students: int
    failed_students: int
    total_embeddings_created: int
    message: str
    students: List[FolderStudentEnrollmentResult]

class FolderManifestStudentItem(BaseModel):
    roll_number: str
    student_id: Optional[int] = None
    full_name: Optional[str] = None
    class_name: Optional[str] = None
    exists_in_db: bool
    current_template_count: int = 0
    image_files_count: int
    files: List[str] = []

class FolderManifestResponse(BaseModel):
    folder_path: Optional[str] = None
    total_folders: int
    total_image_files: int
    ignored_non_image_files: int
    students_found_in_db: int
    students_missing_in_db: int
    students: List[FolderManifestStudentItem]

class FolderPathEnrollmentRequest(BaseModel):
    folder_path: str
    replace: bool = False
    append: bool = False
    dry_run: bool = False

# Phase 7.8: Canonical Face Dataset & Multi-Photo Enrollment Schemas
class StudentPhotoItemOut(BaseModel):
    embedding_id: int
    filename: str
    image_path: str
    created_at: Optional[str] = None
    quality_score: Optional[float] = None

class StudentDatasetViewOut(BaseModel):
    student_id: int
    roll_number: str
    full_name: str
    class_name: Optional[str] = None
    enrolled: bool
    photo_count: int
    template_count: int
    photos: List[StudentPhotoItemOut]

class MultiPhotoEnrollmentResultItem(BaseModel):
    filename: str
    status: str
    reason: Optional[str] = None
    faces_detected: int = 0
    embedding_id: Optional[int] = None
    saved_path: Optional[str] = None

class MultiPhotoEnrollmentResponse(BaseModel):
    student_id: int
    roll_number: str
    full_name: str
    total_files: int
    valid_enrolled: int
    rejected: int
    replaced_old_count: int = 0
    message: str
    items: List[MultiPhotoEnrollmentResultItem]


