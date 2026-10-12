import sqlite3
DB = r"C:\Users\Abishek\Desktop\am-oss\attendance_system.db"
conn = sqlite3.connect(DB)
c = conn.cursor()
c.execute("SELECT username, role, force_password_change FROM users WHERE role='ADMIN' OR username='admin'")
for r in c.fetchall():
    print(f"Admin: user={r[0]}, role={r[1]}, force_pw={r[2]}")
# If admin was modified, restore admin force_password_change to 0
c.execute("UPDATE users SET force_password_change=0 WHERE role='ADMIN' OR username='admin'")
conn.commit()

c.execute("SELECT force_password_change, COUNT(*) FROM users GROUP BY force_password_change")
for r in c.fetchall():
    print(f"force_password_change={r[0]}: {r[1]}")
conn.close()
