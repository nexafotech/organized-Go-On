with open('mobile/lib/faculty/screens/faculty_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

target = "'${item.startTime} - ${item.endTime}'"
replacement = "'${TimezoneUtils.format24hTo12h(item.startTime)} - ${TimezoneUtils.format24hTo12h(item.endTime)}'"

if target in text:
    text = text.replace(target, replacement)
    print("Replaced item.startTime in dashboard!")
else:
    print("Target not found!")

with open('mobile/lib/faculty/screens/faculty_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
