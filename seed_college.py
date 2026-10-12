import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy.orm import Session
from app.core.database import SessionLocal, Base, engine
from app.models.user import User, UserRole
from app.core.security import get_password_hash
from app.services.college_importer import import_college_seed_bundle, ImportValidationError

def seed_college_data():
    print("[INFO] Creating database schema...")
    Base.metadata.create_all(bind=engine)
    db: Session = SessionLocal()

    try:
        # Seed Admin user if not exists
        admin = db.query(User).filter(User.username == "admin").first()
        if not admin:
            admin = User(
                username="admin",
                email="admin@college.edu",
                hashed_password=get_password_hash("admin123"),
                role=UserRole.ADMIN,
                is_active=True
            )
            db.add(admin)
            db.commit()
            print("[INFO] Baseline admin account verified: admin / admin123")

        print("[INFO] Seeding official college_seed bundle...")
        results = import_college_seed_bundle(db, seed_dir="college_seed")
        print(f"[SUCCESS] College seed completed successfully: {results}")

    except ImportValidationError as e:
        print(f"[ERROR] Import validation failed: {e.message}")
        for err in e.errors:
            print(f"  - {err}")
    except Exception as e:
        print(f"[ERROR] Seeding error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_college_data()
