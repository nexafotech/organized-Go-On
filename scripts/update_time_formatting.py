import os

def update_file(filepath, replacements, import_statement=None, import_after=None):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    if import_statement and import_statement not in content and import_after:
        content = content.replace(import_after, import_after + '\n' + import_statement)

    for old, new in replacements:
        if old in content:
            content = content.replace(old, new)
            print(f'Replaced in {filepath}: {old[:30]}... -> {new[:30]}...')
        else:
            print(f'WARN: Not found in {filepath}: {old[:40]}')

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

# 1. faculty_attendance_screen.dart
update_file(
    'mobile/lib/faculty/screens/faculty_attendance_screen.dart',
    [
        ('const Duration(days: 2)', 'const Duration(days: 1)'),
        (
            "periodTime: '${period.startTime} - ${period.endTime}',",
            "periodTime: '${TimezoneUtils.format24hTo12h(period.startTime)} - ${TimezoneUtils.format24hTo12h(period.endTime)}',"
        ),
        (
            "'${period.startTime} - ${period.endTime}',",
            "'${TimezoneUtils.format24hTo12h(period.startTime)} - ${TimezoneUtils.format24hTo12h(period.endTime)}',"
        ),
    ],
    import_statement="import '../../utils/timezone_utils.dart';",
    import_after="import '../../services/faculty_service.dart';"
)

# 2. faculty_class_advisor_screen.dart
update_file(
    'mobile/lib/faculty/screens/faculty_class_advisor_screen.dart',
    [
        ('const Duration(days: 2)', 'const Duration(days: 1)'),
        (
            "periodTime: '${period.startTime} - ${period.endTime}',",
            "periodTime: '${TimezoneUtils.format24hTo12h(period.startTime)} - ${TimezoneUtils.format24hTo12h(period.endTime)}',"
        ),
        (
            "'${period.startTime} - ${period.endTime}',",
            "'${TimezoneUtils.format24hTo12h(period.startTime)} - ${TimezoneUtils.format24hTo12h(period.endTime)}',"
        ),
        (
            "'Opens after period ends at ${period.endTime}'",
            "'Opens after period ends at ${TimezoneUtils.format24hTo12h(period.endTime)}'"
        ),
    ],
    import_statement="import '../../utils/timezone_utils.dart';",
    import_after="import '../../services/faculty_service.dart';"
)

print('Time formatting update script completed!')
