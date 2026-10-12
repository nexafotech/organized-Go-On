"""PDF renderer for the date-range attendance report (Phase 9).

Renders an already-built ``AttendanceRangeReport`` with ReportLab. It performs
NO attendance calculation and runs NO database queries.

Layout: A4 portrait, 15 mm margins, bordered tables with repeated header rows,
"Page X of Y" footer, wrapped student names (no clipped columns).
"""
from __future__ import annotations

import io
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.platypus import (
    Image,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

from app.services.attendance_report_service import (
    AttendanceRangeReport,
    format_date_dmy,
    status_label,
)
from app.services.report_branding import BRAND_NAME, badge_path

PDF_MEDIA_TYPE = "application/pdf"

_ESPRESSO = colors.HexColor("#4E342E")
_CREAM = colors.HexColor("#F7F1E8")
_GRID = colors.HexColor("#BFB3A5")
_ZEBRA = colors.HexColor("#FBF8F3")

_PAGE_W, _PAGE_H = A4
_MARGIN = 15 * mm
_CONTENT_W = _PAGE_W - 2 * _MARGIN


class _NumberedCanvas(canvas.Canvas):
    """Two-pass canvas so the footer can print 'Page X of Y'."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        total = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self._draw_footer(total)
            super().showPage()
        super().save()

    def _draw_footer(self, total: int) -> None:
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#6D5D52"))
        self.drawString(_MARGIN, 9 * mm, "Confidential - contains student attendance data")
        self.drawRightString(_PAGE_W - _MARGIN, 9 * mm, f"Page {self._pageNumber} of {total}")


def _styles():
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle("t", parent=base["Title"], fontName="Helvetica-Bold", fontSize=18,
                                textColor=_ESPRESSO, alignment=TA_CENTER, spaceAfter=2),
        "sub": ParagraphStyle("s", parent=base["Normal"], fontName="Helvetica", fontSize=10,
                              textColor=colors.HexColor("#6D5D52"), alignment=TA_CENTER, spaceAfter=8),
        "h2": ParagraphStyle("h2", parent=base["Heading2"], fontName="Helvetica-Bold", fontSize=12,
                             textColor=_ESPRESSO, spaceBefore=8, spaceAfter=4),
        "cell": ParagraphStyle("c", parent=base["Normal"], fontName="Helvetica", fontSize=8.5, leading=10.5),
        "cellb": ParagraphStyle("cb", parent=base["Normal"], fontName="Helvetica-Bold", fontSize=8.5, leading=10.5),
        "hdr": ParagraphStyle("h", parent=base["Normal"], fontName="Helvetica-Bold", fontSize=8.5, leading=10.5,
                              textColor=colors.white, alignment=TA_CENTER),
        "note": ParagraphStyle("n", parent=base["Normal"], fontName="Helvetica-Oblique", fontSize=8,
                               textColor=colors.HexColor("#6D5D52"), spaceBefore=4),
    }


def _p(text: str, style) -> Paragraph:
    return Paragraph(escape(str(text)), style)


def _pct(v) -> str:
    return "N/A" if v is None else f"{v:.2f}%"


def _table_style(num_cols_right=()) -> TableStyle:
    cmds = [
        ("BACKGROUND", (0, 0), (-1, 0), _ESPRESSO),
        ("GRID", (0, 0), (-1, -1), 0.5, _GRID),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, _ZEBRA]),
    ]
    for c in num_cols_right:
        cmds.append(("ALIGN", (c, 1), (c, -1), "CENTER"))
    return TableStyle(cmds)


def _brand_header(report: AttendanceRangeReport, st) -> Table:
    """Go-On logo badge + name + report title + institution, with a thin rule."""
    base = getSampleStyleSheet()["Normal"]
    brand = ParagraphStyle("brand", parent=base, fontName="Helvetica-Bold", fontSize=20,
                           leading=22, textColor=_ESPRESSO)
    title = ParagraphStyle("brand_title", parent=base, fontName="Helvetica-Bold", fontSize=11,
                           leading=13, textColor=colors.HexColor("#6D5D52"))
    sub = ParagraphStyle("brand_sub", parent=base, fontName="Helvetica", fontSize=9,
                         leading=11, textColor=colors.HexColor("#6D5D52"))
    text_cell = [
        Paragraph(escape(BRAND_NAME), brand),
        Paragraph("ATTENDANCE REPORT", title),
        Paragraph(escape(report.institution), sub),
    ]

    logo_path = badge_path()
    logo_size = 17 * mm
    if logo_path is not None:
        # Square source + square box => correct aspect ratio, never distorted.
        logo = Image(str(logo_path), width=logo_size, height=logo_size)
        rows = [[logo, text_cell]]
        widths = [logo_size + 4 * mm, _CONTENT_W - logo_size - 4 * mm]
    else:
        rows = [[text_cell]]
        widths = [_CONTENT_W]

    tbl = Table(rows, colWidths=widths)
    tbl.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
        ("TOPPADDING", (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("LINEBELOW", (0, 0), (-1, -1), 1, _ESPRESSO),
    ]))
    return tbl


def render_pdf(report: AttendanceRangeReport, compress: bool = True) -> bytes:
    st = _styles()
    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf, pagesize=A4,
        leftMargin=_MARGIN, rightMargin=_MARGIN, topMargin=_MARGIN, bottomMargin=16 * mm,
        title=f"{BRAND_NAME} Attendance Report - {report.class_name}",
        author=report.institution,
        subject=report.subject_label,
        pageCompression=1 if compress else 0,
    )
    story = []

    # ── Header ──────────────────────────────────────────────
    story.append(_brand_header(report, st))
    story.append(Spacer(1, 4 * mm))

    meta = [
        [_p("Class", st["cellb"]), _p(report.class_name, st["cell"]),
         _p("From Date", st["cellb"]), _p(format_date_dmy(report.from_date), st["cell"])],
        [_p("Subject", st["cellb"]), _p(report.subject_label, st["cell"]),
         _p("To Date", st["cellb"]), _p(format_date_dmy(report.to_date), st["cell"])],
        [_p("Students", st["cellb"]), _p(str(report.student_count), st["cell"]),
         _p("Generated", st["cellb"]), _p(report.generated_at.strftime("%d-%m-%Y %H:%M"), st["cell"])],
    ]
    meta_tbl = Table(meta, colWidths=[22 * mm, _CONTENT_W / 2 - 22 * mm, 24 * mm, _CONTENT_W / 2 - 24 * mm])
    meta_tbl.setStyle(TableStyle([
        ("BOX", (0, 0), (-1, -1), 0.75, _GRID),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, _GRID),
        ("BACKGROUND", (0, 0), (0, -1), _CREAM),
        ("BACKGROUND", (2, 0), (2, -1), _CREAM),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]))
    story.append(meta_tbl)
    if report.scope_note:
        story.append(Paragraph(escape(report.scope_note), st["note"]))

    # ── Summary (student-wise) ──────────────────────────────
    story.append(Paragraph("STUDENT-WISE SUMMARY", st["h2"]))
    hdr = [_p(h, st["hdr"]) for h in
           ["Register No", "Student", "Present", "Absent", "OD", "Total", "Attendance %"]]
    rows = [hdr]
    for s in report.summary:
        rows.append([
            _p(s.roll_number, st["cell"]), _p(s.full_name, st["cell"]),
            str(s.present), str(s.absent), str(s.od), str(s.total_marked), _pct(s.percentage),
        ])
    rows.append([
        _p("TOTAL", st["cellb"]), "",
        str(report.present), str(report.absent), str(report.od),
        str(report.total_marked), _pct(report.percentage),
    ])
    widths = [30 * mm, 62 * mm, 17 * mm, 17 * mm, 14 * mm, 17 * mm, 23 * mm]
    summary_tbl = Table(rows, colWidths=widths, repeatRows=1)
    ts = _table_style(num_cols_right=(2, 3, 4, 5, 6))
    ts.add("BACKGROUND", (0, len(rows) - 1), (-1, len(rows) - 1), _CREAM)
    ts.add("FONTNAME", (0, len(rows) - 1), (-1, len(rows) - 1), "Helvetica-Bold")
    summary_tbl.setStyle(ts)
    story.append(summary_tbl)
    story.append(Paragraph(escape(report.percentage_basis), st["note"]))
    story.append(Paragraph(
        "Only persisted attendance entries are counted. Periods with no attendance entry are not counted as absent.",
        st["note"],
    ))

    # ── Detailed attendance ─────────────────────────────────
    story.append(PageBreak())
    story.append(Paragraph("DETAILED ATTENDANCE", st["h2"]))
    dhdr = [_p(h, st["hdr"]) for h in ["Date", "Period", "Subject", "Register No", "Student", "Status"]]
    drows = [dhdr]
    for d in report.details:
        drows.append([
            format_date_dmy(d.date), f"P{d.period_number}",
            _p(d.subject_code, st["cell"]), _p(d.roll_number, st["cell"]),
            _p(d.full_name, st["cell"]), status_label(d.status),
        ])
    dwidths = [21 * mm, 14 * mm, 22 * mm, 30 * mm, 66 * mm, 27 * mm]
    detail_tbl = Table(drows, colWidths=dwidths, repeatRows=1)
    detail_tbl.setStyle(_table_style(num_cols_right=(0, 1, 5)))
    story.append(detail_tbl)

    doc.build(story, canvasmaker=_NumberedCanvas)
    return buf.getvalue()
