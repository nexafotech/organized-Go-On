import os
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.pdfgen import canvas

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
        self.setFont('Helvetica', 8)
        self.setFillColor(colors.HexColor('#64748B'))
        # Header (pages > 1)
        if self._pageNumber > 1:
            self.drawString(36, 756, 'Attendance Marker (am-oss) | UI & Feature Specification (Student & Faculty)')
            self.setStrokeColor(colors.HexColor('#CBD5E1'))
            self.setLineWidth(0.5)
            self.line(36, 750, letter[0] - 36, 750)

        # Footer (all pages)
        self.setStrokeColor(colors.HexColor('#CBD5E1'))
        self.setLineWidth(0.5)
        self.line(36, 36, letter[0] - 36, 36)
        self.drawString(36, 24, 'CONFIDENTIAL & PROPRIETARY — PREPARED FOR UI/UX DESIGN TEAM')
        self.drawRightString(letter[0] - 36, 24, f'Page {self._pageNumber} of {page_count}')
        self.restoreState()

def build_pdf(filename):
    doc = SimpleDocTemplate(
        filename,
        pagesize=letter,
        leftMargin=36,
        rightMargin=36,
        topMargin=48,
        bottomMargin=48
    )

    styles = getSampleStyleSheet()

    c_primary = colors.HexColor('#1E3A8A')
    c_accent = colors.HexColor('#2563EB')
    c_dark = colors.HexColor('#0F172A')
    c_muted = colors.HexColor('#475569')
    c_light = colors.HexColor('#F8FAFC')
    c_card_bg = colors.HexColor('#FFFFFF')
    c_border = colors.HexColor('#E2E8F0')
    c_success = colors.HexColor('#16A34A')
    c_warning = colors.HexColor('#D97706')
    c_danger = colors.HexColor('#DC2626')

    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=20,
        leading=24,
        textColor=c_primary,
        spaceAfter=6
    )

    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=10.5,
        leading=14.5,
        textColor=c_muted,
        spaceAfter=12
    )

    h1_style = ParagraphStyle(
        'SectionH1',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=13,
        leading=17,
        textColor=c_primary,
        spaceBefore=12,
        spaceAfter=6,
        keepWithNext=True
    )

    h2_style = ParagraphStyle(
        'SectionH2',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=14,
        textColor=c_accent,
        spaceBefore=8,
        spaceAfter=4,
        keepWithNext=True
    )

    body_style = ParagraphStyle(
        'DocBody',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=12.5,
        textColor=c_dark,
        spaceAfter=5
    )

    bullet_style = ParagraphStyle(
        'DocBullet',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=11.5,
        textColor=c_dark,
        leftIndent=12,
        spaceAfter=2.5
    )

    table_header = ParagraphStyle(
        'TableHeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=10.5,
        textColor=colors.white
    )

    table_cell = ParagraphStyle(
        'TableCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7.5,
        leading=10.5,
        textColor=c_dark
    )

    table_cell_bold = ParagraphStyle(
        'TableCellBold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=7.5,
        leading=10.5,
        textColor=c_dark
    )

    story = []

    # Title & Metadata
    story.append(Paragraph('Attendance Marker (am-oss)', title_style))
    story.append(Paragraph('UI & Feature Design Specification — Student & Faculty Mobile Applications', subtitle_style))
    story.append(HRFlowable(width='100%', thickness=1.5, color=c_primary, spaceBefore=2, spaceAfter=8))

    meta_data = [
        [Paragraph('<b>Document Type:</b> UI/UX Architecture & Placement Guide', table_cell), Paragraph('<b>Version:</b> 2.4.0 (Production Blueprint)', table_cell)],
        [Paragraph('<b>Target Audience:</b> UI/UX Designers & Mobile Developers', table_cell), Paragraph('<b>Platforms:</b> Android (Flutter), Web, Desktop', table_cell)],
        [Paragraph('<b>Roles Covered:</b> Faculty & Student Roles', table_cell), Paragraph('<b>Status:</b> Approved & Ready for Mockup Creation', table_cell)]
    ]
    t_meta = Table(meta_data, colWidths=[270, 270])
    t_meta.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#F1F5F9')),
        ('PADDING', (0,0), (-1,-1), 4),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOX', (0,0), (-1,-1), 0.5, c_border),
        ('INNERGRID', (0,0), (-1,-1), 0.5, c_border),
    ]))
    story.append(t_meta)
    story.append(Spacer(1, 8))

    # Executive Overview
    story.append(Paragraph('1. Executive Overview & Global Design System', h1_style))
    story.append(Paragraph(
        'The <b>Attendance Marker</b> mobile client operates on a unified multi-role Flutter codebase supporting two core end-user roles: <b>Faculty</b> and <b>Student</b>. '
        'This specification details every implemented screen, exact component hierarchy, visual token specifications, interaction states, and precise button placements '
        'to guide the UI/UX design team in creating pixel-perfect Figma/Penpot mockups.',
        body_style
    ))

    # Token Table
    token_data = [
        [Paragraph('Token / Style Name', table_header), Paragraph('Hex / Spec', table_header), Paragraph('Role / Visual Context in App', table_header)],
        [Paragraph('Primary Navy', table_cell_bold), Paragraph('#1E3A8A / #0F172A', table_cell), Paragraph('AppBar backgrounds, primary CTA buttons, elevated card borders', table_cell)],
        [Paragraph('Accent Blue', table_cell_bold), Paragraph('#2563EB / #3B82F6', table_cell), Paragraph('Active tabs, primary action highlights, radio selection indicators', table_cell)],
        [Paragraph('Surface Dark (Canvas)', table_cell_bold), Paragraph('#0F172A', table_cell), Paragraph('Dark theme scaffold background; high-contrast base for cards', table_cell)],
        [Paragraph('Card Container', table_cell_bold), Paragraph('#1E293B (Dark) / #FFFFFF (Light)', table_cell), Paragraph('Elevated cards, rounded rectangles (R=12px), elevation 1.0–2.0', table_cell)],
        [Paragraph('Success Green', table_cell_bold), Paragraph('#16A34A / #22C55E', table_cell), Paragraph('Attendance &gt;=75%, Verified status, Present badge, Session Active', table_cell)],
        [Paragraph('Warning Amber', table_cell_bold), Paragraph('#D97706 / #F59E0B', table_cell), Paragraph('Attendance 65%-74.9%, Pending review, Partial enrollment', table_cell)],
        [Paragraph('Critical Red', table_cell_bold), Paragraph('#DC2626 / #EF4444', table_cell), Paragraph('Attendance &lt;65%, Absent badge, Terminate session, Sync failure', table_cell)],
        [Paragraph('Touch Targets', table_cell_bold), Paragraph('Min 48 x 48 dp (W x H)', table_cell), Paragraph('All interactive buttons, icons, pills, and touchable elements', table_cell)]
    ]
    t_tokens = Table(token_data, colWidths=[120, 130, 290])
    t_tokens.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_primary),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('PADDING', (0,0), (-1,-1), 4),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F8FAFC')])
    ]))
    story.append(t_tokens)
    story.append(Spacer(1, 8))

    # Shared Screens
    story.append(Paragraph('2. Shared Screens (Authentication & Settings)', h1_style))
    story.append(Paragraph('2.1 Login Screen & Server Configuration Modal', h2_style))
    story.append(Paragraph('<b>Role Access:</b> Both Faculty and Students log in via the unified login screen.', body_style))
    story.append(Paragraph('• <b>Top Header:</b> App logo (64x64 dp), App Title "Attendance Marker", Subtitle "Smart Academic Attendance Suite".', bullet_style))
    story.append(Paragraph('• <b>Top-Right Icon:</b> Server Settings Gear button (48x48 dp touch target). Opens the Server URL configuration bottom sheet modal.', bullet_style))
    story.append(Paragraph('• <b>Input Field 1 (Username / Reg No):</b> Outlined text field with leading icon (person), clear button, supporting uppercase auto-transform.', bullet_style))
    story.append(Paragraph('• <b>Input Field 2 (Password):</b> Obscured text field with trailing eye toggle (show/hide password).', bullet_style))
    story.append(Paragraph('• <b>Role Toggle / Auto-Detect:</b> Login automatically navigates to Faculty or Student dashboard based on JWT user claims.', bullet_style))
    story.append(Paragraph('• <b>Primary Action Button:</b> Full-width elevated button <b>[ Sign In ]</b> (H=50 dp, navy blue, white bold text). Displays CircularProgressIndicator during submission.', bullet_style))
    story.append(Paragraph('• <b>Server Config Modal:</b> Text field for Base URL (default <code>http://127.0.0.1:8000</code>), <b>[ Test Connection ]</b> outline button, <b>[ Save & Close ]</b> solid button.', bullet_style))
    story.append(Spacer(1, 8))

    # Faculty Application Section
    story.append(Paragraph('3. Faculty Mobile Application Specification', h1_style))
    story.append(Paragraph('The Faculty app contains a 4-tab Bottom Navigation Bar: <b>1. Dashboard</b>, <b>2. Attendance</b>, <b>3. Timetable</b>, <b>4. Profile</b>.', body_style))
    
    story.append(Paragraph('3.1 Tab 1: Faculty Dashboard Screen', h2_style))
    story.append(Paragraph('• <b>Faculty Profile Card (Top):</b> Displays avatar with initials, Faculty Name (e.g., Dr. R. Sharma), Faculty Code (FAC04), Department, and Designation pill badge.', bullet_style))
    story.append(Paragraph('• <b>Active Class Slot Card:</b> Real-time banner showing current ongoing class. Displays Subject Name, Subject Code, Room No, Section, and Period time interval (e.g. 09:00 - 09:50).', bullet_style))
    story.append(Paragraph('• <b>Attendance Window Status Pill:</b> Dynamic status chip: <i>"Active Window" (Green)</i>, <i>"Window Opens in 12m" (Amber)</i>, or <i>"Closed" (Grey)</i>.', bullet_style))
    story.append(Paragraph('• <b>Primary Action Button:</b> Prominent <b>[ Take / Resume Attendance ]</b> button embedded directly in the active slot card. Navigates directly into the Attendance marking workflow.', bullet_style))
    story.append(Paragraph('• <b>Today\'s Schedule Stream:</b> Vertical list of chronological slot cards for today, each with time tag, room badge, and status indicator.', bullet_style))
    story.append(Paragraph('• <b>Error & Offline State:</b> Dedicated error banner with <b>[ Retry ]</b> button to recover seamlessly from network hiccups.', bullet_style))

    story.append(Paragraph('3.2 Tab 2: Faculty Attendance Roster & Marking Screen', h2_style))
    story.append(Paragraph('• <b>Top Dual-Tab Switcher:</b> Segmented pill selector: <b>[ Scheduled Slots ]</b> | <b>[ Manual Override / Roster ]</b>.', bullet_style))
    story.append(Paragraph('• <b>Period Selector Dropdown:</b> Allows choosing among eligible assigned periods for the current day.', bullet_style))
    story.append(Paragraph('• <b>Attendance Summary Header:</b> 3 stat counters: Total Enrolled, Present Count (Green), Absent Count (Red).', bullet_style))
    story.append(Paragraph('• <b>Batch Action Bar:</b> <b>[ Mark All Present ]</b> (outlined green) and <b>[ Reset All ]</b> buttons.', bullet_style))
    story.append(Paragraph('• <b>Student Roster List:</b> Each item row shows student roll number, name, registration number, face-verification confidence badge (e.g., 94% Biometric Match), and dual toggle buttons: <b>[ P ]</b> (Green pill) / <b>[ A ]</b> (Red pill).', bullet_style))
    story.append(Paragraph('• <b>Bottom Sticky Action Bar:</b> Fixed bottom container with <b>[ Finalize & Submit Attendance ]</b> (elevated solid button, H=52 dp).', bullet_style))

    story.append(Paragraph('3.3 Tab 3: Faculty Weekly Timetable Screen', h2_style))
    story.append(Paragraph('• <b>Horizontal Day Selector:</b> Monday through Saturday pill buttons with indicator dot for active day.', bullet_style))
    story.append(Paragraph('• <b>Timetable Slot Cards:</b> Chronological cards showing Start Time, End Time, Subject Code, Subject Title, Section (e.g., CSE-B), and Assigned Room Number.', bullet_style))
    story.append(Paragraph('• <b>Empty State Graphic:</b> "No classes scheduled for this day" illustration when faculty has a free day.', bullet_style))

    story.append(Paragraph('3.4 Tab 4: Faculty Profile & Account Screen', h2_style))
    story.append(Paragraph('• <b>Profile Header:</b> Large circular avatar, Full Name, Employee ID, Email, Department.', bullet_style))
    story.append(Paragraph('• <b>Security Options:</b> <b>[ Change Password ]</b> list tile opening password change sheet.', bullet_style))
    story.append(Paragraph('• <b>System Info:</b> App build version, API endpoint URL, Last Sync timestamp.', bullet_style))
    story.append(Paragraph('• <b>Logout Button:</b> Destructive red-outlined button <b>[ Sign Out ]</b> with confirmation dialogue.', bullet_style))

    story.append(Spacer(1, 8))

    # Student Application Section
    story.append(Paragraph('4. Student Mobile Application Specification', h1_style))
    story.append(Paragraph('The Student app contains a 4-tab Bottom Navigation Bar: <b>1. Overview</b>, <b>2. Biometric Register</b>, <b>3. Timetable</b>, <b>4. Profile</b>.', body_style))

    story.append(Paragraph('4.1 Tab 1: Student Overview & Attendance Dashboard', h2_style))
    story.append(Paragraph('• <b>Student Identity Card (Top):</b> Student avatar with initials, Full Name, Registration Number (e.g., 2024BCSE001), Department, Year, and Section (e.g. CSE-A).', bullet_style))
    story.append(Paragraph('• <b>Mandatory Password Change Alert:</b> If the user is logging in with initial default password, a high-priority amber warning banner renders at the top with a direct <b>[ Update Password Now ]</b> button.', bullet_style))
    story.append(Paragraph('• <b>Overall Attendance Radial Gauge Card:</b> Circular or semi-circular progress meter displaying aggregate attendance percentage (e.g. 84.5%). '
                           'Color transitions dynamically: Green (&gt;=75%), Amber (65%-74.9%), Red (&lt;65%). '
                           'Displays required classes needed to reach 75% threshold.', bullet_style))
    story.append(Paragraph('• <b>Quick Metric Counters (Grid 2x2):</b> '
                           'Total Conducted Classes, Total Attended Classes, Total Absent, Approved On-Duty (OD) credits.', bullet_style))
    story.append(Paragraph('• <b>Subject-Wise Attendance Breakdown:</b> Card list for all enrolled subjects. Each card includes: '
                           'Subject Code (e.g. CS301), Subject Name, Percentage Progress Bar, Fraction (Attended/Total, e.g. 28/32), and Minimum 75% Status Badge.', bullet_style))

    story.append(Paragraph('4.2 Tab 2: Biometric Multi-Pose Face Enrollment Screen', h2_style))
    story.append(Paragraph('• <b>Guidance Instruction Banner:</b> Header detailing camera alignment requirements (clean lighting, neutral expression, no sunglasses/masks).', bullet_style))
    story.append(Paragraph('• <b>Pose Progress Stepper (3-Stage):</b> 1. Frontal Pose (0° ±5°) → 2. Left Angle (15°) → 3. Right Angle (15°).', bullet_style))
    story.append(Paragraph('• <b>Live Camera Viewfinder / Preview:</b> Centered elliptical face guide overlay with real-time feedback bounding box. Bounding box turns Green when face is well-centered and lighting is sufficient.', bullet_style))
    story.append(Paragraph('• <b>Quality & Angle Telemetry:</b> Displays real-time Yaw, Pitch, Roll angles and face clarity score.', bullet_style))
    story.append(Paragraph('• <b>Primary Action Button:</b> Floating / Bottom-centered <b>[ Capture Pose Photo ]</b> (Circular camera icon button, 64x64 dp).', bullet_style))
    story.append(Paragraph('• <b>Validation Review Modal:</b> Shows thumbnail of captured pose with quality metrics and dual actions: <b>[ Retake ]</b> (Outline) and <b>[ Confirm & Next Pose ]</b> (Solid Green).', bullet_style))
    story.append(Paragraph('• <b>Final Submission Button:</b> Once all 3 poses are captured, activates <b>[ Submit Face Templates for Approval ]</b>.', bullet_style))

    story.append(Paragraph('4.3 Tab 3: Student Class Timetable Screen', h2_style))
    story.append(Paragraph('• <b>Day Filter Selector:</b> Horizontal scrollable pills for Mon, Tue, Wed, Thu, Fri, Sat.', bullet_style))
    story.append(Paragraph('• <b>Period Time-block Cards:</b> Displays chronological period slot: Time (08:30 - 09:20), Course Name, Course Code, Faculty In-charge name, and Classroom/Lab Room number.', bullet_style))
    story.append(Paragraph('• <b>Ongoing Class Highlighting:</b> The currently running period card has an elevated border and a pulsating "In Progress" badge.', bullet_style))

    story.append(Paragraph('4.4 Tab 4: Student Profile & Settings Screen', h2_style))
    story.append(Paragraph('• <b>Student Profile Header:</b> Student photo or monogram initials, Full Name, Reg No, Roll No, Official Email, Academic Batch.', bullet_style))
    story.append(Paragraph('• <b>Face Enrollment Status Tile:</b> Shows whether biometric templates are <i>Registered & Verified (Green)</i> or <i>Pending Registration (Amber)</i> with a direct <b>[ Re-enroll Face ]</b> action.', bullet_style))
    story.append(Paragraph('• <b>Account Management:</b> <b>[ Change Password ]</b> action tile opening password modal with validation criteria.', bullet_style))
    story.append(Paragraph('• <b>Logout Button:</b> Destructive red-outlined <b>[ Log Out ]</b> button at the bottom of the scroll view.', bullet_style))

    story.append(Spacer(1, 8))

    # Button Placement & Interaction Matrix
    story.append(Paragraph('5. Button Placement & Interaction Specification Matrix', h1_style))
    story.append(Paragraph('The following table defines the exact screen placement, dimensions, visual styling, and behavioral transitions for every interactive button across both applications.', body_style))

    btn_matrix_data = [
        [Paragraph('Screen / Context', table_header), Paragraph('Button Label', table_header), Paragraph('Exact UI Placement', table_header), Paragraph('Styling & Dimensions', table_header), Paragraph('Target Action / Outcome', table_header)],
        
        # Login & Global
        [Paragraph('Login Screen', table_cell_bold), Paragraph('[ Sign In ]', table_cell), Paragraph('Below password field, full-width with 24dp horizontal margin', table_cell), Paragraph('Solid Navy Blue (#1E3A8A), H=50dp, R=10dp, White bold text', table_cell), Paragraph('Authenticates user, redirects to role dashboard', table_cell)],
        [Paragraph('Login Screen', table_cell_bold), Paragraph('[ Server Config ]', table_cell), Paragraph('Top-right AppBar action icon (Gear icon, 48x48dp target)', table_cell), Paragraph('Icon-only, Slate-400 color, transparent background', table_cell), Paragraph('Opens modal bottom sheet to configure backend host URL', table_cell)],
        
        # Faculty
        [Paragraph('Faculty Dashboard', table_cell_bold), Paragraph('[ Take / Resume Attendance ]', table_cell), Paragraph('Bottom of Active Class Slot Card, aligned right / full-width', table_cell), Paragraph('Solid Emerald Green (#16A34A), H=44dp, R=8dp, White text', table_cell), Paragraph('Opens Attendance Marking screen for the current slot', table_cell)],
        [Paragraph('Faculty Dashboard', table_cell_bold), Paragraph('[ Retry ]', table_cell), Paragraph('Inside network error card, centered below error message', table_cell), Paragraph('Outlined button with blue border, H=38dp, R=6dp', table_cell), Paragraph('Triggers full reload of dashboard schedule & session data', table_cell)],
        [Paragraph('Faculty Attendance', table_cell_bold), Paragraph('[ Mark All Present ]', table_cell), Paragraph('Above roster list, right side of batch action bar', table_cell), Paragraph('Outlined Emerald Green, H=36dp, R=6dp, Green text', table_cell), Paragraph('Sets all student attendance toggles to Present in memory', table_cell)],
        [Paragraph('Faculty Attendance', table_cell_bold), Paragraph('[ P ] / [ A ] Toggles', table_cell), Paragraph('Right side of each student roster list item', table_cell), Paragraph('Pill toggle pair (36x32dp each), Green for P, Red for A', table_cell), Paragraph('Toggles individual student attendance status', table_cell)],
        [Paragraph('Faculty Attendance', table_cell_bold), Paragraph('[ Submit Attendance ]', table_cell), Paragraph('Sticky fixed bottom bar across screen bottom', table_cell), Paragraph('Full-width solid Navy (#1E3A8A), H=52dp, R=0 (or 12dp sheet)', table_cell), Paragraph('POSTs finalized attendance payload to backend API', table_cell)],
        
        # Student
        [Paragraph('Student Dashboard', table_cell_bold), Paragraph('[ Update Password ]', table_cell), Paragraph('Inside mandatory password alert card, right aligned', table_cell), Paragraph('Solid Amber (#D97706), H=36dp, R=6dp, White text', table_cell), Paragraph('Opens password change bottom sheet modal', table_cell)],
        [Paragraph('Student Biometric', table_cell_bold), Paragraph('[ Capture Pose Photo ]', table_cell), Paragraph('Bottom-center of camera viewfinder, 24dp above screen edge', table_cell), Paragraph('Circular shutter button, 68x68dp, White ring with blue core', table_cell), Paragraph('Captures photo, triggers on-device pose & quality analysis', table_cell)],
        [Paragraph('Student Biometric', table_cell_bold), Paragraph('[ Confirm & Next ]', table_cell), Paragraph('Inside pose review bottom sheet, right side', table_cell), Paragraph('Solid Green (#16A34A), H=46dp, R=8dp, White text', table_cell), Paragraph('Stores current pose template and advances to next pose', table_cell)],
        [Paragraph('Student Biometric', table_cell_bold), Paragraph('[ Retake Pose ]', table_cell), Paragraph('Inside pose review bottom sheet, left side', table_cell), Paragraph('Outlined Grey/Red, H=46dp, R=8dp', table_cell), Paragraph('Discards current capture and reactivates camera stream', table_cell)],
        [Paragraph('Student Profile', table_cell_bold), Paragraph('[ Re-enroll Face ]', table_cell), Paragraph('Inside Face Registration tile, right aligned', table_cell), Paragraph('Outlined Blue button, H=34dp, R=6dp', table_cell), Paragraph('Navigates directly to multi-pose biometric enrollment flow', table_cell)],
        [Paragraph('Profile (Both)', table_cell_bold), Paragraph('[ Sign Out ]', table_cell), Paragraph('Bottom of Profile screen scroll view, centered / full-width', table_cell), Paragraph('Outlined Crimson Red (#DC2626), H=48dp, R=8dp', table_cell), Paragraph('Clears JWT tokens, user cache, and navigates to Login', table_cell)]
    ]

    t_matrix = Table(btn_matrix_data, colWidths=[90, 100, 115, 115, 120])
    t_matrix.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_primary),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('PADDING', (0,0), (-1,-1), 3.5),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F8FAFC')])
    ]))
    story.append(t_matrix)
    story.append(Spacer(1, 10))

    # UI Designer Implementation Guidelines
    story.append(Paragraph('6. UI Designer Implementation Guidelines & Deliverables', h1_style))
    story.append(Paragraph(
        'To ensure seamless development handoff, the UI designer should adhere to the following conventions when producing Figma / Penpot design assets:',
        body_style
    ))
    story.append(Paragraph('• <b>Grid & Layout:</b> 8dp grid system. Standard screen padding = 16dp horizontal, 12dp vertical. Card internal padding = 16dp.', bullet_style))
    story.append(Paragraph('• <b>Component Modularization:</b> Create reusable component variants for: Primary Buttons, Status Badges (Green/Amber/Red/Grey), Stat Counters, Schedule Cards, and Roster Item Rows.', bullet_style))
    story.append(Paragraph('• <b>Dynamic States:</b> Provide mockups for <i>Default</i>, <i>Loading (shimmer skeleton)</i>, <i>Empty state</i>, and <i>Error with retry</i> for all dashboard and timetable screens.', bullet_style))
    story.append(Paragraph('• <b>Dark / Light Theming:</b> The Flutter codebase implements dark mode by default (`#0F172A` background, `#1E293B` cards). Designer should provide both Dark Mode and Light Mode (`#F8FAFC` background, `#FFFFFF` cards) color styles.', bullet_style))
    story.append(Paragraph('• <b>Accessibility (a11y):</b> Minimum contrast ratio of 4.5:1 for all body text against card backgrounds. Minimum touch target size of 48x48dp for all interactive icons and buttons.', bullet_style))

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f'Successfully built {filename}')

if __name__ == '__main__':
    paths = [
        r'C:\Users\Abishek\Desktop\STUDENT_AND_FACULTY_UI_FEATURE_SPECIFICATION.pdf',
        r'C:\Users\Abishek\Desktop\am-oss\STUDENT_AND_FACULTY_UI_FEATURE_SPECIFICATION.pdf',
        r'C:\Users\Abishek\.gemini\antigravity\brain\7f90dbc7-1f76-43d0-a6a4-acccb732defd\STUDENT_AND_FACULTY_UI_FEATURE_SPECIFICATION.pdf'
    ]
    for p in paths:
        build_pdf(p)
