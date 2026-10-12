from typing import List, Optional

from pydantic import BaseModel


class RangeStudentSummary(BaseModel):
    roll_number: str
    full_name: str
    present: int
    absent: int
    od: int
    total_marked: int
    percentage: Optional[float] = None  # None => no marked entries (not 0%)


class RangePeriodSummary(BaseModel):
    date: str  # YYYY-MM-DD
    period_number: int
    period_name: str
    subject_code: str
    subject_name: str
    present: int
    absent: int
    od: int
    total_marked: int


class AttendanceRangeReportResponse(BaseModel):
    """JSON view of the SAME dataset that feeds the PDF and Excel exports."""
    class_name: str
    subject_label: str
    subject_code: Optional[str] = None
    from_date: str
    to_date: str
    generated_at: str
    scope_note: Optional[str] = None
    percentage_basis: str
    student_count: int
    present: int
    absent: int
    od: int
    total_marked: int
    percentage: Optional[float] = None
    has_records: bool
    summary: List[RangeStudentSummary]
    period_summary: List[RangePeriodSummary]
