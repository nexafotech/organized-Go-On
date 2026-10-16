import sqlite3
import bcrypt

con = sqlite3.connect('attendance_system.db')
cur = con.cursor()
cur.execute("SELECT u.id, u.email, s.roll_number, u.hashed_password FROM users u JOIN students s ON s.user_id = u.id WHERE s.roll_number = '721024149001'")
row = cur.fetchone()
if row:
    uid, email, roll, hp = row
    print(f"Found: user_id={uid}, email={email}, roll={roll}")
    for p in ["Student@123", "Password@123", "goOn@2026", "Akash@123", "721024149001", "student", "student123", "Akash123!", "Welcome@123"]:
        if bcrypt.checkpw(p.encode('utf-8'), hp.encode('utf-8')):
            print(f"MATCH: {p}")
            break
con.close()
