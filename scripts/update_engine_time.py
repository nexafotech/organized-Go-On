with open('app/engines/attendance_engine.py', 'r', encoding='utf-8') as f:
    text = f.read()

# Update import
old_imp = "from app.engines.timetable_engine import get_active_and_upcoming_class, get_ist_now"
new_imp = "from app.engines.timetable_engine import get_active_and_upcoming_class, get_ist_now, format_time_12h"
assert old_imp in text, "old_imp not found"
text = text.replace(old_imp, new_imp)

# Update lock reasons
text = text.replace(
    'lock_reason = f"Attendance opens after this period ends at {end}"',
    'lock_reason = f"Attendance opens after this period ends at {format_time_12h(end)}"'
)
text = text.replace(
    'detail=f"Attendance isn\'t open yet. This period ends at {entry.period.end_time}."',
    'detail=f"Attendance isn\'t open yet. This period ends at {format_time_12h(entry.period.end_time)}."'
)
text = text.replace(
    'detail=f"Attendance cannot be entered before the period ends at {entry.period.end_time}."',
    'detail=f"Attendance cannot be entered before the period ends at {format_time_12h(entry.period.end_time)}."'
)

with open('app/engines/attendance_engine.py', 'w', encoding='utf-8') as f:
    f.write(text)

print("Updated attendance_engine.py with format_time_12h!")
