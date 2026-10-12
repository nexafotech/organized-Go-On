import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.core.database import SessionLocal
from app.models.academic import ClassSection
from app.models.student import Student

db = SessionLocal()
for cs in db.query(ClassSection).all():
    st_count = db.query(Student).filter(Student.class_id == cs.id).count()
    print(f"Class {cs.id}: '{cs.name}' ({cs.grade_level}) -> {st_count} students")
db.close()
