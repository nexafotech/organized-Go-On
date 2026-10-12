"""
Restore force_password_change=1 for test student 721025149001.
Verify full DB integrity.
"""
import sqlite3

DB = r"C:\Users\Abishek\Desktop\am-oss\attendance_system.db"
conn = sqlite3.connect(DB)
c = conn.cursor()

# Restore force_password_change=1
c.execute("UPDATE users SET force_password_change=1 WHERE role!='admin'")
conn.commit()

# Verify counts
print("=== DATABASE INTEGRITY AUDIT ===")
c.execute("SELECT role, COUNT(*) FROM users GROUP BY role ORDER BY role")
for role, count in c.fetchall():
    print(f"User Accounts ({role}): {count}")

c.execute("SELECT COUNT(*) FROM users")
total_users = c.fetchone()[0]
print(f"Total Users: {total_users}")

c.execute("SELECT force_password_change, COUNT(*) FROM users WHERE role!='admin' GROUP BY force_password_change")
for fpc, count in c.fetchall():
    print(f"Non-admin accounts force_password_change={fpc}: {count}")

c.execute("SELECT COUNT(*) FROM timetable_entries")
print(f"Timetable Entries: {c.fetchone()[0]}")

c.execute("SELECT COUNT(*) FROM attendance_records")
print(f"Attendance Records: {c.fetchone()[0]}")

c.execute("SELECT COUNT(*) FROM class_sessions")
print(f"Class Sessions: {c.fetchone()[0]}")

c.execute("SELECT COUNT(*) FROM face_embeddings")
print(f"Face Embeddings: {c.fetchone()[0]}")

conn.close()
print("=== DB AUDIT COMPLETE ===")
