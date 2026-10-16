with open('mobile/lib/faculty/screens/faculty_class_advisor_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = "'${period.startTime} \u2013 ${period.endTime}'"
replacement = "'${TimezoneUtils.format24hTo12h(period.startTime)} \u2013 ${TimezoneUtils.format24hTo12h(period.endTime)}'"

if target in content:
    content = content.replace(target, replacement)
    print("Replaced en-dash time string in faculty_class_advisor_screen.dart")
else:
    print("En-dash string not found!")

with open('mobile/lib/faculty/screens/faculty_class_advisor_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
