"""
Fix: Set force_password_change=0 for test student and do login correctly.
Verify current DB state.
"""
import sqlite3

DB = r"C:\Users\Abishek\Desktop\am-oss\attendance_system.db"
conn = sqlite3.connect(DB)
c = conn.cursor()

# Check current state of test student
c.execute("SELECT username, role, force_password_change FROM users WHERE username='721025149001'")
row = c.fetchone()
print(f"Student 721025149001: role={row[1]}, force_pw={row[2]}")

# Set force_password_change to 0 so login goes directly to dashboard
c.execute("UPDATE users SET force_password_change=0 WHERE username='721025149001'")
conn.commit()

c.execute("SELECT username, role, force_password_change FROM users WHERE username='721025149001'")
row = c.fetchone()
print(f"After update: force_pw={row[2]}")

# Also show overall counts
c.execute("SELECT COUNT(*), role FROM users GROUP BY role")
for r in c.fetchall():
    print(f"  {r[1]}: {r[0]} accounts")

c.execute("SELECT COUNT(*), force_password_change FROM users WHERE role!='admin' GROUP BY force_password_change")
for r in c.fetchall():
    print(f"  force_pw={r[1]}: {r[0]} accounts")

conn.close()
print("Done.")
