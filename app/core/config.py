import os

from typing import List

class Settings:
    PROJECT_NAME: str = "Go-On Attendance System"
    VERSION: str = "2.0.0"
    API_V1_STR: str = "/api/v1"

    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development").lower()
    _DEFAULT_DEV_SECRET: str = "dev-secret-key-change-in-production-class-attendance-2026"
    SECRET_KEY: str = os.getenv("SECRET_KEY", _DEFAULT_DEV_SECRET)
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days session

    # CORS Allowed Origins and Regex Patterns
    CORS_ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
        "http://localhost",
        "http://127.0.0.1",
    ]
    CORS_ORIGIN_REGEX: str = r"^https?:\/\/(localhost|127\.0\.0\.1|([a-zA-Z0-9-]+\.)*trycloudflare\.com)(:\d+)?$"

    def validate_production_configuration(self):
        """Disallows starting in production mode with known public development secret."""
        if self.ENVIRONMENT in ("production", "prod") and self.SECRET_KEY == self._DEFAULT_DEV_SECRET:
            raise RuntimeError(
                "FATAL CONFIGURATION ERROR: The default development SECRET_KEY cannot be used when "
                "ENVIRONMENT is set to 'production'. Please set a cryptographically random SECRET_KEY environment variable."
            )

    # Database
    _DEFAULT_SQLITE: str = (
        "sqlite:////tmp/attendance_system.db"
        if (os.environ.get("X_ZOHO_CATALYST_LISTEN_PORT") or (os.name != "nt" and not os.access(".", os.W_OK)))
        else "sqlite:///./attendance_system.db"
    )
    DATABASE_URL: str = os.getenv("DATABASE_URL", _DEFAULT_SQLITE)

    # System Capacity Limits (5,000 students, 250 faculty)
    MAX_STUDENTS: int = int(os.getenv("MAX_STUDENTS", "5000"))
    MAX_FACULTY: int = int(os.getenv("MAX_FACULTY", "250"))

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
settings.validate_production_configuration()

