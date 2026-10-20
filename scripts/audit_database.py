import sqlite3

def audit_db():
    conn = sqlite3.connect("attendance_system.db")
    c = conn.cursor()
    c.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [r[0] for r in c.fetchall()]
    print(f"Total tables: {len(tables)}")
    for t in sorted(tables):
        if not t.startswith("sqlite_"):
            c.execute(f"SELECT count(*) FROM [{t}]")
            cnt = c.fetchone()[0]
            print(f"  {t:32s}: {cnt:5d} records")

if __name__ == "__main__":
    audit_db()
