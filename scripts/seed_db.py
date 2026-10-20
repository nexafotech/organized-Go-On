import os
import sys
import json
import cv2
import face_recognition

# Ensure current path is in pythonpath
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy.orm import Session
from app.core.database import SessionLocal, Base, engine
from app.core.security import get_password_hash
from app.models.user import User, Faculty, UserRole
from app.models.academic import ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
from app.models.student import Student
from app.models.attendance import FaceEmbedding

def seed_database():
    print("[INFO] Creating database tables...")
    Base.metadata.create_all(bind=engine)

    db: Session = SessionLocal()

    try:
        print("[INFO] Seeding baseline Admin and Faculty accounts...")
        # 1. Seed Admin
        admin_user = db.query(User).filter(User.username == "admin").first()
        if not admin_user:
            admin_user = User(
                username="admin",
                email="admin@college.edu",
                hashed_password=get_password_hash("admin123"),
                role=UserRole.ADMIN,
                is_active=True
            )
            db.add(admin_user)

        # 2. Seed Faculty
        faculty_user = db.query(User).filter(User.username == "faculty").first()
        if not faculty_user:
            faculty_user = User(
                username="faculty",
                email="faculty@college.edu",
                hashed_password=get_password_hash("faculty123"),
                role=UserRole.FACULTY,
                is_active=True
            )
            db.add(faculty_user)
            db.flush()

            faculty_profile = Faculty(
                user_id=faculty_user.id,
                employee_id="EMP-101",
                full_name="Dr. Alan Turing",
                department="Computer Science & Engineering"
            )
            db.add(faculty_profile)
        else:
            faculty_profile = db.query(Faculty).filter(Faculty.user_id == faculty_user.id).first()

        db.flush()

        # 3. Seed Class Sections
        print("[INFO] Seeding Class Sections...")
        c1 = db.query(ClassSection).filter(ClassSection.name == "CSE-3A").first()
        if not c1:
            c1 = ClassSection(name="CSE-3A", grade_level="Year 3", academic_year="2025-2026")
            db.add(c1)
        c2 = db.query(ClassSection).filter(ClassSection.name == "CSE-3B").first()
        if not c2:
            c2 = ClassSection(name="CSE-3B", grade_level="Year 3", academic_year="2025-2026")
            db.add(c2)
        db.flush()

        # 4. Seed Subjects
        print("[INFO] Seeding Subjects...")
        subjects_data = [
            ("PTS", "Probability & Technical Statistics"),
            ("TT", "Technical Training"),
            ("CET-II", "Computer Networks II"),
            ("EC", "Electronic Circuits"),
            ("PPP", "Python Programming Practice"),
            ("BEEE", "Basic Electrical & Electronics Eng"),
            ("EG-LAB", "Engineering Graphics Lab"),
            ("PE-LAB", "Physics Electronics Lab"),
        ]
        subjects_dict = {}
        for code, name in subjects_data:
            s = db.query(Subject).filter(Subject.code == code).first()
            if not s:
                s = Subject(code=code, name=name)
                db.add(s)
                db.flush()
            subjects_dict[code] = s

        # 5. Seed Period Timings
        print("[INFO] Seeding Configurable Periods...")
        periods_data = [
            (1, "Period 1", "09:10", "10:00"),
            (2, "Period 2", "10:00", "10:50"),
            (3, "Period 3", "11:10", "12:00"),
            (4, "Period 4", "12:50", "13:40"),
            (5, "Period 5", "13:40", "14:30"),
            (6, "Period 6", "14:30", "15:20"),
            (7, "Period 7", "15:20", "16:10"),
        ]
        periods_dict = {}
        for p_num, p_name, start, end in periods_data:
            p = db.query(Period).filter(Period.period_number == p_num).first()
            if not p:
                p = Period(period_number=p_num, name=p_name, start_time=start, end_time=end)
                db.add(p)
                db.flush()
            else:
                p.name = p_name
                p.start_time = start
                p.end_time = end
                db.flush()
            periods_dict[p_num] = p

        # 6. Seed Faculty Assignments
        print("[INFO] Seeding Faculty Assignments...")
        assignments_dict = {}
        if faculty_profile:
            for code, subj_obj in subjects_dict.items():
                assign = db.query(FacultyAssignment).filter(
                    FacultyAssignment.faculty_id == faculty_profile.id,
                    FacultyAssignment.subject_id == subj_obj.id,
                    FacultyAssignment.class_id == c1.id
                ).first()
                if not assign:
                    assign = FacultyAssignment(
                        faculty_id=faculty_profile.id,
                        subject_id=subj_obj.id,
                        class_id=c1.id
                    )
                    db.add(assign)
                    db.flush()
                assignments_dict[code] = assign

        # 7. Seed Timetable Entries
        print("[INFO] Seeding Database-driven Timetable Entries...")
        schedule_matrix = {
            "Monday": [(1, "PTS"), (2, "TT"), (3, "CET-II"), (4, "CET-II"), (6, "EG-LAB")],
            "Tuesday": [(1, "TT"), (3, "EC"), (4, "PPP"), (5, "BEEE"), (6, "PE-LAB")],
            "Wednesday": [(1, "PTS"), (3, "PTS"), (4, "EC"), (5, "PTS"), (6, "PE-LAB")],
            "Thursday": [(1, "TT"), (2, "EC"), (3, "PTS"), (4, "CET-II")],
            "Friday": [(1, "EC"), (2, "TT"), (3, "PTS"), (4, "PPP")]
        }

        for day, period_list in schedule_matrix.items():
            for p_num, subj_code in period_list:
                p_obj = periods_dict.get(p_num)
                assign_obj = assignments_dict.get(subj_code)
                if p_obj and assign_obj:
                    entry = db.query(TimetableEntry).filter(
                        TimetableEntry.day_of_week == day,
                        TimetableEntry.period_id == p_obj.id,
                        TimetableEntry.assignment_id == assign_obj.id
                    ).first()
                    if not entry:
                        entry = TimetableEntry(
                            day_of_week=day,
                            period_id=p_obj.id,
                            assignment_id=assign_obj.id
                        )
                        db.add(entry)

        # 8. Import Existing Dataset Students and Face Embeddings
        print("[INFO] Importing dataset students & extracting face embeddings...")
        dataset_dir = os.path.join(os.path.dirname(__file__), "dataset")
        if os.path.exists(dataset_dir):
            for item in os.listdir(dataset_dir):
                item_path = os.path.join(dataset_dir, item)
                if os.path.isdir(item_path) and "_" in item:
                    roll, name = item.split("_", 1)
                    student = db.query(Student).filter(Student.roll_number == roll).first()
                    if not student:
                        student = Student(
                            roll_number=roll,
                            full_name=name.capitalize(),
                            email=f"{name.lower()}@student.college.edu",
                            class_id=c1.id,
                            is_active=True
                        )
                        db.add(student)
                        db.flush()
                        print(f"  [STUDENT] Roll: {roll}, Name: {name}")

                    # Scan images in student folder and create FaceEmbeddings
                    for img_file in os.listdir(item_path):
                        img_path = os.path.join(item_path, img_file)
                        if not img_file.lower().endswith(('.jpg', '.jpeg', '.png')):
                            continue

                        img = cv2.imread(img_path)
                        if img is None:
                            continue

                        rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
                        boxes = face_recognition.face_locations(rgb, model="hog")
                        encodings = face_recognition.face_encodings(rgb, boxes)

                        if len(encodings) == 1:
                            emb_list = encodings[0].tolist()
                            emb_json = json.dumps(emb_list)

                            # Check if embedding already exists for this image path
                            existing_emb = db.query(FaceEmbedding).filter(
                                FaceEmbedding.student_id == student.id,
                                FaceEmbedding.image_path == img_path
                            ).first()

                            if not existing_emb:
                                face_emb = FaceEmbedding(
                                    student_id=student.id,
                                    embedding_json=emb_json,
                                    image_path=img_path
                                )
                                db.add(face_emb)
                                print(f"    [FACE EMBEDDING] Created embedding for student {roll} from {img_file}")

        db.commit()
        print("\n✅ Database seed completed successfully!")
        print("--------------------------------------------------")
        print("Demo Credentials:")
        print("  Admin User:   admin / admin123")
        print("  Faculty User: faculty / faculty123")
        print("--------------------------------------------------\n")

    except Exception as e:
        db.rollback()
        print(f"❌ Error seeding database: {e}")
        raise e
    finally:
        db.close()

if __name__ == "__main__":
    seed_database()
