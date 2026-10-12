import os
import sys
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.units import inch
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super(NumberedCanvas, self).__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super(NumberedCanvas, self).showPage()
        super(NumberedCanvas, self).save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 9)
        self.setFillColor(colors.HexColor("#64748B"))
        
        # Header (pages > 1)
        if self._pageNumber > 1:
            self.drawString(54, letter[1] - 36, "Attendance Marker (am-oss) • Faculty Mobile App UI/Feature Specification")
            self.setStrokeColor(colors.HexColor("#CBD5E1"))
            self.setLineWidth(0.5)
            self.line(54, letter[1] - 42, letter[0] - 54, letter[1] - 42)
            
        # Footer
        footer_text = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(letter[0] - 54, 30, footer_text)
        self.drawString(54, 30, "CONFIDENTIAL • Prepared for UI/UX Design Team")
        self.setStrokeColor(colors.HexColor("#CBD5E1"))
        self.setLineWidth(0.5)
        self.line(54, 42, letter[0] - 54, 42)
        
        self.restoreState()

def build_pdf(filename):
    doc = SimpleDocTemplate(
        filename,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    styles = getSampleStyleSheet()

    # Custom styles
    c_primary = colors.HexColor("#1E40AF")
    c_primary_light = colors.HexColor("#2563EB")
    c_dark = colors.HexColor("#0F172A")
    c_text = colors.HexColor("#1E293B")
    c_muted = colors.HexColor("#475569")
    c_green = colors.HexColor("#059669")
    c_red = colors.HexColor("#DC2626")
    c_purple = colors.HexColor("#7C3AED")
    c_amber = colors.HexColor("#D97706")

    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=24,
        leading=28,
        textColor=c_dark,
        spaceAfter=6
    )

    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=12,
        leading=16,
        textColor=c_primary_light,
        spaceAfter=15
    )

    h1_style = ParagraphStyle(
        'Heading1_Custom',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=15,
        leading=19,
        textColor=c_primary,
        spaceBefore=14,
        spaceAfter=8,
        keepWithNext=True
    )

    h2_style = ParagraphStyle(
        'Heading2_Custom',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=16,
        textColor=c_dark,
        spaceBefore=10,
        spaceAfter=6,
        keepWithNext=True
    )

    body_style = ParagraphStyle(
        'Body_Custom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=13.5,
        textColor=c_text,
        spaceAfter=6
    )

    bullet_style = ParagraphStyle(
        'Bullet_Custom',
        parent=body_style,
        leftIndent=14,
        bulletIndent=4,
        spaceAfter=4
    )

    callout_style = ParagraphStyle(
        'Callout',
        parent=styles['Normal'],
        fontName='Helvetica-Oblique',
        fontSize=9,
        leading=13,
        textColor=c_dark
    )

    table_header_style = ParagraphStyle(
        'TableHeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        textColor=colors.white
    )

    table_cell_style = ParagraphStyle(
        'TableCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=11,
        textColor=c_text
    )

    table_cell_bold = ParagraphStyle(
        'TableCellBold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=11,
        textColor=c_dark
    )

    story = []

    # Title Block
    story.append(Paragraph("Faculty Mobile App UI & Feature Specification", title_style))
    story.append(Paragraph("Class Attendance Management System (am-oss) • Mobile UI Architecture Guide", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=2, color=c_primary_light, spaceBefore=0, spaceAfter=12))

    # Meta Table
    meta_data = [
        [Paragraph("<b>Target Audience:</b>", table_cell_bold), Paragraph("UI/UX Designers & Mobile Developers", table_cell_style),
         Paragraph("<b>Date:</b>", table_cell_bold), Paragraph("September 2026", table_cell_style)],
        [Paragraph("<b>System Core:</b>", table_cell_bold), Paragraph("am-oss / Flutter Mobile / FastAPI", table_cell_style),
         Paragraph("<b>Visual Mode:</b>", table_cell_bold), Paragraph("Dark Slate & Royal Blue (High Contrast)", table_cell_style)],
    ]
    meta_table = Table(meta_data, colWidths=[1.3*inch, 2.2*inch, 1.1*inch, 2.4*inch])
    meta_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F8FAFC")),
        ('BOX', (0,0), (-1,-1), 0.5, colors.HexColor("#E2E8F0")),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('PADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(meta_table)
    story.append(Spacer(1, 14))

    # Section 1
    story.append(Paragraph("1. Executive Summary & Core Business Rules", h1_style))
    story.append(Paragraph(
        "The Faculty Mobile Application is the authoritative academic attendance portal designed for professors and lecturers. "
        "It supports both live biometric facial recognition during scheduled classes and an attendance entry window for completed classes. "
        "Strict temporal and role boundaries govern access to periods:", body_style))

    rules_data = [
        [Paragraph("Period Window", table_header_style), Paragraph("Business Rule / Temporal Condition", table_header_style), Paragraph("Visual Status", table_header_style), Paragraph("Action Allowed", table_header_style)],
        [Paragraph("<b>Today's Completed</b>", table_cell_style), Paragraph("Markable strictly after scheduled end time (currentTime &gt;= endTime)", table_cell_style), Paragraph("<font color='#059669'><b>AVAILABLE</b></font>", table_cell_style), Paragraph("<b>Mark Attendance</b> (Green button)", table_cell_style)],
        [Paragraph("<b>Today's Active</b>", table_cell_style), Paragraph("Ongoing period right now (startTime &lt;= currentTime &lt; endTime)", table_cell_style), Paragraph("<font color='#D97706'><b>LOCKED</b></font>", table_cell_style), Paragraph("Locked (Displays unlock time)", table_cell_style)],
        [Paragraph("<b>Today's Future</b>", table_cell_style), Paragraph("Scheduled for later today (currentTime &lt; startTime)", table_cell_style), Paragraph("<font color='#D97706'><b>LOCKED</b></font>", table_cell_style), Paragraph("Locked (Displays unlock time)", table_cell_style)],
        [Paragraph("<b>Yesterday's Completed</b>", table_cell_style), Paragraph("All scheduled periods from yesterday (24-hour grace window)", table_cell_style), Paragraph("<font color='#059669'><b>AVAILABLE</b></font>", table_cell_style), Paragraph("<b>Mark Attendance</b> (Green button)", table_cell_style)],
        [Paragraph("<b>Already Recorded</b>", table_cell_style), Paragraph("Attendance already submitted previously by authorized faculty", table_cell_style), Paragraph("<font color='#2563EB'><b>RECORDED</b></font>", table_cell_style), Paragraph("<b>Attendance Recorded</b> (Outline review)", table_cell_style)],
        [Paragraph("<b>Dates &lt; Yesterday</b>", table_cell_style), Paragraph("2+ days in the past (Tamper-prevention protocol)", table_cell_style), Paragraph("BLOCKED", table_cell_style), Paragraph("Hidden from Faculty app", table_cell_style)],
        [Paragraph("<b>Future Dates</b>", table_cell_style), Paragraph("Tomorrow and beyond", table_cell_style), Paragraph("BLOCKED", table_cell_style), Paragraph("Hidden from Faculty app", table_cell_style)],
    ]
    rules_table = Table(rules_data, colWidths=[1.5*inch, 2.7*inch, 1.1*inch, 1.7*inch])
    rules_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_primary),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#CBD5E1")),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor("#F8FAFC")]),
        ('PADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(rules_table)
    story.append(Spacer(1, 14))

    # Section 2
    story.append(Paragraph("2. Design Tokens & Visual Hierarchy", h1_style))
    story.append(Paragraph(
        "The interface adopts a high-contrast dark palette tailored for mobile OLED displays and campus environments. "
        "Standardized color tokens ensure instant status recognition across all screens:", body_style))

    color_data = [
        [Paragraph("Token", table_header_style), Paragraph("HEX Value", table_header_style), Paragraph("Role & Semantic Meaning", table_header_style), Paragraph("UI Placement Examples", table_header_style)],
        [Paragraph("<b>Primary Brand</b>", table_cell_style), Paragraph("#2563EB", table_cell_style), Paragraph("Royal Blue: Brand identity, primary CTAs", table_cell_style), Paragraph("Submit button, Active tabs, Profile card", table_cell_style)],
        [Paragraph("<b>Dark Canvas</b>", table_cell_style), Paragraph("#0F172A", table_cell_style), Paragraph("Dark Slate: Main scaffold background", table_cell_style), Paragraph("Global screen background", table_cell_style)],
        [Paragraph("<b>Card Surface</b>", table_cell_style), Paragraph("#1E293B", table_cell_style), Paragraph("Slate Surface: Container cards & sheets", table_cell_style), Paragraph("Class cards, Header cards, Modals", table_cell_style)],
        [Paragraph("<b>Elevated Surface</b>", table_cell_style), Paragraph("#334155", table_cell_style), Paragraph("Lighter Slate: Dividers, borders, inputs", table_cell_style), Paragraph("Search input, unselected buttons, borders", table_cell_style)],
        [Paragraph("<b>Status OK</b>", table_cell_style), Paragraph("#10B981", table_cell_style), Paragraph("Emerald: Present, Available, Success", table_cell_style), Paragraph("Available pill, [P] chip, Open button", table_cell_style)],
        [Paragraph("<b>Status Critical</b>", table_cell_style), Paragraph("#EF4444", table_cell_style), Paragraph("Red: Absent, Error, Sign Out", table_cell_style), Paragraph("[A] chip, All Absent button, Sign Out", table_cell_style)],
        [Paragraph("<b>Status OD</b>", table_cell_style), Paragraph("#8B5CF6", table_cell_style), Paragraph("Violet: On-Duty (Official Excusal)", table_cell_style), Paragraph("[OD] chip, OD reason badge, OD dialog", table_cell_style)],
        [Paragraph("<b>Status Warning</b>", table_cell_style), Paragraph("#F59E0B", table_cell_style), Paragraph("Amber: Locked periods, Alert banner", table_cell_style), Paragraph("Locked pill, Password change alert", table_cell_style)],
        [Paragraph("<b>Text Primary</b>", table_cell_style), Paragraph("#F8FAFC", table_cell_style), Paragraph("Pure White: High-contrast headings", table_cell_style), Paragraph("Headers, student names, button text", table_cell_style)],
        [Paragraph("<b>Text Muted</b>", table_cell_style), Paragraph("#94A3B8", table_cell_style), Paragraph("Slate Grey: Secondary captions", table_cell_style), Paragraph("Roll numbers, timing labels, subheaders", table_cell_style)],
    ]
    color_table = Table(color_data, colWidths=[1.4*inch, 0.9*inch, 2.3*inch, 2.4*inch])
    color_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_dark),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#CBD5E1")),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor("#F8FAFC")]),
        ('PADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(color_table)
    story.append(Spacer(1, 14))

    # Section 3
    story.append(Paragraph("3. Global Navigation Structure", h1_style))
    story.append(Paragraph(
        "The app utilizes a <b>Persistent Scaffold Architecture</b> comprising a top AppBar, scrollable body area, and a 4-tab Bottom Navigation Bar:", body_style))
    story.append(Paragraph("• <b>Tab 0 - Dashboard:</b> Overview hub, active class card, attendance shortcut, today's schedule.", bullet_style))
    story.append(Paragraph("• <b>Tab 1 - Attendance:</b> Dual-tab Available Periods window (TODAY &amp; YESTERDAY).", bullet_style))
    story.append(Paragraph("• <b>Tab 2 - Timetable:</b> 7-day horizontal weekday bar with complete period schedule.", bullet_style))
    story.append(Paragraph("• <b>Tab 3 - Profile:</b> Faculty identification, credentials, server status, and secure sign out.", bullet_style))
    story.append(Spacer(1, 14))

    # Section 4
    story.append(Paragraph("4. Detailed Screen Specifications & Button Locations", h1_style))

    # Screen 1
    story.append(Paragraph("Screen 1: Faculty Authentication & Login", h2_style))
    story.append(Paragraph("<b>Layout & Elements:</b>", body_style))
    story.append(Paragraph("• <b>Top Right Server Pill:</b> Pill badge indicating backend connection status. Tapping opens <i>Server Configuration Dialog</i>.", bullet_style))
    story.append(Paragraph("• <b>Role Segmented Tab:</b> Full-width toggle between STUDENT and FACULTY. Faculty segment activates blue highlight (#2563EB).", bullet_style))
    story.append(Paragraph("• <b>Identifier Input & Live Validation Pill:</b> Text input with real-time 500ms debouncing. When valid, displays green check badge '✓ Faculty account recognized' directly below the field.", bullet_style))
    story.append(Paragraph("• <b>Password Input & Unmask Button:</b> Secure text field with trailing eye icon (👁) button to reveal/hide password characters.", bullet_style))
    story.append(Paragraph("• <b>'Faculty Sign In' Button:</b> Centered at bottom of form, full width (48dp height, #2563EB). Shows centered progress spinner during authentication.", bullet_style))

    # Screen 2
    story.append(Paragraph("Screen 2: Faculty Dashboard Screen (Main Hub)", h2_style))
    story.append(Paragraph("<b>Layout & Elements:</b>", body_style))
    story.append(Paragraph("• <b>AppBar Actions:</b> Title 'Faculty Dashboard' centered. Top right Logout icon button triggers sign out confirmation.", bullet_style))
    story.append(Paragraph("• <b>Faculty Profile Card:</b> Unconditionally rendered at top in deep navy (#2563EB). Left avatar circle with initial ('S'), faculty full name ('Dr. Shankar'), and ID subtitle ('Faculty ID: fac04').", bullet_style))
    story.append(Paragraph("• <b>Mandatory Password Banner (Conditional):</b> Amber alert (#FEF3C7) with right-aligned '[ Update ]' button.", bullet_style))
    story.append(Paragraph("• <b>Active Scheduled Slot Card:</b> Central prominent card. Top right displays 'ACTIVE NOW' (green dot) or 'NO ACTIVE CLASS' (grey). Shows Class, Period, Subject Code, Time interval.", bullet_style))
    story.append(Paragraph("• <b>'START ATTENDANCE SESSION' Button:</b> Full-width elevated button inside active slot card (height 44dp, #2563EB). Starts live session &amp; opens Live Session Screen.", bullet_style))
    story.append(Paragraph("• <b>Mark Attendance Quick Access Card:</b> Checklist icon with green right-aligned '[ Open ]' button (#10B981). Directly switches bottom nav to Tab 1 (Attendance Window).", bullet_style))
    story.append(Paragraph("• <b>Today's Schedule Section:</b> Section header with right-aligned '[ View Full Week ]' link (switches to Tab 2). Lists period cards or clean empty state.", bullet_style))
    story.append(Paragraph("• <b>Error Recovery Card:</b> In case of network glitch, displays cloud-off icon, error explanation, and an active '[ Retry ]' button calling loadDashboardData().", bullet_style))

    # Screen 3
    story.append(Paragraph("Screen 3: Faculty Attendance Window (Available Periods)", h2_style))
    story.append(Paragraph("<b>Layout & Elements:</b>", body_style))
    story.append(Paragraph("• <b>Sub-Tab Bar:</b> DefaultTabController with 'TODAY' and 'YESTERDAY' tabs pinned below AppBar.", bullet_style))
    story.append(Paragraph("• <b>Notice Banner:</b> Informational card explaining that completed periods unlock after end time, and yesterday's periods are open for attendance.", bullet_style))
    story.append(Paragraph("• <b>AVAILABLE Period Card:</b> Green accent border. Period number badge ('P1'), time ('09:10 - 10:00'), status pill ('AVAILABLE'). Features full-width green '[ MARK ATTENDANCE ]' button (#10B981) which opens Attendance Entry Screen.", bullet_style))
    story.append(Paragraph("• <b>LOCKED Period Card:</b> Amber status pill ('LOCKED'). Action button is replaced by an informational lock banner with clock icon: 'Attendance opens after this period ends at 15:20'.", bullet_style))
    story.append(Paragraph("• <b>RECORDED Period Card:</b> Royal blue status pill ('RECORDED'). Features full-width green outline button '[ ATTENDANCE RECORDED ]' allowing faculty to review or correct records.", bullet_style))

    # Screen 4
    story.append(Paragraph("Screen 4: Faculty Attendance Entry Screen (Roster Marking)", h2_style))
    story.append(Paragraph("<b>Layout & Elements:</b>", body_style))
    story.append(Paragraph("• <b>Header Summary Card:</b> Pinned at top. Displays period badge, time, date, subject code/name, and class section.", bullet_style))
    story.append(Paragraph("• <b>Live Stat Counters:</b> 4 responsive counters: Total (White), Present (Green), Absent (Red), OD (Violet). Update in real-time as students are marked.", bullet_style))
    story.append(Paragraph("• <b>Batch Action Buttons:</b> Right-aligned '[ All Present ]' (green outline) and '[ All Absent ]' (red outline) buttons for rapid batch roster marking.", bullet_style))
    story.append(Paragraph("• <b>Search Input Field:</b> Real-time filter by student name or roll number.", bullet_style))
    story.append(Paragraph("• <b>Student Roster Row:</b> Student index (#1), full name, roll number, and segmented 3-button group:", bullet_style))
    story.append(Paragraph("&nbsp;&nbsp;&nbsp;&nbsp;- <b>[ P ] (Present):</b> 36x36dp square button. Fills solid emerald green (#10B981) when selected.", bullet_style))
    story.append(Paragraph("&nbsp;&nbsp;&nbsp;&nbsp;- <b>[ A ] (Absent):</b> 36x36dp square button. Fills solid coral red (#EF4444) when selected.", bullet_style))
    story.append(Paragraph("&nbsp;&nbsp;&nbsp;&nbsp;- <b>[ OD ] (On-Duty):</b> 36x36dp square button. Fills solid violet (#8B5CF6) and opens OD Reason Dialog.", bullet_style))
    story.append(Paragraph("• <b>OD Reason Tag:</b> Displays under student name with edit icon (✏) showing selected reason (e.g. 'OD: Sports Event').", bullet_style))
    story.append(Paragraph("• <b>Sticky Bottom Submit Bar:</b> Pinned to screen bottom (height 48dp, #2563EB). Full-width '[ Submit Attendance ]' button submits payload and refreshes attendance window.", bullet_style))

    # Screen 5, 6, 7
    story.append(Paragraph("Screen 5: Live Session Screen (Biometric & Manual Attendance)", h2_style))
    story.append(Paragraph("• Displays live session ID, subject, and class. Features '[ TAKE GROUP PHOTO ]' (camera) and '[ UPLOAD PHOTO ]' (gallery). Face recognition engine highlights recognized students; faculty can confirm candidates or manually toggle attendance before tapping '[ Finish Session ]'.", body_style))

    story.append(Paragraph("Screen 6: Faculty Timetable Screen", h2_style))
    story.append(Paragraph("• Horizontal 7-day selector (Mon-Sun). Current day has active dot indicator. Lists all assigned teaching periods with period badge, times, and subject metadata. Includes pull-to-refresh and retry error card.", body_style))

    story.append(Paragraph("Screen 7: Faculty Profile Screen", h2_style))
    story.append(Paragraph("• Displays large avatar, full name, employee ID, active status pill, registered email, and connected server endpoint. Includes '[ Change Password ]' modal trigger and prominent red '[ Sign Out ]' button with confirmation dialog.", body_style))
    story.append(Spacer(1, 14))

    # Section 5: Master Quick Reference Table
    story.append(Paragraph("5. Master Interactive Component Placement Map", h1_style))
    story.append(Paragraph("The following table catalogs every interactive button, exact screen location, visual styling, and triggered action:", body_style))

    btn_data = [
        [Paragraph("Button Label", table_header_style), Paragraph("Screen / Section", table_header_style), Paragraph("Visual Style & Color", table_header_style), Paragraph("Tap Action & Destination", table_header_style)],
        [Paragraph("<b>Configure Server</b>", table_cell_bold), Paragraph("Login Screen (Top Right)", table_cell_style), Paragraph("Icon button, #94A3B8", table_cell_style), Paragraph("Opens Server Settings Dialog", table_cell_style)],
        [Paragraph("<b>Role Segment</b>", table_cell_bold), Paragraph("Login Screen (Upper)", table_cell_style), Paragraph("Tab selector, #2563EB", table_cell_style), Paragraph("Switches between Student/Faculty login", table_cell_style)],
        [Paragraph("<b>Unmask Password</b>", table_cell_bold), Paragraph("Login Screen (Input)", table_cell_style), Paragraph("Trailing eye icon (👁)", table_cell_style), Paragraph("Toggles password character visibility", table_cell_style)],
        [Paragraph("<b>Faculty Sign In</b>", table_cell_bold), Paragraph("Login Screen (Bottom)", table_cell_style), Paragraph("Elevated 48dp, #2563EB", table_cell_style), Paragraph("Validates credentials &amp; opens Dashboard", table_cell_style)],
        [Paragraph("<b>Logout</b>", table_cell_bold), Paragraph("AppBar (All screens)", table_cell_style), Paragraph("Icon button, White", table_cell_style), Paragraph("Displays Sign Out Confirmation Dialog", table_cell_style)],
        [Paragraph("<b>Resume Session</b>", table_cell_bold), Paragraph("Dashboard (Banner)", table_cell_style), Paragraph("Elevated, #4F46E5", table_cell_style), Paragraph("Navigates to live FacultySessionScreen", table_cell_style)],
        [Paragraph("<b>Start Session</b>", table_cell_bold), Paragraph("Dashboard (Active Slot)", table_cell_style), Paragraph("Elevated 44dp, #2563EB", table_cell_style), Paragraph("Initiates live class attendance session", table_cell_style)],
        [Paragraph("<b>Open Attendance</b>", table_cell_bold), Paragraph("Dashboard (Quick Access)", table_cell_style), Paragraph("Elevated 36dp, #10B981", table_cell_style), Paragraph("Switches Bottom Navigation to Tab 1", table_cell_style)],
        [Paragraph("<b>View Full Week</b>", table_cell_bold), Paragraph("Dashboard (Schedule)", table_cell_style), Paragraph("Text button, #2563EB", table_cell_style), Paragraph("Switches Bottom Navigation to Tab 2", table_cell_style)],
        [Paragraph("<b>Retry</b>", table_cell_bold), Paragraph("Dashboard / Timetable", table_cell_style), Paragraph("Elevated with icon, #2563EB", table_cell_style), Paragraph("Retries failed API network fetch", table_cell_style)],
        [Paragraph("<b>Sub-Tabs (Today/Yest)</b>", table_cell_bold), Paragraph("Attendance Window", table_cell_style), Paragraph("DefaultTabController, #2563EB", table_cell_style), Paragraph("Toggles Today vs Yesterday period list", table_cell_style)],
        [Paragraph("<b>MARK ATTENDANCE</b>", table_cell_bold), Paragraph("Attendance Card (Available)", table_cell_style), Paragraph("Elevated 44dp, #10B981", table_cell_style), Paragraph("Opens Faculty Attendance Entry Screen", table_cell_style)],
        [Paragraph("<b>ATTENDANCE RECORDED</b>", table_cell_bold), Paragraph("Attendance Card (Marked)", table_cell_style), Paragraph("Outlined 44dp, #10B981", table_cell_style), Paragraph("Opens Entry Screen in review/edit mode", table_cell_style)],
        [Paragraph("<b>All Present</b>", table_cell_bold), Paragraph("Entry Screen (Action Bar)", table_cell_style), Paragraph("Outlined with icon, #10B981", table_cell_style), Paragraph("Sets all students in roster to PRESENT", table_cell_style)],
        [Paragraph("<b>All Absent</b>", table_cell_bold), Paragraph("Entry Screen (Action Bar)", table_cell_style), Paragraph("Outlined with icon, #EF4444", table_cell_style), Paragraph("Sets all students in roster to ABSENT", table_cell_style)],
        [Paragraph("<b>[ P ] Chip</b>", table_cell_bold), Paragraph("Entry Screen (Student Row)", table_cell_style), Paragraph("Square 36x36dp, #10B981", table_cell_style), Paragraph("Toggles student attendance to PRESENT", table_cell_style)],
        [Paragraph("<b>[ A ] Chip</b>", table_cell_bold), Paragraph("Entry Screen (Student Row)", table_cell_style), Paragraph("Square 36x36dp, #EF4444", table_cell_style), Paragraph("Toggles student attendance to ABSENT", table_cell_style)],
        [Paragraph("<b>[ OD ] Chip</b>", table_cell_bold), Paragraph("Entry Screen (Student Row)", table_cell_style), Paragraph("Square 36x36dp, #8B5CF6", table_cell_style), Paragraph("Opens On-Duty (OD) Reason Dialog", table_cell_style)],
        [Paragraph("<b>Confirm OD</b>", table_cell_bold), Paragraph("OD Reason Dialog", table_cell_style), Paragraph("Elevated, #8B5CF6", table_cell_style), Paragraph("Saves OD reason &amp; marks student OD", table_cell_style)],
        [Paragraph("<b>Submit Attendance</b>", table_cell_bold), Paragraph("Entry Screen (Sticky Bottom)", table_cell_style), Paragraph("Elevated 48dp, #2563EB", table_cell_style), Paragraph("Submits roster to API &amp; pops back", table_cell_style)],
        [Paragraph("<b>Take Group Photo</b>", table_cell_bold), Paragraph("Session Screen (Actions)", table_cell_style), Paragraph("Elevated with camera icon", table_cell_style), Paragraph("Launches native camera for face capture", table_cell_style)],
        [Paragraph("<b>Upload Photo</b>", table_cell_bold), Paragraph("Session Screen (Actions)", table_cell_style), Paragraph("Outlined with gallery icon", table_cell_style), Paragraph("Opens image gallery picker", table_cell_style)],
        [Paragraph("<b>Finish Session</b>", table_cell_bold), Paragraph("Session Screen (Top Right)", table_cell_style), Paragraph("Text button / Icon, #EF4444", table_cell_style), Paragraph("Finalizes live class attendance session", table_cell_style)],
        [Paragraph("<b>Day Selector (Mon-Sun)</b>", table_cell_bold), Paragraph("Timetable Screen (Top)", table_cell_style), Paragraph("7 segmented pills, #2563EB", table_cell_style), Paragraph("Filters timetable cards by weekday", table_cell_style)],
        [Paragraph("<b>Sign Out</b>", table_cell_bold), Paragraph("Profile Screen (Bottom)", table_cell_style), Paragraph("Elevated 48dp, #EF4444", table_cell_style), Paragraph("Opens Confirm Sign Out Dialog", table_cell_style)],
    ]
    btn_table = Table(btn_data, colWidths=[1.5*inch, 1.8*inch, 1.6*inch, 2.1*inch])
    btn_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_primary),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#CBD5E1")),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor("#F8FAFC")]),
        ('PADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(btn_table)
    story.append(Spacer(1, 14))

    # Section 6: Designer Handoff Recommendations
    story.append(Paragraph("6. Designer Handoff & Implementation Recommendations", h1_style))
    story.append(Paragraph("• <b>Minimum Touch Target Area:</b> Ensure all interactive touch targets (e.g. [P], [A], [OD] chips, icon buttons, day selector tabs) maintain at least 48x48dp clickable hit-test boundaries to prevent mis-clicks during fast-paced classroom roll calls.", bullet_style))
    story.append(Paragraph("• <b>High Contrast Standards:</b> The dark canvas (#0F172A) combined with pure white headings (#F8FAFC) delivers a contrast ratio of &gt;13:1, meeting WCAG AAA requirements. Colored status chips must retain bold white labels for optimal readability in varying ambient room lighting.", bullet_style))
    story.append(Paragraph("• <b>Keyboard Auto-Dismiss:</b> On both the Login Screen and Attendance Entry Screen, tapping outside input text fields must dismiss the soft keyboard so the sticky submit bar remains accessible.", bullet_style))
    story.append(Paragraph("• <b>150ms State Transitions:</b> Interactive chips ([P], [A], [OD]) and navigation tabs utilize 150ms color transitions for immediate tactile feedback.", bullet_style))
    story.append(Paragraph("• <b>Dynamic Text Wrapping:</b> Long course names (e.g. 'Secure Database Management Systems') must wrap cleanly across multiple lines (softWrap: true) to avoid RenderFlex overflow errors.", bullet_style))

    # Build the document
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Successfully generated PDF: {filename}")

if __name__ == "__main__":
    out_path = sys.argv[1] if len(sys.argv) > 1 else "FACULTY_UI_FEATURE_SPECIFICATION.pdf"
    build_pdf(out_path)
