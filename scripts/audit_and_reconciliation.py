import os
import shutil
import datetime
import sqlite3
import json

def run_backup_and_audit():
    db_path = "attendance_system.db"
    if not os.path.exists(db_path):
        print(f"Error: {db_path} does not exist!")
        return

    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_name = f"attendance_system_backup_{ts}.db"
    shutil.copy2(db_path, backup_name)
    print(f"BACKUP_PATH: {os.path.abspath(backup_name)}")

    # Verify backup
    conn = sqlite3.connect(backup_name)
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = [r[0] for r in cur.fetchall()]
    print(f"TABLE_COUNT: {len(tables)}")
    table_counts = {}
    for t in tables:
        cnt = cur.execute(f"SELECT COUNT(*) FROM `{t}`;").fetchone()[0]
        table_counts[t] = cnt
        print(f"  {t}: {cnt}")

    print("\n--- SECTION 1: DETAILED ENTITY AUDIT ---")
    
    # 1. Classes
    cur.execute("SELECT id, name, grade_level, academic_year FROM class_sections;")
    classes = cur.fetchall()
    print(f"\nCLASSES ({len(classes)}):")
    for c in classes:
        st_count = cur.execute("SELECT COUNT(*) FROM students WHERE class_id = ?", (c[0],)).fetchone()[0]
        tt_count = cur.execute("""
            SELECT COUNT(*) FROM timetable_entries te 
            JOIN faculty_assignments fa ON te.assignment_id = fa.id 
            WHERE fa.class_id = ?
        """, (c[0],)).fetchone()[0]
        as_count = cur.execute("SELECT COUNT(*) FROM faculty_assignments WHERE class_id = ?", (c[0],)).fetchone()[0]
        sess_count = cur.execute("""
            SELECT COUNT(*) FROM class_sessions cs
            JOIN timetable_entries te ON cs.timetable_entry_id = te.id
            JOIN faculty_assignments fa ON te.assignment_id = fa.id
            WHERE fa.class_id = ?
        """, (c[0],)).fetchone()[0]
        print(f"  ID {c[0]}: '{c[1]}' (Grade: {c[2]}, Year: {c[3]}) | Students: {st_count}, Timetable: {tt_count}, Assignments: {as_count}, Sessions: {sess_count}")

    # 2. Faculty
    cur.execute("SELECT f.id, f.employee_id, f.full_name, f.department, f.user_id, u.username, u.is_active, u.role FROM faculty f LEFT JOIN users u ON f.user_id = u.id;")
    faculty = cur.fetchall()
    print(f"\nFACULTY ({len(faculty)}):")
    for f in faculty:
        as_count = cur.execute("SELECT COUNT(*) FROM faculty_assignments WHERE faculty_id = ?", (f[0],)).fetchone()[0]
        auth_as_count = cur.execute("SELECT COUNT(*) FROM assignment_authorized_faculty WHERE faculty_id = ?", (f[0],)).fetchone()[0]
        sess_count = cur.execute("SELECT COUNT(*) FROM class_sessions WHERE faculty_id = ?", (f[0],)).fetchone()[0]
        print(f"  ID {f[0]}: [{f[1]}] '{f[2]}' | user: {f[5]} (active={f[6]}, role={f[7]}) | Dept: {f[3]} | Primary Asgn: {as_count}, Co-Asgn: {auth_as_count}, Sessions: {sess_count}")

    # 3. Students
    cur.execute("SELECT COUNT(*), class_id FROM students GROUP BY class_id;")
    student_class_counts = cur.fetchall()
    print(f"\nSTUDENTS BY CLASS:")
    for sc in student_class_counts:
        print(f"  Class ID {sc[1]}: {sc[0]} students")
    total_students = cur.execute("SELECT COUNT(*) FROM students;").fetchone()[0]
    active_students = cur.execute("SELECT COUNT(*) FROM students WHERE is_active = 1;").fetchone()[0]
    fpc_students = cur.execute("SELECT COUNT(*) FROM users u JOIN students s ON u.id = s.user_id WHERE u.force_password_change = 1;").fetchone()[0]
    print(f"  Total Students: {total_students} (Active: {active_students}, Force Password Change: {fpc_students})")

    # Check for any test students
    cur.execute("SELECT id, roll_number, full_name, class_id FROM students WHERE roll_number LIKE '%test%' OR full_name LIKE '%test%' OR full_name LIKE '%Turing%' OR full_name LIKE '%Hopper%';")
    test_students = cur.fetchall()
    print(f"  Suspicious/Test Students: {len(test_students)}")
    for ts_st in test_students:
        print(f"    {ts_st}")

    # 4. Subjects
    cur.execute("SELECT id, code, name FROM subjects ORDER BY id ASC;")
    subjects = cur.fetchall()
    print(f"\nSUBJECTS ({len(subjects)}):")
    for s in subjects:
        as_count = cur.execute("SELECT COUNT(*) FROM faculty_assignments WHERE subject_id = ?", (s[0],)).fetchone()[0]
        tt_count = cur.execute("""
            SELECT COUNT(*) FROM timetable_entries te 
            JOIN faculty_assignments fa ON te.assignment_id = fa.id 
            WHERE fa.subject_id = ?
        """, (s[0],)).fetchone()[0]
        sess_count = cur.execute("""
            SELECT COUNT(*) FROM class_sessions cs
            JOIN timetable_entries te ON cs.timetable_entry_id = te.id
            JOIN faculty_assignments fa ON te.assignment_id = fa.id
            WHERE fa.subject_id = ?
        """, (s[0],)).fetchone()[0]
        print(f"  ID {s[0]}: [{s[1]}] '{s[2]}' | Asgn: {as_count}, Timetable: {tt_count}, Sessions: {sess_count}")

    # 5. Periods
    cur.execute("SELECT id, period_number, name, start_time, end_time FROM periods ORDER BY period_number ASC;")
    periods = cur.fetchall()
    print(f"\nPERIODS ({len(periods)}):")
    for p in periods:
        tt_count = cur.execute("SELECT COUNT(*) FROM timetable_entries WHERE period_id = ?", (p[0],)).fetchone()[0]
        sess_count = cur.execute("""
            SELECT COUNT(*) FROM class_sessions cs
            JOIN timetable_entries te ON cs.timetable_entry_id = te.id
            WHERE te.period_id = ?
        """, (p[0],)).fetchone()[0]
        print(f"  ID {p[0]}: Period {p[1]} '{p[2]}' ({p[3]} - {p[4]}) | Timetable refs: {tt_count}, Session refs: {sess_count}")

    # 6. Timetable Entries
    cur.execute("""
        SELECT fa.class_id, cs.name, COUNT(*) 
        FROM timetable_entries te
        JOIN faculty_assignments fa ON te.assignment_id = fa.id
        LEFT JOIN class_sections cs ON fa.class_id = cs.id
        GROUP BY fa.class_id;
    """)
    tt_class_counts = cur.fetchall()
    print(f"\nTIMETABLE ENTRIES BY CLASS:")
    for tc in tt_class_counts:
        print(f"  Class ID {tc[0]} ('{tc[1]}'): {tc[2]} slots")
    total_tt = cur.execute("SELECT COUNT(*) FROM timetable_entries;").fetchone()[0]
    print(f"  Total Timetable Slots: {total_tt}")

    # Distinct days in timetable
    cur.execute("SELECT DISTINCT day_of_week, COUNT(*) FROM timetable_entries GROUP BY day_of_week ORDER BY COUNT(*) DESC;")
    days_in_tt = cur.fetchall()
    print(f"  Days in Timetable: {days_in_tt}")

    # 7. Faculty Assignments
    cur.execute("""
        SELECT fa.id, fa.class_id, cs.name, fa.subject_id, s.code, s.name, fa.faculty_id, f.full_name
        FROM faculty_assignments fa
        LEFT JOIN class_sections cs ON fa.class_id = cs.id
        LEFT JOIN subjects s ON fa.subject_id = s.id
        LEFT JOIN faculty f ON fa.faculty_id = f.id
        ORDER BY fa.class_id ASC, s.code ASC;
    """)
    asgns = cur.fetchall()
    print(f"\nFACULTY ASSIGNMENTS ({len(asgns)}):")
    for a in asgns:
        co_facs = cur.execute("""
            SELECT f.employee_id, f.full_name 
            FROM assignment_authorized_faculty aaf
            JOIN faculty f ON aaf.faculty_id = f.id
            WHERE aaf.assignment_id = ?
        """, (a[0],)).fetchall()
        co_str = ", ".join([f"{cf[0]}:{cf[1]}" for cf in co_facs]) if co_facs else "None"
        tt_cnt = cur.execute("SELECT COUNT(*) FROM timetable_entries WHERE assignment_id = ?", (a[0],)).fetchone()[0]
        print(f"  ID {a[0]}: Class '{a[2]}' (ID {a[1]}) | Sub: [{a[4]}] '{a[5]}' (ID {a[3]}) | Fac: '{a[7]}' (ID {a[6]}) | Co-fac: [{co_str}] | TT slots: {tt_cnt}")

    # 8. Class Sessions & Attendance Records
    total_sessions = cur.execute("SELECT COUNT(*) FROM class_sessions;").fetchone()[0]
    total_att = cur.execute("SELECT COUNT(*) FROM attendance_records;").fetchone()[0]
    print(f"\nSESSIONS & ATTENDANCE:")
    print(f"  Total Class Sessions: {total_sessions}")
    print(f"  Total Attendance Records: {total_att}")
    if total_sessions > 0:
        cur.execute("SELECT id, class_id, subject_id, faculty_id, session_date, status FROM class_sessions LIMIT 10;")
        for s in cur.fetchall():
            print(f"    Session {s}")
    if total_att > 0:
        cur.execute("SELECT id, session_id, student_id, status, confidence_score FROM attendance_records LIMIT 10;")
        for a in cur.fetchall():
            print(f"    Attendance {a}")

    # 9. Biometrics / Face Embeddings
    total_embeddings = cur.execute("SELECT COUNT(*) FROM face_embeddings;").fetchone()[0]
    print(f"\nBIOMETRICS / FACE EMBEDDINGS:")
    print(f"  Total Face Embeddings: {total_embeddings}")
    if total_embeddings > 0:
        cur.execute("SELECT id, student_id, model_name, model_version, dimension, detector_backend, is_active FROM face_embeddings;")
        for emb in cur.fetchall():
            print(f"    Embedding ID {emb[0]}: Student ID {emb[1]}, Model: {emb[2]} v{emb[3]}, Dim: {emb[4]}, Detector: {emb[5]}, Active: {emb[6]}")

    # 10. Audit Logs
    total_audit = cur.execute("SELECT COUNT(*) FROM audit_logs;").fetchone()[0]
    print(f"\nAUDIT LOGS: {total_audit} entries")

    conn.close()

if __name__ == "__main__":
    run_backup_and_audit()
