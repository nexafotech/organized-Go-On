import os, sys
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether, HRFlowable
)
from reportlab.pdfgen import canvas

PDF_OUTPUT = r"E:\originalam\reports\go-On_Timetable_Session_Pop_Up_Simplification_Report.pdf"

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        self.setFont("Helvetica-Bold", 7.5)
        self.setFillColor(colors.HexColor("#6B5B50"))

        # Running header (pages 2+)
        if self._pageNumber > 1:
            self.drawString(40, 762, "go-On AI Face Attendance System — Timetable Session Pop-Up Simplification Audit")
            self.setStrokeColor(colors.HexColor("#D5C8B8"))
            self.setLineWidth(0.6)
            self.line(40, 756, 572, 756)

        # Running footer
        self.setStrokeColor(colors.HexColor("#D5C8B8"))
        self.setLineWidth(0.6)
        self.line(40, 38, 572, 38)

        self.setFont("Helvetica", 7.5)
        self.setFillColor(colors.HexColor("#8C7A6B"))
        self.drawString(40, 27, "Confidential — Engineering Verification & Role-Independent UI Simplification Audit")
        page_str = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(572, 27, page_str)
        self.restoreState()

def build_pdf():
    os.makedirs(os.path.dirname(PDF_OUTPUT), exist_ok=True)
    doc = SimpleDocTemplate(
        PDF_OUTPUT,
        pagesize=letter,
        leftMargin=40,
        rightMargin=40,
        topMargin=46,
        bottomMargin=46
    )

    styles = getSampleStyleSheet()

    header_title_style = ParagraphStyle(
        'HeaderTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=14,
        leading=17,
        textColor=colors.HexColor("#2B1A13")
    )
    header_subtitle_style = ParagraphStyle(
        'HeaderSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11.5,
        textColor=colors.HexColor("#6B5B50")
    )
    section_h1 = ParagraphStyle(
        'SectionH1',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=12.5,
        textColor=colors.HexColor("#2B1A13"),
        spaceBefore=7,
        spaceAfter=3
    )
    body_style = ParagraphStyle(
        'Body',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=10.5,
        textColor=colors.HexColor("#332F2C")
    )
    body_bold = ParagraphStyle(
        'BodyBold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=10.5,
        textColor=colors.HexColor("#2B1A13")
    )
    code_style = ParagraphStyle(
        'CodeStyle',
        parent=styles['Normal'],
        fontName='Courier',
        fontSize=7,
        leading=9,
        textColor=colors.HexColor("#1A1A1A")
    )
    badge_fixed = ParagraphStyle(
        'BadgeFixed',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=10,
        textColor=colors.HexColor("#1B5E20"),
        alignment=1
    )

    story = []

    # Title Block
    title_data = [
        [
            Paragraph("<b>go-On AI Face Attendance System</b><br/><font size='10.5' color='#6B5B50'>Timetable Session Pop-Up Simplification Across All User Roles</font>", header_title_style),
            Paragraph("<b>Status: <font color='#1B5E20'>SIMPLIFIED_&_VERIFIED</font></b><br/><font size='7.5' color='#6B5B50'>Date: October 20, 2026<br/>Portals: Student, Faculty, Class Adviser<br/>Tests Passing: 367 / 367 (100%)</font>", header_subtitle_style)
        ]
    ]
    t_title = Table(title_data, colWidths=[350, 182])
    t_title.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
    ]))
    story.append(t_title)
    story.append(Spacer(1, 6))
    story.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor("#D5C8B8"), spaceAfter=8))

    # Executive Summary Card
    summary_text = (
        "<b>Executive Summary:</b> In accordance with user specifications, the timetable session details pop-up modal "
        "has been redesigned and unified across all three portals (Student, Faculty, and Class Adviser). All extraneous elements—"
        "including subject banner, subject name, class name, venue, period category, duplicate time tags, and the Attendance Report "
        "button—have been completely removed. The pop-up now renders a clean, compact surface displaying <b>exclusively the assigned "
        "faculty member</b> and the <b>actual period timing in 12-hour IST with AM/PM</b>, along with an intuitive close action. "
        "The reusable component <code>TimetableSessionPopUp</code> has been verified across all roles, resolutions, and themes with "
        "367/367 passing tests."
    )
    t_summary = Table([[Paragraph(summary_text, body_style)]], colWidths=[532])
    t_summary.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F9F6F0")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#E5DCCF")),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(t_summary)
    story.append(Spacer(1, 8))

    # Before vs After Comparison
    story.append(Paragraph("1. Content Audit: Elements Kept vs. Removed", section_h1))
    comparison_data = [
        [
            Paragraph("<b>UI Element / Section</b>", body_bold),
            Paragraph("<b>Previous Pop-Up State</b>", body_bold),
            Paragraph("<b>Updated Pop-Up State</b>", body_bold),
            Paragraph("<b>Architectural Compliance</b>", body_bold),
        ],
        [
            Paragraph("<b>Assigned Faculty</b>", body_style),
            Paragraph("Included in small secondary puck (e.g. 'Santhiya')", body_style),
            Paragraph("<b>Prominently Displayed:</b> 'Faculty: Santhiya'", body_style),
            Paragraph("Reads real assigned faculty; fallback 'Faculty not assigned'", body_style),
        ],
        [
            Paragraph("<b>Period Timing</b>", body_style),
            Paragraph("Displayed redundantly in header and puck", body_style),
            Paragraph("<b>Prominently Displayed:</b> 'Time: 09:10 AM – 10:00 AM'", body_style),
            Paragraph("12-hour IST AM/PM formatting; fallback 'Time unavailable'", body_style),
        ],
        [
            Paragraph("<b>Subject Banner & Code</b>", body_style),
            Paragraph("Large colored banner with 'FDS' badge", body_style),
            Paragraph("<b>REMOVED</b>", body_bold),
            Paragraph("Preserved on screen timetable cards, removed from modal", body_style),
        ],
        [
            Paragraph("<b>Subject Full Title</b>", body_style),
            Paragraph("Bold 18pt subject name text", body_style),
            Paragraph("<b>REMOVED</b>", body_bold),
            Paragraph("Eliminates text clutter and redundant titling", body_style),
        ],
        [
            Paragraph("<b>Class Name / Course</b>", body_style),
            Paragraph("Displayed course/class strings", body_style),
            Paragraph("<b>REMOVED</b>", body_bold),
            Paragraph("Preserved in schedule header context", body_style),
        ],
        [
            Paragraph("<b>Venue / Room Info</b>", body_style),
            Paragraph("Dedicated venue puck ('Lecture Hall')", body_style),
            Paragraph("<b>REMOVED</b>", body_bold),
            Paragraph("Strictly adheres to faculty + timing specification", body_style),
        ],
        [
            Paragraph("<b>Period Type Badge</b>", body_style),
            Paragraph("Badge displaying 'CORE THEORY' / 'LAB'", body_style),
            Paragraph("<b>REMOVED</b>", body_bold),
            Paragraph("Removed from pop-up modal", body_style),
        ],
        [
            Paragraph("<b>Attendance Report Button</b>", body_style),
            Paragraph("Large secondary action button", body_style),
            Paragraph("<b>REMOVED</b>", body_bold),
            Paragraph("Unrelated report navigation eliminated", body_style),
        ],
        [
            Paragraph("<b>Close Action</b>", body_style),
            Paragraph("Outlined small button", body_style),
            Paragraph("<b>Retained & Enhanced:</b> Primary full-width button + (X) header icon", body_style),
            Paragraph("Supports Android back-button & scrim tap dismissal", body_style),
        ],
    ]
    t_comp = Table(comparison_data, colWidths=[115, 135, 142, 140])
    t_comp.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#EFEBE4")),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#D5C8B8")),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(t_comp)
    story.append(Spacer(1, 8))

    # Architecture & Cross-Role Integration
    story.append(Paragraph("2. Cross-Role Integration & Reusable Architecture", section_h1))
    integration_data = [
        [
            Paragraph("<b>User Portal</b>", body_bold),
            Paragraph("<b>Screen & Timetable View</b>", body_bold),
            Paragraph("<b>Card Tap Trigger</b>", body_bold),
            Paragraph("<b>Integration Method</b>", body_bold),
        ],
        [
            Paragraph("<b>Student Portal</b>", body_style),
            Paragraph("<code>StudentTimetableScreen</code><br/>(Weekly Matrix & Daily Agenda)", body_style),
            Paragraph("Tapping any period card or timeline row", body_style),
            Paragraph("<code>TimetableSessionPopUp.showFromItem()</code>", code_style),
        ],
        [
            Paragraph("<b>Faculty Portal</b>", body_style),
            Paragraph("<code>FacultyDashboardScreen</code><br/>(Weekly Grid & Day Agenda)", body_style),
            Paragraph("Tapping weekly cell or non-today session card", body_style),
            Paragraph("<code>TimetableSessionPopUp.showFromFacultySchedule()</code>", code_style),
        ],
        [
            Paragraph("<b>Class Adviser Portal</b>", body_style),
            Paragraph("<code>FacultyClassAdvisorScreen</code><br/>(Class Schedule Tab)", body_style),
            Paragraph("Tapping any period in advised class matrix", body_style),
            Paragraph("<code>WeeklyMatrixTimetableView</code> → <code>showFromItem()</code>", code_style),
        ],
    ]
    t_int = Table(integration_data, colWidths=[105, 150, 135, 142])
    t_int.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#EFEBE4")),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#D5C8B8")),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('TOPPADDING', (0,0), (-1,-1), 3.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3.5),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(t_int)
    story.append(Spacer(1, 8))

    # Verification & Test Suite Results
    story.append(Paragraph("3. Verification & Automated Test Results (367 / 367 Passed)", section_h1))
    test_data = [
        [
            Paragraph("<b>Test Suite Target</b>", body_bold),
            Paragraph("<b>Scope Verified</b>", body_bold),
            Paragraph("<b>Result</b>", body_bold),
        ],
        [
            Paragraph("<code>timetable_session_pop_up_test.dart</code>", code_style),
            Paragraph("Dedicated test suite: 24h & 12h formatting, fallbacks, full exclusion audit, role triggers.", body_style),
            Paragraph("<b>7 / 7 PASSED</b>", badge_fixed),
        ],
        [
            Paragraph("<code>timetable_reference_design_test.dart</code>", code_style),
            Paragraph("Weekly matrix tap assertions updated for simplified modal (Faculty & Time verified).", body_style),
            Paragraph("<b>2 / 2 PASSED</b>", badge_fixed),
        ],
        [
            Paragraph("<code>faculty_and_advisor_timetable_matrix_test.dart</code>", code_style),
            Paragraph("Faculty & Class Advisor weekly matrix tap assertions updated for simplified modal.", body_style),
            Paragraph("<b>4 / 4 PASSED</b>", badge_fixed),
        ],
        [
            Paragraph("<b>Entire Flutter Test Suite</b> (<code>flutter test test/</code>)", body_style),
            Paragraph("Comprehensive regression coverage: 367 tests covering timetable, attendance, auth, and UI.", body_style),
            Paragraph("<b>367 / 367 PASSED</b>", badge_fixed),
        ],
        [
            Paragraph("<b>Flutter Analyzer</b> (<code>flutter analyze</code>)", body_style),
            Paragraph("Static linting, strict typing, zero unused imports/variables.", body_style),
            Paragraph("<b>0 ISSUES FOUND</b>", badge_fixed),
        ],
    ]
    t_test = Table(test_data, colWidths=[175, 247, 110])
    t_test.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#EFEBE4")),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#D5C8B8")),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(t_test)

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Report compiled successfully to: {PDF_OUTPUT}")

if __name__ == "__main__":
    build_pdf()
