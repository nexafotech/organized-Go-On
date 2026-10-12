"""Read-only DB audit script for FINAL_DATA_RECONCILIATION_AUDIT."""
import sqlite3

conn = sqlite3.connect('attendance_system.db')
conn.row_factory = sqlite3.Row
c = conn.cursor()

print('=== USERS SUMMARY ===')
for r in c.execute("SELECT role, COUNT(*) as cnt, SUM(is_active) as active FROM users GROUP BY role"):
    print(dict(r))

print()
print('=== ADMIN USER ===')
for r in c.execute("SELECT id,username,email,role,is_active FROM users WHERE role='ADMIN'"):
    print(dict(r))

print()
print('=== FACULTY (all 8) ===')
for r in c.execute("""SELECT f.id, f.employee_id, f.full_name, f.department, u.username, u.is_active
    FROM faculty f JOIN users u ON f.user_id=u.id ORDER BY f.employee_id"""):
    print(dict(r))

print()
print('=== CLASS SECTIONS (should be 2) ===')
for r in c.execute('SELECT * FROM class_sections ORDER BY id'):
    print(dict(r))

print()
print('=== SUBJECTS (27) ===')
for r in c.execute('SELECT id, code, name FROM subjects ORDER BY code'):
    print(dict(r))

print()
print('=== SUBJECTS LINKED TO CLASSES (via faculty_assignments) ===')
for r in c.execute("""SELECT DISTINCT s.code, s.name, cs.name as class_name
    FROM subjects s
    JOIN faculty_assignments fa ON fa.subject_id=s.id
    JOIN class_sections cs ON fa.class_id=cs.id
    ORDER BY cs.name, s.code"""):
    print(dict(r))

print()
print('=== SUBJECTS NOT LINKED TO ANY ASSIGNMENT ===')
for r in c.execute("""SELECT s.id, s.code, s.name FROM subjects s
    WHERE s.id NOT IN (SELECT subject_id FROM faculty_assignments)"""):
    print(dict(r))

print()
print('=== TIMETABLE SLOTS BY DAY ===')
for r in c.execute("""SELECT day_of_week, COUNT(*) as cnt FROM timetable_entries
    GROUP BY day_of_week ORDER BY
    CASE day_of_week WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2
    WHEN 'Wednesday' THEN 3 WHEN 'Thursday' THEN 4 WHEN 'Friday' THEN 5
    WHEN 'Saturday' THEN 6 ELSE 7 END"""):
    print(dict(r))

print()
print('=== TIMETABLE BY CLASS (via assignment->class) ===')
for r in c.execute("""SELECT cs.name as class_name, COUNT(*) as slots
    FROM timetable_entries te
    JOIN faculty_assignments fa ON te.assignment_id=fa.id
    JOIN class_sections cs ON fa.class_id=cs.id
    GROUP BY cs.id"""):
    print(dict(r))

print()
print('=== FACULTY ASSIGNMENTS (30) ===')
for r in c.execute("""SELECT fa.id, cs.name as class_name, s.code as sub_code, s.name as sub_name,
    f.employee_id, f.full_name
    FROM faculty_assignments fa
    JOIN class_sections cs ON fa.class_id=cs.id
    JOIN subjects s ON fa.subject_id=s.id
    JOIN faculty f ON fa.faculty_id=f.id
    ORDER BY cs.name, s.code"""):
    print(dict(r))

print()
print('=== STUDENT COUNTS BY CLASS ===')
for r in c.execute("""SELECT cs.name, COUNT(*) as cnt FROM students st
    JOIN class_sections cs ON st.class_id=cs.id GROUP BY st.class_id"""):
    print(dict(r))

print()
print('=== ORPHANED STUDENTS (no matching class) ===')
row = c.execute('SELECT COUNT(*) as cnt FROM students WHERE class_id NOT IN (SELECT id FROM class_sections)').fetchone()
print('Count:', row['cnt'])

print()
print('=== BIOMETRICS ===')
print('face_embeddings count:', c.execute('SELECT COUNT(*) FROM face_embeddings').fetchone()[0])
print('Orphaned (no student):', c.execute('SELECT COUNT(*) FROM face_embeddings WHERE student_id NOT IN (SELECT id FROM students)').fetchone()[0])

print()
print('=== CLASS SESSIONS ===')
print('Total:', c.execute('SELECT COUNT(*) FROM class_sessions').fetchone()[0])

print()
print('=== ATTENDANCE RECORDS ===')
print('Total:', c.execute('SELECT COUNT(*) FROM attendance_records').fetchone()[0])

print()
print('=== AUDIT LOGS (recent 15) ===')
for r in c.execute('SELECT id,action,target,timestamp FROM audit_logs ORDER BY id DESC LIMIT 15'):
    print(dict(r))

print()
print('=== FOREIGN KEY CHECK ===')
errors = list(c.execute('PRAGMA foreign_key_check'))
print('FK errors:', len(errors))
for e in errors:
    print('  ', dict(e))

conn.close()
print('\nAudit complete.')
