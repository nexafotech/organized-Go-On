from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Enum as SQLEnum
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
import enum
from app.core.database import Base

class UserRole(str, enum.Enum):
    ADMIN = "ADMIN"
    FACULTY = "FACULTY"
    STUDENT = "STUDENT"

class PasswordChangeScope(str, enum.Enum):
    ALL_STUDENTS = "ALL_STUDENTS"
    ALL_FACULTY = "ALL_FACULTY"
    ALL_USERS = "ALL_USERS"
    SELECTED_STUDENTS = "SELECTED_STUDENTS"
    SELECTED_FACULTY = "SELECTED_FACULTY"
    SELECTED_ACCOUNTS = "SELECTED_ACCOUNTS"

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=True)  # nullable for students using reg num
    hashed_password = Column(String(255), nullable=False)
    role = Column(SQLEnum(UserRole), nullable=False, default=UserRole.FACULTY)
    is_active = Column(Boolean, default=True)
    session_token = Column(String(255), nullable=True, index=True)
    # M4 / 10C.14: Account security fields
    force_password_change = Column(Boolean, default=False, nullable=False)
    failed_login_attempts = Column(Integer, default=0, nullable=False)
    locked_until = Column(DateTime, nullable=True)
    password_changed_at = Column(DateTime, nullable=True)
    password_change_window_id = Column(Integer, ForeignKey("password_change_windows.id", ondelete="SET NULL", use_alter=True, name="fk_user_password_change_window"), nullable=True)
    # M4: login_identifier stores the primary lookup value (employee_id, register_number)
    login_identifier = Column(String(100), nullable=True, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    faculty_profile = relationship("Faculty", back_populates="user", uselist=False, cascade="all, delete-orphan")
    student_profile = relationship("Student", back_populates="user", uselist=False)
    audit_logs = relationship("AuditLog", back_populates="user")
    password_change_window = relationship("PasswordChangeWindow", foreign_keys=[password_change_window_id])

class PasswordChangeWindow(Base):
    __tablename__ = "password_change_windows"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(100), nullable=False)
    scope = Column(SQLEnum(PasswordChangeScope), nullable=False, default=PasswordChangeScope.ALL_USERS)
    target_ids = Column(String(1000), nullable=True)  # JSON or comma-separated list of target student/faculty/user IDs
    start_at = Column(DateTime, nullable=True)
    end_at = Column(DateTime, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    creator = relationship("User", foreign_keys=[created_by])

class AdminSupportSession(Base):
    __tablename__ = "admin_support_sessions"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(String(64), unique=True, index=True, nullable=False)
    admin_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    target_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    target_role = Column(String(20), nullable=False)
    read_only = Column(Boolean, default=True, nullable=False)
    reason = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    expires_at = Column(DateTime, nullable=False)
    ended_at = Column(DateTime, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)

    admin_user = relationship("User", foreign_keys=[admin_user_id])
    target_user = relationship("User", foreign_keys=[target_user_id])

class Faculty(Base):
    __tablename__ = "faculty"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    employee_id = Column(String(50), unique=True, index=True, nullable=False)
    full_name = Column(String(100), nullable=False)
    department = Column(String(100), nullable=True)
    phone = Column(String(20), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    user = relationship("User", back_populates="faculty_profile")
    assignments = relationship("FacultyAssignment", back_populates="faculty", cascade="all, delete-orphan")
    class_sessions = relationship("ClassSession", back_populates="faculty")
