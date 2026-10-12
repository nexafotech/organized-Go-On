from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Enum as SQLEnum, Text, UniqueConstraint, Index
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
import enum
from app.core.database import Base

class SessionStatus(str, enum.Enum):
    SCHEDULED = "SCHEDULED"
    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"

class AttendanceStatus(str, enum.Enum):
    PRESENT = "PRESENT"
    ABSENT = "ABSENT"
    UNCERTAIN = "UNCERTAIN"
    # M4: Extended statuses
    OD = "OD"               # On Duty — separately identifiable, not simply PRESENT
    NOT_ENTERED = "NOT_ENTERED"   # Faculty hasn't marked yet
    NO_CLASS = "NO_CLASS"         # No class scheduled/cancelled
    SUSPENDED = "SUSPENDED"        # Student suspension

class RecognitionSource(str, enum.Enum):
    LIVE_CAMERA = "LIVE_CAMERA"
    GROUP_PHOTO = "GROUP_PHOTO"
    MANUAL = "MANUAL"
    OD_OVERRIDE = "OD_OVERRIDE"   # M4: Source for OD markings

class ReviewStatus(str, enum.Enum):
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    PENDING = "PENDING"

class ClassSession(Base):
    __tablename__ = "class_sessions"

    id = Column(Integer, primary_key=True, index=True)
    timetable_entry_id = Column(Integer, ForeignKey("timetable_entries.id", ondelete="SET NULL"), nullable=True)
    faculty_id = Column(Integer, ForeignKey("faculty.id", ondelete="CASCADE"), nullable=False)
    date = Column(String(10), nullable=False, index=True)  # YYYY-MM-DD
    status = Column(SQLEnum(SessionStatus), default=SessionStatus.SCHEDULED, nullable=False)
    start_timestamp = Column(DateTime, nullable=True)
    end_timestamp = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    timetable_entry = relationship("TimetableEntry", back_populates="class_sessions")
    faculty = relationship("Faculty", back_populates="class_sessions")
    attendance_records = relationship("AttendanceRecord", back_populates="session", cascade="all, delete-orphan")

class AttendanceRecord(Base):
    __tablename__ = "attendance_records"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("class_sessions.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    status = Column(SQLEnum(AttendanceStatus), default=AttendanceStatus.PRESENT, nullable=False)
    confidence = Column(Float, nullable=True)  # e.g., 95.42%
    recognized_via = Column(SQLEnum(RecognitionSource), default=RecognitionSource.LIVE_CAMERA, nullable=False)
    review_status = Column(SQLEnum(ReviewStatus), default=ReviewStatus.APPROVED, nullable=False)
    # M4: OD fields
    od_reason = Column(String(500), nullable=True)   # Reason for On Duty marking
    marked_by_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    marked_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    session = relationship("ClassSession", back_populates="attendance_records")
    student = relationship("Student", back_populates="attendance_records")

    __table_args__ = (
        UniqueConstraint("session_id", "student_id", name="uq_attendance_record_session_student"),
        Index("ix_attendance_records_session_student", "session_id", "student_id"),
    )

class FaceEmbedding(Base):
    __tablename__ = "face_embeddings"

    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    embedding_json = Column(Text, nullable=False)  # JSON-encoded array of floats
    image_path = Column(String(255), nullable=True)
    model_name = Column(String(50), nullable=False, default="dlib_resnet", server_default="dlib_resnet")
    model_version = Column(String(20), nullable=False, default="v1", server_default="v1")
    dimension = Column(Integer, nullable=False, default=128, server_default="128")
    detector_name = Column(String(50), nullable=False, default="dlib_hog", server_default="dlib_hog")
    distance_metric = Column(String(20), nullable=False, default="euclidean", server_default="euclidean")
    quality_score = Column(Float, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    student = relationship("Student", back_populates="face_embeddings")

    __table_args__ = (
        Index("ix_face_embeddings_student_model", "student_id", "model_name"),
    )
