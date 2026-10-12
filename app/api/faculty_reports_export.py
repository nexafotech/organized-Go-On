"""
Faculty / Class Advisor date-range attendance report endpoints (Phase 9).

Follows the existing ``/faculty/reports/*`` conventions:
  GET /api/v1/faculty/reports/range          -> JSON dataset (preview / empty-state check)
  GET /api/v1/faculty/reports/range/pdf      -> application/pdf (attachment)
  GET /api/v1/faculty/reports/range/excel    -> .xlsx (attachment)

All three call the SAME dataset builder, so the numbers cannot diverge.
Authorization is evaluated server-side before any data is read; downloads are
authenticated (Bearer token) - there is no public/unauthenticated file URL and
nothing is written to disk.
"""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from sqlalchemy.orm import Session

from app.api.deps import require_faculty
from app.core.database import get_db
from app.models.audit import AuditLog
from app.models.user import User
from app.schemas.attendance_range_report import (
    AttendanceRangeReportResponse,
    RangePeriodSummary,
    RangeStudentSummary,
)
from app.services.attendance_report_excel import XLSX_MEDIA_TYPE, render_excel
from app.services.attendance_report_pdf import PDF_MEDIA_TYPE, render_pdf
from app.services.attendance_report_service import (
    MAX_PDF_DETAIL_ROWS,
    AttendanceRangeReport,
    build_attendance_range_report,
    build_report_filename,
    parse_and_validate_range,
    resolve_report_scope,
)

logger = logging.getLogger("attendance.report")

router = APIRouter(
    prefix="/faculty/reports/range",
    tags=["Faculty Attendance Range Reports"],
    dependencies=[Depends(require_faculty)],
)


def _no_records_error(report: AttendanceRangeReport) -> HTTPException:
    return HTTPException(
        status_code=404,
        detail={
            "code": "NO_RECORDS_AVAILABLE",
            "message": (
                f"No attendance records were found between "
                f"{report.from_date:%d %b %Y} and {report.to_date:%d %b %Y}."
            ),
        },
    )


def _build(
    db: Session,
    user: User,
    class_id: int,
    subject_id: Optional[int],
    from_date: str,
    to_date: str,
    include_details: bool,
) -> AttendanceRangeReport:
    # Order matters: validate input, then authorize, then read data.
    f, t = parse_and_validate_range(from_date, to_date)
    scope = resolve_report_scope(db, user, class_id, subject_id)
    return build_attendance_range_report(db, scope, f, t, include_details=include_details)


def _audit(db: Session, request: Request, user: User, fmt: str, report: AttendanceRangeReport, class_id: int) -> None:
    """Best-effort audit trail for exports of student attendance data."""
    try:
        db.add(AuditLog(
            user_id=user.id,
            action="ATTENDANCE_REPORT_EXPORT",
            target=f"class_id={class_id}",
            details=(
                f"format={fmt}; subject={report.subject_code or 'ALL'}; "
                f"range={report.from_date.isoformat()}..{report.to_date.isoformat()}; "
                f"students={report.student_count}; marked={report.total_marked}"
            ),
            ip_address=request.client.host if request.client else None,
        ))
        db.commit()
    except Exception:  # never fail the download because auditing failed
        db.rollback()
        logger.warning("audit log write failed for attendance report export", exc_info=True)


def _file_response(content: bytes, media_type: str, filename: str) -> Response:
    return Response(
        content=content,
        media_type=media_type,
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Cache-Control": "no-store, private",
            "Pragma": "no-cache",
            "X-Content-Type-Options": "nosniff",
            "Access-Control-Expose-Headers": "Content-Disposition",
        },
    )


@router.get("", response_model=AttendanceRangeReportResponse)
def get_attendance_range_report(
    class_id: int,
    from_date: str,
    to_date: str,
    subject_id: Optional[int] = Query(default=None),
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db),
):
    """Summary + period summary for the range. ``has_records=false`` => show NO RECORDS AVAILABLE."""
    report = _build(db, current_user, class_id, subject_id, from_date, to_date, include_details=False)
    return AttendanceRangeReportResponse(
        class_name=report.class_name,
        subject_label=report.subject_label,
        subject_code=report.subject_code,
        from_date=report.from_date.isoformat(),
        to_date=report.to_date.isoformat(),
        generated_at=report.generated_at.isoformat(timespec="seconds"),
        scope_note=report.scope_note,
        percentage_basis=report.percentage_basis,
        student_count=report.student_count,
        present=report.present,
        absent=report.absent,
        od=report.od,
        total_marked=report.total_marked,
        percentage=report.percentage,
        has_records=report.has_records,
        summary=[RangeStudentSummary(**vars(s)) for s in report.summary],
        period_summary=[
            RangePeriodSummary(**{**vars(p), "date": p.date.isoformat()}) for p in report.period_summary
        ],
    )


@router.get("/pdf")
def download_attendance_range_pdf(
    request: Request,
    class_id: int,
    from_date: str,
    to_date: str,
    subject_id: Optional[int] = Query(default=None),
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db),
):
    report = _build(db, current_user, class_id, subject_id, from_date, to_date, include_details=True)
    if not report.has_records:
        raise _no_records_error(report)
    if len(report.details) > MAX_PDF_DETAIL_ROWS:
        raise HTTPException(
            status_code=413,
            detail="This report is too large for PDF. Please choose a shorter date range or use the Excel export.",
        )
    try:
        content = render_pdf(report)
    except Exception:
        logger.exception("PDF generation failed class_id=%s range=%s..%s", class_id, report.from_date, report.to_date)
        raise HTTPException(status_code=500, detail="Failed to generate the PDF report. Please try again.")
    _audit(db, request, current_user, "pdf", report, class_id)
    return _file_response(content, PDF_MEDIA_TYPE, build_report_filename(report, "pdf"))


@router.get("/excel")
def download_attendance_range_excel(
    request: Request,
    class_id: int,
    from_date: str,
    to_date: str,
    subject_id: Optional[int] = Query(default=None),
    current_user: User = Depends(require_faculty),
    db: Session = Depends(get_db),
):
    report = _build(db, current_user, class_id, subject_id, from_date, to_date, include_details=True)
    if not report.has_records:
        raise _no_records_error(report)
    try:
        content = render_excel(report)
    except Exception:
        logger.exception("Excel generation failed class_id=%s range=%s..%s", class_id, report.from_date, report.to_date)
        raise HTTPException(status_code=500, detail="Failed to generate the Excel report. Please try again.")
    _audit(db, request, current_user, "excel", report, class_id)
    return _file_response(content, XLSX_MEDIA_TYPE, build_report_filename(report, "xlsx"))
