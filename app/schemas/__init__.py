from app.schemas.auth import LoginRequest, Token, UserOut
from app.schemas.user import FacultyCreate, FacultyUpdate, FacultyOut
from app.schemas.student import StudentCreate, StudentUpdate, StudentOut
from app.schemas.academic import (
    ClassSectionCreate, ClassSectionOut,
    SubjectCreate, SubjectOut,
    PeriodCreate, PeriodOut,
    FacultyAssignmentCreate, FacultyAssignmentOut,
    TimetableEntryCreate, TimetableEntryOut
)

__all__ = [
    "LoginRequest", "Token", "UserOut",
    "FacultyCreate", "FacultyUpdate", "FacultyOut",
    "StudentCreate", "StudentUpdate", "StudentOut",
    "ClassSectionCreate", "ClassSectionOut",
    "SubjectCreate", "SubjectOut",
    "PeriodCreate", "PeriodOut",
    "FacultyAssignmentCreate", "FacultyAssignmentOut",
    "TimetableEntryCreate", "TimetableEntryOut"
]
