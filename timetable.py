from datetime import datetime

# FULL WEEK TIMETABLE (24-HOUR FORMAT)
TIMETABLE = {
    "Monday": [
        ("09:10", "10:00", "PTS"),
        ("10:00", "10:50", "TT"),
        ("11:10", "12:00", "CET-II"),
        ("12:50", "13:40", "CET-II"),
        ("14:30", "15:20", "EG-LAB")
    ],
    "Tuesday": [
        ("09:10", "10:50", "PP-LAB"),
        ("11:10", "12:00", "EC"),
        ("12:50", "13:40", "PPP"),
        ("13:40", "14:30", "BEEE"),
        ("14:30", "15:20", "PE-LAB")
    ],
    "Wednesday": [
        ("09:10", "10:00", "PPT"),
        ("11:10", "12:00", "PPT"),
        ("12:50", "13:40", "EC"),
        ("13:40", "14:30", "PTS"),
        ("14:30", "15:20", "EP-LAB")
    ],
    "Thursday": [
        ("09:10", "10:00", "TT"),
        ("10:00", "10:50", "EC"),
        ("11:10", "12:00", "PTS"),
        ("12:50", "13:40", "CET-II"),
        ("14:30", "15:20", "LAB")
    ],
    "Friday": [
        ("09:10", "10:00", "EC"),
        ("10:00", "10:50", "TT"),
        ("11:10", "12:00", "PTS"),
        ("12:50", "13:40", "PPP"),
        ("14:30", "15:20", "LAB")
    ]
}

def get_current_period():
    now = datetime.now()
    day = now.strftime("%A")
    current_time = now.strftime("%H:%M")

    # If today not in timetable
    if day not in TIMETABLE:
        return day, None, None

    for period_number, (start, end, subject) in enumerate(TIMETABLE[day], start=1):
        if start <= current_time <= end:
            return day, period_number, subject

    return day, None, None
