import sqlite3

con = sqlite3.connect("attendance_system.db")
cur = con.cursor()

# Check foreign keys
cur.execute("PRAGMA foreign_keys = OFF;")

# Recreate table with nullable faculty_id
cur.execute("""
CREATE TABLE faculty_assignments_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    faculty_id INTEGER,
    subject_id INTEGER NOT NULL,
    class_id INTEGER NOT NULL,
    created_at DATETIME,
    FOREIGN KEY(faculty_id) REFERENCES faculty(id) ON DELETE CASCADE,
    FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
    FOREIGN KEY(class_id) REFERENCES class_sections(id) ON DELETE CASCADE,
    CONSTRAINT uq_faculty_subject_class UNIQUE (faculty_id, subject_id, class_id)
);
""")

cur.execute("""
INSERT INTO faculty_assignments_new (id, faculty_id, subject_id, class_id, created_at)
SELECT id, faculty_id, subject_id, class_id, created_at FROM faculty_assignments;
""")

cur.execute("DROP TABLE faculty_assignments;")
cur.execute("ALTER TABLE faculty_assignments_new RENAME TO faculty_assignments;")

cur.execute("PRAGMA foreign_keys = ON;")
con.commit()
con.close()
print("Migrated faculty_assignments table: faculty_id is now nullable.")
