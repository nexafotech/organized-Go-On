import sqlite3

con = sqlite3.connect("attendance_system.db")
cur = con.cursor()
cols = cur.execute("PRAGMA table_info(faculty_assignments)").fetchall()
print("faculty_assignments schema:")
for col in cols:
    print(col)
con.close()
