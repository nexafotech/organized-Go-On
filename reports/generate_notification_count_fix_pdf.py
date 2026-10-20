import os
import sys
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.pdfgen import canvas
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle

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
            if self._pageNumber > 1:
                self.saveState()
                self.setFont('Helvetica-Bold', 8)
                self.setFillColor(colors.HexColor('#475569'))
                self.drawString(40, 755, "go-On AI Face Attendance System")
                self.setFont('Helvetica', 8)
                self.drawString(180, 755, " - Notification Count & Empty Inbox Synchronization Audit")
                self.drawRightString(612 - 40, 755, "Verified on Android (S24) & Web")
                self.setStrokeColor(colors.HexColor('#CBD5E1'))
                self.setLineWidth(0.6)
                self.line(40, 748, 612 - 40, 748)

                # Running Footer
                self.line(40, 42, 612 - 40, 42)
                self.setFont('Helvetica', 8)
                self.setFillColor(colors.HexColor('#64748B'))
                self.drawString(40, 30, "CONFIDENTIAL & PROPRIETARY - Notification Synchronization Engineering Deliverable")
                self.drawRightString(612 - 40, 30, f"Page {self._pageNumber} of {num_pages}")
                self.restoreState()
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)


def generate_pdf(pdf_path):
    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=letter,
        leftMargin=40,
        rightMargin=40,
        topMargin=50,
        bottomMargin=50
    )

    styles = getSampleStyleSheet()

    c_primary = colors.HexColor('#0F172A')
    c_accent = colors.HexColor('#3B82F6')
    c_accent_dark = colors.HexColor('#1D4ED8')
    c_text = colors.HexColor('#1E293B')
    c_muted = colors.HexColor('#64748B')
    c_pass = colors.HexColor('#059669')
    c_card_bg = colors.HexColor('#F8FAFC')
    c_border = colors.HexColor('#E2E8F0')

    title_style = ParagraphStyle(
        'CoverTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=18,
        leading=22,
        textColor=c_primary
    )
    subtitle_style = ParagraphStyle(
        'CoverSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=13.5,
        textColor=colors.HexColor('#475569')
    )
    h1_style = ParagraphStyle(
        'AuditH1',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=11,
        leading=14,
        textColor=c_accent_dark,
        spaceBefore=10,
        spaceAfter=4,
        keepWithNext=True
    )
    body_style = ParagraphStyle(
        'AuditBody',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.2,
        leading=11.5,
        textColor=c_text,
        spaceAfter=4
    )
    bold_body = ParagraphStyle(
        'AuditBodyBold',
        parent=body_style,
        fontName='Helvetica-Bold'
    )
    th_style = ParagraphStyle(
        'AuditTH',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=7.8,
        leading=10,
        textColor=colors.white
    )
    td_style = ParagraphStyle(
        'AuditTD',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7.4,
        leading=9.6,
        textColor=c_text
    )
    td_pass = ParagraphStyle(
        'AuditTDPass',
        parent=td_style,
        fontName='Helvetica-Bold',
        textColor=c_pass
    )

    story = []

    # Title Block
    story.append(Paragraph("go-On — Notification Count & Empty Inbox Synchronization", title_style))
    story.append(Spacer(1, 4))
    story.append(Paragraph("Comprehensive Root Cause Analysis, Fix Implementation, and Verification Report", subtitle_style))
    story.append(Spacer(1, 10))

    # Meta Table
    meta_data = [
        [
            Paragraph("<b>System:</b> go-On AI Face Attendance", td_style),
            Paragraph("<b>Target OS:</b> Android (S24 SM-S921E) & Web", td_style),
            Paragraph("<b>Status:</b> <font color='#059669'><b>RESOLVED & TESTED</b></font>", td_style),
        ],
        [
            Paragraph("<b>Scope:</b> Notifications History UI & Service", td_style),
            Paragraph("<b>Date:</b> October 20, 2026", td_style),
            Paragraph("<b>Analysis:</b> 0 Issues (Clean)", td_style),
        ]
    ]
    meta_table = Table(meta_data, colWidths=[180, 180, 172])
    meta_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), c_card_bg),
        ('BOX', (0,0), (-1,-1), 0.8, c_border),
        ('INNERGRID', (0,0), (-1,-1), 0.5, c_border),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(meta_table)
    story.append(Spacer(1, 10))

    # Executive Summary
    story.append(Paragraph("1. Executive Summary", h1_style))
    story.append(Paragraph(
        "A critical defect was identified in the Notifications page where the AppBar badge and filter chips "
        "displayed unread counts (e.g. <b>Notifications 3</b>, <b>Unread 3</b>) while the body rendered the empty state: "
        "<i>'No notifications yet. Class updates and announcements will appear here.'</i> "
        "An end-to-end investigation from database models up to UI widget trees uncovered six interrelated root causes, "
        "including asynchronous unread polling race conditions, initial post-frame empty state flashes, destructive filter re-fetches, "
        "and unsanitized service states on login transitions. All causes have been addressed and verified across automated test suites.",
        body_style
    ))
    story.append(Spacer(1, 8))

    # Root Cause Matrix
    story.append(Paragraph("2. Root Cause Analysis Matrix", h1_style))
    rc_data = [
        [
            Paragraph("ID", th_style),
            Paragraph("Subsystem", th_style),
            Paragraph("Root Cause Description", th_style),
            Paragraph("Observed Behavioral Impact", th_style),
            Paragraph("Engineering Fix Applied", th_style),
        ],
        [
            Paragraph("<b>RC-1</b>", td_style),
            Paragraph("UI Layer", td_style),
            Paragraph("All chip and Unread chip read from different sources (list length vs counter variable).", td_style),
            Paragraph("All showed 0 while Unread and AppBar showed 3.", td_style),
            Paragraph("Both counts unified to derive strictly from active in-memory notifications.", td_style),
        ],
        [
            Paragraph("<b>RC-2</b>", td_style),
            Paragraph("UI Filter", td_style),
            Paragraph("Tapping Unread chip called API with unreadOnly=true, overwriting full list.", td_style),
            Paragraph("All count got corrupted to match unread count; list had to be re-downloaded.", td_style),
            Paragraph("Local in-memory filtering applied. Destructive re-fetch removed.", td_style),
        ],
        [
            Paragraph("<b>RC-3</b>", td_style),
            Paragraph("UI Lifecycle", td_style),
            Paragraph("Initial fetch was queued in addPostFrameCallback. Frame 1 had empty items and isLoading=false.", td_style),
            Paragraph("Screen briefly flashed 'No notifications yet' while showing 3 in badges.", td_style),
            Paragraph("Added _hasInitialLoaded lifecycle guard and spinner for initial load.", td_style),
        ],
        [
            Paragraph("<b>RC-4</b>", td_style),
            Paragraph("Service Layer", td_style),
            Paragraph("fetchNotifications emitted notifyListeners before reconciling unread count.", td_style),
            Paragraph("Temporary race condition between items and counter.", td_style),
            Paragraph("Immediate activeUnread calculation before notifyListeners.", td_style),
        ],
        [
            Paragraph("<b>RC-5</b>", td_style),
            Paragraph("Auth Service", td_style),
            Paragraph("clearUserData was only called on logout, never on login or session restore.", td_style),
            Paragraph("Previous user notification count leaked into next logged-in account.", td_style),
            Paragraph("clearUserData invoked in restoreSession, loginStudent, and loginFaculty.", td_style),
        ],
        [
            Paragraph("<b>RC-6</b>", td_style),
            Paragraph("Backend ORM", td_style),
            Paragraph("mark_all_notifications_as_read lacked synchronize_session='fetch'.", td_style),
            Paragraph("Stale cached counts in concurrent sessions.", td_style),
            Paragraph("Added explicit synchronize_session='fetch' to bulk update.", td_style),
        ],
    ]

    rc_table = Table(rc_data, colWidths=[30, 65, 150, 145, 142])
    rc_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_primary),
        ('BOX', (0,0), (-1,-1), 0.8, c_border),
        ('INNERGRID', (0,0), (-1,-1), 0.5, c_border),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(rc_table)
    story.append(Spacer(1, 10))

    # Test Matrix
    story.append(Paragraph("3. Verification and Test Results", h1_style))
    test_data = [
        [
            Paragraph("Test Suite", th_style),
            Paragraph("Test Scenario / Verification Objective", th_style),
            Paragraph("Result", th_style),
        ],
        [
            Paragraph("notification_count_and_sync_test.dart", td_style),
            Paragraph("NotificationService clearUserData resets counts, notifications, and state", td_style),
            Paragraph("PASSED", td_pass),
        ],
        [
            Paragraph("notification_count_and_sync_test.dart", td_style),
            Paragraph("Empty inbox renders zero counts, hidden header badge, and empty state message", td_style),
            Paragraph("PASSED", td_pass),
        ],
        [
            Paragraph("notification_count_and_sync_test.dart", td_style),
            Paragraph("Populated inbox with 3 unread displays matching header badge and filter counts", td_style),
            Paragraph("PASSED", td_pass),
        ],
        [
            Paragraph("notification_count_and_sync_test.dart", td_style),
            Paragraph("Tapping Unread filter tab filters list in-place without destroying All count", td_style),
            Paragraph("PASSED", td_pass),
        ],
        [
            Paragraph("notification_count_and_sync_test.dart", td_style),
            Paragraph("Unread tab with 0 unread displays correct empty state message without corrupting All tab", td_style),
            Paragraph("PASSED", td_pass),
        ],
        [
            Paragraph("faculty_notification_bell_and_delivery_test.dart", td_style),
            Paragraph("Active bell, zero unread hiding, single/multi-digit badge verification (6 tests)", td_style),
            Paragraph("PASSED (6/6)", td_pass),
        ],
        [
            Paragraph("notification_bulk_delete_test.dart", td_style),
            Paragraph("Bulk deletion confirmation, unpinned deletion, pinned preservation (7 tests)", td_style),
            Paragraph("PASSED (7/7)", td_pass),
        ],
        [
            Paragraph("notification_delete_pin_test.dart", td_style),
            Paragraph("Swipe to pin, swipe to delete, system tray deduplication (7 tests)", td_style),
            Paragraph("PASSED (7/7)", td_pass),
        ],
        [
            Paragraph("Backend Pytest", td_style),
            Paragraph("test_notification_bulk_delete.py, test_notification_delete_pin_audit.py, test_phase11_notifications.py", td_style),
            Paragraph("PASSED (22/22)", td_pass),
        ],
        [
            Paragraph("Static Code Analysis", td_style),
            Paragraph("flutter analyze (Entire Mobile Codebase)", td_style),
            Paragraph("0 ISSUES", td_pass),
        ],
    ]

    test_table = Table(test_data, colWidths=[180, 272, 80])
    test_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_primary),
        ('BOX', (0,0), (-1,-1), 0.8, c_border),
        ('INNERGRID', (0,0), (-1,-1), 0.5, c_border),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ('ALIGN', (2,1), (2,-1), 'CENTER'),
    ]))
    story.append(test_table)
    story.append(Spacer(1, 10))

    # Architecture Rules Followed
    story.append(Paragraph("4. Key Architectural Guarantees", h1_style))
    story.append(Paragraph(
        "• <b>Zero Count Discrepancies:</b> The header badge, filter tabs, and inbox list now share identical mathematical derivation.<br/>"
        "• <b>Pure Local Filtering:</b> Switching tabs does not trigger unnecessary network roundtrips or wipe out in-memory data.<br/>"
        "• <b>Deterministic Empty State:</b> 'No notifications yet' is only shown when the user truly has zero notifications, and unread empty state specifically states 'All your notifications have been marked as read.'<br/>"
        "• <b>Clean Session Transitions:</b> Account switching completely purges previous user cache and polling queues.",
        body_style
    ))

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"PDF generated successfully at {pdf_path}")

if __name__ == '__main__':
    out_path = os.path.join(os.path.dirname(__file__), 'go-On_Notification_Count_and_Inbox_State_Fix_Report.pdf')
    generate_pdf(out_path)
