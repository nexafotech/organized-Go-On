import os

class Settings:
    PROJECT_NAME: str = "Class Attendance Management System"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"

    SECRET_KEY: str = os.getenv("SECRET_KEY", "dev-secret-key-change-in-production-class-attendance-2026")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days session

    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./attendance_system.db")

    # System Capacity Limits (Milestone 10C.9)
    MAX_STUDENTS: int = 130
    MAX_FACULTY: int = 15

    # Cookie Configuration
    COOKIE_NAME: str = "attendance_session"
    COOKIE_SECURE: bool = False  # Set to True in production HTTPS
    COOKIE_HTTPONLY: bool = True
    COOKIE_SAMESITE: str = "lax"

    # Canonical Student Face Dataset Configuration (Phase 7.8)
    STUDENT_FACE_DATASET_DIR: str = os.getenv("STUDENT_FACE_DATASET_DIR", "data/student_faces")

    @property
    def student_face_dataset_path(self) -> str:
        """Returns normalized absolute path to canonical student face dataset directory."""
        base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        if os.path.isabs(self.STUDENT_FACE_DATASET_DIR):
            return os.path.normpath(self.STUDENT_FACE_DATASET_DIR)
        return os.path.normpath(os.path.join(base_dir, self.STUDENT_FACE_DATASET_DIR))

settings = Settings()

