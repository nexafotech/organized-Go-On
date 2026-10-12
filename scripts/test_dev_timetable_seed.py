import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.core.database import SessionLocal
from app.services.college_importer import seed_temporary_dev_timetable
from app.models.academic import ClassSection, TimetableEntry, FacultyAssignment

db = SessionLocal()
results = seed_temporary_dev_timetable(db, class_name="all", force_reset=True)
print("Seed results:", results)

for cs in db.query(ClassSection).all():
    tt_count = db.query(TimetableEntry).join(FacultyAssignment).filter(FacultyAssignment.class_id == cs.id).count()
    print(f"Class {cs.id}: '{cs.name}' ({cs.grade_level}) -> {tt_count} timetable slots")

db.close()
