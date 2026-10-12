import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.core.database import SessionLocal
from app.models.academic import ClassSection, TimetableEntry, FacultyAssignment
from app.models.student import Student

db = SessionLocal()

old_name = "II Year CSE Cyber Security - Class 2"
new_name = "III Year CSE Cyber Security - Class 2"

print("--- CURRENT DATABASE STATE ---")
for cs in db.query(ClassSection).all():
    st_count = db.query(Student).filter(Student.class_id == cs.id).count()
    fa_count = db.query(FacultyAssignment).filter(FacultyAssignment.class_id == cs.id).count()
    print(f"Class {cs.id}: '{cs.name}' | Grade: {cs.grade_level} | Students: {st_count} | Assignments: {fa_count}")

# Check if old Class 2 exists in DB
old_cs = db.query(ClassSection).filter(ClassSection.name == old_name).first()
if old_cs:
    print(f"\nUpdating Class {old_cs.id} name from '{old_name}' to '{new_name}' and grade_level to 'III Year'...")
    old_cs.name = new_name
    old_cs.grade_level = "III Year"
    db.commit()
    print("Database updated successfully!")
else:
    # Check if new Class 2 exists
    new_cs = db.query(ClassSection).filter(ClassSection.name == new_name).first()
    if new_cs:
        print(f"\nClass already named '{new_name}' (ID: {new_cs.id}).")
    else:
        print(f"\nNeither '{old_name}' nor '{new_name}' found in database.")

print("\n--- UPDATED DATABASE STATE ---")
for cs in db.query(ClassSection).all():
    st_count = db.query(Student).filter(Student.class_id == cs.id).count()
    fa_count = db.query(FacultyAssignment).filter(FacultyAssignment.class_id == cs.id).count()
    print(f"Class {cs.id}: '{cs.name}' | Grade: {cs.grade_level} | Students: {st_count} | Assignments: {fa_count}")

db.close()
